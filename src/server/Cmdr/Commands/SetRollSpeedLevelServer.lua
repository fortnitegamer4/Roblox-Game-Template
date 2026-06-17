local ServerScriptService = game:GetService("ServerScriptService")

local Store = require(ServerScriptService.Store)

return function(context, level: number, player: Player?)
    player = if player then player else context.Executor

    Store.setRollSpeedLevel(tostring(player.UserId), level)
end
