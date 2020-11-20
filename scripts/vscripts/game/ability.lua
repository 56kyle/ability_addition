CDOTABaseAbility = CDOTABaseAbility or class({})


_G.ability_exclusion = LoadKeyValues("scripts/kv/excluded_ability_combinations.kv")
_G.ability_personal = LoadKeyValues("scripts/kv/ability_types/personal.kv")
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

function IsAbility(ability_name)
    print("IsAbility(", ability_name, ")")
    return ClassifyAbility(ability_name).is_ability
end

function ClassifyAbility(ability_name)
    local info = {}
    info.is_main_ability = table.contains(_G.all_ability_names, ability_name)
    info.is_linked_ability = (_G.linked_abilities_levels[ability_name] and true)
    info.is_pre_ability = IsAbilityDraftPreAbility(ability_name)
    info.is_ult_scepter_ability = IsAbilityDraftUltScepterAbility(ability_name)
    info.is_ult_scepter_pre_ability = IsAbilityDraftUltScepterPreAbility(ability_name)
    info.is_scepter_ability = info.is_pre_ability or info.is_ult_scepter_ability or info.is_ult_scepter_pre_ability
    info.is_hidden_at_start = info.is_pre_ability or info.is_ult_scepter_pre_ability
    info.is_ability = false
    for _, val in pairs(info) do
        info.is_ability = info.is_ability or val
    end
    return info
end

function IsAbilityDraftPreAbility(ability_name)
    return (_G.npc_abilities_override[ability_name] and _G.npc_abilities_override[ability_name]["AbilityDraftPreAbility"]) or (_G.npc_abilities_custom[ability_name] and _G.npc_abilities_custom[ability_name]["AbilityDraftPreAbility"])
end

function IsAbilityDraftUltScepterAbility(ability_name)
    return (_G.npc_abilities_override[ability_name] and _G.npc_abilities_override[ability_name]["AbilityDraftUltScepterAbility"]) or (_G.npc_abilities_custom[ability_name] and _G.npc_abilities_custom[ability_name]["AbilityDraftUltScepterAbility"])
end

function IsAbilityDraftUltScepterPreAbility(ability_name)
    return (_G.npc_abilities_override[ability_name] and _G.npc_abilities_override[ability_name]["AbilityDraftUltScepterPreAbility"]) or (_G.npc_abilities_custom[ability_name] and _G.npc_abilities_custom[ability_name]["AbilityDraftUltScepterPreAbility"])
end

function CDOTABaseAbility:Init(desired_name, parent_ability_name, ignore_children)
    print("CDOTABaseAbility:Init(desired_name = ", tostring(desired_name), ", parent_ability_name = ", tostring(parent_ability_name), ")")
    self.caster = self:GetCaster()
    if not self.caster or not self.caster.IsHero or not self.caster:IsHero() then return print("\tself.caster is not valid") end
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
        self:_ReplaceGenericAbility(desired_name)
    else
        self:_InitGenericAbility(desired_name, ignore_children)
    end
end

function CDOTABaseAbility:Activate()
    print("CDOTABaseAbility:Activate()")
    if self.active then return print("\tAlready activated") end
    self:SetHidden(self:HasBehavior(DOTA_ABILITY_BEHAVIOR_HIDDEN))
    self:SetActivated(true)
    self.active = true
end

function CDOTABaseAbility:Deactivate()
    print("CDOTABaseAbility:Deactivate()")
    if self.active then return print("\tAlready deactivated") end
    self:SetHidden(true)
    self:SetActivated(false)
    self:Refund()
    self.active = false
end

function CDOTABaseAbility:_InitGenericAbility(desired_name, ignore_children)
    self.caster.abilities[desired_name] = self
    if _G.linked_abilities[desired_name] and not ignore_children then
        for _, linked_ability_name in pairs(_G.linked_abilities[desired_name]) do
            table.insert(self.child_ability_name_list, linked_ability_name)
            if not self.caster.abilities[linked_ability_name] then
                self.caster:AddAbility(linked_ability_name, desired_name)
            end
        end
    end
    self.scepter_ability_name_list = {
        _G.npc_abilities_override[self.name] and _G.npc_abilities_override[self.name]["AbilityDraftUltScepterAbility"],
        _G.npc_abilities_override[self.name] and _G.npc_abilities_override[self.name]["AbilityDraftPreAbility"],
        _G.npc_abilities_override[self.name] and _G.npc_abilities_override[self.name]["AbilityDraftUltScepterPreAbility"]
    }
    print("\tAdding scepter_abilities if scepter present")
    if self.caster.should_have_scepter then
        for _, scepter_ability_name in pairs(self.scepter_ability_name_list) do
            print("\t\tAdding scepter_ability_name - ", scepter_ability_name)
            self.caster:AddAbility(scepter_ability_name, self.name)
        end
    end
end

function CDOTABaseAbility:_ReplaceGenericAbility(desired_name)
    local summary = self.caster.abilities[desired_name]:ToSummary()
    self.caster:UnHideAbilityToSlot(self:GetAbilityName(), self.caster.abilities[desired_name]:GetAbilityName())
    self.caster:RemoveAbilityByHandle(self.caster.abilities[desired_name])
    self.caster.abilities[desired_name] = self
    self.caster.abilities[desired_name]:FromSummary(summary)
    if self.caster.abilities[desired_name].parent_ability_name then
        self.caster.abilities[desired_name]:SetLevel(_G.linked_abilities_levels[self.caster.abilities[desired_name].name] or self.caster.abilities[desired_name]:GetLevel())
        self.caster.abilities[desired_name]:SetHidden(self.caster.abilities[desired_name]:HasBehavior(DOTA_ABILITY_BEHAVIOR_HIDDEN))
    end
    self.caster:RefreshAbilities()
end

function CDOTABaseAbility:Refund()
    print("CDOTABaseAbility:Refund()")
    if not self.caster or not self.caster.IsHero or not self.caster:IsHero() then return print("\tCaster is not a hero") end
    self.caster:SetAbilityPoints(self.caster:GetAbilityPoints() + self:GetLevel())
    self:SetLevel(0)
end

function CDOTABaseAbility:IsInnate()
    print("CDOTABaseAbility:IsInnate()")
    return false
end

function CDOTABaseAbility:IsLinkedAbility()
    return self.parent_ability_name and true
end

function CDOTABaseAbility:ToSummary()
    print("CDOTABaseAbility:ToSummary() - Taken from real name - "..self:GetAbilityName())
    local summary = {}
    summary.index = self:GetAbilityIndex()
    if summary.index < 2 then
        summary.index = 2
    end
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
        summary.ancestor = self.ancestor
    else
        summary.ancestor = self.name
    end
    return summary
end

function CDOTABaseAbility:FromSummary(summary)
    print("CDOTABaseAbility:FromSummary() - Applied to real name - "..self:GetAbilityName())
    if not summary then return print("\tno summary given") end
    print("\tSummary - ")
    for k, v in pairs(summary) do
        print("\t\t", k, " - ", v)
    end
    self:SetAbilityIndex(summary.index)
    self:SetHidden(summary.hidden)
    self:SetStealable(summary.stealable)
    self:SetStolen(summary.stolen)
    self:SetActivated(summary.activated)
    self.parent_ability_name = summary.parent_ability_name or self.parent_ability_name
    self.child_ability_name_list = summary.child_ability_name_list or self.child_ability_name_list
    self.scepter_ability_name_list = summary.scepter_ability_name_list or self.scepter_ability_name_list
    self.ancestor = summary.ancestor or self.ancestor

    if not self.caster or not self.caster.IsHero or not self.caster:IsHero() then return end
    -- Random options for what is maintained from the previous ability.
    if CDOTA_BaseNPC_Hero.Config.maintain_cooldown_for_learned_ability then
        self:StartCooldown(summary.cooldown)
    end

    if CDOTA_BaseNPC_Hero.Config.auto_fill_learned_ability_level then
        self:SetLevel(summary.level)
    else
        self.caster:SetAbilityPoints(self.caster:GetAbilityPoints() + summary.level)
    end
end

function CDOTABaseAbility:Refresh()
    -- Just a less awful name for this method
    self:MarkAbilityButtonDirty()
end

function CDOTABaseAbility:IsPrecaching()
    return self:GetAbilityName() == "generic_hidden"
end

function CDOTABaseAbility:IsMainAbility()
    return not self.parent_ability_name
end

function CDOTABaseAbility:_BeforeRemoval(ignore_children)
    print("CDOTABaseAbility:_BeforeRemoval() - Real ability name - "..self:GetAbilityName())
    if self:IsPrecaching() then return print("\tDoing nothing because this is precaching finishing") end
    self:Deactivate()
    if not ignore_children then
        for _, child_ability_name in pairs(self.child_ability_name_list) do
            print("\tRemoving child ability - ", child_ability_name)
            self.caster:RemoveAbility(self.caster.abilities[child_ability_name]:GetAbilityName())
        end
    end
    self.caster.abilities[self.name] = nil
end

function CDOTABaseAbility:HasBehavior(behavior)
	return tonumber(tostring(self:GetBehaviorInt())) == behavior
end

