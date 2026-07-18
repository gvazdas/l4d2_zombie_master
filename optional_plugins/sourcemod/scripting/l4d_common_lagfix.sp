#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_NAME			    "l4d_common_lagfix"
#define PLUGIN_VERSION 			"1.07"
#define CONFIG_FILENAME         PLUGIN_NAME
#define DEBUG 0

public Plugin myinfo =
{
	name = "[L4D1/L4D2] Common Lagfix",
	author = "gvazdas, SilverShot",
	description = "Reduce lag due to dynamic load of materials for Common Infected on Linux servers.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2843590, https://knockout.chat/user/3022"
}

ArrayList g_AllModels; // all infected models
bool g_bClientsCached[MAXPLAYERS+1] = {true,...}; // check if already cached for client
int g_iModel[MAXPLAYERS+1]; // track model in cycle for client
int g_iCycle[MAXPLAYERS+1] = {-1,...}; // track cycle for client. -1 indicates they are not in cycle
int g_iInfectedRef[MAXPLAYERS+1]; // track infected entity assigned to client
ConVar g_hCvarCycles, g_hCvarGibs, g_hCvarNotify, g_hCvarPropDynamic;
bool g_bModelsLoaded;

public void OnPluginStart()
{
	AutoExecConfig(true, CONFIG_FILENAME);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
	g_hCvarCycles = CreateConVar("l4d_common_lagfix","5","How many times to repeat cycle. 0 to disable plugin.",FCVAR_NOTIFY,true,0.0,true,100.0);
	g_hCvarGibs = CreateConVar("l4d_common_lagfix_gibs","0","Include gib models in cycle. Probably not needed.",FCVAR_NOTIFY,true,0.0,true,1.0);
	g_hCvarNotify = CreateConVar("l4d_common_lagfix_notify","1","Print info to clients.",FCVAR_NOTIFY,true,0.0,true,1.0);
    g_hCvarPropDynamic = CreateConVar("l4d_common_lagfix_propdynamic","1","Create prop_dynamic instead of infected entity. Survivor bots will not shoot at prop_dynamic.",FCVAR_NOTIFY,true,0.0,true,1.0);
    RegAdminCmd("l4d_common_lagfix_reload", CmdReload, ADMFLAG_ROOT,"Reload modelprecache and force cycle on all clients. For debugging.");
    g_bModelsLoaded = false;
    CycleClients();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if(GetEngineVersion()!=Engine_Left4Dead2 && GetEngineVersion()!=Engine_Left4Dead)
	{
		strcopy(error,err_max,"Plugin only supports L4D1/L4D2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

Action CmdReload(int client, int args)
{
    g_bModelsLoaded = false;
    CycleClients();
    return Plugin_Continue;
}

public void OnMapEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bClientsCached[i] = false;
	}
    g_bModelsLoaded = false;
}

public void OnMapStart()
{
	g_bModelsLoaded = false;
}

// Load all common infected models from modelprecache string table.
void LoadModels()
{
	if (g_bModelsLoaded) return;
    int table = FindStringTable("modelprecache");
	int total = GetStringTableNumStrings(table);
	static char sTemp[PLATFORM_MAX_PATH];
	delete g_AllModels;
	g_AllModels = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	for( int i = 0; i < total; i++ )
	{
		ReadStringTable(table, i, sTemp, sizeof(sTemp)); // "_w_ models appear to be gib related, i dont think they have this lag issue."
		if( strncmp(sTemp,"models/infected/common",22) == 0 && (g_hCvarGibs.BoolValue || StrContains(sTemp,"_w_",false)<0) )
		{
        	g_AllModels.PushString(sTemp);
        }
	}
	#if DEBUG
	LogMessage("modelprecache: %d models", g_AllModels.Length);
	#endif
    g_bModelsLoaded = true;
}

// Force all clients to cycle models.
void CycleClients()
{
    for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || IsFakeClient(i)) g_bClientsCached[i] = true;
		else
        {
            g_bClientsCached[i] = false;
            g_iCycle[i] = -1; // not cycling
            g_iModel[i] = 0;
            CreateTimer(0.1,Timer_CycleModels,GetClientUserId(i),TIMER_FLAG_NO_MAPCHANGE); // start cycle immediately
        }
	}
}

public void OnPluginEnd()
{
    delete g_AllModels;
    g_bModelsLoaded = false;
}

public void OnClientPutInServer(int client) // player_spawn doesn't always happen. spectators, for example.
{
    if (!IsValidClient(client)) return;
    if(IsFakeClient(client))
    {
        g_bClientsCached[client] = true;
        return;
    }
    #if DEBUG
    LogMessage("OnClientPutInServer %d %f", client, GetEngineTime());
    #endif
    g_bClientsCached[client] = false;
    g_iCycle[client] = -1; // not cycling
    g_iModel[client] = 0;
    if (g_hCvarCycles.IntValue<=0) return;
    CreateTimer(6.5,Timer_CycleModels,GetClientUserId(client),TIMER_FLAG_NO_MAPCHANGE); // takes about 6 seconds to actually be put in game
    // this gives inconsistent results. sometimes servers hang for 30-40 seconds between campaigns. somebody with more brain cells should fix this
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (g_hCvarCycles.IntValue<=0) return;
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(client)) return;
	if (IsFakeClient(client)) g_bClientsCached[client] = true;
	if(g_bClientsCached[client] || g_iCycle[client]>=0) return; // skip if already cached or busy cycling
    #if DEBUG
	LogMessage("Event_PlayerSpawn %d %f", client, GetEngineTime());
	#endif
	CreateTimer(0.10,Timer_CycleModels,GetClientUserId(client),TIMER_FLAG_NO_MAPCHANGE); // in game - start cycle immediately
}

Action Timer_CycleModels(Handle timer, int userid)
{
    LoadModels();
    if (!g_bModelsLoaded) return Plugin_Stop;
    if (g_AllModels.Length <= 0) return Plugin_Stop;
    if (g_hCvarCycles.IntValue<=0) return Plugin_Stop;
    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client)) return Plugin_Stop;
    if (IsFakeClient(client)) g_bClientsCached[client] = true;
    if(g_bClientsCached[client] || g_iCycle[client]>=0) return Plugin_Stop;
    g_iModel[client] = 0;
    g_iCycle[client] = 0;
    RequestFrame(CycleModels,userid);
    return Plugin_Stop;
}

void CycleModels(int userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client) || IsFakeClient(client))
    {
        cleanup_infected(); // client disappeared suddenly, find and delete loose infected entities.
        return;
    }
    int entref_infected = g_iInfectedRef[client];
    if (g_iModel[client]==0) // new zombie for new cycle
    {
        int cycle = g_iCycle[client];
        if (g_hCvarNotify.BoolValue && cycle<g_hCvarCycles.IntValue)
            PrintToChat(client, "[l4d_common_lagfix] Common Infected textures loading: %d/%d ...",
                        g_iCycle[client], g_hCvarCycles.IntValue);
        
        if (IsValidEntRef(entref_infected))
        {
            RemoveEntity(entref_infected);
            g_iInfectedRef[client] = INVALID_ENT_REFERENCE;
            entref_infected = INVALID_ENT_REFERENCE;
        }
    }
    if (g_iCycle[client]>=g_hCvarCycles.IntValue) // end of cycle
    {
        g_iCycle[client] = -1;
        g_bClientsCached[client] = true;
        if (g_hCvarNotify.BoolValue)
        {
            PrintHintText(client, "Common Infected textures loaded.");
            PrintToChat(client,"[l4d_common_lagfix] Common Infected textures loaded.");
        }
        return;
    }
    static char model[PLATFORM_MAX_PATH];
    g_AllModels.GetString(g_iModel[client],model,sizeof(model));
    if (!IsValidEntRef(entref_infected))
    {
        static float vPos[3]; // zombie pos
        GetClientAbsOrigin(client,vPos);
        int infected = CreateEntityByName( g_hCvarPropDynamic.BoolValue ? "prop_dynamic" : "infected" );
        if (!IsValidEntity_Safe(infected))
        {
            g_iCycle[client] = -1;
            return;
        }
        SDKHook(infected, SDKHook_SetTransmit, OnTransmit);
        DispatchKeyValue(infected,"model",model);
        if (g_hCvarPropDynamic.BoolValue)
        {
            DispatchSpawn(infected);
            TeleportEntity(infected, vPos, NULL_VECTOR, NULL_VECTOR);
        }
        else
        {
            vPos[2] += 100.0;
            TeleportEntity(infected, vPos, NULL_VECTOR, NULL_VECTOR);
            DispatchSpawn(infected);
            SetEntProp(infected,Prop_Data,"m_iHealth",99999);
            SetEntProp(infected,Prop_Data,"m_iMaxHealth",99999);
            SetEntProp(infected,Prop_Data,"m_nNextThinkTick",-1);
        }
        SetEntityRenderMode(infected,RENDER_NONE);
        SetEntPropFloat(infected,Prop_Send,"m_flModelScale",0.001); 
        SetEntProp(infected,Prop_Data,"m_takedamage",0);
        SetEntityMoveType(infected, MOVETYPE_NONE);
        SetEntProp(infected, Prop_Data, "m_nSolidType", 0);
        entref_infected = EntIndexToEntRef(infected);
        g_iInfectedRef[client] = entref_infected; 
        #if DEBUG
        LogMessage("%d new infected %d %d (%.1f %.1f %.1f)", client, infected, entref_infected, vPos[0], vPos[1], vPos[2]);
        #endif
    }
    else
    {
        DispatchKeyValue(entref_infected,"model",model);
        if (g_hCvarPropDynamic.BoolValue) DispatchSpawn(entref_infected);
    }
    #if DEBUG
    LogMessage("%d %d %d %s", client, g_iCycle[client], g_iModel[client], model);
    #endif
    g_iModel[client] += 1;
    if (g_iModel[client]>=g_AllModels.Length) // if last model - begin new cycle.
    {
        g_iModel[client] = 0;
        g_iCycle[client] += 1;
    }
    RequestFrame(CycleModels,userid);
}

// Transmit only to clients who are known to need precaching.
Action OnTransmit(int entity, int client)
{
	if(g_bClientsCached[client]) return Plugin_Handled;
	return Plugin_Continue;
}

// A client disappeared in the middle of a cycle - find loose infected and remove them.
void cleanup_infected()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidEntRef(g_iInfectedRef[i])) continue;
        if ( g_iCycle[i]<0 || !IsValidClient(i) || IsFakeClient(i) )
        {
            #if DEBUG
            LogMessage("cleanup_infected %d %d", i, g_iInfectedRef[i]);
            #endif
            RemoveEntity(g_iInfectedRef[i]);
            g_iInfectedRef[i] = INVALID_ENT_REFERENCE;
            g_iCycle[i] = -1;
        }
    }
}

stock bool IsValidEntRef(int entity)
{
	if( entity && entity != -1 && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;	
}

stock bool IsValidEntity_Safe(int entity)
{
	return ( entity && entity != INVALID_ENT_REFERENCE && IsValidEntity(entity) );
}

stock bool IsValidClient(int client, bool replaycheck = true)
{
	if (client<1 || client>MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (replaycheck)
	{
		if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	}
	return true;
}