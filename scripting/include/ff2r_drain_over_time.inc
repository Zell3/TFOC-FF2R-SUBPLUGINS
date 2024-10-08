// clearly I'm going senile. I've already forgotten that these won't work there's no way to guarantee plugin load order.
//native CancelDOTAbilityActivation(bossClientIdx);
//native ForceDOTAbilityDeactivation(bossClientIdx);
//native SetDOTUsability(bossClientIdx, usable);

// so we'll have to do reflection instead
stock Handle FindDOTPlugin()
{
	char buffer[256];
	
	Handle iter = GetPluginIterator();
	Handle pl = INVALID_HANDLE;
	
	while (MorePlugins(iter))
	{
		pl = ReadPlugin(iter);
		
		GetPluginFilename(pl, buffer, sizeof(buffer));
		//PrintToServer("plugin: %s", buffer);
		if (StrContains(buffer, "ff2r_drain_over_time.smx", false) != -1) // hahaha, a function with a boolean sounding name which returns -1 on failure. lololololol
			break;
		else
			pl = INVALID_HANDLE;
	}
	
	CloseHandle(iter);
	
	//if (pl == INVALID_HANDLE)
	//	PrintToServer("Invalid handle.");
	//else
	//{
	//	GetPluginFilename(pl, buffer, sizeof(buffer));
	//	PrintToServer("plugin: %s", buffer);
	//}
	
	return pl;
}

// this is only called when a DOT ability needs to be treated like it was never activated
// this should only be called in OnDOTAbilityActivated()
stock void CancelDOTAbilityActivation(int bossClientIdx)
{
	Handle plugin = FindDOTPlugin();
	if (plugin != INVALID_HANDLE)
	{
		Function func = GetFunctionByName(plugin, "CancelDOTAbilityActivation");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(bossClientIdx);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2r_drain_over_time.sp:CancelDOTAbilityActivation().");
	}
	else
		PrintToServer("ERROR: Could not find DOT plugin. CancelDOTAbilityActivation() failed.");
}

// this allows drain over time subplugins to deactivate the DOT
// this should only be called in OnDOTAbilityTick()
stock void ForceDOTAbilityDeactivation(int bossClientIdx)
{
	Handle plugin = FindDOTPlugin();
	if (plugin != INVALID_HANDLE)
	{
		Function func = GetFunctionByName(plugin, "ForceDOTAbilityDeactivation");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(bossClientIdx);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2r_drain_over_time.sp:ForceDOTAbilityDeactivation().");
	}
	else
		PrintToServer("ERROR: Could not find DOT plugin. ForceDOTAbilityDeactivation() failed.");
}

// this sets a DOT to be usable or unusable
stock void SetDOTUsability(bossClientIdx, usable)
{
	Handle plugin = FindDOTPlugin();
	if (plugin != INVALID_HANDLE)
	{
		Function func = GetFunctionByName(plugin, "SetDOTUsability");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(bossClientIdx);
			Call_PushCell(usable);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find drain_over_time.sp:SetDOTUsability().");
	}
	else
		PrintToServer("ERROR: Could not find DOT plugin. SetDOTUsability() failed.");
}
