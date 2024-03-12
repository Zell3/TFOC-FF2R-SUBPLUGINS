/*
	"rage_hinttext"		//Ability name can use suffixes
	{
		"slot"			"0"								// Ability Slot
		"message"		"Go Get Them Maggot!"			// Hinttext Message
		"plugin_name"	"ff2r_subplugin_template"		// this subplugin name
	}
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf2items>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME     "Freak Fortress 2 Rewrite: Block Item/PowerUp dropping"
#define PLUGIN_AUTHOR   "Naydef"
#define PLUGIN_VERSION  "1.0"
#define ABILITY_NAME "blockdropitem"

#define MAJOR_REVISION 	"1"
#define MINOR_REVISION 	"0"
#define STABLE_REVISION "1"

#define PLUGIN_URL ""

#define MAXTF2PLAYERS	36

public Plugin myinfo = 
{
	name 		= PLUGIN_NAME,
	author 		= PLUGIN_AUTHOR,
	version 	= PLUGIN_VERSION,
};

public void OnPluginStart()
{
	for(int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
	{
		if(IsClientInGame(clientIdx))
		{
			OnClientPutInServer(clientIdx);
			
			BossData cfg = FF2R_GetBossData(clientIdx);	// Get boss config (known as boss index) from player
			if(cfg)
			{
				FF2R_OnBossCreated(clientIdx, cfg, false);	// If boss is valid, Hook the abilities because this subplugin is most likely late-loaded
			}
		}
	}
}

public void OnClientPutInServer(int clientIdx)
{
	// Check and apply stuff if boss abilities that can effect players is active
}

public void OnPluginEnd()
{
	for(int clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
	{
		// Clear everything from players, because FF2:R either disabled/unloaded or this subplugin unloaded
	}
}

public void FF2R_OnBossCreated(int clientIdx, BossData cfg, bool setup)
{	
	AddCommandListener(Command_DropItem, "dropitem");
	/*
	 * When boss created, hook the abilities etc.
	 *
	 * We no longer use RoundStart Event to hook abilities because bosses can be created trough 
	 * manually by command in other gamemodes other than Arena or create bosses mid-round.
	 *
	 */
}

public void FF2R_OnBossRemoved(int clientIdx)
{
	 /*
	  * When boss removed (Died/Left the Game/New Round Started)
	  * 
	  * Unhook and clear ability effects from the player/players
	  *
	  */
}

public Action Command_DropItem(int clientIdx, const char[] command, int argc)
{
	if(IsPlayerAlive(clientIdx))
	{
		if(!clientIdx)
			return Plugin_Handled;
		BossData boss = FF2R_GetBossData(clientIdx);
		if(!boss)
			return Plugin_Handled;
		AbilityData ability = boss.GetAbility("blockdropitem");
		if(!ability.IsMyPlugin())
			return Plugin_Handled;
		static char buffer[256];
		ability.GetString("message", buffer, sizeof(buffer));
		if(buffer[0] != '\0') {
			KickClient(clientIdx, buffer);
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
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