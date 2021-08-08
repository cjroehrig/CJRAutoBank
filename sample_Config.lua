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
	[CRAFTING_TYPE_BLACKSMITHING]		= 2,		-- 1
	[CRAFTING_TYPE_CLOTHIER]			= 2,		-- 2
	[CRAFTING_TYPE_ENCHANTING]			= 2,		-- 3
	[CRAFTING_TYPE_ALCHEMY]				= 1,		-- 4
	[CRAFTING_TYPE_PROVISIONING]		= 3,		-- 5
	[CRAFTING_TYPE_WOODWORKING]			= 3,		-- 6
	[CRAFTING_TYPE_JEWELRYCRAFTING]		= 0,		-- 7
}

-- current questing zone (to keep surveys on MAIN instead of in storage)
CJRAB.CurrZone = "Glenumbra"

--=============================================================================
-- CHARACTER DEFINITIONS

-- XXX: NB: these are globals and leak to other addons

-- These must be in the SAME order as your character selection screen
-- use '/dumpcharraw all' to get the correct indexes
C_Charlotte			= 1
C_Calliope			= 2
C_Buffy				= 3
C_Gareth			= 4
C_Freddy			= 5
C_Kelvin			= 6

-- Define roles:
C_MAIN				= C_Charlotte	-- main char (all others are alts)
C_STYLES			= C_Buffy		-- styles, costumes, clothes
C_SURVEYS			= C_Gareth		-- zone surveys for future zones
C_TRAITS			= C_Freddy		-- trait mats
C_FUTURE			= C_Freddy		-- future, crown, rare mats
C_FOOD				= C_Kelvin		-- unused ingredients, reserved foods
C_LOWMATS			= C_Kelvin		-- outleveled mats

-- Enable Auto Banking for chars
CJRAB.CharsEnabled = {
	[C_Charlotte]		= true,
	[C_Calliope]		= true,
	[C_Buffy]			= true,
	[C_Gareth]			= true,
	[C_Freddy]			= true,
	[C_Kelvin]			= true
}

