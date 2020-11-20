
print("init.lua loaded")

if not IsServer then
    print("This isn't the server, go away")
    return
else
    print("Hey this is actually the server")
end

require("game/ability")
require("game/basenpc")
require("game/chat")
require("game/console")
require("game/hero")
