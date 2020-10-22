


function CDOTA_BaseNPC:Init()
    print("CDOTA_BaseNPC:Init()")
end

function CDOTA_BaseNPC:GetAbilities()
    print("CDOTA_BaseNPC:GetAbilities()")
    local abilities = {}
    for i = 0, 31 do
        local ability = self:GetAbilityByIndex(i)
        if ability then
            print(i)
            print(ability:GetAbilityName())
            abilities[i] = ability
        end
    end
    return abilities
end

