-- Generated from template
_G.GameMode = GameMode or {}

require("utils/init")
require("libraries/keyvalues")
require("game/init")

function Precache( context )
	--[[
		Precache things we know we'll use.  Possible file types include (but not limited to):
			PrecacheResource( "model", "*.vmdl", context )
			PrecacheResource( "soundfile", "*.vsndevts", context )
			PrecacheResource( "particle", "*.vpcf", context )
			PrecacheResource( "particle_folder", "particles/folder", context )
	]]
end

-- Create the game mode when we activate
function Activate()
	GameMode:InitGameMode()
end

function GameMode:InitGameMode()
	print( "Template addon is loaded." )
	local game_mode_entity = GameRules:GetGameModeEntity()
	game_mode_entity.GameMode = self
	game_mode_entity.GameMode.version="3.2"
	GameRules:SetCustomGameSetupAutoLaunchDelay(1.0)
	GameRules:SetPreGameTime(1.0)
    self.teams = {}
	Console:Init()
	game_mode_entity:SetAnnouncerDisabled(true)
	ListenToGameEvent("game_rules_state_change",		Dynamic_Wrap(GameMode, 'OnGameRulesStateChange' ),  self)
	ListenToGameEvent("dota_player_gained_level",		Dynamic_Wrap(GameMode, "OnHeroLevelUp"), 			self)
	ListenToGameEvent("npc_spawned",					Dynamic_Wrap(GameMode, "OnNPCSpawned"), 			self)
	ListenToGameEvent("dota_player_pick_hero",			Dynamic_Wrap(GameMode, "OnHeroPicked"), 		 	self)
	game_mode_entity:SetThink( "OnThink", self, "GlobalThink", 2 )
end

function GameMode:OnGameRulesStateChange(keys)
    print("OnGameRulesStateChange()")
end

function GameMode:OnHeroLevelUp(keys)
	print("OnHeroLevelUp()")
end

function GameMode:OnNPCSpawned(keys)
    if not keys or not keys.entindex then print("missing param") end
	local npc = EntIndexToHScript(keys.entindex)
	if not npc or not npc.IsHero or not npc:IsHero() then return end
	print("Hero spawned")
	npc:Init()
end

function GameMode:OnHeroPicked(keys)
	print("OnHeroPicked()")
end

-- Evaluate the state of the game
function GameMode:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		for _, a_hero in pairs(HeroList:GetAllHeroes()) do
			if a_hero.should_have_scepter ~= a_hero:HasScepter() then
				a_hero:OnScepterChanged()
			end
		end

	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end
	return 1
end
