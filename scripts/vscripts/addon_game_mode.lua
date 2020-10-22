-- Generated from template
_G.GameMode = GameMode or {}

require("utils/init")
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
    self.teams = {}
	Console:Init()
	game_mode_entity:SetAnnouncerDisabled(true)
	game_mode_entity:SetThink( "OnThink", self, "GlobalThink", 2 )
end

-- Evaluate the state of the game
function GameMode:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end
	return 1
end
