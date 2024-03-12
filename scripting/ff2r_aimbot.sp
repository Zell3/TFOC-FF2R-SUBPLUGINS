/*
	"aimbot"
	{
		"duration"	"8.0"	// time of ambotakam
		"plugin_name"	"ff2r_aimbot"
	}
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>

#pragma semicolon 1
#pragma newdecls required

float aimbot_duration;

public Plugin myinfo = {
	name = "[FF2R] AimBot",
	author = "Deatharus Fix by Zell",
	description = "MLG SNIPER",
	version = "1.0.0",
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
		AbilityData ability = cfg.GetAbility("aimbot");
		if (ability.IsMyPlugin()) {
			aimbot_duration = cfg.GetFloat("duration") + GetEngineTime();
		}
	}
}

/**
 * When boss removed (Died?/Left the Game/New Round Started)
 * 
 * You can use this to unhook and clear abilities from the player(s).
 */
public void FF2R_OnBossRemoved(int clientIdx) {
	SDKUnhook(clientIdx, SDKHook_PreThink, AimThink);
}

/**
 * When using ability
 */
public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
	if(!cfg.IsMyPlugin())	// Incase of duplicated ability names in boss config
		return;
	
	if(!cfg.GetBool("enabled", true))	// hidden/internal bool for abilities
		return;
	
	if(!StrContains(ability, "aimbot", false))	// We want to use subffixes
	{
		aimbot_duration = cfg.GetFloat("duration") + GetEngineTime();
		SDKHook(client, SDKHook_PreThink, AimThink);
	}
}

public void AimThink(int client) {
	int i = GetClosestClient(client);
	if(IsValidClient(i))
	{
		float clientEye[3], iEye[3], clientAngle[3];	
		GetClientEyePosition(client, clientEye);
		GetClientEyePosition(i, iEye);
		GetVectorAnglesTwoPoints(clientEye, iEye, clientAngle);
		AnglesNormalize(clientAngle);
		TeleportEntity(client, NULL_VECTOR, clientAngle, NULL_VECTOR);
	}
	if(GetEngineTime() >= aimbot_duration)
		SDKUnhook(client, SDKHook_PreThink, AimThink);
}

stock int GetClosestClient(int client) {
	float fClientLocation[3];
	float fEntityOrigin[3];
	GetClientAbsOrigin(client, fClientLocation);

	int iClosestEntity = -1;
	float fClosestDistance = -1.0;
	for(int i = 1; i < MaxClients; i++) {
		if(IsValidClient(i) && GetClientTeam(i) != GetClientTeam(client) && IsPlayerAlive(i) && i != client) {
			GetClientAbsOrigin(i, fEntityOrigin);
			float fEntityDistance = GetVectorDistance(fClientLocation, fEntityOrigin);
			if((fEntityDistance < fClosestDistance) || fClosestDistance == -1.0)
			{
				fClosestDistance = fEntityDistance;
				iClosestEntity = i;
			}
		}
	}
	return iClosestEntity;
}

stock void AnglesNormalize(float vAngles[3])
{
	while(vAngles[0] >  89.0) vAngles[0]-=360.0;
	while(vAngles[0] < -89.0) vAngles[0]+=360.0;
	while(vAngles[1] > 180.0) vAngles[1]-=360.0;
	while(vAngles[1] <-180.0) vAngles[1]+=360.0;
}

stock float GetVectorAnglesTwoPoints(const float vStartPos[3], const float vEndPos[3], float vAngles[3])
{
	static float tmpVec[3];
	tmpVec[0] = vEndPos[0] - vStartPos[0];
	tmpVec[1] = vEndPos[1] - vStartPos[1];
	tmpVec[2] = vEndPos[2] - vStartPos[2];
	GetVectorAngles(tmpVec, vAngles);
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