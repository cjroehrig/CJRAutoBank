-- boilerplate for each source file to encapsulate everything in CJRAB:
if CJRAB == nil then CJRAB = {} end
local CJRAB = CJRAB

-- NB: this is loaded first, so no references to anything else!

--=============================================================================
-- Config for current state 


-- current crafting ranks for all alts
-- NB: they must rank-up in lock-step for a given craft
CJRAB.ALTCraftRank = {
	-- keep these in order
	[CRAFTING_TYPE_BLACKSMITHING]		= 3,		-- 1
	[CRAFTING_TYPE_CLOTHIER]			= 3,		-- 2
	[CRAFTING_TYPE_ENCHANTING]			= 3,		-- 3
	[CRAFTING_TYPE_ALCHEMY]				= 2,		-- 4
	[CRAFTING_TYPE_PROVISIONING]		= 3,		-- 5
	[CRAFTING_TYPE_WOODWORKING]			= 3,		-- 6
	[CRAFTING_TYPE_JEWELRYCRAFTING]		= 0,		-- 7
}

-- current questing zone (for surveys)
CJRAB.CurrZone = "Glenumbra"

-- Set to true to mark any unused (non-writ) ingredients as junk
-- instead of sending to ROLE_INGREDIENT hoard
CJRAB.JunkUnusedIngredients = false

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

CJRAB.ROLE_RESERVE		= C_Calliope	-- reserved foods and items
CJRAB.ROLE_STYLES		= C_Buffy		-- style mats
CJRAB.ROLE_COSTUMES		= C_Buffy		-- costumes, disguises, clothes
CJRAB.ROLE_SURVEYS		= C_Gareth		-- surveys/maps for non-current zones
CJRAB.ROLE_TRAITS		= C_Freddy		-- trait mats
CJRAB.ROLE_CROWN		= C_Freddy		-- crown items
CJRAB.ROLE_EPIC			= C_Freddy		-- epic/rare mats
CJRAB.ROLE_INGREDIENTS	= C_Kelvin		-- unused food/drink ingredients hoard
CJRAB.ROLE_LOWMATS		= C_Kelvin		-- outleveled mats

