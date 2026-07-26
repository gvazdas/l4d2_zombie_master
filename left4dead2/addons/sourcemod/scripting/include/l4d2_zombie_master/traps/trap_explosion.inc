#if defined _zm_trap_explosion_included
 #endinput
#endif
#define _zm_trap_explosion_included

Action ZM_Explosion(int client, int args)
{
    if (!g_bCvarAllow || !IsValidClientZM() || zm_client!=client) return Plugin_Continue;
    TrapExplosion_BeginArm();
    return Plugin_Continue;
}

void TrapExplosion_BeginArm()
{
    if (!IsValidClientZM()) return;
    if (!Trap_CanAfford(ZM_TRAP_TYPE_EXPLOSION,true)) return;

    int slot = Trap_Register(ZM_TRAP_TYPE_EXPLOSION,ZM_TRAP_FX_PANIC,-1);
    if (slot < 0)
    {
        update_hint("%T", "Trap max reached", zm_client);
        return;
    }

    static float vPos[3];
    Trap_GetAimedEntity(vPos);
    PhysicsExplode(vPos,60,1000.0,false);
    // TE_SetupEnergySplash(vPos,{0.0,0.0,1.0},false);
    if (g_ExplosionSprite>-1) TE_SetupExplosion(vPos,g_ExplosionSprite,1.0,1,0,5,1);
    else TE_SetupMetalSparks(vPos,{0.0,0.0,1.0});
    TE_SendToAll();
    static char sound_explosion[PLATFORM_MAX_PATH];
    switch (GetRandomInt(1,3))
    {
        case 1: sound_explosion = EXPLOSION1;
        case 2: sound_explosion = EXPLOSION2;
        case 3: sound_explosion = EXPLOSION3;
    }
    EmitSoundToAll(sound_explosion,_,_,SNDLEVEL_GUNFIRE,_,0.5,_,_,vPos);
    Trap_ConfirmArm();
    Trap_Cleanup(slot);
}
