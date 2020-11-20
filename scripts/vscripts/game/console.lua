

if not Console then
    Console = class({})
end

function Console:Init()
    self.variables = {
        ability = {
            default_value = "",
            help_string = "an ability",
            flags = FCVAR_PRINTABLEONLY
        },
        function_pointer = {
            default_value = "",
            help_string = "used to point at a function",
            flags = FCVAR_PRINTABLEONLY
        },
        convar_pointer = {
            default_value = "",
            help_string = "used to point at a convar",
            flags = FCVAR_PRINTABLEONLY
        }
    }
    self.commands = {
        add_ability = {
            callback = self.AddAbility,
            help_string = "Adds an ability",
            flags = FCVAR_NONE,
            other_names = {"aa"}
        },
        remove_ability = {
            callback = self.RemoveAbility,
            help_string = "Removes an ability",
            flags = FCVAR_NONE,
            other_names = {"ra"}
        },
        point_function_at_convar = {
            callback = self.PointFunctionAtConvar,
            help_string = "points a function at a convar",
            flags = FCVAR_NONE
        },
        store_handle = {
            callback = self.StoreHandle,
            help_string = "stores a handle",
            flags = FCVAR_NONE
        },
        point_handle_at_function = {
            callback = self.PointHandleAtFunction,
            help_string = "points the current handle at a function",
            flags = FCVAR_NONE
        }
    }
    for variable, info in pairs(self.variables) do
        print("Registering ConVar - ", variable)
        Convars:RegisterConvar(variable, info.default_value, info.help_string, info.flags)
    end
    for command, info in pairs(self.commands) do
        print("Registering Command - ", command)
        Convars:RegisterCommand(command, info.callback, info.help_string, info.flags)
        if info.other_names then
            for _, name in pairs(info.other_names) do
                Convars:RegisterCommand(name, info.callback, info.help_string, info.flags)
            end
        end
    end
end

function Console:AddAbility()
    player = Convars:GetCommandClient()
    if not player then return print("player is nil") end
    hero = player:GetAssignedHero()
    if not hero then return print("hero is nil") end
    print(hero:GetUnitName())
    local ability_name = Convars:GetStr("ability")
    hero:AddAbility(ability_name)
end

function Console:RemoveAbility()
    player = Convars:GetCommandClient()
    if not player then return print("player is nil") end
    hero = player:GetAssignedHero()
    if not hero then return print("hero is nil") end
    print(hero:GetUnitName())
    local ability_name = Convars:GetStr("ability")
    hero:RemoveAbility(ability_name)
end

function Console:PointFunctionAtConvar()
    local desired_function = Convars:GetStr("function_pointer")
    Convars:SetStr(Convars:GetStr("convar_pointer"), self[desired_function](self))
end

function Console:StoreHandle()
    local desired_function = Convars:GetStr("function_pointer")
    self.handle = self[desired_function](self)
end

function Console:PointHandleAtFunction()
    local desired_function = Convars:GetStr("function_pointer")
    return self[desired_function](self, self.handle)
end