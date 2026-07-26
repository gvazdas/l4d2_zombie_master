///////////////////////////////////////
#if defined _zm_music_included
 #endinput
#endif
#define _zm_music_included
///////////////////////////////////////

bool g_bDisableTankDetour = false; // if this broke, set to true to completely avoid messing with tank music
bool g_bIgnoreTankMusic = false; // ignore incoming Tank music soundstring

Handle g_hIgnoreTankTimer; // timer for g_bIgnoreTankMusic

Action Timer_IgnoreTankMusic(Handle timer = null, bool state = true)
{
    if (g_hIgnoreTankTimer!=null && timer!=g_hIgnoreTankTimer) return Plugin_Stop;
    g_hIgnoreTankTimer = null;
    g_bIgnoreTankMusic = state;
    return Plugin_Stop;
}

// Mute/unmute tank music depending on game state
stock void update_tank_music()
{
    if (!g_bCvarAllow || g_bDisableTankDetour || zm_stage>=ZM_END) // force vanilla Tank music behavior
    {
        //LogMessage("update_tank_music -> early Music_TankDetour_Disable");
        Music_TankDetour_Disable();
        return;
    }

    //LogMessage("update_tank_music, live tanks %d", live_zombie_arr[ZOMBIECLASS_TANK]);
    
    // Determine if Tank music should be muted
    bool mute, threat;
    if (!specials_frozen)
    {
        mute = false;
        threat = live_zombie_arr[ZOMBIECLASS_TANK]>0;
    }
    else
    {
        mute = live_zombie_arr[ZOMBIECLASS_TANK]<=0 || (zm_stage<ZM_STARTED && !zm_can_start && !force_started);
        if (!mute && ZM_finale_announced)
        {
            int current = L4D2_GetCurrentFinaleStage(); // check if escape music is playing
            mute = current==FINALE_GAUNTLET_ESCAPE || current==FINALE_HORDE_ESCAPE;
        }
        if (!mute)
        {
            // Tank music must play if there is at least one Threat Tank
            mute = true;
            threat = false;
            for (int i=1;i<=MaxClients;i++)
            {
                if (!IsValidClient(i) || !IsPlayerAlive(i) || GetClientTeam(i)!=TEAM_INFECTED) continue;
                if (GetEntProp(i,Prop_Data,"m_iHealth")<=0) continue;
                int zClass = GetEntProp(i, Prop_Send, "m_zombieClass");
                if (zClass!=ZOMBIECLASS_TANK) continue;
                if (L4D_IsPlayerIncapacitated(i)) continue; // no longer a threat
                if (i==zm_client || (GetEntProp(i,Prop_Send,"m_fFlags")&FL_FROZEN)==0)
                {
                    mute = false; // Found Threat Tank
                    threat = true;
                    //LogMessage("Threat tank %d -> unmute", i);
                    break;
                }
            }
        }
    }

    if (mute!=g_bMusicTankDetour)
    {
        if (mute)
        {
            //LogMessage("update_tank_music -> Music_TankDetour_Enable");
            Music_TankDetour_Enable();
            stop_tankmusic(null,true); // force Tank music OFF
        }
        else
        {
            //LogMessage("update_tank_music -> Music_TankDetour_Disable");
            Music_TankDetour_Disable();
            if (threat) play_tank_music_alive(true); // force Tank music ON
        }
    }
    
}

StringMap g_sMonitorMusic; // store played music soundstrings like Event.Zombat

stock void Music_Monitor_Cleanup()
{
    if (g_sMonitorMusic==null) return;
    g_sMonitorMusic.Clear();
}

// Track all looping music and audio effects playing for survivors. Used for stop sounds for zm.
stock void Music_Monitor_Enable()
{
    if (hPlayMusic==null || g_bMusicMonitor) return;
    if (g_sMonitorMusic==null) g_sMonitorMusic = new StringMap();
    hPlayMusic.Enable(Hook_Post, Detour_MusicPlayPost);
    g_bMusicMonitor = true;
}

stock void Music_Monitor_Disable()
{
    if (hPlayMusic==null || !g_bMusicMonitor) return;
    hPlayMusic.Disable(Hook_Post, Detour_MusicPlayPost);
    g_bMusicMonitor = false;
}


stock void Music_TankDetour_Enable()
{
    if (hPlayMusic==null || g_bMusicTankDetour || g_bDisableTankDetour) return;
    //LogMessage("Music_TankDetour_Enable");
    hPlayMusic.Enable(Hook_Pre, Detour_MusicPlayPre);
    g_bMusicTankDetour = true;
}

stock void Music_TankDetour_Disable()
{
    if (hPlayMusic==null || !g_bMusicTankDetour) return;
    //LogMessage("Music_TankDetour_Disable");
    hPlayMusic.Disable(Hook_Pre, Detour_MusicPlayPre);
    g_bMusicTankDetour = false;
}

// ==========================================
// PRE DETOUR HOOK -- mute tank music when ambush is active.
// ==========================================

public MRESReturn Detour_MusicPlayPre(DHookParam hParams)
{
    static char musicString[64];
    hParams.GetString(1, musicString, sizeof(musicString));
    if (StrContains(musicString,"tank",false) != -1)
    {
        //LogMessage("Detour_MusicPlayPre blocked %s", musicString);
        if (!g_bIgnoreTankMusic)
        {
            musicStringTank = musicString;
            //LogMessage("musicStringTank -> %s", musicStringTank);
        }
        return MRES_Supercede; 
    }
    return MRES_Ignored;
}

// Play Tank music for alive players
stock void play_tank_music_alive(bool force = false)
{
    if (!force && live_zombie_arr[ZOMBIECLASS_TANK]<=0) return;
    static char musicString[PLATFORM_MAX_PATH];
    if (musicStringTank[0]==0) musicString = "Event.Tank";
    else musicString = musicStringTank;
    LogMessage("play_tank_music_alive %s", musicString);
    g_bIgnoreTankMusic = true;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidClient(i) || !IsPlayerAlive(i)) continue;
        L4D_PlayMusic(i,musicString,0,0.0,true,true);
    }
    g_hIgnoreTankTimer = CreateTimer(0.1,Timer_IgnoreTankMusic,false,TIMER_FLAG_NO_MAPCHANGE);
    //g_bIgnoreTankMusic = false;
}

// Stop Tank music for all players
Action stop_tankmusic(Handle timer=null, bool force = false)
{
    if (!force && live_zombie_arr[ZOMBIECLASS_TANK]>0 && !specials_frozen) return Plugin_Stop;
    //LogMessage("stop_tankmusic");
    for (int i=1;i<=MaxClients;i++)
	{
        if (!IsClientInGame(i)) continue;
 		L4D_Stop_TankMusic_Client(i);
    }
    return Plugin_Stop;
}

// ==========================================
// POST DETOUR HOOK -- track all music events played for survivors for zm stop sound.
// ==========================================
public MRESReturn Detour_MusicPlayPost(DHookParam hParams)
{
    static char musicString[64];
    hParams.GetString(1, musicString, sizeof(musicString));
    if (DEBUG)
    {
        int flagVal = hParams.Get(2);
        LogMessage("PlayMusic %s %d", musicString, flagVal);
    }
    if (!g_bIgnoreTankMusic && live_zombie_arr[ZOMBIECLASS_TANK]>0)
    {
        if (StrContains(musicString,"tank",false) != -1)
        {
            musicStringTank = musicString;
            //LogMessage("musicStringTank -> %s", musicStringTank);
            return MRES_Ignored;
        }
    }
    if (CharToLower(musicString[0])=='e')
    {
        switch (CharToLower(musicString[6]))
        {
            case 'c':
            {
                if (strncmp(musicString,"Event.CheckPoint",16,false)==0) Monitor_Add_Music(musicString);
            }
            case 'm':
            {
                if (strncmp(musicString,"Event.MissionStart",18,false)==0) Monitor_Add_Music(musicString);
            }
            case 'z':
            {
                if (strncmp(musicString,"Event.Zombat",12,false)==0) Monitor_Add_Music(musicString);
            }
        }
    }
    return MRES_Ignored;
}

stock void Monitor_Add_Music(const char[] string)
{
    g_sMonitorMusic.SetValue(string,0,true);
    //LogMessage("Monitor_Add_Music %s", string);
}

stock void Monitor_StopMusic(const int client, const bool zm_joined = false)
{
    if (g_sMonitorMusic==null) return;
    static char soundString[64];
    StringMapSnapshot snapshot = g_sMonitorMusic.Snapshot();
    for(int i=0; i<snapshot.Length; i++)
    {
        snapshot.GetKey(i,soundString,64);
        if (zm_joined && CharToLower(soundString[6])!='z') continue; // keep playing mission start / checkpoint music
        L4D_StopMusic(client,soundString);
        if (DEBUG) LogMessage("Monitor_StopMusic %d %s", client, soundString);
    }
    delete snapshot;
}

stock void L4D_Stop_TankMusic_Client(const int client)
{
    L4D_StopMusic(client, "Event.Tank");
    L4D_StopMusic(client, "Event.TankMidpoint");
    L4D_StopMusic(client, "Event.TankMidpoint_Metal");
    L4D_StopMusic(client, "Event.TankBrothers");
    L4D_StopMusic(client, "C2M5.RidinTank1");
    L4D_StopMusic(client, "C2M5.RidinTank2");
    L4D_StopMusic(client, "C2M5.BadManTank1");
    L4D_StopMusic(client, "C2M5.BadManTank2");
    if (musicStringTank[0]!=0) L4D_StopMusic(client, musicStringTank);
}

// Clear looping music for client. if zm_joined, clear out survivor-related sounds but not background music or etc.
void stop_sound(int client, bool zm_joined = false, bool manual_zombats = true)
{
    if (!IsValidClient(client)) return;
    if (!IsPlayerAlive(client)) L4D_CleanupPlayerState(client);
    EmitSoundToClient(client,SOUND_READY,zm_client,SNDCHAN_AUTO,SNDLEVEL_RUSTLE,_,0.00);
    EmitSoundToClient(client,SOUND_READY,zm_client,SNDCHAN_BODY,SNDLEVEL_RUSTLE,_,0.00);
    EmitSoundToClient(client,SOUND_READY,zm_client,SNDCHAN_ITEM,SNDLEVEL_RUSTLE,_,0.00);
    EmitSoundToClient(client,SOUND_READY,zm_client,SNDCHAN_REPLACE,SNDLEVEL_RUSTLE,_,0.00);
    EmitSoundToClient(client,SOUND_READY,zm_client,SNDCHAN_STATIC,SNDLEVEL_RUSTLE,_,0.00);
    EmitSoundToClient(client,SOUND_READY,zm_client,SNDCHAN_STREAM,SNDLEVEL_RUSTLE,_,0.00);
    EmitSoundToClient(client,SOUND_READY,zm_client,SNDCHAN_WEAPON,SNDLEVEL_RUSTLE,_,0.00);
    EmitSoundToClient(client,SOUND_READY,zm_client,SNDCHAN_VOICE,SNDLEVEL_RUSTLE,_,0.00);
    ClientCommand(client,"cl_soundscape_flush");

    // Thanks to HarryPotter l4dinfectedbots.sp
    // https://github.com/fbef0102/L4D1_2-Plugins/blob/master/l4dinfectedbots/scripting/l4dinfectedbots.sp

    L4D_StopMusic(client, "Event.LedgeHangTwoHands");
    L4D_StopMusic(client, "Event.LedgeHangOneHand");
    L4D_StopMusic(client, "Event.LedgeHangFingers");
    L4D_StopMusic(client, "Event.LedgeHangAboutToFall");
    L4D_StopMusic(client, "Event.LedgeHangFalling");
    
    L4D_StopMusic(client, "Event.Down");
    L4D_StopMusic(client, "Event.Down_L4D1");
    L4D_StopMusic(client, "Event.BleedingOut");
    L4D_StopMusic(client, "Event.BleedingOut_L4D1");
    
    L4D_StopMusic(client, "Event.SurvivorDeath");
    L4D_StopMusic(client, "Event.SurvivorDeath_L4D1");
    L4D_StopMusic(client, "Event.ScenarioLose");
    L4D_StopMusic(client, "Event.ScenarioLose_L4D1");
    
    L4D_Stop_TankMusic_Client(client);
    
    L4D_StopMusic(client, "Event.WitchAttack");
    L4D_StopMusic(client, "Event.WitchBurning");
    L4D_StopMusic(client, "Event.WitchRage");
    L4D_StopMusic(client, "Event.WitchDead");
    
    L4D_StopMusic(client, "Event.Mobbed");
    L4D_StopMusic(client, "Event.HunterPounce");
    L4D_StopMusic(client, "Event.SmokerChoke");
    L4D_StopMusic(client, "Event.SmokerDrag");
    L4D_StopMusic(client, "Event.VomitInTheFace");
    L4D_StopMusic(client, "Event.ChargerSlam");
    L4D_StopMusic(client, "Event.JockeyRide");
    L4D_StopMusic(client, "Event.SpitterSpit");
    L4D_StopMusic(client, "Event.SpitterBurn");

    if (manual_zombats)
    {
        L4D_StopMusic(client, "Event.Zombat_1");
        L4D_StopMusic(client, "Event.Zombat_A_1");
        L4D_StopMusic(client, "Event.Zombat_B_1");
        L4D_StopMusic(client, "Event.Zombat_2");
        L4D_StopMusic(client, "Event.Zombat_A_2");
        L4D_StopMusic(client, "Event.Zombat_B_2");
        L4D_StopMusic(client, "Event.Zombat_3");
        L4D_StopMusic(client, "Event.Zombat_A_3");
        L4D_StopMusic(client, "Event.Zombat_B_3");
        L4D_StopMusic(client, "Event.Zombat_4");
        L4D_StopMusic(client, "Event.Zombat_A_4");
        L4D_StopMusic(client, "Event.Zombat_B_4");
        L4D_StopMusic(client, "Event.Zombat_5");
        L4D_StopMusic(client, "Event.Zombat_A_5");
        L4D_StopMusic(client, "Event.Zombat_B_5");
        L4D_StopMusic(client, "Event.Zombat_6");
        L4D_StopMusic(client, "Event.Zombat_A_6");
        L4D_StopMusic(client, "Event.Zombat_B_6");
        L4D_StopMusic(client, "Event.Zombat_7");
        L4D_StopMusic(client, "Event.Zombat_A_7");
        L4D_StopMusic(client, "Event.Zombat_B_7");
        L4D_StopMusic(client, "Event.Zombat_8");
        L4D_StopMusic(client, "Event.Zombat_A_8");
        L4D_StopMusic(client, "Event.Zombat_B_8");
        L4D_StopMusic(client, "Event.Zombat_9");
        L4D_StopMusic(client, "Event.Zombat_A_9");
        L4D_StopMusic(client, "Event.Zombat_B_9");
        L4D_StopMusic(client, "Event.Zombat_10");
        L4D_StopMusic(client, "Event.Zombat_A_10");
        L4D_StopMusic(client, "Event.Zombat_B_10");
        L4D_StopMusic(client, "Event.Zombat_11");
        L4D_StopMusic(client, "Event.Zombat_A_11");
        L4D_StopMusic(client, "Event.Zombat_B_11");
        L4D_StopMusic(client, "Event.Zombat_L4D1");
        L4D_StopMusic(client, "Event.Zombat_A_L4D1");
        L4D_StopMusic(client, "Event.Zombat_B_L4D1");
        L4D_StopMusic(client, "Event.Zombat2_L4D1");
        L4D_StopMusic(client, "Event.Zombat3_L4D1");
        L4D_StopMusic(client, "Event.ZombatIntro_L4D1");
        L4D_StopMusic(client, "Event.Zombat_ThePassing");
        L4D_StopMusic(client, "Event.Zombat_A_1_ThePassing");
        L4D_StopMusic(client, "Event.Zombat_B_1_ThePassing");
        L4D_StopMusic(client, "Event.Zombat3_Intro_ThePassing");
        L4D_StopMusic(client, "Event.Zombat2_Intro_ThePassing");
        L4D_StopMusic(client, "Event.Zombat2_Intro_Survival");
        L4D_StopMusic(client, "Event.Zombat3_Intro_Survival");
        L4D_StopMusic(client, "Event.Zombat2_Intro_NoMercy");
        L4D_StopMusic(client, "Event.Zombat3_Intro_NoMercy");
        L4D_StopMusic(client, "Event.Zombat2_Intro_Airport");
        L4D_StopMusic(client, "Event.Zombat3_Intro_Airport");
        L4D_StopMusic(client, "Event.Zombat2_Intro_Farm");
        L4D_StopMusic(client, "Event.Zombat3_Intro_Farm");
        L4D_StopMusic(client, "Event.Zombat2_Intro_coldstream");
        L4D_StopMusic(client, "Event.Zombat3_Intro_coldstream");
        L4D_StopMusic(client, "Event.Zombat3_Intro_Sacrifice");
        L4D_StopMusic(client, "Event.Zombat2_Intro_Mall");
        L4D_StopMusic(client, "Event.Zombat3_Intro_Mall");
        L4D_StopMusic(client, "Event.Zombat3_A_Mall");
        L4D_StopMusic(client, "Event.Zombat3_B_Mall");
        L4D_StopMusic(client, "Event.Zombat_Intro_Fairgrounds");
        L4D_StopMusic(client, "Event.Zombat_Fairgrounds");
        L4D_StopMusic(client, "Event.Zombat_A_Fairgrounds");
        L4D_StopMusic(client, "Event.Zombat_B_Fairgrounds");
        L4D_StopMusic(client, "Event.Zombat2_Intro_Fairgrounds");
        L4D_StopMusic(client, "Event.Zombat3_Intro_Fairgrounds");
        L4D_StopMusic(client, "Event.Zombat3_A_Fairgrounds");
        L4D_StopMusic(client, "Event.Zombat3_B_Fairgrounds");
        L4D_StopMusic(client, "Event.Zombat_PlankCountry");
        L4D_StopMusic(client, "Event.Zombat_A_PlankCountry");
        L4D_StopMusic(client, "Event.Zombat_B_PlankCountry");
        L4D_StopMusic(client, "Event.Zombat2_Intro_Plankcountry");
        L4D_StopMusic(client, "Event.Zombat3_Intro_Plankcountry");
        L4D_StopMusic(client, "Event.Zombat3_A_Plankcountry");
        L4D_StopMusic(client, "Event.Zombat3_B_Plankcountry");
        L4D_StopMusic(client, "Event.Zombat2_Intro_Milltown");
        L4D_StopMusic(client, "Event.Zombat3_Intro_Milltown");
        L4D_StopMusic(client, "Event.Zombat3_A_Milltown");
        L4D_StopMusic(client, "Event.Zombat3_B_Milltown");
        L4D_StopMusic(client, "Event.Zombat2_Intro_BigEasy");
        L4D_StopMusic(client, "Event.Zombat3_Intro_BigEasy");
        L4D_StopMusic(client, "Event.Zombat3_A_BigEasy");
        L4D_StopMusic(client, "Event.Zombat3_B_BigEasy");
        L4D_StopMusic(client, "Event.Zombat2_Intro_Garage");
        L4D_StopMusic(client, "Event.Zombat3_Intro_Garage");
        L4D_StopMusic(client, "Event.Zombat2_Intro_SmallTown");
        L4D_StopMusic(client, "Event.Zombat3_Intro_SmallTown");
        L4D_StopMusic(client, "Event.Zombat3_Intro_Clown");
    }

    Monitor_StopMusic(client,zm_joined); // Custom Map Zombats, checkpoint music, etc.

    if (zm_joined) return;

    // Music when Mission Starts
    L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Mall");
    L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Fairgrounds");
    L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Plankcountry");
    L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Milltown");
    L4D_StopMusic(client, "Event.MissionStart_BaseLoop_BigEasy");
    
    // Checkpoints
    L4D_StopMusic(client, "Event.CheckPointBaseLoop_Mall");
    L4D_StopMusic(client, "Event.CheckPointBaseLoop_Fairgrounds");
    L4D_StopMusic(client, "Event.CheckPointBaseLoop_Plankcountry");
    L4D_StopMusic(client, "Event.CheckPointBaseLoop_Milltown");
    L4D_StopMusic(client, "Event.CheckPointBaseLoop_BigEasy");

}