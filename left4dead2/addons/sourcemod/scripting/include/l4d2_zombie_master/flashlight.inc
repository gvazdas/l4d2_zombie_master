///////////////////////////////////////
#if defined _zm_flashlight_included
 #endinput
#endif
#define _zm_flashlight_included
///////////////////////////////////////

// Zombie Master Vision

int g_iRefVision = INVALID_ENT_REFERENCE; // light_dynamic
int g_iVisionParent;
int g_iVisionObserver;
bool g_bVisionAlive;

stock void ZM_Vision_Cleanup()
{
    if (IsValidEntRef(g_iRefVision)) AcceptEntityInput(g_iRefVision, "Kill");
    g_iRefVision = INVALID_ENT_REFERENCE;
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
    if (IsValidEntRef(g_iRefVision)) entity_light = EntRefToEntIndex(g_iRefVision);
    if (!IsValidEntity(entity_light))
    {
        entity_light = CreateEntityByName("light_dynamic");
    	if(entity_light == -1) return;
        g_iVisionParent = -1;
       	DispatchKeyValue(entity_light, "_light", "40 40 40");
       	DispatchKeyValue(entity_light, "brightness", "1");
       	DispatchKeyValueFloat(entity_light, "distance", 1000.0);
        DispatchKeyValueFloat(entity_light, "spotlight_radius", 0.0);
       	DispatchKeyValue(entity_light, "style", "0");
       	DispatchSpawn(entity_light);
       	AcceptEntityInput(entity_light, "TurnOn");
		g_iRefVision = EntIndexToEntRef(entity_light);
		SDKHook(entity_light, SDKHook_SetTransmit, TransmitZMLight);
		update_zm_flashlight();
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
                if (GetClientTeam(lastlook)==TEAM_SURVIVOR) SetVariantString("medkit");
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