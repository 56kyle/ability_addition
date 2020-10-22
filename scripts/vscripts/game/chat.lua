_G.last_ability = nil
ListenToGameEvent("player_chat", function(keys)
    if not keys.userid then return end

    local player = PlayerInstanceFromIndex(keys.userid)
    if not player then return end

    local hero = player:GetAssignedHero()
    if not hero then return end

    local player_id = hero:GetPlayerID()
    local text = keys.text
    if string.match(text, "-add_ability") then
        local ability_name = string.gsub(text, "-add_ability ", "")
        _G.last_ability = hero:AddAbility(ability_name)
    end
    if string.match(text, "-aa") then
        local ability_name = string.gsub(text, "-aa ", "")
        _G.last_ability = hero:AddAbility(ability_name)
    end
    if string.match(text, "-remove_ability") then
        local ability_name = string.gsub(text, "-remove_ability ", "")
        if string == "-remove_ability" then
            ability_name = _G.last_ability
        end
        hero:RemoveAbility(ability_name)
    end
    if string.match(text, "-ra") then
        local ability_name = string.gsub(text, "-ra ", "")
        if string == "-ra" then
            ability_name = _G.last_ability
        end
        hero:RemoveAbility(ability_name)
    end
    if string.match(text, "-al") then
        if text == "-al" then
            _G.last_ability:SetLevel(_G.last_ability:GetLevel()+1)
        else
            local lvl = tonumber(string.gsub(text, "-al ", ""))
            _G.last_ability:SetLevel(lvl)
        end
    end
    if text == "-la" then
        table.print(hero:GetAbilities())
    end
    if string.match(text, "-test") then
        local str_num = string.gsub(text, "-test ", "")
        print(str_num)
        local num = tonumber(str_num)
        print(num)
        hero:SetModelScale(num)
    end
end, nil)

