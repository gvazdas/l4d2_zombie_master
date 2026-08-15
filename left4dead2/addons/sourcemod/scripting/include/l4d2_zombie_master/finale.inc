///////////////////////////////////////
#if defined _zm_finale_included
 #endinput
#endif
#define _zm_finale_included
///////////////////////////////////////

// https://github.com/Target5150/MoYu_Server_Stupid_Plugins/blob/master/The%20Last%20Stand/l4d2_scripted_tank_stage_fix/scripting/l4d2_scripted_tank_stage_fix.sp

// methodmap CDirector
// {
// 	public CDirector(Address ptr) {
// 		return view_as<CDirector>(ptr);
// 	}
	
// 	property int m_iTankCount {
// 		public get() {
// 			return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_m_iTankCount), NumberType_Int32);
// 		}
// 		public set(int val) {
// 			StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_m_iTankCount), val, NumberType_Int32);
// 		}
// 	}
// };
// CDirector TheDirector;

Action zm_finale_advance(int client, int args)
{
  if (DEBUG) LogMessage("[zm] zm_finale_advance");
  if (L4D_IsFinaleActive()) L4D2_ForceNextStage();
  else PrintToChat(client, "[zm] Finale is not active"); 
  return Plugin_Continue;
}

stock void get_finale_label(const int finaleType, char[] label, int maxlen = 32)
{
    switch (finaleType)
    {
        case 0: strcopy(label, maxlen, "Gauntlet"); // minimum 30s
        case 1: strcopy(label, maxlen, "Horde"); // no interrupt
        case 2: strcopy(label, maxlen, "Boss 1"); // minimum 30s and tank must die
        case 3: strcopy(label, maxlen, "Gauntlet"); // minimum 30s
        case 4: strcopy(label, maxlen, "Horde"); // no interrupt
        case 5: strcopy(label, maxlen, "Boss 2"); // minimum 30s and tank must die
        case 6: strcopy(label, maxlen, "Escape"); //infinite
        case 7: strcopy(label, maxlen, "PANIC"); // minimum 30s
        case 8: strcopy(label, maxlen, "Boss"); // minimum 30s and tank dead
        case 9: strcopy(label, maxlen, "Custom"); // ??? could do anything
        case 10: strcopy(label, maxlen, "Pause"); // ??? could do anything
        case 11: strcopy(label, maxlen, "Clearout"); // let map manage this
        case 12: strcopy(label, maxlen, "Start"); // let it through
        case 13: strcopy(label, maxlen, "Horde"); // minimum 30s
        case 14: strcopy(label, maxlen, "Horde"); // minimum 30s
        case 15: strcopy(label, maxlen, "Boss"); // let it through
        case 16: strcopy(label, maxlen, "Boss"); // minimum 30s and tank must die
        case 17: strcopy(label, maxlen, "Escape"); // infinite
        case 18: strcopy(label, maxlen, "None"); // let it through
        default: strcopy(label, maxlen, "Unknown"); // let it through
    }
}

// if hud: ignore SI limits, for determining if ZM needs to spend more bank for stage to change.
bool can_change_finale_stage(const bool hud = false)
{
    if (!ZM_finale_announced) return true;
    if (zm_stage>=ZM_END) return true;
    if (!holdfinale) return true;
    if (live_zombie_arr[ZOMBIECLASS_TANK]>0) return false;
    int current = L4D2_GetCurrentFinaleStage();
    if (current==FINALE_CUSTOM_SCRIPTED || current==FINALE_CUSTOM_DELAY || current==FINALE_CUSTOM_CLEAROUT)
        return true;
    if (FloatAbs(GetGameTime()-t_finale_change)>=360.0) return true; // 5 minutes
    int cheapest = cheapest_zombie();
    if (cheapest < 0 || cheapest > bank) return true;
    if (bank<=0 || bank<g_iBonusFinaleStage) return true;
    if ( bank>=(0.5*g_iBonusFinaleStage*g_iAliveSurvivors) ) return false;
    if (hud) return true;
    return live_SI<=1;
}

void announce_finale()
{
    if (DEBUG) LogMessage("[zm] announce_finale");
    if (L4D_IsSurvivalMode() || zm_stage!=ZM_STARTED) return;
    if (panic) toggle_panic(false,true);
    if (!ZM_finale_announced)
    {
        ZM_finale_announced = true;
        if (IsValidClientZM())
        {
            EmitSoundToClient(zm_client,SOUND_PANIC_ON,_,_,_,_,_,GetRandomInt(90,110));
            PrintHintText(zm_client, "%t", "Finale started ZM");
        }
        PrintToChatAll("[zm] %t", "Finale started");
        update_menus();
        // Address DirectorPointer = L4D_GetPointer(POINTER_DIRECTOR);
        // if (DirectorPointer!=Address_Null)
        // {
        //     TheDirector = CDirector(DirectorPointer);
        //     RequestFrame(OnFinaleFrame);
        // }
    }
}

// // Enforce Tank count in Director memory to prevent ZMControlSI on Tanks from advancing Finale stage.
// void OnFinaleFrame(const bool once = false)
// {
//     if (!g_bCvarAllow || zm_stage!=ZM_STARTED || !ZM_finale_announced) return;
//     if (TheDirector.m_iTankCount != live_zombie_arr[ZOMBIECLASS_TANK] && live_zombie_arr[ZOMBIECLASS_TANK]>0)
//     {
//         TheDirector.m_iTankCount = 1;
//         //LogMessage("Set m_iTankCount %d", TheDirector.m_iTankCount);
//     }
//     if (!once) RequestFrame(OnFinaleFrame);
// }