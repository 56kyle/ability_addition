
function CDOTA_BaseNPC_Hero:Init()
    print("CDOTA_BaseNPC_Hero:Init()")
end

function CDOTA_BaseNPC_Hero:AddAbility(ability_name)
    print("CDOTA_BaseNPC_Hero:AddAbility()")
    print("Adding - ", ability_name)
    CDOTA_BaseNPC.AddAbility(self, ability_name)
end

function CDOTA_BaseNPC_Hero:RemoveAbility(ability_name)
    print("CDOTA_BaseNPC_Hero:RemoveAbility()")
    print("Removing - ", ability_name)
    CDOTA_BaseNPC.RemoveAbility(self, ability_name)
end

function CDOTA_BaseNPC_Hero:RemoveAbilityByHandle(ability)
    print("CDOTA_BaseNPC_Hero:RemoveAbilityByHandle()")
    print("Removing - ", ability:GetAbilityName())
    CDOTA_BaseNPC.RemoveAbilityByHandle(self, ability)
end

function CDOTA_BaseNPC_Hero:Precache(ability_name)
    print("CDOTA_BaseNPC_Hero:Precache()")
    PrecacheItemByNameAsync(ability_name, function()
        self:_OnPrecacheFinished(ability_name)
    end
    )
end

function CDOTA_BaseNPC_Hero:_OnPrecacheFinished(ability_name)
    print("CDOTA_BaseNPC_Hero:_OnPrecacheFinished:()")
    CDOTA_BaseNPC.AddAbility(self, ability_name)
end




