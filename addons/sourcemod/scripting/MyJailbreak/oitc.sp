/*
 * MyJailbreak - OneInTheChamber Event Day Plugin.
 * by: shanapu
 * https://github.com/shanapu/MyJailbreak/
 * 
 * Copyright (C) 2016-2017 Thomas Schmidt (shanapu)
 *
 * This file is part of the MyJailbreak SourceMod Plugin.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 */

/******************************************************************************
                   STARTUP
******************************************************************************/

// Includes
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <emitsoundany>
#include <colors>
#include <autoexecconfig>
#include <mystocks>

// Optional Plugins
#undef REQUIRE_PLUGIN
#include <hosties>
#include <lastrequest>
#include <warden>
#include <myjailbreak>
#include <myweapons>
#include <smartjaildoors>
#define REQUIRE_PLUGIN

// Compiler Options
#pragma semicolon 1
#pragma newdecls required

// Booleans
bool g_bIsLateLoad = false;
bool g_bIsOITC = false;
bool g_bStartOITC = false;

// Plugin bools
bool gp_bWarden;
bool gp_bHosties;
bool gp_bSmartJailDoors;
bool gp_bMyJailbreak;
bool gp_bMyWeapons;

// Console Variables
ConVar gc_bPlugin;
ConVar gc_bSetW;
ConVar gc_iCooldownStart;
ConVar gc_bSetA;
ConVar gc_bSetABypassCooldown;
ConVar gc_bSpawnCell;
ConVar gc_bVote;
ConVar gc_iCooldownDay;
ConVar gc_iRoundTime;
ConVar gc_iTruceTime;
ConVar gc_bOverlays;
ConVar gc_sOverlayStartPath;
ConVar gc_bSounds;
ConVar gc_iRounds;
ConVar gc_sSoundStartPath;
ConVar gc_fBeaconTime;
ConVar gc_sCustomCommandVote;
ConVar gc_sCustomCommandSet;
ConVar gc_sAdminFlag;
ConVar gc_bAllowLR;

ConVar gc_bBeginSetA;
ConVar gc_bBeginSetW;
ConVar gc_bBeginSetV;
ConVar gc_bBeginSetVW;
ConVar gc_bTeleportSpawn;
ConVar gc_bKnifeOneHit;
// Extern Convars
//ConVar g_iMPRoundTime;
ConVar g_iTerrorForLR;

// Integers
//int g_iOldRoundTime;
int g_iCoolDown;
int g_iTruceTime;
int g_iVoteCount;
int g_iRound;
int g_iMaxRound;
int g_iTsLR;
int g_iCollision_Offset;

// Handles
Handle g_hTimerTruce;
Handle g_hTimerGiveDeagle[MAXPLAYERS+1];
Handle g_hTimerBeacon;

// Strings
char g_sHasVoted[1500];
char g_sSoundStartPath[256];
char g_sEventsLogFile[PLATFORM_MAX_PATH];
char g_sAdminFlag[64];
char g_sOverlayStartPath[256];

// Floats
float g_fPos[3];

// Info
public Plugin myinfo =  {
	name = "MyJailbreak - OneInTheChamber", 
	author = "shanapu | Hexah", 
	description = "Event Day for Jailbreak Server", 
	version = MYJB_VERSION, 
	url = MYJB_URL_LINK
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bIsLateLoad = late;
	
	return APLRes_Success;
}

// Start
public void OnPluginStart()
{
	// Translation
	LoadTranslations("MyJailbreak.Warden.phrases");
	LoadTranslations("MyJailbreak.OITC.phrases");
	
	// Client Commands
	RegConsoleCmd("sm_setoitc", Command_SetOITC, "Allows the Admin or Warden to set OneInTheChamber as next round");
	RegConsoleCmd("sm_oitc", Command_VoteOITC, "Allows players to vote for a OneInTheChamber");
	
	// AutoExecConfig
	AutoExecConfig_SetFile("OITC", "MyJailbreak/EventDays");
	AutoExecConfig_SetCreateFile(true);
	
	AutoExecConfig_CreateConVar("sm_oitc_version", MYJB_VERSION, "The version of this MyJailbreak SourceMod plugin", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	gc_bPlugin = AutoExecConfig_CreateConVar("sm_oitc_enable", "1", "0 - disabled, 1 - enable this MyJailbreak SourceMod plugin", _, true, 0.0, true, 1.0);
	gc_sCustomCommandVote = AutoExecConfig_CreateConVar("sm_oitc_cmds_vote", "oneinthechamber", "Set your custom chat command for Event voting(!oitc (no 'sm_'/'!')(seperate with comma ', ')(max. 12 commands))");
	gc_sCustomCommandSet = AutoExecConfig_CreateConVar("sm_oitc_cmds_set", "soitc, soneinthechamber", "Set your custom chat command for set Event(!setoitc (no 'sm_'/'!')(seperate with comma ', ')(max. 12 commands))");
	gc_bSetW = AutoExecConfig_CreateConVar("sm_oitc_warden", "1", "0 - disabled, 1 - allow warden to set oitc round", _, true, 0.0, true, 1.0);
	gc_bSetA = AutoExecConfig_CreateConVar("sm_oitc_admin", "1", "0 - disabled, 1 - allow admin/vip to set oitc round", _, true, 0.0, true, 1.0);
	gc_sAdminFlag = AutoExecConfig_CreateConVar("sm_oitc_flag", "g", "Set flag for admin/vip to set this Event Day.");
	gc_bVote = AutoExecConfig_CreateConVar("sm_oitc_vote", "1", "0 - disabled, 1 - allow player to vote for oitc", _, true, 0.0, true, 1.0);
	gc_bSpawnCell = AutoExecConfig_CreateConVar("sm_oitc_spawn", "0", "0 - T teleport to CT spawn, 1 - cell doors auto open", _, true, 0.0, true, 1.0);
	gc_bKnifeOneHit = AutoExecConfig_CreateConVar("sm_oitc_knife_onehit", "1", "0 - Knife does normal damage, 1 - Knife one-hit", _, true, 0.0, true, 1.0);
	
	gc_bBeginSetA = AutoExecConfig_CreateConVar("sm_oitc_begin_admin", "1", "When admin set event (!setoitc) = 0 - start event next round, 1 - start event current round", _, true, 0.0, true, 1.0);
	gc_bBeginSetW = AutoExecConfig_CreateConVar("sm_oitc_begin_warden", "1", "When warden set event (!setoitc) = 0 - start event next round, 1 - start event current round", _, true, 0.0, true, 1.0);
	gc_bBeginSetV = AutoExecConfig_CreateConVar("sm_oitc_begin_vote", "0", "When users vote for event (!oitc) = 0 - start event next round, 1 - start event current round", _, true, 0.0, true, 1.0);
	gc_bBeginSetVW = AutoExecConfig_CreateConVar("sm_oitc_begin_daysvote", "0", "When warden/admin start eventday voting (!sm_voteday) and event wins = 0 - start event next round, 1 - start event current round", _, true, 0.0, true, 1.0);
	gc_bTeleportSpawn = AutoExecConfig_CreateConVar("sm_oitc_teleport_spawn", "0", "0 - start event in current round from current player positions, 1 - teleport players to spawn when start event on current round(only when sm_*_begin_admin, sm_*_begin_warden, sm_*_begin_vote or sm_*_begin_daysvote is on '1')", _, true, 0.0, true, 1.0);
	
	gc_iRounds = AutoExecConfig_CreateConVar("sm_oitc_rounds", "3", "Rounds to play in a row", _, true, 1.0);
	gc_iRoundTime = AutoExecConfig_CreateConVar("sm_oitc_roundtime", "5", "Round time in minutes for a single oitc round", _, true, 1.0);
	gc_fBeaconTime = AutoExecConfig_CreateConVar("sm_oitc_beacon_time", "240", "Time in seconds until the beacon turned on (set to 0 to disable)", _, true, 0.0);
	gc_iTruceTime = AutoExecConfig_CreateConVar("sm_oitc_trucetime", "15", "Time in seconds players can't deal damage", _, true, 0.0);
	gc_iCooldownDay = AutoExecConfig_CreateConVar("sm_oitc_cooldown_day", "3", "Rounds cooldown after a event until event can be start again", _, true, 0.0);
	gc_iCooldownStart = AutoExecConfig_CreateConVar("sm_oitc_cooldown_start", "3", "Rounds until event can be start after mapchange.", _, true, 0.0);
	gc_bSetABypassCooldown = AutoExecConfig_CreateConVar("sm_oitc_cooldown_admin", "1", "0 - disabled, 1 - ignore the cooldown when admin/vip set oitc round", _, true, 0.0, true, 1.0);
	gc_bSounds = AutoExecConfig_CreateConVar("sm_oitc_sounds_enable", "1", "0 - disabled, 1 - enable sounds ", _, true, 0.1, true, 1.0);
	gc_sSoundStartPath = AutoExecConfig_CreateConVar("sm_oitc_sounds_start", "music/MyJailbreak/start.mp3", "Path to the soundfile which should be played for a start.");
	gc_bOverlays = AutoExecConfig_CreateConVar("sm_oitc_overlays_enable", "1", "0 - disabled, 1 - enable overlays", _, true, 0.0, true, 1.0);
	gc_sOverlayStartPath = AutoExecConfig_CreateConVar("sm_oitc_overlays_start", "overlays/MyJailbreak/start", "Path to the start Overlay DONT TYPE .vmt or .vft");
	gc_bAllowLR = AutoExecConfig_CreateConVar("sm_oitc_allow_lr", "0", "0 - disabled, 1 - enable LR for last round and end eventday", _, true, 0.0, true, 1.0);
	
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	
	// Hooks
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_end", Event_RoundEnd);
	HookConVarChange(gc_sOverlayStartPath, OnSettingChanged);
	HookConVarChange(gc_sSoundStartPath, OnSettingChanged);
	HookConVarChange(gc_sAdminFlag, OnSettingChanged);
	
	// Find
	g_iCoolDown = gc_iCooldownDay.IntValue + 1;
	g_iTruceTime = gc_iTruceTime.IntValue;
	//	g_iMPRoundTime = FindConVar("mp_roundtime");
	gc_sOverlayStartPath.GetString(g_sOverlayStartPath, sizeof(g_sOverlayStartPath));
	gc_sSoundStartPath.GetString(g_sSoundStartPath, sizeof(g_sSoundStartPath));
	gc_sAdminFlag.GetString(g_sAdminFlag, sizeof(g_sAdminFlag));
	
	// Offsets
	g_iCollision_Offset = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
	
	// Logs
	SetLogFile(g_sEventsLogFile, "Events", "MyJailbreak");
	
	// Late loading
	if (g_bIsLateLoad)
	{
		for (int i = 1; i <= MaxClients; i++)if (IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
		
		g_bIsLateLoad = false;
	}
}

// ConVarChange for Strings
public void OnSettingChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (convar == gc_sOverlayStartPath)
	{
		strcopy(g_sOverlayStartPath, sizeof(g_sOverlayStartPath), newValue);
		if (gc_bOverlays.BoolValue)
		{
			PrecacheDecalAnyDownload(g_sOverlayStartPath);
		}
	}
	else if (convar == gc_sSoundStartPath)
	{
		strcopy(g_sSoundStartPath, sizeof(g_sSoundStartPath), newValue);
		if (gc_bSounds.BoolValue)
		{
			PrecacheSoundAnyDownload(g_sSoundStartPath);
		}
	}
	else if (convar == gc_sAdminFlag)
	{
		strcopy(g_sAdminFlag, sizeof(g_sAdminFlag), newValue);
	}
}

public void OnAllPluginsLoaded()
{
	gp_bWarden = LibraryExists("warden");
	gp_bHosties = LibraryExists("lastrequest");
	gp_bSmartJailDoors = LibraryExists("smartjaildoors");
	gp_bMyJailbreak = LibraryExists("myjailbreak");
	gp_bMyWeapons = LibraryExists("myweapons");
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "warden"))
		gp_bWarden = false;
	
	if (StrEqual(name, "lastrequest"))
		gp_bHosties = false;
	
	if (StrEqual(name, "smartjaildoors"))
		gp_bSmartJailDoors = false;
	
	if (StrEqual(name, "myjailbreak"))
		gp_bMyJailbreak = false;
	
	if (StrEqual(name, "myweapons"))
		gp_bMyWeapons = false;
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "warden"))
		gp_bWarden = true;
	
	if (StrEqual(name, "lastrequest"))
		gp_bHosties = true;
	
	if (StrEqual(name, "smartjaildoors"))
		gp_bSmartJailDoors = true;
	
	if (StrEqual(name, "myjailbreak"))
		gp_bMyJailbreak = true;
	
	if (StrEqual(name, "myweapons"))
		gp_bMyWeapons = true;
}

// Initialize Plugin
public void OnConfigsExecuted()
{
	g_iTruceTime = gc_iTruceTime.IntValue;
	g_iCoolDown = gc_iCooldownStart.IntValue + 1;
	g_iMaxRound = gc_iRounds.IntValue;
	
	// FindConVar
	if (gp_bHosties)
	{
		g_iTerrorForLR = FindConVar("sm_hosties_lr_ts_max");
	}
	
	// Set custom Commands
	int iCount = 0;
	char sCommands[128], sCommandsL[12][32], sCommand[32];
	
	// Vote
	gc_sCustomCommandVote.GetString(sCommands, sizeof(sCommands));
	ReplaceString(sCommands, sizeof(sCommands), " ", "");
	iCount = ExplodeString(sCommands, ",", sCommandsL, sizeof(sCommandsL), sizeof(sCommandsL[]));
	
	for (int i = 0; i < iCount; i++)
	{
		Format(sCommand, sizeof(sCommand), "sm_%s", sCommandsL[i]);
		if (GetCommandFlags(sCommand) == INVALID_FCVAR_FLAGS) // if command not already exist
		{
			RegConsoleCmd(sCommand, Command_VoteOITC, "Allows players to vote for a OnInTheChamber");
		}
	}
	
	// Set
	gc_sCustomCommandSet.GetString(sCommands, sizeof(sCommands));
	ReplaceString(sCommands, sizeof(sCommands), " ", "");
	iCount = ExplodeString(sCommands, ",", sCommandsL, sizeof(sCommandsL), sizeof(sCommandsL[]));
	
	for (int i = 0; i < iCount; i++)
	{
		Format(sCommand, sizeof(sCommand), "sm_%s", sCommandsL[i]);
		if (GetCommandFlags(sCommand) == INVALID_FCVAR_FLAGS) // if command not already exist
		{
			RegConsoleCmd(sCommand, Command_SetOITC, "Allows the Admin or Warden to set OneInTheChamber as next round");
		}
	}
}

/******************************************************************************
                   COMMANDS
******************************************************************************/

// Admin & Warden set Event
public Action Command_SetOITC(int client, int args)
{
	if (!gc_bPlugin.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "OITC_tag", "OITC_disabled");
		return Plugin_Handled;
	}
	
	if (client == 0) // Called by a server/voting
	{
		StartEventRound(gc_bBeginSetVW.BoolValue);
		
		if (!gp_bMyJailbreak)
		{
			return Plugin_Handled;
		}
		
		if (MyJailbreak_ActiveLogging())
		{
			LogToFileEx(g_sEventsLogFile, "Event OneInTheChamber was started by groupvoting");
		}
	}
	else if (CheckVipFlag(client, g_sAdminFlag)) // Called by admin/VIP
	{
		if (!gc_bSetA.BoolValue)
		{
			CReplyToCommand(client, "%t %t", "OITC_tag", "OITC_setbyadmin");
			return Plugin_Handled;
		}
		
		if (GetTeamClientCount(CS_TEAM_CT) == 0 || GetTeamClientCount(CS_TEAM_T) == 0)
		{
			CReplyToCommand(client, "%t %t", "OITC_tag", "OITC_minplayer");
			return Plugin_Handled;
		}
		
		if (gp_bMyJailbreak)
		{
			char EventDay[64];
			MyJailbreak_GetEventDayName(EventDay);
			
			if (!StrEqual(EventDay, "none", false))
			{
				CReplyToCommand(client, "%t %t", "OITC_tag", "OITC_progress", EventDay);
				return Plugin_Handled;
			}
		}
		
		if (g_iCoolDown > 0 && !gc_bSetABypassCooldown.BoolValue)
		{
			CReplyToCommand(client, "%t %t", "OITC_tag", "OITC_wait", g_iCoolDown);
			return Plugin_Handled;
		}
		
		StartEventRound(gc_bBeginSetA.BoolValue);
		
		if (!gp_bMyJailbreak)
		{
			return Plugin_Handled;
		}
		
		if (MyJailbreak_ActiveLogging())
		{
			LogToFileEx(g_sEventsLogFile, "Event OnInTheChamber was started by admin %L", client);
		}
	}
	else if (gp_bWarden) // Called by warden
	{
		if (!warden_iswarden(client))
		{
			CReplyToCommand(client, "%t %t", "warden_tag", "warden_notwarden");
			return Plugin_Handled;
		}
		
		if (!gc_bSetW.BoolValue)
		{
			CReplyToCommand(client, "%t %t", "warden_tag", "OITC_setbywarden");
			return Plugin_Handled;
		}
		
		if (GetTeamClientCount(CS_TEAM_CT) == 0 || GetTeamClientCount(CS_TEAM_T) == 0)
		{
			CReplyToCommand(client, "%t %t", "OITC_tag", "OITC_minplayer");
			return Plugin_Handled;
		}
		
		if (gp_bMyJailbreak)
		{
			char EventDay[64];
			MyJailbreak_GetEventDayName(EventDay);
			
			if (!StrEqual(EventDay, "none", false))
			{
				CReplyToCommand(client, "%t %t", "OITC_tag", "OITC_progress", EventDay);
				return Plugin_Handled;
			}
		}
		
		if (g_iCoolDown > 0)
		{
			CReplyToCommand(client, "%t %t", "OITC_tag", "OITC_wait", g_iCoolDown);
			return Plugin_Handled;
		}
		
		StartEventRound(gc_bBeginSetW.BoolValue);
		
		if (!gp_bMyJailbreak)
		{
			return Plugin_Handled;
		}
		
		if (MyJailbreak_ActiveLogging())
		{
			LogToFileEx(g_sEventsLogFile, "Event OneInTheChamber was started by warden %L", client);
		}
	}
	else
	{
		CReplyToCommand(client, "%t %t", "warden_tag", "warden_notwarden");
	}
	
	return Plugin_Handled;
}

// Voting for Event
public Action Command_VoteOITC(int client, int args)
{
	if (!gc_bPlugin.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "OITC_tag", "OITC_disabled");
		return Plugin_Handled;
	}
	
	if (!gc_bVote.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "OITC_tag", "OITC_voting");
		return Plugin_Handled;
	}
	
	if (GetTeamClientCount(CS_TEAM_CT) == 0 || GetTeamClientCount(CS_TEAM_T) == 0)
	{
		CReplyToCommand(client, "%t %t", "OITC_tag", "OITC_minplayer");
		return Plugin_Handled;
	}
	
	if (gp_bMyJailbreak)
	{
		char EventDay[64];
		MyJailbreak_GetEventDayName(EventDay);
		
		if (!StrEqual(EventDay, "none", false))
		{
			CReplyToCommand(client, "%t %t", "OITC_tag", "OITC_progress", EventDay);
			return Plugin_Handled;
		}
	}
	
	if (g_iCoolDown > 0)
	{
		CReplyToCommand(client, "%t %t", "OITC_tag", "OITC_wait", g_iCoolDown);
		return Plugin_Handled;
	}
	
	char steamid[24];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	if (StrContains(g_sHasVoted, steamid, true) != -1)
	{
		CReplyToCommand(client, "%t %t", "OITC_tag", "OITC_voted");
		return Plugin_Handled;
	}
	
	int playercount = (GetClientCount(true) / 2);
	g_iVoteCount += 1;
	
	int Missing = playercount - g_iVoteCount + 1;
	Format(g_sHasVoted, sizeof(g_sHasVoted), "%s, %s", g_sHasVoted, steamid);
	
	if (g_iVoteCount > playercount)
	{
		StartEventRound(gc_bBeginSetV.BoolValue);
		
		if (!gp_bMyJailbreak)
		{
			return Plugin_Handled;
		}
		
		if (MyJailbreak_ActiveLogging())
		{
			LogToFileEx(g_sEventsLogFile, "Event OneInTheChamber was started by voting");
		}
	}
	else
	{
		CPrintToChatAll("%t %t", "OITC_tag", "OITC_need", Missing, client);
	}
	
	return Plugin_Handled;
}

/******************************************************************************
                   EVENTS
******************************************************************************/

// Round start
public void Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
	if (!g_bStartOITC && !g_bIsOITC)
	{
		if (gp_bMyJailbreak)
		{
			char EventDay[64];
			MyJailbreak_GetEventDayName(EventDay);
			
			if (!StrEqual(EventDay, "none", false))
			{
				g_iCoolDown = gc_iCooldownDay.IntValue + 1;
			}
			else if (g_iCoolDown > 0)
			{
				g_iCoolDown -= 1;
			}
		}
		else if (g_iCoolDown > 0)
		{
			g_iCoolDown -= 1;
		}
		
		return;
	}
	
	g_bIsOITC = true;
	g_bStartOITC = false;
	
	PrepareDay(false);
}

// Round End
public void Event_RoundEnd(Event event, char[] name, bool dontBroadcast)
{
	if (g_bIsOITC)
	{
		for (int i = 1; i <= MaxClients; i++)if (IsClientInGame(i))
		{
			SetEntData(i, g_iCollision_Offset, 0, 4, true);
		}
		
		delete g_hTimerTruce;
		delete g_hTimerBeacon;
		
		int winner = event.GetInt("winner");
		if (winner == 2)
		{
			PrintCenterTextAll("%t", "OITC_twin_nc");
		}
		if (winner == 3)
		{
			PrintCenterTextAll("%t", "OITC_ctwin_nc");
		}
		
		if (g_iRound == g_iMaxRound)
		{
			g_bIsOITC = false;
			g_bStartOITC = false;
			g_iRound = 0;
			Format(g_sHasVoted, sizeof(g_sHasVoted), "");
			
			if (gp_bHosties)
			{
				SetCvar("sm_hosties_lr", 1);
			}
			
			if (gp_bWarden)
			{
				SetCvar("sm_warden_enable", 1);
			}
			
			if (gp_bMyWeapons)
			{
				MyWeapons_AllowTeam(CS_TEAM_T, false);
				MyWeapons_AllowTeam(CS_TEAM_CT, true);
			}
			
			SetCvar("sv_infinite_ammo", 0);
			SetCvar("mp_teammates_are_enemies", 0);
			
			if (gp_bMyJailbreak)
			{
				SetCvar("sm_menu_enable", 1);
				
				MyJailbreak_SetEventDayRunning(false, winner);
				MyJailbreak_SetEventDayName("none");
			}
			
			//			g_iMPRoundTime.IntValue = g_iOldRoundTime;
			
			CPrintToChatAll("%t %t", "OITC_tag", "OITC_end");
		}
	}
	
	if (g_bStartOITC)
	{
		for (int i = 1; i <= MaxClients; i++)if (IsClientInGame(i))
		{
			CreateInfoPanel(i);
		}
		
		CPrintToChatAll("%t %t", "OITC_tag", "OITC_next");
		PrintCenterTextAll("%t", "OITC_next_nc");
	}
}

// Add ammos on Kill
public void Event_PlayerDeath(Event event, char[] name, bool dontBroadcast)
{
	if (g_bIsOITC)
	{
		int killer = GetClientOfUserId(event.GetInt("attacker"));
		
		GiveAmmo(killer);
	}
}

/******************************************************************************
                   FORWARDS LISTEN
******************************************************************************/

// Initialize Event
public void OnMapStart()
{
	g_iVoteCount = 0;
	g_iRound = 0;
	g_bIsOITC = false;
	g_bStartOITC = false;
	
	g_iCoolDown = gc_iCooldownStart.IntValue + 1;
	g_iTruceTime = gc_iTruceTime.IntValue;
	
	if (gc_bOverlays.BoolValue)
	{
		PrecacheDecalAnyDownload(g_sOverlayStartPath);
	}
	
	if (gc_bSounds.BoolValue)
	{
		PrecacheSoundAnyDownload(g_sSoundStartPath);
	}
}

// Listen for Last Lequest
public void OnAvailableLR(int Announced)
{
	if (g_bIsOITC && gc_bAllowLR.BoolValue && (g_iTsLR > g_iTerrorForLR.IntValue))
	{
		for (int i = 1; i <= MaxClients; i++)if (IsClientInGame(i))
		{
			SetEntData(i, g_iCollision_Offset, 0, 4, true);
			
			StripAllPlayerWeapons(i);
			if (GetClientTeam(i) == CS_TEAM_CT)
			{
				FakeClientCommand(i, "sm_weapons");
			}
			GivePlayerItem(i, "weapon_knife");
			
		}
		
		delete g_hTimerBeacon;
		delete g_hTimerTruce;
		
		if (g_iRound == g_iMaxRound)
		{
			g_bIsOITC = false;
			g_bStartOITC = false;
			g_iRound = 0;
			Format(g_sHasVoted, sizeof(g_sHasVoted), "");
			
			SetCvar("sm_hosties_lr", 1);
			SetCvar("sv_infinite_ammo", 0);
			SetCvar("mp_teammates_are_enemies", 0);
			
			if (gp_bWarden)
			{
				SetCvar("sm_warden_enable", 1);
			}
			
			if (gp_bMyWeapons)
			{
				MyWeapons_AllowTeam(CS_TEAM_T, false);
				MyWeapons_AllowTeam(CS_TEAM_CT, true);
			}
			
			if (gp_bMyJailbreak)
			{
				SetCvar("sm_menu_enable", 1);
				
				MyJailbreak_SetEventDayName("none");
				MyJailbreak_SetEventDayRunning(false, 0);
			}
			
			//			g_iMPRoundTime.IntValue = g_iOldRoundTime;
			
			CPrintToChatAll("%t %t", "OITC_tag", "OITC_end");
		}
	}
}

// Map End
public void OnMapEnd()
{
	g_bIsOITC = false;
	g_bStartOITC = false;
	
	delete g_hTimerTruce;
	delete g_hTimerBeacon;
	
	g_iVoteCount = 0;
	g_iRound = 0;
	g_sHasVoted[0] = '\0';
}

// Set Client Hook
public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
	SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

// Knife & Deagle only
public Action OnWeaponCanUse(int client, int weapon)
{
	if (!g_bIsOITC)
	{
		return Plugin_Continue;
	}
	
	char sWeapon[32];
	GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));
	
	if (StrEqual(sWeapon, "weapon_knife", false) || StrEqual(sWeapon, "weapon_deagle", false))
	{
		return Plugin_Continue;
	}
	else return Plugin_Handled;
}

//Deny weapon drops
public Action OnWeaponDrop(int client, int weapon)
{
	if (!g_bIsOITC)
	{
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!g_bIsOITC)
		return Plugin_Continue;
	
	if (damagetype != DMG_BULLET)
		return Plugin_Continue;
	
	char sWeaponName[64];
	GetEdictClassname(inflictor, sWeaponName, sizeof(sWeaponName));
	
	if (!StrEqual(sWeaponName, "weapon_knife"))
	{
		damage = 1000.0;
	}
	else if (gc_bKnifeOneHit.BoolValue)
	{
		damage = 1000.0;
	}
	else
	{
		return Plugin_Continue;
	}
	return Plugin_Changed;
}

/******************************************************************************
                   FUNCTIONS
******************************************************************************/


// Prepare Event for next round
// Prepare Event
void StartEventRound(bool thisround)
{
	g_iCoolDown = gc_iCooldownDay.IntValue;
	g_iVoteCount = 0;
	
	//	g_iOldRoundTime = g_iMPRoundTime.IntValue; // save original round time
	//	g_iMPRoundTime.IntValue = gc_iRoundTime.IntValue; // set event round time
	
	if (gp_bMyJailbreak)
	{
		char buffer[32];
		Format(buffer, sizeof(buffer), "%T", "OITC_name", LANG_SERVER);
		MyJailbreak_SetEventDayName(buffer);
		MyJailbreak_SetEventDayPlanned(true);
	}
	
	if (thisround)
	{
		g_bIsOITC = true;
		
		for (int i = 1; i <= MaxClients; i++)if (IsValidClient(i, true, false))
		{
			SetEntProp(i, Prop_Data, "m_takedamage", 0, 1);
			
			SetEntityMoveType(i, MOVETYPE_NONE);
		}
		
		CreateTimer(3.0, Timer_PrepareEvent);
		
		CPrintToChatAll("%t %t", "OITC_tag", "OITC_now");
		PrintCenterTextAll("%t", "OITC_now_nc");
	}
	else
	{
		g_bStartOITC = true;
		g_iCoolDown++;
		
		CPrintToChatAll("%t %t", "OITC_tag", "OITC_next");
		PrintCenterTextAll("%t", "OITC_next_nc");
	}
}

public Action Timer_PrepareEvent(Handle timer)
{
	PrepareDay(true);
}

void PrepareDay(bool thisround)
{
	g_iRound++;
	
	if (gp_bSmartJailDoors)
	{
		SJD_OpenDoors();
	}
	
	if ((thisround && gc_bTeleportSpawn.BoolValue) || !gc_bSpawnCell.BoolValue || !gp_bSmartJailDoors || (gc_bSpawnCell.BoolValue && (SJD_IsCurrentMapConfigured() != true))) // spawn Terrors to CT Spawn 
	{
		int RandomCT = 0;
		for (int i = 1; i <= MaxClients; i++)if (IsValidClient(i, true, false))
		{
			if (GetClientTeam(i) == CS_TEAM_CT)
			{
				CS_RespawnPlayer(i);
				RandomCT = i;
				break;
			}
		}
		
		if (RandomCT)
		{
			for (int i = 1; i <= MaxClients; i++)if (IsValidClient(i, true, false))
			{
				GetClientAbsOrigin(RandomCT, g_fPos);
				
				g_fPos[2] = g_fPos[2] + 5;
				
				TeleportEntity(i, g_fPos, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
	
	for (int i = 1; i <= MaxClients; i++)if (IsClientInGame(i))
	{
		SetEntData(i, g_iCollision_Offset, 2, 4, true);
		
		SetEntProp(i, Prop_Data, "m_takedamage", 0, 1);
		
		SetEntityMoveType(i, MOVETYPE_NONE);
		
		CreateInfoPanel(i);
		
		StripAllPlayerWeapons(i);
		
		GivePlayerItem(i, "weapon_knife");
		
		g_hTimerGiveDeagle[i] = CreateTimer(0.5, Timer_GiveAmmo, i);
	}
	
	if (gp_bMyJailbreak)
	{
		SetCvar("sm_menu_enable", 0);
		
		MyJailbreak_SetEventDayPlanned(false);
		MyJailbreak_SetEventDayRunning(true, 0);
		
		if (gc_fBeaconTime.FloatValue > 0.0)
		{
			g_hTimerBeacon = CreateTimer(gc_fBeaconTime.FloatValue, Timer_BeaconOn, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	
	if (gp_bWarden)
	{
		SetCvar("sm_warden_enable", 0);
	}
	
	if (gp_bHosties)
	{
		SetCvar("sm_hosties_lr", 0);
	}
	
	SetCvar("mp_teammates_are_enemies", 1);
	
	if (gp_bMyWeapons)
	{
		MyWeapons_AllowTeam(CS_TEAM_T, false);
		MyWeapons_AllowTeam(CS_TEAM_CT, false);
	}
	
	if (gp_bHosties)
	{
		// enable lr on last round
		g_iTsLR = GetAlivePlayersCount(CS_TEAM_T);
		
		if (gc_bAllowLR.BoolValue)
		{
			if (g_iRound == g_iMaxRound && g_iTsLR > g_iTerrorForLR.IntValue)
			{
				SetCvar("sm_hosties_lr", 1);
			}
		}
	}
	
	GameRules_SetProp("m_iRoundTime", gc_iRoundTime.IntValue * 60, 4, 0, true);
	
	g_hTimerTruce = CreateTimer(1.0, Timer_StartEvent, _, TIMER_REPEAT);
	
	CPrintToChatAll("%t %t", "OITC_tag", "OITC_rounds", g_iRound, g_iMaxRound);
}

// Give Ammo
void GiveAmmo(int client)
{
	if (IsValidClient(client, true, false))
	{
		int weaponEnt = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
		SetPlayerAmmo(client, GetEntProp(weaponEnt, Prop_Send, "m_iClip1") + 1);
	}
} 

/******************************************************************************
                   MENUS
******************************************************************************/

void CreateInfoPanel(int client)
{
	// Create info Panel
	char info[255];
	
	Panel InfoPanel = new Panel();
	
	Format(info, sizeof(info), "%T", "OITC_info_title", client);
	InfoPanel.SetTitle(info);
	
	InfoPanel.DrawText("                                   ");
	Format(info, sizeof(info), "%T", "OITC_info_line1", client);
	InfoPanel.DrawText(info);
	InfoPanel.DrawText("-----------------------------------");
	Format(info, sizeof(info), "%T", "OITC_info_line2", client);
	InfoPanel.DrawText(info);
	Format(info, sizeof(info), "%T", "OITC_info_line3", client);
	InfoPanel.DrawText(info);
	Format(info, sizeof(info), "%T", "OITC_info_line4", client);
	InfoPanel.DrawText(info);
	Format(info, sizeof(info), "%T", "OITC_info_line5", client);
	InfoPanel.DrawText(info);
	Format(info, sizeof(info), "%T", "OITC_info_line6", client);
	InfoPanel.DrawText(info);
	Format(info, sizeof(info), "%T", "OITC_info_line7", client);
	InfoPanel.DrawText(info);
	InfoPanel.DrawText("-----------------------------------");
	Format(info, sizeof(info), "%T", "warden_close", client);
	
	InfoPanel.DrawItem(info);
	InfoPanel.Send(client, Handler_NullCancel, 20);
}

/******************************************************************************
                   TIMER
******************************************************************************/

// Start Timer
public Action Timer_StartEvent(Handle timer)
{
	if (g_iTruceTime > 0)
	{
		g_iTruceTime--;
		
		if (g_iTruceTime == gc_iTruceTime.IntValue - 3)
		{
			for (int i = 1; i <= MaxClients; i++)if (IsValidClient(i, true, false))
			{
				SetEntityMoveType(i, MOVETYPE_WALK);
			}
		}
		
		PrintCenterTextAll("%t", "OITC_timeuntilstart_nc", g_iTruceTime);
		
		return Plugin_Continue;
	}
	
	g_iTruceTime = gc_iTruceTime.IntValue;
	
	for (int i = 1; i <= MaxClients; i++)if (IsValidClient(i, true, false))
	{
		SetEntProp(i, Prop_Data, "m_takedamage", 2, 1);
		
		if (gc_bOverlays.BoolValue)
		{
			ShowOverlay(i, g_sOverlayStartPath, 2.0);
		}
	}
	
	if (gc_bSounds.BoolValue)
	{
		EmitSoundToAllAny(g_sSoundStartPath);
	}
	
	PrintCenterTextAll("%t", "OITC_start_nc");
	
	CPrintToChatAll("%t %t", "OITC_tag", "OITC_start");
	
	g_hTimerTruce = null;
	
	return Plugin_Stop;
}

// Beacon Timer
public Action Timer_BeaconOn(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)if (IsValidClient(i, true, false))
	{
		MyJailbreak_BeaconOn(i, 2.0);
	}
	
	g_hTimerBeacon = null;
}

// Delay give Deagle
public Action Timer_GiveAmmo(Handle timer, any client)
{
	if (IsValidClient(client, true, false))
	{
		int weaponEnt = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
		g_hTimerGiveDeagle[client] = INVALID_HANDLE;
		
		SetPlayerAmmo(client, GetEntProp(weaponEnt, Prop_Send, "m_iClip1") + 1);
	}
	
} 
