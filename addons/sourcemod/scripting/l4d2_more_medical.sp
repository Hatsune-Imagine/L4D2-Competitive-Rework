#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define VERSION "1.2"

int currentMultiple = 1;

public Plugin myinfo = 
{
	name = "L4D2 More Medical",
	author = "HatsuneImagine",
	description = "More medical items based on player counts.",
	version = VERSION,
	url = "https://github.com/Hatsune-Imagine/l4d2-plugins"
}

public void OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_connect", Event_PlayerConnect);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(10.0, DelayTimer);
}

void Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(1.0, DelayTimer);
}

void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(1.0, DelayTimer);
}

Action DelayTimer(Handle timer)
{
	SetMoreMedical(RoundToCeil(GetAllPlayerCount() / 4.0));
	return Plugin_Continue;
}

void SetMoreMedical(int count)
{
	if (count <= 0)
		return;

	if (count == currentMultiple)
		return;

	currentMultiple = count;

	char gameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), gameMode, sizeof(gameMode));
	if (StrContains(gameMode, "versus") > -1 || StrContains(gameMode, "scavenge") > -1)
		return;

	char entCount[2];
	IntToString(count, entCount, sizeof(entCount));
	SetEntCount("weapon_defibrillator_spawn", entCount);	//电击器
	SetEntCount("weapon_first_aid_kit_spawn", entCount);	//医疗包
	SetEntCount("weapon_pain_pills_spawn", entCount);		//止痛药
	SetEntCount("weapon_adrenaline_spawn", entCount);		//肾上腺素
}

void SetEntCount(const char[] entName, const char[] entCount)
{
	int edictIndex = FindEntityByClassname(-1, entName);
	while (edictIndex != -1)
	{
		if (IsValidEntity(edictIndex))
			DispatchKeyValue(edictIndex, "count", entCount);

		edictIndex = FindEntityByClassname(edictIndex, entName);
	}
}

int GetAllPlayerCount()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i) && !IsFakeClient(i))
			count++;

	return count;
}
