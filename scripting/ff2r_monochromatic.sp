/*
	"monochrome"
	{
		"target"	"1" // 1: Bosses, 2: Non-Bosses, 3: Everyone
		"plugin_name"	"ff2r_monochromatic"
	}
*/

#include <tf2>
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <sourcemod>
#include <cfgmap>
#include <ff2r>

#pragma semicolon 1
#pragma newdecls required


#define VERSION_NUMBER "1.0.1"

public Plugin myinfo = {
	name = "Freak Fortress 2 Rewrite: Monochromatic",
	description = "The following has been brought to you in black and white",
	author = "Koishi, Zell",
	version = VERSION_NUMBER,
};

int effectboss = 0;
bool IsEnable = false;

public void OnPluginStart() {
	HookEvent("arena_win_panel", Event_RoundEnd);
	HookEvent("teamplay_round_win", Event_RoundEnd); // for non-arena maps

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

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup) {
	if (!(!setup || FF2R_GetGamemodeType() != 2)) {
		AbilityData ability = cfg.GetAbility("monochrome");
		if (ability.IsMyPlugin())
			PrepareOverlay(client, "monochrome", ability);
	}
}

public void OnClientPutInServer(int target) {
	if(!IsValidClient(target))
		return;

	if(IsEnable)
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			BossData boss = FF2R_GetBossData(client);
			if(boss)
				if(TargetType(client, target))
					CreateTimer(0.02, Monochrome_Prethink, target, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}


stock void SetMonochrome(int client)
{
	if(!IsValidClient(client))
		return;
	
	int flags=GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT);
	SetCommandFlags("r_screenoverlay", flags);
	ClientCommand(client, "r_screenoverlay \"%s\"", IsEnable ? "debug/yuv" : "");
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	IsEnable = false;
	for(int target = 1; target <= MaxClients; target++)
	{
		if(!IsValidClient(target))
			continue;

		SetMonochrome(target);
	}
}

public Action Monochrome_Prethink(Handle timer, int client) {
	if(!IsValidClient(client))
		return Plugin_Stop;

	if(!IsEnable) {
		SetMonochrome(client);
		return Plugin_Stop;
	}
	SetMonochrome(client);
	return Plugin_Continue;
}

public void PrepareOverlay(int client, const char[] ability_name, AbilityData ability) {
	IsEnable = true;
	effectboss = ability.GetInt("target", 0);
	for(int target = 1; target <= MaxClients; target++)
	{
		if(!IsValidClient(target))
			continue;

		if(TargetType(client, target))
			CreateTimer(0.02, Monochrome_Prethink, target, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

stock bool TargetType(int client, int target)
{
	switch(effectboss)
	{
		case 1: // if target is boss,
		{
			if(client == target)		
				return true;
			else return false;
		}
		case 2: // if target's team is not same team as boss's team
		{
			if(GetClientTeam(target) != GetClientTeam(client)) 
				return true;
			else return false;
		}
		case 3:
		{
			return true;
		}
		default: // effect everyone
		{
			return false;	
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