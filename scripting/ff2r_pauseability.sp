/*
"rage_pause"
{
	"duration"	"6.0"       // Time(in seconds) the effect will be active
	"plugin_name"	"ff2r_pauseability" // Plugin name
}
*/

#include <sourcemod>
#include <sdktools>
#include <cfgmap>
#include <ff2r>
#include <tf2>

#pragma semicolon 1
#pragma newdecls required

//Defines
#define PLUGIN_VERSION "0.5.1"
#define ABILITY "ff2_pause"

//Declarations
Handle pauseCVar;
bool paused;
bool IsProxy[MAXPLAYERS+1];
Handle rageTM[MAXPLAYERS+1];

public Plugin myinfo = {
	name = "Freak Fortress 2 Rewrite: Pause Ability", 
	author = "Naydef, Zell",
	description = "Subplugin, which can pause the whole server!",
	version = "0.5.3",
	url = "https://forums.alliedmods.net/forumdisplay.php?f=154"
};

public void OnPluginStart() {
	pauseCVar = FindConVar("sv_pausable");
	if(pauseCVar == INVALID_HANDLE)
		SetFailState("sv_pausable convar not found. Subplugin disabled!!!");

	AddCommandListener(Listener_PauseCommand, "pause");
	AddCommandListener(Listener_PauseCommand, "unpause"); // For safety
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
	if (!StrContains(ability, "rage_pause", false) && cfg.IsMyPlugin()) {
		float time = cfg.GetFloat("duration", 0.0);

		for(int i = 1; i <= MaxClients; i++) {
			if(!IsValidClient(i))
				continue;

			SetNextAttack(i, time);
			SilentCvarChange(pauseCVar, true);
			SetConVarBool(pauseCVar, true);
			SilentCvarChange(pauseCVar, false);

			if(!paused)
			{
				IsProxy[i] = true;
				FakeClientCommand(i, "pause");
				IsProxy[i] = false;
			}
			paused = true;

			Handle packet = CreateDataPack();
			WritePackCell(packet, GetClientUserId(i));
			rageTM[i] = CreateTimer(time, Timer_UnPause, packet, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public void OnClientDisconnect(int client)
{
	if(rageTM[client] != INVALID_HANDLE)
	{
		TriggerTimer(rageTM[client]);
		rageTM[client] = INVALID_HANDLE;
	}
	IsProxy[client] = false;
}

public Action Listener_PauseCommand(int client, const char[] command, int argc)
{
	if(!IsProxy[client])
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action Timer_UnPause(Handle htimer, Handle packet)
{
	ResetPack(packet);
	int client = GetClientOfUserId(ReadPackCell(packet));

	if(!IsValidClient(client))
		return Plugin_Stop;

	SilentCvarChange(pauseCVar, true);
	SetConVarBool(pauseCVar, true);
	SilentCvarChange(pauseCVar, false);
	IsProxy[client] = true;

	if(paused)
		FakeClientCommand(client, "pause");

	paused = false;
	IsProxy[client] = false;
	rageTM[client] = INVALID_HANDLE;

	for(int i = 1; i <= MaxClients; i++)
		if(IsValidClient(i))
			SetNextAttack(i, 0.1);

	CloseHandle(packet);
	return Plugin_Continue;
}


stock bool IsValidClient(int client, bool replaycheck = true)
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

stock void SilentCvarChange(Handle cvar, bool setsilent = true)
{
	int flags = GetConVarFlags(cvar);
	(setsilent) ? (flags^=FCVAR_NOTIFY) : (flags|=FCVAR_NOTIFY);
	SetConVarFlags(cvar, flags);
}

stock void SetNextAttack(int client, float time) // Fix prediction
{
	if(IsValidClient(client))
	{
		SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime() + time);
		for(int i = 0; i <= 2; i++)
		{
			int weapon = GetPlayerWeaponSlot(client, i);
			if(IsValidEntity(weapon))
				SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + time);
		}
	}
}