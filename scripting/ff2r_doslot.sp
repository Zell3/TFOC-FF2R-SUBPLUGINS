/*
	"rage_doslot"	// Ability name can use suffixes
	{
		"slot"		    "0"			// Ability Slot
		"delay"		    "3.0"		// Delay before first use
		"doslot"		"20"		// Trigger Slot

		"plugin_name"	"ff2r_doslot"	// Plugin Name
	}
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>

#pragma semicolon 1
#pragma newdecls required

bool IsRound;

public Plugin myinfo = {
	name = "[FF2R] Do Slot",
	author = "Zell Copy Batfox code like a pro",
	description = "Do ability slot and have it delay",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart() {
}

public void OnPluginEnd() {
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client) && FF2R_GetBossData(client)) {
			FF2R_OnBossRemoved(client);
		}
	}
}

public void FF2R_OnBossRemoved(int clientIdx) {
	IsRound = false;
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
	if (!StrContains(ability, "rage_doslot", false) && cfg.IsMyPlugin()) {
		IsRound = true;
		DataPack pack;
		CreateDataTimer(cfg.GetFloat("delay", 0.0), DoSlot, pack, TIMER_FLAG_NO_MAPCHANGE);
		pack.WriteCell(client);
		pack.WriteCell(cfg.GetInt("doslot"));
	}
}

public Action DoSlot(Handle timer, DataPack pack) {
	if(!IsRound)
		return Plugin_Stop;
	pack.Reset();
	int client = pack.ReadCell();
	int slot = pack.ReadCell();
	
	FF2R_DoBossSlot(client, slot);
	
	return Plugin_Continue;
}