
function CDOTA_BaseNPC:Init()
    print("CDOTA_BaseNPC:Init()")
end

function CDOTA_BaseNPC:GetAbilities()
    print("CDOTA_BaseNPC:GetAbilities()")
    local abilities = {}
    for i = 0, 31 do
        local ability = self:GetAbilityByIndex(i)
        if ability then
            abilities[i] = ability
        end
    end
    return abilities
end

function CDOTA_BaseNPC:GetNormalAbilities()
    local all_abilities = self:GetAbilities()
    for i, ability in pairs(all_abilities) do
        if string.match(ability:GetAbilityName(), "special_") or ability:GetAbilityName() == "generic_hidden" then
            all_abilities[i] = nil
        end
    end
    return all_abilities
end
