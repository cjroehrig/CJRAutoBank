-- boilerplate for each source file to encapsulate everything in CJRAB:
if CJRAB == nil then CJRAB = {} end
local CJRAB = CJRAB

-- NB: this is loaded first, so no references to anything else!

-- these can be toggled via slashcommands (see SlashCommands.lua)
CJRAB.DryRun		= true			-- don't do any transfers; just show them
CJRAB.Logging		= true			-- log all inventory in/out
CJRAB.Debug			= false			-- log debug messages

-- for debugging:
CJRAB.NoQueue		= false			-- don't add to TransferQueue

--=============================================================================
-- CHARACTER DEFINITIONS

-- These must be in the SAME order as your character selection screen
-- use '/dumpcharraw all' to get the correct indexes
local C_Charlotte		= 1
local C_Calliope		= 2
local C_Buffy			= 3
local C_Gareth			= 4
local C_Freddy			= 5
local C_Kelvin			= 6

-- Enable Auto Banking for chars
CJRAB.CharsEnabled = {
	[C_Charlotte]		= true,
	[C_Calliope]		= true,
	[C_Buffy]			= true,
	[C_Gareth]			= true,
	[C_Freddy]			= true,
	[C_Kelvin]			= true
}

--=============================================================================
-- Config for current state

-- Set to true if you own Summerset (Jewelcrafting)
CJRAB.HasJewelcrafting = true

-- Current CRAFTER Crafting Ranks:
-- NB: Rank is the level of the primary ability for that Craft
-- Raw mats at this level and above will stay on the ROLE_CRAFTER;
-- mats below this level will be sent to LOWMATS except for
-- mats at ALTCraftRank which stay in the bank.
-- Best way to proceed is to rank-up your main (crafter) as soon as you
-- start getting nodes for the next tier.
-- Since 50% of nodes are based on your level and 50% are based on your rank,
-- this ensures that you are only ever collecting one type of node mat.
-- Wait with your ALTs until they run out of writ mats for the previous rank
-- and then rank-up all ALTs together, and update their rank below.
CJRAB.CrafterRank = {
	[CRAFTING_TYPE_BLACKSMITHING]		= 10,		-- 1
		-- Keen Eye 1
		-- Extraction 3
		-- Research 0
		-- Expertise 0
	[CRAFTING_TYPE_CLOTHIER]			= 10,		-- 2
		-- Keen Eye 1
		-- Extraction 3
		-- Research 0
		-- Expertise 0
	[CRAFTING_TYPE_ENCHANTING]			= 10,		-- 3
		-- Improvement 4
	[CRAFTING_TYPE_ALCHEMY]				= 7,		-- 4
		-- Keen Eye 1
	[CRAFTING_TYPE_PROVISIONING]		= 6,		-- 5
		-- Quality 4
	[CRAFTING_TYPE_WOODWORKING]			= 10,		-- 6
		-- Keen Eye 1
		-- Extraction 3
		-- Research 0
		-- Expertise 0
	[CRAFTING_TYPE_JEWELRYCRAFTING]		= 5,		-- 7
		-- Keen Eye 1
		-- Extraction 3
		-- Research 0
		-- Expertise 0
}

-- Current ALT Crafting Ranks
-- NB: for all alts; they should rank-up in lock-step for a given craft.
-- mats < these ranks will be sent to ROLE_LOWMATS
-- NB: numbers here are the ones displayed for the proficiency ability
CJRAB.ALTCraftRank = {
	[CRAFTING_TYPE_BLACKSMITHING]		= 1,		-- 1
	[CRAFTING_TYPE_CLOTHIER]			= 1,		-- 2
	[CRAFTING_TYPE_ENCHANTING]			= 10,		-- 3
	[CRAFTING_TYPE_ALCHEMY]				= 6,		-- 4
		-- NB: keep here at 6 so Cloud Mist stays in bank; ALTs are really 7/8
	[CRAFTING_TYPE_PROVISIONING]		= 6,		-- 5
	[CRAFTING_TYPE_WOODWORKING]			= 1,		-- 6
	[CRAFTING_TYPE_JEWELRYCRAFTING]		= 1,		-- 7
}
-- Enchanting Hirelings3: By,Cw,Kj
-- Chef/Brewer3: Fj

-- XXX: ALT 2024Aug30 SAVED: ENCHANTING=9, ALC=6?, Prov=5,JC=2, *=1
-- XXX: ALT 2024Oct10 SAVED: ENCHANTING=10, ALC=7, Prov=2,JC=2, *=1
-- XXX: ALT 2024Nov20 SAVED: ENCHANTING=10, ALC=7, Prov=2,JC=1, *=1


-- Crafting deconstruct (DC) distribution: If true, distribute DC items to the
-- lowest-ranked ALT; otherwise always send them to ROLE_CRAFTER.
-- (unresearched items always go to ROLE_RESEARCH).
-- (Also see CJRAB.CrafterQualityDC below).
CJRAB.ALTCraftDistribute = {
	[CRAFTING_TYPE_BLACKSMITHING]		= true,			-- 1
	[CRAFTING_TYPE_CLOTHIER]			= true,			-- 2
	[CRAFTING_TYPE_ENCHANTING]			= true,			-- 3
	[CRAFTING_TYPE_ALCHEMY]				= true,			-- 4
	[CRAFTING_TYPE_PROVISIONING]		= true,			-- 5
	[CRAFTING_TYPE_WOODWORKING]			= true,			-- 6
	[CRAFTING_TYPE_JEWELRYCRAFTING]		= true,			-- 7
}
-- Set to true to distribute raw mats to the ROLE_CRAFTER
-- (otherwise they are just ignored)
CJRAB.DistribRawMats					= true

-- patterns for which characters take surveys and treasure maps:
-- NB: These override ROLE_SURVEYS
-- NB: ROLE_QUESTER character has precedence.
CJRAB.CharSurveys = {
	[C_Charlotte]		= {
		----- Daggerfall Covenant
		"Stros M'Kai",
		"Betnikh",
		"Glenumbra",
		"Stormhaven",
		"Rivenspire",
		"Alik",
		"Bangkorai",
		----- Alteri Dominion
		"Khenarthi's Roost",			-- XXX: TEMP?  Just the CE?
		"Auridon",
		"Grahtwood",
		"Greenshade",
		"Malabal",
		"Reaper",
		----- Ebonhart Pact
--		"Bleakrock",
--		"Bal Foyen",
		----- Common & DLC
		"Coldharbour",
		"Craglorn",
		"Hew's Bane",
		"Gold Coast",
		"Dominion",				-- TEMP: reward treasure map coffer
		"Pact",					-- TEMP: reward treasure map coffer
		},
	[C_Calliope]		= {},
	[C_Buffy]			= {
		"Alchemist",
	},
	[C_Gareth]			= {},
	[C_Freddy]			= {},
	[C_Kelvin]			= {
		"Jewelry",
		"Enchanter",
	},
}

-- Set to true to mark any unused (non-writ) ingredients as junk
-- instead of sending to ROLE_INGREDIENT hoard
CJRAB.JunkUnusedIngredients = false

-- Set to true to keep racial writ style mats in the bank.
-- Otherwise they are distributed to alts according to race.
-- (Only applies to style mats marked as writs).
CJRAB.WritStyleMatsInBank = true

-- If all toons have equal rank and chance at DCing for quality mats, then set
-- to false and quality items will be sent to the toon of lowest craft level.
-- Otherwise (e.g. if your CRAFTER has Extraction skills), set to true to
-- send all "quality" (> green/FINE) items to ROLE_CRAFTER for deconstruction.
-- (NB: this only applies to items without researchable traits for the
-- ROLE_RESEARCH toon [requires the CraftStore addon])
CJRAB.CrafterQualityDC = true

-- Bank any CP160 Epic+ gear instead of sending it for DC
CJRAB.BankCP160Gear = false

-- store researchable items (for the ROLE_RESEARCH toon) in the bank instead
-- of sending them to that toon.
CJRAB.ResearchablesInBank = true


--=============================================================================
-- FCO ItemSaver Dynamic Icons

--  Use /dumpfcoicons to get a list of all icons and their indexes
--  or use /zgoo FCOIS to inspect LAMiconsList to get the index for icons
--  custom/dynamic icons start at [13]

-- These Dynamic icons are required:
CJRAB.FCO_ICON_RESERVED			= 13
CJRAB.FCO_ICON_WRITMATS			= 14

CJRAB.FCO_ICON_MIN				= 13
CJRAB.FCO_ICON_MAX				= 14


--=============================================================================
-- ROLE DEFINITIONS

local C_MAIN			= C_Charlotte	-- main char (all others are alts)


CJRAB.ROLE_QUESTER		= C_MAIN		-- surveys/treasure maps for CurrZone
CJRAB.ROLE_CRAFTER		= C_MAIN		-- crafting mats, some style mats
CJRAB.ROLE_RESEARCH		= C_MAIN		-- who is doing crafting research
CJRAB.ROLE_MONEY		= C_MAIN		-- hoards (most of) the money
CJRAB.ROLE_LURE			= C_MAIN		-- fishing lures
CJRAB.ROLE_RECIPE		= C_MAIN		-- learns all unknown recipes
CJRAB.ROLE_FURNISHING	= C_MAIN		-- furnishings hoard
CJRAB.ROLE_SOULGEM		= C_MAIN		-- empty soul gem filler
CJRAB.ROLE_COLLECTOR	= C_MAIN		-- collector of trophies, fragments, etc

CJRAB.ROLE_ALCHEMY		= nil			-- alchemy hoard (bank)
CJRAB.ROLE_ENCHANT		= nil			-- enchant hoard (bank)

CJRAB.ROLE_ARCHIVE		= C_Calliope	-- Archived items (marked with reserve)
CJRAB.ROLE_STYLES		= C_Buffy		-- (non-writ) style mats
CJRAB.ROLE_COSTUMES		= C_Freddy		-- costumes, disguises, clothes
CJRAB.ROLE_TRAITS		= C_Buffy		-- trait mats
CJRAB.ROLE_SURVEYS		= C_Gareth		-- surveys/maps for non-current zones
CJRAB.ROLE_CROWN		= C_Calliope	-- crown items

--CJRAB.ROLE_EPIC			= C_Freddy		-- epic/rare mats
CJRAB.ROLE_EPIC			= nil		-- epic/rare mats go to bank

CJRAB.ROLE_INGREDIENTS	= C_Freddy		-- unused food/drink ingredients hoard
CJRAB.ROLE_LOWMATS		= C_Kelvin		-- outleveled crafting mats

-- OVERFLOW ROLES (more than BANK_STACKLIMIT in bank)
CJRAB.ROLE_OVRFLW_BLACKSMITHING		= C_Freddy
CJRAB.ROLE_OVRFLW_CLOTHIER			= C_Calliope
CJRAB.ROLE_OVRFLW_ENCHANTING		= C_Kelvin
CJRAB.ROLE_OVRFLW_ALCHEMY			= C_Kelvin
CJRAB.ROLE_OVRFLW_PROVISIONING		= C_Kelvin
CJRAB.ROLE_OVRFLW_WOODWORKING		= C_Gareth
CJRAB.ROLE_OVRFLW_JEWELRYCRAFTING	= C_Freddy
-- Maximum number of full stacks to keep in bank before OVRFLW
CJRAB.BANK_STACKLIMIT = {
	[CRAFTING_TYPE_BLACKSMITHING]		= 1,			-- 1
	[CRAFTING_TYPE_CLOTHIER]			= 1,			-- 2
	[CRAFTING_TYPE_ENCHANTING]			= 1,			-- 3
	[CRAFTING_TYPE_ALCHEMY]				= 1,			-- 4
	[CRAFTING_TYPE_PROVISIONING]		= 1,			-- 5
	[CRAFTING_TYPE_WOODWORKING]			= 1,			-- 6
	[CRAFTING_TYPE_JEWELRYCRAFTING]		= 1,			-- 7
}
