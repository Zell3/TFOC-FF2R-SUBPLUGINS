/*
"rage_projectile"	//Replace X with your last ability number
{
	"name"	"tf_projectile_rocket"		// Projectile Name
	"velocity"	"1100.0"					// Velocity
	
	//The following Arguments are only required if Projectile is not spell
	"mindamage"	"30"						// Minimum Damage (Proportional to the Damage Bonus of the Weapon Held by the Boss)
	"maxdamage"	"33"						// Maximum Damage (Proportional to the Damage Bonus of the Weapon Held by the Boss)
	"models"	"freak_fortress_2/myboss/nuclearwarhead.mdl"		// Overriden New Projectile Model
	"crits"	"1"							// Critical Chance; -1:Random Crits, 1:Crit, 0:No Random Crits
    }
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf2items>
#include <sdktools>
#include <sdkhooks>

#include "freak_fortress_2/formula_parser.sp"


#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME 	"Freak Fortress 2: Cast Projectile"
#define PLUGIN_AUTHOR 	"J0BL3SS"
#define PLUGIN_DESC 	"Rage projectile ability with various settings"

#define MAJOR_REVISION 	"1"
#define MINOR_REVISION 	"2"
#define STABLE_REVISION "0"
#define PLUGIN_VERSION 	MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define PLUGIN_URL ""

#define MAXPLAYERARRAY MAXPLAYERS+1

char PRJ_EntityName[768];					//arg1		- Projectile Name
float PRJ_Velocity;			//arg2		- Projectile Velocity
char PRJ_MinDamage[1024]; 	//arg3		- Minimum Damage [Formula]
char PRJ_MaxDamage[1024];	//arg4		- Maximum Damage [Formula]
char PRJ_NewModel[PLATFORM_MAX_PATH];		//arg5		- Override Projectile Model	
int	PRJ_Crit;				//arg6		- Critz: -1=Use Defaults, 1=Crit, 0=No Random Crits

enum Operators
{
	Operator_None = 0,
	Operator_Add,
	Operator_Subtract,
	Operator_Multiply,
	Operator_Divide,
	Operator_Exponent,
};

public Plugin myinfo = 
{
	name 		= PLUGIN_NAME,
	author 		= PLUGIN_AUTHOR,
	description	= PLUGIN_DESC,
	version 	= PLUGIN_VERSION,
	url			= PLUGIN_URL,
};

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
	if(!cfg.IsMyPlugin())	// Incase of duplicated ability names
		return;
	
	if(!cfg.GetBool("enabled", true))	// hidden/internal bool for abilities
		return;
	
	if(!StrContains(ability, "rage_projectile", false))
	{
		CastSpell(client, ability, cfg);
	}
}

public void CastSpell(int clientIdx, const char[] ability_name, AbilityData cfg)
{
	cfg.GetString("name", PRJ_EntityName, sizeof(PRJ_EntityName));
	PRJ_Velocity = cfg.GetFloat("velocity", 1100.0);
	cfg.GetString("mindamage", PRJ_MinDamage, sizeof(PRJ_MinDamage));
	cfg.GetString("maxdamage", PRJ_MaxDamage, sizeof(PRJ_MaxDamage));
	cfg.GetString("models", PRJ_NewModel, sizeof(PRJ_NewModel));
	PRJ_Crit = cfg.GetInt("crits", -1);
	
	float flAng[3], flPos[3];
	GetClientEyeAngles(clientIdx, flAng);
	GetClientEyePosition(clientIdx, flPos);
	
	int iTeam = GetClientTeam(clientIdx);
	int iProjectile = CreateEntityByName(PRJ_EntityName);
	
	float flVel1[3], flVel2[3];
	GetAngleVectors(flAng, flVel2, NULL_VECTOR, NULL_VECTOR);
	
	flVel1[0] = flVel2[0] * PRJ_Velocity;
	flVel1[1] = flVel2[1] * PRJ_Velocity;
	flVel1[2] = flVel2[2] * PRJ_Velocity;
	
	SetEntPropEnt(iProjectile, Prop_Send, "m_hOwnerEntity", clientIdx);
	if(!IsProjectileTypeSpell(PRJ_EntityName))
	{
		SetEntDataFloat(iProjectile, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4,
		GetRandomFloat(ParseFormula(PRJ_MinDamage, clientIdx), ParseFormula(PRJ_MaxDamage, clientIdx)), true);
		
		int CritValue;
		
		if(PRJ_Crit == 1) CritValue = 1;
		else if(PRJ_Crit == 0) CritValue = 0;
		else CritValue = (GetRandomInt(0, 100) <= 3 ? 1 : 0);
			
		SetEntProp(iProjectile, Prop_Send, "m_bCritical", CritValue, 1);
	}
	SetEntProp(iProjectile, Prop_Send, "m_iTeamNum", iTeam, 1);
	SetEntProp(iProjectile, Prop_Send, "m_nSkin", (iTeam-2));
	
	if(!IsModelPrecached(PRJ_NewModel))
	{
		if(FileExists(PRJ_NewModel, true))
		{
			PrecacheModel(PRJ_NewModel);
		}
		else
		{
			return;
		}
	}

	SetEntityModel(iProjectile, PRJ_NewModel);
	
	TeleportEntity(iProjectile, flPos, flAng, NULL_VECTOR);
	
	SetVariantInt(iTeam);
	AcceptEntityInput(iProjectile, "TeamNum", -1, -1, 0);
	SetVariantInt(iTeam);
	AcceptEntityInput(iProjectile, "SetTeam", -1, -1, 0);
	
	DispatchSpawn(iProjectile);
	TeleportEntity(iProjectile, NULL_VECTOR, NULL_VECTOR, flVel1);
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

stock bool IsProjectileTypeSpell(const char[] entity_name)
{
	if(StrContains(entity_name, "tf_projectile_spell", false) != -1 || !strcmp(entity_name, "tf_projectile_lightningorb")) return true;
	else return false;
}

stock void OperateString(ArrayList sumArray, int &bracket, char[] value, int size, ArrayList _operator)
{
	if(!StrEqual(value, ""))  //Make sure 'value' isn't blank
	{
		Operate(sumArray, bracket, StringToFloat(value), _operator);
		strcopy(value, size, "");
	}
}

stock void Operate(ArrayList sumArray, int &bracket, float value, ArrayList _operator)
{
	//Borrowed from Batfoxkid
	float sum = sumArray.Get(bracket);
	switch(_operator.Get(bracket))
	{
		case Operator_Add:sumArray.Set(bracket, sum + value);
		case Operator_Subtract:sumArray.Set(bracket, sum - value);
		case Operator_Multiply:sumArray.Set(bracket, sum * value);
		case Operator_Divide:
		{
			if(!value)
			{
				bracket = 0;
				return;
			}
			sumArray.Set(bracket, sum/value);
		}
		case Operator_Exponent: sumArray.Set(bracket, Pow(sum, value));
		default: sumArray.Set(bracket, value);  //This means we're dealing with a constant
	}
	_operator.Set(bracket, Operator_None);
}

stock int GetTotalPlayerCount()
{
	int total;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			total++;
		}
	}
	return total;
}
