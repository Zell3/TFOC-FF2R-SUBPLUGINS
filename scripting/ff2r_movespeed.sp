/*
    "rage_movespeed"
    {
        "boss" "520.0"     // Boss Move Speed
        "b_duration" "10"      // Boss Move Speed Duration (seconds)
        "range" "500"    // Victim Range (to enable victim move speed)
        "victim" "150"    // Victim Move Speed
        "v_duration" "10"     //Victim Move Speed duration (seconds)
     
        "plugin_name" "ff2r_movespeed"    
    } 
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_functions>
#include <ff2_dynamic_defaults>

#pragma semicolon 1
#pragma newdecls required

/**
 * If you want to use formula to your ability, uncomment this.
 * This file provides ParseFormula functions.
 */
//#include "freak_fortress_2/formula_parser.sp"

/**
 * After 2023-07-25 Update, we don't need to set 36.
 */
//#define MAXTF2PLAYERS MAXPLAYERS + 1
float NewSpeed[MAXPLAYERS+1];
float NewSpeedDuration[MAXPLAYERS+1];
bool DSM_SpeedOverride[MAXPLAYERS+1];
float INACTIVE = 100000000.0;

/**
 * Original author is J0BL3SS. But he is retired and privatize all his plugins.
 * 
 * Your plugin's info. Fill it.
 */
public Plugin myinfo = {
    name = "Freak Fortress 2 Rewrite: Move Speed",
    author = "SHADoW NiNE TR3S og but zell fix it",
};

public void OnPluginStart() {
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			OnClientPutInServer(client);
			BossData cfg = FF2R_GetBossData(client);
			if (cfg) {
				FF2R_OnBossCreated(client, cfg, false);
			}
		}
	}
}

public void OnPluginEnd() {
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client) && FF2R_GetBossData(client)) {
			FF2R_OnBossRemoved(client);
		}
	}
}

/**
 * Usually, SDKHook on OnTakeDamage here. But you can use nosoop's SM-TFOnTakeDamage instead.
 */
public void OnClientPutInServer(int client) {
	
}

/**
 * When boss created, hook the abilities here.
 * 
 * We no longer use RoundStart Event to hook abilities because bosses can be created trough 
 * manually by command in other gamemodes other than Arena or create bosses mid-round.
 * 
 * Actually, this forward is called twice. OnBossSpawn and OnRoundStart.
 * 
 * Add the following conditions to make it work only at the start of the round.
 * if (!setup || FF2R_GetGamemodeType() != 2) {
 * 
 * }
 */
public void FF2R_OnBossCreated(int client, BossData cfg, bool setup) {
	if (!setup || FF2R_GetGamemodeType() != 2) {
		AbilityData ability = cfg.GetAbility("rage_movespeed");
		if (ability.IsMyPlugin()) {
			PrepareAbilities();
		}
	}
}

public void PrepareAbilities() {
	for(int client = 1; client <= MaxClients; client++) {
		if (IsValidClient(client)) {
			DSM_SpeedOverride[client] = false;
			NewSpeed[client] = 0.0;
			NewSpeedDuration[client] = INACTIVE;
		}
	}
}

/**
 * When boss removed (Died?/Left the Game/New Round Started)
 * 
 * You can use this to unhook and clear abilities from the player(s).
 */
public void FF2R_OnBossRemoved(int clientIdx) {
	for(int client = 1; client <= MaxClients; client++) {
		if (IsValidClient(client)) {
			DSM_SpeedOverride[client] = false;
			SDKUnhook(client, SDKHook_PreThink, MoveSpeed_Prethink);
			NewSpeed[client] = 0.0;
			NewSpeedDuration[client] = INACTIVE;
		}
	}
}

/**
 * When using ability
 */
public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
	NewSpeed[client] = cfg.GetFloat("boss");
	if(NewSpeedDuration[client] != INACTIVE) {
		NewSpeedDuration[client] += cfg.GetFloat("b_duration");
	} else {
		NewSpeedDuration[client] = GetEngineTime() + cfg.GetFloat("b_duration");
	}
	
	BossData boss = FF2R_GetBossData(client);
	AbilityData DSM = boss.GetAbility("dynamic_speed_management");
	DSM_SpeedOverride[client] = DSM.IsMyPlugin();
	if(DSM_SpeedOverride[client])
		DSM_SetOverrideSpeed(client, NewSpeed[client]);
	SDKHook(client, SDKHook_PreThink, MoveSpeed_Prethink);
	
	float dist2 = cfg.GetFloat("range");
	if(dist2) {
		float pos[3];
		float pos2[3];
		float dist;
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
		for(int target=1; target<=MaxClients; target++) {
			if(!IsValidClient(target))
				continue;
		
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", pos2);
			dist = GetVectorDistance( pos, pos2 );

			if (dist < dist2 && IsPlayerAlive(target) && GetClientTeam(target) != GetClientTeam(client)) {
				SDKHook(target, SDKHook_PreThink, MoveSpeed_Prethink);
				NewSpeed[target] = cfg.GetFloat("victim"); // Victim Move Speed
				if(NewSpeedDuration[target] != INACTIVE) {
					NewSpeedDuration[target] += cfg.GetFloat("v_duration"); // Add time if rage is active?
				} else {
					NewSpeedDuration[target] = GetEngineTime() + cfg.GetFloat("v_duration"); // Victim Move Speed Duration
				}
			}
		}
	}
}

public void MoveSpeed_Prethink(int client) {
	if(!DSM_SpeedOverride[client])
	{
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", NewSpeed[client]);
	}
	SpeedTick(client, GetEngineTime());
}

public void SpeedTick(int client, float gameTime) {
	// Move Speed
	if(gameTime >= NewSpeedDuration[client])
	{
		if(DSM_SpeedOverride[client])
		{
			DSM_SpeedOverride[client] = false;
			DSM_SetOverrideSpeed(client, -1.0);
		}

		NewSpeed[client] = 0.0;
		NewSpeedDuration[client] = INACTIVE;
		SDKUnhook(client, SDKHook_PreThink, MoveSpeed_Prethink);
	}
}


stock bool IsValidClient(int clientIdx, bool replaycheck=true)
{
	if(clientIdx <= 0 || clientIdx > MaxClients)
		return false;

	if(!IsClientInGame(clientIdx) || !IsClientConnected(clientIdx))
		return false;

	if(GetEntProp(clientIdx, Prop_Send, "m_bIsCoaching"))
		return false;

	if(replaycheck && (IsClientSourceTV(clientIdx) || IsClientReplay(clientIdx)))
		return false;

	return true;
}