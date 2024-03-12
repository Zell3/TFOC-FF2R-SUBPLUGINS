/*
	"darkrealm_passive"
	{
		// start round - melee
		// melee damage x (1 + (meleemultiplier * kills after round start))
		"meleemultiplier"		"0.05"

		// 5 kills - loose cannon
		// loose cannon damage x (1 + (cannonmultiplier * kills after 5 kills))
		"cannonmultiplier"		"0.05"      

		// 10 kills - loose cannon now have big explosion

		// 15 kills - all multiplier
		// melee damage x (1 + (meleemultiplier * kills after round start) + (allmultiplier * kills after 15 kills))
		// loose cannon damage x (1 + (cannonmultiplier * kills after 5 kills) + (allmultiplier * kills after 15 kills))
		"allmultiplier"         "0.10"



		"plugin_name"	"ff2r_darkrealm"	// Plugin Name
	}

	"darkrealm_rage" // Ability name can use suffixes
	{
		"slot"       "0"
		"kill"       "5"                     // How many kills need to trigger that slot
		"doslot"     ""                      // Slot that will be trigger
		"plugin_name"	"ff2r_darkrealm"	// Plugin Name
	}
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <tf2items>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <tf2attributes>

#pragma semicolon 1
#pragma newdecls required

bool IsPassiveActive;
bool IsRageActive;
float ML_Multiplier[MAXPLAYERS + 1];
float CN_Multiplier[MAXPLAYERS + 1];
float AL_Multiplier[MAXPLAYERS + 1];
static int DR_Killcount[MAXPLAYERS + 1];

Handle DarkRealmHud;

public Plugin myinfo = {
	name = "[FF2R] Dark Realms Erandicator Abilities",
	author = "Zell",
	description = "For Dark Realms Only",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart() {
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
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

public void OnClientPutInServer(int client){
	if (IsPassiveActive)
		if (IsValidClient(client))
   			SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}


public void FF2R_OnBossCreated(int client, BossData cfg, bool setup) {
	if (!setup || FF2R_GetGamemodeType() != 2) {
		AbilityData ability = cfg.GetAbility("darkrealm_passive");
		if (ability.IsMyPlugin()) {
			ML_Multiplier[client] = 0.0;
			CN_Multiplier[client] = 0.0;
			AL_Multiplier[client] = 0.0;
			DR_Killcount[client] = 0;
			IsPassiveActive = true;
			DarkRealmHud = CreateHudSynchronizer();
			HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_PostNoCopy);
			SDKHook(client, SDKHook_PreThink, DarkRealmHud_Prethink);
			for (int i = 1; i <= MaxClients; i++) {
				if (IsValidClient(i)) {
					SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
				}
			}
			ML_Multiplier[client] = ability.GetFloat("meleemultiplier", 0.05);
			CN_Multiplier[client] = ability.GetFloat("cannonmultiplier", 0.05);
			AL_Multiplier[client] = ability.GetFloat("allmultiplier", 0.10);
		}
	}
}

public void FF2R_OnBossRemoved(int client) {
	if(IsRageActive)	
		IsRageActive = false;
	if(IsPassiveActive)	{
		IsPassiveActive = false;
		ML_Multiplier[client] = 0.0;
		CN_Multiplier[client] = 0.0;
		AL_Multiplier[client] = 0.0;
		DR_Killcount[client] = 0;
		UnhookEvent("player_death", Event_OnPlayerDeath, EventHookMode_PostNoCopy);
		for (int i = 1; i <= MaxClients; i++) {
			if (IsValidClient(i)) {
				SDKUnhook(i, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}
		SDKUnhook(client, SDKHook_PreThink, DarkRealmHud_Prethink);
	}
}

public Action Event_OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	if(!IsPassiveActive)
		return Plugin_Continue;
		
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if((GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
		return Plugin_Continue;

	if (!FF2R_GetBossData(attacker))
		return Plugin_Continue;

	BossData cfg = FF2R_GetBossData(attacker);
	AbilityData ability = cfg.GetAbility("darkrealm_passive");
	if (ability.IsMyPlugin()) {
		if(FF2R_GetBossData(victim)) {
			FF2R_OnBossRemoved(victim);
		} else{
			DR_Killcount[attacker] = DR_Killcount[attacker] + 1;
		}

		// float meleedmgmulti = 1.0;
		// if(DR_Killcount[attacker] > 0) {
		// 		meleedmgmulti += (ML_Multiplier[attacker] * DR_Killcount[attacker]);
		// }

		// float cannondmgmulti = 1.0;
		// if(DR_Killcount[attacker] > 5) {
		// 		cannondmgmulti += (CN_Multiplier[attacker] * (DR_Killcount[attacker]-5));
		// }

		// if(DR_Killcount[attacker] > 15) {
		// 		meleedmgmulti += (AL_Multiplier[attacker] * (DR_Killcount[attacker]-15));
		// 		cannondmgmulti += (AL_Multiplier[attacker] * (DR_Killcount[attacker]-15));
		// }

		// char meleeattr[2048];
		// Format(meleeattr, sizeof(meleeattr),
		// "2025 ; 3 ; 2013 ; 2004 ; 2014 ; 2 ; 149 ; 5 ; 137 ; 5 ; 252 ; 0.5 ; 5 ; 0.7 ; 2 ; %.2f", meleedmgmulti);
		// SpawnWeapon(attacker, "tf_weapon_wrench", 155, 15, 13, meleeattr);

		if (DR_Killcount[attacker] == 5) {
			SpawnWeapon(attacker, "tf_weapon_cannon", 996, 15, 13,
			"4 ; 999 ; 112 ; 999 ; 5 ; 1.5 ; 318 ; 0.00001 ; 2025 ; 3 ; 2013 ; 2004 ; 2014 ; 2");
		}
		else if (DR_Killcount[attacker] == 12) {
			SpawnWeapon(attacker, "tf_weapon_cannon", 996, 16, 14,
			"4 ; 999 ; 112 ; 999 ; 5 ; 1.8 ; 318 ; 0.00001 ; 521 ; 1 ; 2025 ; 3 ; 2013 ; 2004 ; 2014 ; 2 ; 99 ; 1");
		}
	}

	return Plugin_Continue;
}

public void DarkRealmHud_Prethink(int client)
{
	if(!IsPlayerAlive(client) || !IsValidClient(client, false)) // Round ended or boss was defeated?	
		return;

	BossData boss = FF2R_GetBossData(client);
	if (!boss)
		return;

	AbilityData ability = boss.GetAbility("darkrealm_passive");
	if (!ability.IsMyPlugin()) 
		return;

	if(DR_Killcount[client] >= 0 && DR_Killcount[client] < 5 )
	{
		SetHudTextParams(-1.0,0.70,0.1,64,255,64,255);
		ShowSyncHudText(client, DarkRealmHud, "Kills : %i\nMelee DMG x %.2f",
		DR_Killcount[client],
		(1 + (ML_Multiplier[client] * DR_Killcount[client])) );
	}
	else if(DR_Killcount[client] >= 5 && DR_Killcount[client] < 15)
	{
		SetHudTextParams(-1.0,0.70,0.1,255,255,64,255);
		ShowSyncHudText(client, DarkRealmHud, "Kills : %i\nMelee DMG x %.2f | Cannon DMG x %.2f", 
		DR_Killcount[client],
		(1 + (ML_Multiplier[client] * DR_Killcount[client])), (1 + (CN_Multiplier[client] * (DR_Killcount[client]- 5))));        
	}
	else if(DR_Killcount[client] >= 15)
	{
		SetHudTextParams(-1.0,0.70,0.1,255,64,64,255);
		ShowSyncHudText(client, DarkRealmHud, "Kills : %i\nMelee DMG x %.2f | Cannon DMG x %.2f",
		DR_Killcount[client],
		(1 + (ML_Multiplier[client] * DR_Killcount[client])) + (AL_Multiplier[client] * (DR_Killcount[client]-15)),
		(1 + (CN_Multiplier[client] * (DR_Killcount[client]- 5))) + (AL_Multiplier[client] * (DR_Killcount[client]-15)));        
	}

}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
	if (!StrContains(ability, "darkrealm_rage", false) && cfg.IsMyPlugin()) {
		if( DR_Killcount[client] >= cfg.GetInt("kill"))
			FF2R_DoBossSlot(client, cfg.GetInt("doslot"));
	}
}

void SpawnWeapon(int client, char[] classname, int index, int level, int quality, char[] attributes)
{
	int slot = TF2_GetClassnameSlot(classname);
	TF2_RemoveWeaponSlot(client, slot);
	int entity = -1;

	Handle item = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(item, classname);
	TF2Items_SetItemIndex(item, index);
	TF2Items_SetLevel(item, level);
	TF2Items_SetQuality(item, quality);

	static char buffers[40][256];
	int count = ExplodeString(attributes, " ; ", buffers, sizeof(buffers), sizeof(buffers));
	if (count > 0)
	{
		TF2Items_SetNumAttributes(item, count/2);
		int i2 = 0;
		for (int i = 0; i < count; i+=2)
		{
			TF2Items_SetAttribute(item, i2, StringToInt(buffers[i]), StringToFloat(buffers[i+1]));
			i2++;
		}
	}
	entity = TF2Items_GiveNamedItem(client, item);
	delete item;
	
	EquipPlayerWeapon(client, entity);
	SetEntityRenderMode(entity, RENDER_ENVIRONMENTAL);
	SetEntProp(entity, Prop_Send, "m_iAccountID", GetSteamAccountID(client, false));
	FakeClientCommand(client, "use %s", classname);
}

public Action OnTakeDamage(int victim,int &attacker,int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]){
	if(!IsPassiveActive)
		return Plugin_Continue;

	if(!IsValidClient(attacker) && !IsValidClient(victim))
		return Plugin_Continue;
	
	if(!IsPlayerAlive(attacker) && !IsPlayerAlive(victim))
		return Plugin_Continue;

	if(FF2R_GetBossData(attacker) && FF2R_GetBossData(attacker).GetAbility("darkrealm_passive").IsMyPlugin())
	{
		float damageMult = 1.0;
		if(DR_Killcount[attacker] >= 0) {
			if (weapon == GetPlayerWeaponSlot(attacker, TFWeaponSlot_Melee)) {
		 		damageMult += (ML_Multiplier[attacker] * DR_Killcount[attacker]);
			}
		}
		if(DR_Killcount[attacker] >= 5) {
			if (weapon == GetPlayerWeaponSlot(attacker, TFWeaponSlot_Primary)) {
				damageMult += (CN_Multiplier[attacker] * (DR_Killcount[attacker]-5));
			}
		}
		if(DR_Killcount[attacker] >= 15)
			damageMult += (AL_Multiplier[attacker] * (DR_Killcount[attacker]-15));

		damage *= damageMult;
		return Plugin_Changed;
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

stock int TF2_GetClassnameSlot(const char[] classname, bool econ = false)
{
	if(StrEqual(classname, "player"))
	{
		return -1;
	}
	else if(StrEqual(classname, "tf_weapon_scattergun") ||
	   StrEqual(classname, "tf_weapon_handgun_scout_primary") ||
	   StrEqual(classname, "tf_weapon_soda_popper") ||
	   StrEqual(classname, "tf_weapon_pep_brawler_blaster") ||
	  !StrContains(classname, "tf_weapon_rocketlauncher") ||
	   StrEqual(classname, "tf_weapon_particle_cannon") ||
	   StrEqual(classname, "tf_weapon_flamethrower") ||
	   StrEqual(classname, "tf_weapon_grenadelauncher") ||
	   StrEqual(classname, "tf_weapon_cannon") ||
	   StrEqual(classname, "tf_weapon_minigun") ||
	   StrEqual(classname, "tf_weapon_shotgun_primary") ||
	   StrEqual(classname, "tf_weapon_sentry_revenge") ||
	   StrEqual(classname, "tf_weapon_drg_pomson") ||
	   StrEqual(classname, "tf_weapon_shotgun_building_rescue") ||
	   StrEqual(classname, "tf_weapon_syringegun_medic") ||
	   StrEqual(classname, "tf_weapon_crossbow") ||
	  !StrContains(classname, "tf_weapon_sniperrifle") ||
	   StrEqual(classname, "tf_weapon_compound_bow"))
	{
		return TFWeaponSlot_Primary;
	}
	else if(!StrContains(classname, "tf_weapon_pistol") ||
	  !StrContains(classname, "tf_weapon_lunchbox") ||
	  !StrContains(classname, "tf_weapon_jar") ||
	   StrEqual(classname, "tf_weapon_handgun_scout_secondary") ||
	   StrEqual(classname, "tf_weapon_cleaver") ||
	  !StrContains(classname, "tf_weapon_shotgun") ||
	   StrEqual(classname, "tf_weapon_buff_item") ||
	   StrEqual(classname, "tf_weapon_raygun") ||
	  !StrContains(classname, "tf_weapon_flaregun") ||
	  !StrContains(classname, "tf_weapon_rocketpack") ||
	  !StrContains(classname, "tf_weapon_pipebomblauncher") ||
	   StrEqual(classname, "tf_weapon_laser_pointer") ||
	   StrEqual(classname, "tf_weapon_mechanical_arm") ||
	   StrEqual(classname, "tf_weapon_medigun") ||
	   StrEqual(classname, "tf_weapon_smg") ||
	   StrEqual(classname, "tf_weapon_charged_smg"))
	{
		return TFWeaponSlot_Secondary;
	}
	else if(!StrContains(classname, "tf_weapon_r"))	// Revolver
	{
		return econ ? TFWeaponSlot_Secondary : TFWeaponSlot_Primary;
	}
	else if(StrEqual(classname, "tf_weapon_sa"))	// Sapper
	{
		return econ ? TFWeaponSlot_Building : TFWeaponSlot_Secondary;
	}
	else if(!StrContains(classname, "tf_weapon_i") || !StrContains(classname, "tf_weapon_pda_engineer_d"))	// Invis & Destory PDA
	{
		return econ ? TFWeaponSlot_Item1 : TFWeaponSlot_Building;
	}
	else if(!StrContains(classname, "tf_weapon_p"))	// Disguise Kit & Build PDA
	{
		return econ ? TFWeaponSlot_PDA : TFWeaponSlot_Grenade;
	}
	else if(!StrContains(classname, "tf_weapon_bu"))	// Builder Box
	{
		return econ ? TFWeaponSlot_Building : TFWeaponSlot_PDA;
	}
	else if(!StrContains(classname, "tf_weapon_sp"))	 // Spellbook
	{
		return TFWeaponSlot_Item1;
	}
	return TFWeaponSlot_Melee;
}