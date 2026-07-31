return PlaceObj('ModDef', {
	'title', "JAZZ NoMaps",
	'description', "Optional JAZZ package: truncated Legion AI, squad wiring and loot inject for vanilla HotDiamonds when jazz-maps is not enabled.\n\nInstall instead of jazz-maps:\n1. JAZZ Assets\n2. JAZZ Units\n3. JAZZ NoMaps\n4. JAZZ\n(+ JA3_CommonLib)\n\nDisable this mod when using jazz-maps. If both are enabled, NoMaps stays inactive.\n\nОпциональный пакет JAZZ: урезанный Legion AI, wiring отрядов и лут для vanilla HotDiamonds без jazz-maps.\nСтавить вместо maps. При включённом jazz-maps — no-op.",
	'last_changes', "v0.6: remap Flak/Kevlar/HeavyArmor stubs → JazzArmor on gear refresh; armor loot pack for containers.\nv0.7: Global AI playable — manpower 40, Tax/Recruiter on; clear ErnieIsland.Sectors; economy rev migrate.\nv0.8: fix sparse gv_Squads gear refresh; missing-def log; Thugs affiliation; tier hook after bootstrap; expand remap.",
	'id', "7MsJ2Eq",
	'author', "Kpoji4er",
	'version_major', 0,
	'version_minor', 8,
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
