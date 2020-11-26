CDOTA_BaseNPC_Hero = CDOTA_BaseNPC_Hero or class({})

CDOTA_BaseNPC_Hero.Config = {
    auto_fill_learned_ability_level = false,
    maintain_cooldown_for_learned_ability = false,
    main_ability_limit = 6,
}

function CDOTA_BaseNPC_Hero:Init()
    print("CDOTA_BaseNPC_Hero:Init()")
    self.abilities = {}
    self.should_have_scepter = self:HasScepter()

    -- Removes all generic_hidden since we can't have repeat keys in self.abilities
    for _, ability in pairs(self:GetAbilities()) do
        if ability:GetAbilityName() == "generic_hidden" then
            CDOTA_BaseNPC.RemoveAbilityByHandle(self, ability)
        end
    end

    for _, ability in pairs(self:GetNormalAbilities()) do
        CDOTA_BaseNPC.RemoveAbilityByHandle(self, ability)
    end

    CDOTA_BaseNPC.AddAbility(self, "generic_hidden"):SetAbilityIndex(4)
    CDOTA_BaseNPC.AddAbility(self, "generic_hidden"):SetAbilityIndex(5)
end

function CDOTA_BaseNPC_Hero:AddAbility(ability_name, parent_ability_name, ignore_children)
    print("CDOTA_BaseNPC_Hero:AddAbility()")
    if not ability_name then return print("\tNo ability name supplied") end
    if not(IsAbility(ability_name)) then return print("\tIs not an ability - ", ability_name) end

    local main_abilities_count = 0
    for _, ability in pairs(self.abilities) do
        if ability and ability:IsMainAbility() and not ability:IsPrecaching() then
            main_abilities_count = main_abilities_count + 1
        end
    end
    if main_abilities_count >= CDOTA_BaseNPC_Hero.Config.main_ability_limit and not parent_ability_name then return print("\tHero has too many abilities") end
    return self:Precache(ability_name, parent_ability_name, ignore_children)
end

function CDOTA_BaseNPC_Hero:RelearnAbilityFor(original_ability_name, new_ability_name)
    print("CDOTA_BaseNPC_Hero:RelearnAbilityFor()")
    if not original_ability_name or not new_ability_name then return print("\tMissing param") end
    if not self.abilities[original_ability_name] then return print("\tOriginal ability not owned") end
    self.abilities[new_ability_name] = self.abilities[original_ability_name]
    return self:AddAbility(new_ability_name)
end

function CDOTA_BaseNPC_Hero:RelearnAbilityAtIndexFor(original_ability_index, new_ability_name)
    print("CDOTA_BaseNPC_Hero:RelearnAbilityAtIndexFor()")
    if not original_ability_index or not new_ability_name then return print("\tMissing param") end
    local original_ability_name = self:GetAbilityByIndex().name or self:GetAbilityByIndex():GetAbilityName()
    if not self.abilities[original_ability_name] then return print("\tOriginal ability not owned") end
    self.abilities[new_ability_name] = self.abilities[original_ability_name]
    return self:AddAbility(new_ability_name)
end

function CDOTA_BaseNPC_Hero:RemoveAbility(ability_name, ignore_children)
    print("CDOTA_BaseNPC_Hero:RemoveAbility()")
    print("\tRemoving - ", ability_name)
    local intrinsic_modifier = ""
    local abilities_dependent_on_ability_name = 0
    for _, ability in pairs(self.abilities) do
        if table.contains(ability.child_ability_name_list, ability_name) then
            abilities_dependent_on_ability_name = abilities_dependent_on_ability_name + 1
        end
    end
    if abilities_dependent_on_ability_name > 1 then return print("Not removing child ability, there are still other abilities depending on it.") end
    if self.abilities[ability_name] then
        intrinsic_modifier = self.abilities[ability_name]:GetIntrinsicModifierName()
        self.abilities[ability_name]:_BeforeRemoval(ignore_children)
    else
        local passing = false
        for _, ability in self:GetNormalAbilities() do
            passing = passing or ability:GetAbilityName() == ability_name
        end
        if not passing then return print("Ability is not present") end
    end
    if _G.unremovable_abilities[ability_name] then return print("Can not remove ability - ", ability_name) end
    CDOTA_BaseNPC.RemoveAbility(self, ability_name)
    if self:HasModifier(intrinsic_modifier) then
        self:RemoveModifierByName(intrinsic_modifier)
    end
    self:RefreshAbilities()
end

function CDOTA_BaseNPC_Hero:RemoveAbilityByHandle(ability, ignore_children)
    print("CDOTA_BaseNPC_Hero:RemoveAbilityByHandle()")
    if not ability or ability:IsNull() then return print("\tAbility is null") end
    print("\tRemoving (real name) - ", ability:GetAbilityName())

    local intrinsic_modifier = ""
    if self.abilities[ability.name or ability:GetAbilityName()] then
        intrinsic_modifier = self.abilities[ability.name or ability:GetAbilityName()]:GetIntrinsicModifierName()
        self.abilities[ability.name or ability:GetAbilityName()]:_BeforeRemoval(ignore_children)
    else
        return print("Can't remove ability")
    end
    if _G.unremovable_abilities[ability:GetAbilityName()] then return print("Can not remove ability - ", ability:GetAbilityName()) end
    CDOTA_BaseNPC.RemoveAbilityByHandle(self, ability)
    if self:HasModifier(intrinsic_modifier) then
        self:RemoveModifierByName(intrinsic_modifier)
    end
    self:RefreshAbilities()
end

-- All ability initialization is handled between CDOTA_BaseNPC_Hero:Precache() and CDOTABaseAbility:Init()
function CDOTA_BaseNPC_Hero:Precache(ability_name, parent_ability_name, ignore_children, ability_name_to_remove)
    print("CDOTA_BaseNPC_Hero:Precache()")
    local placeholder = CDOTA_BaseNPC.AddAbility(self, "generic_hidden")
    if not placeholder then return print("generic ability could not be added") end
    placeholder:Init(ability_name, parent_ability_name, ignore_children)
    PrecacheItemByNameAsync(ability_name, function()
        print("DOTA_BaseNPC_Hero - Precache finished")
        print("\tNow adding ability using ability_name = ", ability_name)
        local new_ability = CDOTA_BaseNPC.AddAbility(self, ability_name)
        if new_ability then
            new_ability:Init(nil, parent_ability_name, ignore_children)
            if ability_name_to_remove and self.abilities[ability_name_to_remove] then
                self:RemoveAbilityByHandle(self.abilities[ability_name_to_remove])
            end
        else
            CDOTA_BaseNPC.RemoveAbilityByHandle(self.abilities[ability_name])
            self.abilities[ability_name] = nil
        end
    end)
    return placeholder
end

function CDOTA_BaseNPC_Hero:TradeAbilities(own_ability, other_ability)
    print("CDOTA_BaseNPC_Hero:TradeAbilities()")
    local other_caster = other_ability.caster or other_ability:GetCaster()
    if not instanceof(other_caster, CDOTA_BaseNPC_Hero) then return print("\tOther ability not owned by a hero") end
    local own_name = own_ability.name
    local other_name = other_ability.name
    self:RelearnAbilityFor(own_name, other_name)
    other_caster:RelearnAbilityFor(other_name, own_name)
end

function CDOTA_BaseNPC_Hero:RefreshAbilities()
    print("CDOTA_BaseNPC_Hero:RefreshAbilities()")
    for _, ability in pairs(self:GetAbilities()) do
        if ability and ability.Refresh then
            ability:Refresh()
        else
            print("Ability is null or not refreshable--------------------------")
        end
    end
end

function CDOTA_BaseNPC_Hero:OnScepterChanged()
    print("CDOTA_BaseNPC_Hero:OnScepterChanged")
    if self:HasScepter() then
        self:OnScepterGained()
    else
        self:OnScepterLost()
    end
end

function CDOTA_BaseNPC_Hero:OnScepterGained()
    print("CDOTA_BaseNPC_Hero:OnScepterGained")
    self.should_have_scepter = true
    local scepter_ability_names_added = {}
    for _, ability in pairs(self.abilities) do
        for _, scepter_ability_name in pairs(ability.scepter_ability_name_list) do
            if not table.contains(scepter_ability_names_added, scepter_ability_name) then
                self:AddAbility(scepter_ability_name, ability)
                table.insert(scepter_ability_names_added, scepter_ability_name)
            end
        end
    end
end

function CDOTA_BaseNPC_Hero:OnScepterLost()
    print("CDOTA_BaseNPC_Hero:OnScepterLost")
    self.should_have_scepter = false
    for _, ability in pairs(self.abilities) do
        ability:_RemoveScepterChildren()
    end
end

