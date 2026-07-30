///////////////////////////////////////
#if defined _zm_flashlight_included
 #endinput
#endif
#define _zm_flashlight_included
///////////////////////////////////////

// Zombie Master Vision
// light_dynamic lights up at info_target position.

int g_iRefVision = INVALID_ENT_REFERENCE; // light_dynamic
//int g_iRefVisionInfo = INVALID_ENT_REFERENCE; // info_target
int g_iVisionParent;
int g_iVisionObserver;
bool g_bVisionAlive;

stock void ZM_Vision_Cleanup()
{
    if (IsValidEntRef(g_iRefVision)) AcceptEntityInput(g_iRefVision, "Kill");
    //if (IsValidEntRef(g_iRefVisionInfo)) AcceptEntityInput(g_iRefVisionInfo, "Kill");
    g_iRefVision = INVALID_ENT_REFERENCE;
    //g_iRefVisionInfo = INVALID_ENT_REFERENCE;
    g_iVisionParent = -1;
    g_bVisionAlive = false;
    g_iVisionObserver = -1;
}

// see l4d_flashlight by Silvers
void toggle_ZM_vision(int client)
{
    if (!g_bCvarAllow || client!=zm_client || !IsValidClient(client)) return;
    if (is_zm_spamming()) return;
    
    int entity_light = -1;
    //int entity_info = -1;
    //if (IsValidEntRef(g_iRefVision) && IsValidEntRef(g_iRefVisionInfo))
    if (IsValidEntRef(g_iRefVision))
    {
        entity_light = EntRefToEntIndex(g_iRefVision);
        //entity_info =  EntRefToEntIndex(g_iRefVisionInfo);
    }
    // else
    // {
    //     ZM_Vision_Cleanup();
    // }

    // if (!IsValidEntity(entity_info))
    // {
    //     entity_info = CreateEntityByName("info_target");
    //     if(entity_info == -1) return;
    //     DispatchSpawn(entity_info);
    //     g_iRefVisionInfo = EntIndexToEntRef(entity_info);
    //     SDKHook(entity_info, SDKHook_SetTransmit, TransmitZMInfo);
    //    update_info_vision();
    //}
    //else entity_info = EntRefToEntIndex(g_iRefVisionInfo);
    
    if (!IsValidEntity(entity_light))
    {
        // No dynamic light when observing somebody. Prevents flicker.
        //int observermode = GetEntProp(client, Prop_Send, "m_iObserverMode");
        //if (observermode==4 || observermode==5) return;
        
        entity_light = CreateEntityByName("light_dynamic");
    	if(entity_light == -1) return;
        g_iVisionParent = -1;
       	DispatchKeyValue(entity_light, "_light", "40 40 40");
       	DispatchKeyValue(entity_light, "brightness", "1");
       	DispatchKeyValueFloat(entity_light, "distance", 1000.0);
        DispatchKeyValueFloat(entity_light, "spotlight_radius", 0.0);
       	DispatchKeyValue(entity_light, "style", "0");
       	DispatchSpawn(entity_light);
        //SetVariantString("!activator");
        //AcceptEntityInput(entity_light, "SetParent", zm_client);
        //g_iVisionParent = zm_client;
       	AcceptEntityInput(entity_light, "TurnOn");
		g_iRefVision = EntIndexToEntRef(entity_light);
		SDKHook(entity_light, SDKHook_SetTransmit, TransmitZMLight);
        //TeleportEntity(entity_light, {0.0,0.0,0.0}, NULL_VECTOR, NULL_VECTOR);
		update_zm_flashlight();
        //static float origin[3];
        //GetClientEyePosition(zm_client,origin);
        //TeleportEntity(entity_light, origin, NULL_VECTOR, NULL_VECTOR);
    }
	else
    {
        ZM_Vision_Cleanup();
    }

    EmitSoundToClient(client,SOUND_VISION);
}

// Update flashlight state based on observer mode and ZM alive state.
void update_zm_flashlight()
{
    if (!IsValidEntRef(g_iRefVision)) return;
    int entity = EntRefToEntIndex(g_iRefVision);
    if (!IsValidEntity(entity)) return;
    if (!IsValidClientZM())
    {
        ZM_Vision_Cleanup();
        return;
    }
    int observermode = GetEntProp(zm_client, Prop_Send, "m_iObserverMode");
    int lastlook = -1;
    if (observermode==4 || observermode==5) lastlook = GetEntPropEnt(zm_client, Prop_Send, "m_hObserverTarget");
    if (lastlook<=0 || !IsValidEntity(lastlook)) lastlook = zm_client;
    bool alive = IsValidClient(lastlook) && IsPlayerAlive(lastlook);
    bool change = g_iVisionParent!=lastlook || g_bVisionAlive!=alive || g_iVisionObserver!=observermode;
    if (change)
    {
        int viewmodel = -1;
        bool try_viewmodel = lastlook==zm_client || observermode==4; // viewmodel does not always transmit
        if (try_viewmodel && (alive || IsValidClient(lastlook)))
        {
            viewmodel = GetEntPropEnt(lastlook, Prop_Data, "m_hViewModel");
        }
        SetVariantString("!activator");
        if (IsValidEntity(viewmodel))
        {
            AcceptEntityInput(entity, "SetParent", viewmodel);
            SetEntProp(entity, Prop_Send, "m_iParentAttachment", 0);
        }
        else
        {
            AcceptEntityInput(entity, "SetParent", lastlook);
            if (alive)
            {
                if (GetClientTeam(lastlook)==TEAM_SURVIVOR) SetVariantString("muzzle_flash");
                else SetVariantString("forward");
                AcceptEntityInput(entity, "SetParentAttachment");
            }
            else
            {
                SetEntProp(entity, Prop_Send, "m_iParentAttachment", 0);
            }
        }
        TeleportEntity(entity, {0.0,0.0,0.0}, NULL_VECTOR, NULL_VECTOR);
        g_bVisionAlive = alive;
        g_iVisionParent = lastlook;
        g_iVisionObserver = observermode;
    }
    
    //TeleportEntity(entity, offs, NULL_VECTOR, NULL_VECTOR);
    //DispatchKeyValue(entity, "angles", "0 0 90");
    //static float origin[3];
    //if (IsValidClient(lastlook)) GetClientEyePosition(lastlook,origin);
    //else if (IsValidEntity(lastlook)) GetEntPropVector(lastlook, Prop_Send, "m_vecOrigin", origin);
    //TeleportEntity(entity, origin, NULL_VECTOR, NULL_VECTOR);

    //static float min[3],max[3],offs[3]
    //static float ang[3];
    //GetClientAbsOrigin(zm_client,min);
    //GetClientEyePosition(zm_client,max);
    //offs[2] = max[2] - min[2];
    //GetClientAbsAngles(zm_client,ang);
    //ScaleVector(ang,-1.0);
    //ang[0] = 90.0 - ang[0];
    //ang[1] = -ang[1];
    //ang[2] = -ang[2];
    //SetVariantString("eyes"); 
    //AcceptEntityInput(entity, "SetParentAttachmentMaintainOffset");
    //TeleportEntity(entity,NULL_VECTOR,NULL_VECTOR,NULL_VECTOR);
    //TeleportEntity(entity,offs,ang,NULL_VECTOR);
    //TeleportEntity(entity,offs,NULL_VECTOR,NULL_VECTOR);6
    //if (IsValidEntRef(g_iRefVisionInfo)) update_info_vision();
    //SetEntPropVector(entity, Prop_Send, "m_angRotation", ang);
}

Action ZM_Vision(int client, int args)
{
   toggle_ZM_vision(client);
   return Plugin_Continue;
}

Action TransmitZMLight(int entity, int client)
{
	if(client==zm_client)
    {
        update_zm_flashlight();
        return Plugin_Continue;
    }
	return Plugin_Handled;
}

// Action TransmitZMInfo(int entity, int client)
// {
// 	return Plugin_Handled;
// }

// stock void update_info_vision()
// {
//     if (!IsValidClientZM()) return;
//     static float origin[3];
//     GetClientEyePosition(zm_client,origin);
//     TeleportEntity(g_iRefVisionInfo, origin, NULL_VECTOR, NULL_VECTOR);
// }