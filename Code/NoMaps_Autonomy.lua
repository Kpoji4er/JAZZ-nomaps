-- JAZZ Vanilla Maps (7MsJ2Eq, package jazz-nomaps) — autonomy when jazz-maps (FhNNYd) is not loaded.
-- Vanilla HotDiamonds geography only. No-op while FhNNYd is active.
-- Spec: jazz/docs/specs/active/JAZZ-COMPAT-002.md … JAZZ-COMPAT-006.md
-- COMPAT-004: Major HQ force A20; adopt InitialSquads; seed POI; UnitData remap; tiered container loot.
-- COMPAT-005: true T1-only Early squad + class-tier cap on gear major I (day-1 weight class).
-- COMPAT-006/007: multi-outpost Voronoi + ai_region_rev; 007 = unbounded nearest-outpost (full surface coverage).

JAZZ_NOMAPS_ID = "7MsJ2Eq"
JAZZ_MAPS_MOD_ID = "FhNNYd"
JAZZ_NOMAPS_MAJOR_HQ = "A20" -- vanilla The Eagle's Nest / Major's Camp

-- Strict globals: runtime OnMsg cannot *create* new _G keys (Assert "Attempt to create a new global").
-- Predeclare wrap flags/bases at file load (like jazz Guardpost_Patrols.lua); prefer rawset for writes.
g_JAZZ_NoMapsGenerateEnemySquadWrapped = rawget(_G, "g_JAZZ_NoMapsGenerateEnemySquadWrapped") or false
g_JAZZ_NoMapsBaseGenerateEnemySquad = rawget(_G, "g_JAZZ_NoMapsBaseGenerateEnemySquad") or false
g_JAZZ_NoMapsWorldFlipGuarded = rawget(_G, "g_JAZZ_NoMapsWorldFlipGuarded") or false
g_JAZZ_NoMapsBaseWorldFlip = rawget(_G, "g_JAZZ_NoMapsBaseWorldFlip") or false
JAZZ_NoMaps_CreateUnitDataWrapped = rawget(_G, "JAZZ_NoMaps_CreateUnitDataWrapped") or false
JAZZ_NoMaps_BaseCreateUnitData = rawget(_G, "JAZZ_NoMaps_BaseCreateUnitData") or false
JAZZ_NoMaps_UnitMarkerWrapped = rawget(_G, "JAZZ_NoMaps_UnitMarkerWrapped") or false
JAZZ_NoMaps_BaseUnitMarkerSpawnObjects = rawget(_G, "JAZZ_NoMaps_BaseUnitMarkerSpawnObjects") or false
JAZZ_StandaloneNoMapsBootstrap = rawget(_G, "JAZZ_StandaloneNoMapsBootstrap") or false
JAZZ_StandaloneNoMapsIsActive = rawget(_G, "JAZZ_StandaloneNoMapsIsActive") or false

GameVar("gv_JAZZ_NoMaps", function()
	return {
		schema = 1,
		active = false,
		bootstrapped = false,
		injected = {},
		auto_regions = {},
		geared = {},
		disabled_regions = {},
		ai_economy_rev = 0,
		ai_region_rev = 0,
	}
end)

-- Compat with COMPAT-001 saves that used gv_JAZZ_StandaloneNoMaps
local function lMigrateLegacyGameVar()
	local legacy = rawget(_G, "gv_JAZZ_StandaloneNoMaps")
	if type(legacy) == "table" and type(gv_JAZZ_NoMaps) == "table" then
		for k, v in pairs(legacy) do
			if gv_JAZZ_NoMaps[k] == nil then
				gv_JAZZ_NoMaps[k] = v
			end
		end
	end
end

local function lJazzMapsLoaded()
	if rawget(_G, "IsModLoaded") then
		return not not IsModLoaded(JAZZ_MAPS_MOD_ID)
	end
	if rawget(_G, "GetModLoaded") then
		return not not GetModLoaded(JAZZ_MAPS_MOD_ID)
	end
	return ModsLoaded and table.find(ModsLoaded, "id", JAZZ_MAPS_MOD_ID) and true or false
end

local function lShouldRun()
	return not lJazzMapsLoaded()
end

local function lLog(msg)
	if CombatLog and Untranslated then
		CombatLog("debug", Untranslated("[JAZZ Vanilla Maps] " .. msg))
	else
		print("[JAZZ Vanilla Maps] " .. msg)
	end
end

local function lEnsureState()
	lMigrateLegacyGameVar()
	local root = gv_JAZZ_NoMaps
	if type(root) ~= "table" then
		root = {
			schema = 1,
			active = false,
			bootstrapped = false,
			injected = {},
			auto_regions = {},
			geared = {},
			disabled_regions = {},
		}
		gv_JAZZ_NoMaps = root
	end
	root.injected = root.injected or {}
	root.auto_regions = root.auto_regions or {}
	root.geared = root.geared or {}
	root.disabled_regions = root.disabled_regions or {}
	root.ai_economy_rev = root.ai_economy_rev or 0
	root.ai_region_rev = root.ai_region_rev or 0
	return root
end

local function lHasEnemySquad(id)
	return id and EnemySquadDefs and EnemySquadDefs[id] and true or false
end

local function lPickExisting(list)
	local out = {}
	for _, id in ipairs(list or empty_table) do
		if lHasEnemySquad(id) then
			out[#out + 1] = id
		end
	end
	return out
end

local function lResolveMajorHQ()
	if gv_Sectors and gv_Sectors[JAZZ_NOMAPS_MAJOR_HQ] then
		return JAZZ_NOMAPS_MAJOR_HQ
	end
	return false
end

-- Vanilla / weak IDs → jazz EnemySquadDefs when present (units package).
local SQUAD_REMAP = {
	-- Legion (vanilla HotDiamonds IDs -> jazz-units)
	LegionAttackers_Balanced_Easy = "LegionAttackers_JazzBalanced_Easy_Assault",
	LegionAttackers_Balanced_Easy_Assault = "LegionAttackers_JazzBalanced_Easy_Assault",
	LegionAttackers_Balanced = "LegionAttackers_JazzBalanced_Easy_Assault",
	LegionAttackers_Balanced_Hard = "LegionAttackers_Balanced_Hard",
	LegionRaidSquad = "LegionJAZZSquadT1_Early",
	LegionRaidSquad_Easy = "LegionJAZZSquadT1_Early",
	LegionRaidSquad_01 = "LegionJAZZSquadT1_Early",
	LegionRaidSquad_02 = "LegionJAZZSquadT1_Early",
	LegionRaidSquad_03 = "LegionJAZZSquadT1_Early",
	LegionDefenders_Easy = "LegionGlobalAI_Garrison",
	LegionDefenders_Mobile_Easy = "LegionGlobalAI_Patrol",
	LegionDefenders_Shooters_Easy = "LegionAttackers_JazzBalanced_Easy_Assault",
	FortressDefenders = "LegionFortressDefenders",
	-- FortressPierre: keep vanilla (1x Pierre + PierreGuard). Remapping to
	-- LegionJAZZSquadT2 dropped the boss — elite Legion got group "Pierre",
	-- spoke Pierre_1 with GenerateEliteUnitName ("Kingboy Life").
	LegionHeavyTroops = "LegionHeavyTroops",
	LegionHeavy = "LegionHeavyTroops",
	LegionAttackers_Shock_Easy = "LegionAttackers_Shock_Easy",
	LegionAttackers_Shock_Hard = "LegionAttackers_Shock_Hard",
	LegionAttackers_Marksmen_Easy = "LegionAttackers_Marksmen_Easy",
	LegionAttackers_Marksmen_Hard = "LegionAttackers_Marksmen_Hard",
	LegionAttackers_Ordnance_Easy = "LegionAttackers_Ordnance_Easy",
	LegionAttackers_Ordnance_Hard = "LegionAttackers_Ordnance_Hard",
	LegionExtraSquadFireArms = "LegionExtraSquadFireArms_T2",
	-- WorldFlip / faction lists (same-id jazz-units overrides preferred)
	Adonis_Troops_Assault_Light = "Adonis_Troops_Assault_Light",
	Adonis_Troops_Assault_Heavy = "Adonis_Troops_Assault_Heavy",
	Adonis_Troops_Defenders_Light = "Adonis_Troops_Defenders_Light",
	Adonis_Troops_Defenders_Heavy = "Adonis_Troops_Defenders_Heavy",
	Adonis_Heavy_Troops = "Adonis_Heavy_Troops",
	Adonis_Heavy_Troops_Alt = "Adonis_Heavy_Troops_Alt",
	Adonis_SpecOps_Light = "Adonis_SpecOps_Light",
	Adonis_SpecOps_Heavy = "Adonis_SpecOps_Heavy",
	ArmySpecOps = "ArmySpecOps",
	ArmySpecOps_alt = "ArmySpecOps_alt",
	ArmyAttackers_Balanced_Hard = "ArmyAttackers_Balanced_Hard",
	ArmyAttackers_Balanced_Alt = "ArmyAttackers_Balanced_Alt",
	RebelRaiders = "RebelRaiders",
	-- Extra HotDiamonds / legacy Legion aliases → jazz-units
	LegionRaidSquad_Hard = "LegionJAZZSquadT2",
	LegionRaidSquad_04 = "LegionJAZZSquadT1_Early",
	LegionRaidSquad_05 = "LegionJAZZSquadT1_Early",
	LegionDefenders = "LegionGlobalAI_Garrison",
	LegionDefenders_Hard = "LegionGlobalAI_Garrison",
	LegionDefenders_Mobile = "LegionGlobalAI_Patrol",
	LegionDefenders_Mobile_Hard = "LegionGlobalAI_Patrol",
	LegionDefenders_Shooters = "LegionAttackers_JazzBalanced_Easy_Assault",
	LegionDefenders_Shooters_Hard = "LegionAttackers_Balanced_Hard",
	LegionAttackers = "LegionAttackers_JazzBalanced_Easy_Assault",
	LegionAttackers_Easy = "LegionAttackers_JazzBalanced_Easy_Assault",
	LegionAttackers_Hard = "LegionAttackers_Balanced_Hard",
	LegionPatrol = "LegionGlobalAI_Patrol",
	Legion_Patrol = "LegionGlobalAI_Patrol",
	OutlookPatrool = "LegionGlobalAI_Patrol",
	Beach_Patrol = "LegionGlobalAI_Patrol",
	["3rd_Patrol"] = "LegionGlobalAI_Patrol",
	LegionOutlook_Easy = "LegionJAZZSquadT1_Early",
	LegionErnieVillage = "LegionJAZZSquadT1_Early",
	LegionRustIni = "LegionJAZZSquadT1_Early",
	LegionExtraSquadMelee = "LegionExtraSquadMelee_T2",
	-- Thug satellite squads (vanilla IDs; no jazz-units Thug EnemySquad → Legion T1 kit)
	Thugs = "LegionJAZZSquadT1_Early",
	ThugsSquad = "LegionJAZZSquadT1_Early",
	ThugSquad = "LegionJAZZSquadT1_Early",
	Thugs_Attackers = "LegionJAZZSquadT1_Early",
	ThugsAttackers = "LegionJAZZSquadT1_Early",
	Thugs_Raid = "LegionJAZZSquadT1_Early",
	ThugEnforcers = "LegionJAZZSquadT1_Early",
}

local ROLE_LISTS = {
	garrison = { "LegionGlobalAI_Garrison", "FortressDefenders", "LegionFortressDefenders" },
	patrol = { "LegionGlobalAI_Patrol", "LegionJAZZSquadT1_Early", "LegionAttackers_Balanced_Easy_Assault" },
	recon = { "LegionGlobalAI_Recon", "LegionJAZZSquadT1_Early" },
	qrf = { "LegionJAZZSquadT2", "LegionHeavyTroops" },
	attack = { "LegionJAZZSquadT1_Early", "LegionAttackers_Balanced_Easy_Assault", "LegionExtraSquadFireArms_T2" },
	strong = { "LegionJAZZSquadT2", "LegionHeavyTroops", "LegionJAZZSquadT3" },
	convoy = { "LegionGlobalAI_Convoy" },
	major = { "LegionJAZZSquadT3", "LegionHeavyTroops" },
}

local LOOT_PACKS_BY_MAJOR = {
	-- Sum of chances = inject rate; remainder = miss. T1 intentionally sparse.
	[1] = {
		{ chance = 22, id = "JAZZ_NoMaps_Container_Ammo_T1" },
		{ chance = 12, id = "JAZZ_NoMaps_Container_Common_T1" },
		{ chance = 5, id = "JAZZ_NoMaps_Container_Armor_T1" },
		{ chance = 3, id = "JAZZ_NoMaps_Container_Weapon_T1" },
	},
	[2] = {
		{ chance = 28, id = "JAZZ_NoMaps_Container_Ammo_T2" },
		{ chance = 16, id = "JAZZ_NoMaps_Container_Common_T2" },
		{ chance = 10, id = "JAZZ_NoMaps_Container_Armor_T2" },
		{ chance = 8, id = "JAZZ_NoMaps_Container_Weapon_T2" },
	},
	[3] = {
		{ chance = 30, id = "JAZZ_NoMaps_Container_Ammo_T3" },
		{ chance = 18, id = "JAZZ_NoMaps_Container_Common_T3" },
		{ chance = 14, id = "JAZZ_NoMaps_Container_Armor_T3" },
		{ chance = 12, id = "JAZZ_NoMaps_Container_Weapon_T3" },
	},
}

-- Legacy flat ids → T3 packs (if old code paths linger).
local LOOT_PACKS = LOOT_PACKS_BY_MAJOR[3]

local LOOT_POOLS_FALLBACK_BY_MAJOR = {
	[1] = {
		common = { "Meds", "Lockpick" },
		ammo = {
			"JAZZ_AMMO_9x19_Poor",
			"JAZZ_AMMO_9x19_FMJ",
			"JAZZ_AMMO_762x39_Poor",
			"JAZZ_AMMO_12gauge_Buckshot",
		},
		weapons = { "HiPower", "UZI" },
		armor = {
			"JazzArmor_FlakM69",
			"JazzArmor_LeatherPants",
			"JazzArmor_M1Helm",
		},
	},
	[2] = {
		common = { "Meds", "FragGrenade", "SmokeGrenade", "Lockpick", "Wirecutter" },
		ammo = {
			"JAZZ_AMMO_9x19_FMJ",
			"JAZZ_AMMO_556_FMJ",
			"JAZZ_AMMO_762x39_FMJ",
			"JAZZ_AMMO_12gauge_Buckshot",
		},
		weapons = { "AK47", "MP5A2", "UZI", "Glock18" },
		armor = {
			"JazzArmor_FlakM69",
			"JazzArmor_FlakM1955",
			"JazzArmor_LeatherPants",
			"JazzArmor_M1Helm",
			"JazzArmor_PASGTHelm",
		},
	},
	[3] = {
		common = { "Meds", "FragGrenade", "SmokeGrenade", "Lockpick", "Wirecutter" },
		ammo = {
			"JAZZ_AMMO_9x19_FMJ",
			"JAZZ_AMMO_556_FMJ",
			"JAZZ_AMMO_762x51_FMJ",
			"JAZZ_AMMO_762x39_FMJ",
			"JAZZ_AMMO_12gauge_Buckshot",
		},
		weapons = { "AK47", "MP5A2", "UZI", "Galil", "FAMAS", "Glock18" },
		armor = {
			"JazzArmor_FlakM69",
			"JazzArmor_FlakM1955",
			"JazzArmor_GuardianMedium",
			"JazzArmor_LeatherPants",
			"JazzArmor_GuardianLegs",
			"JazzArmor_M1Helm",
			"JazzArmor_PASGTHelm",
		},
	},
}

local LOOT_POOLS_FALLBACK = LOOT_POOLS_FALLBACK_BY_MAJOR[3]

-- Vanilla stem → JAZZ family key (pools below). Named / Hyena omitted on purpose.
-- Match stem + generic strength/map/tutorial suffixes (not LegionRaider_Jose / Bastien).
-- Exact overrides: WeakFlagHill is Goon-named → assault T1 Roughneck, not front Marauder.
local UNIT_GENERIC_SUFFIX = {
	[""] = true,
	["_Stronger"] = true,
	["_Stronger_Elite"] = true,
	["_Elite"] = true,
	["_Ernie_Elite"] = true,
	["_WeakFlagHill"] = true,
	["_Tutorial"] = true,
	["_SlowReloader"] = true,
	["_PresidentGuard"] = true,
}

-- Exact UnitData id → family (wins over stem). Force Goon role for Flag Hill openers.
local UNIT_FAMILY_OVERRIDE = {
	LegionRaider_WeakFlagHill = "assault",
}

local UNIT_FAMILY_BY_STEM = {
	LegionGoon = "assault",
	LegionManiac = "crusher",
	LegionGrenadir = "grenadier",
	LegionGrenadier = "grenadier",
	LegionRaider = "front",
	LegionMarauder = "front", -- tutorial id LegionMarauder_Tutorial (vanilla Name = Marauder)
	LegionGunner = "gunner",
	LegionSniper = "sniper",
	LegionSharpShooter = "marksman",
	LegionSharpshooter = "marksman",
	LegionScout = "flanker",
	LegionRanger = "flanker",
	Legion_Recon = "flanker",
	LegionRaidLeader = "leader",
	LegionSergant = "leader",
	LegionSergeant = "leader",
	LegionMedic = "medic",
	Legion_WitchDoctor = "medic",
	LegionRoceteer = "heavy",
	LegionRocketeer = "heavy",
	LegionMortalman = "heavy",
	Legion_Artillery = "heavy",
	LegionButcher = "butcher",
	Legion_Soldier = "front",
	Legion_Marksman = "marksman",
}

local UNIT_POOLS = {
	assault = {
		[1] = { "JAZZ_Legion_AssaultT1_Roughneck" },
		[2] = { "JAZZ_Legion_AssaultT2_Pillager", "JAZZ_Legion_AssaultT2_ShockTrooper" },
		[3] = { "JAZZ_Legion_AssaultT3_Punisher", "JAZZ_Legion_AssaultT3_SkullCrusher" },
		[4] = { "JAZZ_Legion_AssaultT4_Headsman" },
	},
	crusher = {
		[1] = { "JAZZ_Legion_AssaultT1_Crusher" },
		[2] = { "JAZZ_Legion_AssaultT2_Pyro", "JAZZ_Legion_AssaultT2_ShockTrooper" },
		[3] = { "JAZZ_Legion_AssaultT3_SkullCrusher" },
		[4] = { "JAZZ_Legion_AssaultT4_Headsman" },
	},
	grenadier = {
		[1] = { "JAZZ_Legion_AssaultT1_Grenadier" },
		[2] = { "JAZZ_Legion_AssaultT2_Pyro", "JAZZ_Legion_HeavyT2_Grenadier" },
		[3] = { "JAZZ_Legion_AssaultT3_Punisher", "JAZZ_Legion_HeavyT3_Mortarman" },
		[4] = { "JAZZ_Legion_AssaultT4_Headsman" },
	},
	front = {
		[1] = { "JAZZ_Legion_FrontT1_Marauder", "JAZZ_Legion_FrontT1_Rifleman" },
		[2] = { "JAZZ_Legion_FrontT2_Raider", "JAZZ_Legion_FrontT2_Marksman" },
		[3] = { "JAZZ_Legion_FrontT3_Veteran" },
		[4] = { "JAZZ_Legion_FrontT4_Mercenary" },
	},
	gunner = {
		[1] = { "JAZZ_Legion_GunnerT1_Gunner" },
		[2] = { "JAZZ_Legion_GunnerT2_GMPG", "JAZZ_Legion_GunnerT2_AssaultGunner" },
		[3] = { "JAZZ_Legion_GunnerT3_VeteranGunner" },
		[4] = { "JAZZ_Legion_GunnerT4_MercGunner" },
	},
	sniper = {
		-- T1: only Rifleman — Ambusher is T2 archetype; at tier 11 its primary can miss
		-- and night gear leaves FlareHandgun as the only "Firearm" in hands.
		[1] = { "JAZZ_Legion_FrontT1_Rifleman" },
		[2] = { "JAZZ_Legion_FrontT2_Ambusher", "JAZZ_Legion_FrontT2_Marksman" },
		[3] = { "JAZZ_Legion_FrontT3_Sniper" },
		[4] = { "JAZZ_Legion_FrontT4_MercenarySniper" },
	},
	marksman = {
		[1] = { "JAZZ_Legion_FrontT1_Rifleman" },
		[2] = { "JAZZ_Legion_FrontT2_Marksman" },
		[3] = { "JAZZ_Legion_FrontT3_Sniper" },
		[4] = { "JAZZ_Legion_FrontT4_MercenarySniper" },
	},
	flanker = {
		[1] = { "JAZZ_Legion_FlankerT1_Warden" },
		[2] = { "JAZZ_Legion_FlankerT2_Scout", "JAZZ_Legion_FlankerT2_Skirmisher" },
		[3] = { "JAZZ_Legion_FlankerT3_Recon", "JAZZ_Legion_FlankerT3_Pathfinder" },
		[4] = { "JAZZ_Legion_FlankerT4_Ranger" },
	},
	leader = {
		[1] = { "JAZZ_Legion_LeaderT1_Sergeant" },
		[2] = { "JAZZ_Legion_LeaderT2_Lieutenant" },
		[3] = { "JAZZ_Legion_LeaderT3_Captain" },
		[4] = { "JAZZ_Legion_LeaderT4_MercenaryCaptain" },
	},
	medic = {
		[1] = { "JAZZ_Legion_FrontT1_Bonemaker" },
		[2] = { "JAZZ_Legion_FrontT1_Bonemaker" },
		[3] = { "JAZZ_Legion_FrontT1_Bonemaker" },
		[4] = { "JAZZ_Legion_FrontT1_Bonemaker" },
	},
	heavy = {
		[1] = { "JAZZ_Legion_HeavyT1_Rocketeer" },
		[2] = { "JAZZ_Legion_HeavyT2_Grenadier" },
		[3] = { "JAZZ_Legion_HeavyT3_Mortarman" },
		[4] = { "JAZZ_Legion_HeavyT3_Mortarman" },
	},
	butcher = {
		[1] = { "JAZZ_Legion_AssaultT1_Crusher", "JAZZ_Legion_AssaultT1_Roughneck" },
		[2] = { "JAZZ_Legion_AssaultT2_ShockTrooper" },
		[3] = { "JAZZ_Legion_AssaultT3_SkullCrusher" },
		[4] = { "JAZZ_Legion_AssaultT4_Headsman" },
	},
}

-- Gear refresh revision: 1 = strip+CSE+ammo; 2 = +legacy armor → JazzArmor remap;
-- 3 = tier rawset before CSE + ensure firearm + sync live Unit;
-- 4 = FlareGun is not a combat firearm; sniper T1 pool without Ambusher.
local GEAR_REV = 4

-- Economy rev: 1 = Truncated TaxCap=0/manpower=12 freeze; 2 = playable Global AI defaults.
local AI_ECONOMY_REV = 2

-- Region catchment rev:
--   1 = COMPAT-006 Chebyshev R=3 + multi-outpost Voronoi (left peripheral orphans).
--   2 = COMPAT-007 unbounded nearest-outpost Voronoi (full surface coverage; mop≤1; foreign_gp=0).
-- Existing saves rebuild JAZZ_Auto_* Sectors when ai_region_rev < AI_REGION_REV.
local AI_REGION_REV = 2
-- false = unbounded Chebyshev nearest-outpost; number = hard distance cap (legacy).
local AUTO_REGION_RADIUS = false

-- Vanilla / incomplete JAZZ stubs (no ArmorRating) → playable JazzArmor_* (Sergej: light→flak, medium→kevlar/Guardian, heavy→Guardian heavy; helms/pants same bands).
local ARMOR_REMAP = {
	-- Torso light
	FlakVest = "JazzArmor_FlakM69",
	FlakVest_Kompositum = "JazzArmor_FlakM69",
	FlakVest_WeavePadding = "JazzArmor_FlakM69",
	FlakVest_CeramicPlates = "JazzArmor_FlakM69",
	FlakArmor = "JazzArmor_FlakM69",
	FlakArmor_Kompositum = "JazzArmor_FlakM69",
	FlakArmor_WeavePadding = "JazzArmor_FlakM69",
	FlakArmor_CeramicPlates = "JazzArmor_FlakM69",
	CamoArmor_Light = "JazzArmor_FlakM1955",
	CamoArmor_Light_Kompositum = "JazzArmor_FlakM1955",
	-- Torso medium
	KevlarVest = "JazzArmor_GuardianMedium",
	KevlarVest_Kompositum = "JazzArmor_GuardianMedium",
	KevlarVest_WeavePadding = "JazzArmor_GuardianMedium",
	KevlarVest_CeramicPlates = "JazzArmor_GuardianMedium",
	KevlarChestplate = "JazzArmor_GuardianMedium",
	KevlarChestplate_Kompositum = "JazzArmor_GuardianMedium",
	KevlarChestplate_WeavePadding = "JazzArmor_GuardianMedium",
	KevlarChestplate_CeramicPlates = "JazzArmor_GuardianMedium",
	CamoArmor_Medium = "JazzArmor_GuardianMedium",
	CamoArmor_Medium_Kompositum = "JazzArmor_GuardianMedium",
	-- Torso heavy
	HeavyArmorTorso = "JazzArmor_GuardianFull",
	HeavyArmorTorso_Kompositum = "JazzArmor_GuardianFull",
	HeavyArmorTorso_WeavePadding = "JazzArmor_GuardianFull",
	HeavyArmorTorso_CeramicPlates = "JazzArmor_GuardianFull",
	HeavyArmorChestplate = "JazzArmor_GuardianFull",
	HeavyArmorChestplate_Kompositum = "JazzArmor_GuardianFull",
	HeavyArmorChestplate_WeavePadding = "JazzArmor_GuardianFull",
	HeavyArmorChestplate_CeramicPlates = "JazzArmor_GuardianFull",
	-- Legs
	FlakLeggings = "JazzArmor_LeatherPants",
	FlakLeggings_Kompositum = "JazzArmor_LeatherPants",
	FlakLeggings_WeavePadding = "JazzArmor_LeatherPants",
	KevlarLeggings = "JazzArmor_GuardianLegs",
	KevlarLeggings_Kompositum = "JazzArmor_GuardianLegs",
	KevlarLeggings_WeavePadding = "JazzArmor_GuardianLegs",
	HeavyArmorLeggings = "JazzArmor_GuardianHeavyLegs",
	HeavyArmorLeggings_Kompositum = "JazzArmor_GuardianHeavyLegs",
	HeavyArmorLeggings_WeavePadding = "JazzArmor_GuardianHeavyLegs",
	-- Head
	LightHelmet = "JazzArmor_M1Helm",
	LightHelmet_Kompositum = "JazzArmor_M1Helm",
	LightHelmet_WeavePadding = "JazzArmor_M1Helm",
	KevlarHelmet = "JazzArmor_PASGTHelm",
	KevlarHelmet_Kompositum = "JazzArmor_PASGTHelm",
	KevlarHelmet_WeavePadding = "JazzArmor_PASGTHelm",
	HeavyArmorHelmet = "JazzArmor_GuardianHelmHeavy",
	HeavyArmorHelmet_Kompositum = "JazzArmor_GuardianHelmHeavy",
	HeavyArmorHelmet_WeavePadding = "JazzArmor_GuardianHelmHeavy",
}

-- Cut stubs kept in jazz for ID compatibility (see jazz/docs/technical/weapons/cut-content.md).
local CUT_ITEM_DENY = {
	MP5 = true,
	AR15 = true,
	M4Commando = true,
}

local function lItemExists(class)
	return class and g_Classes and g_Classes[class] and true or false
end

local function lIsCutInventoryClass(class)
	if not class then
		return true
	end
	if CUT_ITEM_DENY[class] then
		return true
	end
	-- vanilla underscore ammo families replaced by JAZZ_AMMO_*
	if class:sub(1, 1) == "_" then
		return true
	end
	local def = g_Classes and g_Classes[class]
	if def and def.Icon == "Mod/e6L4ECj/Ammopics/TEST.png" then
		return true
	end
	return false
end

local function lItemAllowed(class)
	return lItemExists(class) and not lIsCutInventoryClass(class)
end

local function lGetLegionTier()
	local quest = gv_Quests and gv_Quests["JAZZ_LegionTier"]
	if quest then
		local state = QuestGetState and QuestGetState("JAZZ_LegionTier")
		local val = state and state.JAZZ_Legion_Tier
		if val == nil and quest.JAZZ_Legion_Tier ~= nil then
			val = quest.JAZZ_Legion_Tier
		end
		val = tonumber(val)
		if val then
			return val
		end
	end
	return 11
end

local function lTierMajor(tier)
	tier = tonumber(tier) or 11
	local major = Max(1, Min(3, math.floor(tier / 10)))
	return major
end

local function lGetLootPacksForTier(tier)
	return LOOT_PACKS_BY_MAJOR[lTierMajor(tier)] or LOOT_PACKS_BY_MAJOR[1]
end

local function lGetFallbackPoolsForTier(tier)
	return LOOT_POOLS_FALLBACK_BY_MAJOR[lTierMajor(tier)] or LOOT_POOLS_FALLBACK_BY_MAJOR[1]
end

local function lCampaignClassTier()
	return Max(1, Min(4, lTierMajor(lGetLegionTier())))
end

local function lVanillaStrengthBump(unit_id)
	if type(unit_id) ~= "string" then
		return 0
	end
	if string.find(unit_id, "Elite", 1, true) then
		return 2
	end
	if string.find(unit_id, "Stronger", 1, true) then
		return 1
	end
	return 0
end

local function lIsTutorialOrWeakOpener(unit_id)
	if type(unit_id) ~= "string" then
		return false
	end
	if unit_id == "LegionRaider_WeakFlagHill" then
		return true
	end
	return string.find(unit_id, "_Tutorial", 1, true) and true or false
end

local function lMatchUnitFamily(unit_id)
	if type(unit_id) ~= "string" or unit_id == "" then
		return false
	end
	if string.sub(unit_id, 1, 11) == "JAZZ_Legion" then
		return false
	end
	local override = UNIT_FAMILY_OVERRIDE[unit_id]
	if override then
		return override
	end
	-- Longest stem match, then require a generic suffix (skip named NPCs like LegionRaider_Jose).
	local best, best_len = false, 0
	for stem, family in pairs(UNIT_FAMILY_BY_STEM) do
		if string.sub(unit_id, 1, #stem) == stem and #stem > best_len then
			best, best_len = family, #stem
		end
	end
	if not best then
		return false
	end
	local suffix = string.sub(unit_id, best_len + 1)
	if not UNIT_GENERIC_SUFFIX[suffix] then
		return false
	end
	return best
end

local function lPickFromPool(pool, seed_key)
	if type(pool) ~= "table" or #pool == 0 then
		return false
	end
	local available = {}
	for _, id in ipairs(pool) do
		if lItemExists(id) then
			available[#available + 1] = id
		end
	end
	if #available == 0 then
		return false
	end
	local idx = 1 + InteractionRand(#available, seed_key or "JAZZ_NoMapsUnitPool")
	return available[idx]
end

local function lRemapUnitTemplate(vanilla_id, seed_key)
	local family = lMatchUnitFamily(vanilla_id)
	if not family then
		return false
	end
	-- COMPAT-005: gear major I stays class T1 (no Stronger/Elite bump); Stronger_Elite→T4 only major III+.
	local major = lCampaignClassTier()
	local class_tier
	if lIsTutorialOrWeakOpener(vanilla_id) or major <= 1 then
		class_tier = 1
	elseif type(vanilla_id) == "string" and string.find(vanilla_id, "Stronger_Elite", 1, true) then
		class_tier = major >= 3 and 4 or 3
	else
		class_tier = Max(1, Min(4, major + lVanillaStrengthBump(vanilla_id)))
		if major == 2 then
			class_tier = Min(class_tier, 3)
		end
	end
	local pools = UNIT_POOLS[family]
	if not pools then
		return false
	end
	-- Walk down tiers if higher band empty / missing classes.
	for t = class_tier, 1, -1 do
		local picked = lPickFromPool(pools[t], (seed_key or "JAZZ_NoMapsRemap") .. "_" .. family .. "_" .. t)
		if picked and picked ~= vanilla_id then
			return picked
		end
	end
	return false
end

local function lRegionId(region)
	return region and (region.id or region.Id)
end

local function lSectorCoords(sector_id)
	if type(sector_id) ~= "string" or #sector_id < 2 then
		return false
	end
	local row = string.byte(sector_id, 1)
	if not row or row < string.byte("A") or row > string.byte("Z") then
		return false
	end
	local col = tonumber(string.sub(sector_id, 2))
	if not col then
		return false
	end
	return col, row - string.byte("A") + 1
end

local function lSectorDist(a, b)
	local ax, ay = lSectorCoords(a)
	local bx, by = lSectorCoords(b)
	if not ax or not bx then
		return 10000
	end
	return Max(abs(ax - bx), abs(ay - by))
end

local function lSectorIsSurface(sector)
	return sector and not sector.GroundSector and sector.Passability ~= "Water" and sector.Passability ~= "Blocked"
end

-- Disable maps-authored Legion AI regions that reference missing/non-guardpost sectors
-- (e.g. ErnieIsland → I7/B28 from jazz-maps geography).
local function lDisableMapsOnlyRegions(root)
	if not Regions then
		return
	end
	for _, region in sorted_pairs(Regions) do
		if not region.LegionAIEnabled then
			goto next_region
		end
		local rid = lRegionId(region)
		-- Never disable runtime auto-regions (ReloadLua can empty ManagedOutposts).
		if type(rid) == "string" and string.find(rid, "JAZZ_Auto_", 1, true) == 1 then
			goto next_region
		end
		local bad = rid == "ErnieIsland" or rid == "PortCacaoEnvirons" or rid == "GreatDesert" or rid == "MountainSteppe" or rid == "FleatownEnvirons" or rid == "LaBarrier" or rid == "GreatForest"
		local hq = region.MajorHQSector
		if hq and hq ~= "" and not (gv_Sectors and gv_Sectors[hq]) then
			bad = true
		end
		for _, sector_id in ipairs(region.ManagedOutposts or empty_table) do
			local sector = gv_Sectors and gv_Sectors[sector_id]
			if not sector or not sector.Guardpost then
				bad = true
				break
			end
		end
		if bad then
			region.LegionAIEnabled = false
			region.ManagedOutposts = {}
			region.Sectors = {}
			if rid then
				root.disabled_regions[rid] = true
			end
			lLog("disabled maps-only region " .. tostring(rid) .. " (cleared Sectors)")
		end
		::next_region::
	end
end

local function lManagedOutpostSet()
	local managed = {}
	for _, region in sorted_pairs(Regions or empty_table) do
		if region.LegionAIEnabled then
			for _, sector_id in ipairs(region.ManagedOutposts or empty_table) do
				managed[sector_id] = true
			end
		end
	end
	return managed
end

local function lCollectGuardposts()
	local list = {}
	for sector_id, sector in sorted_pairs(gv_Sectors or empty_table) do
		if sector and sector.Guardpost and lSectorIsSurface(sector) then
			list[#list + 1] = sector_id
		end
	end
	table.sort(list)
	return list
end

local function lRegionDisplayName(sector_id, sector)
	local city_id = sector and sector.City
	if city_id and city_id ~= "none" and gv_Cities and gv_Cities[city_id] and gv_Cities[city_id].DisplayName then
		local city_name = _InternalTranslate and _InternalTranslate(gv_Cities[city_id].DisplayName) or tostring(city_id)
		return "Округ " .. city_name
	end
	local label = sector and sector.display_name
	if label then
		local text = _InternalTranslate and _InternalTranslate(label) or tostring(label)
		if text and text ~= "" then
			return "Округ " .. text
		end
	end
	return "Округ " .. tostring(sector_id)
end

local function lWireGuardpostSquadLists(sector)
	if not sector then
		return
	end
	local function fill(field, candidates)
		local current = sector[field]
		if type(current) == "table" and #current > 0 then
			return
		end
		local picked = lPickExisting(candidates)
		if #picked > 0 then
			sector[field] = picked
		end
	end
	fill("EnemySquadsGarrisonList", ROLE_LISTS.garrison)
	fill("EnemySquadsPatroolList", ROLE_LISTS.patrol)
	fill("EnemySquadsReconList", ROLE_LISTS.recon)
	fill("EnemySquadsQRFList", ROLE_LISTS.qrf)
	fill("EnemySquadsList", ROLE_LISTS.attack)
	fill("StrongEnemySquadsList", ROLE_LISTS.strong)
	fill("ExtraDefenderSquads", ROLE_LISTS.garrison)
end

local function lCreateAutoRegion(outpost_id, sectors, major_hq)
	if not Regions or not outpost_id then
		return false
	end
	local region_id = "JAZZ_Auto_" .. outpost_id
	if Regions[region_id] then
		-- Refresh HQ / lists on existing auto region
		local existing = Regions[region_id]
		existing.MajorHQSector = major_hq or outpost_id
		existing.LegionAIEnabled = true
		existing.ManagedOutposts = { outpost_id }
		existing.Sectors = sectors
		existing.TaxCap = 1
		existing.RecruiterCap = 1
		existing.StartingManpower = 40
		existing.ManpowerCapacity = 64
		existing.MajorStartingManpower = 120
		existing.StartingSupply = existing.StartingSupply or 20000
		if (existing.PassiveSupplyPerHour or 0) <= 0 then
			existing.PassiveSupplyPerHour = 50
		end
		local convoy = lPickExisting(ROLE_LISTS.convoy)
		local function ensure_list(cur)
			if type(cur) == "table" and #cur > 0 then
				return cur
			end
			return convoy
		end
		if convoy and #convoy > 0 then
			existing.SupplySquads = ensure_list(existing.SupplySquads)
			existing.TaxSquads = ensure_list(existing.TaxSquads)
			existing.RecruiterSquads = ensure_list(existing.RecruiterSquads)
			existing.ManpowerSquads = ensure_list(existing.ManpowerSquads)
		end
		return existing
	end
	local sector = gv_Sectors[outpost_id]
	local convoy = lPickExisting(ROLE_LISTS.convoy)
	local major = lPickExisting(ROLE_LISTS.major)
	local region = PlaceObj("Region", {
		id = region_id,
		Id = region_id,
		group = "Default",
		DisplayName = lRegionDisplayName(outpost_id, sector),
		Description = "Авто-округ Legion AI (jazz-nomaps / vanilla HotDiamonds).",
		Sectors = sectors,
		LegionAIEnabled = true,
		ManagedOutposts = { outpost_id },
		MajorHQSector = major_hq or outpost_id,
		RegularSquadCap = 5,
		GarrisonCap = 2,
		PatrolCap = 1,
		ReconCap = 1,
		QRFCap = 1,
		ReinforceCap = 1,
		TaxCap = 1,
		RecruiterCap = 1,
		SupplySquads = convoy,
		ShipmentSquads = convoy,
		TaxSquads = convoy,
		RecruiterSquads = convoy,
		ManpowerSquads = convoy,
		MajorResponseSquads = major,
		StartingSupply = 20000,
		StartingManpower = 40,
		ManpowerCapacity = 64,
		MajorStartingManpower = 120,
		PassiveSupplyPerHour = 50,
		MajorResponseHeat = 900,
	})
	Regions[region_id] = region
	return region
end

local function lAssignSectorsToOutposts(outposts)
	local buckets = {}
	for _, outpost_id in ipairs(outposts) do
		buckets[outpost_id] = { outpost_id }
	end
	local radius = AUTO_REGION_RADIUS -- false = unbounded (COMPAT-007)
	for sector_id, sector in sorted_pairs(gv_Sectors or empty_table) do
		if not lSectorIsSurface(sector) then
			goto continue
		end
		local best, best_dist = false, 10000
		for _, outpost_id in ipairs(outposts) do
			local d = lSectorDist(sector_id, outpost_id)
			if d < best_dist or (d == best_dist and (not best or outpost_id < best)) then
				best, best_dist = outpost_id, d
			end
		end
		local within = best and (not radius or best_dist <= radius)
		if within and sector_id ~= best then
			local list = buckets[best]
			list[#list + 1] = sector_id
		end
		::continue::
	end
	for _, outpost_id in ipairs(outposts) do
		table.sort(buckets[outpost_id])
	end
	return buckets
end

-- Re-apply auto-region Sectors / ManagedOutposts after ReloadLua / empty stubs / region rev.
-- Always Voronoi across ALL tracked outposts (single-outpost assign inflated catchments).
local function lRefreshTrackedAutoRegions(root)
	if not Regions or not gv_Sectors then
		return 0
	end
	local outposts = {}
	for outpost_id in pairs(root.auto_regions or empty_table) do
		if type(outpost_id) == "string" and gv_Sectors[outpost_id] and gv_Sectors[outpost_id].Guardpost then
			outposts[#outposts + 1] = outpost_id
		end
	end
	table.sort(outposts)
	if #outposts == 0 then
		return 0
	end
	local buckets = lAssignSectorsToOutposts(outposts)
	local major_hq = lResolveMajorHQ()
	local refreshed = 0
	for _, outpost_id in ipairs(outposts) do
		local region = lCreateAutoRegion(outpost_id, buckets[outpost_id], major_hq or outpost_id)
		if region then
			root.auto_regions[outpost_id] = lRegionId(region)
			refreshed = refreshed + 1
		end
	end
	return refreshed
end

local function lApplyRegionRev(root)
	if (root.ai_region_rev or 0) >= AI_REGION_REV then
		return false
	end
	local n = lRefreshTrackedAutoRegions(root)
	root.ai_region_rev = AI_REGION_REV
	lLog(string.format(
		"applied AI region rev %s (radius=%s, refreshed=%d)",
		tostring(AI_REGION_REV),
		AUTO_REGION_RADIUS == false and "unbounded" or tostring(AUTO_REGION_RADIUS),
		n
	))
	return true
end

local g_JAZZ_NoMapsMissingSquadLogged = {}

-- COMPAT-005: Early alias scales with gear major (I→Early T1-only, II→T2, III→T3).
local function lResolveTieredLegionSquad()
	local major = lTierMajor(lGetLegionTier())
	local candidates
	if major >= 3 then
		candidates = { "LegionJAZZSquadT3", "LegionJAZZSquadT2", "LegionJAZZSquadT1_Early", "LegionJAZZSquadT1" }
	elseif major >= 2 then
		candidates = { "LegionJAZZSquadT2", "LegionJAZZSquadT1_Early", "LegionJAZZSquadT1" }
	else
		candidates = { "LegionJAZZSquadT1_Early", "LegionJAZZSquadT1" }
	end
	for _, id in ipairs(candidates) do
		if lHasEnemySquad(id) then
			return id
		end
	end
	return "LegionJAZZSquadT1_Early"
end

local function lExpandSquadAlias(squad_def_id)
	if squad_def_id == "LegionJAZZSquadT1_Early" then
		return lResolveTieredLegionSquad()
	end
	return squad_def_id
end

local function lRemapSquadId(squad_def_id)
	if not squad_def_id then
		return squad_def_id
	end
	-- Early is a real EnemySquad Id; still expand so gear major II/III can promote.
	if squad_def_id == "LegionJAZZSquadT1_Early" then
		return lResolveTieredLegionSquad()
	end
	local mapped = SQUAD_REMAP[squad_def_id]
	if mapped then
		mapped = lExpandSquadAlias(mapped)
		if lHasEnemySquad(mapped) then
			return mapped
		end
	end
	if lHasEnemySquad(squad_def_id) then
		return squad_def_id
	end
	-- Prefix heuristic for unlisted vanilla Legion/Thug satellite defs.
	local prefix_map = false
	if type(squad_def_id) == "string" then
		if string.find(squad_def_id, "Thug", 1, true) == 1 or string.find(squad_def_id, "Thugs", 1, true) == 1 then
			prefix_map = "LegionJAZZSquadT1_Early"
		elseif string.find(squad_def_id, "Legion", 1, true) == 1 then
			prefix_map = "LegionJAZZSquadT1_Early"
		end
	end
	if prefix_map then
		prefix_map = lExpandSquadAlias(prefix_map)
		if lHasEnemySquad(prefix_map) then
			if not g_JAZZ_NoMapsMissingSquadLogged[squad_def_id] then
				g_JAZZ_NoMapsMissingSquadLogged[squad_def_id] = true
				lLog("squad remap prefix " .. tostring(squad_def_id) .. " → " .. prefix_map)
			end
			return prefix_map
		end
	end
	local fallback = lPickExisting(ROLE_LISTS.attack)
	local fb = lExpandSquadAlias(fallback[1] or squad_def_id)
	if not g_JAZZ_NoMapsMissingSquadLogged[squad_def_id] then
		g_JAZZ_NoMapsMissingSquadLogged[squad_def_id] = true
		lLog("missing EnemySquadDef " .. tostring(squad_def_id) .. "; fallback " .. tostring(fb))
	end
	return fb
end

local function lRemapSquadList(list)
	if type(list) ~= "table" then
		return list
	end
	local out = {}
	for _, id in ipairs(list) do
		out[#out + 1] = lRemapSquadId(id)
	end
	return out
end

local function lUpgradeSectorSquadRefs(sector)
	if not sector then
		return
	end
	for _, field in ipairs({
		"EnemySquadsList",
		"StrongEnemySquadsList",
		"ExtraDefenderSquads",
		"EnemySquadsGarrisonList",
		"EnemySquadsPatroolList",
		"EnemySquadsReconList",
		"EnemySquadsQRFList",
		"InitialSquads",
	}) do
		if type(sector[field]) == "table" and #sector[field] > 0 then
			sector[field] = lRemapSquadList(sector[field])
		end
	end
end

local function lInstallGenerateEnemySquadWrapper()
	if rawget(_G, "g_JAZZ_NoMapsGenerateEnemySquadWrapped") then
		return
	end
	local base = rawget(_G, "GenerateEnemySquad")
	if type(base) ~= "function" then
		return
	end
	rawset(_G, "g_JAZZ_NoMapsGenerateEnemySquadWrapped", true)
	rawset(_G, "g_JAZZ_NoMapsBaseGenerateEnemySquad", base)
	function GenerateEnemySquad(squad_def_id, ...)
		if lShouldRun() then
			squad_def_id = lRemapSquadId(squad_def_id)
		end
		return g_JAZZ_NoMapsBaseGenerateEnemySquad(squad_def_id, ...)
	end
end

-- Ensure WorldFlip satellite lanes stay valid on vanilla geography under nomaps.
local function lInstallWorldFlipGuard()
	if rawget(_G, "g_JAZZ_NoMapsWorldFlipGuarded") then
		return
	end
	local base = rawget(_G, "SpawnWorldFlipAttackSquads")
	if type(base) ~= "function" then
		return
	end
	rawset(_G, "g_JAZZ_NoMapsWorldFlipGuarded", true)
	rawset(_G, "g_JAZZ_NoMapsBaseWorldFlip", base)
	function SpawnWorldFlipAttackSquads()
		if not lShouldRun() then
			return g_JAZZ_NoMapsBaseWorldFlip()
		end
		-- jazz WorldFlipSpawnUnits already uses vanilla sector IDs + jazz-units squad defs;
		-- re-install GenerateEnemySquad wrap then run (covers late WorldFlip after reload).
		lInstallGenerateEnemySquadWrapper()
		local ok, err = pcall(g_JAZZ_NoMapsBaseWorldFlip)
		if not ok then
			lLog("WorldFlip failed: " .. tostring(err))
		end
	end
end

local function lPickLootClass(pool, seed_key)
	local valid = {}
	for _, class in ipairs(pool or empty_table) do
		if lItemAllowed(class) then
			valid[#valid + 1] = class
		end
	end
	if #valid == 0 then
		return false
	end
	local idx = InteractionRand(#valid, seed_key) + 1
	return valid[idx]
end

local function lAddItemsToContainer(container, items)
	if not container or not items then
		return 0
	end
	local n = 0
	for _, item in ipairs(items) do
		if item and not lIsCutInventoryClass(item.class) then
			container:AddItem("Inventory", item)
			n = n + 1
		elseif item and DoneObject then
			DoneObject(item)
		end
	end
	return n
end

local function lInjectFromLootDef(container, loot_def_id, seed_key)
	local def = LootDefs and LootDefs[loot_def_id]
	if not def or not def.GenerateLoot then
		return 0
	end
	local items = {}
	def:GenerateLoot(container, container, InteractionRand(nil, seed_key), items)
	return lAddItemsToContainer(container, items)
end

local function lReplaceLegacyArmorItem(owner, slot_name, item)
	local new_id = item and ARMOR_REMAP[item.class]
	if not new_id or not lItemAllowed(new_id) or not owner then
		return false
	end
	local cond, maxc = item.Condition, item.MaxCondition
	owner:RemoveItem(slot_name, item)
	if DoneObject then
		DoneObject(item)
	end
	local neu = PlaceInventoryItem(new_id)
	if not neu then
		return false
	end
	if cond and maxc and maxc > 0 and neu.MaxCondition then
		neu.Condition = MulDivRound(neu.MaxCondition, cond, maxc)
	end
	if owner.CanAddItem and owner:CanAddItem(slot_name, neu) then
		owner:AddItem(slot_name, neu)
	else
		owner:AddItem("Inventory", neu)
	end
	return true
end

-- Replace Flak/Kevlar/HeavyArmor stubs (no JAZZ ArmorRating) with JazzArmor_*.
local function lSanitizeUnitArmor(unitdata)
	if not unitdata or not unitdata.ForEachItem then
		return 0
	end
	local to_replace = {}
	unitdata:ForEachItem(function(item, slot_name)
		if item and ARMOR_REMAP[item.class] then
			to_replace[#to_replace + 1] = { item = item, slot = slot_name }
		end
	end)
	local n = 0
	for _, entry in ipairs(to_replace) do
		if lReplaceLegacyArmorItem(unitdata, entry.slot, entry.item) then
			n = n + 1
		end
	end
	return n
end

-- Remove cut/disabled items; remap legacy armor stubs in vanilla map containers.
local function lScrubContainerCutItems(container)
	if not container or not container.ForEachItem then
		return 0
	end
	local removed = 0
	local to_remove = {}
	local to_remap = {}
	container:ForEachItem(function(item, slot_name)
		if not item then
			return
		end
		if lIsCutInventoryClass(item.class) then
			to_remove[#to_remove + 1] = { item = item, slot = slot_name }
		elseif ARMOR_REMAP[item.class] then
			to_remap[#to_remap + 1] = { item = item, slot = slot_name }
		end
	end)
	for _, entry in ipairs(to_remove) do
		container:RemoveItem(entry.slot, entry.item)
		removed = removed + 1
		if entry.item and DoneObject then
			DoneObject(entry.item)
		end
	end
	for _, entry in ipairs(to_remap) do
		if lReplaceLegacyArmorItem(container, entry.slot, entry.item) then
			removed = removed + 1
		end
	end
	return removed
end

local function lInjectContainerLoot()
	if not lShouldRun() or not gv_CurrentSectorId then
		return
	end
	local root = lEnsureState()
	local sector_key = gv_CurrentSectorId
	local containers = MapGet("map", "ItemContainer") or empty_table
	local scrubbed = 0
	for _, container in ipairs(containers) do
		if IsValid(container) then
			scrubbed = scrubbed + lScrubContainerCutItems(container)
		end
	end
	if scrubbed > 0 then
		lLog("scrubbed cut loot items=" .. scrubbed .. " in " .. tostring(sector_key))
	end
	if root.injected[sector_key] then
		return
	end
	root.injected[sector_key] = true

	local tier = lGetLegionTier()
	local packs = lGetLootPacksForTier(tier)
	local inject_cap = 0
	for _, pack in ipairs(packs) do
		inject_cap = inject_cap + pack.chance
	end

	local count = 0
	for i, container in ipairs(containers) do
		if not IsValid(container) then
			goto next_container
		end
		local handle = container.handle or i
		local inject_key = sector_key .. ":" .. tostring(handle)
		if root.injected[inject_key] then
			goto next_container
		end
		root.injected[inject_key] = true

		local roll = InteractionRand(100, "JAZZ_NoMapsLoot_" .. inject_key)
		local cum = 0
		local used_pack = false
		for _, pack in ipairs(packs) do
			cum = cum + pack.chance
			if roll < cum then
				local n = lInjectFromLootDef(container, pack.id, "JAZZ_NoMapsPack_" .. inject_key)
				if n > 0 then
					count = count + n
					used_pack = true
				end
				break
			end
		end
		-- Fallback if LootDefs not ready yet (same chance band as pack miss boundary).
		if not used_pack and roll < inject_cap then
			local fallback = lGetFallbackPoolsForTier(tier)
			local pool = fallback.ammo
			if roll >= (packs[1].chance + packs[2].chance + packs[3].chance) then
				pool = fallback.weapons
			elseif roll >= (packs[1].chance + packs[2].chance) then
				pool = fallback.armor
			elseif roll >= packs[1].chance then
				pool = fallback.common
			end
			local class = lPickLootClass(pool, "JAZZ_NoMapsFallback_" .. inject_key)
			if class then
				local item = PlaceInventoryItem(class)
				if item then
					if IsKindOf(item, "InventoryStack") then
						item.Amount = Max(1, InteractionRand(6, "JAZZ_NoMapsStack_" .. inject_key) + 2)
					end
					container:AddItem("Inventory", item)
					count = count + 1
				end
			end
		end
		::next_container::
	end
	if count > 0 then
		lLog("injected loot items=" .. count .. " in " .. tostring(sector_key) .. " tier=" .. tostring(tier))
	end
end


local function lPlaceCaliberAmmo(caliber, amount)
	if not caliber or not rawget(_G, "GetAmmosWithCaliber") then
		return false
	end
	local ammos = GetAmmosWithCaliber(caliber, "sort")
	if (not ammos or not ammos[1]) and GetAmmosWithCaliber then
		ammos = GetAmmosWithCaliber(caliber, "sorted")
	end
	local def = ammos and ammos[1]
	local ammo_id = def and (def.id or def.class)
	if type(ammo_id) ~= "string" or not lItemAllowed(ammo_id) then
		return false
	end
	local item = PlaceInventoryItem(ammo_id)
	if not item then
		return false
	end
	if IsKindOf(item, "InventoryStack") then
		local want = amount or 30
		local max_stacks = item.MaxStacks or want
		item.Amount = Max(1, Min(want, max_stacks))
	end
	return item
end

-- Drop cut/vanilla ammo; ensure each carried firearm caliber has a live JAZZ stack.
local function lSanitizeUnitAmmo(unitdata)
	if not unitdata or not unitdata.ForEachItem then
		return
	end
	-- Drop cut weapons (MP5/AR15/M4Commando stubs) before caliber pass.
	local cut_weapons = {}
	unitdata:ForEachItem(function(item, slot_name)
		if item and lIsCutInventoryClass(item.class) and IsKindOf(item, "Firearm") then
			cut_weapons[#cut_weapons + 1] = { item = item, slot = slot_name }
		end
	end)
	for _, entry in ipairs(cut_weapons) do
		unitdata:RemoveItem(entry.slot, entry.item)
	end
	local calibers = {}
	unitdata:ForEachItem(function(item)
		if IsKindOf(item, "Firearm") and item.Caliber then
			calibers[item.Caliber] = true
		end
	end)
	local to_remove = {}
	unitdata:ForEachItem(function(item, slot_name)
		if not IsKindOf(item, "Ammo") then
			return
		end
		local class = item.class
		local keep = item.Caliber and calibers[item.Caliber] and not lIsCutInventoryClass(class)
		if not keep then
			to_remove[#to_remove + 1] = { item = item, slot = slot_name }
		end
	end)
	for _, entry in ipairs(to_remove) do
		unitdata:RemoveItem(entry.slot, entry.item)
	end
	for caliber in sorted_pairs(calibers) do
		local has = false
		unitdata:ForEachItem(function(item)
			if IsKindOf(item, "Ammo") and item.Caliber == caliber and not lIsCutInventoryClass(item.class) then
				has = true
			end
		end)
		if not has then
			local ammo = lPlaceCaliberAmmo(caliber, 30)
			if ammo then
				unitdata:AddItem("Inventory", ammo)
			end
		end
	end
	-- Reload firearms if magazine ammo is missing/wrong caliber.
	unitdata:ForEachItem(function(item)
		if not IsKindOf(item, "Firearm") or not item.Caliber or not item.Reload then
			return
		end
		local mag = item.ammo
		if mag and mag.Caliber == item.Caliber and not lIsCutInventoryClass(mag.class) then
			return
		end
		local stack
		unitdata:ForEachItem(function(cand)
			if IsKindOf(cand, "Ammo") and cand.Caliber == item.Caliber then
				stack = stack or cand
			end
		end)
		if stack then
			item:Reload(stack, "suspend_fx")
		end
	end)
end

local function lStripInventory(inv)
	if not inv or not inv.ForEachItem then
		return
	end
	local doomed = {}
	inv:ForEachItem(function(item, slot_name)
		doomed[#doomed + 1] = { item = item, slot = slot_name }
	end)
	for _, entry in ipairs(doomed) do
		inv:RemoveItem(entry.slot, entry.item)
	end
end

local function lIsCombatFirearm(item)
	if not item then
		return false
	end
	-- Match jazz System_OR_Unit: FlareGun/HeavyWeapon are not usable "Firearm" combat kits.
	if not IsKindOf(item, "Firearm") then
		return false
	end
	if IsKindOfClasses(item, "HeavyWeapon", "FlareGun") then
		return false
	end
	return true
end

-- Hard guarantee after CSE: Rifleman/Ambusher primary can miss; FlareHandgun must not count.
local function lEnsureFirearm(inv)
	if not inv or not inv.ForEachItem then
		return false
	end
	local has = false
	inv:ForEachItem(function(item)
		if lIsCombatFirearm(item) then
			has = true
		end
	end)
	if has then
		return false
	end
	local gun_class = "SKS"
	if not lItemAllowed(gun_class) then
		gun_class = "AK47"
	end
	if not lItemAllowed(gun_class) then
		return false
	end
	local gun = PlaceInventoryItem(gun_class)
	if not gun then
		return false
	end
	if inv.AddItem then
		-- Prefer handheld; fall back to backpack Inventory.
		local left = inv:AddItem("Handheld A", gun)
		if not left then
			inv:AddItem("Inventory", gun)
		end
	end
	if gun.Caliber then
		local ammo = lPlaceCaliberAmmo(gun.Caliber, 30)
		if ammo then
			inv:AddItem("Inventory", ammo)
			if gun.Reload then
				gun:Reload(ammo, "suspend_fx")
			end
		end
	end
	return true
end

local function lRegearInventory(inv, seed)
	if not inv then
		return 0
	end
	lStripInventory(inv)
	if inv.CreateStartingEquipment then
		inv:CreateStartingEquipment(seed)
	end
	lSanitizeUnitAmmo(inv)
	if lEnsureFirearm(inv) then
		lLog("ensured fallback firearm on " .. tostring(inv.class or inv.session_id or "?"))
	end
	return lSanitizeUnitArmor(inv)
end

-- SetQuestVar runs QuestTCEEvaluation; during early NewGame `Groups` can still be boolean → assert.
local function lQuestVarSafeSet(quest, var_id, value)
	if not quest or var_id == nil then
		return false
	end
	if type(rawget(_G, "Groups")) == "table" and SetQuestVar then
		SetQuestVar(quest, var_id, value)
		return true
	end
	rawset(quest, var_id, value)
	return true
end

local function lEnsureLegionTierRawset()
	if rawget(_G, "JAZZ_UpdateLegionTierForNoMaps") then
		JAZZ_UpdateLegionTierForNoMaps()
	end
	-- Loot QuestIsVariableNum uses rawget; metatable default 11 is invisible until value is set.
	local quest = QuestGetState and QuestGetState("JAZZ_LegionTier")
	if quest and rawget(quest, "JAZZ_Legion_Tier") == nil then
		lQuestVarSafeSet(quest, "JAZZ_Legion_Tier", 11)
		lLog("rawset JAZZ_Legion_Tier=11 for loot conditions")
	end
end

local function lRemapUnitDataSession(session_id, unitdata)
	if not unitdata or not session_id or not CreateUnitData then
		return false
	end
	local old_class = unitdata.class
	local new_id = lRemapUnitTemplate(old_class, "JAZZ_NoMapsUnit_" .. tostring(session_id))
	if not new_id then
		return false
	end
	-- CreateUnitData resets Squad; preserve membership so Traveling/ops don't see squad=false.
	local prev_squad = unitdata.Squad
	if (not prev_squad or not (gv_Squads and gv_Squads[prev_squad])) and gv_Squads then
		for sid, squad in pairs(gv_Squads) do
			if type(squad) == "table" and table.find(squad.units, session_id) then
				prev_squad = sid
				break
			end
		end
	end
	local seed = unitdata.randomization_seed
		or InteractionRand(nil, "JAZZ_NoMapsRemapSeed_" .. tostring(session_id))
	if unitdata.delete then
		unitdata:delete()
	end
	gv_UnitData[session_id] = false
	local ok, err = pcall(CreateUnitData, new_id, session_id, seed)
	local fresh = ok and gv_UnitData[session_id]
	if not fresh then
		lLog(string.format("unit remap %s→%s failed: %s", tostring(old_class), tostring(new_id), tostring(err)))
		return false
	end
	if prev_squad and gv_Squads and gv_Squads[prev_squad] then
		fresh.Squad = prev_squad
		local live = g_Units and g_Units[session_id]
		if live then
			live.Squad = prev_squad
		end
	end
	return true
end

-- Repair UnitData.Squad when still listed in SatelliteSquad.units (legacy remap orphans).
local function lRepairOrphanSquadLinks()
	if not gv_Squads or not gv_UnitData then
		return 0
	end
	local fixed = 0
	for _, squad in sorted_pairs(gv_Squads) do
		local squad_id = squad and squad.UniqueId
		if squad_id then
			for _, session_id in ipairs(squad.units or empty_table) do
				local ud = gv_UnitData[session_id]
				if type(ud) == "table" and (not ud.Squad or not gv_Squads[ud.Squad]) then
					ud.Squad = squad_id
					local live = g_Units and g_Units[session_id]
					if live then
						live.Squad = squad_id
					end
					fixed = fixed + 1
				end
			end
		end
	end
	if fixed > 0 then
		lLog("repaired UnitData.Squad links=" .. tostring(fixed))
	end
	return fixed
end

local function lRemapEnemyUnitTemplates()
	if not gv_UnitData then
		return 0
	end
	local to_remap = {}
	for session_id, unitdata in sorted_pairs(gv_UnitData) do
		if type(unitdata) == "table"
			and not unitdata.IsMercenary
			and unitdata.IsDead and not unitdata:IsDead()
			and unitdata.Affiliation
			and (unitdata.Affiliation == "Legion" or unitdata.Affiliation == "Thugs")
			and lMatchUnitFamily(unitdata.class)
		then
			to_remap[#to_remap + 1] = session_id
		end
	end
	local count = 0
	local root = lEnsureState()
	for _, session_id in ipairs(to_remap) do
		local unitdata = gv_UnitData[session_id]
		if unitdata and lRemapUnitDataSession(session_id, unitdata) then
			count = count + 1
			root.geared[session_id] = nil
		end
	end
	lRepairOrphanSquadLinks()
	if count > 0 then
		lLog("remapped UnitData templates=" .. count)
	end
	return count
end

local function lInstallCreateUnitDataWrapper()
	if rawget(_G, "JAZZ_NoMaps_CreateUnitDataWrapped") then
		return
	end
	if type(CreateUnitData) ~= "function" then
		return
	end
	rawset(_G, "JAZZ_NoMaps_BaseCreateUnitData", CreateUnitData)
	rawset(_G, "JAZZ_NoMaps_CreateUnitDataWrapped", true)
	CreateUnitData = function(unit_template, session_id, ...)
		if lShouldRun() and type(unit_template) == "string" then
			local remapped = lRemapUnitTemplate(
				unit_template,
				"JAZZ_NoMapsCreate_" .. tostring(session_id or unit_template)
			)
			if remapped then
				unit_template = remapped
			end
		end
		return JAZZ_NoMaps_BaseCreateUnitData(unit_template, session_id, ...)
	end
end

local function lInstallUnitMarkerWrapper()
	if rawget(_G, "JAZZ_NoMaps_UnitMarkerWrapped") then
		return
	end
	if not UnitMarker or type(UnitMarker.SpawnObjects) ~= "function" then
		return
	end
	rawset(_G, "JAZZ_NoMaps_BaseUnitMarkerSpawnObjects", UnitMarker.SpawnObjects)
	rawset(_G, "JAZZ_NoMaps_UnitMarkerWrapped", true)
	function UnitMarker:SpawnObjects(...)
		if lShouldRun() and self.UnitDataSpawnDefs then
			for _, entry in ipairs(self.UnitDataSpawnDefs) do
				if entry and type(entry.UnitDataDefId) == "string" then
					local remapped = lRemapUnitTemplate(
						entry.UnitDataDefId,
						"JAZZ_NoMapsMarker_" .. tostring(entry.UnitDataDefId)
					)
					if remapped then
						entry.UnitDataDefId = remapped
					end
				end
			end
		end
		return JAZZ_NoMaps_BaseUnitMarkerSpawnObjects(self, ...)
	end
end

local function lRefreshEnemyLoadouts()
	if not gv_Squads then
		return
	end
	lEnsureLegionTierRawset()
	lRemapEnemyUnitTemplates()
	local root = lEnsureState()
	local remapped = 0
	-- sorted_pairs: gv_Squads is a sparse id-map; ipairs stops at the first hole.
	for _, squad in sorted_pairs(gv_Squads) do
		if type(squad) ~= "table" or type(squad.units) ~= "table" then
			goto next_squad
		end
		for _, unit_id in ipairs(squad.units or empty_table) do
			if root.geared[unit_id] == GEAR_REV then
				goto next_unit
			end
			local unitdata = gv_UnitData and gv_UnitData[unit_id]
			if unitdata
				and not unitdata.IsMercenary
				and unitdata.IsDead and not unitdata:IsDead()
				and unitdata.Affiliation
				and (unitdata.Affiliation == "Legion"
					or unitdata.Affiliation == "Army"
					or unitdata.Affiliation == "Adonis"
					or unitdata.Affiliation == "Rebel"
					or unitdata.Affiliation == "Thugs")
			then
				local already = root.geared[unit_id]
				local seed = unitdata.randomization_seed
				-- Full regear when never geared or still on older GEAR_REV (unarmed lock).
				if not already or already < GEAR_REV then
					local unit = g_Units and g_Units[unit_id]
					if unit and unit.ForEachItem then
						remapped = remapped + lRegearInventory(unit, seed)
					end
					remapped = remapped + lRegearInventory(unitdata, seed)
				else
					-- Should not reach: geared==GEAR_REV skipped above.
					remapped = remapped + lSanitizeUnitArmor(unitdata)
				end
				root.geared[unit_id] = GEAR_REV
			end
			::next_unit::
		end
		::next_squad::
	end
	if remapped > 0 then
		lLog("remapped legacy armor pieces=" .. remapped)
	end
end


local function lApplyEconomyRev(root)
	if (root.ai_economy_rev or 0) >= AI_ECONOMY_REV then
		return
	end
	-- Top up outpost/major manpower so garrison (size_min 25) can spawn after old 12-cap saves.
	if rawget(_G, "gv_JAZZ_LegionAI") and type(gv_JAZZ_LegionAI) == "table" then
		local ai = gv_JAZZ_LegionAI
		for sector_id, outpost in sorted_pairs(ai.outposts or empty_table) do
			if type(outpost) == "table" then
				local rid = outpost.region_id
				if rid and type(rid) == "string" and string.find(rid, "JAZZ_Auto_", 1, true) == 1 then
					outpost.manpower = Max(outpost.manpower or 0, 40)
					outpost.money = Max(outpost.money or 0, 8000)
				end
			end
		end
		if ai.major then
			ai.major.manpower = Max(ai.major.manpower or 0, 120)
		end
	end
	root.ai_economy_rev = AI_ECONOMY_REV
	lLog("applied AI economy rev " .. tostring(AI_ECONOMY_REV))
end

local function lCountHealthyAutoRegions()
	local n = 0
	for region_id, region in pairs(Regions or empty_table) do
		if type(region_id) == "string"
			and string.find(region_id, "JAZZ_Auto_", 1, true) == 1
			and region
			and region.LegionAIEnabled
			and type(region.ManagedOutposts) == "table"
			and #region.ManagedOutposts > 0
		then
			n = n + 1
		end
	end
	return n
end

local function lCountTrackedAutoRegions(root)
	local n = 0
	for _ in pairs(root.auto_regions or empty_table) do
		n = n + 1
	end
	return n
end

function JAZZ_NoMapsBootstrap(force)
	local root = lEnsureState()
	if not lShouldRun() then
		root.active = false
		return false
	end
	if not gv_Sectors then
		return false
	end
	-- Soft path only when mainland auto-regions are still healthy.
	-- Empty auto_regions + bootstrapped=true was a regression: InitSatelliteView
	-- returned early and left only ErnieIsland remnant (HQ=false).
	if root.bootstrapped and not force then
		local healthy = lCountHealthyAutoRegions()
		local tracked = lCountTrackedAutoRegions(root)
		if healthy > 0 and tracked > 0 then
			root.active = true
			lInstallGenerateEnemySquadWrapper()
			lInstallWorldFlipGuard()
			lInstallCreateUnitDataWrapper()
			lInstallUnitMarkerWrapper()
			lRefreshTrackedAutoRegions(root)
			lApplyRegionRev(root)
			lRepairOrphanSquadLinks()
			local major_hq = lResolveMajorHQ()
			if rawget(_G, "JAZZ_LegionAIEnsureState") then
				JAZZ_LegionAIEnsureState()
			end
			if major_hq and rawget(_G, "JAZZ_LegionAIForceMajorHQ") then
				JAZZ_LegionAIForceMajorHQ(major_hq)
			elseif major_hq and rawget(_G, "gv_JAZZ_LegionAI") and type(gv_JAZZ_LegionAI) == "table" then
				gv_JAZZ_LegionAI.major = gv_JAZZ_LegionAI.major or {}
				gv_JAZZ_LegionAI.major.hq_sector = major_hq
			end
			lEnsureLegionTierRawset()
			return true
		end
		lLog(string.format(
			"bootstrap re-run: healthy_auto=%d tracked=%d",
			healthy,
			tracked
		))
		root.bootstrapped = false
	end

	root.active = true
	lInstallGenerateEnemySquadWrapper()
	lInstallWorldFlipGuard()
	lInstallCreateUnitDataWrapper()
	lInstallUnitMarkerWrapper()
	lDisableMapsOnlyRegions(root)

	local major_hq = lResolveMajorHQ()
	local managed = lManagedOutpostSet()
	local all_posts = lCollectGuardposts()
	if #all_posts == 0 then
		lLog("bootstrap deferred: no surface Guardposts yet")
		return false
	end
	local unmanaged = {}
	for _, sector_id in ipairs(all_posts) do
		if not managed[sector_id] then
			unmanaged[#unmanaged + 1] = sector_id
		end
		lWireGuardpostSquadLists(gv_Sectors[sector_id])
		lUpgradeSectorSquadRefs(gv_Sectors[sector_id])
	end

	for _, sector in sorted_pairs(gv_Sectors) do
		if sector and (sector.Side == "enemy1" or sector.Side == "enemy2" or sector.InitialSquads) then
			lUpgradeSectorSquadRefs(sector)
		end
	end

	-- If disable left nothing managed but auto stubs are empty, treat all posts as unmanaged.
	if #unmanaged == 0 and lCountHealthyAutoRegions() == 0 then
		unmanaged = table.copy(all_posts)
	end

	if #unmanaged > 0 then
		local buckets = lAssignSectorsToOutposts(unmanaged)
		for _, outpost_id in ipairs(unmanaged) do
			local region = lCreateAutoRegion(outpost_id, buckets[outpost_id], major_hq or outpost_id)
			if region then
				root.auto_regions[outpost_id] = lRegionId(region)
			end
		end
		lLog(string.format(
			"auto regions: %d guardposts; MajorHQ=%s",
			#unmanaged,
			tostring(major_hq or "per-outpost")
		))
	else
		lLog("no unmanaged guardposts after maps-only disable")
	end

	-- COMPAT-006: always re-Voronoi tracked auto-regions (force path skipped soft refresh
	-- when every Guardpost was already managed → stale huge Sectors survived).
	lRefreshTrackedAutoRegions(root)
	root.ai_region_rev = AI_REGION_REV

	for sector_id in pairs(managed) do
		lWireGuardpostSquadLists(gv_Sectors[sector_id])
		lUpgradeSectorSquadRefs(gv_Sectors[sector_id])
	end

	-- Re-collect managed set after auto-regions created.
	managed = lManagedOutpostSet()
	for sector_id in pairs(managed) do
		lWireGuardpostSquadLists(gv_Sectors[sector_id])
		lUpgradeSectorSquadRefs(gv_Sectors[sector_id])
	end

	-- Keep bootstrapped=false until AI seed finishes so InitSatelliteView can retry after errors.
	if rawget(_G, "JAZZ_LegionAIEnsureState") then
		JAZZ_LegionAIEnsureState()
	end
	-- COMPAT-004: force Major HQ to vanilla camp (overwrite Ernie B28 latch).
	if major_hq and rawget(_G, "JAZZ_LegionAIForceMajorHQ") then
		JAZZ_LegionAIForceMajorHQ(major_hq)
		lLog("forced Major HQ=" .. tostring(major_hq))
	elseif major_hq and rawget(_G, "gv_JAZZ_LegionAI") and type(gv_JAZZ_LegionAI) == "table" then
		gv_JAZZ_LegionAI.major = gv_JAZZ_LegionAI.major or {}
		gv_JAZZ_LegionAI.major.hq_sector = major_hq
		lLog("forced Major HQ (fallback)=" .. tostring(major_hq))
	end
	if rawget(_G, "JAZZ_LegionAIAdoptOutpostDefenders") then
		local n = JAZZ_LegionAIAdoptOutpostDefenders()
		if n and n > 0 then
			lLog("adopted outpost defenders as garrison=" .. tostring(n))
		end
	end
	if rawget(_G, "JAZZ_LegionAISeedPoiEconomy") then
		local ok, n = pcall(JAZZ_LegionAISeedPoiEconomy, { money = 1500, recruits = 10 })
		if not ok then
			lLog("SeedPoiEconomy failed: " .. tostring(n))
		elseif n and n > 0 then
			lLog("seeded POI economy entries=" .. tostring(n))
		end
	end
	lApplyEconomyRev(root)
	-- Tier rawset BEFORE gear refresh so Rifleman_Firearm quest conditions see JAZZ_Legion_Tier.
	lEnsureLegionTierRawset()
	lRefreshEnemyLoadouts()
	lRepairOrphanSquadLinks()
	local healthy = lCountHealthyAutoRegions()
	if healthy <= 0 then
		lLog("bootstrap incomplete: no healthy JAZZ_Auto_* regions; will retry")
		root.bootstrapped = false
		return false
	end
	root.bootstrapped = true
	return true
end

function JAZZ_NoMapsIsActive()
	return lShouldRun() and lEnsureState().active
end

-- Legacy alias for COMPAT-001 callers / diagnostics (predeclared above; use rawset).
rawset(_G, "JAZZ_StandaloneNoMapsBootstrap", JAZZ_NoMapsBootstrap)
rawset(_G, "JAZZ_StandaloneNoMapsIsActive", JAZZ_NoMapsIsActive)

function OnMsg.ModsReloaded()
	if lShouldRun() then
		lInstallGenerateEnemySquadWrapper()
		lInstallWorldFlipGuard()
		lInstallCreateUnitDataWrapper()
		lInstallUnitMarkerWrapper()
	end
end

function OnMsg.NewGame()
	if not lShouldRun() then
		return
	end
	local root = lEnsureState()
	root.bootstrapped = false
	root.injected = {}
	root.auto_regions = {}
	root.geared = {}
	root.disabled_regions = {}
	JAZZ_NoMapsBootstrap(true)
end

function OnMsg.LoadGame()
	if not lShouldRun() then
		return
	end
	local root = lEnsureState()
	root.bootstrapped = false
	JAZZ_NoMapsBootstrap(true)
end

function OnMsg.InitSatelliteView()
	if not lShouldRun() then
		return
	end
	JAZZ_NoMapsBootstrap(false)
	lRefreshEnemyLoadouts()
end

function OnMsg.ExplorationStart()
	if not lShouldRun() then
		return
	end
	JAZZ_NoMapsBootstrap(false)
	lRefreshEnemyLoadouts()
	lInjectContainerLoot()
end

function OnMsg.CombatStart()
	if not lShouldRun() then
		return
	end
	lRefreshEnemyLoadouts()
	lInjectContainerLoot()
end
