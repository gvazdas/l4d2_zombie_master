#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#undef REQUIRE_PLUGIN

#define PLUGIN_NAME			    "l4d2_zombie_master"
#define PLUGIN_VERSION 			"0.1.0 2025-12-12"
#define GAMEDATA_FILE           PLUGIN_NAME

#define TEAM_SPECTATOR		1
#define TEAM_SURVIVOR		2
#define TEAM_INFECTED		3

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

#define MODEL_SMOKER "models/infected/smoker.mdl"
#define MODEL_BOOMER "models/infected/boomer.mdl"
#define MODEL_HUNTER "models/infected/hunter.mdl"
#define MODEL_SPITTER "models/infected/spitter.mdl"
#define MODEL_JOCKEY "models/infected/jockey.mdl"
#define MODEL_CHARGER "models/infected/charger.mdl"
#define MODEL_TANK "models/infected/hulk.mdl"

#define SOUND_READY "ui/critical_event_1.wav"
#define SOUND_START "ui/pickup_guitarriff10.wav"

#define MAXENTITIES                   2048
#define ENTITY_SAFE_LIMIT 2000 //don't spawn boxes when it's index is above this
#define ENTITY_SAFER_LIMIT 1900

//signature call
static Handle hFlashLightTurnOn = null;
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
// Tank cooldown: 20s
// 

// native bool L4D2_IsReachable(int client, const float vecPos[3]); 
// native bool L4D2_NavAreaBuildPath(Address nav_startPos, Address nav_endPos, float flMaxPathLength, int teamID, bool ignoreNavBlockers); 

/// Compute distance between two areas
// native float L4D2_VScriptWrapper_NavAreaTravelDistance(float startPos[3], float endPos[3], float flMaxPathLength, bool checkLOS, bool checkGround); 

//// Returns a random client in game
//stock int GetRandomClient(int team = -1, int alive = -1, int bots = -1) 

// Draw zombie outlines for spectator

// Bank bonuses:
// Check for Onslaught etc events

int AllPlayerCount;

ConVar g_hCvarAllow, z_max_player_zombies;
bool g_bCvarAllow;
bool g_bSpawnWitchBride = false; // avoid crash

// Zombie Master Live Variables
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
float zm_spawner_pos[3];
Address zm_spawner_navArea;
int g_iEntities;
Menu ZM_menu = null;
bool zm_menu_IsOpen = false; // track if menu is open to update zm UI data
Handle zm_timer = null;
char ZM_hint[32]; 
bool zm_deleted = false; //track if ZM just deleted something, for checks in removal of entity

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
int g_iCostCommon, g_iCostWitchStatic, g_iCostWitchMoving, g_iBonusCarAlarm, g_iBonusFinaleStage, g_iMaxWitches, g_iMaxSI, g_iMaxUniqueSI;

bool g_bLockSaferoom;

int bank_track_numplayers = 0; //tracking if more bank should be added when more survivors appear
void set_bank_begin()
{
    bank = g_iBankInitial;
    if (g_iPlayersInSurvivorTeam<=0) CountAliveSurvivors();
    bank += g_iBankInitialPlayer*g_iPlayersInSurvivorTeam;
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

// ZM Pointer

// Weather: CmdFog CmdRain CmdSnow CmdWind

#define SAFEROOM_UNKNOWN 	-2
#define SAFEROOM_NO	 -1
int g_iLockedDoor = SAFEROOM_UNKNOWN;
int g_iFirstFlags = -1;
float saferoom_cooldown = 5.0;
bool saferoom_glowing = false;
bool saferoom_locked = false;
bool zm_can_start = false;
float t_last_join = 0.0;

stock bool IsValidEntRef(int entity)
{
	//if( entity && entity != -1 && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
	//	return true;
	//return false;
	if( !entity || entity<0 || EntRefToEntIndex(entity) == INVALID_ENT_REFERENCE )
	   return false;
    return true;
		
}

void check_saferoom()
{
   if (DEBUG) PrintToServer("[zm] check_saferoom");
   if (g_iLockedDoor==SAFEROOM_UNKNOWN)
   {
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
   }
   if (DEBUG) PrintToServer("[zm] check_saferoom done");
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
   check_saferoom();
   
   if (zm_started)
   {
      if (saferoom_locked) saferoom_lock(false);
      //else saferoom_glow(false);
      return;
   }
   
   if ( zm_client>0 && (GetEngineTime()-t_last_join)>saferoom_cooldown )
      zm_can_start = true;
      
   if (zm_can_start)
   {
       if (saferoom_locked)
       {
           saferoom_lock(false);
           PrintToChatAll("[zm] Survivors can leave the safe zone!");
           EmitSoundToAll(SOUND_READY);
       }
       //else saferoom_glow(false);
   }
   else if (g_bLockSaferoom && !saferoom_locked)
   {
      saferoom_lock(true);
   }
 
   
}

void freeze_player(int client, bool state = true, int team = TEAM_SURVIVOR)
{
    if(IsValidEntRef(client) && IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client)==team)
    {   
        if (state && !zm_started)
        {
            SetEntProp(client, Prop_Data, "m_takedamage", 0);
    		SetEntityMoveType(client, MOVETYPE_NONE);
    		if (team == TEAM_INFECTED) SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags")|FL_FROZEN);
    		if (team == TEAM_SURVIVOR) TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
    		
		}
		else
		{
    		SetEntityMoveType(client, MOVETYPE_WALK);
    		if (team == TEAM_INFECTED)
    		{
        		SetEntProp(client, Prop_Send, "m_fFlags", (GetEntProp(client, Prop_Send, "m_fFlags")&~FL_FROZEN));
        		int ticktime = RoundToNearest(GetGameTime()/GetTickInterval()) + 5;
            	SetEntProp(client, Prop_Data, "m_nNextThinkTick", ticktime);
            	//DispatchSpawn(client);
            	//ActivateEntity(client);
    		}
            SetEntProp(client,Prop_Data,"m_takedamage",2);
            //if (team == TEAM_INFECTED) ActivateEntity(client);
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
    if (state) PrintToServer("[zm] Froze team %d", team);
    else PrintToServer("[zm] Unfroze team %d", team);
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
   
   if (g_iLockedDoor<=0)
   {
       saferoom_glowing=false;
       return;
   }
   
   if (state && !zm_started && g_bLockSaferoom)
   {
       SetEntProp(g_iLockedDoor, Prop_Send, "m_iGlowType", 3);
       SetEntProp(g_iLockedDoor, Prop_Send, "m_glowColorOverride", 254); //red
       SetEntProp(g_iLockedDoor, Prop_Send, "m_nGlowRange", 1000);
       saferoom_glowing=true;
   }
   else
   {
       SetEntProp(g_iLockedDoor, Prop_Send, "m_glowColorOverride", 0);
       AcceptEntityInput(g_iLockedDoor, "StopGlowing");
       saferoom_glowing=false;
   }
   
}

//Action Event_PlayerUse(Event event, const char[] name, bool dontBroadcast)
//{
//	//PrintToServer("[zm] zm_started zm_client g_iLockedDoor %d %d %d", zm_started, zm_client, g_iLockedDoor);
//	if (zm_started || g_iLockedDoor<=0 || !g_bLockSaferoom) return Plugin_Continue;
//	
//	int entity = event.GetInt("targetid");
//	//PrintToServer("[zm] used entity %d, is safedoor %d", entity, EntIndexToEntRef(entity) == g_iLockedDoor);
//	if( entity==g_iLockedDoor && GetEntProp(entity, Prop_Send, "m_bLocked") == 1 )
//	{ 
//	    //PrintToServer("[zm] Checking saferoom");
//	    int client = GetClientOfUserId(event.GetInt("userid"));
//	    if (GetClientTeam(client)!=TEAM_SURVIVOR || !IsClientInGame(client)) return Plugin_Continue;
//	    can_zm_start();
//	    if (!zm_can_start)
//	    {
//	       saferoom_lock(true);
//	       if (!IsFakeClient(client)) PrintHintText(client, "There is no Zombie Master, round cannot start. Type !zm to become zm.");
//	    }
//        return Plugin_Handled;
//	}
//	
//	return Plugin_Continue;
//}

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

bool IsValidClientZM(int client=-1)
{
    if (client<0) client = zm_client;
    return IsValidEntRef(client) && client>=0 && IsClientInGame(client);
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

// This needs work!!!!! Rescue vehicle can be cancelled if ZM re-advances the stage. Enforce
// do not allow advances if survivors are in rescue vehicle... check for any termination

//int entity = CreateEntityByName("info_goal_infected_chase");
//DispatchKeyValue(entity, "targetname", "l4d_si_command_chase");
//DispatchKeyValueVector(entity, "origin", vEndPos);
//DispatchSpawn(entity);

//AcceptEntityInput(entity, "Enable");

//int chase_entity = -1;
//asdf

// If calling with default parameters: switch whatever it is now.
// If calling with overwrite, force panic mode to be what is desired.

// Full credit to Dragokas
// Check how chase works if not updated by spawning zombies behind survivors and see if they catch up correctly
void Chase(int target)
{
	if (!IsValidClientZM(target)) return;
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
	}
}

int panic_target = -1;
void toggle_panic(bool state = true, bool overwrite = false, bool free = false)
{
    if (DEBUG) PrintToServer("[zm] toggle_panic");
    bool actual_state;
    if (overwrite) actual_state = state;
    else
    {
        bool current = FindConVar("director_panic_forever").BoolValue;
        actual_state = !current;
    }
    
    if (actual_state && zm_started && !L4D_IsFinaleActive() && !ZM_finale_announced)
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
       
       PrintToServer("[zm] Panic ON");
       int target = L4D_GetHighestFlowSurvivor();
       L4D_ForcePanicEvent();
       if (IsValidClientZM(target) && IsPlayerAlive(target))
       {
           Chase(target);
           panic_target = target;
       }
       else
       {
           panic_target = -1;
       }
       update_hint("Panic ON. Bank rate reduced.");
       actual_state = true;
       // Trying to prevent director respawns
       SetConVarInt(FindConVar("z_common_limit"), 0);
       SetConVarInt(FindConVar("z_background_limit"), 0);
    }
    else
    {
        PrintToServer("[zm] Panic OFF");
        update_hint("Panic OFF. Bank rate normal.");
        actual_state = false;
        int chase_ent = FindEntityByClassname(MaxClients + 1, "info_goal_infected_chase");
        if (chase_ent && chase_ent != INVALID_ENT_REFERENCE)
        {
 			AcceptEntityInput(chase_ent, "Disable");
 			AcceptEntityInput(chase_ent, "ClearParent");
 			//TeleportEntity(chase_ent, vPos, NULL_VECTOR, NULL_VECTOR);
        }
    }
    SetConVarInt(FindConVar("director_panic_forever"), actual_state);
    zm_update(zm_timer);
    
    panic = actual_state;
    
}

float get_bank_rate()
{
 // Onslaught and other events: 2x bank rate
 if (L4D_IsFinaleActive() || ZM_finale_announced)
 {
    if (!ZM_finale_announced)
    {
        announce_finale();
    }
    else if (bank<=100 && !ZM_finale_ended)
    {
       if (IsValidClientZM()) PrintHintText(zm_client, "Finale has advanced.");
       L4D2_ForceNextStage();
       CountAliveSurvivors();
       bank += g_iBonusFinaleStage*g_iPlayersInSurvivorTeam;
    }
    return 0.0;
 }
 float final_rate = g_fBankRateBase;
 if (g_iPlayersInSurvivorTeam>0)
    final_rate += g_iPlayersInSurvivorTeam*g_fBankRatePlayer;
    
 if (panic) final_rate /= 10.0;
 return final_rate;
}


// Round start hook actually runs first and only then mapstart!!! WHAT THE FUCK VALVE
void zm_new_round()
{
    if (!g_bCvarAllow) return;
    
    if (DEBUG) PrintToServer("[zm] zm_new_round");
    
    check_saferoom();
    
    delete_all_infected();
    SetConVarInt(FindConVar("z_common_limit"), 0);
    //SetConVarInt(FindConVar("director_panic_forever"), 0);
    SetConVarInt(FindConVar("z_background_limit"), 0);

    
    toggle_panic(false,true);
    
    //SetConVarInt(FindConVar("nb_delete_all"), 1);
    //SetConVarInt(FindConVar("director_stop"), 1);
    //toggle_infected_freeze(true,true);
    //freeze_team(true,TEAM_INFECTED);
    
    ZM_finale_announced = false;
    ZM_finale_ended = false;
    zm_can_start = !g_bLockSaferoom;
    zm_started = false;
    t_last_update = GetEngineTime();
    update_t_zm_activity(t_last_update);
    g_iPlayersInSurvivorTeam = -1;
    
    //if (zm_client>0 && IsClientInGame(zm_client)) ChangeClientTeam(zm_client,TEAM_SURVIVOR);
    zm_client = -1;
    //saferoom_glow(true);
    UpdateLiveSI(false);
    CountAliveSurvivors(); // will always run zm_update here
    CountWitches(false);
    CountCommons(false);
    
    
    
    set_bank_begin();
    
    //SIs_available = max_SI;
    //witches_available = g_iPlayersInSurvivorTeam - 1;
    
    if (zm_timer==null) zm_update(zm_timer);
    // Move zm to survivors
    // Pick new zm
    
    //if (g_bLockSaferoom && !saferoom_locked) saferoom_lock(true);
    
    zm_deleted = false;
    
}

// Might as well run this at the same time as count player survivors...
void UpdateLiveSI(bool fast = true)
{
	if (live_SI<=0 && fast) return;
	if (DEBUG) PrintToServer("[zm] UpdateLiveSI expensive");
	int temp_SI = 0;
	AllPlayerCount = 0;
	for (int i=1;i<=MaxClients;i++)
	{
		if(IsClientConnected(i))
		{
			AllPlayerCount++;
		}
		if (!IsClientInGame(i)) continue;
		if (GetClientTeam(i)==TEAM_INFECTED && IsPlayerAlive(i))
		   temp_SI += 1;
	}
	if (live_SI!=temp_SI)
	{
	   live_SI = temp_SI;
	   zm_update(zm_timer);
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
	
	ZM_menu.AddItem("11", "Delete Target");
	ZM_menu.AddItem("12", "Delete Commons");
	ZM_menu.AddItem("13", "Delete Specials");
	ZM_menu.AddItem("14", "Delete Witches");
	ZM_menu.AddItem("15", "Delete All");
	ZM_menu.AddItem("16", "Unlock Saferoom");
	ZM_menu.AddItem("17", "Toggle Rain");
	ZM_menu.AddItem("18", "Toggle Snow");
	ZM_menu.AddItem("19", "Give Up");

	
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
                else if (param2==11) ZM_Delete(zm_client,0);
                else if (param2==12) ZM_Delete_Commons(zm_client,0);
                else if (param2==13) ZM_Delete_Specials(zm_client,0);
                else if (param2==14) ZM_Delete_Witches(zm_client,0);
                else if (param2==15) ZM_Delete_All(zm_client,0);
                else if (param2==16) zm_unlock(zm_client,0);
                else if (param2==17) ZM_Rain_Toggle(zm_client); 
                else if (param2==18) ZM_Snow_Toggle(zm_client); 
                else if (param2==19) QuitZM(zm_client,0); 
                
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
    if (!g_bCvarAllow || zm_client<=0 || client<=0 || zm_client!=client || IsFakeClient(client) || !IsClientInGame(client))
       return Plugin_Continue;
    toggle_panic();
    return Plugin_Continue;
}

void CountCommons(bool fast = true)
{
    if (live_commons>0 || !fast || panic)
    {
        if (DEBUG) PrintToServer("[zm] CountCommons expensive");
        live_commons = L4D_GetCommonsCount();
        if (!panic)
        {
            SetConVarInt(FindConVar("z_common_limit"), live_commons);
            SetConVarInt(FindConVar("z_background_limit"), live_commons);
        }
        else
        {
            SetConVarInt(FindConVar("z_common_limit"), 0);
            SetConVarInt(FindConVar("z_background_limit"), 0);
        }
        
        //asdf
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
         zm_started = true;
         PrintToChatAll("[zm] Round has started!");
         PrintHintText(zm_client, "Round has started!");
         EmitSoundToAll(SOUND_START);
         update_t_zm_activity(t_now);
         saferoom_lock(false);
         if (saferoom_glowing) saferoom_glow(false);
         freeze_team(false);
         freeze_team(false,TEAM_INFECTED);
         saferoom_locked = false;
         if (IsValidEntRef(g_iLockedDoor))
         {
            AcceptEntityInput(g_iLockedDoor, "Unlock");
            AcceptEntityInput(g_iLockedDoor, "Open");
         }
      }
      else if (g_bLockSaferoom && !IsValidEntRef(g_iLockedDoor) && !zm_can_start && L4D_IsInIntro()>0)
         freeze_team(true); // otherwise one player can move after intro cutscene
      
      //set_bank_begin();
   
   }
   
   t_last_update = t_now;
   
   if (panic)
   {
       if (!IsValidClientZM(panic_target) || !IsPlayerAlive(panic_target))
       {
           panic_target = L4D_GetHighestFlowSurvivor();
           Chase(panic_target);
       }
   }
   
   if (IsValidClientZM() && GetClientTeam(zm_client)==TEAM_SPECTATOR)
   { 
      if (ZM_menu==null) create_ZM_menu();
      
      // No need to count SI here - playerdeath will track them.
      CountWitches();
      UpdateLiveSI();
      CountCommons();
      
      if (g_iPlayersInSurvivorTeam!=bank_track_numplayers)
      {
           int player_diff = g_iPlayersInSurvivorTeam - bank_track_numplayers;
           if (player_diff>0 || !zm_started) bank += g_iBankInitialPlayer*player_diff;
           bank_track_numplayers = g_iPlayersInSurvivorTeam;
           //if (bank<0) bank=0;
      }
      
      //PrintToServer("[zm] bank: %d", bank); 
      //UpdateLiveSI();
      //ZM_menu.SetTitle("Zombie Master");
      ZM_menu.SetTitle("%d %d/%d %d/%d", bank, live_commons, g_iMaxCommons, live_SI, max_SI);
      //PrintToServer("[zm] Updating zm menu title"); 
      //ZM_menu.SetTitle(IntToString(bank));
      //UpdateZMSpawnerPos();
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
             zm_client = -1;
             update_t_zm_activity(t_now);
         }
      }
      
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
      //if (!zm_started) saferoom_glow(true);
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
	name = "[L4D2] Zombie Master Game Mode",
	author = "gvazdas",
	description = "AI Game Director is replaced with a Player Game Director, the Zombie Master. Heavily inspired by the original HL2 mod.",
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
    
    g_hUpdateRate = CreateConVar("zm_fUpdateRate", "1.0", "Update rate for periodic ZM checks.",FCVAR_NOTIFY, true, 0.0001, true, 10.0);
    g_hUpdateRate.AddChangeHook(ConVarChanged_Cvars);
    
    g_hMaxCommons = CreateConVar("zm_maxcommons", "150", "ZM max number of common zombies. Incease it if your server can take it.",FCVAR_NOTIFY, true, 0.0, true, 1000.0);
    g_hMaxCommons.AddChangeHook(ConVarChanged_Cvars_ZMenu);
    
    g_hSpawnMinDistance = CreateConVar("zm_spawndistance", "800", "ZM minimum spawn distance.",FCVAR_NOTIFY, true, 0.0, true, 10000.0);
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
    
    g_hBonusFinaleStage = CreateConVar("zm_bonus_finale", "475", "ZM bank reward per player for advancing to the next Finale stage. A tank usually spawns too!",FCVAR_NOTIFY, true, 0.0, true, 10000.0);
    g_hBonusFinaleStage.AddChangeHook(ConVarChanged_Cvars);
    
    g_hLockSaferoom = CreateConVar("zm_lock_saferoom", "0", "Lock saferoom until player join activity has cooled down and ZM is present. Survivors will be frozen if there is no saferoom.",FCVAR_NOTIFY, true, 0.0, true, 1.0);
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
  	
  	// Allow commands that are usually sv_cheats 1 prohibited to work to control director and the horde.
  	//RegConsoleCmd("director_stop",cheatcommand);
  	//SetCommandFlags("director_stop", ~FCVAR_CHEAT);
	
	set_bank_begin();
}

// update zmenu when these cvars change
void ConVarChanged_Cvars_ZMenu(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (DEBUG) PrintToServer("[zm] ConVarChanged_Cvars_ZMenu");
    GetCvars();
    SetCvarsZM();
    create_ZM_menu();
    if (zm_client>0 && IsClientInGame(zm_client) && zm_menu_IsOpen)
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
    
    if (g_bCvarAllow && zm_started && zm_client>0) zm_update(zm_timer);
    
}

Action JoinZM(int client, int args)
{
	if (DEBUG) PrintToServer("[zm] JoinZM");
	if (!g_bCvarAllow) return Plugin_Continue;
	if (client<=0 || IsFakeClient(client)) return Plugin_Continue;
	if (zm_client>0 && IsClientInGame(zm_client))
	{
       if (client==zm_client)
       {
          ChangeClientTeam(client,TEAM_SPECTATOR);
          SetEntProp(client, Prop_Data, "m_iObserverMode", 6); //thanks to EHG https://forums.alliedmods.net/showthread.php?p=1080991
          // Teleport ZM to random survivor at round start on initial ZM join
          zm_update(zm_timer);
          ZM_menu.Display(zm_client,MENU_TIME_FOREVER);
          zm_menu_IsOpen = true; 
       }
       else
          PrintHintText(client,"There is already a Zombie Master.");
       return Plugin_Continue;
    }
	
	if (ZM_menu!=null) ZM_menu.Cancel();
	else create_ZM_menu();
	
    L4D_CleanupPlayerState(client);
    
    ChangeClientTeam(client,TEAM_SPECTATOR);
    zm_client = client;
    char name[MAX_NAME_LENGTH]; 
    GetClientName(client,name,sizeof(name));
    PrintToChatAll("[zm] %s is the Zombie Master.", name);
    PrintHintText(client, "You are the Zombie Master. Type /zm to open the menu.");
    update_t_zm_activity();
    zm_update(zm_timer);
    ZM_menu.Display(zm_client,MENU_TIME_FOREVER);
    zm_menu_IsOpen = true;

	return Plugin_Continue;
}

// Rain and Snow all thanks to l4d2_storm by SilverShot
// https://forums.alliedmods.net/showthread.php?t=184890

int rain_entity = -1;

Action ZM_Rain_Toggle(int client)
{
   toggle_rain(client);
   return Plugin_Continue;
}

void toggle_rain(int client)
{
	if (DEBUG) PrintToServer("[zm] toggle_rain");
	if (!g_bCvarAllow || client<=0 || zm_client<=0 || client!=zm_client || IsFakeClient(client) || !IsClientInGame(client)) return;
	
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
		else if (zm_client>0 && IsClientInGame(zm_client))
			PrintHintText(zm_client, "[zm] Weather could not be adjusted.");
	
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
	if (!g_bCvarAllow || client<=0 || zm_client<=0 || client!=zm_client || IsFakeClient(client) || !IsClientInGame(client)) return;
	
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
	else if (zm_client>0 && IsClientInGame(zm_client))
        PrintHintText(zm_client, "[zm] Weather could not be adjusted.");
	
	return;
}


Action QuitZM(int client, int args)
{
	if (DEBUG) PrintToServer("[zm] QuitZM");
	if (!g_bCvarAllow || client<=0 || IsFakeClient(client) || !IsClientInGame(client)) return Plugin_Continue;
	if (zm_client>0 && client==zm_client)
	{
	   // Sanitize here: get userid not entity. Crashes can happen otherwise.
       char name[MAX_NAME_LENGTH]; 
       GetClientName(client,name,sizeof(name));
       L4D_CleanupPlayerState(client);
       ChangeClientTeam(client,TEAM_SURVIVOR);
       zm_client = -1;
       PrintToChatAll("[zm] %s is no longer the Zombie Master.", name);
       update_t_zm_activity();
       if (ZM_menu!=null) ZM_menu.Cancel();
       zm_menu_IsOpen = false; 
       zm_update(zm_timer);
    }
    ChangeClientTeam(client,TEAM_SURVIVOR);
    
	return Plugin_Continue;
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
            check_saferoom();
            saferoom_lock(false);
            if (g_iLockedDoor>0 && EntRefToEntIndex(g_iLockedDoor)!=INVALID_ENT_REFERENCE)
            {
               AcceptEntityInput(g_iLockedDoor, "Unlock");
               AcceptEntityInput(g_iLockedDoor, "Open");
               PrintToServer("[zm] Saferoom forced open"); 
            }
        }
        freeze_team(false);
        //saferoom_glow(false);
    }
    return Plugin_Continue;
}

void UpdateZMSpawnerPos()
{
	if (DEBUG) PrintToServer("[zm] UpdateZMSpawnerPos");
	if (zm_client<=0) return;
	float vAngles[3],vOrigin[3],vPos[3];
	GetClientAbsOrigin(zm_client,vPos);
	GetClientEyePosition(zm_client,vOrigin);
	GetClientEyeAngles(zm_client,vAngles);
	
	//get endpoint for teleport
	Handle trace = TR_TraceRayFilterEx(vOrigin,vAngles,MASK_SHOT,RayType_Infinite,TraceEntityFilterPlayer);
	
	if(TR_DidHit(trace))
	{
		float vBuffer[3],vStart[3];
		TR_GetEndPosition(vStart, trace);
		GetVectorDistance(vOrigin, vStart, false);
		float Distance = -35.0;
		GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
		vPos[0] = vStart[0] + (vBuffer[0]*Distance);
		vPos[1] = vStart[1] + (vBuffer[1]*Distance);
		vPos[2] = vStart[2] + (vBuffer[2]*Distance);
	}
    
    zm_spawner_pos = vPos;
    
    // bools: anyz los checkground
    zm_spawner_navArea = L4D_GetNearestNavArea(zm_spawner_pos,50.0,true,false,true,TEAM_INFECTED);
    
	delete trace;
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

bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return entity > MaxClients || !entity;
}

void refresh_zm_ui()
{
    if (IsValidClientZM())
    {
       PrintToChat(zm_client,ZM_hint);
       if (DEBUG) PrintToServer("[zm] refresh_zm_ui");
    }
}

void update_hint(char text[32])
{
    ZM_hint = text;
    refresh_zm_ui();
}

static bool TraceFilter(int entity, int mask, int self)
{
	return entity != self;
}

bool can_any_alive_survivor_see(float vecPos[3])
{
   
   if (zm_client<=0 || !IsClientInGame(zm_client) || !IsValidClient(zm_client)) return true; // in case zm crashed
   
   if (DEBUG) PrintToServer("[zm] can_any_alive_survivor_see");
   
   //if (IsLocationFoggedToSurvivors(vecPos)) return false;
   
   // Check line of sight with saferoom door before spawning frozen infected
   if (!zm_started && g_iLockedDoor>0)
   {
        float saferoom_pos[3];
        //GetEntityAbsOrigin(g_iLockedDoor, saferoom_pos);
        GetEntPropVector(g_iLockedDoor, Prop_Send, "m_vecOrigin", saferoom_pos);
        Handle trace = TR_TraceRayFilterEx(vecPos,saferoom_pos, MASK_ALL, RayType_Infinite, TraceFilter, zm_client);
        //Handle trace = TR_TraceRayFilterEx(vecPos,saferoom_pos,MASK_SHOT,RayType_Infinite,TraceEntityFilterPlayer);
        if(TR_DidHit(trace))
        {
            int hit_entity = TR_GetEntityIndex(trace);
            if (hit_entity==g_iLockedDoor)
            {
               update_hint("Visible to saferoom."); // asdf NOT WORKING
               delete trace;
               return true;
            }
        }
        delete trace;
   }
   
   for( int i = 1; i <= MaxClients; i++ )
   {
      if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
      {
        
        if (L4D2_IsVisibleToPlayer(i,TEAM_SURVIVOR,3,zm_spawner_navArea,vecPos))
        {
           update_hint("Visible to survivors.");
           return true;
        }
      }
   }
   return false;
}

//int client_nearest_chase = 0; // store nearest client to chase while this is running
// Find smallest distance to survivor. Check both ways in case survivor is about to appear here.
float min_distance_to_survivors(float vecPos[3])
{
   if (DEBUG) PrintToServer("[zm] min_distance_to_survivors");
   float min_distance = -1.0;
   float survivor_origin[3];
   float temp_dist1, temp_dist2;
   for( int i = 1; i <= MaxClients; i++ )
   {
      if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
      {
        GetClientAbsOrigin(i,survivor_origin);
        temp_dist1 = L4D2_NavAreaTravelDistance(vecPos,survivor_origin,true);
        if (temp_dist1>=0.0 && (min_distance<0.0 || temp_dist1<min_distance)) min_distance = temp_dist1;
        temp_dist2 = L4D2_NavAreaTravelDistance(survivor_origin,vecPos,true);
        if (temp_dist2>=0.0 && (min_distance<0.0 || temp_dist2<min_distance)) min_distance = temp_dist2;
      }
   }

   // Check nav mesh first - is the surface OK to spawn zombies?
   
   // if min_distance is negative, we can't physically make our way to the survivors.
   // try checking the raw distance between vectors
   if (min_distance<0.0)
   {
      // Check if the ground on nav mesh area is compatible with infected team.
   }
   
   return min_distance;

}

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

void ZM_Horde(int client, int count=10)
{
	if (DEBUG) PrintToServer("[zm] ZM_Horde");
	if (!g_bCvarAllow || client<=0 || client!=zm_client || zm_client<=0 || IsFakeClient(client) || !IsClientInGame(zm_client)) return;
	
	update_t_zm_activity();
	
	//PrintToServer("[zm] Horde called by client %d, num zombies %d", client, count); 
	int temp_cost = g_iCostCommon*count;
	if ((bank-temp_cost)<0)
	{
    	update_hint("OH GOD WE'RE GONNA BE POOR");
    	return;
	}
	
	UpdateZMSpawnerPos();
	if (TR_PointOutsideWorld(zm_spawner_pos) || !zm_spawner_navArea) 
	{
    	update_hint("Invalid spawner position.");
    	return;
	}
	
	int navSpawnAttributes = L4D_GetNavArea_SpawnAttributes(zm_spawner_navArea);
	bool obscured = false;
	if (navSpawnAttributes>0)
	{
	    
	    if (navSpawnAttributes & NAV_SPAWN_NO_MOBS)
	    {
    	    update_hint("Zombies are illegal there.");
        	return;
	    }
	    
	    // Obscured from survivors - should be able to spawn there.
	    if (navSpawnAttributes & NAV_SPAWN_OBSCURED) obscured = true;
	    
	   
	   
	}
	
	// Check if nav area is visible to players
	
	// TerrorNavArea bool IsBlocked(int team, bool affectsFlow)
    // bool IsSpawningAllowed()
    // asdf
    //for( int i = 1; i <= MaxClients; i++ )
    //{
    //    if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
    //   {
    //      if (L4D2_IsVisibleToPlayer(i,TEAM_SURVIVOR,TEAM_INFECTED,zm_spawner_navArea,zm_spawner_pos))
    //      {
    //         update_hint("Area visible to survivors.");
    //     	 return;
    //      }
    //   }
    //}
    
    // GetNavAreaAttribute(NavArea, NAV_ATTR_OBSCURED))
	
	// Check nav mesh - is the surface OK for spawning zombies? They will suicide otherwise.
	if (can_any_alive_survivor_see(zm_spawner_pos)) return;
	float min_distance = min_distance_to_survivors(zm_spawner_pos);
	// If min distance is <0, check nav mesh if it's ok to spawn that shit.
	// Always check nav mesh, it must be valid for spawning zawambies. If nav mesh is bad don't even check spawn distance and just be like yeah nah.
	
	// Min distance can't be calculated but maybe spawns are allowed by director?
	if (min_distance<0)
	{
	    if (!obscured)
	    {
    	    update_hint("Invalid location.");
        	return;
    	}
	}
	else if (min_distance<g_fSpawnMinDistance) 
	{
        update_hint("Too close to survivors");
    	return;
	}
	
	// Check if 
	
	// Already checked if spawn pos is visible, now check nav area. If nav is seen let the zombies spawn in the monster closet
	// native bool L4D2_IsVisibleToPlayer(int client, int team, int team_target, int NavArea, float vecPos[3]);  
	
	//float dist = min_distance_to_survivors(zm_spawner_pos);
	//PrintToServer("[zm] Distance: %f", dist); 
	
	// if panic is off, try to make zombie look to nearest survivor to avoid despawning
	
	// check for line of sight with alive survivors!!!
	
	CountCommons(false);
	g_iEntities = GetEntityCountEx();
	
	if((live_commons+count)>=g_iMaxCommons || (g_iEntities+count)>=ENTITY_SAFER_LIMIT)
	{
	   //PrintHintText(zm_client, "Limit reached.");
	   update_hint("Limit reached."); 
	   return;
    }
    
	bank -= temp_cost;
	live_commons += count;
	if (!panic) SetConVarInt(FindConVar("z_common_limit"), live_commons);
	else SetConVarInt(FindConVar("z_common_limit"), 0);
	SetConVarInt(FindConVar("z_background_limit"), 0);
	//int ticktime = RoundToNearest(GetGameTime()/GetTickInterval()) + 5;
	
	// bools: anyz los checkground
	float randomPos[3];
	//PrintToServer("[zm] Horde NavArea %d", navArea);
	for( int i = 0; i < count; i++  )
	{
		
		int zombie = -1;
		if (zm_spawner_navArea)
		{
    		L4D_FindRandomSpot(zm_spawner_navArea,randomPos);
    		zombie = L4D_SpawnCommonInfected(randomPos); 
		}
		if (zombie<=0)
		{
		   //PrintToServer("[zm] Random failed");
		   zombie = L4D_SpawnCommonInfected(zm_spawner_pos);
		}
		else continue;
		if (zombie<=0)
    	{
            	if (DEBUG) PrintToServer("[zm] Spawn failed");
            	bank += temp_cost;
            	live_commons -= 1;
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
	if (!panic) SetConVarInt(FindConVar("z_common_limit"), live_commons);
	else SetConVarInt(FindConVar("z_common_limit"), 0);
	
	
    //CreateTimer(0.01,zm_update);
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
	if (!g_bCvarAllow || client<=0 || client!=zm_client || zm_client<=0 || IsFakeClient(client) || !IsClientInGame(zm_client)) return;
	
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
	
	UpdateZMSpawnerPos();
	if (TR_PointOutsideWorld(zm_spawner_pos))
	{
    	update_hint("Invalid spawn position.");
    	return;
	}
	if (can_any_alive_survivor_see(zm_spawner_pos)) return;
	float min_distance = min_distance_to_survivors(zm_spawner_pos);
	if (min_distance>0 && min_distance<g_fSpawnMinDistance) 
	{
    	update_hint("Too close to survivors");
    	return;
	}
	
	// Sitting or moving witch
	// sm_cvar sv_force_time_of_day 0 -- midnight -- sitting witch
	// sm_cvar sv_force_time_of_day 3 -- day -- walking witch
	
	bool reset_wander = false;
	if (witch_type==WITCH_STATIC)
	{
	   SetConVarInt(FindConVar("sv_force_time_of_day"),0);
	   reset_wander = true;
	}
	else
	{
 	   SetConVarInt(FindConVar("sv_force_time_of_day"),3);
 	   reset_wander = true;
	}
	
	int witch;
	if(g_bSpawnWitchBride) witch = L4D2_SpawnWitchBride(zm_spawner_pos,NULL_VECTOR);
    else witch = L4D2_SpawnWitch(zm_spawner_pos,NULL_VECTOR);
	
	if (reset_wander)
	{
	//reset_time_of_day(); //needs a delay lol I LOVE YOU VALVE
	CreateTimer(g_fUpdateRate,reset_time_of_day,TIMER_FLAG_NO_MAPCHANGE);
	//PrintToServer("[zm] Changing sv_force_time_of_day"); 
	}
	
	if (witch>0)
	{
    	bank -= temp_cost;
    	live_witches += 1;
	}
	else
	{
    	//PrintHintText(zm_client, "Witch spawn failed. Try again.");
    	update_hint("Spawn failed.");
    }
	
    //CreateTimer(0.01,zm_update);
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
   	   SetConVarInt(FindConVar("z_background_limit"), 0);
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
   if (!g_bCvarAllow || client!=zm_client || zm_client<=0 || IsFakeClient(client) || !IsClientInGame(zm_client)) return;
   
   update_t_zm_activity();
   
   zm_deleted = false;
   
   //float vAngles[3],vOrigin[3];//vPos[3];
   //GetClientAbsOrigin(zm_client,vPos);
   //GetClientEyePosition(zm_client,vOrigin);
   //GetClientEyeAngles(zm_client,vAngles);
   //Handle trace = TR_TraceRayFilterEx(vOrigin,vAngles,MASK_SHOT,RayType_Infinite,TraceFilter,zm_client);
   int entity = GetClientAimTarget(zm_client, false);
   //if(TR_DidHit(trace))
   //{
      //int entity = TR_GetEntityIndex(trace);
      if (entity>0 && IsValidEdict(entity))
      {
         static char class[32];
 	     GetEntityClassname(entity, class, sizeof(class));
 	     if ( strcmp(class,"infected")==0 || strcmp(class,"witch")==0 || (strcmp(class,"player")==0 && GetClientTeam(entity)==TEAM_INFECTED) )
 	     {
     	     RemoveEntity(entity);
     	     zm_deleted = true;
 	     }
      }
   //}
   //else PrintHintText(zm_client, "Nothing to delete. Try again.");
   //delete trace;
}

// Witches: if seen by survivors, do not allow refunds anymore

public Action evtPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    
    if (!g_bCvarAllow) return Plugin_Continue;
    
    if (DEBUG) PrintToServer("[zm] evtPlayerDeath");
    
    // Skip victims that are infected entities
    int victim = GetClientOfUserId(event.GetInt("userid"));
    if (!victim || !IsClientInGame(victim)) return Plugin_Continue;
    
    if(GetClientTeam(victim)!=TEAM_INFECTED)
    {
        CountAliveSurvivors();
        return Plugin_Continue;
    }
    
    UpdateLiveSI(false);
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    
    if(victim>0 && attacker>0 && attacker==victim)
	{
         int zClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
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

void ZM_Spawn_SI(int client, int ZOMBIECLASS)
{
	if (DEBUG) PrintToServer("[zm] ZM_Spawn_SI");
	if (!g_bCvarAllow || client!=zm_client || IsFakeClient(client) || zm_client<=0 || !IsClientInGame(zm_client) || ZOMBIECLASS<=0) return;
	
	update_t_zm_activity();
	
	// spawn random area inside navmesh to avoid getting stuck
	
	int cost_SI = costs_SI[ZOMBIECLASS];
	if ((bank-cost_SI)<0)
	{
    	update_hint("Try getting a job?");
    	return;
	}
	
	
	UpdateLiveSI();
	if (live_SI>=max_SI)
	{
    	update_hint("Limit reached.");
    	return;
	}
	
	UpdateZMSpawnerPos();
	if (TR_PointOutsideWorld(zm_spawner_pos) || !zm_spawner_navArea)
	{
    	update_hint("Invalid spawner position.");
    	return;
	}
	if (can_any_alive_survivor_see(zm_spawner_pos)) return;
	float min_distance = min_distance_to_survivors(zm_spawner_pos);
	if (min_distance<g_fSpawnMinDistance) 
	{
    	if (min_distance<0.0) update_hint("Invalid location.");
    	else update_hint("Too close to survivors");
    	return;
	}
	
	int bot;
	
	// For now it's working OK but maybe these are more efficient.
	// Spawns a Tank
    //native int L4D2_SpawnTank(const float vecPos[3], const float vecAng[3]);
    // Spawns a Special Infected
    //native int L4D2_SpawnSpecial(int zombieClass, const float vecPos[3], const float vecAng[3]);
	
	switch (ZOMBIECLASS)
	{
    	case ZOMBIECLASS_SMOKER: 
    	{
    		bot = SDKCall(hCreateSmoker, "ZM Smoker");
    	}
    	case ZOMBIECLASS_BOOMER: 
    	{
    		bot = SDKCall(hCreateBoomer, "ZM Boomer");
    	}
    	case ZOMBIECLASS_HUNTER: 
    	{
    		bot = SDKCall(hCreateHunter, "ZM Hunter");
    	}
    	case ZOMBIECLASS_SPITTER: 
    	{
    		bot = SDKCall(hCreateSpitter, "ZM Spitter");
    	}
    	case ZOMBIECLASS_JOCKEY: 
    	{
    		bot = SDKCall(hCreateJockey, "ZM Jockey");
    	}
    	case ZOMBIECLASS_CHARGER: 
    	{
    		bot = SDKCall(hCreateCharger, "ZM Charger");
    	}
    	case ZOMBIECLASS_TANK: 
    	{
    		bot = SDKCall(hCreateTank, "ZM Tank");
    	}
	}
	
	if (IsValidClient(bot))
	{
    	ChangeClientTeam(bot, TEAM_INFECTED);
    	SetEntProp(bot, Prop_Send, "m_usSolidFlags", 16);
    	
    	SetEntProp(bot, Prop_Send, "deadflag", 0);
    	SetEntProp(bot, Prop_Send, "m_lifeState", 0);
    	SetEntProp(bot, Prop_Send, "m_iObserverMode", 0);
    	SetEntProp(bot, Prop_Send, "m_iPlayerState", 0);
    	SetEntProp(bot, Prop_Send, "m_zombieState", 0);
    	if (!zm_started) 
    	{ 
        	SetEntProp(bot, Prop_Send, "movetype", 0);
        	SetEntityMoveType(bot, MOVETYPE_NONE);  
        	SetEntProp(bot, Prop_Send, "m_fFlags", GetEntProp(bot, Prop_Send, "m_fFlags")|FL_FROZEN);
    	}
    	else
    	{
        	SetEntProp(bot, Prop_Send, "movetype", 2);
        	//ActivateEntity(bot); asdf
    	}
    	DispatchSpawn(bot);
    	ActivateEntity(bot);
    	TeleportEntity(bot, zm_spawner_pos, NULL_VECTOR, NULL_VECTOR);
    	if (!zm_started)
    	{
        	SetEntProp(bot, Prop_Send, "m_fFlags", GetEntProp(bot, Prop_Send, "m_fFlags")|FL_FROZEN);
            int ticktime = RoundToNearest(GetGameTime()/GetTickInterval()) + 5000000;
        	SetEntProp(bot, Prop_Data, "m_nNextThinkTick", ticktime);
        	//L4D_State_Transition(bot,STATE_OBSERVER_MODE);
            //L4D_BecomeGhost(bot);
            //SetEntProp(bot, Prop_Send, "m_fFlags", GetEntProp(bot, Prop_Send, "m_fFlags")|FL_FROZEN);
            SDKHook(bot, SDKHook_OnTakeDamage, OnTakeDamage_Units);
            SDKHook(bot, SDKHook_OnTakeDamageAlive, OnTakeDamage_Units);
    	}
    	bank -= cost_SI;
    	live_SI += 1;
    	
    	
	}
	else update_hint("Spawn failed. Try again.");//PrintHintText(zm_client, "Spawn failed. Try again.");
	
	// Lower SI "more allowed spawns" counter here, and add appropriate Timer to allow more SI spawns in the future.
	
    zm_update(zm_timer);
    
	return;
}

// director_force_panic_event // Forces a 'PanicEvent' to occur 
// pair this with allowing director to spawn mob shit, might be interesting

// z_health can temporarily increase common infected health

Action OnTakeDamage_Units(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
        //PrintToServer("[zm] OnTakeDamage_Units");
        int health = GetEntProp(victim, Prop_Data, "m_iHealth");
        int max_health = GetEntProp(victim, Prop_Data, "m_iMaxHealth");
        if (DEBUG) PrintToServer("[zm] Unit %d (%d/%d) taking %f damage from %d %d %d", victim, health, max_health, damage, attacker, inflictor, weapon);
        //if (!zm_started)
        
        if (victim!=attacker)
        {
           SDKUnhook(victim, SDKHook_OnTakeDamageAlive, OnTakeDamage_Units);
           SDKUnhook(victim, SDKHook_OnTakeDamage, OnTakeDamage_Units);
           if (DEBUG) PrintToServer("[zm] Unit %d unhooked - no refunds", victim);
        }
        
        // Unhook if unit takes damage from survivors -- no more refunds :)
        
        return Plugin_Continue;
} 

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
   if (zm_client>0 && client==zm_client) delete_all_infected(true,true,true);
   return Plugin_Continue;
}

Action ZM_Delete_Commons(int client, int args)
{
   if (zm_client>0 && client==zm_client) delete_all_infected(true,false,false);
   return Plugin_Continue;
}

Action ZM_Delete_Specials(int client, int args)
{
   if (zm_client>0 && client==zm_client) delete_all_infected(false,false,true);
   return Plugin_Continue;
}

Action ZM_Delete_Witches(int client, int args)
{
   if (zm_client>0 && client==zm_client) delete_all_infected(false,true,false);
   return Plugin_Continue;
}




void ResetCvars()
{
    if (DEBUG) PrintToServer("[zm] ResetCvars");
    ResetConVar(FindConVar("z_common_limit"), true, true);
    ResetConVar(FindConVar("z_background_limit"), true, true);
	ResetConVar(FindConVar("z_minion_limit"), true, true);
	ResetConVar(FindConVar("director_no_mobs"), true, true);
	ResetConVar(FindConVar("z_wandering_density"), true, true);
	ResetConVar(FindConVar("director_no_bosses"), true, true);
	ResetConVar(FindConVar("director_no_specials"), true, true);
	ResetConVar(FindConVar("director_panic_forever"), true, true);

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
	//ResetConVar(FindConVar("nb_stop"), true,true);
	//ResetConVar(FindConVar("director_stop"), true,true);
	//ResetConVar(FindConVar("director_start"), true,true);

}

// Re-run this if player number has changed
void SetCvarsZM()
{
   if (DEBUG) PrintToServer("[zm] SetCvarsZM");
   if (!g_bCvarAllow) return;
   
   // asdf director_stop
   // if (!zm_started) stop_director() should only run at round start and nothing else!!!
   if (panic)
   {
       SetConVarInt(FindConVar("z_common_limit"), 0);
   }
   SetConVarInt(FindConVar("z_minion_limit"), 0);
   SetConVarInt(FindConVar("director_no_mobs"), 1);
   SetConVarInt(FindConVar("z_wandering_density"), 0);
   SetConVarInt(FindConVar("director_no_bosses"), 1);
   SetConVarInt(FindConVar("director_no_specials"), 1);
   //SetConVarInt(FindConVar("director_panic_forever"), 1); //this should be controlled dynamically by ZM
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


public void OnPluginEnd()
{
	//for( int i = 1; i <= MaxClients; i++ )
	//{
	//}
    if (DEBUG) PrintToServer("[zm] OnPluginEnd");
    ResetCvars();
    ResetTimer();
    //if (zm_client>0 && IsClientInGame(zm_client))
    //   ChangeClientTeam(zm_client,TEAM_SURVIVOR);
    zm_client = -1;
    if (saferoom_locked) saferoom_lock(false);

	//for( int i = 1; i <= MaxClients; i++ )
	//	if(IsClientInGame(i) && !IsFakeClient(i)) g_hCvarMPGameMode.ReplicateToClient(i, g_sCvarMPGameMode);
	
}



bool IsValidClient(int client, bool replaycheck = true)
{
	if (client <= 0 || client > MaxClients) return false;
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

//Action Timer_ChangeTeam(Handle timer, int userid)
//{
//	int client = GetClientOfUserId(userid);
//	if(client && IsClientInGame(client) && 
////		!IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client))
//	{
//		//RecordSteamID(client); // Record SteamID of player.
//	}
//
//	return Plugin_Continue;
//}

void PluginPrecacheModel(const char[] model)
{
	if (!IsModelPrecached(model)) PrecacheModel(model, true);
}

public void OnMapStart()
{
    if (DEBUG) PrintToServer("[zm] OnMapStart");
    g_iLockedDoor = SAFEROOM_UNKNOWN;
    if (!g_bCvarAllow) return;
	//zm_new_round();
	ZM_menu = null;
	zm_menu_IsOpen = false;
	//ZM_finale_announced = false;
	//ZM_finale_ended = false;
	zm_kick_notify = false;
	create_ZM_menu();
	rain_entity = -1;
	snow_entity = -1;
	ResetTimer();
	t_last_join = GetEngineTime();
    //toggle_panic(false,true); //set panic to false, override
    //zm_timer = CreateTimer(g_fUpdateRate,zm_update,_,TIMER_REPEAT);
	
	PluginPrecacheModel(MODEL_SMOKER);
	PluginPrecacheModel(MODEL_BOOMER);
	PluginPrecacheModel(MODEL_HUNTER);
	PluginPrecacheModel(MODEL_SPITTER);
	PluginPrecacheModel(MODEL_JOCKEY);
	PluginPrecacheModel(MODEL_CHARGER);
	PluginPrecacheModel(MODEL_TANK);
	
	PrecacheSound(SOUND_READY);
    PrecacheSound(SOUND_START);
	
	CountCommons(false);
	g_iEntities = GetEntityCountEx();
	CountWitches(false);
	UpdateLiveSI(false);

	g_bSpawnWitchBride = false;
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	if(StrEqual("c6m1_riverbank", sMap, false))
		g_bSpawnWitchBride = true;
}

public void OnMapEnd()
{
	if (DEBUG) PrintToServer("[zm] OnMapEnd");
	zm_started = false;
	if (ZM_menu!=null) ZM_menu.Cancel();
	g_iLockedDoor = SAFEROOM_UNKNOWN; // we don't know if there's gonna be a door next map
	ResetTimer();
	//chase_entity = -1;
}

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

//Action Timer_PluginStart(Handle timer)
//{
//	if (!g_bCvarAllow)
//		return Plugin_Continue;
//}

void PanicEventStarted(Event event, const char[] name, bool dontBroadcast)
{
	if (DEBUG) PrintToServer("[zm] PanicEventStarted");
	if (zm_started)
    {
        bank += g_iBonusCarAlarm;
        //PrintToChatAll("[zm] ZM awarded %d zombux and free panic for car alarm!", g_iBonusCarAlarm);
        if (!panic) toggle_panic(true,true,true); // free panic! asdf
        else bank += g_iPanicCost;
    }
}

void evtRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	
	if (DEBUG) PrintToServer("[zm] evtRoundEnd");
	g_iLockedDoor = SAFEROOM_UNKNOWN;
	saferoom_locked = false;
	//for( int i = 1; i <= MaxClients; i++ )
	//	DeleteLight(i);
    if (ZM_finale_announced) ZM_finale_ended = true;
	//zm_started=false;
	//zm_can_start = false;
	//zm_client = -1;
	if (ZM_menu!=null) ZM_menu.Cancel();
	ResetTimer();
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

void Event_SurvivalRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	
	if (!g_bCvarAllow) return;
	if (DEBUG) PrintToServer("[zm] Event_SurvivalRoundStart");
	
	//if (!zm_started)
	//{
	   //zm_update(zm_timer);
	   //g_iPlayersInSurvivorTeam = -1;
	   //bank = g_iBankInitial;
	   //t_last_update = GetEngineTime();
	   //set_bank_begin(); // will recalculate alive survivors
	//}
	zm_started = true;
	//CountAliveSurvivors();
	//UpdateLiveSI();
	//zm_menu_IsOpen = true;
    //CreateTimer(0.01,zm_update);
    zm_update(zm_timer);
}

// Make this a function to wrap various cvars
//z_max_player_zombies = FindConVar("z_max_player_zombies");
//flags = z_max_player_zombies.Flags;
//ConVarBounds(z_max_player_zombies, ConVarBound_Upper, false);
//ConVarFlags(z_max_player_zombies, flags & ~FCVAR_NOTIFY);
// z_spawn mob
// z_spawn_old mob
// L4D_GetRandomPZSpawnPosition(L4D_GetHighestFlowSurvivor(), g_iZClassAm + 1, 5, vPos)


void IsAllowed()
{
	if (DEBUG) PrintToServer("[zm] IsAllowed");
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	//GetCvars();

	if(!g_bCvarAllow && bCvarAllow)
	{
		//CreateTimer(0.5, Timer_PluginStart, _, TIMER_FLAG_NO_MAPCHANGE);
		g_bCvarAllow = true;

		//SetSpawnDis();

		HookEvent("round_start", evtRoundStart,		EventHookMode_PostNoCopy);
		HookEvent("survival_round_start",Event_SurvivalRoundStart,EventHookMode_PostNoCopy);
		HookEvent("round_end",				evtRoundEnd,		EventHookMode_PostNoCopy); //trigger twice in versus mode, one when all survivors wipe out or make it to saferom, one when first round ends (second round_start begins).
		HookEvent("map_transition", 		evtRoundEnd,		EventHookMode_PostNoCopy); //all survivors make it to saferoom, and server is about to change next level in coop mode (does not trigger round_end) 
		HookEvent("mission_lost", 			evtRoundEnd,		EventHookMode_PostNoCopy); //all survivors wipe out in coop mode (also triggers round_end)
		HookEvent("finale_vehicle_leaving", evtRoundEnd,		EventHookMode_PostNoCopy); //final map final rescue vehicle leaving  (does not trigger round_end)
	    
	    HookEvent("create_panic_event", PanicEventStarted,		EventHookMode_PostNoCopy);
	    
	    HookEvent("triggered_car_alarm", Event_TriggeredCarAlarm, EventHookMode_Pre);
		HookEvent("player_death", evtPlayerDeath, EventHookMode_Pre);
		HookEvent("player_team", evtPlayerTeam);
		//HookEvent("player_spawn", evtPlayerSpawn);
		HookEvent("finale_start", 			evtFinaleStart, EventHookMode_PostNoCopy); //final starts, some of final maps won't trigger
		HookEvent("finale_radio_start", 	evtFinaleStart, EventHookMode_PostNoCopy); //final starts, all final maps trigger
		HookEvent("gauntlet_finale_start", 	evtFinaleStart, EventHookMode_PostNoCopy); //final starts, only rushing maps trigger (C5M5, C13M4)
		HookEvent("player_spawn", evtPlayerSpawned);
		//HookEvent("player_hurt", evtInfectedHurt);
		HookEvent("player_team", evtPlayerTeam);
		//HookEvent("ghost_spawn_time", Event_GhostSpawnTime);
		HookEvent("player_first_spawn", evtPlayerSpawned);
		HookEvent("player_entered_start_area", evtPlayerSpawned);
		HookEvent("player_entered_checkpoint", evtPlayerSpawned);
		HookEvent("player_transitioned", evtPlayerSpawned);
		HookEvent("player_left_start_area", evt_ZM_start_imminent);
		HookEvent("player_left_checkpoint", evt_ZM_start_imminent);
		//HookEvent("player_incapacitated", Event_Incap);
		//HookEvent("player_ledge_grab", Event_Incap);
		//HookEvent("player_now_it", Event_GotVomit);
		//HookEvent("revive_success", Event_revive_success);/
		//HookEvent("player_ledge_release", Event_ledge_release);//
		//HookEvent("player_bot_replace", Event_BotReplacePlayer);
		//HookEvent("bot_player_replace", Event_PlayerReplaceBot);
		//HookEvent("tank_frustrated", OnTankFrustrated, EventHookMode_Post);
		HookEvent("player_disconnect", Event_PlayerDisconnect);
		
		HookEvent("finale_vehicle_ready", EvtFinaleEnding, EventHookMode_Post);
		HookEvent("finale_vehicle_incoming", EvtFinaleEnding, EventHookMode_Post);
		
		//HookEvent("player_use",Event_PlayerUse,EventHookMode_Pre);

		//for (int i = 1; i <= MaxClients; i++)
		//{
		//	if (IsClientInGame(i))
		//	{
		//		OnClientPutInServer(i);
		//	}
		//}
		
		// asdf check these
		//SetCommandFlags("nb_delete_all",  ~FCVAR_CHEAT);
		//SetCommandFlags("director_stop",  ~FCVAR_CHEAT);
		//SetCommandFlags("director_start", ~FCVAR_CHEAT);
		
		GetCvars();
		SetCvarsZM();
		
		ServerCommand("sm_cvar mp_restartgame 1");
	}

	else if(g_bCvarAllow && !bCvarAllow)
	{
		OnPluginEnd();
		//ResetCvars();
		g_bCvarAllow = false;
		UnhookEvent("round_start", evtRoundStart,		EventHookMode_PostNoCopy);
		UnhookEvent("survival_round_start", Event_SurvivalRoundStart,		EventHookMode_PostNoCopy); //生存模式之下計時開始之時 (一代沒有此事件)
		UnhookEvent("round_end",				evtRoundEnd,		EventHookMode_PostNoCopy); //trigger twice in versus mode, one when all survivors wipe out or make it to saferom, one when first round ends (second round_start begins).
		UnhookEvent("map_transition", 			evtRoundEnd,		EventHookMode_PostNoCopy); //all survivors make it to saferoom, and server is about to change next level in coop mode (does not trigger round_end) 
		UnhookEvent("mission_lost", 			evtRoundEnd,		EventHookMode_PostNoCopy); //all survivors wipe out in coop mode (also triggers round_end)
		UnhookEvent("finale_vehicle_leaving", 	evtRoundEnd,		EventHookMode_PostNoCopy); //final map final rescue vehicle leaving  (does not trigger round_end)
	
	    UnhookEvent("create_panic_event", PanicEventStarted,		EventHookMode_PostNoCopy);
	
	    UnhookEvent("triggered_car_alarm", Event_TriggeredCarAlarm, EventHookMode_Pre);
		UnhookEvent("player_death", evtPlayerDeath, EventHookMode_Pre);
		UnhookEvent("player_team", evtPlayerTeam);
		//UnhookEvent("player_spawn", evtPlayerSpawn);
		UnhookEvent("finale_start", 			evtFinaleStart, EventHookMode_PostNoCopy); //final starts, some of final maps won't trigger
		UnhookEvent("finale_radio_start", 	evtFinaleStart, EventHookMode_PostNoCopy); //final starts, all final maps trigger
		UnhookEvent("gauntlet_finale_start", 	evtFinaleStart, EventHookMode_PostNoCopy); //final starts, only rushing maps trigger (C5M5, C13M4)
		UnhookEvent("player_spawn", evtPlayerSpawned);
		//UnhookEvent("player_hurt", evtInfectedHurt);
		UnhookEvent("player_team", evtPlayerTeam);
		//UnhookEvent("ghost_spawn_time", Event_GhostSpawnTime);
		UnhookEvent("player_first_spawn", evtPlayerSpawned);
		UnhookEvent("player_entered_start_area", evtPlayerSpawned);
		UnhookEvent("player_entered_checkpoint", evtPlayerSpawned);
		UnhookEvent("player_transitioned", evtPlayerSpawned);
		UnhookEvent("player_left_start_area", evt_ZM_start_imminent);
		UnhookEvent("player_left_checkpoint", evt_ZM_start_imminent);
		//UnhookEvent("player_incapacitated", Event_Incap);
		//UnhookEvent("player_ledge_grab", Event_Incap);
		//UnhookEvent("player_now_it", Event_GotVomit);
		//UnhookEvent("revive_success", Event_revive_success);//救起倒地的or 懸掛的
		//UnhookEvent("player_ledge_release", Event_ledge_release);//懸掛的玩家放開了
		//UnhookEvent("player_bot_replace", Event_BotReplacePlayer);
		//UnhookEvent("bot_player_replace", Event_PlayerReplaceBot);
		//UnhookEvent("tank_frustrated", OnTankFrustrated, EventHookMode_Post);
		UnhookEvent("player_disconnect", Event_PlayerDisconnect); //換圖不會觸發該事件
		
		//UnhookEvent("player_use",Event_PlayerUse,EventHookMode_Pre);
		
		UnhookEvent("finale_vehicle_ready", EvtFinaleEnding, EventHookMode_Post);
		UnhookEvent("finale_vehicle_incoming", EvtFinaleEnding, EventHookMode_Post);

		//for( int i = 1; i <= MaxClients; i++ ){
		//	if(IsClientInGame(i)) OnClientDisconnect(i);
		//}
		
		//SetCommandFlags("nb_delete_all",  FCVAR_CHEAT);
		//SetCommandFlags("director_stop",  FCVAR_CHEAT);
		//SetCommandFlags("director_start", FCVAR_CHEAT);
		
		ServerCommand("sm_cvar mp_restartgame 1");
		
		
	}

	
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
    if (DEBUG) PrintToServer("[zm] Event_TriggeredCarAlarm");
    if (zm_started)
    {
        bank += g_iBonusCarAlarm;
        PrintToChatAll("[zm] ZM awarded %d zombux and free panic for car alarm!", g_iBonusCarAlarm);
        if (!panic) toggle_panic(true,true,true); // free panic!
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
       CountAliveSurvivors();
       UpdateLiveSI();
       //CreateTimer(0.01,zm_update);
       //if (zm_timer == null) zm_update(zm_timer);
    }
}

void evtPlayerSpawned(Event event, const char[] name, bool dontBroadcast)
{
    if (DEBUG) PrintToServer("[zm] evtPlayerSpawned");
	//int userid = event.GetInt("userid");
	//int client = GetClientOfUserId(userid);

	//if (!client || IsFakeClient(client))
	//	return;
    
    if (g_bCvarAllow)
    {
       UpdateLiveSI();
       CountAliveSurvivors();
       if (g_iLockedDoor==SAFEROOM_UNKNOWN) check_saferoom();
       //CreateTimer(0.01,zm_update);
       if (zm_timer == null) zm_update(zm_timer);
       if (g_bLockSaferoom && g_iLockedDoor<0 && saferoom_locked)
       {
           int userid = event.GetInt("userid");
       	   int client = GetClientOfUserId(userid);
       	   freeze_player(client,true,TEAM_SURVIVOR);
   	   }
       
       
       
    }
  
    //delete zm_timer;
    //zm_timer = CreateTimer(g_fUpdateRate/10.0, zm_update, TIMER_FLAG_NO_MAPCHANGE);
}

void evtPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (DEBUG) PrintToServer("[zm] evtPlayerTeam");
	if (g_bCvarAllow)
    {
       int client = GetClientOfUserId(event.GetInt("userid"));
       if (zm_client==client)
       {
   	      if (GetClientTeam(zm_client)!=TEAM_SPECTATOR)
   	      {
   	         zm_client=-1;
   	         update_t_zm_activity(0.0); // instantly starts printing the "no ZM" message
   	         zm_update(zm_timer);
   	      }
   	      if (!zm_started && !zm_can_start) can_zm_start();
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
    	if (!zm_started && !zm_can_start) can_zm_start();
    	
	}
	
    //CountAliveSurvivors();
	//UpdateLiveSI();
	//CreateTimer(0.01,zm_update);
	if (zm_timer == null) zm_update(zm_timer);
	
	//delete zm_timer;
    //zm_timer = CreateTimer(g_fUpdateRate, zm_update, TIMER_FLAG_NO_MAPCHANGE);

	//SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

	if (IsFakeClient(client))
		return;
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
   	   //CreateTimer(0.01,zm_update);
   	   //if (zm_timer == null) zm_update(zm_timer);
    }
	
	//if(!IsClientInGame(client))
	//   return;
	
	
    
    // Check if ZM disconnected - replace if so.

	//clientGreeted[client] = 0;

	// Reset all other arrays
	//PlayerLifeState[client] = false;
	//PlayerHasEnteredStart[client] = false;
	//Player_zss_notified[client] = false;

	//delete g_hPlayerSpawnTimer[client];
	//delete FightOrDieTimer[client];
	//delete RestoreColorTimer[client];



	//if(!g_bCvarAllow) return;

	//if(!IsFakeClient(client) && L4D_HasPlayerControlledZombies() == false && CheckRealPlayers_InSV(client) == false)
}

// Refund zombie delete
public void OnEntityDestroyed(int entity)
{
    if ( !g_bCvarAllow || entity == INVALID_ENT_REFERENCE) return;
    
    // Refund despawned zombies
	if (zm_started || zm_deleted)
	{
	   int max_health = GetEntProp(entity,Prop_Data,"m_iMaxHealth");
	   if (DEBUG) PrintToServer("[zm] OnEntityDestroyed MaxHP %d", max_health);
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
       	     // TBD: figure out if witch entity is stationary or moving
       	     // asdf when creating witch hook its death to one of two functions for moving and static type
       	     if (bank_refund>=0)
       	     {
           	     if (g_hCostWitchStatic<g_hCostWitchMoving) bank_refund=g_iCostWitchStatic;
           	     else bank_refund=g_iCostWitchMoving;
       	     }
       	  }
       	  else if (strcmp(class,"player")==0 && GetClientTeam(entity)==TEAM_INFECTED)
       	  {
           	 int zClass = GetEntProp(entity, Prop_Send, "m_zombieClass");
             if (zClass<ZOMBIECLASS_SMOKER || zClass>ZOMBIECLASS_TANK || zClass==7) return;
             bank_refund = costs_SI[zClass];
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
	}
	else
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "FlashlightIsOn");
		hFlashLightTurnOn = EndPrepSDKCall();
	}
	if (hFlashLightTurnOn == null)
		SetFailState("FlashLightTurnOn Signature broken");

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

// Made for the Knockout.chat community
// HUGE THANKS TO TESTERS: IronBar, ngh, Hatsune Miku Fan, Raykeno, Lil Ole Fella, ShaunOfTheLive
// Chance, Skerion
// HUGE THANKS TO Reagy and IronBar for hosting the Knockout Left 4 Dead 2 Server