/*
	"hook_ability"
	{
		"button"			"0"		// 0 = right mouse 1 = middle mouse 2 = reload
		"recharge"          "5.0"	//the time in seconds it takes for the ability to recharge
		"duration"          "2.0"	//how long in seconds until the grapple hook is removed thus ending the ability
		"hookmode"          "1" 	//changes how the grappling hook behaves (add the numbers together for the desired effect)
		//1 = ability stays active until the boss stops being pulled
		//2 = constantly use +attack1 while ability is active
		//4 = cooldown begins when the ability fully ends
		
		"attributes"		"280 ; 26 ; 547 ; 0.0 ; 199 ; 0.0 ; 712 ; 1 ; 138 ; 0.0"	//attributes that the grapple hook is given
		
		//text to display on the hud
		"verticalpos"		"0.77"	//the vertical position of the hud message 0.0 = the top of the screen
		"cdmessage"			"Grapple Hook %.0f%%"	// cooldown message
		"rdmessage"			"Grapple Hook Ready Press ATTACK2!"	// ready to use message

		"plugin_name"	"ff2r_grapplehookplus"
	}

	"hook_style"
	{
		"unhook"			"1"			//if set to 1 it makes the boss unhook from the player when switching from their grappling hook
		"destroy"			"1"			//sets what destroys the hook on contact (add numbers for desired effect)
		//1 = destroyed when hitting an enemy player
		//2 = destroyed when hitting an enemy building
		"dmgvsplayer"		"15.0"		//if the hook gets destroyed on enemy players, this is how much damage they will take from the hook hitting them
		"dmgvsbuilding"		"15.0"		//if the hook gets destroyed on enemy buildings, this is how much damage they will take from the hook hitting them
		"delay"				"1.0"		//prevents the boss from firing their weapons for X seconds after using a grappling hook
		"timer"				"1.0"		//automatically makes the boss unhook from a caught player if they've been attatched for more than X seconds
		
		"plugin_name"	"ff2r_grapplehookplus"
	}
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2>
#include <tf2items>

#pragma semicolon 1
#pragma newdecls required

int string_hud = 128;
int string_path = 256;

int HookRef[MAXPLAYERS+1];
float HookDelaySwing[MAXPLAYERS+1];
bool WasUsingHook[MAXPLAYERS+1];
bool HookAbilityActive[MAXPLAYERS+1];
float GrappleTimer[MAXPLAYERS+1];
float CoolTimer[MAXPLAYERS+1];
int LastSlot[MAXPLAYERS+1];
int LastButtons[MAXPLAYERS+1];


bool ActiveRound=false;

Handle AbilityHUD;

//hook_ability args
bool HasFF2HA[MAXPLAYERS+1];
int FF2HAButton[MAXPLAYERS+1];
float FF2HACoolTime[MAXPLAYERS+1];
float FF2HADuration[MAXPLAYERS+1];
int FF2HAFlags[MAXPLAYERS+1];
//1 = active until unused
//2 = constantly apply +attack1
//4 = cooldown when fully ended
//8 = disable weapon switching
char FF2HAAttrib[MAXPLAYERS+1][255];
float FF2HAHudOffset[MAXPLAYERS+1];

//hookstyle args
bool HasFF2HS[MAXPLAYERS+1];
int FF2HSGrabType[MAXPLAYERS+1];
int FF2HSHitFlags[MAXPLAYERS+1];
float FF2HSPlayerDmg[MAXPLAYERS+1];
float FF2HSEntityDmg[MAXPLAYERS+1];
// new FF2HSDmgFix[MAXPLAYERS+1];
float FF2HSFirePenalty[MAXPLAYERS+1];
float FF2HSGrabTime[MAXPLAYERS+1];

public Plugin myinfo=
{
	name="Freak Fortress 2 Rewrite: Grapple Hook Plus",
	author="kking117 , Zell",
	description="Just some stuff to help balance grapple hook bosses.",
	version="2.0",
};

public void OnPluginStart() {
	
	AbilityHUD = CreateHudSynchronizer();

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

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup) {
	if (!setup || FF2R_GetGamemodeType() != 2) {

		SDKUnhook(client, SDKHook_WeaponCanSwitchTo, Hook_WeaponCanSwitch);
		SDKHook(client, SDKHook_WeaponCanSwitchTo, Hook_WeaponCanSwitch); 
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

		ActiveRound = true;
		ClearVariables(client, "hook_ability");
		ClearVariables(client, "hook_style");

		AbilityData ability = cfg.GetAbility("hook_ability");
		if (ability.IsMyPlugin()) {
			HasFF2HA[client] = true;
			FF2HAButton[client] = ability.GetInt("button", 0);
			FF2HACoolTime[client] = ability.GetFloat("recharge", 5.0);
			FF2HADuration[client] = ability.GetFloat("duration", 2.0);
			FF2HAFlags[client] = ability.GetInt("hookmode", 15);
			ability.GetString("attributes", FF2HAAttrib[client], string_path);
			FF2HAHudOffset[client] = ability.GetFloat("verticalpos", 0.77);
			CoolTimer[client]=FF2HACoolTime[client];
		}
		AbilityData style = cfg.GetAbility("hook_style");
		if (style.IsMyPlugin()) {
			HasFF2HS[client] = true;
			FF2HSGrabType[client] = style.GetInt("unhook", 1);
			FF2HSHitFlags[client] = style.GetInt("destroy", 1);
			FF2HSPlayerDmg[client] = style.GetFloat("dmgvsplayer", 15.0);
			FF2HSEntityDmg[client] = style.GetFloat("dmgvsbuilding", 15.0);
			FF2HSFirePenalty[client] = style.GetFloat("delay", 0.75);
			FF2HSGrabTime[client] = style.GetFloat("timer", 1.0);
		}
	}
	ActiveRound=true;
	CreateTimer(0.2, ClientTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action ClientTimer(Handle timer)
{
	if(!ActiveRound)
		return Plugin_Stop;

	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			if(IsPlayerAlive(client))
			{
				if(IsBoss(client))
				{
					BossData boss = FF2R_GetBossData(client);
					AbilityData ability = boss.GetAbility("hook_ability");
					if (ability.IsMyPlugin()) {
						if(HasFF2HA[client])
						{
							float cooltime = CoolTimer[client]-GetGameTime();
							char HudMsg[255];
							
							cooltime = 100.0 - (((CoolTimer[client]-GetGameTime()) / FF2HACoolTime[client])*100.0);
							//so it doesn't say -0% sometimes
							if (cooltime<0.0)
								cooltime=0.0;
							
							if(TF2_IsPlayerInCondition(client, TFCond_GrapplingHook) || TF2_IsPlayerInCondition(client, TFCond_GrapplingHookLatched))
								if(!HasEquipmentByClassName(client, "tf_weapon_grapplinghook"))
									UnloadHook(client);

							if(CoolTimer[client] <= GetGameTime() && CoolTimer[client] >= 0.0)
							{
								ability.GetString("rdmessage", HudMsg, string_hud);
								ReplaceString(HudMsg, 255, "\\n", "\n");
								SetHudTextParams(-1.0, FF2HAHudOffset[client], 0.35, 255, 64, 64, 255, 0, 0.2, 0.0, 0.1);
								ShowSyncHudText(client, AbilityHUD, HudMsg);
							} else {
								ability.GetString("cdmessage", HudMsg, string_hud);
								ReplaceString(HudMsg, 255, "\\n", "\n");
								if(CoolTimer[client]==-1.0)
								{
									SetHudTextParams(-1.0, FF2HAHudOffset[client], 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
									ShowSyncHudText(client, AbilityHUD, HudMsg, 0.0);
								} else {
									SetHudTextParams(-1.0, FF2HAHudOffset[client], 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
									ShowSyncHudText(client, AbilityHUD, HudMsg, cooltime);
								}
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public void ClearVariables(int client, char[] ability_name)
{
	if(!strcmp(ability_name, "hook_ability"))
	{
		HasFF2HA[client]=false;
		FF2HAButton[client] = 0;
		FF2HACoolTime[client]=5.0;
		FF2HADuration[client]=2.0;
		FF2HAFlags[client]=15;
		FF2HAHudOffset[client]=0.77;
		
		HookRef[client]=0;
		HookDelaySwing[client]=0.0;
		WasUsingHook[client]=false;
		HookAbilityActive[client]=false;
		GrappleTimer[client]=0.0;
		CoolTimer[client]=0.0;
		LastSlot[client]=0;
	}
	else if(!strcmp(ability_name, "hook_style"))
	{
		HasFF2HS[client]=false;
		FF2HSGrabType[client]=1;
		FF2HSHitFlags[client]=1;
		FF2HSPlayerDmg[client]=15.0;
		FF2HSEntityDmg[client]=15.0;
		FF2HSFirePenalty[client]=0.75;
		FF2HSGrabTime[client]=1.0;
	}
}


public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual("tf_projectile_grapplinghook", classname))
	{
		CreateTimer(0.1, CheckProjectile, EntIndexToEntRef(entity));
		SDKHook(entity, SDKHook_StartTouch, OnStartTouchHooks);
	}
}

public void FF2R_OnBossRemoved(int client) {
	ActiveRound=false;
	UnloadHook(client);
	ClearVariables(client, "hook_ability");
	ClearVariables(client, "hook_style");
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(IsValidClient(attacker) && attacker!=victim && IsBoss(attacker))
	{
		if(IsValidEntity(weapon))
		{
			char WeaponName[64];
			GetEntityClassname(weapon, WeaponName, sizeof(WeaponName)); 
			if(StrEqual("tf_weapon_grapplinghook", WeaponName))
			{
				if(HasFF2HS[attacker])
				{
					if(FF2HSHitFlags[attacker] & 1) //kills the hook on contact with an enemy
					{
						CreateTimer(0.12, CheckHook, attacker);
					}
					else
					{
						if(FF2HSGrabTime[attacker]>0.0)
						{
							CreateTimer(FF2HSGrabTime[attacker], KillHook, HookRef[attacker]);
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;	
}

public Action CheckProjectile(Handle timer, int entity1)
{
	int entity = EntRefToEntIndex(entity1);
	if(IsValidEntity(entity))
	{
		bool DoneHere = false;
		int howner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		int curlauncher = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");
		int hownerclient;
		int curlauncherclient;
		if(IsValidEntity(howner) && !IsValidClient(howner))
		{
			hownerclient = GetEntPropEnt(howner, Prop_Send, "m_hOwnerEntity");
			if(IsValidClient(hownerclient))
			{
				DoneHere=true;
				HookRef[hownerclient]=entity1;
			}
		}
		if(!DoneHere && IsValidEntity(curlauncher) && !IsValidClient(curlauncher))
		{
			curlauncherclient = GetEntPropEnt(curlauncher, Prop_Send, "m_hOwnerEntity");
			if(IsValidClient(curlauncherclient))
			{
				HookRef[curlauncherclient]=entity1;
			}
		}
	}
	return Plugin_Continue;
}

public Action OnStartTouchHooks(int entity, int other)
{
	if(IsValidEntity(entity))
	{
		int projowner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if(IsValidEntity(projowner) && !IsValidClient(projowner)) //is actually the launcher or some other entity
		{
			projowner = GetEntPropEnt(projowner, Prop_Send, "m_hOwnerEntity"); //the actual owner
		}
		int attacker = projowner;
		if(IsValidClient(attacker) && IsBoss(attacker))
		{
			if(HasFF2HS[attacker])
			{
				if(IsValidClient(other) && GetClientTeam(other)!=GetEntProp(entity, Prop_Send, "m_iTeamNum"))
				{
					if(FF2HSHitFlags[attacker] & 1)
					{
						int client = other;
						int dmgtype;
						dmgtype = DMG_SLASH;
						if(GetEntProp(entity, Prop_Send, "m_bCritical")==1)
						{
							dmgtype |= DMG_ACID;
						}
						float dmg = FF2HSPlayerDmg[attacker];
						if(dmg<=160.0)
						{
							dmg=dmg/3.0;
						}
						DamageEntity(client, attacker, dmg, dmgtype, "");
						SDKHook(entity, SDKHook_Touch, OnTouch);
					}
					else
					{
						if(FF2HSGrabTime[attacker]>0.0)
						{
							CreateTimer(FF2HSGrabTime[attacker], KillHook, HookRef[attacker]);
						}
					}
				}
				else if(IsValidEntity(other))
				{
					CreateTimer(0.12, CheckHook, attacker);
					if(FF2HSHitFlags[attacker] & 2)
					{
						char classname[32];
						//buildings
						GetEdictClassname(other, classname, sizeof(classname));
						bool HurtableEnt=false;
						if(StrContains(classname, "obj_", false) != -1)
						{
							HurtableEnt=true;
						}
						else if(StrContains(classname, "_boss", false) != -1)
						{
							HurtableEnt=true;
						}
						else if(StrEqual(classname, "merasmus", false))
						{
							HurtableEnt=true;
						}
						else if(StrEqual(classname, "headless_hatman", false))
						{
							HurtableEnt=true;
						}
						if(HurtableEnt)
						{
							int dmgtype;
							dmgtype = DMG_SLASH;
							if(GetEntProp(entity, Prop_Send, "m_bCritical")==1)
							{
								dmgtype |= DMG_ACID;
							}
							float dmg = FF2HSEntityDmg[attacker];
							DamageEntity(other, attacker, dmg, dmgtype, "");
							SDKHook(entity, SDKHook_Touch, OnTouch);
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action OnTouch(int entity,int other)
{
	SDKUnhook(entity, SDKHook_Touch, OnTouch);
	AcceptEntityInput(entity, "Kill");
	return Plugin_Handled;
}

public Action KillHook(Handle timer,int entityref)
{
	int entity = EntRefToEntIndex(entityref);
	if(IsValidEntity(entity))
	{
		char classname[64];
		GetEntityClassname(entity, classname, sizeof(classname));
		if(StrEqual(classname, "tf_projectile_grapplinghook", false))
		{
			RemoveEdict(entity);
		}
	}
	return Plugin_Continue;
}

public Action CheckHook(Handle timer,int client)
{
	if(IsValidClient(client))
	{
		if(TF2_IsPlayerInCondition(client, TFCond_GrapplingHook) || TF2_IsPlayerInCondition(client, TFCond_GrapplingHookLatched))
		{
			int activewep = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
			char entname[50];
			GetEntityClassname(activewep, entname, sizeof(entname));
			if(!StrEqual(entname, "tf_weapon_grapplinghook", false))
			{
				UnloadHook(client);
			}
		}
	}
	return Plugin_Continue;
}

public Action Hook_WeaponCanSwitch(int client, int weapon) 
{
	if(IsValidEntity(weapon))
	{
		if(IsBoss(client))
		{
			char WeaponName[64];
			GetEntityClassname(weapon, WeaponName, sizeof(WeaponName));
			if(!StrEqual("tf_weapon_grapplinghook", WeaponName))
			{
				if(HasFF2HS[client])
				{
					if(TF2_IsPlayerInCondition(client, TFCond_GrapplingHook) || TF2_IsPlayerInCondition(client, TFCond_GrapplingHookLatched))
					{
						if(FF2HSGrabType[client]!=0)
						{
							UnloadHook(client);
						}
					}
					if(HookDelaySwing[client]>GetGameTime())
					{
						SetEntPropFloat(weapon, Prop_Data, "m_flNextPrimaryAttack", HookDelaySwing[client]);
					}
				}
				for(int slot = 0; slot<3; slot++)
				{
					if(GetPlayerWeaponSlot(client, slot)==weapon)
					{
						LastSlot[client] = slot;
						break;
					}
				}
			}
			else
			{
				if(HasFF2HA[client] && HookAbilityActive[client])
				{
					if(GrappleTimer[client]-0.25<=GetGameTime())
					{
						return Plugin_Stop;
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapons, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
	if(IsValidClient(client))
	{
		if(IsPlayerAlive(client))
		{
			int wp = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
			if(IsBoss(client))
			{
				if(HasFF2HS[client])
				{
					if(TF2_IsPlayerInCondition(client, TFCond_GrapplingHook) || TF2_IsPlayerInCondition(client, TFCond_GrapplingHookLatched))
					{
						WasUsingHook[client]=true;
						if(FF2HSFirePenalty[client]>0.0)
						{
							HookDelaySwing[client] = GetGameTime()+FF2HSFirePenalty[client];
						}
						else
						{
							HookDelaySwing[client] = 0.0;
						}
					}
					else if(!TF2_IsPlayerInCondition(client, TFCond_GrapplingHook) && !TF2_IsPlayerInCondition(client, TFCond_GrapplingHookLatched))
					{
						WasUsingHook[client]=false;
					}
				}
				if(ActiveRound)
				{
					if(HasFF2HA[client])
					{
						if(!HookAbilityActive[client] && CoolTimer[client]<=GetGameTime())
						{
							if(FF2HAButton[client]==1)
							{
								if(!(LastButtons[client] & IN_ATTACK3) && (buttons & IN_ATTACK3))
								{
									InitiateHookAbility(client);
								}
							}
							else if(FF2HAButton[client]==2)
							{
								if(!(LastButtons[client] & IN_RELOAD) && (buttons & IN_RELOAD))
								{
									InitiateHookAbility(client);
								}
							}
							else
							{
								if(!(LastButtons[client] & IN_ATTACK2) && (buttons & IN_ATTACK2))
								{
									InitiateHookAbility(client);
								}
							}
						}
						else if(HookAbilityActive[client])
						{
							bool keepattacking = true;
							if(GrappleTimer[client]-0.25<=GetGameTime())
							{
								if((FF2HAFlags[client] & 1) && TF2_IsPlayerInCondition(client, TFCond_GrapplingHook) && TF2_IsPlayerInCondition(client, TFCond_GrapplingHookLatched))
								{
								}
								else
								{
									keepattacking=false;
									EndHookAbility1(client);
								}
							}
							if(IsValidEntity(wp) && keepattacking)
							{
								if(FF2HAFlags[client] & 2)
								{
									char classname[64];
									GetEntityClassname(wp, classname, sizeof(classname));
									if(StrEqual(classname, "tf_weapon_grapplinghook", false))
									{
										buttons |= IN_ATTACK;
									}
								}
							}
						}
					}
				}
				LastButtons[client] = buttons;
			}
		}
	}
	return Plugin_Changed;
}

public void InitiateHookAbility(int client)
{
	if(IsValidClient(client))
	{
		if(IsBoss(client))
		{
			for(int slot = 0; slot<3; slot++)
			{
				if(GetPlayerWeaponSlot(client, slot)==GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon"))
				{
					LastSlot[client] = slot;
					break;
				}
			}
			SpawnWeapon(client, "tf_weapon_grapplinghook", 1152, 1, 6, FF2HAAttrib[client]);
			HookAbilityActive[client]=true;
			GrappleTimer[client] = GetGameTime()+FF2HADuration[client];
			SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", GetPlayerWeaponSlot(client, 5));
			if(FF2HAFlags[client] & 4)
			{
				CoolTimer[client]=-1.0;
			}
			else
			{
				CoolTimer[client]=GetGameTime()+FF2HACoolTime[client];
			}
		}
	}
}

public void EndHookAbility1(int client)
{
	if(IsValidClient(client))
	{
		if(IsBoss(client))
		{
			int activewep = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
			if(IsValidEntity(activewep))
			{
				char entname[50];
				GetEntityClassname(activewep, entname, sizeof(entname));
				if(StrEqual(entname, "tf_weapon_grapplinghook", false))
				{
					//attempt to switch back to the last standard weapon they used
					if(IsValidEntity(GetPlayerWeaponSlot(client, LastSlot[client])))
					{
						SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", GetPlayerWeaponSlot(client, LastSlot[client]));
						if(HasFF2HS[client] && FF2HSFirePenalty[client]>0.0)
						{
							SetEntPropFloat(GetPlayerWeaponSlot(client, LastSlot[client]), Prop_Data, "m_flNextPrimaryAttack", HookDelaySwing[client]);
						}
					}
					else
					{
						if(IsValidEntity(GetPlayerWeaponSlot(client, 2)))
						{
							SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", GetPlayerWeaponSlot(client, 2));
							if(HasFF2HS[client] && FF2HSFirePenalty[client]>0.0)
							{
								SetEntPropFloat(GetPlayerWeaponSlot(client, 2), Prop_Data, "m_flNextPrimaryAttack", HookDelaySwing[client]);
							}
						}
						else if(IsValidEntity(GetPlayerWeaponSlot(client, 0)))
						{
							SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", GetPlayerWeaponSlot(client, 0));
							if(HasFF2HS[client] && FF2HSFirePenalty[client]>0.0)
							{
								SetEntPropFloat(GetPlayerWeaponSlot(client, 0), Prop_Data, "m_flNextPrimaryAttack", HookDelaySwing[client]);
							}
						}
						else if(IsValidEntity(GetPlayerWeaponSlot(client, 1)))
						{
							SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", GetPlayerWeaponSlot(client, 1));
							if(HasFF2HS[client] && FF2HSFirePenalty[client]>0.0)
							{
								SetEntPropFloat(GetPlayerWeaponSlot(client, 1), Prop_Data, "m_flNextPrimaryAttack", HookDelaySwing[client]);
							}
						}
					}
				}
			}
			UnloadHook(client);
			if(FF2HAFlags[client] & 4)
			{
				CoolTimer[client]=GetGameTime()+FF2HACoolTime[client];
			}
			HookAbilityActive[client]=false;
			CreateTimer(0.25, EndHookAbility2, client);
		}
	}
}

public Action EndHookAbility2(Handle timer,int client)
{
	if(IsValidClient(client))
	{
		int activewep = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		if(IsValidEntity(activewep))
		{
			char entname[50];
			GetEntityClassname(activewep, entname, sizeof(entname));
			if(!StrEqual(entname, "tf_weapon_grapplinghook", false))
			{
			}
		}
		RemoveEquipmentByClassName(client, "tf_weapon_grapplinghook");
		UnloadHook(client);
	}
	return Plugin_Continue;
}

public void UnloadHook(int client)
{
	if(IsValidClient(client))
	{
		int entity = EntRefToEntIndex(HookRef[client]);
		if(IsValidEntity(entity))
		{
			char classname[64];
			GetEntityClassname(entity, classname, sizeof(classname));
			if(StrEqual(classname, "tf_projectile_grapplinghook", false))
			{
				RemoveEdict(entity);
			}
		}
		TF2_RemoveCondition(client, TFCond_GrapplingHookLatched);
		TF2_RemoveCondition(client, TFCond_GrapplingHook);
		HookRef[client]=0;
	}
}

public void DamageEntity(int client, int attacker, float dmg, int dmg_type, char[] weapon)
{
	if(IsValidClient(client) || IsValidEntity(client))
	{
		if(IsValidClient(client) && !IsFakeClient(client))
		{
			Format(weapon, 1, ""); //point hurt will crash the server if you specify the classname against live players
		}
		int damage = RoundToNearest(dmg);
		char dmg_str[16];
		IntToString(damage,dmg_str,16);
		char dmg_type_str[32];
		IntToString(dmg_type,dmg_type_str,32);
		int pointHurt=CreateEntityByName("point_hurt");
		if(pointHurt)
		{
			DispatchKeyValue(client,"targetname","targetsname_ff2r_grapplehookplus");
			DispatchKeyValue(pointHurt,"DamageTarget","targetsname_ff2r_grapplehookplus");
			DispatchKeyValue(pointHurt,"Damage",dmg_str);
			DispatchKeyValue(pointHurt,"DamageType",dmg_type_str);
			if(!StrEqual(weapon,""))
			{
				DispatchKeyValue(pointHurt,"classname",weapon);
			}
			DispatchSpawn(pointHurt);
			if(IsValidEntity(attacker))
			{
				float AttackLocation[3];
				GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", AttackLocation);
				TeleportEntity(pointHurt, AttackLocation, NULL_VECTOR, NULL_VECTOR);
			}
			AcceptEntityInput(pointHurt,"Hurt",(attacker>0)?attacker:-1);
			DispatchKeyValue(pointHurt,"classname","point_hurt");
			DispatchKeyValue(client,"targetname","donthurtme");
			RemoveEdict(pointHurt);
		}
	}
}

public void RemoveEquipmentByClassName(int client, char classname[255])
{
	if(IsValidClient(client))
	{
		if(StrEqual(classname, "tf_wearable_weapon", false))
		{
			int i = -1; 
			while ((i = FindEntityByClassname(i, "tf_wearabl*")) != -1)
			{ 
				if(client == GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity"))
				{
					if(IsValidEntity(i))
					{
						int index=GetEntProp(i, Prop_Send, "m_iItemDefinitionIndex");
						switch(index)
						{
							case 131, 406, 1099, 1144, 133, 444, 642, 231, 57, 405, 608: //every wearable weapon
							{
								AcceptEntityInput(i, "Kill"); 
							}
						}
					}
				}
			}
		}
		else
		{
			int i = -1; 
			while ((i = FindEntityByClassname(i, classname)) != -1)
			{ 
				if(client == GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity"))
				{
					if(IsValidEntity(i))
					{
						AcceptEntityInput(i, "Kill");
					}
				}
			}
		}
	}
}

stock bool HasEquipmentByClassName(int client, char classname[255])
{
	if(IsValidClient(client))
	{
		int i = -1; 
		while ((i = FindEntityByClassname(i, classname)) != -1)
		{ 
			if(client == GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity"))
			{
				if(IsValidEntity(i))
				{
					return true;
				}
			}
		}
	}
	return false;
}

stock int SpawnWeapon(int client, char[] name,int index,int level,int qual, char[] att)
{
	Handle hWeapon=TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	if(hWeapon==INVALID_HANDLE)
	{
		return -1;
	}

	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	char atts[32][32];
	int count=ExplodeString(att, ";", atts, 32, 32);

	if(count % 2)
	{
		--count;
	}

	if(count>0)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		int i2;
		for(int i; i<count; i+=2)
		{
			int attrib=StringToInt(atts[i]);
			if(!attrib)
			{
				LogError("Bad weapon attribute passed: %s ; %s", atts[i], atts[i+1]);
				CloseHandle(hWeapon);
				return -1;
			}

			TF2Items_SetAttribute(hWeapon, i2, attrib, StringToFloat(atts[i+1]));
			i2++;
		}
	}
	else
	{
		TF2Items_SetNumAttributes(hWeapon, 0);
	}

	int entity=TF2Items_GiveNamedItem(client, hWeapon);
	CloseHandle(hWeapon);
	EquipPlayerWeapon(client, entity);
	return entity;
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

stock bool IsBoss(int client)
{
	if(IsValidClient(client))
		if(FF2R_GetBossData(client))
			return true;
	return false;
}