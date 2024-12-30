#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>				// https://github.com/SilvDev/Left4DHooks
#include <l4d2_nativevote>			// https://github.com/fdxx/l4d2_nativevote
#include <l4d2_source_keyvalues>	// https://github.com/fdxx/l4d2_source_keyvalues
#include <multicolors>

#define VERSION "1.0"
#define CUSTOM_FLAG_LIST_MAX_SIZE 32
#define CUSTOM_FLAG_MAX_LENGTH 32
#define COMMAND_MAX_LENGTH 511

#define CUSTOMFLAGS_DEFAULT ""

#define INVALID_FLAGS       0

#define MODEFLAGS_COOP      1
#define MODEFLAGS_REALISM   2
#define MODEFLAGS_VERSUS    4
#define MODEFLAGS_SURVIVAL  8
#define MODEFLAGS_SCAVENGE  16
#define MODEFLAGS_DEFAULT   (MODEFLAGS_COOP | MODEFLAGS_REALISM | MODEFLAGS_VERSUS | MODEFLAGS_SURVIVAL | MODEFLAGS_SCAVENGE)

#define TEAMFLAGS_SPEC      2
#define TEAMFLAGS_SUR       4
#define TEAMFLAGS_INF       8
#define TEAMFLAGS_DEFAULT   (TEAMFLAGS_SPEC | TEAMFLAGS_SUR | TEAMFLAGS_INF)

enum SelectType
{
	SelectType_NotFound = 0,
	SelectType_Single,
	SelectType_Multiple,
	SelectType_CvarTracking,
	SelectType_PluginTracking,
}

enum ConfigType
{
	ConfigType_NotFound = 0,
	ConfigType_ServerCommand,
	ConfigType_ClientCommand,
	ConfigType_ExternalVote,
	ConfigType_CheatCommand,
}

enum struct ConfigData
{
	ConfigType type;
	int menuCustomFlags;
	int menuModeFlags;
	int menuTeamFlags;
	int voteTeamFlags;
	bool bAdminOneVotePassed;
	bool bAdminOneVoteAgainst;
	char description[128];
	char cmd[COMMAND_MAX_LENGTH];
}

SourceKeyValues
	g_kvSelect[MAXPLAYERS + 1],
	g_kvSelectLastVotedSub,
	g_kvRoot;

ConVar g_cvVoteFilePath, g_cvMenuCustomFlags, g_cvAdminTeamFlags, g_cvPrintMsg, g_cvPassMode, g_cvIconSelected, g_cvIconUnselected;
ConfigData g_cfgData[MAXPLAYERS + 1];
char g_iconSelected[8], g_iconUnselected[8];

public Plugin myinfo = 
{
	name = "L4D2 Config Vote",
	author = "fdxx, HatsuneImagine",
	version = VERSION,
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("l4d2_config_vote");
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d2_config_vote_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvVoteFilePath = CreateConVar("l4d2_config_vote_path", "data/l4d2_config_vote.kv", "Vote config file path.");
	g_cvMenuCustomFlags = CreateConVar("l4d2_config_vote_menucustomflags", "", "Menu custom flags (',' separated).");
	g_cvAdminTeamFlags = CreateConVar("l4d2_config_vote_adminteamflags", "1", "Admin bypass TeamFlags.");
	g_cvPrintMsg = CreateConVar("l4d2_config_vote_printmsg", "0", "Whether print hint message to clients.");
	g_cvPassMode = CreateConVar("l4d2_config_vote_passmode", "0", "Method of judging vote pass. 0=Vote Yes count > Vote No count. 1=Vote Yes count > Half of players count.");
	g_cvIconSelected = CreateConVar("l4d2_config_vote_icon_selected", "[√]", "Selected Icon.");
	g_cvIconUnselected = CreateConVar("l4d2_config_vote_icon_unselected", "[  ]", "Unselected Icon.");
	g_cvVoteFilePath.AddChangeHook(OnCvarChanged);
	// AutoExecConfig(true, "l4d2_config_vote");
}

void OnCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	Init();
}

public void OnConfigsExecuted()
{
	static bool shit;
	if (shit) return;
	shit = true;

	Init();
	RegAdminCmdEx("sm_votecfg_reload", Cmd_Reload, ADMFLAG_ROOT, "Reload config file.");
	RegConsoleCmdEx("sm_v", Cmd_Vote);
	RegConsoleCmdEx("sm_vt", Cmd_Vote);
	RegConsoleCmdEx("sm_votes", Cmd_Vote);
}

Action Cmd_Reload(int client, int args)
{
	Init();
	return Plugin_Handled;
}

Action Cmd_Vote(int client, int args)
{
	ShowMenu(client, g_kvRoot, false);
	return Plugin_Handled;
}

void ShowMenu(int client, SourceKeyValues kv, bool bBackButton = true)
{
	if (client < 1 || !IsClientInGame(client) || IsFakeClient(client))
		return;

	if (!kv)
		ThrowError("Invalid SourceKeyValues pointer!");

	g_kvSelect[client] = kv;

	char title[128], display[128], sKv[16];
	kv.GetName(title, sizeof(title));

	Menu menu = new Menu(MenuHandlerCB);
	menu.SetTitle("%s:", title);

	for (SourceKeyValues sub = kv.GetFirstTrueSubKey(); sub; sub = sub.GetNextTrueSubKey())
	{
		char customFlag[128];
		sub.GetString("MenuCustomFlags", customFlag, sizeof(customFlag), CUSTOMFLAGS_DEFAULT);
		if (!IsValidCustomFlags(customFlag))
			continue;

		if (!IsValidModeFlags(sub.GetInt("MenuModeFlags", MODEFLAGS_DEFAULT)))
			continue;

		if (!IsValidTeamFlags(client, sub.GetInt("MenuTeamFlags", TEAMFLAGS_DEFAULT)))
			continue;

		sub.GetName(display, sizeof(display));
		SelectType selectType = GetSelectType(kv);
		switch (selectType)
		{
			case SelectType_Single, SelectType_Multiple:
			{
				Format(display, sizeof(display), "%s %s", display, sub.GetInt("Selected", 0) > 0 ? g_iconSelected : g_iconUnselected);
			}
			case SelectType_CvarTracking:
			{
				char cvarName[64], cvarType[8];
				kv.GetString("CvarName", cvarName, sizeof(cvarName));
				kv.GetString("CvarType", cvarType, sizeof(cvarType));
				ConVar cv = FindConVar(cvarName);
				if (cv != null)
				{
					if (!strcmp(cvarType, "int", false))
					{
						int cvarValue = cv.IntValue;
						int cvarMatch = sub.GetInt("CvarMatch", -1);
						Format(display, sizeof(display), "%s %s", display, cvarValue == cvarMatch ? g_iconSelected : g_iconUnselected);
					}
					else if (!strcmp(cvarType, "float", false))
					{
						float cvarValue = cv.FloatValue;
						float cvarMatch = sub.GetFloat("CvarMatch", -1.0);
						Format(display, sizeof(display), "%s %s", display, cvarValue == cvarMatch ? g_iconSelected : g_iconUnselected);
					}
					else if (!strcmp(cvarType, "string", false))
					{
						char cvarValue[32], cvarMatch[32];
						cv.GetString(cvarValue, sizeof(cvarValue));
						sub.GetString("CvarMatch", cvarMatch, sizeof(cvarMatch));
						Format(display, sizeof(display), "%s %s", display, !strcmp(cvarValue, cvarMatch, false) ? g_iconSelected : g_iconUnselected);
					}
				}
				delete cv;
			}
			case SelectType_PluginTracking:
			{
				char pluginMatch[64];
				sub.GetString("PluginMatch", pluginMatch, sizeof(pluginMatch));
				Handle pg = FindPluginByFile(pluginMatch);
				Format(display, sizeof(display), "%s %s", display, pg != INVALID_HANDLE ? g_iconSelected : g_iconUnselected);
				delete pg;
			}
			default:
			{
				// do nothing
			}
		}

		IntToString(view_as<int>(sub), sKv, sizeof(sKv));
		menu.AddItem(sKv, display);
	}

	menu.ExitBackButton = bBackButton;
	menu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandlerCB(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sKv[16];
			menu.GetItem(itemNum, sKv, sizeof(sKv));

			SourceKeyValues kv = view_as<SourceKeyValues>(StringToInt(sKv));
			ConfigType configType = GetConfigType(kv);

			switch (configType)
			{
				case ConfigType_NotFound:
				{
					ShowMenu(client, kv);
				}
				case ConfigType_ExternalVote:
				{
					char cmd[COMMAND_MAX_LENGTH];
					kv.GetString("Command", cmd, sizeof(cmd));
					ClientCommand(client, "%s", cmd);
				}
				default:
				{
					StartVote(client, kv, configType);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
			{
				SourceKeyValues kv = GetPreviousNode(g_kvRoot, g_kvSelect[client]);
				ShowMenu(client, kv, kv != g_kvRoot);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void StartVote(int client, SourceKeyValues kv, ConfigType type)
{
	if (!L4D2NativeVote_IsAllowNewVote())
	{
		CPrintToChat(client, "{lightgreen}投票正在进行中, 暂不能发起新的投票.");
		return;
	}

	g_kvSelectLastVotedSub = kv;

	g_cfgData[client].type = type;
	g_cfgData[client].voteTeamFlags = kv.GetInt("VoteTeamFlags", TEAMFLAGS_DEFAULT);
	g_cfgData[client].bAdminOneVotePassed = kv.GetInt("AdminOneVotePassed", 1) > 0;
	g_cfgData[client].bAdminOneVoteAgainst = kv.GetInt("AdminOneVoteAgainst", 1) > 0;
	kv.GetString("Description", g_cfgData[client].description, sizeof(g_cfgData[].description));
	kv.GetString("Command", g_cfgData[client].cmd, sizeof(g_cfgData[].cmd));

	L4D2NativeVote vote = L4D2NativeVote(Vote_Handler);
	vote.SetDisplayText("%s", g_cfgData[client].description);
	vote.Initiator = client;

	int iPlayerCount = 0;
	int[] iClients = new int[MaxClients];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (!IsValidTeamFlags(i, g_cfgData[client].voteTeamFlags))
				continue;

			iClients[iPlayerCount++] = i;
		}
	}

	if (!vote.DisplayVote(iClients, iPlayerCount, 20))
		LogMessage("发起投票失败");
}

void Vote_Handler(L4D2NativeVote vote, VoteAction action, int param1, int param2)
{
	switch (action)
	{
		case VoteAction_Start:
		{
			if (g_cvPrintMsg.BoolValue)
				CPrintToChatAll("{blue}[Vote] {olive}%N {default}发起了一个投票.", param1);
		}
		case VoteAction_PlayerVoted:
		{
			if (g_cvPrintMsg.BoolValue)
				CPrintToChatAll("{olive}%N {default}已投票", param1);

			if (!CheckCommandAccess(param1, "sm_admin", ADMFLAG_ROOT))
				return;
			
			if (param2 == VOTE_YES && g_cfgData[vote.Initiator].bAdminOneVotePassed)
			{
				vote.YesCount = vote.PlayerCount;
				vote.NoCount = 0;
			}
			else if (param2 == VOTE_NO && g_cfgData[vote.Initiator].bAdminOneVoteAgainst)
			{
				vote.YesCount = 0;
				vote.NoCount = vote.PlayerCount;
			}
		}
		case VoteAction_End:
		{
			bool voteResult = (g_cvPassMode.BoolValue) ? (vote.YesCount > vote.PlayerCount / 2) : (vote.YesCount > vote.NoCount);
			if (voteResult)
			{
				vote.SetPass("加载中...");

				switch (g_cfgData[vote.Initiator].type)
				{
					case ConfigType_ServerCommand:
					{
						ServerCommand("%s", g_cfgData[vote.Initiator].cmd);
					}
					case ConfigType_ClientCommand:
					{
						if (IsClientInGame(vote.Initiator))
							ClientCommand(vote.Initiator, "%s", g_cfgData[vote.Initiator].cmd);
					}
					case ConfigType_CheatCommand:
					{
						if (!IsClientInGame(vote.Initiator))
							return;

						char cmd[COMMAND_MAX_LENGTH], cmdArgs[COMMAND_MAX_LENGTH];

						int index = SplitString(g_cfgData[vote.Initiator].cmd, " ", cmd, sizeof(cmd));
						if (index != -1)
							strcopy(cmdArgs, sizeof(cmdArgs), g_cfgData[vote.Initiator].cmd[index]);
						else
							strcopy(cmd, sizeof(cmd), g_cfgData[vote.Initiator].cmd);

						int iFlags = GetCommandFlags(cmd);
						SetCommandFlags(cmd, iFlags & ~FCVAR_CHEAT);
						FakeClientCommand(vote.Initiator, "%s %s", cmd, cmdArgs);
						SetCommandFlags(cmd, iFlags);
					}
				}

				SourceKeyValues kv = g_kvSelectLastVotedSub;
				SourceKeyValues parentKv = GetPreviousNode(g_kvRoot, g_kvSelectLastVotedSub);
				SelectType selectType = GetSelectType(parentKv);
				switch (selectType)
				{
					case SelectType_Single:
					{
						// set this node's <Selected> to 1, and set other same level nodes' <Selected> to 0
						for (SourceKeyValues sub = parentKv.GetFirstTrueSubKey(); sub; sub = sub.GetNextTrueSubKey())
							sub.SetInt("Selected", sub == kv ? 1 : 0);
					}
					case SelectType_Multiple:
					{
						// set this node's <Selected> to it's opposite
						kv.SetInt("Selected", (kv.GetInt("Selected", 0) + 1) % 2);
					}
					case SelectType_CvarTracking, SelectType_PluginTracking:
					{
						// do nothing
					}
					default:
					{
						// do nothing
					}
				}
			}
			else
				vote.SetFail();
		}
	}
}

bool StrListContains(char[][] list, int listSize, char[] element)
{
	for (int i = 0; i < listSize; i++)
		if (strlen(list[i]) > 0 && strlen(element) > 0 && strcmp(list[i], element, false) == 0)
			return true;

	return false;
}

bool IsValidCustomFlags(char[] flags)
{
	TrimString(flags);
	if (strlen(flags) == 0)
		return true;

	char menuCustomFlagsList[CUSTOM_FLAG_LIST_MAX_SIZE][CUSTOM_FLAG_MAX_LENGTH];
	ExplodeString(flags, ",", menuCustomFlagsList, CUSTOM_FLAG_LIST_MAX_SIZE, CUSTOM_FLAG_MAX_LENGTH);

	char cvarCustomFlagsList[CUSTOM_FLAG_LIST_MAX_SIZE][CUSTOM_FLAG_MAX_LENGTH];
	char cvarCustomFlagsCommaSeparated[128];
	g_cvMenuCustomFlags.GetString(cvarCustomFlagsCommaSeparated, sizeof(cvarCustomFlagsCommaSeparated));
	TrimString(cvarCustomFlagsCommaSeparated);
	ExplodeString(cvarCustomFlagsCommaSeparated, ",", cvarCustomFlagsList, CUSTOM_FLAG_LIST_MAX_SIZE, CUSTOM_FLAG_MAX_LENGTH);

	bool isValid = false;
	for (int i = 0; i < CUSTOM_FLAG_LIST_MAX_SIZE; i++)
		isValid |= StrListContains(menuCustomFlagsList, CUSTOM_FLAG_LIST_MAX_SIZE, cvarCustomFlagsList[i]);

	return isValid;
}

bool IsValidModeFlags(int flags)
{
	if (L4D_IsCoopMode() && (flags & MODEFLAGS_COOP))
		return true;

	if (L4D2_IsRealismMode() && (flags & MODEFLAGS_REALISM))
		return true;

	if (L4D_IsVersusMode() && (flags & MODEFLAGS_VERSUS))
		return true;

	if (L4D_IsSurvivalMode() && (flags & MODEFLAGS_SURVIVAL))
		return true;

	if (L4D2_IsScavengeMode() && (flags & MODEFLAGS_SCAVENGE))
		return true;

	return false;
}

bool IsValidTeamFlags(int client, int flags)
{
	if (g_cvAdminTeamFlags.BoolValue && CheckCommandAccess(client, "sm_admin", ADMFLAG_ROOT))
		return true;

	int team = GetClientTeam(client);
	return (flags & (1 << team)) != 0;
}

SourceKeyValues GetPreviousNode(SourceKeyValues kvRoot, SourceKeyValues kvTarget)
{
	for (SourceKeyValues sub = kvRoot.GetFirstTrueSubKey(); sub; sub = sub.GetNextTrueSubKey())
	{
		if (sub == kvTarget)
			return kvRoot;

		if (sub.GetFirstTrueSubKey())
		{
			SourceKeyValues result = GetPreviousNode(sub, kvTarget);
			if (result)
				return result;
		}
	}
	return view_as<SourceKeyValues>(0);
}

SelectType GetSelectType(SourceKeyValues kv)
{
	char type[32];
	kv.GetString("SelectType", type, sizeof(type));

	if (!strcmp(type, "Single", false))
		return SelectType_Single;

	if (!strcmp(type, "Multiple", false))
		return SelectType_Multiple;

	if (!strcmp(type, "CvarTracking", false))
		return SelectType_CvarTracking;

	if (!strcmp(type, "PluginTracking", false))
		return SelectType_PluginTracking;

	return SelectType_NotFound;
}

ConfigType GetConfigType(SourceKeyValues kv)
{
	char type[32];
	kv.GetString("Type", type, sizeof(type));

	if (!strcmp(type, "ServerCommand", false))
		return ConfigType_ServerCommand;

	if (!strcmp(type, "ClientCommand", false))
		return ConfigType_ClientCommand;

	if (!strcmp(type, "ExternalVote", false))
		return ConfigType_ExternalVote;

	if (!strcmp(type, "CheatCommand", false))
		return ConfigType_CheatCommand;

	return ConfigType_NotFound;
}

void RegAdminCmdEx(const char[] cmd, ConCmd callback, int adminflags, const char[] description="", const char[] group="", int flags=0)
{
	if (!CommandExists(cmd))
		RegAdminCmd(cmd, callback, adminflags, description, group, flags);
	else
	{
		char pluginName[PLATFORM_MAX_PATH];
		FindPluginNameByCmd(pluginName, sizeof(pluginName), cmd);
		LogError("The command \"%s\" already exists, plugin: \"%s\"", cmd, pluginName);
	}
}

void RegConsoleCmdEx(const char[] cmd, ConCmd callback, const char[] description="", int flags=0)
{
	if (!CommandExists(cmd))
		RegConsoleCmd(cmd, callback, description, flags);
	else
	{
		char pluginName[PLATFORM_MAX_PATH];
		FindPluginNameByCmd(pluginName, sizeof(pluginName), cmd);
		LogError("The command \"%s\" already exists, plugin: \"%s\"", cmd, pluginName);
	}
}

bool FindPluginNameByCmd(char[] buffer, int maxlength, const char[] cmd)
{
	char cmdBuffer[128];
	bool result = false;
	CommandIterator iter = new CommandIterator();

	while (iter.Next())
	{
		iter.GetName(cmdBuffer, sizeof(cmdBuffer));
		if (strcmp(cmdBuffer, cmd, false))
			continue;

		GetPluginFilename(iter.Plugin, buffer, maxlength);
		result = true;
		break;
	}

	if (!result)
	{
		ConVar cvar = FindConVar(cmd);
		if (cvar)
		{
			GetPluginFilename(cvar.Plugin, buffer, maxlength);
			result = true;
		}
	}

	delete iter;
	return result;
}

void Init()
{
	if (g_kvRoot)
		g_kvRoot.deleteThis();

	char file[PLATFORM_MAX_PATH];
	char voteFilePath[PLATFORM_MAX_PATH];
	g_cvVoteFilePath.GetString(voteFilePath, sizeof(voteFilePath));
	BuildPath(Path_SM, file, sizeof(file), voteFilePath);

	g_kvRoot = SourceKeyValues("");
	g_kvRoot.UsesEscapeSequences(true);
	if (!g_kvRoot.LoadFromFile(file))
		SetFailState("Failed to load %s", file);

	g_cvIconSelected.GetString(g_iconSelected, sizeof(g_iconSelected));
	g_cvIconUnselected.GetString(g_iconUnselected, sizeof(g_iconUnselected));
}

public void OnPluginEnd()
{
	if (g_kvRoot)
		g_kvRoot.deleteThis();
}
