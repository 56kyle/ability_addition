for _, listenerId in ipairs(registeredCustomEventListeners or {}) do
	CustomGameEventManager:UnregisterListener(listenerId)
end
registeredCustomEventListeners = {}
function RegisterCustomEventListener(eventName, callback)
	local listenerId = CustomGameEventManager:RegisterListener(eventName, function(_, args)
		callback(args)
	end)

	table.insert(registeredCustomEventListeners, listenerId)
end

for _, listenerId in ipairs(registeredGameEventListeners or {}) do
	StopListeningToGameEvent(listenerId)
end
registeredGameEventListeners = {}
function RegisterGameEventListener(eventName, callback)
	local listenerId = ListenToGameEvent(eventName, callback, nil)
	table.insert(registeredGameEventListeners, listenerId)
end

function DisplayError(playerId, message)
	local player = PlayerResource:GetPlayer(playerId)
	if player then
		CustomGameEventManager:Send_ServerToPlayer(player, "display_custom_error", { message = message })
	end
end


function string.split(inputstr, sep)
	if sep == nil then sep = "%s" end
	local t={} ; i=1
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		t[i] = str
		i = i + 1
	end
	return t
end

function string.trim(s)
	return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

function AnnounceLocation()
	local calling_method = debug.getinfo(2).name
	if not calling_method then return print("Anonymous Function()") end
	if calling_method == "?" then return print("FunctionInTable()") end
    print(calling_method.."()")
end

function table.DeepPrint(self, tab_count, history)
	tab_count = tab_count or 0
	history = history or {}
	for key, val in pairs(self) do
		print(key.." - ")
		if val and type(val) == "table" and val.DeepPrint then
			if table.contains(history, val) then return print("VAL ---> ", val) end
			table.insert(history, val)
			val:DeepPrint(tab_count + 1, history)
		else
            local tabs = ""
			for _ = 0, tab_count do
				tabs = tabs.."\t"
			end
			print(tabs, val)
		end
	end
end

