-------- Table Of Contents
--- Line 52 - Ability Initialization
--- Line 119 - Ability Summarization
--- Line 171 - Ability Removal Callbacks
--- Line 233 - Random Utility
--- Line 253 - Ability Classifiers
--- Line 283 - Global Ability Classifiers
--- Line TBD - Compatibility Callbacks

CDOTABaseAbility = CDOTABaseAbility or class({})

_G.ability_exclusion = LoadKeyValues("scripts/kv/excluded_ability_combinations.kv")
_G.hero_specific_abilities = LoadKeyValues("scripts/kv/ability_types/hero_specific.kv")
_G.unremovable_abilities = LoadKeyValues("scripts/kv/ability_types/unremovable.kv")
_G.summon_abilities = LoadKeyValues("scripts/kv/ability_types/summon.kv")
_G.disabled_abilities = LoadKeyValues("scripts/kv/ability_types/disabled.kv")
_G.innate_abilities = LoadKeyValues("scripts/kv/innate_abilities.kv")
_G.npc_abilities_override = LoadKeyValues("scripts/npc/npc_abilities_override.txt")
_G.npc_abilities_custom = LoadKeyValues("scripts/npc/npc_abilities_custom.txt")

if not _G.all_ability_names then
    _G.all_ability_names = {}
    _G.linked_abilities = {}
    _G.linked_abilities_levels = {}
    _G.subsidiary_abilities_list = {}
    _G.hero_ability_pools = {}
    _G.ability_hero_map = {}

    local ability_list_kv = LoadKeyValues("scripts/npc/npc_abilities_list.txt")
    for hero_name, all_abilities_contents in pairs(ability_list_kv) do
        _G.hero_ability_pools["npc_dota_hero_".. hero_name] = {}
        if all_abilities_contents and type(all_abilities_contents) == "table" then
            for ability_name, ability_contents in pairs(all_abilities_contents) do
                if type(ability_contents) == "table" then
                    _G.linked_abilities[ability_name] = {}
                    for sub_ability_name, level in pairs(ability_contents) do
                        table.insert(_G.linked_abilities[ability_name], sub_ability_name)
                        table.insert(_G.subsidiary_abilities_list, sub_ability_name)
                        _G.linked_abilities_levels[sub_ability_name] = tonumber(level)
                    end
                else
                    if _G.disabled_abilities[ability_contents] then
                        print(ability_contents, "was disabled by disabled_abilities.kv")
                    else
                        if not table.contains(_G.all_ability_names, ability_contents) then
                            table.insert(_G.all_ability_names, ability_contents)
                        end
                        table.insert(_G.hero_ability_pools["npc_dota_hero_".. hero_name], ability_contents)
                        _G.ability_hero_map[ability_contents] = hero_name
                    end
                end
            end
        end
    end
end


-------- Ability Initialization
function CDOTABaseAbility:Init(desired_name, parent_ability_name, ignore_children)
    print("CDOTABaseAbility:Init(desired_name = ", tostring(desired_name), ", parent_ability_name = ", tostring(parent_ability_name), ")")
    -- Compatibility Callback Logic
    local params = {desired_name = desired_name, parent_ability_name = parent_ability_name, ignore_children = ignore_children}
    local callback_info = self:CheckForCallback("BeforeInit", params)
    if not callback_info then return self:CheckForCallback("AfterInit", params) end
    if type(callback_info) ~= "table" then return print("Ability not initialized, callback_info = ", callback_info) end
    desired_name = callback_info.desired_name
    parent_ability_name = callback_info.parent_ability_name
    ignore_children = callback_info.ignore_children
    --

    self.caster = self:GetCaster()
    if not self.caster or not self.caster.IsHero or not self.caster:IsHero() then return self:CheckForCallback("AfterInit", print("\tself.caster is not valid")) end
    -- If this isn't owned by a hero, then leave it be

    desired_name = desired_name or self:GetAbilityName()
    self.name = desired_name
    print("\tself.name - ", self.name)
    print("\tActual name - ", self:GetAbilityName())
    self.caster.abilities = self.caster.abilities or {}
    self.parent_ability_name = parent_ability_name
    self.child_ability_name_list = {}
    self.scepter_ability_name_list = {}

    -- Inherits properties of previous ability based on config values, or just assigns itself
    if self.caster.abilities[desired_name] then
        -- If an ability is already there, then this is precaching finishing.
        if self.caster.abilities[desired_name]:GetAbilityName() ~= "generic_hidden" then
            self:_InitAbilityDependents(desired_name, ignore_children)
        end
        self:_ReplaceAbility(desired_name)
    else
        -- Otherwise, this is a new ability being added
        self.caster.abilities[desired_name] = self
        self:_InitAbilityDependents(desired_name, ignore_children)
    end
    return self:CheckForCallback("AfterInit")
end

function CDOTABaseAbility:_InitAbilityDependents(desired_name, ignore_children)
    print("CDOTABaseAbility:InitAbilityDependents()")
    -- Compatibility Callback Logic
    local params = {desired_name = desired_name, ignore_children = ignore_children}
    local callback_info = self:CheckForCallback("Before_InitAbilityDependents", params)
    if not callback_info then return self:CheckForCallback("After_InitAbilityDependents", params) end
    if type(callback_info) ~= "table" then return end
    desired_name = callback_info.desired_name
    ignore_children = callback_info.ignore_children
    --

    if _G.linked_abilities[desired_name] and not ignore_children then
        for _, linked_ability_name in pairs(_G.linked_abilities[desired_name]) do
            table.insert(self.child_ability_name_list, linked_ability_name)
            if not self.caster.abilities[linked_ability_name] then
                self.caster:AddAbilityToHero(linked_ability_name, desired_name)
            end
        end
    end
    self.scepter_ability_name_list = {
        HasAbilityDraftUltScepterAbility(self.name),
        HasAbilityDraftPreAbility(self.name),
        HasAbilityDraftUltScepterPreAbility(self.name)
    }
    print("\tAdding scepter_abilities if scepter present")
    if self.caster.should_have_scepter then
        for _, scepter_ability_name in pairs(self.scepter_ability_name_list) do
            if not self.caster.abilities[scepter_ability_name] then
                print("\t\tAdding scepter_ability_name - ", scepter_ability_name)
                self.caster:AddAbilityToHero(scepter_ability_name, self.name)
            else
                print("\t\tNot adding scepter_ability_name since it is already obtained - ", scepter_ability_name)
            end
        end
    end
    return self:CheckForCallback("After_InitAbilityDependents")
end

function CDOTABaseAbility:_ReplaceAbility(desired_name)
    print("CDOTABaseAbility:_ReplaceAbility()")
    -- Used for both replacing generic_hidden and normal abilities
    local summary = self.caster.abilities[desired_name]:ToSummary()
    self.caster:UnHideAbilityToSlot(self:GetAbilityName(), self.caster.abilities[desired_name]:GetAbilityName())
    self:MarkAbilityButtonDirty()
    self.caster:RemoveAbilityByHandleFromHero(self.caster.abilities[desired_name])
    self.caster.abilities[desired_name] = self
    self.caster.pending_abilities[desired_name] = nil
    self.caster.abilities[desired_name]:FromSummary(summary)
    if self.caster.pending_relearning[desired_name] then
        self.caster:RelearnAbilityFor(desired_name, self.caster.pending_relearning[desired_name])
    end
end
--------

-------- Ability Summarization - One of the more important parts here.
--- Allows for returning a placeholder ability in CDOTA_BaseNPC_Hero:AddAbilityToHero() that will
--- have it's attributes passed to the new ability when precaching is finished,
--- or to the old ability if the ability somehow fails to precache.
function CDOTABaseAbility:ToSummary()
    print("CDOTABaseAbility:ToSummary() - Taken from real name - "..self:GetAbilityName())
    -- Compatibility Callback Logic
    if not self:CheckForCallback("BeforeToSummary") then return self:CheckForCallback("AfterToSummary", print("CDOTABaseAbility:ToSummary canceled by ")) end
    --

    local summary = {}
    summary.index = self:GetAbilityIndex()
    if summary.index < 2 then
        summary.index = 2
    end
    summary.desired_name = self.name
    summary.cooldown = self:GetCooldownTimeRemaining()
    summary.hidden = self:IsHidden() and self:GetAbilityName() ~= "generic_hidden"
    summary.stealable = self:IsStealable()
    summary.stolen = self:IsStolen()
    summary.activated = self:IsActivated()
    summary.level = self:GetLevel()
    if self:GetAbilityName() == "generic_hidden" then
        summary.parent_ability_name = self.parent_ability_name
        summary.child_ability_name_list = self.child_ability_name_list
        summary.scepter_ability_name_list = self.scepter_ability_name_list
        if GetAbilityKV(self.name, "MaxLevel") == 1 then
            summary.level = 1
        end
    end
    return self:CheckForCallback("AfterToSummary", summary)
end

function CDOTABaseAbility:FromSummary(summary)
    print("CDOTABaseAbility:FromSummary() - Applied to real name - "..self:GetAbilityName())
    -- Compatibility Callback Logic
    local params = {summary = summary}
    local callback_info = self:CheckForCallback("BeforeFromSummary", params)
    if not callback_info then return self:CheckForCallback("AfterFromSummary", params) end
    if type(callback_info) ~= "table" then return end
    summary = callback_info.summary
    --

    if not summary then self:CheckForCallback("AfterFromSummary", print("\tNo summary given")) end
    print("\tSummary - ")
    for k, v in pairs(summary) do
        print("\t\t", k, " - ", v)
    end
    local index = summary.index
    while not self.caster:GetAbilityByIndex(index) and index ~= 0 do
        index = index - 1
    end
    self:SetAbilityIndex(index)

    if self:HasBehavior(DOTA_ABILITY_BEHAVIOR_HIDDEN) then
        if GetAbilityKV(self.name).IsGrantedByScepter then
            self:SetHidden(not self.caster.should_have_scepter)
            print("\tself.caster.should_have_scepter = ", self.caster.should_have_scepter)
            if self.caster.should_have_scepter then
                print("\tSet scepter ability to not hidden")
            else
                print("\tSet scepter ability to hidden")
            end
        else
            print("\tSet hidden")
            self:SetHidden(true)
        end
    else
        print("\tSetting hidden to - ", summary.hidden)
        self:SetHidden(summary.hidden)
    end
    self:SetStealable(summary.stealable)
    self:SetStolen(summary.stolen)
    self:SetActivated(summary.activated)
    if summary.desired_name == self:GetAbilityName() then
        self.parent_ability_name = summary.parent_ability_name or self.parent_ability_name
        self.child_ability_name_list = summary.child_ability_name_list or self.child_ability_name_list
        self.scepter_ability_name_list = summary.scepter_ability_name_list or self.scepter_ability_name_list
    end
    if self:IsScepterAbility() then
        print("\tIs a scepter ability")
        if self.caster:HasScepter() then
            print("\tSetting level to - 1")
            self:SetLevel(1)
        else
            print("\tSetting level to - ", summary.level or 0)
            self:SetLevel(summary.level or 0)
        end
    end
    self:MarkAbilityButtonDirty()
    return self:CheckForCallback("AfterFromSummary")
end
--------

-------- Ability Removal Callbacks
function CDOTABaseAbility:_BeforeRemoval(ignore_children)
    print("CDOTABaseAbility:_BeforeRemoval() - Real ability name - ", self:GetAbilityName())
    -- Compatibility Callback Logic
    local params = {ignore_children = ignore_children}
    local callback_info = self:CheckForCallback("Before_BeforeRemoval", params)
    if not callback_info then return self:CheckForCallback("After_BeforeRemoval", params) end
    if type(callback_info) ~= "table" then return end
    ignore_children = callback_info.ignore_children
    --

    if self:IsPrecaching() then return print("\tDoing nothing because this is precaching finishing") end
    self:SetHidden(true)
    if self:IsMainAbility() then
        self:Refund()
    end
    if not ignore_children then
        print("\tRemoving children")
        self:_RemoveChildren()
        self:_RemoveScepterChildren()
    else
        print("\t---- Ignoring Children! ----")
    end
    self.caster.abilities[self.name] = nil
    self.caster.pending_abilities[self.name] = nil
end

function CDOTABaseAbility:_RemoveChildren()
    print("CDOTABaseAbility:_RemoveChildren()")
    for _, child_ability_name in pairs(self.child_ability_name_list) do
        print("\tRemoving child ability - ", child_ability_name)
        print("\t", _, " - ", child_ability_name)
        local keep_child = false
        for other_ability_name, ability in pairs(self.caster.abilities) do
            if ability.name ~= self.name then
                keep_child = table.contains(ability.child_ability_name_list, child_ability_name) or keep_child
            end
        end
        for new_ability_name, old_ability in pairs(self.caster.pending_abilities) do
            if old_ability.name ~= self.name then
                keep_child = table.contains(old_ability.child_ability_name_list or {}, child_ability_name) or keep_child
            end
        end
        if not keep_child then
            if not _G.unremovable_abilities[child_ability_name] then
                self.caster:RemoveAbilityByHandleFromHero(self.caster.abilities[child_ability_name])
            else
                self.caster.abilities[child_ability_name]:SetHidden(true)
                CDOTA_BaseNPC.RemoveAbilityByHandle(self.caster, self.caster.abilities[child_ability_name])
                self.caster.abilities[child_ability_name] = nil
                self.caster.pending_abilities[child_ability_name] = nil
            end
        end
    end
end

function CDOTABaseAbility:_RemoveScepterChildren()
    print("CDOTABaseAbility:_RemoveScepterChildren()")
    for _, scepter_ability_name in pairs(self.scepter_ability_name_list) do
        print("\tRemoving scepter ability - ", scepter_ability_name)
        print("\t", _, " - ", scepter_ability_name)
        local keep_child = false
        for other_ability_name, ability in pairs(self.caster.abilities) do
            if ability ~= self then
                keep_child = table.contains(ability.scepter_ability_name_list, scepter_ability_name) or keep_child
            end
        end
        for new_ability_name, old_ability in pairs(self.caster.pending_abilities) do
            if old_ability.name ~= self.name then
                keep_child = table.contains(old_ability.scepter_ability_name_list or {}, scepter_ability_name) or keep_child
            end
        end
        if not keep_child then
            if not _G.unremovable_abilities[scepter_ability_name] then
                self.caster:RemoveAbilityByHandleFromHero(self.caster.abilities[scepter_ability_name])
            else
                self.caster.abilities[scepter_ability_name]:SetHidden(true)
                CDOTA_BaseNPC.RemoveAbilityByHandle(self.caster, self.caster.abilities[scepter_ability_name])
                self.caster.abilities[scepter_ability_name] = nil
                self.caster.pending_abilities[scepter_ability_name] = nil
            end
        end
    end
end

-------- Random Utility
function CDOTABaseAbility:Refund()
    print("CDOTABaseAbility:Refund()")
    if not self:CheckForCallback("BeforeRefund") then return self:CheckForCallback("AfterRefund") end
    if not self.caster or not self.caster.IsHero or not self.caster:IsHero() then return print("\tCaster is not a hero") end
    self.caster:SetAbilityPoints(self.caster:GetAbilityPoints() + self:GetLevel())
    self:SetLevel(0)
    return self:CheckForCallback("AfterRefund")
end

function CDOTABaseAbility:HasBehavior(behavior)
	local abilityBehavior = tonumber(tostring(self:GetBehaviorInt()))
	return bit.band(abilityBehavior, behavior) == behavior
end
--------

-------- Ability Classifiers
function CDOTABaseAbility:IsInnate()
    print("CDOTABaseAbility:IsInnate()")
    return table.contains(_G.innate_abilities, self.name)
end

function CDOTABaseAbility:IsMainAbility()
    print("CDOTABaseAbility:IsMainAbility()")
    return ClassifyAbility(self.name or self:GetAbilityName()).is_main_ability
end

function CDOTABaseAbility:IsLinkedAbility()
    print("CDOTABaseAbility:IsLinkedAbility()")
    return self.parent_ability_name and true
end

function CDOTABaseAbility:IsScepterAbility()
    print("CDOTABaseAbility:IsScepterAbility()")
    return GetAbilityKV(self.name).IsGrantedByScepter == 1
end

function CDOTABaseAbility:IsPrecaching()
    print("CDOTABaseAbility:IsPrecaching()")
    return self:GetAbilityName() == "generic_hidden" or self:GetAbilityName() ~= self.name
end
--------

-------- Global Ability Classifiers
function IsAbility(ability_name)
    print("IsAbility(", ability_name, ")")
    return GetAbilityKV(ability_name) and true
end

function ClassifyAbility(ability_name)
    local info = {}
    info.is_main_ability = table.contains(_G.all_ability_names, ability_name)
    info.is_linked_ability = (_G.linked_abilities_levels[ability_name] and true)
    info.is_pre_ability = HasAbilityDraftPreAbility(ability_name)
    info.is_ult_scepter_ability = HasAbilityDraftUltScepterAbility(ability_name)
    info.is_ult_scepter_pre_ability = HasAbilityDraftUltScepterPreAbility(ability_name)
    info.is_scepter_ability = info.is_pre_ability or info.is_ult_scepter_ability or info.is_ult_scepter_pre_ability
    info.is_hidden_at_start = info.is_pre_ability or info.is_ult_scepter_pre_ability
    info.is_ability = false
    for _, val in pairs(info) do
        info.is_ability = info.is_ability or (val and true)
    end
    return info
end

function HasAbilityDraftPreAbility(ability_name)
    return GetAbilityKV(ability_name, "AbilityDraftPreAbility")
end

function HasAbilityDraftUltScepterAbility(ability_name)
    return GetAbilityKV(ability_name, "AbilityDraftUltScepterAbility")
end

function HasAbilityDraftUltScepterPreAbility(ability_name)
    return GetAbilityKV(ability_name, "AbilityDraftUltScepterPreAbility")
end
--------

-------- Compatibility Callbacks
--- Unless there is a good reason not to, please keep any functions being used in CDOTABaseAbility.Config.compatibility_callbacks inside this section
function CDOTABaseAbility:CheckForCallback(callback_name, passed_info)
    -- print("CDOTABaseAbility:CheckForCallback()")
    if CDOTABaseAbility.Config.compatibility_callbacks[callback_name] then
        -- print("CDOTABaseAbility:",  callback_name, "()")
        return CDOTABaseAbility.Config.compatibility_callbacks[callback_name](self, passed_info)
    else
        if string.starts_with(callback_name, "Before") then
            -- print(callback_name, " - ", passed_info or true)
            return passed_info or true
        elseif string.starts_with(callback_name, "After") then
            -- print(callback_name, " - ", passed_info)
            return passed_info
        else
            return print("ERROR - CDOTABaseAbility:CheckForCallback was given a callback_name not starting with 'Before' or 'After'. The callback_name is - ", callback_name)
        end
    end
end

--------

-------- Default Config
CDOTABaseAbility.Config = {
    compatibility_callbacks = {
        -- event_name = callback function
        -- Ex: OnInit = CDOTABaseAbility.Refresh
    }
}
--------