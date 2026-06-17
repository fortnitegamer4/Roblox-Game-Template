return {
	Name = "SetRollSpeedLevel";
	Aliases = { "sRSL" };
	Description = "Developer-only command to set a player's scan cooldown upgrade level.";
	Group = "Admin";
	Args = {
		{
			Type = "number";
			Name = "Level";
			Description = "RollSpeedLevel to set. Higher values reduce scan cooldown.";
		},
		{
			Type = "player";
			Name = "Player";
			Description = "The Player";
			Optional = true;
		},
	}
}
