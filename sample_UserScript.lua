-- boilerplate for each source file to encapsulate everything in CJRAB:
if CJRAB == nil then CJRAB = {} end
local CJRAB = CJRAB

-- shortcut aliases
local Msg						= CJRAB.Msg
local Err						= CJRAB.Err
local Dbg						= CJRAB.Dbg

--=============================================================================
-- UserScript  -- this is where all character definitions and actions go


--=============================================================================
-- CHARACTER DEFINITIONS

-- current equipment (cloth/blacksm/wood) crafting rank for all alts
-- NB: they must tier-up in lock-step
local CURR_ALT_EQUIP_WRIT_RANK	= 2
local CURR_QUEST_ZONE			= "Glenumbra"

-- Use constants instead of strings
local C_Charlotte		= 1
local C_Calliope		= 2
local C_Buffy			= 3
local C_Gareth			= 4
local C_Freddy			= 5
local C_Kevin			= 6

-- Enable Auto Banking for that char
CJRAB.CharsEnabled = {
	[C_Charlotte]		= true,
	[C_Calliope]		= true,
	[C_Buffy]			= true,
	[C_Gareth]			= true,
	[C_Freddy]			= true,
	[C_Kevin]			= true
}

-- for CJRAB.GetString
CJRAB_SI_CHARNAME = {
	[0]="UNKNOWN CHAR",
	"Charlotte",
	"Calliope",
	"Buffy",
	"Gareth",
	"Freddy",
	"Kevin",
}


--=============================================================================
-- FCOItemSaver Icons
--  Use /dumpfcoicons to get a list of all icons and their indexes
--  or use /zgoo FCOIS to inspect LAMiconsList to get the index for icons
--  custom/dynamic icons start at [13]

local ICON_LOWLEVEL			= 13
local ICON_WRITMATS			= 14

local is_writ = function(bag, slot)
	if not FCOIS then return false end
	return FCOIS.IsMarked( bag, slot, ICON_WRITMATS )
end
local is_low = function(bag, slot)
	if not FCOIS then return false end
	return FCOIS.IsMarked( bag, slot, ICON_LOWLEVEL )
end


--=============================================================================
-- Shortcut item identifiers
--	t = type  st = specific type

--=====================================
-- ESO ITEM_QUALITY constants are bizarre; these correspond to the SI_..
local QUALITY_WORN			= 0
local QUALITY_NORMAL		= 1
local QUALITY_FINE			= 2
local QUALITY_SUPERIOR		= 3
local QUALITY_EPIC			= 4
local QUALITY_LEGENDARY		= 5

--=====================================
local function isEnchant(t)
	-- return True if ItemType t is enchanting
	if t == ITEMTYPE_ENCHANTING_RUNE_ASPECT 	then return true end
	if t == ITEMTYPE_ENCHANTING_RUNE_ESSENCE 	then return true end
	if t == ITEMTYPE_ENCHANTING_RUNE_POTENCY 	then return true end
	if t == ITEMTYPE_ENCHANTING_BOOSTER		 	then return true end
	return false
end

--=====================================
local function isAlchemy(t)
	if t == ITEMTYPE_POTION_BASE				then return true end
	if t == ITEMTYPE_REAGENT     				then return true end
	if t == ITEMTYPE_POISON_BASE 				then return true end
	return false
end

--=====================================
local function isArmor(link, t)
	if t ~= ITEMTYPE_ARMOR then return false end
	if GetItemLinkArmorType(link) == 0 then return false end -- jewelry
	return true
end
local function isJewelry(link, t)
	if t ~= ITEMTYPE_ARMOR then return false end
	if GetItemLinkArmorType(link) ~= 0 then return false end
	return true
end
local function isWeapon(link, t)
	if t ~= ITEMTYPE_WEAPON then return false end
	return true
end
local function isGlyph(link, t)
	if t == ITEMTYPE_GLYPH_ARMOR then return true end
	if t == ITEMTYPE_GLYPH_WEAPON then return true end
	if t == ITEMTYPE_GLYPH_JEWELRY then return true end
	return false
end
local function isJewelryMat(link, t)
	if t == ITEMTYPE_JEWELRYCRAFTING_MATERIAL then return true end
	if t == ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL then return true end
	if t == ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER then return true end
	if t == ITEMTYPE_JEWELRYCRAFTING_RAW_TRAIT then return true end
	return false
end


--=====================================
local function isEquipCraft(t)
	if t == ITEMTYPE_WEAPON_BOOSTER		 		then return true end
	if t == ITEMTYPE_ARMOR_BOOSTER		 		then return true end
	-- Blacksmithing
	if t == ITEMTYPE_BLACKSMITHING_BOOSTER		then return true end
	if t == ITEMTYPE_BLACKSMITHING_MATERIAL		then return true end
	-- Clothier
	if t == ITEMTYPE_CLOTHIER_BOOSTER			then return true end
	if t == ITEMTYPE_CLOTHIER_MATERIAL			then return true end
	-- Woodworking
	if t == ITEMTYPE_WOODWORKING_BOOSTER		then return true end
	if t == ITEMTYPE_WOODWORKING_MATERIAL		then return true end
	return false
end

--=====================================
local function isEquipWritMat(link, t, quality)
	-- Return true if link (type t) is a current rank Writ equip craft material
	if	t == ITEMTYPE_BLACKSMITHING_MATERIAL or
		t == ITEMTYPE_CLOTHIER_MATERIAL or
		t == ITEMTYPE_WOODWORKING_MATERIAL then
		local minRank = GetItemLinkRequiredCraftingSkillRank(link)
		if minRank == CURR_ALT_EQUIP_WRIT_RANK then
			if quality < QUALITY_FINE then
				return true
			end
		end
	end
	return false
end

--=============================================================================
-- Hoard helper functions

-- A global extra reason for a character transfer
local HoardReason = ""

--=====================================
local function isCharStyle(char, bag, slot, link, t, style)
	-- return true if this is char's style mat
	if t ~= ITEMTYPE_STYLE_MATERIAL then return false end
	-- only distribute style mats marked as "low-level"...
	if not is_low(bag,slot) then return false end

	-- XXX: can't check style == GetRaceId(char); maybe with LeoAltholic...
			--[[
				ITEMSTYLE_RACIAL_BRETON		1
				ITEMSTYLE_RACIAL_ORC		3
				ITEMSTYLE_RACIAL_DARK_ELF	4
				ITEMSTYLE_RACIAL_NORD		5
				ITEMSTYLE_RACIAL_ARGONIAN	6
				ITEMSTYLE_RACIAL_HIGH_ELF	7
				ITEMSTYLE_RACIAL_WOOD_ELF	8
				ITEMSTYLE_RACIAL_KHAJIIT	9
				ITEMSTYLE_RACIAL_IMPERIAL	34
			]]--

	if	   (char == C_Calliope	and style == ITEMSTYLE_RACIAL_REDGUARD)
		or (char == C_Buffy		and style == ITEMSTYLE_RACIAL_HIGH_ELF)
--		or (char == C_Gareth	and style == ITEMSTYLE_RACIAL_NORD)
		or (char == C_Freddy	and style == ITEMSTYLE_RACIAL_NORD)
--		or (char == C_Kevin	and style == ITEMSTYLE_RACIAL_REDGUARD)
		then
			return true
	elseif	char == C_Charlotte
		and	style ~= ITEMSTYLE_RACIAL_REDGUARD
		and	style ~= ITEMSTYLE_RACIAL_NORD
		and	style ~= ITEMSTYLE_RACIAL_HIGH_ELF then
		-- gets all the rest
		return true
	end
end

--=====================================
function CJRAB.LowestCraftLevelChar(ctype)
	-- return the char with lowest level for CRAFTING_TYPE ctype
	-- NB: CJRAB.FetchLeoData must have been called first.
	if not CJRAB.LeoData then return nil end
	local min_level = 999
	local min_char = nil
	local leoId = CJRAB.GetLeoCraftID(ctype)
	local char, cdata

	for char, cdata in pairs(CJRAB.LeoData) do
		if cdata then
			local craft = cdata.skills.craft[leoId]
			if craft then
				if craft.rank < min_level then
					min_char = char
					min_level = craft.rank
				end
			end
		end
	end
--	Dbg("%s has lowest %s crafting (%d)", CJRAB.CharName(min_char),
--			CJRAB.GetString('CJRAB_SI_CRAFTINGTYPE', ctype), min_level)
	return min_char
end

--=====================================
local function isUnresearchedTraitItem(char, link, t)
	-- Return true if item link,t is needed for trait research by char
	local trait
	if isArmor(link, t) then
		trait = GetItemLinkTraitInfo(link)
		if trait == 0 then return false end
		if trait == ITEM_TRAIT_TYPE_ARMOR_INTRICATE then return false end
		if trait == ITEM_TRAIT_TYPE_ARMOR_ORNATE then return false end
		-- if trait == ITEM_TRAIT_TYPE_ARMOR_TRAINING then return false end
		-- XXX: just accept any traits for now
		return true
	elseif isWeapon(link, t) then
		trait = GetItemLinkTraitInfo(link)
		if trait == 0 then return false end
		if trait == ITEM_TRAIT_TYPE_WEAPON_INTRICATE then return false end
		if trait == ITEM_TRAIT_TYPE_WEAPON_ORNATE then return false end
		-- if trait == ITEM_TRAIT_TYPE_WEAPON_TRAINING then return false end
		-- XXX: just accept any traits for now
		return true
--	elseif isJewelry(link, t) then
--		return false
	end
	return false
end


--=====================================
local function isForDeconstruction(char, bag, slot, link, t, quality)
	-- return true if the item is for deconstruction, and
	-- set HoardReason accordingly.
	if isArmor(link, t) or isWeapon(link, t) or isGlyph(link, t) then
		if is_low(bag,slot) then return false end 		-- skip marked gear
		if isUnresearchedTraitItem(C_Charlotte, link, t) then return false end

		if not isGlyph(link, t) and quality > QUALITY_NORMAL then
			-- don't get rare mats from low-level alts; send to main instead
			if char == C_Charlotte then
				HoardReason = HoardReason .. "for mats deconstruction"
				return true
			end
		else
			-- send to char with the lowest skill
			local craft = GetItemLinkCraftingSkillType(link)
			if char == CJRAB.LowestCraftLevelChar(craft) then
				HoardReason = HoardReason .. "for XP deconstruction"
				return true
			end
		end
	end
	return false
end


--=============================================================================
-- HOARD DEFINITIONS


--=====================================
local function isInCharHoard(char, player, bag, slot)
	-- Return true if the item in bag/slot is in char's hoard. 
	local t, st = GetItemType(bag, slot)
	local link = GetItemLink(bag, slot)
	local name = GetItemLinkName(link)
	local icon, stack, sellprice, usable, locked, equiptype, style, quality =
            GetItemInfo(bag, slot)
	local filter = GetItemLinkFilterTypeInfo(link)
	local trait = GetItemLinkTraitInfo(link)
	-- if true then return false end		-- for debugging

	-- distribute style mats to appropriate chars
	if isCharStyle(char, bag, slot, link, t, style) then return true end

	-- items for deconstruction if char has the lowest skill
	if isForDeconstruction(char, bag, slot, link, t, quality) then
		return true		
	end

	---------------------------------------
	if char == C_Charlotte then
		if t == ITEMTYPE_LURE then return true end
		if isAlchemy(t) and not is_writ(bag,slot)	then return true end

		-- must know all recipes
		if t == ITEMTYPE_RECIPE and not IsItemLinkRecipeKnown(link) then
			return true
		end
		-- Furnishings
		if t == ITEMTYPE_FURNISHING					then return true end
		if t == ITEMTYPE_FURNISHING_MATERIAL		then return true end
		-- Equip Craft mats
		if	isEquipCraft(t) and
			not isEquipWritMat(link, t, quality) and
			quality <= QUALITY_SUPERIOR then return true end

		-- surveys for the current zone
		if st == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT then
			if name:find(CURR_QUEST_ZONE) then return true end
		end

		-- XXX: take all empties for filling for now
		if t == ITEMTYPE_SOUL_GEM and quality == QUALITY_NORMAL then
									return true end -- empty Soul gems

	---------------------------------------
	elseif char == C_Calliope then
		-- quester...


	---------------------------------------
	elseif char == C_Buffy then

		-- future style mats
		if t == ITEMTYPE_STYLE_MATERIAL and not is_low(bag, slot) then
			return true
		end
		-- Costumes, etc
		if t == ITEMTYPE_COSTUME					then return true end
		if t == ITEMTYPE_DISGUISE					then return true end
		-- XXX: cosmetic apparel (also st=0):
		if t == ITEMTYPE_ARMOR and
			filter == ITEMFILTERTYPE_MISCELLANEOUS	then return true end

	---------------------------------------
	elseif char == C_Gareth then
		-- future surveys
		if st == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT then
			if not name:find(CURR_QUEST_ZONE) then return true end
		end

	---------------------------------------
	elseif char == C_Freddy then
		-- trait mats
		if t == ITEMTYPE_WEAPON_TRAIT 				then return true end
		if t == ITEMTYPE_ARMOR_TRAIT 				then return true end

		-- Future items
		--if t == ITEMTYPE_CROWN_REPAIR				then return true end
		if t == ITEMTYPE_CROWN_ITEM					then return true end
		if name:find("^Crown") then
			-- exceptions...
			return true
		end

		if isEnchant(t) then return quality > QUALITY_SUPERIOR end
		if isEquipCraft(t) and quality > QUALITY_SUPERIOR then return true end
		if t == ITEMTYPE_POISON then return quality > QUALITY_FINE end

	---------------------------------------
	elseif char == C_Kevin then
		-- Provisioning ingredients not marked as Writ
		if t == ITEMTYPE_INGREDIENT and not is_writ(bag,slot) then
			HoardReason = HoardReason .. "stores unused ingredients"
			return true
		end

		-- low level (previous writ) food
		if t == ITEMTYPE_FOOD or t == ITEMTYPE_DRINK then
			if is_low(bag,slot) then
				HoardReason = HoardReason .. "outleveled food for guild"
				return true
			end
		end

		-- out-leveled Equip crafting mats (manually deposited)
		if	isEquipCraft(t) then
			local minRank = GetItemLinkRequiredCraftingSkillRank(link)
			if minRank < CURR_ALT_EQUIP_WRIT_RANK and
					quality < QUALITY_FINE then
				HoardReason = HoardReason .. "outleveled mats"
				return true
			end
		end
	end

	return false
end

--=====================================
local function isInOtherCharHoard(char, bag, slot)
	-- Return the charID if the item in bag/slot is in another character's hoard
	-- (not char's), or nil otherwise.
	for c, enabled in ipairs(CJRAB.CharsEnabled) do
		if c ~= char then
			if isInCharHoard(c, char, bag, slot) then return c end
		end
	end
	return nil
end


--=====================================
local function isInBankHoard(bankBag, bag, slot)
	-- Return true if the item in bag/slot the bankBag hoard.
	-- NB: isInCharHoard takes precedence
	-- if true then return false end		-- for debugging
	local t, st = GetItemType(bag, slot)
	local link = GetItemLink(bag, slot)
	local icon, stack, sellprice, usable, locked, equiptype, style, quality =
            GetItemInfo(bag, slot)
	---------------------------------------
	if bankBag == BAG_BANK then

		if isEnchant(t) and quality <= QUALITY_SUPERIOR then return true end

		if t== ITEMTYPE_RECIPE and IsItemLinkRecipeKnown(link) then
									return true end
		if st == SPECIALIZED_ITEMTYPE_TROPHY_SCROLL then return true end

		-- Provisioning Writ Mats
		if isAlchemy(t) and is_writ(bag,slot)	then return true end
		if t == ITEMTYPE_INGREDIENT and is_writ(bag,slot) then return true end
		if t == ITEMTYPE_FOOD and is_writ(bag,slot) then return true end
		if t == ITEMTYPE_DRINK and is_writ(bag,slot) then return true end
		if t == ITEMTYPE_POTION and is_writ(bag,slot) then return true end

		-- Equipment (b/c/w) Writ mats (only for current rank)
		if isEquipWritMat(link, t, quality) then return true end

		-- Bank all unknown trait Research items for Charlotte
		-- (but leave them in the bank)
		if isUnresearchedTraitItem(C_Charlotte, link, t) and
					not is_low(bag, slot) then		-- skip marked gear
			HoardReason = HoardReason .. "for Charlotte to research"
			return true
		end
	end

	return false
end


--=====================================
local function depositHoardables( char, bankBag, onlyFillExisting )
	-- Deposit all hoardable stuff from backpack into bankBag
	-- (including anything hoardable by any characters other than char).
	-- If onlyFillExisting is true, then don't use any new slots in bankBag.
	local slot, str, count
	local bag = BAG_BACKPACK

	for slot in CJRAB.BagItems(bag) do
		local link = GetItemLink(bag, slot, 1)
		HoardReason = ""

		if 		not CJRAB.IsCharBound(bag, slot) and 
				not IsItemStolen(bag, slot) and
		   		not IsItemJunk(bag, slot) and
		   		not IsItemLinkUnique(link) and
				not isInCharHoard(char, char, bag, slot) then

			-- first check if it is in another char's hoard
			local reason = nil
			local c = isInOtherCharHoard(char, bag, slot)
			if c then
				reason = "for " .. CJRAB.CharName(c)
			elseif isInBankHoard(bankBag, bag, slot) then
				-- otherwise if it is in the bank's hoard
				reason = "for " .. CJRAB.BagName(bankBag)
			end

			if reason then
				if HoardReason ~= "" then
					reason = reason .. ", " .. HoardReason
				end
				if onlyFillExisting then
					CJRAB.TransferFill(bag, slot, bankBag, reason)
				else
					CJRAB.Transfer(bag, slot, bankBag, reason)
				end
			end
		end
	end
end

--=====================================
local function withdrawHoardables( char, bankBag )
	local slot, str, count
	for slot in CJRAB.BagItems(bankBag) do
		HoardReason = ""
		if isInCharHoard(char, char, bankBag, slot) then
			CJRAB.Transfer(bankBag, slot, BAG_BACKPACK, HoardReason)
		end
	end
end

--=====================================
local function transferCurrency(char)
	local amount, src, dst, msg

	if char == C_Charlotte then
		-- withdraw all
		amount = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_BANK)
		src = CURRENCY_LOCATION_BANK
		dst = CURRENCY_LOCATION_CHARACTER
		msg = "Withdrawing"

	else
		-- deposit all but 999G
		amount = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER)
		amount = amount - 999
		src = CURRENCY_LOCATION_CHARACTER
		dst = CURRENCY_LOCATION_BANK
		msg = "Depositing"
	end

	if amount > 0 then
		Msg("%s %d G", msg, amount)
		TransferCurrency( CURT_MONEY, amount, src, dst)
	end
end


--=============================================================================
-- UserScript ENTRY POINTS

--=====================================
function CJRAB.OpenBanking(bankBag)
	local slot
	local charname = GetUnitName("player")
	local char = CJRAB.GetChar(charname)
	-- skip if character is not enabled
	if not char or not CJRAB.CharsEnabled[char] then return false end

	-- XXX: only do our actual bank for now...
	if bankBag ~= BAG_BANK then return end

	-- don't fight with Lazy Writ Creator...
	if WritCreater then
		local _, writActive = WritCreater.writSearch()
		if writActive then
			Msg("AutoBank disabled when Lazy & Writ quest is active.")
			return
		end
	end

	-- get (copy) LeoAltholic data once here
	CJRAB:FetchLeoData()

	-- Step 0:  Stack all items in the bank and bags
	-- XXX: don't do this; I suspect it doesn't complete before the
	-- TransferPlan starts and things stack incorrectly.
	-- StackBag(bankBag)
	-- StackBag(BAG_BACKPACK)

	CJRAB.InitTransfer(bankBag)		-- NB: discards any pending transfers
	-- Step 1:  Deposit all bankables to existing stacks to clear backpack
	depositHoardables(char, bankBag, true)

	-- Step 2:  Withdraw all char-specific collectibles to clear bank space
	withdrawHoardables(char, bankBag)

	-- Step 3:  Deposit all bankable now
	depositHoardables(char, bankBag)

	-- Initiate the transfer
	CJRAB.ProcessTransfer()

	-- Step 4:  Deposit/withdraw currency
	transferCurrency(char)
end

--=====================================
function CJRAB.CloseBanking(bankBag)
	Msg("See you next time.")
end

--=====================================
function CJRAB.Inventory(bag, slot, reason)
	-- inventory bag/slot has changed
	local charname = GetUnitName("player")
	local char = CJRAB.GetChar(charname)
	local t, st = GetItemType(bag, slot)
	local link = GetItemLink(bag, slot)
	local icon, stack, sellprice, usable, locked, equiptype, style, quality =
            GetItemInfo(bag, slot)
	local trait = GetItemLinkTraitInfo(link)
	local isJunk = false

	---------------------------------------
	-- trash
	if t == ITEMTYPE_TRASH then isJunk=true end
	-- NOPE! if quality == ITEM_QUALITY_TRASH then isJunk=true end
	-- XXX: be careful here, some good rewards are Ornate...
	if trait == ITEM_TRAIT_TYPE_WEAPON_ORNATE then isJunk=true end
	if trait == ITEM_TRAIT_TYPE_ARMOR_ORNATE then isJunk=true end
	if trait == ITEM_TRAIT_TYPE_JEWELRY_ORNATE then isJunk=true end

	-- unused mats
	--[[
	if t == ITEMTYPE_INGREDIENT and not is_writ(bag,slot) then
		if quality < QUALITY_FINE then
			isJunk=true
		end
	end
	]]--

	-- jewelery (don't have Summerset)
	if isJewelryMat(link, t) then isJunk = true end

	---------------------------------------
	if isJunk then
		Msg("%s marked as junk", CJRAB.ItemName(bag, slot))
		SetItemIsJunk(bag, slot, true)
	end

end
