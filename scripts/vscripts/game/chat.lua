_G.last_ability = nil
ListenToGameEvent("player_chat", function(keys)
    if not keys.userid then return end

    local player = PlayerInstanceFromIndex(keys.userid)
    if not player then return end

    local hero = player:GetAssignedHero()
    if not hero then return end

    local player_id = hero:GetPlayerID()
    local text = string.trim(string.lower(keys.text))
    if text:sub(0, 1) ~= "-" then return end

    text = text:sub(2)
    local keywords = string.split(text)
    local command = table.remove(keywords, 1)

    print("Chat Command - ", command)
    for _, val in pairs(keywords) do
        print("\tArgument - ", val)
    end

    if command == "add_ability" or command == "aa" then
        local ability_name = keywords[1] or table.random(_G.all_ability_names)
        hero:AddAbility(ability_name)
    end

    if command == "remove_ability" or command == "ra" then
        if keywords[1] and hero.abilities[keywords[1]] then
            hero:RemoveAbility(keywords[1])
        else
            if keywords[1] then
                print("Can't remove ability")
            else
                hero:RemoveAbilityByHandle(table.random_with_condition(hero.abilities, function(ability) return ability end))
            end
        end
    end

    if command == "list_heroes" or command == "lh" then
        for _, a_hero in pairs(HeroList:GetAllHeroes()) do
            print(a_hero:GetUnitName())
        end
    end

    if command == "trade_for" or command == "tf" then
        local ability_name_one = keywords[1]
        local ability_name_two = keywords[2]
        if not(ability_name_one and ability_name_two) then return print("missing params") end
        hero:RelearnAbilityFor(ability_name_one, ability_name_two)
    end

    if command == "swap" then
        local ability_one = table.random(hero.abilities).name
        local ability_two = table.random(hero.abilities).name
        hero:SwapAbilities(ability_one, ability_two, true, true)
    end

    if command == "refresh_ab" then
        hero:RefreshAbilities()
    end

    if command == "al" then
        _G.last_ability:SetLevel(tonumber(keywords[1]))
    end
    if command == "la" then
        for i, ability in pairs(hero:GetAbilities()) do
            print(tostring(i).." - "..ability:GetAbilityName())
        end
        for ability_name, ability in pairs(hero.abilities) do
            print(ability_name, " - ")
            if type(ability) == "table" then
                for k, v in pairs(ability) do
                    print("\t", k, " - ", v)
                end
            else
                print("\tAbility is not table - ")
                print(ability)
            end
        end
    end
    if command == "setlvl" then
        hero:SetLevel(tonumber(keywords[1]))
    end
    if command == "respawn" then
        hero:RespawnHero(false, false)
    end
    if command == "scale" then
        hero:SetModelScale(tonumber(keywords[1]))
    end
    if command == "gold" then
        hero:ModifyGold(tonumber(keywords[1]), true, 0)
    end
end, nil)

