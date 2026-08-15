///////////////////////////////////////
#if defined _zm_eye_glow_included
 #endinput
#endif
#define _zm_eye_glow_included
///////////////////////////////////////

// Full credit to l4d_survivor_eyes by Marttt

#define PARTICLE_ZM_EYE "witch_eye_glow"

int iLeftEyeEntRef = INVALID_ENT_REFERENCE;
int iRightEyeEntRef = INVALID_ENT_REFERENCE;

/**
 * Precaches a particle.
 *
 * @param particle      Particle name.
 */
int tableParticleEffectNames = INVALID_STRING_TABLE;
stock void PrecacheParticle(const char[] particle)
{
    if (tableParticleEffectNames == INVALID_STRING_TABLE)
        tableParticleEffectNames = FindStringTable("ParticleEffectNames");

    if (FindStringIndex(tableParticleEffectNames, particle) == INVALID_STRING_INDEX)
    {
        bool save = LockStringTables(false);
        AddToStringTable(tableParticleEffectNames, particle);
        LockStringTables(save);
    }
}

bool g_bDebugEye = false;

/** Console command for testing eye glow on Special Infected. */
Action ZM_Debug_Eye(int client, int args)
{
   if (!IsValidClient(client)) return Plugin_Continue;
   int target = GetClientAimTarget(client,true);
   if (!IsValidClient(target))
   {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (i==client) continue;
            if (!IsValidClient(i)) continue;
            if (!IsPlayerAlive(i)) continue;
            if (GetClientTeam(i)!=TEAM_INFECTED) continue;
            target = i;
            break;
        }
        if (!IsValidClient(target)) return Plugin_Continue;
   }
   float dx,dy,dz;
   if (args>0)
   {
        dx = GetCmdArgFloat(1);
        if (args>1)
        {
            dy = GetCmdArgFloat(2);
            if (args>2) dz = GetCmdArgFloat(3);
        }
   }
   bool state = CreateEyeGlowOffsets(target,dx,dy,dz);
   if (state) g_bDebugEye = true; // do not delete eye glow no matter what
   return Plugin_Continue;
}

stock void CreateEyeGlow(const int client)
{
    CreateEyeGlowOffsets(client);
}

stock bool CreateEyeGlowOffsets(const int client, float dx = 0.0, float dy = 0.0, float dz = 0.0)
{
    if (!IsValidClient(client) || GetClientTeam(client)!=TEAM_INFECTED) return false;
    g_bDebugEye = false;
    CleanUpEyeGlow();
    int zClass = GetEntProp(client, Prop_Send, "m_zombieClass");
    static float vAngles[3], vLeft[3], vRight[3];
    vAngles = view_as<float>({ 0.0, 0.0, 0.0 });
    static char attachment[8];
    static char sModelName[64];
    GetEntPropString(client, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
    attachment = "forward";
    bool right_eye = true;
    bool left_eye = true;
    switch (zClass)
    {
        case ZOMBIECLASS_SMOKER:
        {
            left_eye = false;
            if (StrContains(sModelName,"l4d1",false)>=0) vRight = view_as<float>({ 0.0, -1.35, 0.315 });
            else                                         vRight = view_as<float>({ 0.0, -1.435, 0.3 });
        }
        case ZOMBIECLASS_BOOMER:
        {
            if (StrContains(sModelName,"l4d1",false)>=0) // L4D1 Boomer
            {
                vLeft = view_as<float>({ 0.0, 1.34, 2.84 });
                right_eye = false;
                attachment = "mouth";

                // try ValveBiped.Bip01_Head1
                // try ValveBiped.Bip01_Neck0
                //vLeft = view_as<float>({ 0.0, 0.0, 0.0});
                //attachment = "ValveBiped.Bip01_Head1";
            }
            else if (StrContains(sModelName,"boomette",false)>=0) // Boomette
            {
                vLeft = view_as<float>({ 0.9, 1.85, -0.7 });
                vRight = view_as<float>({ 0.9, -1.9, -0.55 });
            }
            else // Boomer
            {
                vLeft = view_as<float>({ 0.5, 1.465, 0.36 });
                right_eye = false;
            }
        }
        case ZOMBIECLASS_HUNTER:
        {
            if (StrContains(sModelName,"l4d1",false)>=0)
            {
                vLeft = view_as<float>({ 0.5, 1.2, 0.3 });
                vRight = view_as<float>({ 0.5, -1.2, 0.3 });
            }
            else
            {
                vLeft = view_as<float>({ 0.5, 1.45, 0.0 });
                vRight = view_as<float>({ 0.5, -0.95, 0.0 });
            }
        }
        case ZOMBIECLASS_SPITTER:
        {
            vLeft = view_as<float>({ 0.1, 1.3, -0.66 });
            vRight = view_as<float>({ 0.1, -1.2, -0.65 });
        }
        case ZOMBIECLASS_JOCKEY:
        {
            vLeft = view_as<float>({ 0.5, 1.4, 0.0 });
            vRight = view_as<float>({ 0.5, -1.4, 0.0 });
        }
        case ZOMBIECLASS_CHARGER:
        {
            vLeft = view_as<float>({ 0.5, 1.2, 0.3 });
            vRight = view_as<float>({ 0.5, -1.5, 0.5 });
        }
        case ZOMBIECLASS_TANK:
        {
            vAngles = view_as<float>({ 270.0, 270.0, 0.0 });
            vLeft = view_as<float>({ 1.4, 4.3, 1.4 });
            vRight = view_as<float>({ -1.5, 4.3, 1.5 });
            attachment = "mouth";

            //attachment = "ValveBiped.Bip01_Neck0";
            //vLeft = view_as<float>({ 0.0, 0.0, 0.0 });
            //vRight = view_as<float>({ 0.0, 0.0, 0.0 });
            // try ValveBiped.Bip01_Neck0
            // try ValveBiped.Bip01_Spine3
            // try ValveBiped.Bip01_Head
        }
        default: return false;
    }

    vLeft[0] += dx; vRight[0] -= dx;
    vLeft[1] += dy; vRight[1] -= dy;
    vLeft[2] += dz; vRight[2] += dz;

    int entity = -1;
    if (left_eye)
    {
        entity = CreateParticle(PARTICLE_ZM_EYE,vLeft,vAngles,client,attachment,zClass);
        if (IsValidEntity(entity)) iLeftEyeEntRef = EntIndexToEntRef(entity); 
    }
    if (right_eye)
    {
        entity = CreateParticle(PARTICLE_ZM_EYE,vRight,vAngles,client,attachment,zClass);
        if (IsValidEntity(entity)) iRightEyeEntRef = EntIndexToEntRef(entity);
    }
    return true;
}

stock void CleanUpEyeGlow()
{
    if (g_bDebugEye) return;
    if (IsValidEntRef(iLeftEyeEntRef)) AcceptEntityInput(iLeftEyeEntRef, "Kill");
    if (IsValidEntRef(iRightEyeEntRef)) AcceptEntityInput(iRightEyeEntRef, "Kill");
    iLeftEyeEntRef = INVALID_ENT_REFERENCE;
    iRightEyeEntRef = INVALID_ENT_REFERENCE;
}

stock int CreateParticle(const char[] particle, const float vPos[3], float vAng[3], const int target, const char[] attachment, const int zClass)
{
    int entity = CreateEntityByName("info_particle_system");
    if (!IsEntitySafe(entity)) return -1;
    DispatchKeyValue(entity, "start_active", "1");
    DispatchKeyValue(entity, "effect_name", particle);
    DispatchSpawn(entity);
    SetVariantString("!activator");
    AcceptEntityInput(entity, "SetParent", target);
    if (attachment[0] != 0)
    {
        SetVariantString(attachment);
        AcceptEntityInput(entity, "SetParentAttachment");
    }
    TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
    ActivateEntity(entity);
    static char g_sStopInput[50];
    static char g_sFireUser2Input[50];
    if (g_sStopInput[0]==0) FormatEx(g_sStopInput, sizeof(g_sStopInput), "OnUser1 !self:Stop::%.1f:-1", 5.0);
    if (g_sFireUser2Input[0]==0) FormatEx(g_sFireUser2Input, sizeof(g_sFireUser2Input), "OnUser1 !self:FireUser2::%.1f:-1", 5.0 + 0.1);
    SetVariantString(g_sStopInput);
    AcceptEntityInput(entity, "AddOutput");
    SetVariantString(g_sFireUser2Input);
    AcceptEntityInput(entity, "AddOutput");
    AcceptEntityInput(entity, "FireUser1");
    SetVariantString("OnUser2 !self:Start::0:-1");
    AcceptEntityInput(entity, "AddOutput");
    SetVariantString("OnUser2 !self:FireUser1::0:-1");
    AcceptEntityInput(entity, "AddOutput");
    SetEdictFlags(entity, GetEdictFlags(entity)&(~FL_EDICT_ALWAYS) ); // allow settransmit hooks
    if (zClass==ZOMBIECLASS_TANK && target==zm_client) SDKHook(entity, SDKHook_SetTransmit, OnTransmitEyeGlow);
    return entity;
}

// Hide eye glow for tank
Action OnTransmitEyeGlow(int entity, int client)
{
    if (client==zm_client)
    {
        SetFlagsEye(entity);
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

void SetFlagsEye(int edict)
{
    if (GetEdictFlags(edict) & FL_EDICT_ALWAYS)
    {
        SetEdictFlags(edict, (GetEdictFlags(edict) ^ FL_EDICT_ALWAYS));
    }
} 