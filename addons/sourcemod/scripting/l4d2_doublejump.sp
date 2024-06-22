/*
 * Double Jump
 *
 * Description:
 *  Allows players to double-jump
 *  Original idea: NcB_Sav
 *
 * Convars:
 *  sm_doublejump_enabled [bool] : Enables or disable double-jumping. Default: 1
 *  sm_doublejump_boost [amount] : Amount to boost the player. Default: 250
 *  sm_doublejump_max [jumps]    : Maximum number of re-jumps while airborne. Default: 1
 *
 * Changelog:
 *  v1.1.0 - Update by StrikerTheHedgefox
 *   Overhaul. Doesn't use OnGameFrame anymore, and ditches an unnecessary variable.
 *  v1.0.1
 *   Minor code optimization.
 *  v1.0.0
 *   Initial release.
 *
 * Known issues:
 *  Doesn't register all mouse-wheel triggered +jumps
 *
 * Todo:
 *  Employ upcoming OnClientCommand function to remove excess OnGameFrame-age.
 *
 * Contact:
 *  Paegus: paegus@gmail.com
 *  SourceMod: http://www.sourcemod.net
 *  Hidden:Source: http://www.hidden-source.com
 *  NcB_Sav: http://forums.alliedmods.net/showthread.php?t=99228
 */
#define PLUGIN_VERSION		"1.1.0"
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

public Plugin myinfo = {
	name		= "Double Jump",
	author		= "Paegus & StrikerTheHedgefox",
	description	= "Allows double-jumping.",
	version		= PLUGIN_VERSION,
	url			= ""
}

ConVar g_cvJumpEnable, g_doublejump, g_cvJumpBoost, g_cvJumpMax;
	
int g_fLastButtons[MAXPLAYERS+1];
int g_iJumps[MAXPLAYERS+1];

int g_iJumpMax;
int g_bDoubleswitch;
int g_bDoubleJump;
bool l4d2_bDoubleswitch;

bool l4d2_doublejump = false;
	
float g_flBoost;
	
public void OnPluginStart()
{
	CreateConVar("sm_doublejump_version", PLUGIN_VERSION, "多段跳插件的版本", FCVAR_NOTIFY);
	
	RegAdminCmd("sm_jump", Command_doublejump, ADMFLAG_KICK, "管理员开关多段跳.");
	
	g_cvJumpEnable = CreateConVar("l4d2_doublejump_Enabled", "1", "启用多段跳? (指令 !jump 关闭或开启多段跳) 0=禁用, 1=启用.", FCVAR_NOTIFY);
	g_doublejump = CreateConVar("l4d2_doublejump_Switch", "1", "默认开启多段跳? (指令开启或关闭多段跳后这里的值失效) 0=关闭, 1=开启.", FCVAR_NOTIFY);
	g_cvJumpBoost = CreateConVar("l4d2_doublejump_boost", "200.0", "设置额外跳跃时的高度(不包括第一次跳跃).", FCVAR_NOTIFY);
	g_cvJumpMax = CreateConVar("l4d2_doublejump_Max", "1", "设置额外的跳跃次数.", FCVAR_NOTIFY);
	
	AutoExecConfig(true, "l4d2_doublejump");
	
	g_cvJumpEnable.AddChangeHook(ConVarChangedcvJump);
	g_doublejump.AddChangeHook(ConVarChangedcvJump);
	g_cvJumpBoost.AddChangeHook(ConVarChangedcvJump);
	g_cvJumpMax.AddChangeHook(ConVarChangedcvJump);
}

public Action Command_doublejump(int client, int args)
{
	switch(g_bDoubleJump)
	{
		case 0:
		{
			PrintToChat(client, "\x04[提示]\x05多段跳没有启用.");
		}
		case 1:
		{
			if(l4d2_bDoubleswitch)
			{
				l4d2_doublejump = true;
				l4d2_bDoubleswitch = false;
				PrintToChat(client, "\x04[提示]\x03已关闭\x05%d段跳.", g_iJumpMax + 1);
			}
			else
			{
				l4d2_doublejump = true;
				l4d2_bDoubleswitch = true;
				PrintToChat(client, "\x04[提示]\x03已开启\x05%d段跳.", g_iJumpMax + 1);
			}
		}
	}
	return Plugin_Handled;
}

public void ConVarChangedcvJump(ConVar convar, const char[] oldValue, const char[] newValue)
{
	l4d2doublejump();
}

public void OnMapStart()
{
	l4d2doublejump();
}

void l4d2doublejump()
{
	g_bDoubleJump = g_cvJumpEnable.IntValue;
	g_bDoubleswitch = g_doublejump.IntValue;
	g_flBoost = g_cvJumpBoost.FloatValue;
	g_iJumpMax = g_cvJumpMax.IntValue;
}

public void OnConfigsExecuted()
{
	if(!l4d2_doublejump)
	{
		switch(g_bDoubleswitch)
		{
			case 0:
			{
				l4d2_bDoubleswitch = false;
			}
			case 1:
			{
				l4d2_bDoubleswitch = true;
			}
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(g_bDoubleJump == 1)
	{
		if(l4d2_bDoubleswitch)
		{
			int fCurFlags = GetEntityFlags(client);
			
			if(fCurFlags & FL_ONGROUND)
			{
				Landed(client);
			}
			else if(!(g_fLastButtons[client] & IN_JUMP) && (buttons & IN_JUMP) && !(fCurFlags & FL_ONGROUND))
			{
				ReJump(client);
			}
			
			g_fLastButtons[client] = buttons;
		}
	}
	return Plugin_Continue;
}

void Landed(int client)
{
	g_iJumps[client] = 0;
}

void ReJump(int client)
{
	if (g_iJumps[client] < g_iJumpMax)
	{						
		g_iJumps[client]++;
		float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
		
		vVel[2] = g_flBoost;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	}
}

