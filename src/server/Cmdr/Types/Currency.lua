return function (registry)
	registry:RegisterType("currency", registry.Cmdr.Util.MakeEnumType("currency", { "Fuel" }))
end
