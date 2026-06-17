local ServerScriptService = game:GetService("ServerScriptService")

local FuelService = require(ServerScriptService.Services.FuelService)

return function (context, amount: number, player: Player?)
    player = if player then player else context.Executor

    if amount > 0 then
        return FuelService.AddFuel(player, amount)
    end

    return FuelService.RemoveFuel(player, math.abs(amount))
end
