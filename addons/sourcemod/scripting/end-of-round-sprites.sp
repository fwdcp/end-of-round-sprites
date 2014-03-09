#include <sourcemod>
#include <sdktools>

#define CONFIG "configs/end-of-round-sprites.cfg"
#define VERSION "0.1.5"

new bool:g_bRoundEnded = false;
new Handle:g_hSprites = INVALID_HANDLE;
new g_SpriteEntities[MAXPLAYERS + 1];
new g_VelocityOffset;

public Plugin:myinfo = 
{
	name = "End-of-Round Sprites",
	author = "Forward Command Post (thesupremecommander)",
	description = "Place sprites on people's heads at the end of the round.",
	version = VERSION,
	url = "http://fwdcp.net"
}

public OnPluginStart()
{
	CreateConVar("sm_endofroundsprites_version", VERSION, "End-of-Round Sprites version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	HookEventEx("teamplay_round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEventEx("arena_round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEventEx("teamplay_round_win", OnRoundEnd, EventHookMode_PostNoCopy);
	HookEventEx("arena_win_panel", OnRoundEnd, EventHookMode_PostNoCopy);
	HookEventEx("player_death", OnPlayerDeath, EventHookMode_Post);
	
	g_hSprites = CreateKeyValues("Sprites");
	LoadSpriteConfig();
	
	for (new i = 1; i <= MAXPLAYERS; i++)
	{
		g_SpriteEntities[i] = INVALID_ENT_REFERENCE;
	}
	
	g_VelocityOffset = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
}

public OnMapStart()
{
	if (KvGotoFirstSubKey(g_hSprites))
	{
		do
		{
			decl String:sSprite[PLATFORM_MAX_PATH];
			KvGetString(g_hSprites, "sprite", sSprite, sizeof(sSprite), "");
			
			decl String:sSpriteMaterial[PLATFORM_MAX_PATH];
			FormatEx(sSpriteMaterial, sizeof(sSpriteMaterial), "%s.vmt", sSprite);
			PrecacheGeneric(sSpriteMaterial, true);
			AddFileToDownloadsTable(sSpriteMaterial);
			
			decl String:sSpriteTexture[PLATFORM_MAX_PATH];
			FormatEx(sSpriteTexture, sizeof(sSpriteTexture), "%s.vtf", sSprite);
			PrecacheGeneric(sSpriteTexture, true);
			AddFileToDownloadsTable(sSpriteTexture);
		}
		while (KvGotoNextKey(g_hSprites));
	}
	
	KvRewind(g_hSprites);
}

public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			KillSprite(i);
		}
	}
	
	g_bRoundEnded = false;
}

public OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (KvGotoFirstSubKey(g_hSprites))
	{
		do
		{
			decl String:sOverride[255];
			KvGetString(g_hSprites, "override", sOverride, sizeof(sOverride), "");
			decl String:sFlags[27];
			KvGetString(g_hSprites, "flags", sFlags, sizeof(sFlags), "");
			decl String:sSprite[PLATFORM_MAX_PATH];
			KvGetString(g_hSprites, "sprite", sSprite, sizeof(sSprite), "");
			
			for (new i = 1; i <= MaxClients; i++)
			{
				if (g_SpriteEntities[i] != INVALID_ENT_REFERENCE && IsValidEntity(g_SpriteEntities[i]))
				{
					KillSprite(i);
				}
				
				if (CheckCommandAccess(i, sOverride, ReadFlagString(sFlags), true))
				{
					decl String:sSpriteMaterial[PLATFORM_MAX_PATH];
					FormatEx(sSpriteMaterial, sizeof(sSpriteMaterial), "%s.vmt", sSprite);
					CreateSprite(i, sSpriteMaterial);
				}
			}	
		}
		while (KvGotoNextKey(g_hSprites));
	}
	
	KvRewind(g_hSprites);
	
	g_bRoundEnded = true;
}

public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bRoundEnded)
	{
		KillSprite(GetClientOfUserId(GetEventInt(event, "userid")));
	}
	
	return Plugin_Continue;
}

LoadSpriteConfig()
{
	decl String:sConfigPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigPath, sizeof(sConfigPath), CONFIG);
	FileToKeyValues(g_hSprites, sConfigPath);
}

CreateSprite(iClient, String:sSprite[])
{
	new String:sName[16];
	Format(sName, sizeof(sName), "client%i", iClient);
	DispatchKeyValue(iClient, "targetname", sName);
	
	new Float:vOrigin[3];
	GetClientEyePosition(iClient, vOrigin);
	vOrigin[2] += 25.0;
	new ent = CreateEntityByName("env_sprite_oriented");
	if (ent)
	{
		DispatchKeyValue(ent, "model", sSprite);
		DispatchKeyValue(ent, "classname", "env_sprite_oriented");
		DispatchKeyValue(ent, "spawnflags", "1");
		DispatchKeyValue(ent, "scale", "0.1");
		DispatchKeyValue(ent, "rendermode", "1");
		DispatchKeyValue(ent, "rendercolor", "255 255 255");
		DispatchKeyValue(ent, "targetname", "donator_spr");
		DispatchKeyValue(ent, "parentname", sName);
		DispatchSpawn(ent);
		
		TeleportEntity(ent, vOrigin, NULL_VECTOR, NULL_VECTOR);

		g_SpriteEntities[iClient] = EntIndexToEntRef(ent);
	}
}

KillSprite(iClient)
{
	if (g_SpriteEntities[iClient] != INVALID_ENT_REFERENCE && IsValidEntity(g_SpriteEntities[iClient]))
	{
		AcceptEntityInput(g_SpriteEntities[iClient], "kill");
		g_SpriteEntities[iClient] = INVALID_ENT_REFERENCE;
	}
}

public OnGameFrame()
{
	if (g_bRoundEnded)
	{
		new ent, Float:vOrigin[3], Float:vVelocity[3];
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && g_SpriteEntities[i] != INVALID_ENT_REFERENCE && IsValidEntity(g_SpriteEntities[i]))
			{
				ent = g_SpriteEntities[i];
				
				GetClientEyePosition(i, vOrigin);
				vOrigin[2] += 25.0;
				GetEntDataVector(i, g_VelocityOffset, vVelocity);
				TeleportEntity(ent, vOrigin, NULL_VECTOR, vVelocity);
			}
			else
			{
				g_SpriteEntities[i] = INVALID_ENT_REFERENCE;
			}
		}
	}
}