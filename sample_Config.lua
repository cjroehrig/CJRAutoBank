-- boilerplate for each source file to encapsulate everything in CJRAB:
if CJRAB == nil then CJRAB = {} end
local CJRAB = CJRAB

-- NB: this is loaded first, so no references to anything else!

-- these can be toggled via slashcommands (see SlashCommands.lua)
CJRAB.DryRun		= true			-- don't do any transfers; just show them
CJRAB.Logging		= true			-- log all inventory in/out
CJRAB.Debug			= false			-- log debug messages

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

-- current crafting ranks for all alts
-- NB: they must rank-up in lock-step for a given craft
CJRAB.ALTCraftRank = {
	[CRAFTING_TYPE_BLACKSMITHING]		= 3,		-- 1
	[CRAFTING_TYPE_CLOTHIER]			= 3,		-- 2
	[CRAFTING_TYPE_ENCHANTING]			= 3,		-- 3
	[CRAFTING_TYPE_ALCHEMY]				= 2,		-- 4
	[CRAFTING_TYPE_PROVISIONING]		= 4,		-- 5
	[CRAFTING_TYPE_WOODWORKING]			= 4,		-- 6
	[CRAFTING_TYPE_JEWELRYCRAFTING]		= 0,		-- 7
}

-- Crafting mat distribution
-- If true, distribute low quality (< green) craft mats to the
-- lowest-ranked ALT; otherwise always send them to ROLE_CRAFTER.
-- (unresearched items always go to ROLE_RESEARCH).
CJRAB.ALTCraftDistribute = {
	[CRAFTING_TYPE_BLACKSMITHING]		= true,			-- 1
	[CRAFTING_TYPE_CLOTHIER]			= true,			-- 2
	[CRAFTING_TYPE_ENCHANTING]			= true,			-- 3
	[CRAFTING_TYPE_ALCHEMY]				= true,			-- 4
	[CRAFTING_TYPE_PROVISIONING]		= true,			-- 5
	[CRAFTING_TYPE_WOODWORKING]			= true,			-- 6
	[CRAFTING_TYPE_JEWELRYCRAFTING]		= false,		-- 7
}

-- zones for which characters take surveys and treasure maps:
CJRAB.CharZones = {
	[C_Charlotte]		= {
		"Glenumbra",
		"Stormhaven",
		},
	[C_Calliope]		= {},
	[C_Buffy]			= {},
	[C_Gareth]			= {},
	[C_Freddy]			= {},
	[C_Kelvin]			= {},
}

-- Set to true to mark any unused (non-writ) ingredients as junk
-- instead of sending to ROLE_INGREDIENT hoard
CJRAB.JunkUnusedIngredients = false

-- Set to true to keep racial writ style mats in the bank.
-- Otherwise they are distributed to alts according to race.
-- (Only applies to style mats marked as writs).
CJRAB.WritStyleMatsInBank = true

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
CJRAB.ROLE_ALCHEMY		= C_MAIN		-- alchemy hoard
CJRAB.ROLE_RECIPE		= C_MAIN		-- learns all unknown recipes
CJRAB.ROLE_FURNISHING	= C_MAIN		-- furnishings hoard
CJRAB.ROLE_SOULGEM		= C_MAIN		-- empty soul gem filler

CJRAB.ROLE_ENCHANT		= nil			-- enchant mats go to bank

CJRAB.ROLE_ARCHIVE		= C_Calliope	-- Archived items (marked with reserve)
CJRAB.ROLE_STYLES		= C_Buffy		-- (non-writ) style mats
CJRAB.ROLE_COSTUMES		= C_Buffy		-- costumes, disguises, clothes
CJRAB.ROLE_SURVEYS		= C_Gareth		-- surveys/maps for non-current zones
CJRAB.ROLE_TRAITS		= C_Freddy		-- trait mats
CJRAB.ROLE_CROWN		= C_Freddy		-- crown items
CJRAB.ROLE_EPIC			= C_Freddy		-- epic/rare mats
CJRAB.ROLE_INGREDIENTS	= C_Kelvin		-- unused food/drink ingredients hoard
CJRAB.ROLE_LOWMATS		= C_Kelvin		-- outleveled crafting mats
