
-------- Table of Contents
--- Line 25 - Hero Initialization
--- Line 54 - Ability Methods (Addition, Removal, etc.)
--- Line 150 - Ability Precaching and Precaching Callbacks
--- Line 183 - General Utility Methods
--- Line 226 - Rerolling Utility Methods
--- Line 329 - Ability Filter Methods (Used in CDOTA_BaseNPC_Hero.Config.allowed_ability_filters)
--- Line 383 - Compatibility Callbacks (Used in CDOTA_BaseNPC_Hero.Config.compatibility_callbacks)
--------

-------- Explanations
---- Compatibility Callbacks
--- Before -
---     If there is a "Before"..function_name function present in class_name.Config.compatibility_callbacks then
--- the function will be called with the parameters that were passed into the original function in table format.
--- Once the Before callback returns, all parameters of the main function will be reassigned based on values present
--- in the returned table, or in the evenet that nothing is returned the After callback will be called and passed
--- the initial parameters.
---
--- After -
---     The After callback will be passed the result that would have been returned if no callback had been present.
--- Whatever is returned by the After callback will be returned by the original function. If there is no After callback
--- then the original return value is returned.
--------


CDOTA_BaseNPC_Hero = CDOTA_BaseNPC_Hero or class({})

-- Default config, some parts can be modified for instances such as allowed_ability_filters,
-- while others may directly reference the main config variable.
CDOTA_BaseNPC_Hero.Config = {
    auto_fill_learned_ability_level = false,
    maintain_cooldown_for_learned_ability = false,
    main_ability_limit = 6,
    allowed_ability_filters = {
        CDOTA_BaseNPC_Hero.FilterOwnedAbilities,
        CDOTA_BaseNPC_Hero.FilterPossiblyOwnedAbilities,
        CDOTA_BaseNPC_Hero.FilterExcludedAbilityCombos,
        CDOTA_BaseNPC_Hero.FilterHeroSpecificAbilities,
    },
    compatibility_callbacks = {
        -- ("Before" or "After")..function_name = callback function
        -- Ex: BeforeInit = CDOTA_BaseNPC_Hero.RefreshAbilities
    }
}

-------- Hero Initialization, called within GameMode:OnNPCSpawned()
function CDOTA_BaseNPC_Hero:Init()
    print("CDOTA_BaseNPC_Hero:Init()")
    if not self:CheckForCallback("BeforeInit") then return self:CheckForCallback("AfterInit", print("Init canceled by compatibility callback")) end
    self.abilities = {}
    self.pending_abilities = {}
    self.should_have_scepter = self:HasScepter()
    self.all_allowed_ability_names = table.deepcopy(_G.all_ability_names)

    -- Removes all generic_hidden since we can't have repeat keys in self.abilities
    for _, ability in pairs(self:GetAbilities()) do
        if ability:GetAbilityName() == "generic_hidden" then
            CDOTA_BaseNPC.RemoveAbilityByHandle(self, ability)
        end
    end

    for _, ability in pairs(self:GetNormalAbilities()) do
        CDOTA_BaseNPC.RemoveAbilityByHandle(self, ability)
    end

    -- Must have two abilities for UI to display
    CDOTA_BaseNPC.AddAbility(self, "generic_hidden"):SetAbilityIndex(4)
    CDOTA_BaseNPC.AddAbility(self, "generic_hidden"):SetAbilityIndex(5)
    return self:CheckForCallback("AfterInit")
end
--------

-------- Ability Addition, Removal, and Retraining(Combines the two)
function CDOTA_BaseNPC_Hero:AddAbility(ability_name, parent_ability_name, ignore_children)
    print("CDOTA_BaseNPC_Hero:AddAbility()")

    -- Compatibility Callback Logic
    local params = {ability_name = ability_name, parent_ability_name = parent_ability_name, ignore_children = ignore_children}
    local callback_info = self:CheckForCallback("BeforeAddAbility", params)
    if not callback_info then return self:CheckForCallback("AfterAddAbility", params) end
    if type(callback_info) ~= "table" then return end
    ability_name = callback_info.ability_name
    parent_ability_name = callback_info.parent_ability_name
    ignore_children = callback_info.ignore_children
    --

    if not ability_name then return self:CheckForCallback("AfterAddAbility", print("\tNo ability name supplied")) end
    if not(IsAbility(ability_name)) then return self:CheckForCallback("AfterAddAbility", print("\tIs not an ability - ", ability_name)) end
    self:GetAllAllowedAbilityNames()
    if not table.contains(self.all_allowed_ability_names, ability_name) and not parent_ability_name then self:CheckForCallback("AfterAddAbility", print("\tCan't add ", ability_name, " because it is not an allowed ability")) end
    local main_abilities_count = 0
    for _, ability in pairs(self.abilities) do
        if ability and ability:IsMainAbility() and not ability:IsPrecaching() then
            main_abilities_count = main_abilities_count + 1
        end
    end
    if main_abilities_count >= CDOTA_BaseNPC_Hero.Config.main_ability_limit and not parent_ability_name then return self:CheckForCallback("AfterAddAbility", print("\tHero has too many abilities")) end
    local placeholder = CDOTA_BaseNPC.AddAbility(self, "generic_hidden")
    if not placeholder then return self:CheckForCallback("AfterAddAbility", print("\tGeneric ability could not be added")) end
    placeholder:Init(ability_name, parent_ability_name, ignore_children)
    self:Precache(ability_name, function()
        self:OnNewAbilityPrecacheFinished(ability_name, parent_ability_name, ignore_children)
    end)
    return self:CheckForCallback("AfterAddAbility", placeholder)
end

function CDOTA_BaseNPC_Hero:RelearnAbilityFor(original_ability_name, new_ability_name)
    print("CDOTA_BaseNPC_Hero:RelearnAbilityFor()")
    -- Compatibility Callback Logic
    local params = {original_ability_name = original_ability_name, new_ability_name = new_ability_name}
    local callback_info = self:CheckForCallback("BeforeRelearnAbilityFor", params)
    if not callback_info then return self:CheckForCallback("AfterRelearnAbilityFor", params) end
    if type(callback_info) ~= "table" then return end
    original_ability_name = callback_info.original_ability_name
    new_ability_name = callback_info.new_ability_name
    --

    if not original_ability_name or not new_ability_name then return self:CheckForCallback("AfterRelearnAbilityFor", print("\tMissing param")) end
    if not self.abilities[original_ability_name] then return self:CheckForCallback("AfterRelearnAbilityFor", print("\tOriginal ability not owned")) end
    if not table.contains(self.all_allowed_ability_names, new_ability_name) then return self:CheckForCallback("AfterRelearnAbilityFor", print("\tCan't relearn ", original_ability_name, " for ", new_ability_name, " because it is not an allowed ability")) end

    self.pending_abilities[new_ability_name] = original_ability_name
    self:Precache(new_ability_name, function()
        self:OnReplacementAbilityPrecacheFinished(new_ability_name, original_ability_name)
    end)
    return self:CheckForCallback("AfterRelearnAbilityFor", self.abilities[original_ability_name])
end

function CDOTA_BaseNPC_Hero:RemoveAbility(ability_name, ignore_children)
    print("CDOTA_BaseNPC_Hero:RemoveAbility()")
    -- Compatibility Callback Logic
    local params = {ability_name = ability_name, ignore_children = ignore_children}
    local callback_info = self:CheckForCallback("BeforeRemoveAbility", params)
    if not callback_info then return self:CheckForCallback("AfterRemoveAbility", params) end
    if type(callback_info) ~= "table" then return end
    ability_name = callback_info.ability_name
    ignore_children = callback_info.ignore_children
    --

    print("\tRemoving - ", ability_name)
    -- Testing if the ability has more than one dependent abilities
    if self:_DoesAbilityHaveMultipleDependencies(ability_name) then return self:CheckForCallback("AfterRemoveAbility", print("\tCan't remove ability - Too many dependent abilities")) end
    if ability_name ~= self.abilities[ability_name]:GetAbilityName() then return self:CheckForCallback("AfterRemoveAbility", print("\tAbility is precaching. Can not remove yet.")) end

    -- Testing if ability exists in the new structuring or if this is an exception
    local intrinsic_modifier = ""
    if self.abilities[ability_name] then
        intrinsic_modifier = self.abilities[ability_name]:GetIntrinsicModifierName()
        self.abilities[ability_name]:_BeforeRemoval(ignore_children)
    else
        local passing = false
        for _, ability in self:GetNormalAbilities() do
            passing = passing or ability:GetAbilityName() == ability_name
        end
        if not passing then return self:CheckForCallback("AfterRemoveAbility", print("Ability is not present")) end
    end

    -- Unremovable scepter abilities are removed manually within CDOTABaseAbility._RemoveScepterChildren
    if _G.unremovable_abilities[ability_name] then return self:CheckForCallback("AfterRemoveAbility", print("Can not remove ability - ", ability_name)) end

    CDOTA_BaseNPC.RemoveAbility(self, ability_name)
    if self:HasModifier(intrinsic_modifier) then
        self:RemoveModifierByName(intrinsic_modifier)
    end
    self:RefreshAbilities()
    return self:CheckForCallback("AfterRemoveAbility")
end

function CDOTA_BaseNPC_Hero:RemoveAbilityByHandle(ability, ignore_children)
    print("CDOTA_BaseNPC_Hero:RemoveAbilityByHandle()")
    -- Compatibility Callback Logic
    local params = {ability = ability, ignore_children = ignore_children}
    local callback_info = self:CheckForCallback("BeforeRemoveAbilityByHandle", params)
    if not callback_info then return self:CheckForCallback("AfterRemoveAbilityByHandle", params) end
    if type(callback_info) ~= "table" then return end
    ability = callback_info.ability
    ignore_children = callback_info.ignore_children
    --

    if not ability or ability:IsNull() then return self:CheckForCallback("AfterRemoveAbilityByHandle", print("\tAbility is null")) end
    print("\tRemoving (real name) - ", ability:GetAbilityName())

    -- Testing if the ability has more than one dependent abilities
    if self:_DoesAbilityHaveMultipleDependencies(ability.name or ability:GetAbilityName()) then return self:CheckForCallback("AfterRemoveAbilityByHandle", print("\tCan't remove ability - Too many dependent abilities")) end

    local intrinsic_modifier = ""
    -- Testing if ability exists in the new structuring or if this is an exception
    if self.abilities[ability.name or ability:GetAbilityName()] then
        intrinsic_modifier = self.abilities[ability.name or ability:GetAbilityName()]:GetIntrinsicModifierName()
        self.abilities[ability.name or ability:GetAbilityName()]:_BeforeRemoval(ignore_children)
    else
        return self:CheckForCallback("AfterRemoveAbilityByHandle", print("Can't remove ability"))
    end

    -- Unremovable scepter abilities are removed manually within CDOTABaseAbility._RemoveScepterChildren
    if _G.unremovable_abilities[ability:GetAbilityName()] then return self:CheckForCallback("AfterRemoveAbilityByHandle", print("Can not remove ", ability:GetAbilityName())) end

    CDOTA_BaseNPC.RemoveAbilityByHandle(self, ability)
    if self:HasModifier(intrinsic_modifier) then
        self:RemoveModifierByName(intrinsic_modifier)
    end
    self:RefreshAbilities()
    return self:CheckForCallback("AfterRemoveAbilityByHandle")
end
--------

-------- Ability Precaching and Callbacks
function CDOTA_BaseNPC_Hero:Precache(ability_name, callback)
    print("CDOTA_BaseNPC_Hero:Precache()")
    PrecacheItemByNameAsync(ability_name, callback)
end

function CDOTA_BaseNPC_Hero:OnNewAbilityPrecacheFinished(ability_name, parent_ability_name, ignore_children)
    print("CDOTA_BaseNPC_Hero:OnNewAbilityPrecacheFinished()")
    -- Compatibility Callback Logic
    local params = {ability_name = ability_name, parent_ability_name = parent_ability_name, ignore_children = ignore_children}
    local callback_info = self:CheckForCallback("BeforeOnNewAbilityPrecacheFinished", params)
    if not callback_info then return self:CheckForCallback("AfterOnNewAbilityPrecacheFinished", params) end
    if type(callback_info) ~= "table" then return end
    ability_name = callback_info.ability_name
    parent_ability_name = callback_info.parent_ability_name
    ignore_children = callback_info.ignore_children
    --

    print("\tNow adding ", ability_name)
    local new_ability = CDOTA_BaseNPC.AddAbility(self, ability_name)
    if new_ability then
        new_ability:Init(nil, parent_ability_name, ignore_children)
    else
        print("\tFailed to add ", ability_name)
        CDOTA_BaseNPC.RemoveAbilityByHandle(self, self.abilities[ability_name])
        self.abilities[ability_name] = nil
    end
    self.pending_abilities[ability_name] = nil
    return self:CheckForCallback("AfterOnNewAbilityPrecacheFinished")
end

function CDOTA_BaseNPC_Hero:OnReplacementAbilityPrecacheFinished(new_ability_name, original_ability_name)
    print("CDOTA_BaseNPC_Hero:OnReplacementAbilityPrecacheFinished()")

    -- Compatibility Callback Logic
    local params = {new_ability_name = new_ability_name, original_ability_name = original_ability_name}
    local callback_info = self:CheckForCallback("BeforeOnReplacementAbilityPrecacheFinished", params)
    if not callback_info then return self:CheckForCallback("AfterOnReplacementAbilityPrecacheFinished", params) or print("CDOTA_BaseNPC_Hero:OnReplacementAbilityPrecacheFinished has been canceled by a compatibility callback") end
    if type(callback_info) ~= "table" then return end
    new_ability_name = callback_info.new_ability_name
    original_ability_name = callback_info.original_ability_name
    --

    local new_ability = CDOTA_BaseNPC.AddAbility(self, new_ability_name)
    if new_ability then
        self.abilities[new_ability_name] = self.abilities[original_ability_name]
        new_ability:Init()
    else
        print("\tFailed to add the precached ability, deleting the placeholder and reverting to previous ability")
    end
    self.pending_abilities[new_ability_name] = nil
    return self:CheckForCallback("AfterOnReplacementAbilityPrecacheFinished")
end
--------

-------- General Utility Methods
function CDOTA_BaseNPC_Hero:_DoesAbilityHaveMultipleDependencies(ability_name)
    print("CDOTA_BaseNPC_Hero:_DoesAbilityHaveMultipleDependencies()")
    local abilities_dependent_on_ability_name = 0
    for _, ability in pairs(self.abilities) do
        if table.contains(ability.child_ability_name_list, ability_name) then
            print("\tability.name = ", ability.name)
            print("\tability:GetAbilityName() = ", ability:GetAbilityName())
            _DeepPrintTable(ability.child_ability_name_list)
            abilities_dependent_on_ability_name = abilities_dependent_on_ability_name + 1
            print("\t", ability:GetAbilityName(), "has ", ability_name, " as a dependency; count = ", abilities_dependent_on_ability_name)
        end
    end
    return abilities_dependent_on_ability_name > 1
end

function CDOTA_BaseNPC_Hero:RefreshAbilities()
    print("CDOTA_BaseNPC_Hero:RefreshAbilities()")
    if not self:CheckForCallback("BeforeRefreshAbilities") then return print("CDOTA_BaseNPC_Hero:RefreshAbilities has been canceled by a compatibility callback") end
    for _, ability in pairs(self:GetAbilities()) do
        if ability and ability.Refresh then
            ability:Refresh()
        else
            print("Ability is null or not refreshable--------------------------")
        end
    end
    return self:CheckForCallback("AfterRefreshAbilities")
end

function CDOTA_BaseNPC_Hero:GetMainAbilities()
    print("CDOTA_BaseNPC_Hero:GetMainAbilities()")
    -- Note, does not distinguish between pending_abilities, abilities that may be removed, etc.
    local main_abilities = {}
    for _, ability in pairs(self.abilities) do
        if ability:IsMainAbility() then
            print("\t", ability.name, " is a main ability")
            main_abilities[ability.name] = ability
        else
            print("\t", ability.name, " is NOT a main ability")
        end
    end
    return main_abilities
end
--------

-------- Utility Methods relating to rerolling abilities
function CDOTA_BaseNPC_Hero:GetAllAllowedAbilityNames()
    print("CDOTA_BaseNPC_Hero:GetAllAllowedAbilityNames()")
    self.all_allowed_ability_names = table.deepcopy(_G.all_ability_names)
    self:FilterAllowedAbilityNames()
end

function CDOTA_BaseNPC_Hero:FilterAllowedAbilityNames()
    print("CDOTA_BaseNPC_Hero:FilterAllowedAbilityNames()")
    for _, filter in pairs(self.Config.allowed_ability_filters) do
        filter(self)
    end
end

function CDOTA_BaseNPC_Hero:GetPoolOfRandomAbilityNames(conditions)
    print("CDOTA_BaseNPC_Hero:GetPoolOfRandomAbilityNames()")
    conditions = conditions or {}
    conditions.size = conditions.size or 9
    conditions.additional_filters = conditions.additional_filters or {}
    conditions.first_ability = self.abilities == {} or not self.abilities

    local pool_of_random_ability_names = {}
    self:GetAllAllowedAbilityNames()
    if conditions.size < 1 then return {} end

    -- Decides if the first ability is from the hero's pool or not and adds the ability to the pool
    local hero_ability_names = {}
    if math.random(1, 100) < 65 or conditions.first_ability then
        hero_ability_names = table.deepcopy(_G.hero_ability_pools[self:GetUnitName()])
        for _, hero_ability_name in pairs(hero_ability_names) do
            if not table.contains(self.all_allowed_ability_names, hero_ability_name) then
                table.remove_item(hero_ability_names, hero_ability_name)
            end
        end
    end
    table.insert(pool_of_random_ability_names, table.random(hero_ability_names) or table.random(self.all_allowed_ability_names))

    if conditions.size < 2 then return pool_of_random_ability_names end

    -- Adds the remaining abilities to the pool
    for _, ability_name in pairs(table.random_some(self.all_allowed_ability_names, conditions.size - 1)) do
        table.insert(pool_of_random_ability_names, ability_name)
    end

    return pool_of_random_ability_names
end

function CDOTA_BaseNPC_Hero:GetPoolOfRandomSummonAbilityNames(conditions)
    print("CDOTA_BaseNPC_Hero:GetPoolOfRandomSummonAbilityNames()")
    -- Just a conveinience function
    conditions = conditions or {}
    conditions.summon_abilities = true
    return self:GetPoolOfRandomAbilityNames(conditions)
end

function CDOTA_BaseNPC_Hero:GetRandomSummonAbilityName(conditions)
    print("CDOTA_BaseNPC_Hero:GetRandomSummonAbilityName()")
    -- Just a conveinience function
    conditions = conditions or {}
    conditions.size = 1
    conditions.summon_abilities = true
    local random_summon_ability_name = false
    for _, summon_ability_name in pairs(self:GetPoolOfRandomAbilityNames(conditions)) do
        random_summon_ability_name = summon_ability_name
    end
    return random_summon_ability_name or "\tError - Could not find an allowed summon ability name"
end
--------

-------- Scepter Callbacks
function CDOTA_BaseNPC_Hero:OnScepterChanged()
    print("CDOTA_BaseNPC_Hero:OnScepterChanged")
    if not self:CheckForCallback("BeforeOnScepterChanged") then return print("CDOTA_BaseNPC_Hero:OnScepterGained has been canceled by a compatibility callback") end
    if self:HasScepter() then
        self:OnScepterGained()
    else
        self:OnScepterLost()
    end
    return self:CheckForCallback("AfterOnScepterChanged")
end

function CDOTA_BaseNPC_Hero:OnScepterGained()
    print("CDOTA_BaseNPC_Hero:OnScepterGained")
    if not self:CheckForCallback("BeforeOnScepterGained") then return print("CDOTA_BaseNPC_Hero:OnScepterGained has been canceled by a compatibility callback") end
    self.should_have_scepter = true
    local scepter_ability_names_added = {}
    for _, ability in pairs(self.abilities) do
        for _, scepter_ability_name in pairs(ability.scepter_ability_name_list) do
            if not table.contains(scepter_ability_names_added, scepter_ability_name) then
                self:AddAbility(scepter_ability_name, ability.name)
                table.insert(scepter_ability_names_added, scepter_ability_name)
            end
        end
    end
    return self:CheckForCallback("AfterOnScepterGained")
end

function CDOTA_BaseNPC_Hero:OnScepterLost()
    print("CDOTA_BaseNPC_Hero:OnScepterLost")
    if not self:CheckForCallback("BeforeOnScepterLost") then return print("CDOTA_BaseNPC_Hero:OnScepterLost has been canceled by a compatibility_callback") end
    self.should_have_scepter = false
    for _, ability in pairs(self.abilities) do
        ability:_RemoveScepterChildren()
    end
    return self:CheckForCallback("AfterOnScepterLost")
end


--------- Methods for parsing for allowed abilities.
-- Each will be called in CDOTA_BaseNPC_Hero:GetAllAllowedAbilities()
-- Because of their placement in CDOTA_BaseNPC_Hero.Config.allowed_ability_filters
-- Modifiying self.config.allowed_ability_filters allows for individuals to have different
-- reroll conditions if desired.

--- Note - not all methods are by default inside CDOTA_BaseNPC_Hero.Config.allowed_ability_filters.
--- some such as CDOTA_BaseNPC_Hero:FilterSummonAbilities() will only see use in other methods where the
--- hero has their config.allowed_ability_filters modified and reverted within the same method.

function CDOTA_BaseNPC_Hero:FilterExcludedAbilityCombos()
    print("CDOTA_BaseNPC_Hero:FilterExcludedAbilityCombos()")
    for ability_name, ability in pairs(self.abilities) do
        if _G.ability_exclusion[ability_name] then
            for banned_ability_name, _ in pairs(_G.ability_exclusion[ability_name]) do
                table.remove_item(self.all_allowed_ability_names, banned_ability_name)
            end
        end
    end
end

function CDOTA_BaseNPC_Hero:FilterHeroSpecificAbilities()
    print("CDOTA_BaseNPC_Hero:FilterHeroSpecificAbilities()")
    for hero_name, ability_name in pairs(_G.ability_personal) do
        if hero_name ~= self:GetUnitName() then
            table.remove_item(self.all_allowed_ability_names, ability_name)
        end
    end
end

function CDOTA_BaseNPC_Hero:FilterOwnedAbilities()
    print("CDOTA_BaseNPC_Hero:FilterOwnedAbilities()")
    for ability_name, _ in pairs(self.abilities) do
        table.remove_item(self.all_allowed_ability_names, ability_name)
    end
end

function CDOTA_BaseNPC_Hero:FilterPossiblyOwnedAbilities()
    print("CDOTA_BaseNPC_Hero:FilterPossibleOwnedAbilities()")
    for ability_name, _ in pairs(self.pending_abilities) do
        table.remove_item(self.all_allowed_ability_names, ability_name)
    end
end

function CDOTA_BaseNPC_Hero:FilterSummonAbilities()
    print("CDOTA_BaseNPC_Hero:FilterSummonAbilities()")
    for num, ability_name in pairs(self.all_allowed_ability_names) do
        if not table.contains(_G.summon_abilities, ability_name) then
            self.all_allowed_ability_names[num] = nil
        end
    end
end
--------

-------- Compatibility Callbacks
--- Unless there is a good reason not to, please keep any functions being used in CDOTA_BaseNPC_Hero.Config.compatibility_callbacks inside this section
function CDOTA_BaseNPC_Hero:CheckForCallback(callback_name, passed_info)
    print("CDOTA_BaseNPC_Hero:CheckForCallback()")
    if CDOTA_BaseNPC_Hero.Config.compatibility_callbacks[callback_name] then
        print("CDOTA_BaseNPC_Hero:",  callback_name, "()")
        return CDOTA_BaseNPC_Hero.Config.compatibility_callbacks[callback_name](self, passed_info)
    else
        if string.starts_with(callback_name, "Before") then
            return passed_info or true
        elseif string.starts_with(callback_name, "After") then
            return passed_info
        else
            return print("ERROR - CDOTA_BaseNPC_Hero:CheckForCallback was given a callback_name not starting with 'Before' or 'After'. The callback_name is - ", callback_name)
        end
    end
end
--------
