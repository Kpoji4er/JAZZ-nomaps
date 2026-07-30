return PlaceObj('ModDef', {
	'title', "JAZZ NoMaps",
	'description', "Optional JAZZ package: truncated Legion AI, squad wiring and loot inject for vanilla HotDiamonds when jazz-maps is not enabled.\n\nInstall instead of jazz-maps:\n1. JAZZ Assets\n2. JAZZ Units\n3. JAZZ NoMaps\n4. JAZZ\n(+ JA3_CommonLib)\n\nDisable this mod when using jazz-maps. If both are enabled, NoMaps stays inactive.\n\nОпциональный пакет JAZZ: урезанный Legion AI, wiring отрядов и лут для vanilla HotDiamonds без jazz-maps.\nСтавить вместо maps. При включённом jazz-maps — no-op.",
	'last_changes', "Loot packs: JAZZ_AMMO_* + MP5A2; deny cut/TEST ammo; sanitize enemy ammo to weapon caliber.",
	'id', "7MsJ2Eq",
	'author', "Kpoji4er",
	'version_major', 0,
	'version_minor', 4,
	'version', 1,
	'lua_revision', 233360,
	'saved_with_revision', 366685,
	'code', {
		"Code/NoMaps_Autonomy.lua",
	},
	'default_options', {},
	'dependencies', {
		PlaceObj('ModDependency', {
			'id', "e6L4ECj",
			'title', "JAZZ",
		}),
		PlaceObj('ModDependency', {
			'id', "Dv3mFVN",
			'title', "JAZZ Units",
		}),
		PlaceObj('ModDependency', {
			'id', "pDGDhr",
			'title', "JAZZ Assets",
		}),
		PlaceObj('ModDependency', {
			'id', "JA3_CommonLib",
			'title', "JA3_CommonLib",
			'version_major', 1,
			'version_minor', 11,
			'required', false,
		}),
	},
})
