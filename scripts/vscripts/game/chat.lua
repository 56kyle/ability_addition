_G.last_ability = nil
ListenToGameEvent("player_chat", function(keys)
    if not keys.userid then return end

    local player = PlayerInstanceFromIndex(keys.userid)
    if not player then return end

    local hero = player:GetAssignedHero()
    if not hero then return end

    local player_id = hero:GetPlayerID()
    local text = string.trim(keys.text)
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

    if command == "force_add" then
        if keywords[1] then
            CDOTA_BaseNPC.AddAbility(hero, keywords[1])
        end
    end

    if command == "show_kv" then
        if keywords[1] then
            _DeepPrintTable(GetAbilityKV(keywords[1]))
        end
    end

    if command == "show_global" then
        if _G[keywords[1] or ""] then
            if type (_G[keywords[1]]) == "table" then
                _DeepPrintTable(_G[keywords[1]])
            else
                print(_G[keywords[1]])
            end
        end
    end

    if command == "remove_ability" or command == "ra" then
        if keywords[1] and hero.abilities[keywords[1]] then
            hero:RemoveAbility(keywords[1])
        else
            if keywords[1] then
                print("Can't remove ability")
            else
                local random_ability = table.random_with_condition(hero.abilities, function(t, k, ability) return ability:IsMainAbility() end)
                hero:RemoveAbilityByHandle(random_ability, nil)
            end
        end
    end

    if command == "list_heroes" or command == "lh" then
        for _, a_hero in pairs(HeroList:GetAllHeroes()) do
            print(a_hero:GetUnitName())
        end
    end

    if command == "aghs" then
        hero:AddItemByName("item_ultimate_scepter")
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

    if command == "re_all" then
        local conditions = {size = 6}
        local new_abilities = hero:GetPoolOfRandomAbilityNames(conditions)
        _DeepPrintTable(new_abilities)
        for ability_name, _ in pairs(hero:GetMainAbilities()) do
            local new_name = table.random(new_abilities)
            hero:RelearnAbilityFor(ability_name, new_name)
            table.remove_item(new_abilities, new_name)
        end
    end

    if command == "refresh_ab" then
        hero:RefreshAbilities()
    end

    if command == "al" then
        _G.last_ability:SetLevel(tonumber(keywords[1]))
    end

    if command == "la" then
        print("From - hero:GetAbilities()")
        for i, ability in pairs(hero:GetAbilities()) do
            print(tostring(i).." - "..ability:GetAbilityName())
        end
        print("From - hero.abilities")
        for ability_name, ability in pairs(hero.abilities) do
            print(ability_name, " - ")
            if type(ability) == "table" then
                for k, v in pairs(ability:ToSummary()) do
                    print("\t", k, " - ")
                    if type(v) == "table" then
                        for key, val in pairs(v) do
                            print("\t\t", key, " - ", val)
                        end
                    elseif v then
                        print("\t\t", v)
                    else
                        print("\t\tValue is nil")
                    end
                end
            else
                print("\tAbility is not table - ")
                print(ability)
            end
        end
    end

    if command == "describe" or command == "des" then
        if keywords[1] and hero.abilities[keywords[1]] then
            _DeepPrintTable(hero.abilities[keywords[1]])
        end
    end

    if command == "show_from_self" then
        print("Showing self.", keywords[1])
        if hero[keywords[1]] then
            if type(hero[keywords[1]]) == "table" then
                _DeepPrintTable(hero[keywords[1]])
            else
                print(hero[keywords[1]])
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

