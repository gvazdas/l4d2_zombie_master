#if defined _zm_trap_entity_included
 #endinput
#endif
#define _zm_trap_entity_included

int g_iEntityToTrap[MAXENTITIES+1] = {-1, ...};

// Validate entity for generic entity trap
bool TrapEntity_CanArm(int entity)
{
    if (!IsValidEntity(entity) || !IsValidEdict(entity)) return false;
    if (IsValidClient(entity) && GetClientTeam(entity)!=TEAM_INFECTED) return false;
    static char sModelName[2];
    GetEntPropString(entity, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
    if (sModelName[0]==0) return false;
    //static char cls[32];
    //GetEntityClassname(entity, cls, sizeof(cls));
    // ban: prop_dynamic_ornament, entities with parents
    return true;
}

void TrapEntity_BeginArm()
{
    if (!IsValidClientZM()) return;
    int cost = Trap_TypeCost(ZM_TRAP_TYPE_ENTITY);
    if (cost<0 || !g_hTraps.BoolValue || Trap_TypeMax(ZM_TRAP_TYPE_ENTITY)<=0)
    {
        update_hint("%T", "Trap disabled", zm_client);
        return;
    }
    if ((GetGameTime() - g_fTrapLastArm) < g_fTrapCooldown)
    {
        update_hint("%T", "Trap on cooldown", zm_client);
        return;
    }
    if (cost>0 && (bank-cost)<0)
    {
        update_hint("%T", "Cannot afford", zm_client);
        return;
    }

    static float hitPos[3];
    int ent = Trap_GetAimedEntity(hitPos);
    if (ent<=0 || !TrapEntity_CanArm(ent))
    {
        update_hint("%s", "Trap invalid entity");
        return;
    }

    // If already trapped -> undo trap
    int slot = g_iEntityToTrap[ent];
    if (slot>=0 && g_Traps[slot].type==ZM_TRAP_TYPE_ENTITY)
    {
        g_iEntityToTrap[ent] = -1;
        Trap_Cleanup(slot);
        update_hint("%s", "Trap deleted");
        create_traps_menu();
        return;
    }

    // If max traps reached, free up oldest entity trap
    if (Trap_CountActive(ZM_TRAP_TYPE_ENTITY) >= Trap_TypeMax(ZM_TRAP_TYPE_ENTITY))
    {
        float t_oldest = -1.0;
        int i_oldest = -1;
        for (int i = 0; i < ZM_TRAP_MAX; i++)
        {
            if (g_Traps[i].type==ZM_TRAP_TYPE_ENTITY)
            {
                float t = g_Traps[i].armedAt;
                if (t_oldest<0.0 || t<t_oldest)
                {
                    t_oldest = t;
                    i_oldest = i;
                }
            }
        }
        if (i_oldest>=0)
        {
            int ent2 = EntRefToEntIndex(g_Traps[i_oldest].entRef);
            Trap_Cleanup(i_oldest);
            if (IsValidEntity(ent2) && IsValidEdict(ent2)) g_iEntityToTrap[ent2] = -1;
        }
        else return; // critical failure skill issue
    }

    slot = Trap_Register(ZM_TRAP_TYPE_ENTITY, ZM_TRAP_FX_PANIC, ent);
    if (slot<0)
    {
        update_hint("%T", "Trap max reached", zm_client);
        return;
    }

    g_iEntityToTrap[ent] = slot;
    CreateTrapGlowZM(slot);

    if (g_DHook_AcceptInput) DHookEntity(g_DHook_AcceptInput, true, ent, INVALID_FUNCTION, EntityTrap_AcceptInput);
    SDKHook(ent, SDKHook_TouchPost, EntityTrap_Touch);
    SDKHook(ent, SDKHook_TraceAttackPost, EntityTrap_TraceAttack);
    SDKHook(ent, SDKHook_UsePost, EntityTrap_Use);
    SDKHook(ent, SDKHook_OnTakeDamagePost, EntityTrap_TakeDamage);

    Trap_ConfirmArm();
    update_hint("%s", "Trap armed");
    create_traps_menu();
}

// Activate generic entity trap activated by survivor. Supply entity index of trap entity if known.
stock void Activate_Entity_Trap(const int trap, const int survivor, int ent = -1)
{
    //LogMessage("Activate_Entity_Trap %d %d %d", trap, survivor, ent);
    if (!g_bCvarAllow || trap<0) return;
    if (g_Traps[trap].type != ZM_TRAP_TYPE_ENTITY) return;
    if (!IsValidClient(survivor) || !IsPlayerAlive(survivor) || GetClientTeam(survivor)!=TEAM_SURVIVOR) return;
    if (!panic) toggle_panic(true);
    ZM_Horde(0,30,"",false,true,false,_,survivor);
    // Try RequestFrame and 0.1 delay if there aren't enough zombies
    if (ent<=0) ent = EntRefToEntIndex(g_Traps[trap].entRef);
    if (IsValidEntity(ent) && IsValidEdict(ent)) g_iEntityToTrap[ent] = -1;
    Trap_Cleanup(trap);
}

void EntityTrap_Touch(int entity, int other)
{
    //LogMessage("EntityTrap_Touch %d %d", entity, other);
    Activate_Entity_Trap(g_iEntityToTrap[entity],other,entity);
}

void EntityTrap_TraceAttack(int victim, int attacker, int inflictor, float damage, int damagetype, int ammotype, int hitbox, int hitgroup)
{
    //LogMessage("EntityTrap_TraceAttack %d %d %d", victim, attacker, inflictor);
    Activate_Entity_Trap(g_iEntityToTrap[victim],attacker,victim);
    Activate_Entity_Trap(g_iEntityToTrap[victim],inflictor,victim);
}

void EntityTrap_Use(int entity, int activator, int caller, UseType type, float value)
{
    //LogMessage("EntityTrap_Use %d %d", entity, activator);
    Activate_Entity_Trap(g_iEntityToTrap[entity],activator,entity);
}

void EntityTrap_TakeDamage(int victim, int attacker, int inflictor, float damage, int damagetype)
{
    //LogMessage("EntityTrap_TakeDamage %d %d %d", victim, attacker, inflictor);
    Activate_Entity_Trap(g_iEntityToTrap[victim],attacker,victim);
    Activate_Entity_Trap(g_iEntityToTrap[victim],inflictor,victim);
}

MRESReturn EntityTrap_AcceptInput(int pThis, DHookReturn hReturn, DHookParam hParams)
{
    if (g_iEntityToTrap[pThis]<0) return MRES_Ignored;
	int activator = hParams.IsNull(2) ? -1 : hParams.Get(2);
	//LogMessage("EntityTrap_AcceptInput %d %d", pThis, activator);
    Activate_Entity_Trap(g_iEntityToTrap[pThis],activator,pThis);
	return MRES_Ignored;
}

stock void TrapEntityAttachGlow(int slot, int entity)
{
    if (!CanEntityGlow(entity)) return;
    g_Traps[slot].glowZMRef   = Trap_CreateDoorGlowZM(entity);
}

stock bool CanEntityGlow(int entity)
{
    static char sModelName[2];
    GetEntPropString(entity, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
    if (sModelName[0]=='*') return false; // no glows on brushes
    return HasEntProp(entity,Prop_Send,"m_iGlowType");
}

// Remove remove hooks
void TrapEntity_Teardown(int slot)
{
    //if (g_Traps[slot].hookID==-1) return;
    int ent = EntRefToEntIndex(g_Traps[slot].entRef);
    if (ent > 0 && IsValidEntity(ent))
    {
            SDKUnhook(ent, SDKHook_TouchPost, EntityTrap_Touch);
            SDKUnhook(ent, SDKHook_TraceAttackPost, EntityTrap_TraceAttack);
            SDKUnhook(ent, SDKHook_UsePost, EntityTrap_Use);
            SDKUnhook(ent, SDKHook_OnTakeDamagePost, EntityTrap_TakeDamage);
    }
    //    UnhookSingleEntityOutput(door, "OnOpen", TrapDoor_OnOpen);
    //DHookRemoveHookID(g_Traps[slot].hookID);
}
