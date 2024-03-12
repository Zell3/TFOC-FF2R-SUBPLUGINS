/*
	"passive_doublejump"
	{
		"target"        "1"             // 0: Everyone, 1: Boss, 2: Boss Team, 3: Enemy Team, 4: Except boss
		"velocity"		"250.0"         // Velocity
		"max"		    "1"             // Max of extra jump
		"plugin_name"	"ff2r_doublejump"
	}

	"rage_doublejump"	// Ability name can use suffixes
	{
		"slot"			"0"             // Ability Slot
		"duration"      "10.0"          // Duration
		"target"        "1"             // 0: Everyone, 1: Boss, 2: Boss Team, 3: Enemy Team, 4: Except boss
		"velocity"		"250.0"         // Velocity
		"max"		    "1"             // Max of extra jump
		"plugin_name"	"ff2r_doublejump"
	}
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name = "[FF2R] Double Jump",
	author = "Paegus, Zell",
	description = "Doublejump!!!!",
	version = "1.0.0",
	url = "http://203.159.92.45/donate/"
};

bool isActive;
bool IsTarget[MAXPLAYERS+1];
float g_flBoost[MAXPLAYERS+1];
int g_fLastButtons[MAXPLAYERS+1];
int g_fLastFlags[MAXPLAYERS+1];
int g_iJumps[MAXPLAYERS+1];
int g_iJumpMax[MAXPLAYERS+1];
int g_target;

public void OnPluginStart() {
	for (int client = 1; client <= MaxClients; client++) {
		IsTarget[client] = false;
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

public void OnClientPutInServer(int target) {
	if(!isActive)
		return;

	for (int client = 1; client <= MaxClients; client++)
		if (IsClientInGame(client) && FF2R_GetBossData(client))
			if(IsClientTarget(client, target, g_target))
				IsTarget[target] = true;
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup) {
	if (!setup || FF2R_GetGamemodeType() != 2) {
		AbilityData ability = cfg.GetAbility("passive_doublejump");
		if (ability.IsMyPlugin()) {
			isActive = true;
			g_target = ability.GetInt("target", 0);

			for (int target = 1; target <= MaxClients; target++) {
				if(IsValidClient(target)) {
					if(IsClientTarget(client, target, g_target)) {
						g_flBoost[target] = ability.GetFloat("velocity", 250.0);
						g_iJumpMax[target] = ability.GetInt("max", 1);
						IsTarget[target] = true;
					}
				}
			}
		}
	}
}

public void FF2R_OnBossRemoved(int clientIdx) {
	isActive = false;
	for (int target = 1; target <= MaxClients; target++)
		IsTarget[target] = false;
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
	if (!StrContains(ability, "rage_doublejump", false) && cfg.IsMyPlugin()) {
		isActive = true;
		g_target = cfg.GetInt("target", 0);
		float duration = cfg.GetFloat("duration", 0.0);

		for (int target = 1; target <= MaxClients; target++) {
			if(IsValidClient(target)) {
				if(IsClientTarget(client, target, g_target)) {
					IsTarget[target] = true;
					g_flBoost[target] = cfg.GetFloat("velocity", 250.0);
					g_iJumpMax[target] = cfg.GetInt("max", 1);
					CreateTimer(duration, EndDoubleJump, target, TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}
	}
}

public Action EndDoubleJump(Handle timer, int client) {
	IsTarget[client] = false;

	return Plugin_Stop;
}

public void OnGameFrame() {
	if (isActive) 							        // double jump active
		for (int i = 1; i <= MaxClients; i++) 		// cycle through players
			if (IsValidClient(i) && IsTarget[i] && IsPlayerAlive(i))
				DoubleJump(i);						// Check for double jumping
}

stock void DoubleJump(const int client) {
	int fCurFlags	= GetEntityFlags(client);		// current flags
	int fCurButtons	= GetClientButtons(client);		// current buttons
	
	if (g_fLastFlags[client] & FL_ONGROUND) {		// was grounded last frame
		if (
			!(fCurFlags & FL_ONGROUND) &&			// becomes airbirne this frame
			!(g_fLastButtons[client] & IN_JUMP) &&	// was not jumping last frame
			fCurButtons & IN_JUMP					// started jumping this frame
		) {
			OriginalJump(client);					// process jump from the ground
		}
	} else if (										// was airborne last frame
		fCurFlags & FL_ONGROUND						// becomes grounded this frame
	) {
		Landed(client);								// process landing on the ground
	} else if (										// remains airborne this frame
		!(g_fLastButtons[client] & IN_JUMP) &&		// was not jumping last frame
		fCurButtons & IN_JUMP						// started jumping this frame
	) {
		ReJump(client);								// process attempt to double-jump
	}
	
	g_fLastFlags[client]	= fCurFlags;				// update flag state for next frame
	g_fLastButtons[client]	= fCurButtons;			// update button state for next frame
}

stock void OriginalJump(const int client) {
	g_iJumps[client]++;	    // increment jump count
}

stock void Landed(const int client) {
	g_iJumps[client] = 0;	// reset jumps count
}

stock void ReJump(const int client) {
	if ( 1 <= g_iJumps[client] <= g_iJumpMax[client]) {						// has jumped at least once but hasn't exceeded max re-jumps
		g_iJumps[client]++;											// increment jump count
		float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);	// get current speeds
		
		vVel[2] = g_flBoost[client];
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);		// boost player
	}
}

stock bool IsClientTarget(int client, int target, int type)
{
	switch(type)
	{
		case 1: // if target is boss,
		{
			if(client == target)		
				return true;
			else return false;
		}
		case 2: // if target's team same team as boss's team
		{
			if(GetClientTeam(target) == GetClientTeam(client)) 
				return true;
			else return false;
		}
		case 3: // if target's team is not same team as boss's team
		{
			if(GetClientTeam(target) != GetClientTeam(client)) 
				return true;
			else return false;
		}
		case 4: // if target is not boss
		{
			if(client != target) 
				return true;
			else return false;
		}
		default: // effect everyone
		{
			return true;	
		}
	}
}

stock bool IsValidClient(int client, bool replaycheck=true)
{
	if(client <= 0 || client > MaxClients)
		return false;

	if(!IsClientInGame(client) || !IsClientConnected(client))
		return false;

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
		return false;

	if(replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
		return false;

	return true;
}	