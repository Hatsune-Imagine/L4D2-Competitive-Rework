#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>

#define DMG_CUSTOM_PIPEBOMB             134217792
#define DMG_CUSTOM_PROPANE              16777280
#define DMG_CUSTOM_OXYGEN               33554432
#define DMG_CUSTOM_GRENADE_LAUNCHER     1107296256

#define VERSION "1.0"

public Plugin myinfo = 
{
	name = "L4D2 No Medkits",
	author = "HatsuneImagine",
	description = "Disable Medkits spawn.",
	version = VERSION,
	url = "https://github.com/Hatsune-Imagine/l4d2-plugins"
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "weapon_spawn") == 0)
		SDKHook(entity, SDKHook_Spawn, OnWeaponSpawn);
	if (strcmp(classname, "weapon_first_aid_kit_spawn") == 0)
		SDKHook(entity, SDKHook_Spawn, Remove_Medical);
}

Action Remove_Medical(int entity)
{
	RemoveEntity(entity);
	return Plugin_Continue;
}

Action OnWeaponSpawn(int entity)
{
	RequestFrame(RemoveKitByRef, EntIndexToEntRef(entity));
	return Plugin_Continue;
}

void RemoveKitByRef(int ref)
{
	int entity = EntRefToEntIndex(ref);
	if (entity != -1 && GetEntProp(entity, Prop_Data, "m_weaponID") == 12)
		RemoveEntity(entity);
}
