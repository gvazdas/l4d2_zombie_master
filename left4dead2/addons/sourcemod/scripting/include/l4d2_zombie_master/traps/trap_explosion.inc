#if defined _zm_trap_explosion_included
 #endinput
#endif
#define _zm_trap_explosion_included

#define SOUND_EXPLOSION_ALERT "zm/explosion_alert.mp3"

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
    Trap_ConfirmArm();
    static float vPos[3];
    Trap_GetAimedEntity(vPos);
    g_Traps[slot].pos = vPos;
    EmitSoundToAll(SOUND_EXPLOSION_ALERT,SOUND_FROM_WORLD,_,SNDLEVEL_GUNFIRE,_,1.0,_,_,vPos);
    CreateTimer(0.1,ZM_Explode_Sparks,slot,TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(9.0,ZM_Explode,slot,TIMER_FLAG_NO_MAPCHANGE);
}

Action ZM_Explode_Sparks(Handle timer, int slot)
{
    if (g_Traps[slot].roundcount != roundcount) return Plugin_Stop;
    if (g_Traps[slot].type != ZM_TRAP_TYPE_EXPLOSION) return Plugin_Stop;
    if (g_Traps[slot].state != ZM_TRAP_STATE_ARMED) return Plugin_Stop;
    static float dir[3];
    dir[0] = GetRandomFloat(-2.0,2.0);
    dir[1] = GetRandomFloat(-2.0,2.0);
    dir[2] = GetRandomFloat(1.0,5.0);
    TE_SetupMetalSparks(g_Traps[slot].pos,dir);
    TE_SendToAll();
    CreateTimer(0.1,ZM_Explode_Sparks,slot,TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Stop;
}

Action ZM_Explode(Handle timer, int slot)
{
    if (g_Traps[slot].roundcount != roundcount) return Plugin_Stop;
    if (g_Traps[slot].type != ZM_TRAP_TYPE_EXPLOSION) return Plugin_Stop;
    if (g_Traps[slot].state != ZM_TRAP_STATE_ARMED) return Plugin_Stop;
    //TE_SetupDust(g_Traps[slot].pos,{0.0,0.0,1.0},100.0,1.0);
    //TE_SendToAll();
    //TE_SetupMuzzleFlash(g_Traps[slot].pos,{0.0,0.0,0.0},1.0,0);
    //TE_SendToAll();
    TE_SetupSparks(g_Traps[slot].pos,{0.0,0.0,1.0},8,7);
    TE_SendToAll();
    PhysicsExplode(g_Traps[slot].pos,60,1000.0,false);
    static char sound_explosion[PLATFORM_MAX_PATH];
    switch (GetRandomInt(1,3))
    {
        case 1: sound_explosion = EXPLOSION1;
        case 2: sound_explosion = EXPLOSION2;
        case 3: sound_explosion = EXPLOSION3;
    }
    EmitSoundToAll(sound_explosion,SOUND_FROM_WORLD,_,SNDLEVEL_GUNFIRE,_,0.5,_,_,g_Traps[slot].pos);
    Trap_Cleanup(slot);
    return Plugin_Stop;
}
