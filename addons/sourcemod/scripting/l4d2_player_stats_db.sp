#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <geoip>

#define TEAM_SPECTATOR	1
#define TEAM_SURVIVOR	2
#define TEAM_INFECTED	3

#define ZC_SMOKER		1
#define ZC_BOOMER		2
#define ZC_HUNTER		3
#define ZC_SPITTER		4
#define ZC_JOCKEY		5
#define ZC_CHARGER		6
#define ZC_WITCH		7
#define ZC_TANK			8

enum struct PlayerInfo
{
	char ip[16];
	char country[32];
	char region[32];
	char city[32];
	float latitude;
	float longitude;
	char steamId[32];
	char nickname[32];
	int gametime;
	int headshot;
	int melee;
	int ciKilled;
	int smokerKilled;
	int boomerKilled;
	int hunterKilled;
	int spitterKilled;
	int jockeyKilled;
	int chargerKilled;
	int witchKilled;
	int tankKilled;
	int siDamageValue;
	float siDamagePercent;
	int totalFF;
	int totalFFReceived;
	float totalFFPercent;
	int adrenalineUsed;
	int pillsUsed;
	int medkitUsed;
	int teammateProtected;
	int teammateRevived;
	int teammateIncapped;
	int teammateKilled;
	int ledgeHanged;
	int incapped;
	int dead;
	int missionCompleted;
	int missionLost;
	int smokerTongueCut;
	int smokerSelfCleared;
	int hunterSkeeted;
	int chargerLeveled;
	int witchCrowned;
	int tankRockSkeeted;
	int tankRockEaten;
	int alarmTriggered;
	float avgInstaClearTime;
	ArrayList instaClearTime;
}

int allSiDamage;
int allFF;

Database g_db;
PlayerInfo g_players[MAXPLAYERS + 1];
char g_playersInGame[MAXPLAYERS + 1][32];
char g_serverName[32];
char g_serverIP[16];
char g_serverPort[8];
char g_serverMap[32];
char g_serverMode[32];
int g_mapRound;

bool isSkillDetectLoaded;
bool isCompetitiveInRound;

public Plugin myinfo = {
	name = "L4D2 Player Stats with Database",
	author = "HatsuneImagine",
	description = "Store & Fetch player stats from/to databases.",
	version = "2.0",
	url = "https://github.com/Hatsune-Imagine/l4d2-plugins"
}

public void OnPluginStart() {
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", Event_MissionLost, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_MissionCompleted, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_MissionCompleted, EventHookMode_PostNoCopy);
	HookEvent("adrenaline_used", Event_AdrenalineUsed, EventHookMode_Post);
	HookEvent("pills_used", Event_PillsUsed, EventHookMode_Post);
	HookEvent("heal_success", Event_HealSuccess, EventHookMode_Post);
	HookEvent("award_earned", Event_AwardEarned, EventHookMode_Post);
	HookEvent("revive_success", Event_ReviveSuccess, EventHookMode_Post);
	HookEvent("player_ledge_grab", Event_PlayerLedgeGrab, EventHookMode_Post);
	HookEvent("player_incapacitated", Event_PlayerIncapacitated, EventHookMode_Post);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("infected_hurt", Event_InfectedHurt, EventHookMode_Post);
	HookEvent("infected_death", Event_InfectedDeath, EventHookMode_Post);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("witch_killed", Event_WitchDeath, EventHookMode_Post);

	FindConVar("hostname").GetString(g_serverName, sizeof(g_serverName));
	FindConVar("net_public_adr").GetString(g_serverIP, sizeof(g_serverIP));
	if (StrEqual(g_serverIP, "")) FindConVar("ip").GetString(g_serverIP, sizeof(g_serverIP));
	FindConVar("hostport").GetString(g_serverPort, sizeof(g_serverPort));
	HandleSpecialChar(g_serverName, sizeof(g_serverName));

	RegConsoleCmd("sm_debug_mystats", Cmd_My_Stats, "Show my stats.");
	RegConsoleCmd("sm_debug_my_stats", Cmd_My_Stats, "Show my stats.");

	for (int i = 0; i < MAXPLAYERS + 1; i++) {
		g_players[i].instaClearTime = new ArrayList();
	}

	AddCommandListener(CommandListener, "");
	Database.Connect(ConnectCallback, "player_stats");
}

public void OnAllPluginsLoaded() {
	isSkillDetectLoaded = LibraryExists("skill_detect");
}

public void OnLibraryAdded(const char[] name) {
	CheckLib(name, true);
}

public void OnLibraryRemoved(const char[] name) {
	CheckLib(name, false);
}

void CheckLib(const char[] name, bool state) {
	if (strcmp(name, "skill_detect") == 0) {
		isSkillDetectLoaded = state;
	}
}

Action Cmd_My_Stats(int client, int args) {
	PrintToChat(client, "IP: %s", g_players[client].ip);
	PrintToChat(client, "Country: %s", g_players[client].country);
	PrintToChat(client, "Region: %s", g_players[client].region);
	PrintToChat(client, "City: %s", g_players[client].city);
	PrintToChat(client, "Latitude: %.6f", g_players[client].latitude);
	PrintToChat(client, "Longitude: %.6f", g_players[client].longitude);
	PrintToChat(client, "SteamID: %s", g_players[client].steamId);
	PrintToChat(client, "Nickname: %s", g_players[client].nickname);
	PrintToChat(client, "GameTime: %d", g_players[client].gametime);
	PrintToChat(client, "Headshot: %d", g_players[client].headshot);
	PrintToChat(client, "Melee: %d", g_players[client].melee);
	PrintToChat(client, "CI Killed: %d", g_players[client].ciKilled);
	PrintToChat(client, "Smoker Killed: %d", g_players[client].smokerKilled);
	PrintToChat(client, "Boomer Killed: %d", g_players[client].boomerKilled);
	PrintToChat(client, "Hunter Killed: %d", g_players[client].hunterKilled);
	PrintToChat(client, "Spitter Killed: %d", g_players[client].spitterKilled);
	PrintToChat(client, "Jockey Killed: %d", g_players[client].jockeyKilled);
	PrintToChat(client, "Charger Killed: %d", g_players[client].chargerKilled);
	PrintToChat(client, "Witch Killed: %d", g_players[client].witchKilled);
	PrintToChat(client, "Tank Killed: %d", g_players[client].tankKilled);
	PrintToChat(client, "SI Damage Value: %d", g_players[client].siDamageValue);
	PrintToChat(client, "SI Damage Percent: %.2f", g_players[client].siDamagePercent);
	PrintToChat(client, "Total FF: %d", g_players[client].totalFF);
	PrintToChat(client, "Total FF Received: %d", g_players[client].totalFFReceived);
	PrintToChat(client, "Total FF Percent: %.2f", g_players[client].totalFFPercent);
	PrintToChat(client, "Adrenaline Used: %d", g_players[client].adrenalineUsed);
	PrintToChat(client, "Pills Used: %d", g_players[client].pillsUsed);
	PrintToChat(client, "Medkit Used: %d", g_players[client].medkitUsed);
	PrintToChat(client, "Teammate Protected: %d", g_players[client].teammateProtected);
	PrintToChat(client, "Teammate Revived: %d", g_players[client].teammateRevived);
	PrintToChat(client, "Teammate Incapped: %d", g_players[client].teammateIncapped);
	PrintToChat(client, "Teammate Killed: %d", g_players[client].teammateKilled);
	PrintToChat(client, "Ledge Hanged: %d", g_players[client].ledgeHanged);
	PrintToChat(client, "Incapped: %d", g_players[client].incapped);
	PrintToChat(client, "Dead: %d", g_players[client].dead);
	PrintToChat(client, "Mission Completed: %d", g_players[client].missionCompleted);
	PrintToChat(client, "Mission Lost: %d", g_players[client].missionLost);
	PrintToChat(client, "Smoker Tongue Cut: %d", g_players[client].smokerTongueCut);
	PrintToChat(client, "Smoker Self Cleared: %d", g_players[client].smokerSelfCleared);
	PrintToChat(client, "Hunter Skeeted: %d", g_players[client].hunterSkeeted);
	PrintToChat(client, "Charger Leveled: %d", g_players[client].chargerLeveled);
	PrintToChat(client, "Witch Crowned: %d", g_players[client].witchCrowned);
	PrintToChat(client, "Tank Rock Skeeted: %d", g_players[client].tankRockSkeeted);
	PrintToChat(client, "Tank Rock Eaten: %d", g_players[client].tankRockEaten);
	PrintToChat(client, "Alarm Triggered: %d", g_players[client].alarmTriggered);
	PrintToChat(client, "Avg Insta-Clear Time: %.2f", g_players[client].avgInstaClearTime);

	PrintToChat(client, "Insta-Clear Array: ");
	PrintToChat(client, "[");
	for (int i = 0; i < g_players[client].instaClearTime.Length; i++) {
		PrintToChat(client, "\t%.2f", g_players[client].instaClearTime.Get(i));
	}
	PrintToChat(client, "]");
	return Plugin_Continue;
}

Action CommandListener(int client, char[] command, int argc) {
	if (!IsRealClient(client)) {
		return Plugin_Continue;
	}

	StringToLowerCase(command);
	if (!StrEqual(command, "say") && !StrEqual(command, "say_team")) {
		return Plugin_Continue;
	}

	char team[16];
	char msg[256];
	GetTeamName(GetClientTeam(client), team, sizeof(team));
	GetCmdArgString(msg, sizeof(msg));
	StripQuotes(msg);
	HandleSpecialChar(msg, sizeof(msg));

	// 保存玩家聊天记录
	if (StrEqual(command, "say")) {
		SQL_InsertChatLog(client, team, msg);
	}
	else if (StrEqual(command, "say_team")) {
		Format(msg, sizeof(msg), "(TEAM) %s", msg);
		SQL_InsertChatLog(client, team, msg);
	}

	return Plugin_Continue;
}

public void OnClientAuthorized(int client) {
	// 玩家进入游戏
	if (IsFakeClient(client)) {
		return;
	}

	// 初始化玩家本局缓存数据
	InitCachedPlayerInfo(client);
	// 保存玩家连接记录
	SQL_InsertConnectLog(client);
}

public void OnMapEnd() {
	// 章节结束，重置回合数
	g_mapRound = 0;
}

public void OnPluginEnd() {
	// 插件卸载
	CloseHandle(g_db);
}

void Event_AdrenalineUsed(Event event, const char[] name, bool dontBroadcast) {
	// 玩家使用肾上腺素
	int client = GetClientOfUserId(event.GetInt("userid"));
	// PrintToChatAll("%d:%N used adrenaline!", client, client);
	if (IsValidClient(client)) {
		g_players[client].adrenalineUsed++;
	}
}

void Event_PillsUsed(Event event, const char[] name, bool dontBroadcast) {
	// 玩家使用止痛药
	int client = GetClientOfUserId(event.GetInt("userid"));
	// PrintToChatAll("%d:%N used pills!", client, client);
	if (IsValidClient(client)) {
		g_players[client].pillsUsed++;
	}
}

void Event_HealSuccess(Event event, const char[] name, bool dontBroadcast) {
	// 玩家使用医疗包
	int client = GetClientOfUserId(event.GetInt("subject"));
	// int helper = GetClientOfUserId(event.GetInt("userid"));
	// PrintToChatAll("%d:%N healed %d:%N", helper, helper, client, client);
	if (IsValidClient(client)) {
		g_players[client].medkitUsed++;
	}
}

void Event_AwardEarned(Event event, const char[] name, bool dontBroadcast) {
	// 玩家保护队友
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subjectEnt = GetClientOfUserId(event.GetInt("subjectEntid"));
	int awardId = event.GetInt("award");

	// PrintToChatAll("%d:%N protected %d:%N, awardId = %i", client, client, subjectEnt, subjectEnt, awardId);
	if (IsValidClient(client) && IsValidClient(subjectEnt) && awardId == 67) {
		g_players[client].teammateProtected++;
	}
}

void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast) {
	// 玩家救起队友
	// int client = GetClientOfUserId(event.GetInt("subject"));
	int helper = GetClientOfUserId(event.GetInt("userid"));
	// PrintToChatAll("%d:%N revived %d:%N", helper, helper, client, client);
	if (IsValidClient(helper)) {
		g_players[helper].teammateRevived++;
	}
}

void Event_PlayerLedgeGrab(Event event, const char[] name, bool dontBroadcast) {
	// 玩家挂边
	int client = GetClientOfUserId(event.GetInt("userid"));
	// PrintToChatAll("%d:%N hanged on ledge!", client, client);
	if (IsValidClient(client)) {
		g_players[client].ledgeHanged++;
	}
}

void Event_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast) {
	// 玩家倒地
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	// PrintToChatAll("%d:%N incapped!", victim, victim);
	if (IsValidClient(victim) && GetClientTeam(victim) == TEAM_SURVIVOR) {
		g_players[victim].incapped++;
	}
	if (IsValidClient(attacker) && IsValidClient(victim) && GetClientTeam(attacker) == TEAM_SURVIVOR && GetClientTeam(victim) == TEAM_SURVIVOR && attacker != victim) {
		g_players[attacker].teammateIncapped++;
	}
}

void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
	// 玩家退出，保存此玩家本局缓存数据 -> 数据库
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && client <= MaxClients) {
		int currentTime = RoundToNearest(GetEngineTime());
		g_players[client].gametime = currentTime - g_players[client].gametime;
		g_players[client].siDamagePercent = allSiDamage == 0 ? (g_players[client].siDamageValue > 0 ? 1.0 : 0.0) : float(g_players[client].siDamageValue) / float(allSiDamage);
		g_players[client].totalFFPercent = allFF == 0 ? (g_players[client].totalFF > 0 ? 1.0 : 0.0) : float(g_players[client].totalFF) / float(allFF);
		float allInstaClearTime = 0.0;
		for (int j = 0; j < g_players[client].instaClearTime.Length; j++) {
			char eachClearTime[8];
			FormatEx(eachClearTime, sizeof(eachClearTime), "%.2f", g_players[client].instaClearTime.Get(j));
			// LogMessage("Client: %d:%N, Insta-Clear Time Array Content[%d]: %s", client, client, j, eachClearTime);
			allInstaClearTime += StringToFloat(eachClearTime);
		}
		g_players[client].avgInstaClearTime = g_players[client].instaClearTime.Length > 0 ? allInstaClearTime / g_players[client].instaClearTime.Length : 0.0;

		// 更新此玩家总体数据
		SQL_UpdatePlayerInfo(client);
		// 新增此玩家本局详情
		SQL_InsertPlayerRoundDetail(client);

		// 清除此client缓存数据
		ClearCachedPlayerInfo(client);
		g_playersInGame[client] = "";
	}
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	// 回合开始
	if ((IsVersus() || IsScavenge())) {
		isCompetitiveInRound = true;
	}
	GetCurrentMap(g_serverMap, sizeof(g_serverMap));
	FindConVar("mp_gamemode").GetString(g_serverMode, sizeof(g_serverMode));
	g_mapRound++;

	// 重置所有玩家本局缓存数据
	for (int i = 1; i <= MaxClients; i++) {
		ResetCachedPlayerInfo(i);
	}
	allSiDamage = 0;
	allFF = 0;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	// 回合结束（仅用于处理竞技类型模式），保存所有玩家本局缓存数据 -> 数据库
	if ((IsVersus() || IsScavenge()) && isCompetitiveInRound) {
		isCompetitiveInRound = false;
		SaveAllPlayerInfoAndDetail(false, false);
	}
}

void Event_MissionLost(Event event, const char[] name, bool dontBroadcast) {
	// 回合结束（团灭），保存所有玩家本局缓存数据 -> 数据库
	if (!(IsVersus() || IsScavenge())) {
		SaveAllPlayerInfoAndDetail(true, false);
	}
}

void Event_MissionCompleted(Event event, const char[] name, bool dontBroadcast) {
	// 回合结束（过关），保存所有玩家本局缓存数据 -> 数据库
	if (!(IsVersus() || IsScavenge())) {
		SaveAllPlayerInfoAndDetail(true, true);
	}
}



/*
Such actions will trigger such events.

KillCI
	Infected Hurt
	Infected Death
	Player Death

KillSI
	Player Hurt
	Player Death

KillWitch
	Infected Hurt
	Infected Death
	Player Death
	Witch Death

KillTank
	Player Hurt
	Player Death
*/

// KillCI, KillWitch
void Event_InfectedHurt(Event event, const char[] name, bool dontBroadcast) {
	// 感染者受伤，统计玩家对Witch伤害
	int victimEntId = event.GetInt("entityid");

	if (IsWitch(victimEntId)) {
		int attacker = GetClientOfUserId(event.GetInt("attacker"));
		int damageDone = event.GetInt("amount");

		if (IsValidClient(attacker) && GetClientTeam(attacker) == TEAM_SURVIVOR) {
			g_players[attacker].siDamageValue += damageDone;
			allSiDamage += damageDone;
		}
	}
}

// KillCI, KillWitch
void Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast) {
	// 感染者死亡，统计玩家普通感染者击杀数
	int victimEntId = event.GetInt("entityid");

	if (!IsWitch(victimEntId)) {
		int attacker = GetClientOfUserId(event.GetInt("attacker"));

		if (IsValidClient(attacker) && GetClientTeam(attacker) == TEAM_SURVIVOR) {
			g_players[attacker].ciKilled++;
		}
	}
}

// KillSI, KillTank, FF
void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	// 玩家受伤，统计玩家对特感伤害/玩家友伤
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int damageDone = event.GetInt("dmg_health");

	if (IsValidClient(attacker) && IsValidClient(victim)) {
		// 生还者攻击特感
		if (GetClientTeam(attacker) == TEAM_SURVIVOR && GetClientTeam(victim) == TEAM_INFECTED) {
			g_players[attacker].siDamageValue += damageDone;
			allSiDamage += damageDone;
		}
		// 生还者攻击生还者
		if (GetClientTeam(attacker) == TEAM_SURVIVOR && GetClientTeam(victim) == TEAM_SURVIVOR && !IsPlayerIncapacitated(victim)) {
			g_players[attacker].totalFF += damageDone;
			g_players[victim].totalFFReceived += damageDone;
			allFF += damageDone;
		}
	}
}

// KillCI, KillSI, KillWitch, KillTank
void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	// 玩家死亡，统计玩家特感击杀数
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	bool headshot = event.GetBool("headshot");
	char weapon[64];
	event.GetString("weapon", weapon, sizeof(weapon));

	if (IsValidClient(attacker) && IsValidClient(victim)) {
		// 生还者击杀特感
		if (GetClientTeam(attacker) == TEAM_SURVIVOR && GetClientTeam(victim) == TEAM_INFECTED) {
			int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");

			// 统计6种特感 + Tank 击杀数 (Witch需单独处理)
			if (zombieClass == ZC_SMOKER) {
				g_players[attacker].smokerKilled++;
			}
			else if (zombieClass == ZC_BOOMER) {
				g_players[attacker].boomerKilled++;
			}
			else if (zombieClass == ZC_HUNTER) {
				g_players[attacker].hunterKilled++;
			}
			else if (zombieClass == ZC_SPITTER) {
				g_players[attacker].spitterKilled++;
			}
			else if (zombieClass == ZC_JOCKEY) {
				g_players[attacker].jockeyKilled++;
			}
			else if (zombieClass == ZC_CHARGER) {
				g_players[attacker].chargerKilled++;
			}
			else if (zombieClass == ZC_TANK) {
				g_players[attacker].tankKilled++;
			}
		}
		// 生还者击杀生还者
		if (GetClientTeam(attacker) == TEAM_SURVIVOR && GetClientTeam(victim) == TEAM_SURVIVOR && attacker != victim) {
			g_players[attacker].teammateKilled++;
		}
	}
	// 生还者死亡
	if (IsValidClient(victim) && GetClientTeam(victim) == TEAM_SURVIVOR) {
		g_players[victim].dead++;
	}

	// 统计爆头数
	if (headshot) {
		g_players[attacker].headshot++;
	}

	// 统计近战击杀数
	if (IsMeleeWeapon(weapon)) {
		g_players[attacker].melee++;
	}
}

void Event_WitchDeath(Event event, const char[] name, bool dontBroadcast) {
	// Witch死亡，统计玩家Witch击杀数
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(attacker) && GetClientTeam(attacker) == TEAM_SURVIVOR) {
		g_players[attacker].witchKilled++;
	}
}


// -------------------- [skill_detect] Start --------------------

public void OnTongueCut(int attacker, int victim) {
	// 玩家近战砍断Smoker舌头
	if (IsValidClient(attacker)) {
		g_players[attacker].smokerTongueCut++;
	}
}

public void OnSmokerSelfClear(int attacker, int victim, bool withShove) {
	// 玩家自解Smoker舌头
	if (IsValidClient(attacker)) {
		g_players[attacker].smokerSelfCleared++;
	}
}

public void OnSkeet(int attacker, int victim) {
	// 玩家空爆Hunter
	if (IsValidClient(attacker)) {
		g_players[attacker].hunterSkeeted++;
	}
}

public void OnSkeetGL(int attacker, int victim) {
	// 玩家榴弹空爆Hunter
	if (IsValidClient(attacker)) {
		g_players[attacker].hunterSkeeted++;
	}
}

public void OnSkeetHurt(int attacker, int victim, int damage) {
	// 玩家空爆残血Hunter
	if (IsValidClient(attacker)) {
		g_players[attacker].hunterSkeeted++;
	}
}

public void OnSkeetMelee(int attacker, int victim) {
	// 玩家近战空爆Hunter
	if (IsValidClient(attacker)) {
		g_players[attacker].hunterSkeeted++;
	}
}

public void OnSkeetMeleeHurt(int attacker, int victim, int damage) {
	// 玩家近战空爆残血Hunter
	if (IsValidClient(attacker)) {
		g_players[attacker].hunterSkeeted++;
	}
}

public void OnSkeetSniper(int attacker, int victim) {
	// 玩家狙击空爆Hunter
	if (IsValidClient(attacker)) {
		g_players[attacker].hunterSkeeted++;
	}
}

public void OnSkeetSniperHurt(int attacker, int victim, int damage) {
	// 玩家狙击空爆残血Hunter
	if (IsValidClient(attacker)) {
		g_players[attacker].hunterSkeeted++;
	}
}

public void OnChargerLevel(int attacker, int victim) {
	// 玩家近战砍死冲锋Charger
	if (IsValidClient(attacker)) {
		g_players[attacker].chargerLeveled++;
	}
}

public void OnChargerLevelHurt(int attacker, int victim, int damage) {
	// 玩家近战砍死残血冲锋Charger
	if (IsValidClient(attacker)) {
		g_players[attacker].chargerLeveled++;
	}
}

public void OnWitchCrown(int attacker, int damage) {
	// 玩家秒杀Witch
	if (IsValidClient(attacker)) {
		g_players[attacker].witchCrowned++;
	}
}

public void OnWitchDrawCrown(int attacker, int damage, int chipdamage) {
	// 玩家引秒Witch
	if (IsValidClient(attacker)) {
		g_players[attacker].witchCrowned++;
	}
}

public void OnTankRockSkeeted(int attacker, int victim) {
	// 玩家打碎Tank石头
	if (IsValidClient(attacker)) {
		g_players[attacker].tankRockSkeeted++;
	}
}

public void OnTankRockEaten(int attacker, int victim) {
	// 玩家被Tank石头砸中
	if (IsValidClient(attacker)) {
		g_players[victim].tankRockEaten++;
	}
}

public void OnCarAlarmTriggered(int survivor, int infected) {
	// 玩家触发警报
	if (IsValidClient(survivor)) {
		g_players[survivor].alarmTriggered++;
	}
}

public void OnSpecialClear(int clearer, int pinner, int pinvictim, int zombieClass, float timeA, float timeB, bool withShove) {
	// 玩家解救被控队友
	float clearTime = timeA;
	if (zombieClass == ZC_CHARGER || zombieClass == ZC_SMOKER) { 
		clearTime = timeB;
	}

	if (IsValidClient(clearer) && clearTime > 0.0 && clearTime < 60.0) {
		g_players[clearer].instaClearTime.Push(clearTime);
	}
}

// -------------------- [skill_detect] End --------------------


bool IsVersus() {
	char mode[32];
	FindConVar("mp_gamemode").GetString(mode, sizeof(mode));
	return StrContains(mode, "versus", false) > -1;
}

bool IsScavenge() {
	char mode[32];
	FindConVar("mp_gamemode").GetString(mode, sizeof(mode));
	return StrContains(mode, "scavenge", false) > -1;
}

bool IsValidClient(int client) {
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

bool IsRealClient(int client) {
	return IsValidClient(client) && !IsFakeClient(client);
}

bool IsWitch(int entity) {
	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity)) {
		char edictClassName[64];
		GetEdictClassname(entity, edictClassName, sizeof(edictClassName));
		return StrEqual(edictClassName, "witch");
	}
	return false;
}

bool IsPlayerIncapacitated(int client) {
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

bool IsMeleeWeapon(char[] weaponName) {
	return StrEqual(weaponName, "melee", false) || StrEqual(weaponName, "chainsaw", false);
}

void StringToLowerCase(char[] szInput) {
	int iIterator;
	while (szInput[iIterator] != EOS) {
		szInput[iIterator] = CharToLower(szInput[iIterator]);
		++iIterator;
	}
}

void HandleSpecialChar(char[] str, int size) {
	ReplaceString(str, size, "\\", "\\\\");
	ReplaceString(str, size, "/", "\\/");
	ReplaceString(str, size, "\"", "\\\"");
	ReplaceString(str, size, "'", "\\'");
	ReplaceString(str, size, "-", "\\-");
	ReplaceString(str, size, "#", "\\#");
	ReplaceString(str, size, ";", "\\;");
	ReplaceString(str, size, "`", "\\`");
}

void SaveAllPlayerInfoAndDetail(bool isAddMissionCount, bool isWin) {
	int currentTime = RoundToNearest(GetEngineTime());
	for (int i = 1; i <= MaxClients; i++) {
		g_players[i].gametime = currentTime - g_players[i].gametime;
		g_players[i].siDamagePercent = allSiDamage == 0 ? (g_players[i].siDamageValue > 0 ? 1.0 : 0.0) : float(g_players[i].siDamageValue) / float(allSiDamage);
		g_players[i].totalFFPercent = allFF == 0 ? (g_players[i].totalFF > 0 ? 1.0 : 0.0) : float(g_players[i].totalFF) / float(allFF);
		if (isAddMissionCount) {
			if (isWin) g_players[i].missionCompleted++;
			else g_players[i].missionLost++;
		}

		float allInstaClearTime = 0.0;
		for (int j = 0; j < g_players[i].instaClearTime.Length; j++) {
			char eachClearTime[8];
			FormatEx(eachClearTime, sizeof(eachClearTime), "%.2f", g_players[i].instaClearTime.Get(j));
			// LogMessage("Client: %d:%N, Insta-Clear Time Array Content[%d]: %s", i, i, j, eachClearTime);
			allInstaClearTime += StringToFloat(eachClearTime);
		}
		g_players[i].avgInstaClearTime = g_players[i].instaClearTime.Length > 0 ? allInstaClearTime / g_players[i].instaClearTime.Length : 0.0;

		// 更新此玩家总体数据
		SQL_UpdatePlayerInfo(i);
		// 新增此玩家本局详情
		SQL_InsertPlayerRoundDetail(i);
	}
}

void SQL_InsertOrUpdateServer() {
	char query[2048];
	FormatEx(query, sizeof(query), "select 1 from t_server where server_ip = '%s' and server_port = '%s'", g_serverIP, g_serverPort);
	LogMessage(query);
	g_db.Query(ServerQueryCallback, query);
}

void SQL_InsertChatLog(int client, char[] team, char[] msg) {
	if (StrEqual(g_players[client].steamId, "") || StrEqual(g_players[client].steamId, "BOT")) {
		return;
	}

	char insert[2048];
	FormatEx(insert, sizeof(insert), "insert into t_player_chat_log (server_id, steam_id, server_map, server_mode, map_round, player_team, content) values ((select id from t_server where server_ip = '%s' and server_port = '%s'), '%s', '%s', '%s', %d, '%s', '%s')", g_serverIP, g_serverPort, g_players[client].steamId, g_serverMap, g_serverMode, g_mapRound, team, msg);
	LogMessage(insert);
	g_db.Query(DatabaseInsertCallback, insert, client);
}

void SQL_InsertConnectLog(int client) {
	if (StrEqual(g_players[client].steamId, "") || StrEqual(g_players[client].steamId, "BOT")) {
		return;
	}

	char query[2048];
	FormatEx(query, sizeof(query), "select 1 from t_player where steam_id = '%s'", g_players[client].steamId);
	LogMessage(query);
	g_db.Query(PlayerJoinQueryCallback, query, client);

	if (!StrEqual(g_playersInGame[client], g_players[client].steamId)) {
		g_playersInGame[client] = g_players[client].steamId;

		char insert[2048];
		FormatEx(insert, sizeof(insert), "insert into t_player_connect_log (server_id, steam_id, connect_ip, ip_country, ip_region, ip_city, latitude, longitude) values ((select id from t_server where server_ip = '%s' and server_port = '%s'), '%s', '%s', '%s', '%s', '%s', %.6f, %.6f)", g_serverIP, g_serverPort, g_players[client].steamId, g_players[client].ip, g_players[client].country, g_players[client].region, g_players[client].city, g_players[client].latitude, g_players[client].longitude);
		LogMessage(insert);
		g_db.Query(DatabaseInsertCallback, insert, client);
	}
}

void SQL_UpdatePlayerInfo(int client) {
	if (StrEqual(g_players[client].steamId, "") || StrEqual(g_players[client].steamId, "BOT")) {
		return;
	}

	if (!isSkillDetectLoaded) {
		PrintToServer("[l4d2_player_stats_db] Warning: 'Skill Detect' is not loaded, some of the player skill data will not be recorded and saved to DB!");
		LogMessage("[l4d2_player_stats_db] Warning: 'Skill Detect' is not loaded, some of the player skill data will not be recorded and saved to DB!");
	}

	char update[2048];
	FormatEx(update, sizeof(update), 
		"update t_player set "
	...	"gametime = gametime + %d, "
	...	"headshot = headshot + %d, "
	...	"melee = melee + %d, "
	...	"ci_killed = ci_killed + %d, "
	...	"smoker_killed = smoker_killed + %d, "
	...	"boomer_killed = boomer_killed + %d, "
	...	"hunter_killed = hunter_killed + %d, "
	...	"spitter_killed = spitter_killed + %d, "
	...	"jockey_killed = jockey_killed + %d, "
	...	"charger_killed = charger_killed + %d, "
	...	"witch_killed = witch_killed + %d, "
	...	"tank_killed = tank_killed + %d, "
	...	"total_ff = total_ff + %d, "
	...	"total_ff_received = total_ff_received + %d, "
	...	"teammate_protected = teammate_protected + %d, "
	...	"teammate_revived = teammate_revived + %d, "
	...	"teammate_incapped = teammate_incapped + %d, "
	...	"teammate_killed = teammate_killed + %d, "
	...	"ledge_hanged = ledge_hanged + %d, "
	...	"incapped = incapped + %d, "
	...	"dead = dead + %d, "
	...	"mission_completed = mission_completed + %d, "
	...	"mission_lost = mission_lost + %d, "
	...	"smoker_tongue_cut = smoker_tongue_cut + %d, "
	...	"smoker_self_cleared = smoker_self_cleared + %d, "
	...	"hunter_skeeted = hunter_skeeted + %d, "
	...	"charger_leveled = charger_leveled + %d, "
	...	"witch_crowned = witch_crowned + %d, "
	...	"tank_rock_skeeted = tank_rock_skeeted + %d, "
	...	"tank_rock_eaten = tank_rock_eaten + %d, "
	...	"alarm_triggered = alarm_triggered + %d "
	...	"where steam_id = '%s'", 
		g_players[client].gametime, 
		g_players[client].headshot, 
		g_players[client].melee, 
		g_players[client].ciKilled, 
		g_players[client].smokerKilled, 
		g_players[client].boomerKilled, 
		g_players[client].hunterKilled, 
		g_players[client].spitterKilled, 
		g_players[client].jockeyKilled, 
		g_players[client].chargerKilled, 
		g_players[client].witchKilled, 
		g_players[client].tankKilled, 
		g_players[client].totalFF, 
		g_players[client].totalFFReceived, 
		g_players[client].teammateProtected, 
		g_players[client].teammateRevived, 
		g_players[client].teammateIncapped, 
		g_players[client].teammateKilled, 
		g_players[client].ledgeHanged, 
		g_players[client].incapped, 
		g_players[client].dead, 
		g_players[client].missionCompleted, 
		g_players[client].missionLost, 
		g_players[client].smokerTongueCut, 
		g_players[client].smokerSelfCleared, 
		g_players[client].hunterSkeeted, 
		g_players[client].chargerLeveled, 
		g_players[client].witchCrowned, 
		g_players[client].tankRockSkeeted, 
		g_players[client].tankRockEaten, 
		g_players[client].alarmTriggered, 
		g_players[client].steamId
	);
	LogMessage(update);
	g_db.Query(DatabaseUpdateCallback, update);
}

void SQL_InsertPlayerRoundDetail(int client) {
	if (StrEqual(g_players[client].steamId, "") || StrEqual(g_players[client].steamId, "BOT")) {
		return;
	}

	if (!isSkillDetectLoaded) {
		PrintToServer("[l4d2_player_stats_db] Warning: 'Skill Detect' is not loaded, some of the player skill data will not be recorded and saved to DB!");
		LogMessage("[l4d2_player_stats_db] Warning: 'Skill Detect' is not loaded, some of the player skill data will not be recorded and saved to DB!");
	}

	char insert[2048];
	FormatEx(insert, sizeof(insert), 
		"insert into t_player_round_detail ("
	...	"server_id, "
	...	"steam_id, "
	...	"server_map, "
	...	"server_mode, "
	...	"map_round, "
	...	"gametime, "
	...	"headshot, "
	...	"melee, "
	...	"ci_killed, "
	...	"smoker_killed, "
	...	"boomer_killed, "
	...	"hunter_killed, "
	...	"spitter_killed, "
	...	"jockey_killed, "
	...	"charger_killed, "
	...	"witch_killed, "
	...	"tank_killed, "
	...	"si_damage_value, "
	...	"si_damage_percent, "
	...	"total_ff, "
	...	"total_ff_received, "
	...	"total_ff_percent, "
	...	"adrenaline_used, "
	...	"pills_used, "
	...	"medkit_used, "
	...	"teammate_protected, "
	...	"teammate_revived, "
	...	"teammate_incapped, "
	...	"teammate_killed, "
	...	"ledge_hanged, "
	...	"incapped, "
	...	"dead, "
	...	"smoker_tongue_cut, "
	...	"smoker_self_cleared, "
	...	"hunter_skeeted, "
	...	"charger_leveled, "
	...	"witch_crowned, "
	...	"tank_rock_skeeted, "
	...	"tank_rock_eaten, "
	...	"alarm_triggered, "
	...	"avg_insta_clear_time) "
	...	"values ((select id from t_server where server_ip = '%s' and server_port = '%s'), '%s', '%s', '%s', %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %.2f, %d, %d, %.2f, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %.2f)", 
		g_serverIP, 
		g_serverPort, 
		g_players[client].steamId, 
		g_serverMap, 
		g_serverMode, 
		g_mapRound, 
		g_players[client].gametime, 
		g_players[client].headshot, 
		g_players[client].melee, 
		g_players[client].ciKilled, 
		g_players[client].smokerKilled, 
		g_players[client].boomerKilled, 
		g_players[client].hunterKilled, 
		g_players[client].spitterKilled, 
		g_players[client].jockeyKilled, 
		g_players[client].chargerKilled, 
		g_players[client].witchKilled, 
		g_players[client].tankKilled, 
		g_players[client].siDamageValue, 
		g_players[client].siDamagePercent, 
		g_players[client].totalFF, 
		g_players[client].totalFFReceived, 
		g_players[client].totalFFPercent, 
		g_players[client].adrenalineUsed, 
		g_players[client].pillsUsed, 
		g_players[client].medkitUsed, 
		g_players[client].teammateProtected, 
		g_players[client].teammateRevived, 
		g_players[client].teammateIncapped, 
		g_players[client].teammateKilled, 
		g_players[client].ledgeHanged, 
		g_players[client].incapped, 
		g_players[client].dead, 
		g_players[client].smokerTongueCut, 
		g_players[client].smokerSelfCleared, 
		g_players[client].hunterSkeeted, 
		g_players[client].chargerLeveled, 
		g_players[client].witchCrowned, 
		g_players[client].tankRockSkeeted, 
		g_players[client].tankRockEaten, 
		g_players[client].alarmTriggered, 
		g_players[client].avgInstaClearTime
	);
	LogMessage(insert);
	g_db.Query(DatabaseInsertCallback, insert);
}

void ConnectCallback(Database db, const char[] error, any data) {
	if (db == INVALID_HANDLE) {
		LogError("Database connect failure: %s.", error);
		return;
	}

	g_db = db;
	g_db.SetCharset("utf8mb4");

	// 新增或更新服务器信息
	SQL_InsertOrUpdateServer();
}

void ServerQueryCallback(Database db, DBResultSet results, const char[] error, any data) {
	if (results.RowCount == 0) {
		char insert[2048];
		FormatEx(insert, sizeof(insert), "insert into t_server (server_name, server_ip, server_port) values ('%s', '%s', '%s')", g_serverName, g_serverIP, g_serverPort);
		LogMessage(insert);
		g_db.Query(DatabaseInsertCallback, insert);
	}
	else {
		char update[2048];
		FormatEx(update, sizeof(update), "update t_server set server_name = '%s' where server_ip = '%s' and server_port = '%s'", g_serverName, g_serverIP, g_serverPort);
		LogMessage(update);
		g_db.Query(DatabaseUpdateCallback, update);
	}
}

void PlayerJoinQueryCallback(Database db, DBResultSet results, const char[] error, any client) {
	if (results.RowCount == 0) {
		char insert[2048];
		FormatEx(insert, sizeof(insert), "insert into t_player (steam_id, nickname) values ('%s', '%s')", g_players[client].steamId, g_players[client].nickname);
		LogMessage(insert);
		g_db.Query(DatabaseInsertCallback, insert);
	}
	else {
		char update[2048];
		FormatEx(update, sizeof(update), "update t_player set nickname = '%s' where steam_id = '%s'", g_players[client].nickname, g_players[client].steamId);
		LogMessage(update);
		g_db.Query(DatabaseUpdateCallback, update);
	}
}

void DatabaseInsertCallback(Database db, DBResultSet results, const char[] error, any data) {
	if (!StrEqual(error, "")) {
		LogError("Insert error. %s", error);
	}
}

void DatabaseUpdateCallback(Database db, DBResultSet results, const char[] error, any data) {
	if (!StrEqual(error, "")) {
		LogError("Update error. %s", error);
	}
}

void InitCachedPlayerInfo(int client) {
	char ip[16];
	char country[32];
	char region[32];
	char city[32];
	char steamId[32];
	char nickname[32];
	GetClientIP(client, ip, sizeof(ip));
	GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
	GetClientName(client, nickname, sizeof(nickname));
	if (!GeoipCountry(ip, country, sizeof(country))) {
		Format(country, sizeof(country), "<N/A>");
	}
	if (!GeoipRegion(ip, region, sizeof(region))) {
		Format(region, sizeof(region), "<N/A>");
	}
	if (!GeoipCity(ip, city, sizeof(city))) {
		Format(city, sizeof(city), "<N/A>");
	}
	HandleSpecialChar(nickname, sizeof(nickname));
	HandleSpecialChar(country, sizeof(country));
	HandleSpecialChar(region, sizeof(region));
	HandleSpecialChar(city, sizeof(city));

	g_players[client].ip = ip;
	g_players[client].country = country;
	g_players[client].region = region;
	g_players[client].city = city;
	g_players[client].latitude = GeoipLatitude(ip);
	g_players[client].longitude = GeoipLongitude(ip);
	g_players[client].steamId = steamId;
	g_players[client].nickname = nickname;

	ResetCachedPlayerInfo(client);
}

void ClearCachedPlayerInfo(int client) {
	ResetCachedPlayerInfo(client);
	g_players[client].ip = "";
	g_players[client].country = "";
	g_players[client].region = "";
	g_players[client].city = "";
	g_players[client].latitude = 0.0;
	g_players[client].longitude = 0.0;
	g_players[client].steamId = "";
	g_players[client].nickname = "";
	g_players[client].gametime = 0;
}

void ResetCachedPlayerInfo(int client) {
	g_players[client].gametime = RoundToNearest(GetEngineTime());
	g_players[client].headshot = 0;
	g_players[client].melee = 0;
	g_players[client].ciKilled = 0;
	g_players[client].smokerKilled = 0;
	g_players[client].boomerKilled = 0;
	g_players[client].hunterKilled = 0;
	g_players[client].spitterKilled = 0;
	g_players[client].jockeyKilled = 0;
	g_players[client].chargerKilled = 0;
	g_players[client].witchKilled = 0;
	g_players[client].tankKilled = 0;
	g_players[client].siDamageValue = 0;
	g_players[client].siDamagePercent = 0.0;
	g_players[client].totalFF = 0;
	g_players[client].totalFFReceived = 0;
	g_players[client].totalFFPercent = 0.0;
	g_players[client].adrenalineUsed = 0;
	g_players[client].pillsUsed = 0;
	g_players[client].medkitUsed = 0;
	g_players[client].teammateProtected = 0;
	g_players[client].teammateRevived = 0;
	g_players[client].teammateIncapped = 0;
	g_players[client].teammateKilled = 0;
	g_players[client].ledgeHanged = 0;
	g_players[client].incapped = 0;
	g_players[client].dead = 0;
	g_players[client].missionCompleted = 0;
	g_players[client].missionLost = 0;
	g_players[client].smokerTongueCut = 0;
	g_players[client].smokerSelfCleared = 0;
	g_players[client].hunterSkeeted = 0;
	g_players[client].chargerLeveled = 0;
	g_players[client].witchCrowned = 0;
	g_players[client].tankRockSkeeted = 0;
	g_players[client].tankRockEaten = 0;
	g_players[client].alarmTriggered = 0;
	g_players[client].avgInstaClearTime = 0.0;
	g_players[client].instaClearTime.Clear();
}
