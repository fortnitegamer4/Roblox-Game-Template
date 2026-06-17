return {
	Name = "AdjustBalance";
	Aliases = { "aB" };
	Description = "Developer-only command to add or remove test Fuel.";
	Group = "Admin";
	Args = {
		{
			Type = "number";
			Name = "Amount";
			Description = "Positive numbers add Fuel; negative numbers remove Fuel.";
		},
		{
			Type = "player";
			Name = "Player";
			Description = "The Player";
			Optional = true;
		},
	}
}
