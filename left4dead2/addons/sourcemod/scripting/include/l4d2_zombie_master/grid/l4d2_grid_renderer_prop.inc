/**
 * Grid Renderer Backend: prop_dynamic + Custom Model
 * Spawns colored quad models at cell positions
 */

#if defined _l4d2_grid_renderer_prop_included
 #endinput
#endif
#define _l4d2_grid_renderer_prop_included

// SDKHooks for transmit filtering
#include <sdkhooks>

// ============================================================================
// Constants
// ============================================================================

#define GRIDRENDERERPROP_MAX_ENTITIES 25
#define GRIDRENDERERPROP_MODEL_BASE "models/grid/grid_cell6"
#define GRIDRENDERERPROP_MODEL      GRIDRENDERERPROP_MODEL_BASE ... ".mdl"
#define GRIDRENDERERPROP_MODEL_VVD  GRIDRENDERERPROP_MODEL_BASE ... ".vvd"
#define GRIDRENDERERPROP_MODEL_VTX  GRIDRENDERERPROP_MODEL_BASE ... ".dx90.vtx"

// Render modes
#define RENDER_NORMAL     0
#define RENDER_TRANSCOLOR 1
#define RENDER_TRANSTEXTURE 2
#define RENDER_TRANSALPHA 4
#define RENDER_TRANSADD   5

// Entity effect flags
#define EF_NOINTERP  8   // Don't interpolate position (snap instantly)
#define EF_NOSHADOW  16  // Don't cast shadows
#define EF_NODRAW    32  // Don't render

// order must match the $texturegroup skin family list in tools/models/grid/grid_cell6.qc
#define GRIDSKIN_VALID        0
#define GRIDSKIN_BLOCKED      1
#define GRIDSKIN_CONDITIONAL  2
#define GRIDSKIN_TARGET       3
#define GRIDSKIN_RING         4

// X-ray twins. Selected when a cell is underwater or out of the ZM's direct sight, so it
// draws through geometry
#define GRIDSKIN_VALID_XRAY       5
#define GRIDSKIN_BLOCKED_XRAY     6
#define GRIDSKIN_CONDITIONAL_XRAY 7
#define GRIDSKIN_SEEN             8
#define GRIDSKIN_NEAR             9
#define GRIDSKIN_SEEN_XRAY        10
#define GRIDSKIN_NEAR_XRAY        11

static const char GRIDSKIN_NAMES[][24] = {
	"valid", "blocked2", "conditional", "target", "ring",
	"valid_xray", "blocked2_xray", "conditional_xray",
	"seen", "near", "seen_xray", "near_xray"
};

#if GRIDRENDERER_MAX_CELLS > PVSFORCE_MAX_ORIGINS
 #error PVSFORCE_MAX_ORIGINS must be at least GRIDRENDERER_MAX_CELLS
#endif

// ============================================================================
// Data Structures
// ============================================================================

enum struct PropPool
{
	int entities[GRIDRENDERERPROP_MAX_ENTITIES];      // Entity refs
	int assignedCell[GRIDRENDERERPROP_MAX_ENTITIES];  // Cell index assigned to each entity (-1 = free)
	int lastColor[GRIDRENDERERPROP_MAX_ENTITIES];     // Last packed RGBA written
	int lastSkin[GRIDRENDERERPROP_MAX_ENTITIES];      // Last m_nSkin written
	bool glowOn[GRIDRENDERERPROP_MAX_ENTITIES];       // Last glow state written
	int glowRgb[GRIDRENDERERPROP_MAX_ENTITIES];       // Last glow colour written
	bool hidden[GRIDRENDERERPROP_MAX_ENTITIES];       // Currently EF_NODRAW'd by us
	int activeCount;                                  // Currently visible entities
	int totalAllocated;                               // Total allocated in pool
	bool initialized;                                 // Pool is ready

	int focusEntity;         // Entity ref, or INVALID_ENT_REFERENCE
	int focusLastColor;      // Last packed RGBA written
	int focusLastSkin;       // Last m_nSkin written
	float focusLastScale;    // Last m_flModelScale written
	bool focusHidden;
	bool focusCreateFailed;
}

// ============================================================================
// Private State
// ============================================================================

static PropPool g_PropPool[MAXPLAYERS+1];
static int g_Prop_OwnerClient[2049];   // Entity index -> owner client
static bool g_PropModelPrecached = false;
static bool g_PropAlphaFade = true;    // Distance-based alpha fade
static bool g_PropClusterOverflowWarned = false;

// ============================================================================
// Backend Interface
// ============================================================================

/**
 * Enable or disable distance-based alpha fade on cells
 */
stock void GridRendererProp_SetAlphaFade(bool enabled)
{
	g_PropAlphaFade = enabled;
}

stock void GridRendererProp_Init()
{
	for (int i = 1; i <= MaxClients; i++)
		GridRendererProp_DestroyPool(i);

	for (int i = 0; i <= MaxClients; i++)
	{
		g_PropPool[i].initialized = false;
		g_PropPool[i].totalAllocated = 0;
		g_PropPool[i].activeCount = 0;
		for (int j = 0; j < GRIDRENDERERPROP_MAX_ENTITIES; j++)
			GridRendererProp_ResetSlot(i, j);
		GridRendererProp_ResetFocus(i);
	}

	for (int i = 0; i < sizeof(g_Prop_OwnerClient); i++)
		g_Prop_OwnerClient[i] = 0;

	g_PropClusterOverflowWarned = false;

	// Precache model and add to downloads table
	if (GridRendererProp_PrecacheAssets())
	{
		g_PropModelPrecached = true;
		if (DEBUG) LogMessage("[GridRenderer Prop] Model precached: %s", GRIDRENDERERPROP_MODEL);
	}
	else
	{
		g_PropModelPrecached = false;
		if (DEBUG) LogError("[GridRenderer Prop] Failed to precache model! Backend will be unavailable.");
	}
}

stock void GridRendererProp_Cleanup()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		GridRendererProp_DestroyPool(i);
	}
}

stock void GridRendererProp_OnClientEnabled(int client)
{
	if (!g_PropModelPrecached)
		return;

	GridRendererProp_CreatePool(client);
}

stock void GridRendererProp_OnClientDisabled(int client)
{
	GridRendererProp_DestroyPool(client);
}

/**
 * Draw cells using prop_dynamic entities with stable reconciliation.
 *
 * Entities are stably assigned to GridLib cell indices across frames. If a cell
 * persists between frames, the same entity keeps rendering it (color-only
 * update, no teleport). Only cells that appear/disappear cause entity
 * reassignment, eliminating visual "scrambling" when the grid moves.
 *
 * assignedCell[] stores the GridLib cell index (can be any positive int),
 * NOT the 0-24 position in the cellIndices array.
 */
stock int GridRendererProp_DrawCells(int client,
                                     const int cellIndices[GRIDRENDERER_MAX_CELLS],
                                     const bool cellValid[GRIDRENDERER_MAX_CELLS],
                                     int count,
                                     int closestValidIdx,
                                     const float overridePositions[GRIDRENDERER_MAX_CELLS][3],
                                     const bool hasOverride[GRIDRENDERER_MAX_CELLS],
                                     const bool overrideFlat[GRIDRENDERER_MAX_CELLS],
                                     const float overrideNormals[GRIDRENDERER_MAX_CELLS][3])
{
	if (!g_PropPool[client].initialized || !g_PropModelPrecached)
		return 0;

	int totalEnts = g_PropPool[client].totalAllocated;
	if (totalEnts <= 0)
		return 0;

	// Clamp count to pool size
	if (count > totalEnts)
		count = totalEnts;

	int clusterKeys[PVSFORCE_MAX_ORIGINS];
	int clusterEnts[PVSFORCE_MAX_ORIGINS];
	int clusterSetCount = 0;

	// --- Phase 1: Classify entities as "kept" or "freed" ---
	// An entity is "kept" if its assignedCell matches one of the new cellIndices.
	// We also record which cellIndices[] slot it matched (for color lookup).
	bool entityKept[GRIDRENDERERPROP_MAX_ENTITIES];
	int entityDataIdx[GRIDRENDERERPROP_MAX_ENTITIES]; // index into cellIndices/cellValid for kept entities
	bool justAssigned[GRIDRENDERERPROP_MAX_ENTITIES];
	bool cellHandled[GRIDRENDERER_MAX_CELLS];         // which cellIndices slots already have an entity

	for (int i = 0; i < GRIDRENDERER_MAX_CELLS; i++)
		cellHandled[i] = false;

	for (int e = 0; e < totalEnts; e++)
	{
		entityKept[e] = false;
		entityDataIdx[e] = -1;
		justAssigned[e] = false;

		int ac = g_PropPool[client].assignedCell[e];
		if (ac < 0)
			continue;

		// Search for this entity's assigned cell in the new cellIndices
		for (int i = 0; i < count; i++)
		{
			if (!cellHandled[i] && cellIndices[i] == ac)
			{
				// Match - keep this entity for this cell
				entityKept[e] = true;
				entityDataIdx[e] = i;
				cellHandled[i] = true;
				break;
			}
		}

		if (!entityKept[e])
		{
			// Cell is gone - free this entity
			g_PropPool[client].assignedCell[e] = -1;
		}
	}

	int drawn = 0;

	bool targetCollected = false;
	if (closestValidIdx >= 0 && cellHandled[closestValidIdx])
	{
		for (int e = 0; e < totalEnts; e++)
		{
			if (entityDataIdx[e] != closestValidIdx)
				continue;

			int targetAlpha = GridRendererProp_ComputeAlpha(closestValidIdx, count, true, g_GridCellContext[closestValidIdx]);
			GridRendererProp_CollectClusterOrigin(cellIndices[closestValidIdx], targetAlpha,
				EntRefToEntIndex(g_PropPool[client].entities[e]), hasOverride[closestValidIdx],
				clusterKeys, clusterEnts, clusterSetCount);

			targetCollected = true;
			break;
		}
	}

	// --- Phase 2: Assign freed entities to new (unmatched) cells ---
	int freeIdx = 0;
	for (int n = 0; n < count; n++)
	{
		int i = n;
		if (closestValidIdx >= 0 && closestValidIdx < count && !targetCollected)
		{
			if (n == 0) i = closestValidIdx;
			else if (n == closestValidIdx) i = 0;
		}

		if (cellHandled[i])
			continue;  // Already has a kept entity

		// Find next free entity
		while (freeIdx < totalEnts && entityKept[freeIdx])
			freeIdx++;

		if (freeIdx >= totalEnts)
			break;  // No more free entities

		// Assign this freed entity to the new cell
		g_PropPool[client].assignedCell[freeIdx] = cellIndices[i];
		entityKept[freeIdx] = true;
		entityDataIdx[freeIdx] = i;

		// Get cell data and teleport
		float position[3], normal[3];
		Address navArea;
		bool obstructed;

		if (GridLib_GetCellData(cellIndices[i], position, normal, navArea, obstructed))
		{
			// Apply runtime rescue position override (prop top, etc.)
			if (hasOverride[i])
			{
				position[0] = overridePositions[i][0];
				position[1] = overridePositions[i][1];
				position[2] = overridePositions[i][2];

				if (overrideFlat[i])
				{
					normal[0] = 0.0;
					normal[1] = 0.0;
					normal[2] = 1.0;
				}
				else
				{
					normal[0] = overrideNormals[i][0];
					normal[1] = overrideNormals[i][1];
					normal[2] = overrideNormals[i][2];
				}
			}

			int color[4];
			bool isClosest = (i == closestValidIdx);
			int cellClass = GridRenderer_ClassifyCell(cellValid[i], g_GridCellContext[i], g_GridCellCooldown[i]);
			GridRenderer_ResolveColor(cellClass, isClosest, color);
			color[3] = GridRendererProp_ComputeAlpha(i, count, isClosest, g_GridCellContext[i]);

			bool isTarget = isClosest && cellValid[i] && g_iSpawnerMode==2;
			bool underwater = GridLib_IsCellUnderwater(cellIndices[i]);
			int skin = GridRendererProp_ResolveStateSkin(cellClass, isTarget);

			float angles[3];
			GridRendererProp_NormalToAngles(normal, angles);
			GridRendererProp_UpdateEntity(client, freeIdx, position, angles, color, skin, isTarget, underwater);

			GridRendererProp_CollectClusterOrigin(cellIndices[i], color[3],
				EntRefToEntIndex(g_PropPool[client].entities[freeIdx]), hasOverride[i],
				clusterKeys, clusterEnts, clusterSetCount);

			drawn++;

			justAssigned[freeIdx] = true;
		}

		freeIdx++;
	}

	// --- Phase 3: Update kept entities (color + teleport if override changed) ---
	for (int e = 0; e < totalEnts; e++)
	{
		int dataIdx = entityDataIdx[e];
		if (dataIdx < 0 || justAssigned[e])
			continue;  // Unused (hidden in Phase 4), or already drawn by Phase 2 above

		// Update color (and ensure visible)
		int color[4];
		bool isClosest = (dataIdx == closestValidIdx);
		int cellClass = GridRenderer_ClassifyCell(cellValid[dataIdx], g_GridCellContext[dataIdx], g_GridCellCooldown[dataIdx]);
		GridRenderer_ResolveColor(cellClass, isClosest, color);
		color[3] = GridRendererProp_ComputeAlpha(dataIdx, count, isClosest, g_GridCellContext[dataIdx]);

		bool isTarget = isClosest && cellValid[dataIdx] && g_iSpawnerMode==2;
		bool underwater = GridLib_IsCellUnderwater(cellIndices[dataIdx]);
		int skin = GridRendererProp_ResolveStateSkin(cellClass, isTarget);

		// If this cell has a rescue position override, teleport to the adjusted position
		if (hasOverride[dataIdx])
		{
			float position[3], normal[3];
			Address navArea;
			bool obstructed;
			if (GridLib_GetCellData(cellIndices[dataIdx], position, normal, navArea, obstructed))
			{
				position[0] = overridePositions[dataIdx][0];
				position[1] = overridePositions[dataIdx][1];
				position[2] = overridePositions[dataIdx][2];

				if (overrideFlat[dataIdx])
				{
					normal[0] = 0.0;
					normal[1] = 0.0;
					normal[2] = 1.0;
				}
				else
				{
					normal[0] = overrideNormals[dataIdx][0];
					normal[1] = overrideNormals[dataIdx][1];
					normal[2] = overrideNormals[dataIdx][2];
				}

				float angles[3];
				GridRendererProp_NormalToAngles(normal, angles);
				GridRendererProp_UpdateEntity(client, e, position, angles, color, skin, isTarget, underwater);
			}
			else
			{
				GridRendererProp_UpdateEntityColor(client, e, color, skin, isTarget, underwater);
			}
		}
		else
		{
			GridRendererProp_UpdateEntityColor(client, e, color, skin, isTarget, underwater);
		}

		if (dataIdx != closestValidIdx || !targetCollected)
		{
			GridRendererProp_CollectClusterOrigin(cellIndices[dataIdx], color[3],
				EntRefToEntIndex(g_PropPool[client].entities[e]), hasOverride[dataIdx],
				clusterKeys, clusterEnts, clusterSetCount);
		}

		drawn++;
	}

	// --- Phase 4: Hide unused entities ---
	for (int e = 0; e < totalEnts; e++)
	{
		if (g_PropPool[client].assignedCell[e] < 0)
			GridRendererProp_HideEntity(client, e);
	}

	// --- Phase 5: Position the focus marker on the target cell ---
	if (g_iSpawnerMode != 2)
	{
		GridRendererProp_HideFocusMarker(client);
	}
	else
	{
		int focusTargetEnt = INVALID_ENT_REFERENCE;
		if (closestValidIdx >= 0)
		{
			for (int e = 0; e < totalEnts; e++)
			{
				if (entityDataIdx[e] == closestValidIdx)
				{
					focusTargetEnt = EntRefToEntIndex(g_PropPool[client].entities[e]);
					break;
				}
			}
		}

		if (focusTargetEnt == INVALID_ENT_REFERENCE || !IsValidEntity(focusTargetEnt))
		{
			GridRendererProp_HideFocusMarker(client);
		}
		else if (!GridRendererProp_EnsureFocusMarker(client))
		{
			GridRendererProp_HideFocusMarker(client);
		}
		else
		{
			float focusPos[3], focusAng[3];
			GetEntPropVector(focusTargetEnt, Prop_Send, "m_vecOrigin", focusPos);
			GetEntPropVector(focusTargetEnt, Prop_Send, "m_angRotation", focusAng);
			GridRendererProp_UpdateFocusMarker(client, focusPos, focusAng, GridRendererProp_ResolveHullScale());
		}
	}

	PvsForce_SetOrigins(client, clusterEnts, clusterSetCount);

	g_PropPool[client].activeCount = drawn;
	return drawn;
}

// ============================================================================
// Alpha Helpers
// ============================================================================

/**
 * Compute alpha for a cell based on its distance rank from center.
 * Cells are sorted closest-first, so dataIdx 0 = center, count-1 = edge.
 *
 * @param dataIdx       Index in the sorted cellIndices array (0 = closest)
 * @param count         Total cells being rendered
 * @param isClosest     Whether this is the highlighted (closest valid) cell
 * @return              Alpha value (0-255)
 */
static int GridRendererProp_ComputeAlpha(int dataIdx, int count, bool isClosest, int state = SPAWNER_OK)
{
	if (state==SPAWNER_BUDGET) return 0;

	static const int ALPHA_CENTER = 230;
	static const int ALPHA_EDGE = 66;

	int alpha;
	if (isClosest && g_iSpawnerMode==2)
		alpha = 255;
	else if (!g_PropAlphaFade)
		alpha = 95;
	else if (count <= 1)
		alpha = ALPHA_CENTER;
	else
	{
		// Linear interpolation: t goes from 0.0 (center) to 1.0 (edge)
		float t = float(dataIdx) / float(count - 1);
		alpha = RoundToNearest(float(ALPHA_CENTER) + t * float(ALPHA_EDGE - ALPHA_CENTER));
	}

	return alpha;
}

// ============================================================================
// Skin Helpers
// ============================================================================

/**
 * Resolve a cell's base skin from its class.
 *
 * @param cellClass    GRIDCELL_CLASS_* from GridRenderer_ClassifyCell
 * @param isTarget     Closest valid cell under Spawner Mode 2 (the ZM's active pick)
 * @return             Resolved GRIDSKIN_* constant
 */
static int GridRendererProp_ResolveStateSkin(int cellClass, bool isTarget)
{
	if (isTarget)
		return GRIDSKIN_TARGET;

	switch (cellClass)
	{
		case GRIDCELL_CLASS_VALID: return GRIDSKIN_VALID;
		case GRIDCELL_CLASS_SEEN:  return GRIDSKIN_SEEN;
		case GRIDCELL_CLASS_NEAR:  return GRIDSKIN_NEAR;
		case GRIDCELL_CLASS_DEAD:  return GRIDSKIN_BLOCKED;
	}

	return GRIDSKIN_CONDITIONAL;
}

/**
 * Map a base state skin to its x-ray twin.
 *
 * @param baseSkin    GRIDSKIN_* returned by GridRendererProp_ResolveStateSkin
 * @return            The base skin's x-ray twin, or the base skin unchanged if it has none
 */
static int GridRendererProp_ResolveOccludedSkin(int baseSkin)
{
	switch (baseSkin)
	{
		case GRIDSKIN_VALID:       return GRIDSKIN_VALID_XRAY;
		case GRIDSKIN_BLOCKED:     return GRIDSKIN_BLOCKED_XRAY;
		case GRIDSKIN_CONDITIONAL: return GRIDSKIN_CONDITIONAL_XRAY;
		case GRIDSKIN_SEEN:        return GRIDSKIN_SEEN_XRAY;
		case GRIDSKIN_NEAR:        return GRIDSKIN_NEAR_XRAY;
	}

	// GRIDSKIN_TARGET and GRIDSKIN_RING already carry $ignorez and need no twin.
	// Returning the base keeps this safe if a state is added later without XRAY variant.
	return baseSkin;
}

static void GridRendererProp_CollectClusterOrigin(int gridCellIdx, int alpha, int entity, bool skipOverrideDedup,
                                                    int clusterKeys[PVSFORCE_MAX_ORIGINS],
                                                    int clusterEnts[PVSFORCE_MAX_ORIGINS],
                                                    int &setCount)
{
	if (alpha == 0 || entity <= 0 || !IsValidEntity(entity))
		return;

	if (skipOverrideDedup)
	{
		if (setCount >= PVSFORCE_MAX_ORIGINS)
		{
			if (!g_PropClusterOverflowWarned)
			{
				LogError("[GridRenderer Prop] PVS cluster set hit its bound (%d); some drawn cells will not transmit through walls this frame.", PVSFORCE_MAX_ORIGINS);
				g_PropClusterOverflowWarned = true;
			}
			return;
		}
		clusterKeys[setCount] = -2 - setCount;
		clusterEnts[setCount] = entity;
		setCount++;
		return;
	}

	int cluster = GridLib_GetCellCluster(gridCellIdx);

	if (cluster == -1)
		return;

	for (int j = 0; j < setCount; j++)
	{
		if (clusterKeys[j] == cluster)
			return; // Cluster already has a representative origin
	}

	if (setCount >= PVSFORCE_MAX_ORIGINS)
	{
		if (!g_PropClusterOverflowWarned)
		{
			LogError("[GridRenderer Prop] PVS cluster set hit its bound (%d); some drawn cells will not transmit through walls this frame.", PVSFORCE_MAX_ORIGINS);
			g_PropClusterOverflowWarned = true;
		}
		return;
	}

	clusterKeys[setCount] = cluster;
	clusterEnts[setCount] = entity;
	setCount++;
}

// ============================================================================
// Asset Management
// ============================================================================

/**
 * Precache model and add files to download table
 */
stock bool GridRendererProp_PrecacheAssets()
{
	// Check if model file exists before trying to precache
	if (!FileExists(GRIDRENDERERPROP_MODEL, true))
	{
		LogError("[GridRenderer Prop] Model file not found: %s", GRIDRENDERERPROP_MODEL);
		LogError("[GridRenderer Prop] To use this backend, create the model files.");
		LogError("[GridRenderer Prop] See RENDERER_BACKENDS.md for details.");
		return false;
	}

	PrecacheModel(GRIDRENDERERPROP_MODEL, true);

	// Add model files, and every skin family's material, to the downloads table
	if (FindConVar("sv_allowdownload").BoolValue)
	{
		AddFileToDownloadsTable(GRIDRENDERERPROP_MODEL);
		AddFileToDownloadsTable(GRIDRENDERERPROP_MODEL_VVD);
		AddFileToDownloadsTable(GRIDRENDERERPROP_MODEL_VTX);

		char path[PLATFORM_MAX_PATH];
		for (int i = 0; i < sizeof(GRIDSKIN_NAMES); i++)
		{
			FormatEx(path, sizeof(path), "materials/models/grid/grid_cell_%s.vmt", GRIDSKIN_NAMES[i]);
			AddFileToDownloadsTable(path);

			FormatEx(path, sizeof(path), "materials/models/grid/grid_cell_%s.vtf", GRIDSKIN_NAMES[i]);
			AddFileToDownloadsTable(path);
		}
	}

	return true;
}

// ============================================================================
// Pool Management
// ============================================================================

static void GridRendererProp_ResetSlot(int client, int idx)
{
	g_PropPool[client].assignedCell[idx] = -1;
	g_PropPool[client].lastColor[idx] = 0;
	g_PropPool[client].lastSkin[idx] = -1;
	g_PropPool[client].glowOn[idx] = false;
	g_PropPool[client].glowRgb[idx] = 0;
	g_PropPool[client].hidden[idx] = true;
}

static void GridRendererProp_ResetFocus(int client)
{
	g_PropPool[client].focusEntity = INVALID_ENT_REFERENCE;
	g_PropPool[client].focusLastColor = 0;
	g_PropPool[client].focusLastSkin = -1;
	g_PropPool[client].focusLastScale = -1.0;
	g_PropPool[client].focusHidden = true;
	g_PropPool[client].focusCreateFailed = false;
}

/**
 * Create the entity pool for a client
 */
static void GridRendererProp_CreatePool(int client)
{
	if (g_PropPool[client].initialized)
		return;

	int created = 0;

	for (int i = 0; i < GRIDRENDERERPROP_MAX_ENTITIES; i++)
	{
		int ent = CreateEntityByName("prop_dynamic_override");
		if (!IsEntitySafe(ent))
		{
			LogError("[GridRenderer Prop] Edict limit reached at %d/%d entities", i, GRIDRENDERERPROP_MAX_ENTITIES);
			break;
		}

		DispatchKeyValue(ent, "model", GRIDRENDERERPROP_MODEL);
		DispatchKeyValue(ent, "solid", "0");            // Not solid
		DispatchKeyValue(ent, "disableshadows", "1");    // No cast shadows
		DispatchKeyValue(ent, "disablereceiveshadows", "1"); // No receive shadows
		DispatchKeyValue(ent, "DisableBoneFollowers", "1"); // Save edicts

		DispatchSpawn(ent);

		// Set render mode for color/alpha support
		SetEntityRenderMode(ent, view_as<RenderMode>(RENDER_TRANSCOLOR));
		SetEntityRenderColor(ent, 0, 0, 0, 0);

		// Start hidden, no shadows, no interpolation
		int effects = GetEntProp(ent, Prop_Send, "m_fEffects");
		SetEntProp(ent, Prop_Send, "m_fEffects", effects | EF_NODRAW | EF_NOSHADOW | EF_NOINTERP);

		GridRendererProp_ResetSlot(client, i);

		// Set up transmit hook for per-client visibility
		g_Prop_OwnerClient[ent] = client;
		SDKHook(ent, SDKHook_SetTransmit, GridRendererProp_OnSetTransmit);

		g_PropPool[client].entities[i] = EntIndexToEntRef(ent);
		created++;

		// Force-visible to the owner through walls and across the whole map, while
		// the SDKHook_SetTransmit gate above keeps it invisible to other clients.
		PvsForce_Register(ent, client);

	}

	for (int i = created; i < GRIDRENDERERPROP_MAX_ENTITIES; i++)
		GridRendererProp_ResetSlot(client, i);

	g_PropPool[client].totalAllocated = created;
	g_PropPool[client].activeCount = 0;
	g_PropPool[client].initialized = true;

	GridRendererProp_ResetFocus(client);

	if (DEBUG) LogMessage("[GridRenderer Prop] Created pool for client %d: %d entities", client, created);
}

/**
 * Destroy the entity pool for a client
 */
static void GridRendererProp_DestroyPool(int client)
{
	if (!g_PropPool[client].initialized)
		return;

	if (DEBUG) LogMessage("[zm] GridRendererProp_DestroyPool: client=%d, entities=%d",
		                  client, g_PropPool[client].totalAllocated);

	for (int i = 0; i < g_PropPool[client].totalAllocated; i++)
	{
		// Unregister by the stored ref unconditionally, so the PVS-force count is
		// released even if the prop was already invalidated before teardown.
		PvsForce_UnregisterRef(g_PropPool[client].entities[i]);

		int ent = EntRefToEntIndex(g_PropPool[client].entities[i]);
		if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent))
		{
			g_Prop_OwnerClient[ent] = 0;
			RemoveEntity(ent);
		}

		GridRendererProp_ResetSlot(client, i);
	}

	PvsForce_UnregisterRef(g_PropPool[client].focusEntity);
	int focus = EntRefToEntIndex(g_PropPool[client].focusEntity);
	if (focus != INVALID_ENT_REFERENCE && IsValidEntity(focus))
	{
		g_Prop_OwnerClient[focus] = 0;
		RemoveEntity(focus);
	}
	GridRendererProp_ResetFocus(client);

	g_PropPool[client].totalAllocated = 0;
	g_PropPool[client].activeCount = 0;
	g_PropPool[client].initialized = false;
}

// ============================================================================
// Entity Updates
// ============================================================================

static bool GridRendererProp_ColorChanged(int client, int idx, const int color[4])
{
	int packed = (color[0] << 24) | (color[1] << 16) | (color[2] << 8) | color[3];
	if (g_PropPool[client].lastColor[idx] == packed)
		return false;

	g_PropPool[client].lastColor[idx] = packed;
	return true;
}

static bool GridRendererProp_SkinChanged(int client, int idx, int skin)
{
	if (g_PropPool[client].lastSkin[idx] == skin)
		return false;

	g_PropPool[client].lastSkin[idx] = skin;
	return true;
}

/**
 * Decide whether a cell glows, and swap its skin to the x-ray twin when it is hidden.
 *
 * A cell counts as hidden when it is underwater or when the ZM has no direct line to it.
 *
 * @param isTarget    Cell is the ZM's active pick
 * @param underwater  GridLib_IsCellUnderwater for this cell
 * @param position    Cell world position, used for the ZM sight trace
 * @param alpha       Resolved alpha; 0 means the cell is not drawn at all
 * @param skin        In/out: swapped to the x-ray twin when the cell is hidden
 * @return            Whether the cell should glow
 */
static bool GridRendererProp_ShouldGlow(bool isTarget, bool underwater, const float position[3], int alpha, int &skin)
{
	if (alpha == 0)
		return false;

	if (isTarget)
		return true;

	bool hidden = underwater || !can_ZM_see(position, 1.0);
	if (hidden)
		skin = GridRendererProp_ResolveOccludedSkin(skin);

	return hidden;
}

/**
 * Update a prop entity's position, angle, color, skin, and glow state
 */
static void GridRendererProp_UpdateEntity(int client, int idx,
                                           const float position[3],
                                           const float angles[3],
                                           const int color[4],
                                           int skin,
                                           bool isTarget,
                                           bool underwater)
{
	int ent = EntRefToEntIndex(g_PropPool[client].entities[idx]);
	if (ent == INVALID_ENT_REFERENCE || !IsValidEntity(ent))
		return;

	TeleportEntity(ent, position, angles, NULL_VECTOR);
	if (GridRendererProp_ColorChanged(client, idx, color))
		SetEntityRenderColor(ent, color[0], color[1], color[2], color[3]);

	int effects = GetEntProp(ent, Prop_Send, "m_fEffects") & ~EF_NODRAW;
	if (g_iSpawnerMode<2) effects = effects | EF_NOSHADOW;
	else effects = effects | EF_NOSHADOW | EF_NOINTERP;
	SetEntProp(ent, Prop_Send, "m_fEffects", effects);
	g_PropPool[client].hidden[idx] = false;

	bool glow = GridRendererProp_ShouldGlow(isTarget, underwater, position, color[3], skin);
	if (GridRendererProp_SkinChanged(client, idx, skin))
		SetEntProp(ent, Prop_Send, "m_nSkin", skin);

	GridRendererProp_SetGlow(client, idx, glow, color);
}

/**
 * Update a prop entity's color, skin, and glow only (no teleport) and ensure visible
 */
static void GridRendererProp_UpdateEntityColor(int client, int idx, const int color[4], int skin, bool isTarget, bool underwater)
{
	int ent = EntRefToEntIndex(g_PropPool[client].entities[idx]);
	if (ent == INVALID_ENT_REFERENCE || !IsValidEntity(ent))
		return;

	if (GridRendererProp_ColorChanged(client, idx, color))
		SetEntityRenderColor(ent, color[0], color[1], color[2], color[3]);

	int effects = GetEntProp(ent, Prop_Send, "m_fEffects") & ~EF_NODRAW;
    if (g_iSpawnerMode<2) effects = effects | EF_NOSHADOW;
    else effects = effects | EF_NOSHADOW | EF_NOINTERP;
	SetEntProp(ent, Prop_Send, "m_fEffects", effects);
	g_PropPool[client].hidden[idx] = false;

	float position[3];
	if (!isTarget && !underwater && color[3] != 0)
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", position);

	bool glow = GridRendererProp_ShouldGlow(isTarget, underwater, position, color[3], skin);
	if (GridRendererProp_SkinChanged(client, idx, skin))
		SetEntProp(ent, Prop_Send, "m_nSkin", skin);

	GridRendererProp_SetGlow(client, idx, glow, color);
}

static void GridRendererProp_SetGlow(int client, int idx, bool glow, const int color[4])
{
	int rgb = color[0] | (color[1] << 8) | (color[2] << 16);

	if (g_PropPool[client].glowOn[idx] == glow && (!glow || g_PropPool[client].glowRgb[idx] == rgb))
		return;

	int ent = EntRefToEntIndex(g_PropPool[client].entities[idx]);
	if (ent == INVALID_ENT_REFERENCE || !IsValidEntity(ent))
		return;

	g_PropPool[client].glowOn[idx] = glow;

	if (glow)
	{
		g_PropPool[client].glowRgb[idx] = rgb;
		SetEntProp(ent, Prop_Send, "m_iGlowType", 3);
		SetEntProp(ent, Prop_Send, "m_glowColorOverride", rgb);
		SetEntProp(ent, Prop_Send, "m_nGlowRangeMin", 0);
		SetEntProp(ent, Prop_Send, "m_nGlowRange", 999999);
		AcceptEntityInput(ent, "StartGlowing");
	}
	else
	{
		SetEntProp(ent, Prop_Send, "m_glowColorOverride", 0);
		AcceptEntityInput(ent, "StopGlowing");
	}
}

static void GridRendererProp_HideEntity(int client, int idx)
{
	if (g_PropPool[client].hidden[idx] && !g_PropPool[client].glowOn[idx])
		return;

	int ent = EntRefToEntIndex(g_PropPool[client].entities[idx]);
	if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent))
	{
		// Set EF_NODRAW, keep EF_NOSHADOW + EF_NOINTERP
		int effects = GetEntProp(ent, Prop_Send, "m_fEffects");
		SetEntProp(ent, Prop_Send, "m_fEffects", effects | EF_NODRAW | EF_NOSHADOW | EF_NOINTERP);

		SetEntProp(ent, Prop_Send, "m_glowColorOverride", 0);
		AcceptEntityInput(ent, "StopGlowing");
		g_PropPool[client].hidden[idx] = true;
		g_PropPool[client].glowOn[idx] = false;
		g_PropPool[client].glowRgb[idx] = 0;
	}
}

void GridRendererProp_HideAll(int client)
{
	if (!g_PropPool[client].initialized) return;
	int totalEnts = g_PropPool[client].totalAllocated;
	for (int e = 0; e < totalEnts; e++)
	{
		g_PropPool[client].assignedCell[e] = -1;
		GridRendererProp_HideEntity(client, e);
	}
	g_PropPool[client].activeCount = 0;
	GridRendererProp_HideFocusMarker(client);
}

// ============================================================================
// Focus Marker
// ============================================================================

/**
 * Focus marker analog of GridRendererProp_ColorChanged.
 */
static bool GridRendererProp_FocusColorChanged(int client, const int color[4])
{
	int packed = (color[0] << 24) | (color[1] << 16) | (color[2] << 8) | color[3];
	if (g_PropPool[client].focusLastColor == packed)
		return false;

	g_PropPool[client].focusLastColor = packed;
	return true;
}

static bool GridRendererProp_FocusSkinChanged(int client, int skin)
{
	if (g_PropPool[client].focusLastSkin == skin)
		return false;

	g_PropPool[client].focusLastSkin = skin;
	return true;
}

static bool GridRendererProp_FocusScaleChanged(int client, float scale)
{
	if (g_PropPool[client].focusLastScale == scale)
		return false;

	g_PropPool[client].focusLastScale = scale;
	return true;
}

static float GridRendererProp_ResolveHullScale()
{
	int preview = EntRefToEntIndex(entref_preview);
	if (preview == INVALID_ENT_REFERENCE || !IsValidEntity(preview))
		return 1.0;

	float mins[3], maxs[3];
	GetEntPropVector(preview, Prop_Send, "m_vecMins", mins);
	GetEntPropVector(preview, Prop_Send, "m_vecMaxs", maxs);

	float wideX = maxs[0] - mins[0];
	float wideY = maxs[1] - mins[1];
	float width = (wideX > wideY) ? wideX : wideY;
	if (width <= 0.0)
		return 1.0;

	return width / GRIDLIB_CELL_SIZE;
}

static bool GridRendererProp_EnsureFocusMarker(int client)
{
	int existing = EntRefToEntIndex(g_PropPool[client].focusEntity);
	if (existing != INVALID_ENT_REFERENCE && IsValidEntity(existing))
		return true;

	PvsForce_UnregisterRef(g_PropPool[client].focusEntity);

	int focus = CreateEntityByName("prop_dynamic_override");
	if (!IsEntitySafe(focus))
	{
		if (!g_PropPool[client].focusCreateFailed)
		{
			LogError("[GridRenderer Prop] Edict limit reached creating focus marker for client %d", client);
			g_PropPool[client].focusCreateFailed = true;
		}
		return false;
	}

	DispatchKeyValue(focus, "model", GRIDRENDERERPROP_MODEL);
	DispatchKeyValue(focus, "solid", "0");
	DispatchKeyValue(focus, "disableshadows", "1");
	DispatchKeyValue(focus, "disablereceiveshadows", "1");
	DispatchKeyValue(focus, "DisableBoneFollowers", "1");

	DispatchSpawn(focus);

	SetEntityRenderMode(focus, view_as<RenderMode>(RENDER_TRANSCOLOR));
	SetEntityRenderColor(focus, 0, 0, 0, 0);

	int focusEffects = GetEntProp(focus, Prop_Send, "m_fEffects");
	SetEntProp(focus, Prop_Send, "m_fEffects", focusEffects | EF_NODRAW | EF_NOSHADOW | EF_NOINTERP);

	g_Prop_OwnerClient[focus] = client;
	SDKHook(focus, SDKHook_SetTransmit, GridRendererProp_OnSetTransmit);

	g_PropPool[client].focusEntity = EntIndexToEntRef(focus);

	PvsForce_Register(focus, client);

	g_PropPool[client].focusLastColor = 0;
	g_PropPool[client].focusLastSkin = -1;
	g_PropPool[client].focusLastScale = -1.0;
	g_PropPool[client].focusHidden = true;
	g_PropPool[client].focusCreateFailed = false;

	if (DEBUG) LogMessage("[GridRenderer Prop] Lazily created focus marker for client %d", client);

	return true;
}

static void GridRendererProp_HideFocusMarker(int client)
{
	if (g_PropPool[client].focusHidden)
		return;

	int ent = EntRefToEntIndex(g_PropPool[client].focusEntity);
	if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent))
	{
		int effects = GetEntProp(ent, Prop_Send, "m_fEffects");
		SetEntProp(ent, Prop_Send, "m_fEffects", effects | EF_NODRAW | EF_NOSHADOW | EF_NOINTERP);
		g_PropPool[client].focusHidden = true;
	}
}

static void GridRendererProp_UpdateFocusMarker(int client, const float position[3], const float angles[3], float scale)
{
	int ent = EntRefToEntIndex(g_PropPool[client].focusEntity);
	if (ent == INVALID_ENT_REFERENCE || !IsValidEntity(ent))
		return;

	TeleportEntity(ent, position, angles, NULL_VECTOR);

	if (GridRendererProp_FocusScaleChanged(client, scale))
		SetEntPropFloat(ent, Prop_Send, "m_flModelScale", scale);

	int color[4] = GRIDRENDERER_COLOR_HIGHLIGHT;
	if (GridRendererProp_FocusColorChanged(client, color))
		SetEntityRenderColor(ent, color[0], color[1], color[2], color[3]);

	if (GridRendererProp_FocusSkinChanged(client, GRIDSKIN_RING))
		SetEntProp(ent, Prop_Send, "m_nSkin", GRIDSKIN_RING);

	if (g_PropPool[client].focusHidden)
	{
		int effects = GetEntProp(ent, Prop_Send, "m_fEffects") & ~EF_NODRAW;
		SetEntProp(ent, Prop_Send, "m_fEffects", effects);
		g_PropPool[client].focusHidden = false;
	}
}

// ============================================================================
// Helpers
// ============================================================================

/**
 * Convert a surface normal vector to Euler angles for entity orientation.
 *
 * @param normal    Surface normal vector (unit length)
 * @param angles    Output: Pitch, Yaw, Roll angles in degrees
 */
static void GridRendererProp_NormalToAngles(const float normal[3], float angles[3])
{
	float ny = normal[1];
	if (ny > 0.99)  ny = 0.99;
	if (ny < -0.99) ny = -0.99;

	float pitch = RadToDeg(ArcTangent2(normal[0], normal[2]));
	float roll  = -RadToDeg(ArcSine(ny));

	angles[0] = pitch;
	angles[1] = 0.0;
	angles[2] = roll;
}

// ============================================================================
// Transmit Hook
// ============================================================================

/**
 * SetTransmit hook - only show entities to their owner client
 */
public Action GridRendererProp_OnSetTransmit(int entity, int client)
{
	if (g_Prop_OwnerClient[entity] != client)
		return Plugin_Handled;
	return Plugin_Continue;
}
