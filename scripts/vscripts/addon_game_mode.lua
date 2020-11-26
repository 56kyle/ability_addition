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

function GameMode:InitAbilityLists()
	local abilityListKV = LoadKeyValues("scripts/npc/npc_abilities_list.txt")
	local all_ability_names = {}
	local hero_ability_pools = {}
	for hero_name, ability_table_or_name in pairs(abilityListKV) do
		hero_ability_pools["npc_dota_hero_".. hero_name] = {}
		if ability_table_or_name and type(ability_table_or_name) == "table" then
			for key, value in pairs(ability_table_or_name) do
				--Skill definition
				if type(value) ~= "table" then
					if not disabled_abilities[value] then
						if not table.contains(all_ability_names, value)then
							table.insert(all_ability_names, value)
						end
						table.insert(HeroBuilder.heroAbilityPool["npc_dota_hero_".. hero_name], value)
						HeroBuilder.abilityHeroMap[value] = hero_name
					else
						print(value, "was disabled by disabled_abilities.kv")
					end
					--Bonus Skills
				else
					HeroBuilder.linkedAbilities[key]={}
					for k,v in pairs(value) do
						--Add bonus skills to the queue
						table.insert(HeroBuilder.linkedAbilities[key],k)
						table.insert(HeroBuilder.subsidiaryAbilitiesList,k)
						HeroBuilder.linkedAbilitiesLevel[k] = tonumber(v)
					end
				end
			end
		end
	end
end
