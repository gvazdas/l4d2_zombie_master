#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <dhooks>
#include <sdkhooks>
#include <left4dhooks>
#undef REQUIRE_PLUGIN

#define PLUGIN_NAME			    "l4d2_zombie_master"
#define PLUGIN_VERSION 			"0.1.8 2025-12-24"
#define GAMEDATA_FILE           PLUGIN_NAME

#define TEAM_SPECTATOR		1
#define TEAM_SURVIVOR		2
#define TEAM_INFECTED		3
#define TEAM_ZM 3

#define ZOMBIECLASS_SMOKER 	1
#define ZOMBIECLASS_BOOMER	 2
#define ZOMBIECLASS_HUNTER	 3
#define ZOMBIECLASS_SPITTER	4
#define ZOMBIECLASS_JOCKEY	 5
#define ZOMBIECLASS_CHARGER	6
#define ZOMBIECLASS_TANK	8

#define WITCH_STATIC 0
#define WITCH_MOVING 1

bool DEBUG = false;

//bool precached_resources = false;

#define MODEL_SMOKER "models/infected/smoker.mdl"
#define MODEL_BOOMER "models/infected/boomer.mdl"
#define MODEL_HUNTER "models/infected/hunter.mdl"
#define MODEL_SPITTER "models/infected/spitter.mdl"
#define MODEL_JOCKEY "models/infected/jockey.mdl"
#define MODEL_CHARGER "models/infected/charger.mdl"
#define MODEL_TANK "models/infected/hulk.mdl"

#define SOUND_READY "ui/critical_event_1.wav"
#define SOUND_START "ui/pickup_guitarriff10.wav"
#define SOUND_VISION "ui/menu_horror01.wav"
#define SOUND_PANIC_ON "npc/mega_mob/mega_mob_incoming.wav"
#define SOUND_PANIC_OFF "ui/pickup_secret01.wav"

// These are played whenever the ZM forces the round to start by slamming the door open.
#define SOUND_SCARY1 "ambient/creatures/town_moan1.wav"
#define SOUND_SCARY2 "ambient/creatures/town_scared_breathing1.wav"
#define SOUND_SCARY3 "ambient/creatures/town_scared_breathing2.wav"
#define SOUND_SCARY4 "ambient/creatures/town_scared_sob1.wav"
#define SOUND_SCARY5 "ambient/creatures/town_scared_sob2.wav"

#define VMT_LASERBEAM "sprites/laserbeam.vmt"
#define VMT_HALO "sprites/halo.vmt"

#define MAXENTITIES                   2048
#define ENTITY_SAFE_LIMIT 2000 //don't spawn boxes when it's index is above this
#define ENTITY_SAFER_LIMIT 1900

//Address pZombieManager = Address_Null;

// Thanks Forgetest
DynamicDetour g_dd_CTerrorPlayer_StartRangeCull;
bool dd_failed = false;

//signature call
static Handle hFlashLightTurnOn = null;
//static Handle StartRangeCull = null;
static Handle hCreateSmoker = null;
#define NAME_CreateSmoker "NextBotCreatePlayerBot<Smoker>"
#define NAME_CreateSmoker_L4D1 "reloffs_NextBotCreatePlayerBot<Smoker>"
static Handle hCreateBoomer = null;
#define NAME_CreateBoomer "NextBotCreatePlayerBot<Boomer>"
#define NAME_CreateBoomer_L4D1 "reloffs_NextBotCreatePlayerBot<Boomer>"
static Handle hCreateHunter = null;
#define NAME_CreateHunter "NextBotCreatePlayerBot<Hunter>"
#define NAME_CreateHunter_L4D1 "reloffs_NextBotCreatePlayerBot<Hunter>"
static Handle hCreateSpitter = null;
#define NAME_CreateSpitter "NextBotCreatePlayerBot<Spitter>"
static Handle hCreateJockey = null;
#define NAME_CreateJockey "NextBotCreatePlayerBot<Jockey>"
static Handle hCreateCharger = null;
#define NAME_CreateCharger "NextBotCreatePlayerBot<Charger>"
static Handle hCreateTank = null;
#define NAME_CreateTank "NextBotCreatePlayerBot<Tank>"
#define NAME_CreateTank_L4D1 "reloffs_NextBotCreatePlayerBot<Tank>"

// Cooldown on SI spawns: set intensity in seconds
// Witches are ridiculous. Make them more expensive and add 20s cooldown
// SI cooldown: 10s
// Tank cooldown: 30s
// 

// "infected"
// - m_flNextAttack (Offset 6108) (Save)(4 Bytes)
// - m_iDamageCount (Offset 6208) (Save)(4 Bytes)
// - m_CurrentWeaponProficiency (Offset 6212) (Save)(4 Bytes)
// - InputKilledNPC (Offset 0) (Input)(0 Bytes) - KilledNPC
// - m_flLastEventCheck (Offset 1092) (Save)(4 Bytes)
// - m_bSequenceFinished (Offset 1160) (Save)(1 Bytes)
// - m_nSequence (Offset 1172) (Save|Key)(4 Bytes) - sequence
// - m_flCycle (Offset 1168) (Save|Key)(4 Bytes) - cycle
// - m_flFrozen (Offset 1320) (Save)(4 Bytes)
// - m_iParent (Offset 132) (Save|Key)(4 Bytes) - parentname
// - m_pfnMoveDone (Offset 20) (Save)(8 Bytes)
// - m_target (Offset 248) (Save|Key)(4 Bytes) - target
// - m_flCreateTime (Offset 152) (Save)(4 Bytes)
// - m_bIsInStasis (Offset 8) (Save)(1 Bytes)
// - m_spawnflags (Offset 328) (Save|Key)(4 Bytes) - spawnflags
// - m_fFlags (Offset 336) (Save)(4 Bytes)
// - InputKill (Offset 0) (Input)(0 Bytes) - Kill
// GetEntPropEnt(common, Prop_Send, "m_clientLookatTarget");  

// player -- figure out bot management to prevent auto suicide
// m_StuckLast (Offset 6716) (Save)(4 Bytes)
// - m_lastDamageAmount (Offset 7480) (Save)(4 Bytes)
// - m_flDeathTime (Offset 7516) (Save)(4 Bytes)
// - m_DmgTake (Offset 7500) (Save)(4 Bytes)
// - m_DmgSave (Offset 7504) (Save)(4 Bytes)
// - m_autoKickDisabled (Offset 8588) (Save)(1 Bytes)
// - CBasePlayerPlayerDeathThink (Offset 0) (FunctionTable)(0 Bytes)
// - m_iDamageCount (Offset 6208) (Save)(4 Bytes)
// - m_CurrentWeaponProficiency (Offset 6212) (Save)(4 Bytes)
// - m_flLastEventCheck (Offset 1092) (Save)(4 Bytes)
// - m_bSequenceFinished (Offset 1160) (Save)(1 Bytes)
// - m_nSequence (Offset 1172) (Save|Key)(4 Bytes) - sequence
// - m_flCycle (Offset 1168) (Save|Key)(4 Bytes) - cycle
// - m_flCreateTime (Offset 152) (Save)(4 Bytes)
// - m_lifeState (Offset 260) (Save)(1 Bytes)
// - m_takedamage (Offset 261) (Save)(1 Bytes)
// - m_target (Offset 248) (Save|Key)(4 Bytes) - target
// - m_bIsInStasis (Offset 8) (Save)(1 Bytes)
// - m_spawnflags (Offset 328) (Save|Key)(4 Bytes) - spawnflags
// - m_fFlags (Offset 336) (Save)(4 Bytes)
// - InputKill (Offset 0) (Input)(0 Bytes) - Kill
// - InputSetDamageFilter (Offset 0) (Input)(0 Bytes) - SetDamageFilter

// native bool L4D2_IsReachable(int client, const float vecPos[3]); 
// native bool L4D2_NavAreaBuildPath(Address nav_startPos, Address nav_endPos, float flMaxPathLength, int teamID, bool ignoreNavBlockers); 

/// Compute distance between two areas
// native float L4D2_VScriptWrapper_NavAreaTravelDistance(float startPos[3], float endPos[3], float flMaxPathLength, bool checkLOS, bool checkGround); 

//// Returns a random client in game
//stock int GetRandomClient(int team = -1, int alive = -1, int bots = -1) 

int AllPlayerCount;

ConVar g_hCvarAllow, z_max_player_zombies;
bool g_bCvarAllow;
bool g_bSpawnWitchBride = false; // avoid crash

// Zombie Master Live Variables
bool zm_can_start = false;
int zm_client = -1;
bool zm_started = false;
int bank = 0; // bank is shared between all ZMs
float bank_add = 0.0; // in case very small numbers need to be tracked
float t_last_update = 0.0;
int g_iPlayersInSurvivorTeam = -1;
int max_SI = 16;
int max_unique_SI = 16;
int live_SI = 0;
int live_witches=0;
int max_witches = 0;
int live_commons = 0;
bool panic = false;
float t_last_panic = 0.0;
static float t_panic_overlap = 5.0; //consecutive panic within this window is considered the same one
int g_iEntities;
Menu ZM_menu = null;
bool zm_menu_IsOpen = false; // track if menu is open to update zm UI data
bool zm_allow_spawns = true; // in survival, prevent spawns until survivors have started timer
Handle zm_timer = null;
char ZM_hint[MAX_NAME_LENGTH]; 
bool zm_deleted = false; //track if ZM just deleted something, for checks in removal of entity

int entref_control = INVALID_ENT_REFERENCE; // track the last special infected ZM looked at
int entref_delete = INVALID_ENT_REFERENCE; // track the last zombie ZM looked at

int g_iGlowList[MAXENTITIES] = {-1, ...}; // track glow children of parent entities

#define SAFEROOM_UNKNOWN 	-2
#define SAFEROOM_NO	 -1
int g_iLockedDoor = SAFEROOM_UNKNOWN;
int g_iFirstFlags = -1;
float saferoom_cooldown = 5.0;
bool saferoom_locked = false;
float t_last_join = 0.0;

// enum for spawner state
#define SPAWNER_BLOCKED 0 // can never spawn infected here
#define SPAWNER_CONDITIONAL 1 // cannot spawn here temporarily because survivors can see or are too close
#define SPAWNER_ALLOWED 2 // can spawn infected here
static int color_blocked[4] = {255,0,0,128};
static int color_conditional[4] = {0,0,255,128};
static int color_allowed[4] = {0,255,0,128};

float zm_target_pos[3], zm_spawner_pos[3], zm_spawner_posNav[3]; // raw pointer + nearest center of valid nav area location where zm is pointing
Address zm_spawner_navArea;
int zm_spawner_navAttrFlags, zm_spawner_navSpawnAttrs, zm_spawner_state;
//int zm_spawner_navID;
float t_last_spawner_update;
//bool spawner_relocated = false; // track if found navarea is very distant from expected spawner position
int g_iLaser = 0;
int g_iHalo = 0;

ConVar g_hCvarMPGameMode;
char g_sCvarMPGameMode[32];

// Kick AFK ZM due to inactivity
float t_zm_activity = 0.0;
bool zm_kick_notify = false;
void update_t_zm_activity(float new_t = -1.0)
{
    zm_kick_notify = false;
    if (new_t<0.0) t_zm_activity = GetEngineTime();
    else t_zm_activity = new_t;
}

// Cooldowns and ZM anti-spam features
//int SIs_available = 0;
//int witches_available = 0;
//float cooldown_specials = 10.0; //cooldown time for SI and witch
//float cooldown_common = 0.01; // cooldown for zombie horde

// each SI: independent timers. do not allow ZM to spawn more than survivors/2 same SI

ConVar g_hBankRateBase, g_hBankRatePlayer, g_hBankInitial, g_hBankInitialPlayer, g_hStopInactivity, g_hMaxUniqueSI,
       g_hUpdateRate, g_hMaxCommons, g_hSpawnMinDistance, g_hBonusCarAlarm, g_hBonusFinaleStage, g_hPanicCost,
       g_hCostBoomer, g_hCostSpitter, g_hCostHunter, g_hCostSmoker, g_hCostJockey, g_hMaxWitches, g_hMaxSI,
       g_hCostCharger, g_hCostTank, g_hCostWitchStatic, g_hCostWitchMoving, g_hCostCommon, g_hLockSaferoom;

float g_fBankRateBase,g_fBankRatePlayer,g_fUpdateRate,g_fSpawnMinDistance,g_fStopInactivity;
int g_iBankInitial,g_iBankInitialPlayer,g_iMaxCommons, g_iPanicCost;

int costs_SI[9];
int live_SI_arr[9];
int g_iCostCommon, g_iCostWitchStatic, g_iCostWitchMoving, g_iBonusCarAlarm, g_iBonusFinaleStage, g_iMaxWitches, g_iMaxSI, g_iMaxUniqueSI;

bool g_bLockSaferoom;

int bank_track_numplayers = 0; //tracking if more bank should be added when more survivors appear
void set_bank_begin()
{
    
    if (g_iPlayersInSurvivorTeam<=0) CountAliveSurvivors();
    if (strcmp(g_sCvarMPGameMode, "survival", false) == 0)
    {
        bank = g_iBonusFinaleStage*g_iPlayersInSurvivorTeam;
    }
    else
    {
        bank = g_iBankInitial;
        bank += g_iBankInitialPlayer*g_iPlayersInSurvivorTeam;
    }
    bank_track_numplayers = g_iPlayersInSurvivorTeam;
    
    bank_add = 0.0;
}

// Zombie Master Info HUD
#define HUD4                          3
//char g_sData_HUD4_Text[128];
//char g_sCvar_HUD4_Text[128];
//char g_sHUD4_Text[128];
//RequestFrame(OnNextFrameHUDBackground, HUD4);
//GameRules_SetProp("m_iScriptedHUDFlags", HUD_FLAG_TEXT, _, HUD4);
//GameRules_SetPropFloat("m_fScriptedHUDPosX", 0.75, HUD4);
//GameRules_SetPropFloat("m_fScriptedHUDPosY", 0.35, HUD4);
//GameRules_SetPropFloat("m_fScriptedHUDWidth", 1.5, HUD4);
//GameRules_SetPropFloat("m_fScriptedHUDHeight", 0.026, HUD4);
//GameRules_SetPropString("m_szScriptedHUDStringSet", "test");

void refresh_zm_ui()
{
    if (IsValidClientZM())
    {
       PrintToChat(zm_client,ZM_hint);
       if (DEBUG) PrintToServer("[zm] refresh_zm_ui");
    }
}

void update_hint(char text[MAX_NAME_LENGTH])
{
    ZM_hint = text;
    refresh_zm_ui();
}

// ZM Pointer

void update_ZM_spawner(float target_pos[3], float spawner_pos[3], int state, bool draw=true)
{
    
    if (zm_spawner_state!=state || zm_target_pos[0]!=target_pos[0] || zm_target_pos[1]!=target_pos[1] || zm_target_pos[2]!=target_pos[2])
    {
      if (draw && IsValidClientZM() && g_iLaser>0 && g_iHalo>0)
      {
          int color[4];
          if (state==SPAWNER_BLOCKED) color = color_blocked;
          else if (state==SPAWNER_CONDITIONAL) color = color_conditional;
          else color = color_allowed;
          float draw_pos[3];
          draw_pos = spawner_pos;
          TE_SetupBeamRingPoint(draw_pos,20.0,30.0,g_iLaser,g_iHalo,0,0,g_fUpdateRate*2.0,2.0,0.0,color,0,0);
          TE_SendToClient(zm_client);
          draw_pos = spawner_pos; draw_pos[2] += 15.0;
          TE_SetupBeamRingPoint(draw_pos,20.0,30.0,g_iLaser,g_iHalo,0,0,g_fUpdateRate*2.0,2.0,0.0,color,0,0);
          TE_SendToClient(zm_client);
          draw_pos = spawner_pos; draw_pos[2] -= 15.0;
          TE_SetupBeamRingPoint(draw_pos,20.0,30.0,g_iLaser,g_iHalo,0,0,g_fUpdateRate*2.0,2.0,0.0,color,0,0);
          TE_SendToClient(zm_client);
          t_last_spawner_update = GetEngineTime();
      }
      
    }
    zm_target_pos = target_pos;
    zm_spawner_pos = spawner_pos;
    zm_spawner_state = state;
    
}

// Allow witches to be spawned in weird places
bool nav_can_spawn_zombies(int navAttributeFlags, int navSpawnAttributes, bool witch = false)
{
    if ( (navSpawnAttributes & NAV_SPAWN_OBSCURED) || (navSpawnAttributes & NAV_SPAWN_IGNORE_VISIBILITY)) return true; // always spawn
    if (!witch && (navAttributeFlags & NAV_BASE_OUTSIDE_WORLD)) return false;
    //if (!witch && (navSpawnAttributes & NAV_SPAWN_NO_MOBS) && (navSpawnAttributes & NAV_SPAWN_EMPTY)) return false; // this should be respected but makes zm frustrating on some maps // double distance by 2x
    if (navSpawnAttributes & NAV_SPAWN_PLAYER_START) return false;
    if (navSpawnAttributes & NAV_SPAWN_RESCUE_CLOSET) return false;
    if (!witch && (navSpawnAttributes & NAV_SPAWN_CHECKPOINT)) return false;
    if (!witch && (navSpawnAttributes & NAV_SPAWN_BATTLESTATION)) return false;
    if (navSpawnAttributes & NAV_SPAWN_RESCUE_CLOSET) return false;
    //if (navSpawnAttributes & NAV_SPAWN_RESCUE_VEHICLE) return false;
    return true;
}

// True to allow the current entity to be hit, otherwise false.
static bool FilterSpawner(int entity, int mask, int self)
{
	if (!IsValidEntity(entity)) return false;
	if (entity==self) return false;
	if (GetEntProp(entity,Prop_Data,"m_iHealth")>0) return false;
	static char class[32];
	GetEntityClassname(entity, class, sizeof(class));
	if (strcmp(class,"func_playerinfected_clip")==0) return false;
	if (strcmp(class,"func_clip_vphysics")==0) return false;
	if (strcmp(class,"func_playerghostinfected_clip")==0) return false;
	if (strcmp(class,"func_vehicleclip")==0) return false;
	if (strcmp(class,"script_clip_vphysics")==0) return false;
	if (strcmp(class,"env_physics_blocker")==0) return false;
	if (strcmp(class,"env_player_blocker")==0) return false;
	if (strcmp(class,"entity_blocker")==0) return false;
	return true;
}

bool can_any_alive_survivor_see(float vecPos[3], bool hint = true)
{
   
   if (DEBUG) PrintToServer("[zm] can_any_alive_survivor_see");
   
   int filter_client;
   if (IsValidClientZM()) filter_client = zm_client;
   else filter_client = 0;
   
   float VecPos2[3];
   AddVectors(vecPos,{0.0,0.0,35.0},VecPos2);
   
   float VecPos3[3];
   AddVectors(vecPos,{-25.0,0.0,35.0},VecPos3);
   
   float VecPos4[3];
   AddVectors(vecPos,{25.0,0.0,35.0},VecPos4);
   
   float VecPos5[3];
   AddVectors(vecPos,{0.0,-25.0,35.0},VecPos5);
   
   float VecPos6[3];
   AddVectors(vecPos,{0.0,25.0,35.0},VecPos6);
   
   // Check line of sight with saferoom door before spawning frozen infected
   if (!zm_started && IsValidEntRef(g_iLockedDoor))
   {
        float saferoom_pos[3];
        GetEntPropVector(g_iLockedDoor, Prop_Send, "m_vecOrigin", saferoom_pos);
        
        Handle trace = TR_TraceRayFilterEx(vecPos,saferoom_pos,MASK_VISIBLE,RayType_EndPoint,FilterSpawner,filter_client);
        if(TR_DidHit(trace))
        {
            int hit_entity = TR_GetEntityIndex(trace);
            if (hit_entity==g_iLockedDoor)
            {
               if (hint) update_hint("Visible to saferoom.");
               delete trace;
               return true;
            }
        }
        delete trace;
        
        trace = TR_TraceRayFilterEx(VecPos2,saferoom_pos,MASK_VISIBLE,RayType_EndPoint,FilterSpawner,filter_client);
        if(TR_DidHit(trace))
        {
            int hit_entity = TR_GetEntityIndex(trace);
            if (hit_entity==g_iLockedDoor)
            {
               if (hint) update_hint("Visible to saferoom.");
               delete trace;
               return true;
            }
        }
        delete trace;
        
        trace = TR_TraceRayFilterEx(VecPos3,saferoom_pos,MASK_VISIBLE,RayType_EndPoint,FilterSpawner,filter_client);
        if(TR_DidHit(trace))
        {
            int hit_entity = TR_GetEntityIndex(trace);
            if (hit_entity==g_iLockedDoor)
            {
               if (hint) update_hint("Visible to saferoom.");
               delete trace;
               return true;
            }
        }
        delete trace;
        
        trace = TR_TraceRayFilterEx(VecPos4,saferoom_pos,MASK_VISIBLE,RayType_EndPoint,FilterSpawner,filter_client);
        if(TR_DidHit(trace))
        {
            int hit_entity = TR_GetEntityIndex(trace);
            if (hit_entity==g_iLockedDoor)
            {
               if (hint) update_hint("Visible to saferoom.");
               delete trace;
               return true;
            }
        }
        delete trace;
        
        trace = TR_TraceRayFilterEx(VecPos5,saferoom_pos,MASK_VISIBLE,RayType_EndPoint,FilterSpawner,filter_client);
        if(TR_DidHit(trace))
        {
            int hit_entity = TR_GetEntityIndex(trace);
            if (hit_entity==g_iLockedDoor)
            {
               if (hint) update_hint("Visible to saferoom.");
               delete trace;
               return true;
            }
        }
        delete trace;
        
        trace = TR_TraceRayFilterEx(VecPos6,saferoom_pos,MASK_VISIBLE,RayType_EndPoint,FilterSpawner,filter_client);
        if(TR_DidHit(trace))
        {
            int hit_entity = TR_GetEntityIndex(trace);
            if (hit_entity==g_iLockedDoor)
            {
               if (hint) update_hint("Visible to saferoom.");
               delete trace;
               return true;
            }
        }
        delete trace;
        
   }
   
   // TBD: make this loop over known precalculated alive survivors rather than all players
   for( int i = 1; i <= MaxClients; i++ )
   {
      if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
      {
        
        if (L4D2_IsVisibleToPlayer(i,TEAM_SURVIVOR,3,0,vecPos))
        {
           if (hint) update_hint("Visible to survivors.");
           return true;
        }
        if (L4D2_IsVisibleToPlayer(i,TEAM_SURVIVOR,3,0,VecPos2))
        {
           if (hint) update_hint("Visible to survivors.");
           return true;
        }
        if (L4D2_IsVisibleToPlayer(i,TEAM_SURVIVOR,3,0,VecPos3))
        {
           if (hint) update_hint("Visible to survivors.");
           return true;
        }
        if (L4D2_IsVisibleToPlayer(i,TEAM_SURVIVOR,3,0,VecPos4))
        {
           if (hint) update_hint("Visible to survivors.");
           return true;
        }
        if (L4D2_IsVisibleToPlayer(i,TEAM_SURVIVOR,3,0,VecPos5))
        {
           if (hint) update_hint("Visible to survivors.");
           return true;
        }
        if (L4D2_IsVisibleToPlayer(i,TEAM_SURVIVOR,3,0,VecPos6))
        {
           if (hint) update_hint("Visible to survivors.");
           return true;
        }
      }
   }
   return false;
}

// Find smallest distance to survivor. Check both ways in case survivor is about to appear here.
float min_distance_to_survivors(float vecPos[3])
{
   if (DEBUG) PrintToServer("[zm] min_distance_to_survivors");
   float min_distance = -1.0;
   float survivor_origin[3];
   float temp_dist1;
   float temp_dist2;
   for( int i = 1; i <= MaxClients; i++ )
   {
      if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
      {
        GetClientAbsOrigin(i,survivor_origin);
        temp_dist1 = L4D2_NavAreaTravelDistance(vecPos,survivor_origin,true);
        if (temp_dist1>=0.0 && (min_distance<0.0 || temp_dist1<min_distance)) min_distance = temp_dist1;
        if (zm_started)
        {
            temp_dist2 = L4D2_NavAreaTravelDistance(survivor_origin,vecPos,true);
            if (temp_dist2>=0.0 && (min_distance<0.0 || temp_dist2<min_distance)) min_distance = temp_dist2;
        }
      }
   }
   
   return min_distance;

}

bool can_ZM_spawn(bool witch = false, bool hint = true)
{
	if (DEBUG) PrintToServer("[zm] can_ZM_spawn");
	if (!IsValidClientZM()) return false;
	
	float vAngles[3],vOrigin[3],vPos[3],vPos_spawner[3];
	GetClientAbsOrigin(zm_client,vPos);
	GetClientEyePosition(zm_client,vOrigin);
	GetClientEyeAngles(zm_client,vAngles);
	
    Handle trace = TR_TraceRayFilterEx(vOrigin,vAngles,MASK_VISIBLE,RayType_Infinite,FilterSpawner,zm_client);
    	
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(vPos,trace);
		//vPos[2] += 1.0;
		vPos_spawner = vPos;
		//int entity = TR_GetEntityIndex(trace);
	    //static char class[32];
    	//if (IsValidEntity(entity)) GetEntityClassname(entity, class, sizeof(class));
		//if (DEBUG) PrintToServer("Hit: %d %s", entity, class);
		
	}
	delete trace;
    
    if (TR_PointOutsideWorld(vPos))
    {
        if (hint) update_hint("Location outside world.");
        update_ZM_spawner(vPos,vPos_spawner,SPAWNER_BLOCKED,false);
        return false;
    }
    
    // bools: anyz los checkground
    float check_dist = 200.0;
    if (witch) check_dist = 10.0;
    zm_spawner_navArea = L4D_GetNearestNavArea(vPos,check_dist,true,true,true,TEAM_INFECTED);
    if (zm_spawner_navArea)
    {
        zm_spawner_navSpawnAttrs = L4D_GetNavArea_SpawnAttributes(zm_spawner_navArea);
        zm_spawner_navAttrFlags = L4D_GetNavArea_AttributeFlags(zm_spawner_navArea);
        float navSize[3], navOrigin[3];
        L4D_GetNavAreaCenter(zm_spawner_navArea, zm_spawner_posNav);
        L4D_GetNavAreaPos(zm_spawner_navArea, navOrigin);
        L4D_GetNavAreaSize(zm_spawner_navArea, navSize);
        float z_max = navOrigin[2];
        if (z_max<zm_spawner_posNav[2]) z_max =  zm_spawner_posNav[2];
        z_max += navSize[2];
        if (z_max<vPos[2]) z_max = vPos[2];
        // Check if fully within navarea xy. If not, grab a random position
        if ( FloatAbs(vPos[0]-zm_spawner_posNav[0])>(navSize[0]/2.0) || FloatAbs(vPos[1]-zm_spawner_posNav[1])>(navSize[1]/2.0) )
        {
            L4D_FindRandomSpot(zm_spawner_navArea,vPos_spawner);
        }
        else vPos_spawner[2] = z_max;
        
    }
    else
    {
        vPos_spawner = vPos;
        zm_spawner_navSpawnAttrs = 0;
        zm_spawner_navAttrFlags = 0;
        if (!witch)
        {
            if (hint) update_hint("Invalid location.");
            update_ZM_spawner(vPos,vPos_spawner,SPAWNER_BLOCKED);
            return false;
        }
    }
    
    if (!nav_can_spawn_zombies(zm_spawner_navAttrFlags,zm_spawner_navSpawnAttrs,witch))
    {
        if (hint)
        {
            if (witch) update_hint("Witches are illegal there.");
            else update_hint("Zombies are illegal there.");
        }
        update_ZM_spawner(vPos,vPos_spawner,SPAWNER_BLOCKED);
        return false;
    }
    
    // If obscured, we don't care about line of sight but should check distance.
    bool obscured = ( (zm_spawner_navSpawnAttrs & NAV_SPAWN_OBSCURED) || (zm_spawner_navSpawnAttrs & NAV_SPAWN_IGNORE_VISIBILITY));
    if (!obscured)
    {
        if (can_any_alive_survivor_see(vPos_spawner,hint))
        {
            update_ZM_spawner(vPos,vPos_spawner,SPAWNER_CONDITIONAL);
            return false;
        }
    }
    
    float min_distance = min_distance_to_survivors(vPos);
    if (min_distance>=0.0)
    {
        if (zm_spawner_navSpawnAttrs & NAV_SPAWN_NO_MOBS) min_distance /= 2.0; // 2x the usual survivor distance for areas marked "NO MOBS".
        else if (!zm_started) min_distance *= 2.0; // if not started, players won't get swarmed so easily by initial wave
        
        if (min_distance<g_fSpawnMinDistance)
        {
            if (hint) update_hint("Too close to survivors.");
            update_ZM_spawner(vPos,vPos_spawner,SPAWNER_CONDITIONAL);
            return false;
        }
    }
    
    if (!zm_allow_spawns)
	{
    	if (hint) update_hint("Zombie spawns disabled.");
    	update_ZM_spawner(vPos,vPos_spawner,SPAWNER_CONDITIONAL);
    	return false;
	}
    
    update_ZM_spawner(vPos,vPos_spawner,SPAWNER_ALLOWED);
    return true;
    
}

// For zm_client always use EntRefToEntIndex
// Should pass userid instead

stock bool IsValidEntRef(int entity)
{
	if( entity && entity != -1 && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
		
}

void check_saferoom()
{
   if (g_iLockedDoor==SAFEROOM_UNKNOWN)
   {
        if (DEBUG) PrintToServer("[zm] check_saferoom");
        if (DEBUG) PrintToServer("[zm] L4D_GetCheckpointFirst");
        g_iLockedDoor = L4D_GetCheckpointFirst();
        if (IsValidEntRef(g_iLockedDoor) && IsValidEntity(g_iLockedDoor))
        {
            if (DEBUG) PrintToServer("[zm] get m_spawnflags");
            g_iFirstFlags = GetEntProp(g_iLockedDoor, Prop_Send, "m_spawnflags");
        }
        else
        {
            if (DEBUG) PrintToServer("[zm] no saferoom, ignoring");
            g_iLockedDoor = SAFEROOM_NO;
            g_iFirstFlags = -1;
        }
     if (DEBUG) PrintToServer("[zm] check_saferoom done");
   }
   
   
}

void can_zm_start()
{
   if (DEBUG) PrintToServer("[zm] can_zm_start");
   if (!g_bLockSaferoom || zm_can_start) // Option 2: do not re-lock saferoom after first "round can start" announcement
   //if (!g_bLockSaferoom) // Option 1: allow saferoom to be relocked
   {
       zm_can_start = true;
       if (saferoom_locked)
       {
           saferoom_lock(false);
       }
       return;
   }
   
   zm_can_start = false;
   if (!zm_allow_spawns) return;
   check_saferoom();
   
   if (zm_started)
   {
      if (saferoom_locked) saferoom_lock(false);
      return;
   }
   
   // Survival: check if timer started
   
   if ( zm_client>0 && (GetEngineTime()-t_last_join)>saferoom_cooldown )
      zm_can_start = true;
      
   if (zm_can_start)
   {
       if (saferoom_locked)
       {
           saferoom_lock(false);
           PrintToChatAll("[zm] Survivors can leave the safe zone!");
           if (!zm_started) EmitSoundToAll(SOUND_READY);
       }
   }
   else if (g_bLockSaferoom && !saferoom_locked)
   {
      saferoom_lock(true);
   }
 
   
}

void freeze_player(int client, bool state = true, int team = TEAM_SURVIVOR)
{
    if(IsValidEntRef(client) && IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client)==team && client!=zm_client)
    {   
        if (state && !zm_started)
        {
            if (team == TEAM_SURVIVOR) SetEntProp(client, Prop_Data, "m_takedamage", 0);
    		SetEntityMoveType(client, MOVETYPE_NONE);
    		if (team == TEAM_INFECTED) 
    		{
        		SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags")|FL_FROZEN);
        		//BlockPlayerRangeCull(client); // prevent suicide
    		}
    		if (team == TEAM_SURVIVOR) TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
    		
		}
		else
		{
    		SetEntityMoveType(client, MOVETYPE_WALK);
    		if (team == TEAM_INFECTED)
    		{
        		SetEntProp(client, Prop_Send, "m_fFlags", (GetEntProp(client, Prop_Send, "m_fFlags")&~FL_FROZEN));
        		//int ticktime = RoundToNearest(GetGameTime()/GetTickInterval()) + 5;
            	//SetEntProp(client, Prop_Data, "m_nNextThinkTick", ticktime);
    		}
            if (team == TEAM_SURVIVOR) SetEntProp(client,Prop_Data,"m_takedamage",2);
		}
    }
}

// Call this if you want to freeze silently (for periodic refreezing)
void freeze_team(bool state = true, int team = TEAM_SURVIVOR)
{
    if (DEBUG) PrintToServer("[zm] freeze_team");
    //check_saferoom();
    for (int i=1;i<=MaxClients;i++)
    {
        freeze_player(i,state,team);
    }
    if (DEBUG)
    {
        if (state) PrintToServer("[zm] Froze team %d", team);
        else PrintToServer("[zm] Unfroze team %d", team);
    }
    if (team==TEAM_SURVIVOR && g_iLockedDoor<0) saferoom_locked=state;
    
}

void saferoom_lock(bool state)
{
    if (DEBUG) PrintToServer("[zm] saferoom_lock");
    check_saferoom();
    
    if ( g_iLockedDoor<=0 || !IsValidEntRef(g_iLockedDoor) )
    {
        
        if (state && !zm_started && g_bLockSaferoom)
        {
            if (DEBUG) PrintToServer("[zm] Can't lock - Freezing survivors");
            freeze_team(true);
        }
        else
        {
            if (DEBUG) PrintToServer("[zm] Can't unlock - Unfreezing survivors");
            freeze_team(false);
        }
        
        
        return;
    }
    
    //int door_state = GetEntProp(g_iLockedDoor,Prop_Send,"m_eDoorState");
    //int blocked = GetEntProp(g_iLockedDoor, Prop_Data, "m_bLocked");
    //int hasSequence = GetEntProp(g_iLockedDoor, Prop_Data, "m_hasUnlockSequence");
    //PrintToServer("[zm] Saferoom state before: %d %d %d", door_state, blocked, hasSequence);
    
    if (state && !zm_started && g_bLockSaferoom)
    {
        //SetEntProp(g_iLockedDoor,Prop_Send,"m_bLocked",1);
        //AcceptEntityInput(g_iLockedDoor, "Close");
        AcceptEntityInput(g_iLockedDoor, "forceclosed");
        //AcceptEntityInput(g_iLockedDoor, "Lock");
        //SetEntProp(g_iLockedDoor, Prop_Send, "m_eDoorState", DOOR_STATE_CLOSING_IN_PROGRESS);
        SetEntProp(g_iLockedDoor, Prop_Send, "m_spawnflags", g_iFirstFlags|DOOR_FLAG_IGNORE_USE);
        saferoom_glow(true);
        saferoom_locked=true;
        if (DEBUG) PrintToServer("[zm] Locked saferoom");
    }
    else
    {
        SetEntProp(g_iLockedDoor,Prop_Send,"m_bLocked",0);
        AcceptEntityInput(g_iLockedDoor, "Unlock");
        SetEntProp(g_iLockedDoor, Prop_Send, "m_spawnflags", g_iFirstFlags&~DOOR_FLAG_IGNORE_USE);
        //if (GetEntProp(g_iLockedDoor,Prop_Send,"m_eDoorState")!=DOOR_STATE_OPENING_IN_PROGRESS) SetEntProp(g_iLockedDoor,Prop_Send,"m_eDoorState",DOOR_STATE_CLOSED);
        saferoom_glow(false);
        saferoom_locked=false;
        freeze_team(false);
        if (DEBUG) PrintToServer("[zm] Unlocked saferoom");
    }
    
    //door_state = GetEntProp(g_iLockedDoor,Prop_Send,"m_eDoorState");
    //blocked = GetEntProp(g_iLockedDoor, Prop_Data, "m_bLocked");
    //hasSequence = GetEntProp(g_iLockedDoor, Prop_Data, "m_hasUnlockSequence");
    //PrintToServer("[zm] Saferoom state after: %d %d %d", door_state, blocked, hasSequence);
    
}

void saferoom_glow(bool state=true)
{
   if (DEBUG) PrintToServer("[zm] saferoom_glow");
   check_saferoom();
   if (!IsValidEntRef(g_iLockedDoor) ) return;
   
   if (state && !zm_started && g_bLockSaferoom)
   {
       SetEntProp(g_iLockedDoor, Prop_Send, "m_iGlowType", 3);
       SetEntProp(g_iLockedDoor, Prop_Send, "m_glowColorOverride", 254); //red
       SetEntProp(g_iLockedDoor, Prop_Send, "m_nGlowRange", 1000);
   }
   else
   {
       SetEntProp(g_iLockedDoor, Prop_Send, "m_glowColorOverride", 0);
       AcceptEntityInput(g_iLockedDoor, "StopGlowing");
   }
   
}

stock int GetEntityCountEx()
{
	if (DEBUG) PrintToServer("[zm] GetEntityCountEx");
	int ent;
	int cnt;
	for(ent = 0; ent < MAXENTITIES; ent++)
	{
		if( IsValidEntity(ent) || IsValidEdict(ent) )
		{
			cnt++;
		}
	}
	return cnt;
}


bool ZM_finale_announced = false;
bool ZM_finale_ended = false;

public Action L4D2_OnSendInRescueVehicle()
{
if (ZM_finale_announced) ZM_finale_ended = true;
else PrintToServer("[zm] Rescue vehicle sent before Finale start. WHAT THE ACTUAL FUCK");
}

// Check if player is a valid actual player on the server
bool IsValidClientZM(int client=-1)
{
    int check_client = client;
    if (client<0) check_client = zm_client;
    if (check_client>0 && IsClientInGame(check_client) && !IsFakeClient(check_client) && !IsClientSourceTV(check_client) && !IsClientReplay(check_client))
       return true;
    return false;
}

void announce_finale()
{
    if (DEBUG) PrintToServer("[zm] announce_finale");
    if (!ZM_finale_announced)
    {
        if (IsValidClientZM()) PrintHintText(zm_client, "The Finale has started. Use up your bank to advance the stage.");
        PrintToChatAll("[zm] The Finale has started. Stages will advance when the ZM runs out of resources.");
        ZM_finale_announced=true;
        if (panic) toggle_panic(false,true);
        //CountAliveSurvivors();
        //bank += g_iBonusFinaleStage*g_iPlayersInSurvivorTeam;
    }
    else if (ZM_finale_ended)
    {
        PrintToServer("[zm] Finale just announced but it's already ended. lol");
    }
    if (panic) toggle_panic(false,true);
    ZM_finale_announced = true;
}

void evtFinaleStart(Event event, const char[] name, bool dontBroadcast)
{
    announce_finale();
}


// If calling with default parameters: switch whatever it is now.
// If calling with overwrite, force panic mode to be what is desired.

// Full credit to Dragokas
// Check how chase works if not updated by spawning zombies behind survivors and see if they catch up correctly
void Chase(int target)
{
	if (DEBUG) PrintToServer("[zm] Chase");
	
	if (ZM_finale_announced || strcmp(g_sCvarMPGameMode, "survival", false) == 0 )
	{
    	if (DEBUG) PrintToServer("[zm] Infected chase is already set, ignoring.");
    	return;
	}
	
	if (!IsClientInGame(target)) return;
	bool bTeleported;
	float vPos[3];
	static int iChase = INVALID_ENT_REFERENCE;
	
	GetClientEyePosition(target, vPos);
	if (TR_PointOutsideWorld(vPos)) return;
	
	int entity = EntRefToEntIndex(iChase);
	if( !entity || entity == INVALID_ENT_REFERENCE || !IsValidEntity(entity) )
	{
		entity = FindEntityByClassname(MaxClients + 1, "info_goal_infected_chase");
		if( !entity || entity == INVALID_ENT_REFERENCE )
		{
		    if (DEBUG) PrintToServer("[zm] New Chase created");
			entity = CreateEntityByName("info_goal_infected_chase");
			if( entity != -1 )
			{
				TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
				DispatchSpawn(entity);
				iChase = EntIndexToEntRef(entity);
				bTeleported = true;
			}
		}
	}
	if( entity != -1 )
	{
		if( !bTeleported)
		{
			AcceptEntityInput(entity, "Disable");
			AcceptEntityInput(entity, "ClearParent");
			TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		}
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", target);
		AcceptEntityInput(entity, "Enable");
		if (DEBUG) PrintToServer("[zm] Chase enabled");
		
		char char1[MAX_NAME_LENGTH] = "Chasing: "; 
		char name[MAX_NAME_LENGTH];
        GetClientName(target,name,sizeof(name));
        char char_full[MAX_NAME_LENGTH]; 
        FormatEx(char_full,sizeof(char_full),"%s %s",char1,name);
        if (DEBUG) PrintToServer(char_full);
		if (IsValidClientZM()) update_hint(char_full);
	}
}

int panic_target = -1;
bool manual_panic = false; // track whether panic was started by game or by ZM
// look for incapped
void toggle_panic(bool state = true, bool overwrite = false, bool free = false)
{
    if (strcmp(g_sCvarMPGameMode, "survival", false)==0)
    {
        update_hint("Panic is automatic in Survival.");
        return;
    }
    else if (ZM_finale_announced)
    {
        update_hint("Panic is automatic in Finales.");
        return;
    }
    
    if (DEBUG) PrintToServer("[zm] toggle_panic");
    bool actual_state;
    //SetPendingMobCount(0);
    if (overwrite) actual_state = state;
    else
    {
        bool current = panic;
        actual_state = !current;
    }
    
    if ( zm_started && actual_state )
    {
       
       if (!free)
       {
           if ((bank-g_iPanicCost)<0)
           {
              update_hint("Panic don't come cheap.");
              return;
           }
           bank -= g_iPanicCost;
       }
       else
       {
           if (DEBUG) PrintToServer("[zm] Free panic");
       }
       
       PrintToServer("[zm] Panic ON");
       int target = L4D_GetHighestFlowSurvivor();
       if (zm_started && !panic && IsValidClientZM() && manual_panic) EmitSoundToClient(zm_client,SOUND_PANIC_ON);
       panic = true;
       t_last_panic = GetEngineTime();
       if (manual_panic)
       {
           PrintToServer("[zm] Manual panic");
           L4D_ForcePanicEvent();
           if (IsValidClient(target))
           {
               Chase(target);
               panic_target = target;
           }
           else
           {
               panic_target = -1;
           }
       }
       update_hint("Panic ON. Bank rate reduced.");
       actual_state = true;
       // Trying to prevent director respawns
       //SetConVarInt(FindConVar("z_common_limit"), 0);
       //SetConVarInt(FindConVar("z_background_limit"), 0);
    }
    else
    {
        PrintToServer("[zm] Panic OFF");
        manual_panic = false;
        update_hint("Panic OFF. Bank rate normal.");
        actual_state = false;
        int chase_ent = FindEntityByClassname(MaxClients + 1, "info_goal_infected_chase");
        if (chase_ent && chase_ent != INVALID_ENT_REFERENCE)
        {
            if (DEBUG) PrintToServer("[zm] Chase found, disabled");
 			AcceptEntityInput(chase_ent, "Disable");
 			AcceptEntityInput(chase_ent, "ClearParent");
 			//TeleportEntity(chase_ent, vPos, NULL_VECTOR, NULL_VECTOR);
        }
        if (zm_started && panic && IsValidClientZM()) EmitSoundToClient(zm_client,SOUND_PANIC_OFF);
        panic = false;
    }
    
    if (panic && live_commons>=10) SetConVarInt(FindConVar("director_panic_forever"), 1);
    else SetConVarInt(FindConVar("director_panic_forever"), 0);
    zm_update(zm_timer);
    
}

float get_bank_rate()
{
 if (L4D_IsFinaleActive() || ZM_finale_announced || strcmp(g_sCvarMPGameMode, "survival", false) == 0 )
 {
    if (!ZM_finale_announced && L4D_IsFinaleActive())
    {
        announce_finale();
    }
    else if (ZM_finale_announced && bank<=100 && !ZM_finale_ended && live_SI_arr[ZOMBIECLASS_TANK]<=0)
    {
       if (IsValidClientZM()) PrintHintText(zm_client, "Finale has advanced.");
       L4D2_ForceNextStage();
       CountAliveSurvivors();
       bank += g_iBonusFinaleStage*g_iPlayersInSurvivorTeam;
    }
    return 0.0;
 }
 float final_rate = g_fBankRateBase;
 if (g_iPlayersInSurvivorTeam>0) final_rate += g_iPlayersInSurvivorTeam*g_fBankRatePlayer;
    
 if (panic) final_rate /= 10.0;
 return final_rate;
}

// Round start hook actually runs first and only then mapstart!!! WHAT THE FUCK VALVE
void zm_new_round()
{
    if (!g_bCvarAllow) return;
    
	//if(!L4D_HasPlayerControlledZombies())
	//{
	//	for( int i = 1; i <= MaxClients; i++ )
	//	{
	//		if(IsClientInGame(i) && !IsFakeClient(i)) FindConVar("mp_gamemode").ReplicateToClient(i,"versus");
	//	}
	//}
	
    
    SetConVarInt(FindConVar("z_discard_min_range"), 9999999);
    SetConVarInt(FindConVar("z_discard_range"), 9999999);
    SetConVarInt(FindConVar("z_no_cull"), 1);
    
    if (DEBUG) PrintToServer("[zm] zm_new_round");
    if (DEBUG) PrintToServer("[zm] Gamemode: %s", g_sCvarMPGameMode);
    
    //int flags = GetCommandFlags("mat_postprocess_enable");
    //SetCommandFlags("mat_postprocess_enable", flags & ~FCVAR_CHEAT);
    
    if(strcmp(g_sCvarMPGameMode, "survival", false) == 0)
    {
        zm_allow_spawns = false;
        g_iLockedDoor = SAFEROOM_NO;
    }
    else
    {
        zm_allow_spawns = true;
        check_saferoom();
    }
    
    manual_panic = false;
    delete_all_infected();
    SetConVarInt(FindConVar("z_common_limit"), 0);

    
    
    
    ZM_finale_announced = false;
    ZM_finale_ended = false;
    zm_can_start = !g_bLockSaferoom;
    zm_started = false;
    t_last_update = GetEngineTime();
    t_last_panic = t_last_update;
    t_last_spawner_update = t_last_update;
    update_t_zm_activity(t_last_update);
    g_iPlayersInSurvivorTeam = -1;
    
    if (IsValidClientZM()) QuitZM(zm_client,0);
    
    UpdateLiveSI(false);
    CountAliveSurvivors(); // will always run zm_update here
    CountWitches(false);
    CountCommons(false);
    
    
    
    set_bank_begin();
    
    toggle_panic(false,true);
    
    //SIs_available = max_SI;
    //witches_available = g_iPlayersInSurvivorTeam - 1;
    
    if (zm_timer==null) zm_update(zm_timer);
    // Move zm to survivors
    // Pick new zm
    
    //if (g_bLockSaferoom && !saferoom_locked) saferoom_lock(true);
    
    zm_deleted = false;
    entref_control = INVALID_ENT_REFERENCE;
    entref_delete = INVALID_ENT_REFERENCE;
    
    
    
}

// TBD: use this for survivor + SI count
//stock GetClientCountEx(bool:inGameOnly, bool:filterBots)
//{
//    new clients = 0;
//    FOR_EACH_CLIENT_CONNECTED(client)
//    {
//        if (inGameOnly && !IsClientInGame(client)) continue;
//        if (filterBots && IsFakeClient(client)) continue;
//        clients++;
//    }
//    return clients;
//}

// Might as well run this at the same time as count player survivors...
void UpdateLiveSI(bool fast = true)
{
	if (live_SI<=0 && fast) return;
	if (DEBUG) PrintToServer("[zm] UpdateLiveSI expensive");
	int temp_SI = 0;
	AllPlayerCount = 0;
	int zClass;
	
	int length = sizeof(live_SI_arr);//live_SI_arr.Length;
    for(int i = 0; i < length; i++)
	{
		live_SI_arr[i] = 0;
	}
	
	for (int i=1;i<=MaxClients;i++)
	{
		if(IsClientConnected(i))
		{
			AllPlayerCount++;
		}
		if (!IsClientInGame(i)) continue;
		if (GetClientTeam(i)==TEAM_INFECTED && IsPlayerAlive(i))
		{
		   temp_SI += 1;
		   zClass = GetEntProp(i, Prop_Send, "m_zombieClass");
		   live_SI_arr[zClass] += 1;
		}
	}
	if (live_SI!=temp_SI)
	{
	   live_SI = temp_SI;
	   if (zm_started || zm_timer==null) zm_update(zm_timer);
	   return;
	}
}


void create_ZM_menu()
{		
	if (DEBUG) PrintToServer("[zm] create_ZM_menu");
	zm_menu_IsOpen = false;
	ZM_menu = new Menu(ZM_MenuHandler);
	//ZM_menu = CreateMenuEx(GetMenuStyleHandle(MenuStyle_Radio),ZM_MenuHandler);
	//ZM_menu = new Menu(ZM_MenuHandler,MenuStyle_Radio);
	ZM_menu.SetTitle("Zombie Master");
	//ZM_menu.SetTitle("ZM Resources: (%d %d/%d)", bank, live_SI, max_SI); 
    //ZM_menu.SetTitle("%d %d/%d %d/%d", bank, live_commons, g_iMaxCommons, live_SI, max_SI);
    //DisplayMenuAtItem(ZM_menu,client,current_item,MENU_TIME_FOREVER)
    
    char char1[32]; 
    char char2[32];
    char buffer[32]; 
    
    char1 = "Common"; 
    IntToString(g_iCostCommon,char2,sizeof(char2));
    FormatEx(buffer,sizeof(buffer),"%s %s",char1,char2);
	ZM_menu.AddItem("0", buffer);
	
	char1 = "Boomer"; 
    IntToString(costs_SI[ZOMBIECLASS_BOOMER],char2,sizeof(char2));
    FormatEx(buffer,sizeof(buffer),"%s %s",char1,char2);
	ZM_menu.AddItem("1", buffer);
	
	char1 = "Spitter"; 
    IntToString(costs_SI[ZOMBIECLASS_SPITTER],char2,sizeof(char2));
    FormatEx(buffer,sizeof(buffer),"%s %s",char1,char2);
	ZM_menu.AddItem("2", buffer);
	
	char1 = "Smoker"; 
    IntToString(costs_SI[ZOMBIECLASS_SMOKER],char2,sizeof(char2));
    FormatEx(buffer,sizeof(buffer),"%s %s",char1,char2);
	ZM_menu.AddItem("3", buffer);
	
	char1 = "Hunter"; 
    IntToString(costs_SI[ZOMBIECLASS_HUNTER],char2,sizeof(char2));
    FormatEx(buffer,sizeof(buffer),"%s %s",char1,char2);
	ZM_menu.AddItem("4", buffer);
	
	char1 = "Jockey"; 
    IntToString(costs_SI[ZOMBIECLASS_JOCKEY],char2,sizeof(char2));
    FormatEx(buffer,sizeof(buffer),"%s %s",char1,char2);
	ZM_menu.AddItem("5", buffer);
	
	char1 = "Charger"; 
    IntToString(costs_SI[ZOMBIECLASS_CHARGER],char2,sizeof(char2));
    FormatEx(buffer,sizeof(buffer),"%s %s",char1,char2);
	ZM_menu.AddItem("6", buffer);
	
	char1 = "Witch Static"; 
    IntToString(g_iCostWitchStatic,char2,sizeof(char2));
    FormatEx(buffer,sizeof(buffer),"%s %s",char1,char2);
	ZM_menu.AddItem("7", buffer);
	
	char1 = "Witch Moving"; 
    IntToString(g_iCostWitchStatic,char2,sizeof(char2));
    FormatEx(buffer,sizeof(buffer),"%s %s",char1,char2);
	ZM_menu.AddItem("8", buffer);
	
	char1 = "Tank"; 
    IntToString(costs_SI[ZOMBIECLASS_TANK],char2,sizeof(char2));
    FormatEx(buffer,sizeof(buffer),"%s %s",char1,char2);
	ZM_menu.AddItem("9", buffer);
	
	char1 = "PANIC"; 
    IntToString(g_iPanicCost,char2,sizeof(char2));
    FormatEx(buffer,sizeof(buffer),"%s %s",char1,char2);
	ZM_menu.AddItem("10", buffer);
	
	ZM_menu.AddItem("11", "TP To Survivors");
	ZM_menu.AddItem("12", "Control Special");
	ZM_menu.AddItem("13", "Delete Target");
	ZM_menu.AddItem("14", "Delete Commons");
	ZM_menu.AddItem("15", "Delete Specials");
	ZM_menu.AddItem("16", "Delete Witches");
	ZM_menu.AddItem("17", "Delete All");
	ZM_menu.AddItem("18", "Force Start");
	ZM_menu.AddItem("19", "Toggle Fog");
	ZM_menu.AddItem("20", "Toggle Rain");
	ZM_menu.AddItem("21", "Toggle Snow");
	ZM_menu.AddItem("22", "Toggle Vision");
	ZM_menu.AddItem("23", "Give Up");

	
	//ZM_menu.AddItem("2", "Witch (Moving)");

	ZM_menu.ExitBackButton = false;
	ZM_menu.ExitButton = true;
	SetMenuOptionFlags(ZM_menu,MENUFLAG_NO_SOUND);
	//ZM_menu.SetFlags(MenuStyle_Radio);
    if (IsValidClientZM() && zm_menu_IsOpen)
    {
	   //zm_menu_IsOpen = true;
	   ZM_menu.Display(zm_client,MENU_TIME_FOREVER);
	}
	return;
}

int ZM_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    
    if (!IsValidClientZM())
    {
        if (ZM_menu!=null) ZM_menu.Cancel();
        if (DEBUG) PrintToServer("[zm] Invalid ZM client, cancelling menu");
        zm_menu_IsOpen = false;
        return 0;
    }
    
    //DisplayMenuAtItem(ZM_menu,client,current_item,MENU_TIME_FOREVER)
    
    switch(action) 
    {
        case MenuAction_Select:
        {
        	
        	if (param1!=zm_client) return 0;
        	update_t_zm_activity();
        	//PrintHintText(zm_client, "Zombie spawns before round start are disabled."); //PLACEHOLDER
            	if (param2==0) ZM_Horde(zm_client,10);
        	    else if (param2==1) ZM_Boomer(zm_client,0); 
                else if (param2==2) ZM_Spitter(zm_client,0); 
    	        else if (param2==3) ZM_Smoker(zm_client,0); 
                else if (param2==4) ZM_Hunter(zm_client,0); 
                else if (param2==5) ZM_Jockey(zm_client,0); 
                else if (param2==6) ZM_Charger(zm_client,0); 
                else if (param2==7) ZM_Witch(zm_client,WITCH_STATIC);
                else if (param2==8) ZM_Witch(zm_client,WITCH_MOVING);
                else if (param2==9) ZM_Tank(zm_client,0); 
                else if (param2==10) ZMPanic(zm_client,0);
                else if (param2==11) ZMTeleport(zm_client,0); 
                else if (param2==12) ZMControlSI(zm_client,0); 
                else if (param2==13) ZM_Delete(zm_client,0);
                else if (param2==14) ZM_Delete_Commons(zm_client,0);
                else if (param2==15) ZM_Delete_Specials(zm_client,0);
                else if (param2==16) ZM_Delete_Witches(zm_client,0);
                else if (param2==17) ZM_Delete_All(zm_client,0);
                else if (param2==18) zm_unlock(zm_client,0);
                else if (param2==19) ZM_Fog_Toggle(zm_client); 
                else if (param2==20) ZM_Rain_Toggle(zm_client); 
                else if (param2==21) ZM_Snow_Toggle(zm_client); 
                else if (param2==22) ZM_Vision(zm_client,0); 
                else if (param2==23) QuitZM(zm_client,0);
            
                
            // toggle_panic(bool state = true, bool overwrite = false)
            
            //PrintToServer("[zm] zm menu MenuAction_Select %d %d", param1, param2);
            if (IsValidClientZM()) ZM_menu.Display(zm_client,MENU_TIME_FOREVER);
            zm_menu_IsOpen=true;
            
        }
        case MenuAction_Cancel:
        {
           if (param1==zm_client && param2==MenuCancel_Exit)
           {
              zm_menu_IsOpen=false;
              //PrintToServer("[zm] Closed zm menu");
              return 0;
           }
        }
    }

	return 0;
}



Action ZMPanic(int client, int args)
{
    if (!g_bCvarAllow || !IsValidClientZM() || zm_client!=client) return Plugin_Continue;
    if (!panic) manual_panic = true;
    toggle_panic();
    return Plugin_Continue;
}

Action ZMTeleport(int client, int args)
{
    if (!g_bCvarAllow || !IsValidClientZM() || zm_client!=client) return Plugin_Continue;
    int target = L4D_GetHighestFlowSurvivor();
    if (IsValidClient(target) && IsPlayerAlive(target))
    {
        float vTP[3];
        GetEntPropVector(target, Prop_Send, "m_vecOrigin", vTP);
        //SetEntPropVector(zm_client, Prop_Send, "m_vecOrigin", vTP);
        TeleportEntity(zm_client, vTP, NULL_VECTOR, NULL_VECTOR);
    }

    return Plugin_Continue;
}

Action ZMControlSI(int client, int args)
{
    if (!g_bCvarAllow || !IsValidClientZM() || zm_client!=client) return Plugin_Continue;
    
    if (!zm_started)
    {
        update_hint("Round has not started.");
        return Plugin_Continue;
    }
    
    update_ZM_looktarget();
    if (!IsValidEntRef(entref_control))
    {
        update_hint("Invalid target.");
        return Plugin_Continue;
    }
    int entity = EntRefToEntIndex(entref_control);
    if (!IsValidEntity(entity) || !IsValidClient(entity) || GetClientTeam(entity)!=TEAM_INFECTED || !IsFakeClient(entity)) 
    {
        update_hint("Invalid target.");
        return Plugin_Continue;
    }
    
    if (entity && IsValidEntity(entity) && entity!=client)
    {
         static char class[32];
  	     GetEntityClassname(entity, class, sizeof(class));
  	     if ( (strcmp(class,"player")==0 && GetClientTeam(entity)==TEAM_INFECTED) && IsFakeClient(entity) )
  	     {
             float vOrigin[3], vAngles[3], vVelocity[3];
             GetClientAbsOrigin(entity, vOrigin);
             if (TR_PointOutsideWorld(vOrigin)) return Plugin_Continue;
             GetClientEyeAngles(entity, vAngles); 
             GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vVelocity);
             int health = GetEntProp(entity,Prop_Data,"m_iHealth");
             if (health<=0) return Plugin_Continue;
             //int fFlags = GetEntProp(entity, Prop_Data, "m_fFlags");
             int zClass = GetEntProp(entity, Prop_Send, "m_zombieClass");
             SetEntProp(entity,Prop_Data,"m_iHealth",health-1); //prevent refund
             RemoveEntity(entity);
             
             L4D_State_Transition(zm_client, STATE_OBSERVER_MODE);
             L4D_SetPlayerSpawnTime(zm_client,1.0,true);
             L4D_BecomeGhost(zm_client);
             L4D_SetClass(zm_client, zClass);
             //TeleportEntity(zm_client, vOrigin, NULL_VECTOR, NULL_VECTOR);
             //L4D_MaterializeFromGhost(zm_client);
             //TeleportEntity(zm_client, vOrigin, vAngles, vVelocity);	
	         //L4D_CleanupPlayerState(zm_client);
	         //SetEntProp(zm_client,Prop_Data,"m_iHealth",health);
	         //SetEntProp(zm_client,Prop_Data,"m_fFlags",fFlags);
  	     }
  	     else update_hint("Only special infected can be controlled.");
  	     
    } else update_hint("No entity there.");
    return Plugin_Continue;
}

public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStasis)
{
	if(L4D_HasPlayerControlledZombies() == false && tank_index && IsClientInGame(tank_index) && IsFakeClient(tank_index))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

Action ZM_Chase_ZM(int client, int args)
{
    if (!g_bCvarAllow || !IsValidClientZM()  || zm_client!=client) return Plugin_Continue;
    if (panic) Chase(zm_client);
    else update_hint("Panic must be ON.");
    return Plugin_Continue;
}

void CountCommons(bool fast = true)
{
    if (live_commons>0 || !fast || panic)
    {
        if (DEBUG) PrintToServer("[zm] CountCommons expensive");
        live_commons = L4D_GetCommonsCount();
    }
}

void start_zm_round(bool play_sound = true)
{
 if (!zm_started)
 {
     PrintToChatAll("[zm] Round has started!");
     if (IsValidClientZM()) PrintHintText(zm_client, "Round has started!");
     if (play_sound) EmitSoundToAll(SOUND_START);
 }
 zm_allow_spawns = true;
 zm_started = true;
 update_t_zm_activity();
 check_saferoom();
 saferoom_lock(false);
 freeze_team(false);
 freeze_team(false,TEAM_INFECTED);
 saferoom_locked = false;
 if (IsValidEntRef(g_iLockedDoor)) AcceptEntityInput(g_iLockedDoor, "Open");
}

void update_ZM_looktarget()
{
   if (!IsValidClientZM()) return;
   int target = GetClientAimTarget(zm_client, false);
   if (target<=0) return;
   if (target <= MaxClients && !IsFakeClient(target)) return;
   if (target && IsValidEntity(target) && target!=zm_client)
   {
         static char class[32];
 	     GetEntityClassname(target, class, sizeof(class));
 	     if ( strcmp(class,"infected")==0 || strcmp(class,"witch")==0 || (strcmp(class,"player")==0 && GetClientTeam(target)==TEAM_INFECTED) )
 	     {
       	     entref_delete = EntIndexToEntRef(target);
       	     if (strcmp(class,"player")==0 && GetClientTeam(target)==TEAM_INFECTED) entref_control = entref_delete;
 	     }
   }
}

Action zm_update(Handle Timer)
{
   
   if (DEBUG) PrintToServer("[zm] zm_update"); 
   
   if (!g_bCvarAllow)
   {
      delete zm_timer;
      return Plugin_Continue;
   }
   //SetPendingMobCount(0);
   float t_now = GetEngineTime();
   if (zm_started)
   {
      float dt = t_now - t_last_update;
      if (dt>0.0)
      {
         bank_add += dt*get_bank_rate();
         if (bank_add>=1.0)
         {
             int add_int = RoundFloat(bank_add);
             bank += add_int;
             bank_add -= add_int;
         }
         //if (bank<0) bank=0;
      }
   }
   else
   {
      if (!zm_can_start) can_zm_start();
      if (L4D_HasAnySurvivorLeftSafeArea() && IsValidClientZM() && zm_can_start)
      {
         start_zm_round();
      }
      else
      {
         if ((strcmp(g_sCvarMPGameMode, "survival", false) != 0) && g_bLockSaferoom && !IsValidEntRef(g_iLockedDoor) && !zm_can_start && L4D_IsInIntro()>0)
            freeze_team(true); // otherwise one player can move after intro cutscene
          
         //if (live_SI>0) freeze_team(true,TEAM_INFECTED); // prevents suicide
      }
      
      //set_bank_begin();
   
   }
   
   t_last_update = t_now;
   
   // Check if witches were spotted to prevent refunds.
   if (live_witches>0)
   {
       
       float witch_pos[3];
       int entity = -1;
       int counted_witches = 0;
       while ( ((entity = FindEntityByClassname(entity, "witch")) != -1) )
       {
       	 if (IsValidEntity(entity))
       	 {
       	     counted_witches += 1;
       	     if (!zm_started) continue;
       	    
       	     
           	 int max_health = GetEntProp(entity,Prop_Data,"m_iMaxHealth");
              int health = GetEntProp(entity,Prop_Data,"m_iHealth");
              if (health>=max_health)
              {
                  GetEntPropVector(entity, Prop_Send, "m_vecOrigin", witch_pos);
                  if (can_any_alive_survivor_see(witch_pos,false))
                  {
                      SetEntProp(entity,Prop_Data,"m_iHealth",health-1);
                      update_hint("Witch spotted, no refund.");
                  }
              }
       	 }
       	 
       }
       
       live_witches = counted_witches; 
   }
   
   if (panic && live_commons>=10) SetConVarInt(FindConVar("director_panic_forever"), 1);
   else SetConVarInt(FindConVar("director_panic_forever"), 0);
   
   if (panic && manual_panic)
   {
       if (panic_target<0 || !IsValidClient(panic_target) || (!IsPlayerAlive(panic_target) && panic_target!=zm_client ))
       {
           panic_target = L4D_GetHighestFlowSurvivor();
           Chase(panic_target);
       }
   }
   
   if (IsValidClientZM() && GetClientTeam(zm_client)!=TEAM_SURVIVOR)
   { 
      if (ZM_menu==null) create_ZM_menu();
      
      UpdateLiveSI();
      CountCommons();
      
      update_ZM_looktarget();
      
      if (g_iPlayersInSurvivorTeam!=bank_track_numplayers)
      {
           int player_diff = g_iPlayersInSurvivorTeam - bank_track_numplayers;
           if (player_diff>0 || !zm_started)
           {
               if (strcmp(g_sCvarMPGameMode, "survival", false) == 0) bank += g_iBonusFinaleStage*player_diff;
               else bank += g_iBankInitialPlayer*player_diff;
           }
           bank_track_numplayers = g_iPlayersInSurvivorTeam;
           //if (bank<0) bank=0;
      }
      
      //PrintToServer("[zm] bank: %d", bank); 
      //UpdateLiveSI();
      //ZM_menu.SetTitle("Zombie Master");
      ZM_menu.SetTitle("%d %d/%d %d/%d", bank, live_commons, g_iMaxCommons, live_SI, max_SI);
      //PrintToServer("[zm] Updating zm menu title"); 
      //ZM_menu.SetTitle(IntToString(bank));
      //PrintHintText(zm_client, "%d %d/%d", bank,live_SI,max_SI);
      //if (zm_menu_IsOpen)
      //{
         //ZM_menu.Display(zm_client,MENU_TIME_FOREVER);
         //PrintToServer("[zm] Updating zm menu"); 
         //DisplayMenuAtItem(ZM_menu,client,current_item,MENU_TIME_FOREVER)
      //}
      
      // Check for witches here too!
      if (g_fStopInactivity>0.0 && zm_started && bank>g_iBankInitial && live_SI<=0 && live_commons<=0 && live_witches<=0 && (t_now-t_zm_activity)>=(g_fStopInactivity)/2.0)
      {
         if (!zm_kick_notify)
         {
             PrintHintText(zm_client, "Type /zm in chat to spawn zombies.");
             zm_kick_notify=true;
         }
         else if ((t_now-t_zm_activity)>=g_fStopInactivity)
         {
             PrintHintText(zm_client, "You were removed from ZM due to inactivity.");
             PrintToChatAll("[zm] The ZM was removed due to inactivity.");
             QuitZM(zm_client,0);
             update_t_zm_activity(t_now);
         }
      }
      
      // Draw spawner visuals for ZM
      if (zm_menu_IsOpen && (t_now-t_last_spawner_update)>=g_fUpdateRate) can_ZM_spawn(false,false);
      
      
   }
   else
   {
      if ((t_now-t_zm_activity)>=10.0)
      {
         PrintToChatAll("[zm] There is no Zombie Master. Type !zm to become ZM.");
         update_t_zm_activity(t_now);
      }
      zm_client = -1;
      if (ZM_menu!=null) ZM_menu.Cancel();
   }

   if (zm_timer==null || !zm_timer)
   {
      delete zm_timer;
      zm_timer = CreateTimer(g_fUpdateRate,zm_update,_,TIMER_REPEAT);
   }
   
   return Plugin_Continue;
   
}



public Plugin myinfo =
{
	name = "[L4D2] Zombie Master",
	author = "gvazdas,zyiks",
	description = "[coop,survival] AI Game Director is replaced with a Player Game Director, the Zombie Master. Heavily inspired by the original HL2 mod.",
	version = PLUGIN_VERSION,
	url = "https://github.com/gvazdas"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{

	if(GetEngineVersion()!=Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	RegPluginLibrary("l4d2_zombie_master");

	return APLRes_Success;
}

void ConVarChanged_Allow(ConVar convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

//Handle hCommonLimit = INVALID_HANDLE;
//int iCommonLimit;

public void OnPluginStart()
{
	//LoadTranslations("l4d2_zombie_master.phrases");
    if (DEBUG) PrintToServer("[zm] OnPluginStart");
	GetGameData();
	ZM_finale_announced = false;
	ZM_finale_ended = false;
	
    
    // opt_zm // opt out of ZM lottery
    //RegConsoleCmd("zm_opt", OptZM, "Opt out of becoming the Zombie Master.");
	RegConsoleCmd("zm", JoinZM, "Become the Zombie Master; If already ZM, open ZM menu.");
	RegConsoleCmd("zm_horde", ZM_Spawn_Horde, "Spawn n zombies where Zombie Master is pointing");
	RegConsoleCmd("zm_witch", ZM_Spawn_Witch, "Spawn witch where Zombie Master is pointing; 0->static, 1->moving");
	RegConsoleCmd("zm_smoker", ZM_Smoker, "Spawn SI where Zombie Master is pointing");
	RegConsoleCmd("zm_hunter", ZM_Hunter, "Spawn SI where Zombie Master is pointing");
	RegConsoleCmd("zm_jockey", ZM_Jockey, "Spawn SI where Zombie Master is pointing");
	RegConsoleCmd("zm_spitter", ZM_Spitter, "Spawn SI where Zombie Master is pointing");
	RegConsoleCmd("zm_boomer", ZM_Boomer, "Spawn zombies where Zombie Master is pointing");
	RegConsoleCmd("zm_charger", ZM_Charger, "Spawn zombies where Zombie Master is pointing");
	RegConsoleCmd("zm_tank", ZM_Tank, "Spawn zombies where Zombie Master is pointing");
	RegConsoleCmd("zm_delete", ZM_Delete, "Delete Zombie Master units where Zombie Master is pointing.");
	RegConsoleCmd("zm_delete_all", ZM_Delete_All, "Delete ALL zombie master units."); // cannot use nb_delete_all!!!
	RegConsoleCmd("zm_delete_common", ZM_Delete_Commons, "Delete all common infected.");
    RegConsoleCmd("zm_delete_specials", ZM_Delete_Specials, "Delete all special infected.");
    RegConsoleCmd("zm_delete_witches", ZM_Delete_Witches, "Delete all witches.");
	RegConsoleCmd("zm_quit", QuitZM, "Zombie Master gives up and joins Survivors.");
	RegConsoleCmd("zm_panic", ZMPanic, "Zombie Master toggles panic event: horde rushes survivor who has progressed the most.");
	RegConsoleCmd("zm_unlock", zm_unlock,"Unlock and open saferoom door. Does not work if round ready conditions are not satisfied. Can be used by ZM and admins.");
	RegConsoleCmd("zm_followme", ZM_Chase_ZM, "Horde will follow ZM position.");
	RegConsoleCmd("zm_vision", ZM_Vision, "Toggle night vision for ZM.");
	RegConsoleCmd("zm_teleport", ZMTeleport, "ZM will teleport to farthest flow survivor.");
	RegConsoleCmd("zm_control", ZMControlSI, "ZM will take control of special infected they are pointing at.");
	
	//RegAdminCmd("sm_zlimit", Console_ZLimit, ADMFLAG_ROOT,"Control max special zombies limit until next map or data is reloaded");
	RegAdminCmd("zm_addbank", zm_addbank, ADMFLAG_ROOT,"Add zombux to zombie master bank. Admins only.");
    RegAdminCmd("zm_finale_next", zm_finale_advance, ADMFLAG_ROOT,"Trigger next finale stage. Admins only.");
    //RegAdminCmd("zm_addbank", zm_addbank, ADMFLAG_ROOT,"Add zombux to zombie master bank. Admins only.");
    
    
    
	g_hCvarAllow = CreateConVar("zm_enable", "0", "0=Plugin off, 1=Plugin on.",FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
    
    g_hBankRateBase = CreateConVar("g_fBankRateBase", "8", "Base ZM bank rate.",FCVAR_NOTIFY, true, 0.0, true, 1000000.0);
    g_hBankRateBase.AddChangeHook(ConVarChanged_Cvars);
    
    g_hBankRatePlayer = CreateConVar("zm_bank_rate_player", "2", "Additional ZM bank rate per alive survivor.",FCVAR_NOTIFY, true, 0.0, true, 1000000.0);
    g_hBankRatePlayer.AddChangeHook(ConVarChanged_Cvars);
    
    g_hBankInitial = CreateConVar("zm_iBankInitial", "1300", "Initial ZM bank.",FCVAR_NOTIFY, true, 0.0, true, 1000000.0);
    g_hBankInitial.AddChangeHook(ConVarChanged_Cvars);
    
    g_hPanicCost = CreateConVar("zm_panic_cost", "300", "Horde panic cost.",FCVAR_NOTIFY, true, 0.0, true, 1000000.0);
    g_hPanicCost.AddChangeHook(ConVarChanged_Cvars_ZMenu);
    
    g_hBankInitialPlayer = CreateConVar("zm_iBankInitial_player", "200", "Additional ZM bank per extra player.",FCVAR_NOTIFY, true, 0.0, true, 1000000.0);
    g_hBankInitialPlayer.AddChangeHook(ConVarChanged_Cvars);
    
    g_hUpdateRate = CreateConVar("zm_fUpdateRate", "0.5", "Update rate for periodic ZM checks.",FCVAR_NOTIFY, true, 0.1, true, 10.0);
    g_hUpdateRate.AddChangeHook(ConVarChanged_Cvars);
    
    g_hMaxCommons = CreateConVar("zm_maxcommons", "150", "ZM max number of common zombies. Increase it if your server can take it.",FCVAR_NOTIFY, true, 0.0, true, 1000.0);
    g_hMaxCommons.AddChangeHook(ConVarChanged_Cvars_ZMenu);
    
    g_hSpawnMinDistance = CreateConVar("zm_spawndistance", "500", "ZM minimum spawn distance.",FCVAR_NOTIFY, true, 0.0, true, 10000.0);
    g_hSpawnMinDistance.AddChangeHook(ConVarChanged_Cvars);
    
    g_hCostBoomer = CreateConVar("zm_cost_boomer", "150", "ZM boomer cost.",FCVAR_NOTIFY, true, 0.0, true, 10000.0);
    g_hCostBoomer.AddChangeHook(ConVarChanged_Cvars_ZMenu);
    
    g_hCostSpitter = CreateConVar("zm_cost_spitter", "150", "ZM spitter cost.",FCVAR_NOTIFY, true, 0.0, true, 10000.0);
    g_hCostSpitter.AddChangeHook(ConVarChanged_Cvars_ZMenu);
    
    g_hCostHunter = CreateConVar("zm_cost_hunter", "200", "ZM hunter cost.",FCVAR_NOTIFY, true, 0.0, true, 10000.0);
    g_hCostHunter.AddChangeHook(ConVarChanged_Cvars_ZMenu);
    
    g_hCostSmoker = CreateConVar("zm_cost_smoker", "200", "ZM smoker cost.",FCVAR_NOTIFY, true, 0.0, true, 10000.0);
    g_hCostSmoker.AddChangeHook(ConVarChanged_Cvars_ZMenu);
    
    g_hCostJockey = CreateConVar("zm_cost_jockey", "200", "ZM jockey cost.",FCVAR_NOTIFY, true, 0.0, true, 10000.0);
    g_hCostJockey.AddChangeHook(ConVarChanged_Cvars_ZMenu);
    
    g_hCostCharger = CreateConVar("zm_cost_charger", "200", "ZM charger cost.",FCVAR_NOTIFY, true, 0.0, true, 10000.0);
    g_hCostCharger.AddChangeHook(ConVarChanged_Cvars_ZMenu);
    
    g_hCostTank = CreateConVar("zm_cost_tank", "2000", "ZM tank cost.",FCVAR_NOTIFY, true, 0.0, true, 10000.0);
    g_hCostTank.AddChangeHook(ConVarChanged_Cvars_ZMenu);
    
    g_hCostWitchStatic = CreateConVar("zm_cost_witch_static", "500", "ZM static witch cost.",FCVAR_NOTIFY, true, 0.0, true, 10000.0);
    g_hCostWitchStatic.AddChangeHook(ConVarChanged_Cvars_ZMenu);
    
    g_hCostWitchMoving = CreateConVar("zm_cost_witch_moving", "500", "ZM moving witch cost.",FCVAR_NOTIFY, true, 0.0, true, 10000.0);
    g_hCostWitchMoving.AddChangeHook(ConVarChanged_Cvars_ZMenu);
    
    g_hCostCommon = CreateConVar("zm_cost_common", "2", "ZM common infected cost.",FCVAR_NOTIFY, true, 0.0, true, 10000.0);
    g_hCostCommon.AddChangeHook(ConVarChanged_Cvars_ZMenu);
    
    g_hBonusCarAlarm = CreateConVar("zm_bonus_car_alarm", "500", "Award ZM points for triggered car alarm.",FCVAR_NOTIFY, true, 0.0, true, 10000.0);
    g_hBonusCarAlarm.AddChangeHook(ConVarChanged_Cvars);
    
    g_hBonusFinaleStage = CreateConVar("zm_bonus_finale", "350", "ZM bank reward per player for advancing to the next Finale stage. A tank usually spawns too!",FCVAR_NOTIFY, true, 0.0, true, 10000.0);
    g_hBonusFinaleStage.AddChangeHook(ConVarChanged_Cvars);
    
    g_hLockSaferoom = CreateConVar("zm_lock_saferoom", "1", "Lock saferoom until player join activity has cooled down and ZM is present. Survivors will be frozen if there is no saferoom.",FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hLockSaferoom.AddChangeHook(ConVarChanged_Cvars);
    
    g_hStopInactivity = CreateConVar("zm_inactivity", "120.0", "Seconds of inactivity before the ZM is replaced. 0 to disable.",FCVAR_NOTIFY, true, 0.0, true, 10000000.0);
    g_hStopInactivity.AddChangeHook(ConVarChanged_Cvars);
    
    g_hMaxWitches = CreateConVar("zm_max_witches", "-1.0", "Max number of witches: -1 for automatic AliveSurvivors, otherwise whatever number is given.",FCVAR_NOTIFY, true, -1.0, true, 10000000.0);
    g_hMaxWitches.AddChangeHook(ConVarChanged_Cvars_ZMenu);
    
    g_hMaxSI = CreateConVar("zm_max_SI", "-1.0", "Max number of all special infected: -1 for automatic AliveSurvivors, otherwise whatever number is given.",FCVAR_NOTIFY, true, -1.0, true, 10000000.0);
    g_hMaxSI.AddChangeHook(ConVarChanged_Cvars_ZMenu);
    
    g_hMaxUniqueSI = CreateConVar("zm_max_unique_SI", "-1.0", "Max number of each special infected class: -1 for automatic ceil(AliveSurvivors/2), otherwise whatever number is given.",FCVAR_NOTIFY, true, -1.0, true, 10000000.0);
    g_hMaxUniqueSI.AddChangeHook(ConVarChanged_Cvars_ZMenu);
	
	g_hCvarAllow.AddChangeHook(ConVarChanged_Cvars);

	GetCvars();

	g_iPlayersInSurvivorTeam = -1;
	zm_started = false;
	zm_client = -1;

	// Removes the boundaries for z_max_player_zombies and notify flag
	z_max_player_zombies = FindConVar("z_max_player_zombies");
	int flags = z_max_player_zombies.Flags;
	SetConVarBounds(z_max_player_zombies, ConVarBound_Upper, false);
	SetConVarFlags(z_max_player_zombies, flags & ~FCVAR_NOTIFY);
  	
  	g_hCvarMPGameMode = FindConVar("mp_gamemode");
  	g_hCvarMPGameMode.GetString(g_sCvarMPGameMode, sizeof(g_sCvarMPGameMode));
  	g_hCvarMPGameMode.AddChangeHook(ConVarGameMode);
  	
  	// Allow commands that are usually sv_cheats 1 prohibited to work to control director and the horde.
  	//RegConsoleCmd("director_stop",cheatcommand);
  	//SetCommandFlags("director_stop", ~FCVAR_CHEAT);
	
	set_bank_begin();
	
	//hCommonLimit = FindConVar("z_common_limit");
    //iCommonLimit = GetConVarInt(hCommonLimit);
    //HookConVarChange(hCommonLimit, Cvar_CommonLimitChange);
	
}

//public Cvar_CommonLimitChange( Handle cvar, const String oldValue[], const String newValue[] )
//{
//    iCommonLimit = StringToInt(newValue);
//}

void ConVarGameMode(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char sGameMode[32];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	if(strcmp(g_sCvarMPGameMode, sGameMode, false) == 0) return;
	g_sCvarMPGameMode = sGameMode;
    
    if (DEBUG) PrintToServer("[zm] Gamemode: %s", g_sCvarMPGameMode);
    
	//IsAllowed();
	if (g_bCvarAllow) ServerCommand("sm_cvar mp_restartgame 1");

}

// update zmenu when these cvars change
void ConVarChanged_Cvars_ZMenu(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (DEBUG) PrintToServer("[zm] ConVarChanged_Cvars_ZMenu");
    GetCvars();
    SetCvarsZM();
    create_ZM_menu();
    if (IsValidClientZM() && zm_menu_IsOpen)
    {
	   ZM_menu.Display(zm_client,MENU_TIME_FOREVER);
	   if (DEBUG) PrintToServer("[zm] zmenu cvars changed, redisplaying."); 
	}
	if (g_bCvarAllow && zm_started && zm_client>0) zm_update(zm_timer);
}


void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
    GetCvars();
}

void GetCvars()
{
    
    if (DEBUG) PrintToServer("[zm] GetCvars");
    g_fUpdateRate = g_hUpdateRate.FloatValue;
    ResetTimer();
    
    g_fBankRateBase = g_hBankRateBase.FloatValue;
    g_fBankRatePlayer = g_hBankRatePlayer.FloatValue;
    g_iBankInitial = g_hBankInitial.IntValue;
    g_iBankInitialPlayer = g_hBankInitialPlayer.IntValue;
    g_iMaxCommons = g_hMaxCommons.IntValue;
    g_fSpawnMinDistance = g_hSpawnMinDistance.FloatValue;
    g_fStopInactivity = g_hStopInactivity.FloatValue;
    
    costs_SI[ZOMBIECLASS_BOOMER] = g_hCostBoomer.IntValue;
    costs_SI[ZOMBIECLASS_SPITTER] = g_hCostSpitter.IntValue;
    costs_SI[ZOMBIECLASS_HUNTER] = g_hCostHunter.IntValue;
    costs_SI[ZOMBIECLASS_SMOKER] = g_hCostSmoker.IntValue;
    costs_SI[ZOMBIECLASS_JOCKEY] = g_hCostJockey.IntValue;
    costs_SI[ZOMBIECLASS_CHARGER] = g_hCostCharger.IntValue;
    costs_SI[ZOMBIECLASS_TANK] = g_hCostTank.IntValue;
    g_iCostWitchStatic = g_hCostWitchStatic.IntValue;
    g_iCostWitchMoving = g_hCostWitchMoving.IntValue;
    g_iCostCommon = g_hCostCommon.IntValue;
    g_iMaxWitches = g_hMaxWitches.IntValue;
    g_iMaxSI = g_hMaxSI.IntValue;
    g_iMaxUniqueSI = g_hMaxUniqueSI.IntValue;
    
    g_iBonusCarAlarm = g_hBonusCarAlarm.IntValue;
    g_iBonusFinaleStage = g_hBonusFinaleStage.IntValue;
    
    g_iPanicCost = g_hPanicCost.IntValue;
    
    g_bLockSaferoom = g_hLockSaferoom.BoolValue;
    
}

Action JoinZM(int client, int args)
{
	if (!g_bCvarAllow) return Plugin_Continue;
	if (DEBUG) PrintToServer("[zm] JoinZM");
	if (client<0 || IsFakeClient(client)) return Plugin_Continue;
	if (IsValidClientZM())
	{
       if (client==zm_client)
       {
          if (IsPlayerAlive(zm_client) || GetClientTeam(zm_client)!=TEAM_ZM)
          {
              //ChangeClientTeam(client,TEAM_SPECTATOR);
              ChangeClientTeam(client,TEAM_ZM);
              L4D_State_Transition(client, STATE_OBSERVER_MODE);
          }
          SetEntProp(client, Prop_Data, "m_iObserverMode", 6); //thanks to EHG https://forums.alliedmods.net/showthread.php?p=1080991
          // Teleport ZM to random survivor at round start on initial ZM join
          if (zm_timer==null) zm_update(zm_timer);
          ZM_menu.Display(zm_client,MENU_TIME_FOREVER);
          zm_menu_IsOpen = true; 
          
       }
       else
          PrintHintText(client,"There is already a Zombie Master.");
       return Plugin_Continue;
    }
	
	if (ZM_menu!=null) ZM_menu.Cancel();
	else create_ZM_menu();
    
    //ChangeClientTeam(client,TEAM_SPECTATOR);
    ChangeClientTeam(client,TEAM_ZM);
    L4D_State_Transition(client, STATE_OBSERVER_MODE);
    zm_client = client;
    char name[MAX_NAME_LENGTH]; 
    GetClientName(client,name,sizeof(name));
    PrintToChatAll("[zm] %s is the Zombie Master.", name);
    SetEntProp(client, Prop_Data, "m_iObserverMode", 6);
    PrintHintText(client, "You are the Zombie Master. Type /zm to open the menu.");
    //HookEvent("player_run_cmd", OnZMRunCMD);
    update_t_zm_activity();
    CountAliveSurvivors();
    zm_update(zm_timer);
    ZM_menu.Display(zm_client,MENU_TIME_FOREVER);
    zm_menu_IsOpen = true;
    
    // Prevent InputKill, thanks Shadowysn
    SetVariantString("self.ValidateScriptScope()");
	AcceptEntityInput(client, "RunScriptCode");
	SetVariantString("plugin_shouldKill <- false;");
    AcceptEntityInput(client, "RunScriptCode");
    SetVariantString("function InputKill() {return plugin_shouldKill}");
    AcceptEntityInput(client, "RunScriptCode");
    
    ZMTeleport(zm_client,0);
    L4D_CleanupPlayerState(client);
    
    entref_control = INVALID_ENT_REFERENCE;
    entref_delete = INVALID_ENT_REFERENCE;
    
    //FindConVar("mp_gamemode").ReplicateToClient(zm_client, "versus");
    
    //L4D_SetPlayerSpawnTime(client,99999999.0, true);
    //L4D_SetPlayerSpawnTime(client,-1.0, true);
    //PrintToChat(client, "To reduce tint: mat_postprocess_enable 0; mat_bloom_scalefactor_scalar 0");

	return Plugin_Continue;
}

Action QuitZM(int client, int args)
{
	if (DEBUG) PrintToServer("[zm] QuitZM");
	if (!g_bCvarAllow || client<=0 || IsFakeClient(client) || !IsClientInGame(client)) return Plugin_Continue;
	if (client==zm_client)
	{
	   // Sanitize here: get userid not entity. Crashes can happen otherwise.
	   if (IsValidClientZM())
	   {
           char name[MAX_NAME_LENGTH]; 
           GetClientName(client,name,sizeof(name));
           L4D_CleanupPlayerState(client);
           PrintToChatAll("[zm] %s is no longer the Zombie Master.", name);
           
           //ConVar g_hCvarMPGameMode = FindConVar("mp_gamemode");
           //char g_sCvarMPGameMode[32];
       	   //g_hCvarMPGameMode.GetString(g_sCvarMPGameMode, sizeof(g_sCvarMPGameMode));
           //g_hCvarMPGameMode.ReplicateToClient(client, g_sCvarMPGameMode);
           
       }
       zm_client = -1;
       update_t_zm_activity();
       if (ZM_menu!=null) ZM_menu.Cancel();
       zm_menu_IsOpen = false; 
       zm_update(zm_timer);
    }
    if (IsValidClient(client))
    {
        if (GetClientTeam(client)!=TEAM_SURVIVOR)
        {
            ChangeClientTeam(client,TEAM_SURVIVOR);
            
            // Find bot that can be taken over
            // Credit: l4dmultislots by HarryPotter
            int bot = -1;
            for (int i = 1; i <= MaxClients; i++)
        	{
        		if (!IsClientInGame(i)) continue;
        		if (GetClientTeam(i)!=TEAM_SURVIVOR) continue;
        		if (!IsPlayerAlive(i)) continue;
        		if (!IsFakeClient(i)) continue;
        		if (HasEntProp(i,Prop_Send,"m_humanSpectatorUserID"))
        		{
            		if (GetEntProp(i, Prop_Send, "m_humanSpectatorUserID")>0) continue;
        		}
        		bot = i;
        		break;
            }

   			if(bot > 0)
   			{
   				L4D_SetHumanSpec(bot, client);
   				L4D_TakeOverBot(client);
   			}
        }
        SetEntProp(client, Prop_Send, "m_bNightVisionOn",0); 
    }
    
	return Plugin_Continue;
}

//void OnZMRunCMD(Event event, const char[] name, bool dontBroadcast)
//{
//	int client = GetClientOfUserId(event.GetInt("userid"));
//}

// Rain and Snow all thanks to l4d2_storm by SilverShot
// https://forums.alliedmods.net/showthread.php?t=184890

int rain_entity = -1;

Action ZM_Rain_Toggle(int client)
{
   toggle_rain(client);
   return Plugin_Continue;
}

Action ZM_Fog_Toggle(int client)
{
   toggle_fog(client);
   return Plugin_Continue;
}

Action ZM_Vision(int client, int args)
{
   toggle_ZM_vision(client);
   return Plugin_Continue;
}

void toggle_ZM_vision(int client)
{
    if (!g_bCvarAllow || !IsValidClient(client)) return;
    
    if (client!=zm_client)
    {
        SetEntProp(client, Prop_Send, "m_bNightVisionOn",0);
        return;
    }
    
    int curr_state = GetEntProp(client, Prop_Send, "m_bNightVisionOn");
    if (curr_state>0)
    {
        SetEntProp(client, Prop_Send, "m_bNightVisionOn",0);
        EmitSoundToClient(client,SOUND_VISION);
    }
    else
    {
        SetEntProp(client, Prop_Send, "m_bNightVisionOn",1);
        EmitSoundToClient(client,SOUND_VISION);
    }
}

void toggle_rain(int client)
{
	if (DEBUG) PrintToServer("[zm] toggle_rain");
	if (!g_bCvarAllow || !IsValidClientZM() || client!=zm_client) return;
	
	if (rain_entity>0)
	{
	   if (EntRefToEntIndex(rain_entity)!=INVALID_ENT_REFERENCE) RemoveEntity(rain_entity);
	   rain_entity = -1;
	   PrintToServer("[zm] Rain turned OFF"); 
	   return;
	}
	
	int value, entity = -1;
	while( (entity = FindEntityByClassname(entity, "func_precipitation")) != INVALID_ENT_REFERENCE )
	{
		value = GetEntProp(entity, Prop_Data, "m_nPrecipType");
		if( value < 0 || value == 4 || value > 5 )
			RemoveEntity(entity);
	}
	
		entity = CreateEntityByName("func_precipitation");
		if( entity != -1 )
		{
			char buffer[128];
			GetCurrentMap(buffer, sizeof(buffer));
			Format(buffer, sizeof(buffer), "maps/%s.bsp", buffer);

			DispatchKeyValue(entity, "model", buffer);
			DispatchKeyValue(entity, "targetname", "silver_rain");
			IntToString(1, buffer, sizeof(buffer));
			DispatchKeyValue(entity, "preciptype", buffer);
			DispatchKeyValue(entity, "minSpeed", "25");
			DispatchKeyValue(entity, "maxSpeed", "35");
			DispatchKeyValue(entity, "renderfx", "21");
			DispatchKeyValue(entity, "rendercolor", "31 34 52");
			DispatchKeyValue(entity, "renderamt", "100");

			float vMins[3], vMaxs[3];
			GetEntPropVector(0, Prop_Data, "m_WorldMins", vMins);
			GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vMaxs);
			SetEntPropVector(entity, Prop_Send, "m_vecMins", vMins);
			SetEntPropVector(entity, Prop_Send, "m_vecMaxs", vMaxs);

			float vBuff[3];
			vBuff[0] = vMins[0] + vMaxs[0];
			vBuff[1] = vMins[1] + vMaxs[1];
			vBuff[2] = vMins[2] + vMaxs[2];

			DispatchSpawn(entity);
			ActivateEntity(entity);
			TeleportEntity(entity, vBuff, NULL_VECTOR, NULL_VECTOR);
			
			//rain_entity = EntIndexToEntRef(entity);
			rain_entity = entity;
			PrintToServer("[zm] Rain turned ON"); 
			
		}
		else if (IsValidClientZM())
			PrintHintText(zm_client, "Weather could not be adjusted.");
	
	return;
}

int fog_entity = -1;

void toggle_fog(int client)
{
	if (DEBUG) PrintToServer("[zm] toggle_fog");
	if (!g_bCvarAllow || !IsValidClientZM() || client!=zm_client) return;
	
	if (fog_entity>0)
	{
	   if (EntRefToEntIndex(fog_entity)!=INVALID_ENT_REFERENCE) RemoveEntity(fog_entity);
	   fog_entity = -1;
	   PrintToServer("[zm] Fog turned OFF"); 
	   return;
	}
	
	int entity = -1;
	int count = 0;
	while( (entity = FindEntityByClassname(entity, "env_fog_controller")) != INVALID_ENT_REFERENCE )
	{
		count += 1;
	}
	if (count>0)
	{
	   PrintToServer("[zm] Fog already exists"); 
	   if (IsValidClientZM()) PrintHintText(zm_client, "Fog already exists.");
	   return;
	}
	
	    fog_entity = CreateEntityByName("env_fog_controller");
		if( fog_entity != -1 )
		{
			DispatchKeyValue(fog_entity, "targetname", "silver_fog_storm");
			DispatchKeyValue(fog_entity, "use_angles", "1");
			DispatchKeyValue(fog_entity, "fogstart", "1");
			DispatchKeyValue(fog_entity, "fogmaxdensity", "1");
			DispatchKeyValue(fog_entity, "heightFogStart", "0.0");
			DispatchKeyValue(fog_entity, "heightFogMaxDensity", "1.0");
			DispatchKeyValue(fog_entity, "heightFogDensity", "0.0");
			DispatchKeyValue(fog_entity, "fogenable", "1");
			DispatchKeyValue(fog_entity, "fogdir", "1 0 0");
			DispatchKeyValue(fog_entity, "angles", "0 180 0");
			DispatchSpawn(fog_entity);
			ActivateEntity(fog_entity);

			TeleportEntity(fog_entity, view_as<float>({ 10.0, 15.0, 20.0 }), NULL_VECTOR, NULL_VECTOR);
			//fog_entity = EntIndexToEntRef(fog_entity);
			PrintToServer("[zm] Fog turned ON"); 
		}
		else if (IsValidClientZM()) PrintHintText(zm_client, "Weather could not be adjusted.");
	
	return;
}

int snow_entity = -1;

Action ZM_Snow_Toggle(int client)
{
   toggle_snow(client);
   return Plugin_Continue;
}

void toggle_snow(int client)
{
	if (DEBUG) PrintToServer("[zm] toggle_snow");
	if (!g_bCvarAllow || !IsValidClientZM() || client!=zm_client) return;
	
	if (snow_entity>0)
	{
	   if (EntRefToEntIndex(snow_entity)!=INVALID_ENT_REFERENCE) RemoveEntity(snow_entity);
	   snow_entity = -1;
	   PrintToServer("[zm] Snow turned OFF"); 
	   return;
	}
	
	int value, entity = -1;
	while( (entity = FindEntityByClassname(entity, "func_precipitation")) != INVALID_ENT_REFERENCE )
	{
		value = GetEntProp(entity, Prop_Data, "m_nPrecipType");
		if( value < 0 || value == 4 || value > 5 )
			RemoveEntity(entity);
	}

	entity = CreateEntityByName("func_precipitation");
	if( entity != -1 )
	{
		char buffer[128];
		GetCurrentMap(buffer, sizeof(buffer));
		Format(buffer, sizeof(buffer), "maps/%s.bsp", buffer);

		DispatchKeyValue(entity, "model", buffer);
		DispatchKeyValue(entity, "targetname", "silver_snow");
		DispatchKeyValue(entity, "preciptype", "3");
		DispatchKeyValue(entity, "renderamt", "100");
		DispatchKeyValue(entity, "rendercolor", "200 200 200");

		//snow_entity = EntIndexToEntRef(entity);
		snow_entity = entity;

		float vBuff[3], vMins[3], vMaxs[3];
		GetEntPropVector(0, Prop_Data, "m_WorldMins", vMins);
		GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vMaxs);
		SetEntPropVector(snow_entity, Prop_Send, "m_vecMins", vMins);
		SetEntPropVector(snow_entity, Prop_Send, "m_vecMaxs", vMaxs);

		bool found = false;
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( !found && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
			{
				found = true;
				GetClientAbsOrigin(i, vBuff);
				break;
			}
		}

		if( !found )
		{
			vBuff[0] = vMins[0] + vMaxs[0];
			vBuff[1] = vMins[1] + vMaxs[1];
			vBuff[2] = vMins[2] + vMaxs[2];
		}

		DispatchSpawn(snow_entity);
		ActivateEntity(snow_entity);
		TeleportEntity(snow_entity, vBuff, NULL_VECTOR, NULL_VECTOR);
		
		PrintToServer("[zm] Snow turned ON"); 
		
	}
	else if (IsValidClientZM()) PrintHintText(zm_client, "Weather could not be adjusted.");
	
	return;
}

Action zm_finale_advance(int client, int args)
{
  if (DEBUG) PrintToServer("[zm] zm_finale_advance");
  if (L4D_IsFinaleActive()) L4D2_ForceNextStage();
  else PrintToServer("[zm] Finale is not active"); 
  return Plugin_Continue;
}

Action zm_addbank(int client, int args)
{
    if (DEBUG) PrintToServer("[zm] zm_addbank");
    if (!g_bCvarAllow) return Plugin_Continue;
    if (args>0)
    {
        int add = GetCmdArgInt(1);
        if (add>100000) add = 100000;
        bank += add;
        zm_update(zm_timer);
    }
    return Plugin_Continue;
}



Action zm_unlock(int client, int args)
{
    if (DEBUG) PrintToServer("[zm] zm_unlock");
    if (!g_bCvarAllow) return Plugin_Continue;
    if (client==zm_client || CheckCommandAccess(client,"is_a_sm_admin",ADMFLAG_GENERIC,true))
    {
        if (zm_can_start || zm_started)
        {
            if (!zm_started && IsValidEntRef(g_iLockedDoor))
            {
                int random = GetRandomInt(1,5);
                switch (random)
                {
                    case 1: {EmitSoundToAll(SOUND_SCARY1,g_iLockedDoor);}
                    case 2: {EmitSoundToAll(SOUND_SCARY2,g_iLockedDoor);}
                    case 3: {EmitSoundToAll(SOUND_SCARY3,g_iLockedDoor);}
                    case 4: {EmitSoundToAll(SOUND_SCARY4,g_iLockedDoor);}
                    case 5: {EmitSoundToAll(SOUND_SCARY5,g_iLockedDoor);}
                    default: {EmitSoundToAll(SOUND_SCARY3,g_iLockedDoor);}
                }
                start_zm_round(false);
            }
            else start_zm_round(true);
            PrintToServer("[zm] Saferoom forced open"); 
        }
        else freeze_team(false);
    }
    return Plugin_Continue;
}

Action ZM_Spawn_Horde(int client, int args)
{
    int count = 10;
    if (args>0)
    {
        count=GetCmdArgInt(1);
        if (count<=0 || count>=g_iMaxCommons) count = 10;
	}
    ZM_Horde(client,count);
    return Plugin_Continue;
}

// TerrorNavArea bool IsBlocked(int team, bool affectsFlow)
// bool IsSpawningAllowed()
// TerrorNavArea float GetDistanceSquaredToPoint(Vector pos)

//  CTerrorPlayer GetClosestSurvivor(Vector origin, bool bIncludeIncap, bool bIncludeOnRescueVehicle)
// Returns the closest Survivor from the passed origin, if incapped Survivors are included in search, or on rescue vehicle. 

// NavArea -- have to check if survivors can see it otherwise the spawns may be a little excessively close

// L4D2_CommandABot(int entity, int target, BOT_CMD type, float vecPos[3] = NULL_VECTOR)
// native int L4D_GetNavArea_AttributeFlags(Address pTerrorNavArea); 
// native int L4D_GetNavArea_SpawnAttributes(Address pTerrorNavArea); 
// new target = GetEntPropEnt(common, Prop_Send, "m_clientLookatTarget"); 

//SetConVarInt(FindConVar("z_common_limit"), commonlimit);
//SetConVarInt(FindConVar("z_background_limit"), backgroundlimit);
//SetConVarInt(FindConVar("z_mega_mob_size"), megamobsize);
//SetConVarInt(FindConVar("z_mob_min_notify_count"), mobminnotify);
//SetConVarInt(FindConVar("z_mob_spawn_min_size"), mobminsize);
//SetConVarInt(FindConVar("z_mob_spawn_max_size"), mobmaxsize);
// SetConVarInt(FindConVar("z_spawn_safety_range"), 0);
//sm_cvar z_common_limit tried 100 to 2000
//sm_cvar z_mob_spawn_min_size tried 45 to 85
//sm_cvar z_mob_spawn_max_size tried 85 to 185
//sm_cvar z_mob_spawn_min_interval_hard tried 20 to 60
//sm_cvar z_mob_spawn_max_interval_hard tried 40 to 80
//sm_cvar z_mob_spawn_finale_size tried 40 to 200
//sm_cvar z_mega_mob_size tried 50 to 200
//sm_cvar z_mega_mob_spawn_min_interval tried 20 to 60
//sm_cvar z_mega_mob_spawn_max_interval tried 40 to 80
// z_mob_population_density
//  z_wandering_density
// z_acquire_ make commons more aggressive
// z_background_limit 
// z_alert_range

// Modify these for panic and no panic
// z_acquire_far_range
// z_acquire_far_time
// z_acquire_near_range
// z_acquire_near_time
// z_acquire_time_variance_factor

// zm spawner: if surface is bad but 10 units away there is a good one, lock onto that

// console command to view nav areas? allow toggle for ZM

void ZM_Horde(int client, int count=10)
{
	if (DEBUG) PrintToServer("[zm] ZM_Horde");
	if (!g_bCvarAllow || !IsValidClientZM() || client!=zm_client) return;
	
	update_t_zm_activity();
	
	//PrintToServer("[zm] Horde called by client %d, num zombies %d", client, count); 
	int temp_cost = g_iCostCommon*count;
	if ((bank-temp_cost)<0)
	{
    	update_hint("OH GOD WE'RE GONNA BE POOR");
    	return;
	}
	
	if (!can_ZM_spawn()) return;
	
	CountCommons(false);
	g_iEntities = GetEntityCountEx();
	
	if((live_commons+count)>g_iMaxCommons || (g_iEntities+count)>=ENTITY_SAFER_LIMIT)
	{
	   update_hint("Limit reached.");
	   return;
    }
    
	bank -= temp_cost;
	live_commons += count;
	g_iEntities += count; // do not shrink this because director can teleport these zombies elsewhere on the map
	//if (!panic) SetConVarInt(FindConVar("z_common_limit"), live_commons);
	//else SetConVarInt(FindConVar("z_common_limit"), 0);
	//SetConVarInt(FindConVar("z_background_limit"), 0);
	
	int spawned = 0;
	
	// bools: anyz los checkground
	float randomPos[3];
	//PrintToServer("[zm] Horde NavArea %d", navArea);
	for( int i = 0; i < count; i++  )
	{
		
		int zombie = -1;
		if (zm_spawner_navArea)
		{
    		L4D_FindRandomSpot(zm_spawner_navArea,randomPos);
    		if (!can_any_alive_survivor_see(randomPos,false)) zombie = L4D_SpawnCommonInfected(randomPos); 
		}
		if (zombie<=0)
		{
		   zombie = L4D_SpawnCommonInfected(zm_spawner_pos);
		}
		if (zombie<=0)
    	{
            	if (DEBUG) PrintToServer("[zm] Spawn failed");
            	bank += temp_cost;
            	live_commons -= 1;
        }
        else
        {
           spawned += 1;
        }
		
		
		// stock int L4D_SpawnCommonInfected(float vPos[3], float vAng[3] = { 0.0, 0.0, 0.0 }) 
		//int zombie = CreateEntityByName("infected", -1);
		//if(zombie>0)
		//{
			// asdf
			//L4D_FindRandomSpot(int NavArea, float vecPos[3]); 
			//L4D_SpawnCommonInfected(float vPos[3], float vAng[3] = { 0.0, 0.0, 0.0 })
			//L4D_GetNearestNavArea(const float vecPos[3], float maxDist = 100.0, bool anyZ = false, bool checkLOS = false, bool checkGround = false, int teamID = 2);
			//TeleportEntity(zombie,zm_spawner_pos,NULL_VECTOR,NULL_VECTOR);
			
        	//SetEntProp(zombie, Prop_Data, "m_nNextThinkTick", ticktime);
			//DispatchSpawn(zombie);
			//ActivateEntity(zombie);
			//TeleportEntity(zombie,zm_spawner_pos,NULL_VECTOR,NULL_VECTOR);
			
			// from all4dead2
			//new zombie = CreateEntityByName("infected");
			//SetEntityModel(zombie, change_zombie_model_to);
    		//int ticktime = RoundToNearest(GetGameTime()/GetTickInterval()) + 5;
    		//SetEntProp(zombie, Prop_Data, "m_nNextThinkTick", ticktime);
    		//DispatchSpawn(zombie);
    		//ActivateEntity(zombie);
    		//TeleportEntity(zombie, last_zombie_spawn_location, NULL_VECTOR, NULL_VECTOR);
			
		//}
		
	}
	//if (!panic) SetConVarInt(FindConVar("z_common_limit"), live_commons);
	//else SetConVarInt(FindConVar("z_common_limit"), 0);
	if (spawned<=0)
	{
    	update_hint("Spawn failed.");
    	if (live_commons<10) SetConVarInt(FindConVar("director_panic_forever"), 0);
	}
	else if (panic && live_commons>=10) SetConVarInt(FindConVar("director_panic_forever"), 1);
	
    zm_update(zm_timer);
}

Action reset_time_of_day(Handle Timer)
{
SetConVarInt(FindConVar("sv_force_time_of_day"),-1);
return Plugin_Continue;
}

// WITCH_STATIC WITCH_MOVING
//ConVar sv_force_time_of_day;
void ZM_Witch(int client,int witch_type)
{

	if (DEBUG) PrintToServer("[zm] ZM_Witch");
	if (!g_bCvarAllow || !IsValidClientZM() || client!=zm_client) return;
	
	update_t_zm_activity();
	
	int temp_cost;
	if (witch_type==WITCH_STATIC) temp_cost=g_iCostWitchStatic;
	else temp_cost=g_iCostWitchMoving;
	if ((bank-temp_cost)<0) 
	{
    	update_hint("They don't come cheap.");
    	return;
	}
	
	CountWitches(false);
	if (live_witches>=max_witches) 
	{
    	update_hint("Limit reached.");
    	return;
	}
	
	if (!can_ZM_spawn(true)) return;
	
	// Sitting or moving witch
	// sm_cvar sv_force_time_of_day 0 -- midnight -- sitting witch
	// sm_cvar sv_force_time_of_day 3 -- day -- walking witch
	
	if (witch_type==WITCH_STATIC) SetConVarInt(FindConVar("sv_force_time_of_day"),0);
	else SetConVarInt(FindConVar("sv_force_time_of_day"),3);
	
	int witch;
	if(g_bSpawnWitchBride) witch = L4D2_SpawnWitchBride(zm_spawner_pos,NULL_VECTOR);
    else witch = L4D2_SpawnWitch(zm_spawner_pos,NULL_VECTOR);
	
	CreateTimer(g_fUpdateRate,reset_time_of_day,TIMER_FLAG_NO_MAPCHANGE);
	
	if (witch>0)
	{
    	bank -= temp_cost;
    	live_witches += 1;
    	if (DEBUG) PrintToServer("[zm] Created witch %d", witch);
    	//SDKHook(bot, entity_visible, OnTakeDamage_Units);
    	//CreateTimer(0.1,CreateZMGlow,EntIndexToEntRef(witch));
    	//CreateZMGlow(witch);
    	CreateZMGlow(EntIndexToEntRef(witch));
	}
	else
	{
    	//PrintHintText(zm_client, "Witch spawn failed. Try again.");
    	update_hint("Spawn failed.");
    }
	
    zm_update(zm_timer);

}


void CountWitches(bool fast = true)
{
    if (live_witches<=0 && fast) return;
    if (DEBUG) PrintToServer("[zm] CountWitches expensive");
    live_witches = 0;
    int entity = -1;
    while ( ((entity = FindEntityByClassname(entity, "witch")) != -1) )
    {
    	live_witches++;
    }
}

void delete_all_infected(bool common=true, bool witch=true, bool special=true)
{
   	bool anything_to_delete = false;
   	if (common && live_commons>0)
   	{
   	   anything_to_delete = true;
   	   SetConVarInt(FindConVar("z_common_limit"), 0);
   	   //SetConVarInt(FindConVar("z_background_limit"), 0);
   	   live_commons = 0;
   	}
   	if (witch && live_witches>0)
   	{
   	   anything_to_delete = true;
   	   live_witches = 0;
   	}
   	if (special && live_SI>0)
   	{
       	anything_to_delete = true;
       	live_SI = 0;
   	}
   	if (!anything_to_delete) return;
   	
   	if (DEBUG) PrintToServer("[zm] delete_all_infected");
   	
   	static char class[32];
   	int entity;
   	for(entity = 0; entity < MAXENTITIES; entity++)
   	{
   		if(IsValidEntity(entity) || IsValidEdict(entity))
   		{    
   		     if (entity==zm_client) continue;
   		     if (GetEntProp(entity,Prop_Data,"m_iMaxHealth")<=0) continue;
      	     GetEntityClassname(entity, class, sizeof(class));
      	     if ( (common && strcmp(class,"infected")==0) || (witch && strcmp(class,"witch")==0) || (special && strcmp(class,"player")==0 && GetClientTeam(entity)==TEAM_INFECTED) )
      	     {
          	     zm_deleted = true;
          	     RemoveEntity(entity);
      	     }
   		}
   	}
}

Action ZM_Spawn_Witch(int client, int args)
{	
	int witch_type = WITCH_STATIC;
	if (args>0) witch_type=GetCmdArgInt(1);
	ZM_Witch(client,witch_type);
	return Plugin_Continue;
}


void zm_del_pointing(int client)
{
   
   if (DEBUG) PrintToServer("[zm] zm_del_pointing");
   if (!g_bCvarAllow || !IsValidClientZM() || client!=zm_client) return;
   
   update_t_zm_activity();
   zm_deleted = false;
   update_ZM_looktarget();
   if (!IsValidEntRef(entref_delete))
   {
       update_hint("Invalid target.");
       return;
   }
   int target = EntRefToEntIndex(entref_delete);
   if ( !IsValidEntity(target) || (target<=MaxClients && !IsFakeClient(target)) ) 
   {
       update_hint("Invalid target.");
       return;
   }
   zm_deleted = true;
   RemoveEntity(target);
}


public Action evtPlayerIncap(Event event, const char[] name, bool dontBroadcast)
{
    
    if (!g_bCvarAllow) return Plugin_Continue;
    
    if (DEBUG) PrintToServer("[zm] evtPlayerIncap");
	return Plugin_Continue;
}

public Action evtPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    
    if (!g_bCvarAllow) return Plugin_Continue;
    
    if (DEBUG) PrintToServer("[zm] evtPlayerDeath");
    
    // Skip victims that are not infected entities
    int victim = GetClientOfUserId(event.GetInt("userid"));
    if (DEBUG)
    {
        int max_health = GetEntProp(victim,Prop_Data,"m_iMaxHealth");
        int health = GetEntProp(victim,Prop_Data,"m_iHealth");
        PrintToServer("%d died %d/%d", victim, health, max_health);
    }
    if (!victim || !IsClientInGame(victim)) return Plugin_Continue;
    
    if(GetClientTeam(victim)!=TEAM_INFECTED)
    {
        CountAliveSurvivors();
        //zm_update(zm_timer);
        return Plugin_Continue;
    }
    
    UpdateLiveSI(false);
    
    //if (IsValidClientZM() && victim==zm_client)
    //{
    //    ChangeClientTeam(zm_client,TEAM_SPECTATOR);
    //    ChangeClientTeam(zm_client,TEAM_ZM);
    //    L4D_State_Transition(zm_client, STATE_OBSERVER_MODE);
    //    L4D_CleanupPlayerState(zm_client);
    //}
    
    int zClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
    
    int ent_glow = g_iGlowList[victim];
    if ( ent_glow>0 && IsValidEntity(ent_glow) && ent_glow>MAXPLAYERS && (GetEntProp(ent_glow, Prop_Send, "m_CollisionGroup")==0) )
       RemoveEntity(ent_glow);
    g_iGlowList[victim] = -1;
    
    // survival: every tank death gives ZM points
    if (strcmp(g_sCvarMPGameMode, "survival", false) == 0 && zClass==ZOMBIECLASS_TANK)
    {
       bank += g_iBonusFinaleStage*g_iPlayersInSurvivorTeam;
       return Plugin_Continue;
    }
    
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    
    if(victim>0 && attacker>0 && attacker==victim)
	{
         if (zClass<ZOMBIECLASS_SMOKER || zClass>ZOMBIECLASS_TANK || zClass==7) return Plugin_Continue;
         bank += costs_SI[zClass];
         //static char class[32];
 	     //GetEntityClassname(victim, class, sizeof(class));
         //int max_health = GetEntProp(victim,Prop_Data,"m_iMaxHealth");
         //int health = GetEntProp(victim,Prop_Data,"m_iHealth");
         //PrintToServer("%d has suicided, refunding %d", zClass, costs_SI[zClass]);
	}
	return Plugin_Continue;
}

public Action EvtWitchKilled(Event event, const char[] name, bool dontBroadcast)
{
    
    if (DEBUG) PrintToServer("[zm] EvtWitchKilled");
    
    int witch = event.GetInt("witchid");
    int ent_glow = g_iGlowList[witch];
    if ( ent_glow>0 && IsValidEntity(ent_glow) && ent_glow>MAXPLAYERS && (GetEntProp(ent_glow, Prop_Send, "m_CollisionGroup")==0) )
       RemoveEntity(ent_glow);
    g_iGlowList[witch] = -1;

	return Plugin_Continue;
}


// // Thank you HarryPotter and Forgetest
//void BlockPlayerRangeCull(int client)
//{
//    static int offs_m_cullTimer = -1;
//    if (offs_m_cullTimer == -1) offs_m_cullTimer = FindSendPropInfo("CTerrorPlayer", "m_isCulling") + 4;
//    SetEntProp(client, Prop_Send, "m_isCulling", true);
//    SetEntDataFloat(client, offs_m_cullTimer + 8, GetGameTime() + 99999.9);
//} 

void ZM_Spawn_SI(int client, int ZOMBIECLASS)
{
	if (DEBUG) PrintToServer("[zm] ZM_Spawn_SI");
	if (!g_bCvarAllow || !IsValidClientZM() || client!=zm_client || ZOMBIECLASS<=0) return;
	
	update_t_zm_activity();
	
	int cost_SI = costs_SI[ZOMBIECLASS];
	if ((bank-cost_SI)<0)
	{
    	update_hint("Try getting a job?");
    	return;
	}
	
	UpdateLiveSI();
	if (live_SI>=max_SI || live_SI_arr[ZOMBIECLASS]>=max_unique_SI)
	{
    	update_hint("Limit reached.");
    	return;
	}
	
	if (!can_ZM_spawn()) return;
	
	int bot;
	if (ZOMBIECLASS==ZOMBIECLASS_TANK) bot = L4D2_SpawnTank(zm_spawner_pos,{0.0,0.0,0.0});
	else bot = L4D2_SpawnSpecial(ZOMBIECLASS,zm_spawner_pos,{0.0,0.0,0.0});
	
	// For now it's working OK but maybe these are more efficient.
	// Spawns a Tank
    //native int L4D2_SpawnTank(const float vecPos[3], const float vecAng[3]);
    // Spawns a Special Infected
    //native int L4D2_SpawnSpecial(int zombieClass, const float vecPos[3], const float vecAng[3]);
    
	
	//switch (ZOMBIECLASS)
	//{
    	//case ZOMBIECLASS_SMOKER: 
    	//{
    	//	bot = SDKCall(hCreateSmoker, "ZM Smoker");
    	//}
    	//case ZOMBIECLASS_BOOMER: 
    	//{
    	//	bot = SDKCall(hCreateBoomer, "ZM Boomer");
    	//}
    	//case ZOMBIECLASS_HUNTER: 
    	//{
    	//	bot = SDKCall(hCreateHunter, "ZM Hunter");
    	//}
    	//case ZOMBIECLASS_SPITTER: 
    	//{
    	//	bot = SDKCall(hCreateSpitter, "ZM Spitter");
    	//}
    	//case ZOMBIECLASS_JOCKEY: 
    	//{
    	//	bot = SDKCall(hCreateJockey, "ZM Jockey");
    	//}
    	//case ZOMBIECLASS_CHARGER: 
    	//{
    	//	bot = SDKCall(hCreateCharger, "ZM Charger");
    	//}
    	//case ZOMBIECLASS_TANK: 
    	//{
    		//bot = SDKCall(hCreateTank, "ZM Tank");
    	//}
	//}
	
	if (IsValidClient(bot))
	{
  //  	ChangeClientTeam(bot, TEAM_INFECTED);
  //  	SetEntProp(bot, Prop_Send, "m_usSolidFlags", 16);
  //  	
  //  	SetEntProp(bot, Prop_Send, "deadflag", 0);
  //  	SetEntProp(bot, Prop_Send, "m_lifeState", 0);
  //  	SetEntProp(bot, Prop_Send, "m_iObserverMode", 0);
  //  	SetEntProp(bot, Prop_Send, "m_iPlayerState", 0);
  //  	SetEntProp(bot, Prop_Send, "m_zombieState", 0);
  //  	DispatchSpawn(bot);
  //  	ActivateEntity(bot);
  //  	TeleportEntity(bot, zm_spawner_pos, NULL_VECTOR, NULL_VECTOR);
    	if (!zm_started)
    	{
        	SetEntProp(bot, Prop_Send, "movetype", 0);
        	SetEntProp(bot, Prop_Send, "m_fFlags", GetEntProp(bot, Prop_Send, "m_fFlags")|FL_FROZEN);
        	//BlockPlayerRangeCull(bot);
            //int ticktime = RoundToNearest(GetGameTime()/GetTickInterval()) + 5000000;
        	//SetEntProp(bot, Prop_Data, "m_nNextThinkTick", ticktime);
        	//L4D_State_Transition(bot,STATE_OBSERVER_MODE);
            //L4D_BecomeGhost(bot);
            //SetEntProp(bot, Prop_Send, "m_fFlags", GetEntProp(bot, Prop_Send, "m_fFlags")|FL_FROZEN);
            //SDKHook(bot, SDKHook_OnTakeDamage, OnTakeDamage_Units);
            //SDKHook(bot, SDKHook_OnTakeDamageAlive, OnTakeDamage_Units);
            //SDKHook(bot, SDKHook_OnTakeDamagePost, OnTakeDamage_Units);
            //SetEntProp(bot, Prop_Send, "m_isCulling", true);
            //SetEntDataFloat(bot, 13000 + 8, GetGameTime() + 99999.9);
            //SDKHook_Think
    	}
   // 	else SetEntProp(bot, Prop_Send, "movetype", 2);
    	bank -= cost_SI;
    	live_SI += 1;
    	zm_update(zm_timer);
    	CreateZMGlow(EntIndexToEntRef(bot));
    	
    	
	}
	else update_hint("Spawn failed.");
	
	
	// Lower SI "more allowed spawns" counter here, and add appropriate Timer to allow more SI spawns in the future.
    
	return;
}

//Action OnTakeDamage_Units(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
//{
        //PrintToServer("[zm] OnTakeDamage_Units");
//        int health = GetEntProp(victim, Prop_Data, "m_iHealth");
//        int max_health = GetEntProp(victim, Prop_Data, "m_iMaxHealth");
//        if (DEBUG) PrintToServer("[zm] Unit %d (%d/%d) taking %f damage from %d %d %d", victim, health, max_health, damage, attacker, inflictor, weapon);
        //if (!zm_started)
        
//        if (victim!=attacker)
//        {
//           SDKUnhook(victim, SDKHook_OnTakeDamageAlive, OnTakeDamage_Units);
//           SDKUnhook(victim, SDKHook_OnTakeDamage, OnTakeDamage_Units);
//           if (DEBUG) PrintToServer("[zm] Unit %d unhooked - no refunds", victim);
//        }
        
        // Unhook if unit takes damage from survivors -- no more refunds :)
        
//        return Plugin_Continue;
//} 

// L4D_IsPlayerGhost(client)  asdf for unfreeze of infected after round start

Action ZM_Smoker(int client, int args)
{
   ZM_Spawn_SI(client,ZOMBIECLASS_SMOKER);
   return Plugin_Continue;
}

Action ZM_Boomer(int client, int args)
{
   ZM_Spawn_SI(client,ZOMBIECLASS_BOOMER);
   return Plugin_Continue;
}

Action ZM_Hunter(int client, int args)
{
   ZM_Spawn_SI(client,ZOMBIECLASS_HUNTER);
   return Plugin_Continue;
}

Action ZM_Spitter(int client, int args)
{
   ZM_Spawn_SI(client,ZOMBIECLASS_SPITTER);
   return Plugin_Continue;
}

Action ZM_Jockey(int client, int args)
{
   ZM_Spawn_SI(client,ZOMBIECLASS_JOCKEY);
   return Plugin_Continue;
}

Action ZM_Charger(int client, int args)
{
   ZM_Spawn_SI(client,ZOMBIECLASS_CHARGER);
   return Plugin_Continue;
}

Action ZM_Tank(int client, int args)
{
   ZM_Spawn_SI(client,ZOMBIECLASS_TANK);
   return Plugin_Continue;
}

Action ZM_Delete(int client, int args)
{
   zm_del_pointing(client);
   return Plugin_Continue;
}

//delete_all_infected(bool common=true, bool witch=true, bool special=true)
Action ZM_Delete_All(int client, int args)
{
   if (IsValidClientZM() && client==zm_client) delete_all_infected(true,true,true);
   return Plugin_Continue;
}

Action ZM_Delete_Commons(int client, int args)
{
   if (IsValidClientZM() && client==zm_client) delete_all_infected(true,false,false);
   return Plugin_Continue;
}

Action ZM_Delete_Specials(int client, int args)
{
   if (IsValidClientZM() && client==zm_client) delete_all_infected(false,false,true);
   return Plugin_Continue;
}

Action ZM_Delete_Witches(int client, int args)
{
   if (IsValidClientZM() && client==zm_client) delete_all_infected(false,true,false);
   return Plugin_Continue;
}




void ResetCvars()
{
    if (DEBUG) PrintToServer("[zm] ResetCvars");
    ResetConVar(FindConVar("z_common_limit"), true, true);
    ResetConVar(FindConVar("z_no_cull"), true, true);
    //ResetConVar(FindConVar("z_background_limit"), true, true);
	ResetConVar(FindConVar("z_minion_limit"), true, true);
	ResetConVar(FindConVar("director_no_mobs"), true, true);
	ResetConVar(FindConVar("z_wandering_density"), true, true);
	ResetConVar(FindConVar("director_no_bosses"), true, true);
	ResetConVar(FindConVar("director_no_specials"), true, true);
	ResetConVar(FindConVar("director_panic_forever"), true, true);
	
	ResetConVar(FindConVar("z_discard_range"), true, true);
	ResetConVar(FindConVar("z_discard_min_range"), true, true);

	ResetConVar(FindConVar("survival_max_smokers"), true, true);
	ResetConVar(FindConVar("survival_max_boomers"), true, true);
	ResetConVar(FindConVar("survival_max_hunters"), true, true);
	ResetConVar(FindConVar("survival_max_spitters"), true, true);
	ResetConVar(FindConVar("survival_max_jockeys"), true, true);
	ResetConVar(FindConVar("survival_max_chargers"), true, true);
	ResetConVar(FindConVar("survival_max_specials"), true, true);
	ResetConVar(FindConVar("survival_special_limit_increase"), true, true);
	ResetConVar(FindConVar("survival_special_spawn_interval"), true, true);
	ResetConVar(FindConVar("survival_special_stage_interval"), true, true);
	ResetConVar(FindConVar("z_smoker_limit"), true, true);
	ResetConVar(FindConVar("z_boomer_limit"), true, true);
	ResetConVar(FindConVar("z_hunter_limit"), true, true);
	ResetConVar(FindConVar("z_spitter_limit"), true, true);
	ResetConVar(FindConVar("z_jockey_limit"), true, true);
	ResetConVar(FindConVar("z_charger_limit"), true, true);
	ResetConVar(FindConVar("director_allow_infected_bots"), true, true);
	ResetConVar(FindConVar("z_spawn_safety_range"), true, true);
	
	ResetConVar(FindConVar("z_max_player_zombies"), true,true);

}

// Re-run this if player number has changed
void SetCvarsZM()
{
   if (DEBUG) PrintToServer("[zm] SetCvarsZM");
   if (!g_bCvarAllow) return;
   
   SetConVarInt(FindConVar("z_common_limit"), 0);
   SetConVarInt(FindConVar("z_discard_min_range"), 9999999);
   SetConVarInt(FindConVar("z_discard_range"), 9999999);
   SetConVarInt(FindConVar("z_no_cull"), 1);
   SetConVarInt(FindConVar("z_minion_limit"), 0);
   SetConVarInt(FindConVar("director_no_mobs"), 1);
   SetConVarInt(FindConVar("z_wandering_density"), 0);
   SetConVarInt(FindConVar("director_no_bosses"), 1);
   SetConVarInt(FindConVar("director_no_specials"), 1);
   SetConVarInt(FindConVar("director_allow_infected_bots"), 0);
   
   // z_mega_mob_size
   // z_mob_spawn_max_size
   // z_mob_spawn_min_size
   
   // This needs to be done more carefully - what if more players join later?
   if (g_iMaxSI<0) max_SI = g_iPlayersInSurvivorTeam;
   else max_SI = g_iMaxSI;
   if ((MaxClients-AllPlayerCount)<max_SI)
   {
      max_SI = MaxClients-AllPlayerCount;
   }
   
   if (g_iMaxWitches<0) max_witches = g_iPlayersInSurvivorTeam;
   else max_witches = g_iMaxWitches;
   
   if (g_iMaxUniqueSI<0) max_unique_SI = RoundToCeil(max_SI/2.0);
   else max_unique_SI = g_iMaxUniqueSI;
   
   SetConVarInt(FindConVar("survival_max_specials"), max_SI);
   SetConVarInt(FindConVar("z_max_player_zombies"), max_SI);
   
   SetConVarInt(FindConVar("survival_max_smokers"), max_unique_SI);
   SetConVarInt(FindConVar("survival_max_boomers"), max_unique_SI);
   SetConVarInt(FindConVar("survival_max_hunters"), max_unique_SI);
   SetConVarInt(FindConVar("survival_max_spitters"), max_unique_SI);
   SetConVarInt(FindConVar("survival_max_jockeys"), max_unique_SI);
   SetConVarInt(FindConVar("survival_max_chargers"), max_unique_SI);
   

   SetConVarInt(FindConVar("z_smoker_limit"), max_unique_SI);
   SetConVarInt(FindConVar("z_boomer_limit"), max_unique_SI);
   SetConVarInt(FindConVar("z_hunter_limit"), max_unique_SI);
   SetConVarInt(FindConVar("z_spitter_limit"), max_unique_SI);
   SetConVarInt(FindConVar("z_jockey_limit"), max_unique_SI);
   SetConVarInt(FindConVar("z_charger_limit"), max_unique_SI);
   
}


bool IsValidClient(int client, bool replaycheck = true)
{
	if (client < 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (replaycheck)
	{
		if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	}
	return true;
}

//bool RealValidEntity(int entity)
//{
//	return (entity > 0 && IsValidEntity(entity));
//}

void PluginPrecacheModel(const char[] model)
{
	if (!IsModelPrecached(model)) PrecacheModel(model, true);
}

public void OnMapStart()
{
    if (DEBUG) PrintToServer("[zm] OnMapStart");
    //if (!g_bCvarAllow) return;
	
	PluginPrecacheModel(MODEL_SMOKER);
	PluginPrecacheModel(MODEL_BOOMER);
	PluginPrecacheModel(MODEL_HUNTER);
	PluginPrecacheModel(MODEL_SPITTER);
	PluginPrecacheModel(MODEL_JOCKEY);
	PluginPrecacheModel(MODEL_CHARGER);
	PluginPrecacheModel(MODEL_TANK);
	
	g_iLaser = PrecacheModel(VMT_LASERBEAM, true);
	g_iHalo = PrecacheModel(VMT_HALO, true);
	
	PrecacheSound(SOUND_READY);
    PrecacheSound(SOUND_START);
    PrecacheSound(SOUND_VISION);
    
    PrecacheSound(SOUND_PANIC_ON);
    PrecacheSound(SOUND_PANIC_OFF);
    
    PrecacheSound(SOUND_SCARY1);
    PrecacheSound(SOUND_SCARY2);
    PrecacheSound(SOUND_SCARY3);
    PrecacheSound(SOUND_SCARY4);
    PrecacheSound(SOUND_SCARY5);
	
	//CountCommons(false);
	//g_iEntities = GetEntityCountEx();
	//CountWitches(false);
	//UpdateLiveSI(false);

	g_bSpawnWitchBride = false;
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	if(StrEqual("c6m1_riverbank", sMap, false)) g_bSpawnWitchBride = true;
	else g_bSpawnWitchBride = false;
    
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse)
{
    if (!g_bCvarAllow || !IsValidClient(client)) return;
	if(impulse==100) toggle_ZM_vision(client);	
}

public void OnMapEnd()
{
	if (DEBUG) PrintToServer("[zm] OnMapEnd");
	if (ZM_menu!=null) ZM_menu.Cancel();
	g_iLockedDoor = SAFEROOM_UNKNOWN; // we don't know if there's gonna be a door next map
	ResetTimer();
	fog_entity = -1;
	rain_entity = -1;
	snow_entity = -1;
}

// Merge with countSI since we're going over maxplayers anyway
void CountAliveSurvivors()
{
	if (!g_bCvarAllow) return;
	if (DEBUG) PrintToServer("[zm] CountAliveSurvivors");
	int iPlayersInAliveSurvivors=0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		switch(GetClientTeam(i))
		{
			case TEAM_SURVIVOR:
			{
				if(IsPlayerAlive(i)) iPlayersInAliveSurvivors++;
			}
		}
	}
    
    if (iPlayersInAliveSurvivors!=g_iPlayersInSurvivorTeam)
    {
       g_iPlayersInSurvivorTeam = iPlayersInAliveSurvivors;
       SetCvarsZM();
       zm_update(zm_timer);
    }
    
}

void ResetTimer()
{
 if (DEBUG) PrintToServer("[zm] ResetTimer");
 delete zm_timer;
}




public void OnConfigsExecuted()
{
	//g_hCvarMPGameMode.GetString(g_sCvarMPGameMode, sizeof(g_sCvarMPGameMode));
	//LoadData();
    if (DEBUG) PrintToServer("[zm] OnConfigsExecuted");
	IsAllowed();

	//g_bConfigsExecuted = true;
}

void PanicEventStarted(Event event, const char[] name, bool dontBroadcast)
{
	
	if (strcmp(g_sCvarMPGameMode, "survival", false) == 0) return;
	
	if (DEBUG) PrintToServer("[zm] PanicEventStarted");
	
	//SetPendingMobCount(0);
	if ((GetEngineTime()-t_last_panic)<t_panic_overlap)
	{
    	if (DEBUG) PrintToServer("[zm] Overlap detected, ignoring");
    	return;
	}
	
	if (zm_started)
    {
        bank += g_iBonusCarAlarm;
        //PrintToChatAll("[zm] ZM awarded %d zombux and free panic for car alarm!", g_iBonusCarAlarm);
        if (!panic)
        {
            manual_panic=false; // panic hasn't run yet - means it wasn't started by ZM
            toggle_panic(true,true,true); // free panic!
        }
        else bank += g_iPanicCost;
        zm_update(zm_timer);
    }
}

void evtRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	
	if (DEBUG) PrintToServer("[zm] evtRoundEnd");
	g_iLockedDoor = SAFEROOM_UNKNOWN;
	saferoom_locked = false;
    if (ZM_finale_announced) ZM_finale_ended = true;
	if (ZM_menu!=null) ZM_menu.Cancel();
	ResetTimer();
	
	// InputKill prevention
	if (IsValidClientZM())
	{
    	//ChangeClientTeam(zm_client,TEAM_SPECTATOR);
    	QuitZM(zm_client,0);
	}
}

void evtRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (DEBUG) PrintToServer("[zm] evtRoundStart");
	g_iLockedDoor = SAFEROOM_UNKNOWN;
	saferoom_locked = false;
	if (ZM_menu!=null) ZM_menu.Cancel();
	zm_new_round();
	//toggle_panic(false,true); //set panic to false, override
}

// This needs to be fixed, survival start and zombies should be allowed to spawn when panic is triggered
void Event_SurvivalRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	
	if (!g_bCvarAllow) return;
	if (DEBUG) PrintToServer("[zm] Event_SurvivalRoundStart");
	
    manual_panic = false;
    start_zm_round();
    zm_update(zm_timer);
}

// L4D_GetRandomPZSpawnPosition(anyclient,ZOMBIECLASS_SMOKER,ZOMBIESPAWN_Attempts,vecPos) == true

// dymnamic panic:
//  player_incapacitated

void IsAllowed()
{
	if (DEBUG) PrintToServer("[zm] IsAllowed");
	bool bCvarAllow = g_hCvarAllow.BoolValue;

	if(!g_bCvarAllow && bCvarAllow)
	{
		g_bCvarAllow = true;

		HookEvent("round_start", evtRoundStart,		EventHookMode_PostNoCopy);
		HookEvent("survival_round_start",Event_SurvivalRoundStart,EventHookMode_PostNoCopy);
		HookEvent("round_end",				evtRoundEnd,		EventHookMode_PostNoCopy); //trigger twice in versus mode, one when all survivors wipe out or make it to saferom, one when first round ends (second round_start begins).
		HookEvent("map_transition", 		evtRoundEnd,		EventHookMode_PostNoCopy); //all survivors make it to saferoom, and server is about to change next level in coop mode (does not trigger round_end) 
		HookEvent("mission_lost", 			evtRoundEnd,		EventHookMode_PostNoCopy); //all survivors wipe out in coop mode (also triggers round_end)
		HookEvent("finale_vehicle_leaving", evtRoundEnd,		EventHookMode_PostNoCopy); //final map final rescue vehicle leaving  (does not trigger round_end)
	    HookEvent("create_panic_event", PanicEventStarted,		EventHookMode_PostNoCopy);
	    HookEvent("triggered_car_alarm", Event_TriggeredCarAlarm, EventHookMode_PostNoCopy);
		HookEvent("player_death", evtPlayerDeath, EventHookMode_Pre);
		HookEvent("player_incapacitated", evtPlayerIncap, EventHookMode_Pre);
		HookEvent("player_team", evtPlayerTeam);
		//HookEvent("player_spawn", evtPlayerSpawn);
		HookEvent("finale_start", 			evtFinaleStart, EventHookMode_PostNoCopy); //final starts, some of final maps won't trigger
		HookEvent("finale_radio_start", 	evtFinaleStart, EventHookMode_PostNoCopy); //final starts, all final maps trigger
		HookEvent("gauntlet_finale_start", 	evtFinaleStart, EventHookMode_PostNoCopy); //final starts, only rushing maps trigger (C5M5, C13M4)
		HookEvent("player_spawn", evtPlayerSpawned);
		HookEvent("player_left_start_area", evt_ZM_start_imminent);
		HookEvent("player_left_checkpoint", evt_ZM_start_imminent);
		//HookEvent("player_incapacitated", Event_Incap); //if panic is on and incap happened to survivor, look for another target
		HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);
		
		HookEvent("finale_vehicle_ready", EvtFinaleEnding, EventHookMode_PostNoCopy);
		HookEvent("finale_vehicle_incoming", EvtFinaleEnding, EventHookMode_PostNoCopy);
		
		HookEvent("witch_killed", EvtWitchKilled);
		
		GetCvars();
		SetCvarsZM();
		
		if (!dd_failed)
		{
		if (!g_dd_CTerrorPlayer_StartRangeCull.Enable(Hook_Pre,StartRangeCull_Pre))
		   SetFailState("Failed to detour: \"ZM::CTerrorPlayer::StartRangeCull\"");
		}
		
		ServerCommand("sm_cvar mp_restartgame 1");
		// if sounds, models are not precached...
		//char map[PLATFORM_MAX_PATH];
		//GetCurrentMap(map, sizeof(map));
		//ForceChangeLevel(map, "ZM Started");
		
		
	}
    
	else if(g_bCvarAllow && !bCvarAllow)
	{
		OnPluginEnd();
		g_bCvarAllow = false;
		
		//Add unhooks here
		UnhookEvent("round_start", evtRoundStart,		EventHookMode_PostNoCopy);
		UnhookEvent("survival_round_start",Event_SurvivalRoundStart,EventHookMode_PostNoCopy);
		UnhookEvent("round_end",				evtRoundEnd,		EventHookMode_PostNoCopy); //trigger twice in versus mode, one when all survivors wipe out or make it to saferom, one when first round ends (second round_start begins).
		UnhookEvent("map_transition", 		evtRoundEnd,		EventHookMode_PostNoCopy); //all survivors make it to saferoom, and server is about to change next level in coop mode (does not trigger round_end) 
		UnhookEvent("mission_lost", 			evtRoundEnd,		EventHookMode_PostNoCopy); //all survivors wipe out in coop mode (also triggers round_end)
		UnhookEvent("finale_vehicle_leaving", evtRoundEnd,		EventHookMode_PostNoCopy); //final map final rescue vehicle leaving  (does not trigger round_end)
	    UnhookEvent("create_panic_event", PanicEventStarted,		EventHookMode_PostNoCopy);
	    UnhookEvent("triggered_car_alarm", Event_TriggeredCarAlarm, EventHookMode_PostNoCopy);
		UnhookEvent("player_death", evtPlayerDeath, EventHookMode_Pre);
		UnhookEvent("player_incapacitated", evtPlayerIncap, EventHookMode_Pre);
		UnhookEvent("player_team", evtPlayerTeam);
		//HookEvent("player_spawn", evtPlayerSpawn);
		UnhookEvent("finale_start", 			evtFinaleStart, EventHookMode_PostNoCopy); //final starts, some of final maps won't trigger
		UnhookEvent("finale_radio_start", 	evtFinaleStart, EventHookMode_PostNoCopy); //final starts, all final maps trigger
		UnhookEvent("gauntlet_finale_start", 	evtFinaleStart, EventHookMode_PostNoCopy); //final starts, only rushing maps trigger (C5M5, C13M4)
		UnhookEvent("player_spawn", evtPlayerSpawned);
		UnhookEvent("player_left_start_area", evt_ZM_start_imminent);
		UnhookEvent("player_left_checkpoint", evt_ZM_start_imminent);
		//HookEvent("player_incapacitated", Event_Incap); //if panic is on and incap happened to survivor, look for another target
		UnhookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);
		
		UnhookEvent("finale_vehicle_ready", EvtFinaleEnding, EventHookMode_PostNoCopy);
		UnhookEvent("finale_vehicle_incoming", EvtFinaleEnding, EventHookMode_PostNoCopy);
		
		UnhookEvent("witch_killed", EvtWitchKilled);
		
		if (!dd_failed)
		{
		if (!g_dd_CTerrorPlayer_StartRangeCull.Disable(Hook_Pre,StartRangeCull_Pre))
		   SetFailState("Failed to detour: \"ZM::CTerrorPlayer::StartRangeCull\"");
		}
		
		ServerCommand("sm_cvar mp_restartgame 1");
	}

	
}

MRESReturn StartRangeCull_Pre(int entity)
{
	PrintToServer("[zm] StartRangeCull_Pre");
	if (!zm_started) return MRES_Supercede;
	return MRES_Ignored;
}

//public Action OnCheatCommand(int client, const char[] command, int argc)
//{
//	PrintToServer("[zm] OnCheatCommand");
//	if (g_bCvarAllow)
//	{
//    	return Plugin_Continue;
//	}
//	return Plugin_Handled;
//}

public void OnPluginEnd()
{
    if (DEBUG) PrintToServer("[zm] OnPluginEnd");
    ResetCvars();
    ResetTimer();
    if (IsValidClientZM()) ChangeClientTeam(zm_client,TEAM_SURVIVOR);
    zm_client = -1;
    if (saferoom_locked) saferoom_lock(false);
}


public Action EvtFinaleEnding(Handle hEvent, char[] Name, bool dontBroastcast)
{
    if (DEBUG) PrintToServer("[zm] EvtFinaleEnding");
    if (ZM_finale_announced) ZM_finale_ended = true;
    else PrintToServer("[zm] Finale ending before it started??? WHAT THE ACTUAL FUCK");
    return Plugin_Continue;
}

// We could common infected models for more variety
//PrecacheModel("models/infected/common_male_riot.mdl", true);
//PrecacheModel("models/infected/common_male_ceda.mdl", true);
//PrecacheModel("models/infected/common_male_clown.mdl", true);
//PrecacheModel("models/infected/common_male_mud.mdl", true);
//PrecacheModel("models/infected/common_male_roadcrew.mdl", true);
//PrecacheModel("models/infected/common_male_jimmy.mdl", true);
//PrecacheModel("models/infected/common_male_fallen_survivor.mdl", true);

public Action Event_TriggeredCarAlarm(Handle hEvent, char[] Name, bool dontBroastcast)
{
    if (strcmp(g_sCvarMPGameMode, "survival", false) == 0) return Plugin_Continue;
    if (DEBUG) PrintToServer("[zm] Event_TriggeredCarAlarm");
    if (zm_started)
    {
        bank += g_iBonusCarAlarm;
        PrintToChatAll("[zm] ZM awarded %d zombux and free panic for car alarm!", g_iBonusCarAlarm);
        if (!panic)
        {
            manual_panic=true;
            toggle_panic(true,true,true); // free panic!
        }
        else bank += g_iPanicCost;
    }

    return Plugin_Continue;
}

void Event_PlayerDisconnect(Event event, char[] name, bool bDontBroadcast)
{
    if (DEBUG) PrintToServer("[zm] Event_PlayerDisconnect");
    if (g_bCvarAllow)
    {
       int client = GetClientOfUserId(event.GetInt("userid"));
       if (zm_client==client)
       {
   	      zm_client=-1;
   	      update_t_zm_activity(0.0); // instantly starts printing the "no ZM" message
   	      zm_menu_IsOpen = false;
   	      ZM_menu.Cancel();
   	      if (!zm_started && !zm_can_start) can_zm_start();
   	   }
   	   
   	   if (zm_started || zm_timer==null) zm_update(zm_timer);
    }
}

void evtPlayerSpawned(Event event, const char[] name, bool dontBroadcast)
{
    if (DEBUG) PrintToServer("[zm] evtPlayerSpawned");
    
    if (g_bCvarAllow)
    {
       //if (zm_started)
       //{
           UpdateLiveSI();
           CountAliveSurvivors();
       //}
       if (g_iLockedDoor==SAFEROOM_UNKNOWN) check_saferoom();
       if (zm_timer == null) zm_update(zm_timer);
       if (g_bLockSaferoom && g_iLockedDoor<0 && saferoom_locked)
       {
           int userid = event.GetInt("userid");
       	   int client = GetClientOfUserId(userid);
       	   freeze_player(client,true,TEAM_SURVIVOR);
   	   }
       
       
       
    }
}

void evtPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (DEBUG) PrintToServer("[zm] evtPlayerTeam");
	if (g_bCvarAllow)
    {
       int client = GetClientOfUserId(event.GetInt("userid"));
       if (zm_client==client)
       {
   	      if (GetClientTeam(zm_client)==TEAM_SURVIVOR)
   	      {
   	         zm_client=-1;
   	         update_t_zm_activity(0.0); // instantly starts printing the "no ZM" message
   	         zm_update(zm_timer);
   	      }
   	   }
       CountAliveSurvivors();
       UpdateLiveSI();
    }
}

void evt_ZM_start_imminent(Event event, const char[] name, bool dontBroadcast)
{
    if (g_bCvarAllow && !zm_started) zm_update(zm_timer);
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
  if (g_bCvarAllow && !zm_started) zm_update(zm_timer);
  return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	if(!g_bCvarAllow) return;
	if (DEBUG) PrintToServer("[zm] OnClientPutInServer");
	
	if (!IsFakeClient(client))
	{
    	t_last_join = GetEngineTime();
    	if (DEBUG) PrintToServer("[zm] t_last_join updated");
    	//if (!zm_started && !zm_can_start) can_zm_start();
    	
	}
	
	if (zm_started || zm_timer == null) zm_update(zm_timer);
}

public void OnClientDisconnect(int client)
{
	if (g_bCvarAllow)
	{
	   if (DEBUG) PrintToServer("[zm] OnClientDisconnect");

       UpdateLiveSI();
       CountAliveSurvivors();

       if (zm_client==client)
       {
   	      zm_client=-1;
   	      update_t_zm_activity(0.0);
   	      zm_menu_IsOpen = false;
   	      ZM_menu.Cancel();
   	      if (!zm_started) can_zm_start();
   	   } 
    }
	

}

// Refund zombie delete
public void OnEntityDestroyed(int entity)
{
    if ( !g_bCvarAllow || entity == INVALID_ENT_REFERENCE) return;
    
    // Refund despawned zombies
	if (zm_started || zm_deleted)
	{
	   int max_health = GetEntProp(entity,Prop_Data,"m_iMaxHealth");
	   //if (DEBUG) PrintToServer("[zm] OnEntityDestroyed MaxHP %d", max_health);
	   if (max_health && max_health>0)
	   {
    	   int health = GetEntProp(entity,Prop_Data,"m_iHealth");
    	   
    	   // Immediately update ZM info
    	   //CountWitches();
    	   //asdf
    	   
    	   if (health<max_health) return;
           
           static char class[32];
       	   GetEntityClassname(entity, class, sizeof(class));
       	  
       	  int bank_refund = 0;
       	  
       	  if (strcmp(class,"infected")==0)
       	  {
       	     bank_refund=g_iCostCommon;
   	      }
       	  else if (strcmp(class,"witch")==0)
       	  {
       	     // Figuring out if witch is stationary or moving
       	     bank_refund = -1;
       	     int m_nSequence = GetEntProp(entity,Prop_Data,"m_nSequence");
       	     if (m_nSequence==4 || m_nSequence==27)
       	     {
           	     bank_refund = g_iCostWitchStatic;
           	     if (DEBUG) PrintToServer("[zm] Refunding static witch");
       	     }
       	     else if (m_nSequence==10 || m_nSequence==11 || m_nSequence==2)
       	     {
           	     bank_refund = g_iCostWitchMoving;
           	     if (DEBUG) PrintToServer("[zm] Refunding moving witch");
       	     }
       	     if (bank_refund<0)
       	     {
           	     if (DEBUG) PrintToServer("[zm] Refunding cheapest witch");
           	     if (g_hCostWitchStatic<g_hCostWitchMoving) bank_refund=g_iCostWitchStatic;
           	     else bank_refund=g_iCostWitchMoving;
       	     }
       	  }
       	  else if (strcmp(class,"player")==0 && GetClientTeam(entity)==TEAM_INFECTED)
       	  {
           	 int zClass = GetEntProp(entity, Prop_Send, "m_zombieClass");
             if (zClass<ZOMBIECLASS_SMOKER || zClass>ZOMBIECLASS_TANK || zClass==7) return;
             bank_refund = costs_SI[zClass];
             
             // Prevent tanks from being refunded during finales and survival
             if (zClass==ZOMBIECLASS_TANK && (ZM_finale_announced || strcmp(g_sCvarMPGameMode, "survival", false) == 0 ))
             {
                 bank_refund = 0;
             }
             
       	  }
       	  else return;
       	  
       	  //zm_deleted = false;
       	  
       	  if (bank_refund>0)
       	  {
           	  bank += bank_refund;
           	  //PrintToServer("Refunded %d", bank_refund);
       	  }
 	       
    	   
	   }
	}
    
}



int RGB_ZM = 16777215; // white
// asdf weird glitches when zm is out of bounds need to be fixed
void CreateZMGlow(int targetRef)
{
	if (!IsValidEntRef(targetRef)) return;
	int target = EntRefToEntIndex(targetRef);
	if (!IsValidEntity(target)) return;
	if (DEBUG) PrintToServer("[zm] CreateZMGlow");
	
	int glow = CreateEntityByName("prop_dynamic_ornament");
	//int glow = CreateEntityByName("prop_dynamic");
	if (!IsEntitySafe(glow)) return;
	
	char sModelName[64];
	GetEntPropString(target, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
	
	SetEntityModel(glow, sModelName);
	DispatchSpawn(glow);
	SetEntProp(glow, Prop_Send, "m_CollisionGroup", 0);
	SetEntProp(glow, Prop_Send, "m_nSolidType", 0);
	SetEntProp(glow, Prop_Send, "m_nGlowRangeMin", 0);
	SetEntProp(glow, Prop_Send, "m_nGlowRange", 999999);
	SetEntProp(glow, Prop_Send, "m_iGlowType", 3);
	SetEntProp(glow, Prop_Send, "m_glowColorOverride", RGB_ZM);
	AcceptEntityInput(glow, "StartGlowing");
	SetEntityRenderMode(glow, RENDER_TRANSCOLOR);
	SetEntityRenderColor(glow, 0, 0, 0, 0);
	SetVariantString("!activator");
	AcceptEntityInput(glow, "SetParent", target);
	SetVariantString("!activator");
	AcceptEntityInput(glow, "SetAttached", target);
    g_iGlowList[target] = glow;
	SDKHook(glow, SDKHook_SetTransmit, OnTransmitZM);
}

bool IsEntitySafe(int entity)
{
	if(entity == -1) return false;
	if(entity >= ENTITY_SAFER_LIMIT)
	{
		RemoveEntity(entity);
		return false;
	}
	return true;
}

// Handled: invisible
// Continue: visible
Action OnTransmitZM(int entity, int client)
{
	if(GetClientTeam(client) == TEAM_SURVIVOR) return Plugin_Handled;
	return Plugin_Continue;
}



#define FUNCTION_PATCH "Tank::GetIntentionInterface::Intention"
#define FUNCTION_PATCH2 "Action<Tank>::FirstContainedResponder"
#define FUNCTION_PATCH3 "TankIdle::GetName"

int g_iIntentionOffset;
Handle g_hSDKFirstContainedResponder;
Handle g_hSDKGetName;

GameData hGameData;
void GetGameData()
{
	if (DEBUG) PrintToServer("[zm] GetGameData");
	hGameData = LoadGameConfigFile(GAMEDATA_FILE);
	
	//pZombieManager = GameConfGetAddress(hGameData, "ZombieManager");
	//if (!pZombieManager)
	//{
	//	SetFailState("Couldn't find the 'ZombieManager' address");
	//	PrintToServer("[zm] ZombieManager address failed!!!!!!");
	//}
	
	if( hGameData != null )
	{
		PrepSDKCall();
	}
	else
	{
		SetFailState("Unable to find l4d2_zombie_master.txt gamedata file.");
	}
	delete hGameData;
}

bool g_bL4D2Version = true;
void PrepSDKCall()
{
	if(g_bL4D2Version)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "FlashLightTurnOn");
		hFlashLightTurnOn = EndPrepSDKCall();
		
		//StartPrepSDKCall(SDKCall_Player);
		//PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::StartRangeCull");
		//StartRangeCull = EndPrepSDKCall(); 
		
	}
	else
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "FlashlightIsOn");
		hFlashLightTurnOn = EndPrepSDKCall();
	}
	if (hFlashLightTurnOn == null)
		SetFailState("FlashLightTurnOn Signature broken");
    
    //if (StartRangeCull == null)
	//	SetFailState("StartRangeCull Signature broken");
    
	//find create bot signature
	Address replaceWithBot = GameConfGetAddress(hGameData, "NextBotCreatePlayerBot.jumptable");
	if (replaceWithBot != Address_Null && LoadFromAddress(replaceWithBot, NumberType_Int8) == 0x68) {
		// We're on L4D2 and linux
		PrepWindowsCreateBotCalls(replaceWithBot);
	}
	else
	{
		if (g_bL4D2Version)
		{
			PrepL4D2CreateBotCalls();
		}
		else
		{
			delete hCreateSpitter;
			delete hCreateJockey;
			delete hCreateCharger;
		}

		PrepL4D1CreateBotCalls();
	}

	g_iIntentionOffset = hGameData.GetOffset(FUNCTION_PATCH);
	if (g_iIntentionOffset == -1)
	{
		SetFailState("Failed to load offset: %s", FUNCTION_PATCH);
	}

	int iOffset = hGameData.GetOffset(FUNCTION_PATCH2);
	if (g_iIntentionOffset == -1)
	{
		SetFailState("Failed to load offset: %s", FUNCTION_PATCH2);
	}
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetVirtual(iOffset);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKFirstContainedResponder = EndPrepSDKCall();
	if (g_hSDKFirstContainedResponder == null)
	{
		SetFailState("Your \"%s\" offsets are outdated.", FUNCTION_PATCH2);
	}

	iOffset = hGameData.GetOffset(FUNCTION_PATCH3);
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetVirtual(iOffset);
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Plain);
	g_hSDKGetName = EndPrepSDKCall();
	if (g_hSDKGetName == null)
	{
		SetFailState("Your \"%s\" offsets are outdated.", FUNCTION_PATCH3);
	}

    g_dd_CTerrorPlayer_StartRangeCull = DynamicDetour.FromConf(hGameData, "ZM::CTerrorPlayer::StartRangeCull");
    if (!g_dd_CTerrorPlayer_StartRangeCull)
    {
        //SetFailState("Failed to create DynamicDetour: \"ZM::CTerrorPlayer::StartRangeCull\"");
        PrintToServer("[zm] DynamicDetour ZM::CTerrorPlayer::StartRangeCull failed");
        dd_failed = true;
    }

	delete hGameData;
}

void LoadStringFromAdddress(Address addr, char[] buffer, int maxlength) {
	int i = 0;
	while(i < maxlength) {
		char val = LoadFromAddress(addr + view_as<Address>(i), NumberType_Int8);
		if(val == 0) {
			buffer[i] = 0;
			break;
		}
		buffer[i] = val;
		i++;
	}
	buffer[maxlength - 1] = 0;
}

Handle PrepCreateBotCallFromAddress(Handle hSiFuncTrie, const char[] siName) {
	Address addr;
	StartPrepSDKCall(SDKCall_Static);
	if (!GetTrieValue(hSiFuncTrie, siName, addr) || !PrepSDKCall_SetAddress(addr))
	{
		SetFailState("Unable to find NextBotCreatePlayer<%s> address in memory.", siName);
		return null;
	}
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	return EndPrepSDKCall();
}

void PrepWindowsCreateBotCalls(Address jumpTableAddr) {
	Handle hInfectedFuncs = CreateTrie();
	// We have the address of the jump table, starting at the first PUSH instruction of the
	// PUSH mem32 (5 bytes)
	// CALL rel32 (5 bytes)
	// JUMP rel8 (2 bytes)
	// repeated pattern.

	// Each push is pushing the address of a string onto the stack. Let's grab these strings to identify each case.
	// "Hunter" / "Smoker" / etc.
	for(int i = 0; i < 7; i++) {
		// 12 bytes in PUSH32, CALL32, JMP8.
		Address caseBase = jumpTableAddr + view_as<Address>(i * 12);
		Address siStringAddr = view_as<Address>(LoadFromAddress(caseBase + view_as<Address>(1), NumberType_Int32));
		static char siName[32];
		LoadStringFromAdddress(siStringAddr, siName, sizeof(siName));

		Address funcRefAddr = caseBase + view_as<Address>(6); // 2nd byte of call, 5+1 byte offset.
		int funcRelOffset = LoadFromAddress(funcRefAddr, NumberType_Int32);
		Address callOffsetBase = caseBase + view_as<Address>(10); // first byte of next instruction after the CALL instruction
		Address nextBotCreatePlayerBotTAddr = callOffsetBase + view_as<Address>(funcRelOffset);
		//PrintToServer("Found NextBotCreatePlayerBot<%s>() @ %08x", siName, nextBotCreatePlayerBotTAddr);
		SetTrieValue(hInfectedFuncs, siName, nextBotCreatePlayerBotTAddr);
	}

	hCreateSmoker = PrepCreateBotCallFromAddress(hInfectedFuncs, "Smoker");
	if (hCreateSmoker == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateSmoker); return; }

	hCreateBoomer = PrepCreateBotCallFromAddress(hInfectedFuncs, "Boomer");
	if (hCreateBoomer == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateBoomer); return; }

	hCreateHunter = PrepCreateBotCallFromAddress(hInfectedFuncs, "Hunter");
	if (hCreateHunter == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateHunter); return; }

	hCreateTank = PrepCreateBotCallFromAddress(hInfectedFuncs, "Tank");
	if (hCreateTank == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateTank); return; }

	hCreateSpitter = PrepCreateBotCallFromAddress(hInfectedFuncs, "Spitter");
	if (hCreateSpitter == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateSpitter); return; }

	hCreateJockey = PrepCreateBotCallFromAddress(hInfectedFuncs, "Jockey");
	if (hCreateJockey == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateJockey); return; }

	hCreateCharger = PrepCreateBotCallFromAddress(hInfectedFuncs, "Charger");
	if (hCreateCharger == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateCharger); return; }

	delete hInfectedFuncs;
}

void PrepL4D2CreateBotCalls() {
	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, NAME_CreateSpitter))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateSpitter); return; }
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	hCreateSpitter = EndPrepSDKCall();
	if (hCreateSpitter == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateSpitter); return; }

	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, NAME_CreateJockey))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateJockey); return; }
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	hCreateJockey = EndPrepSDKCall();
	if (hCreateJockey == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateJockey); return; }

	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, NAME_CreateCharger))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateCharger); return; }
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	hCreateCharger = EndPrepSDKCall();
	if (hCreateCharger == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateCharger); return; }
}

void PrepL4D1CreateBotCalls() 
{
	bool bLinuxOS = hGameData.GetOffset("OS") != 0;
	if(bLinuxOS)
	{
		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, NAME_CreateSmoker))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateSmoker); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateSmoker = EndPrepSDKCall();
		if (hCreateSmoker == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateSmoker); return; }

		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, NAME_CreateBoomer))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateBoomer); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateBoomer = EndPrepSDKCall();
		if (hCreateBoomer == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateBoomer); return; }

		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, NAME_CreateHunter))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateHunter); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateHunter = EndPrepSDKCall();
		if (hCreateHunter == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateHunter); return; }

		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, NAME_CreateTank))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateTank); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateTank = EndPrepSDKCall();
		if (hCreateTank == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateTank); return; }
	}
	else
	{
		Address addr;

		addr = RelativeJumpDestination(hGameData.GetAddress(NAME_CreateSmoker_L4D1));
		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetAddress(addr))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateSmoker_L4D1); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateSmoker = EndPrepSDKCall();
		if(hCreateSmoker == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateSmoker_L4D1); return; }

		addr = RelativeJumpDestination(hGameData.GetAddress(NAME_CreateBoomer_L4D1));
		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetAddress(addr))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateBoomer_L4D1); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateBoomer = EndPrepSDKCall();
		if(hCreateSmoker == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateBoomer_L4D1); return; }

		addr = RelativeJumpDestination(hGameData.GetAddress(NAME_CreateHunter_L4D1));
		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetAddress(addr))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateHunter_L4D1); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateHunter = EndPrepSDKCall();
		if(hCreateHunter == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateHunter_L4D1); return; }

		addr = RelativeJumpDestination(hGameData.GetAddress(NAME_CreateTank_L4D1));
		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetAddress(addr))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateTank_L4D1); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateTank = EndPrepSDKCall();
		if(hCreateTank == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateTank_L4D1); return; }
	}
}

Address RelativeJumpDestination(Address p)
{
	int offset = LoadFromAddress(p, NumberType_Int32);
	return p + view_as<Address>(offset + 4);
}

//SetPendingMobCount(count)
//{
//	//return StoreToAddress(pZombieManager + Address:528, count, NumberType_Int32);
//	return StoreToAddress(pZombieManager + view_as<Address>(528), count, NumberType_Int32);
//}

//public Action:L4D_OnGetScriptValueInt(const String:key[], &retVal)
//{
//    if (StrEqual(key,"CommonLimit"))
//    {
//        if (retVal != iCommonLimit)
//        {
//            retVal = iCommonLimit;
//            return Plugin_Handled;
//        }
//    }
//    return Plugin_Continue;
//}



// Made for the Knockout.chat community
// HUGE THANKS TO TESTERS: zyiks, IronBar, ngh, Hatsune Miku Fan, Raykeno, Lil Ole Fella, ShaunOfTheLive
// Chance, Skerion
// HUGE THANKS for plugin development guidance: zyiks, HarryPotter, xerox8521, Forgetest
// HUGE THANKS TO Reagy and IronBar for hosting the Knockout Left 4 Dead 2 Server