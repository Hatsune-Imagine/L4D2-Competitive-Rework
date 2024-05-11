#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>

#define VERSION "1.0"

public Plugin myinfo = {
	name = "L4D2 Full Health Transition",
	author = "HatsuneImagine",
	description = "Make survivor full health during map transition.",
	version = VERSION,
	url = "https://github.com/Hatsune-Imagine/l4d2-plugins"
}

public void OnPluginStart() {
	HookEvent("map_transition", Event_MapTransition, EventHookMode_Pre);
}

void Event_MapTransition(Event event, const char[] name, bool dontBroadcast) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2) {
			if (!IsPlayerAlive(i)) {
				L4D_RespawnPlayer(i);
				TeleportPlayer(i, GetAnyAliveSurvivorExcept(i));
			}
			CheatCommand(i, "give health");
		}
	}
}

void CheatCommand(int client, const char[] command) {
	if (!client || !IsClientInGame(client))
		return;

	char cmd[32];
	if (SplitString(command, " ", cmd, sizeof cmd) == -1)
		strcopy(cmd, sizeof cmd, command);

	int bits = GetUserFlagBits(client);
	int flags = GetCommandFlags(cmd);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags(cmd, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, command);
	SetUserFlagBits(client, bits);
	SetCommandFlags(cmd, flags);

	if (strcmp(cmd, "give") == 0 && strcmp(command[5], "health") == 0)
		L4D_SetPlayerTempHealth(client, 0); //防止有虚血时give health会超过100血
}

int GetAnyAliveSurvivorExcept(int client) {
	for (int i = 1; i <= MaxClients; i++)
		if (client != i && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			return i;
	return -1;
}

void TeleportPlayer(int client, int target) {
	if (!client || !target)
		return;

	if (!IsClientInGame(client) || !IsClientInGame(target))
		return;

	float vPos[3];
	GetClientAbsOrigin(target, vPos);
	TeleportEntity(client, vPos);
}
