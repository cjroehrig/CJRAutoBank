-- boilerplate for each source file to encapsulate everything in CJRAB:
if CJRAB == nil then CJRAB = {} end
local CJRAB = CJRAB

-- shortcut aliases
local Msg						= CJRAB.Msg
local Err						= CJRAB.Err
local Dbg						= CJRAB.Dbg

--=============================================================================
-- UserScript  -- this is where all actions go


--=============================================================================
-- FCOItemSaver Icons
--  Use /dumpfcoicons to get a list of all icons and their indexes
--  or use /zgoo FCOIS to inspect LAMiconsList to get the index for icons
--  custom/dynamic icons start at [13]

local ICON_RESERVED			= 13
local ICON_WRITMATS			= 14

local is_reserved = function(bag, slot)
	if not FCOIS then return false end
	return FCOIS.IsMarked( bag, slot, ICON_RESERVED )
end
local is_writ = function(bag, slot)
	if not FCOIS then return false end
	return FCOIS.IsMarked( bag, slot, ICON_WRITMATS )
end


--=============================================================================
-- Shortcut item identifiers
--	t = type  st = specific type

--=====================================
-- ESO ITEM_QUALITY constants have weird names; use the common ones
local QUALITY_WORN			= ITEM_QUALITY_TRASH		-- 0
local QUALITY_NORMAL		= ITEM_QUALITY_NORMAL		-- 1
local QUALITY_FINE			= ITEM_QUALITY_MAGIC		-- 2
local QUALITY_SUPERIOR		= ITEM_QUALITY_ARCANE		-- 3
local QUALITY_EPIC			= ITEM_QUALITY_ARTIFACT		-- 4
local QUALITY_LEGENDARY		= ITEM_QUALITY_LEGENDARY	-- 5

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
		if minRank == CJRAB.CURR_ALT_EQUIP_WRIT_RANK then
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
local function isCharStyleMat(char, bag, slot, link, t, style)
	-- return true if this is char's style mat
	if t ~= ITEMTYPE_STYLE_MATERIAL then return false end
	-- only distribute style mats marked as reserved...
	if not is_reserved(bag,slot) then return false end

	if char ~= C_MAIN then
		-- alts get their racial style mats
		-- XXX: raceId matches ITEMSTYLE_RACIAL_* .. imperial too?
		local c = CJRAB.Chars[char]
		if style == c.raceId then
			local race = GetRaceName(c.gender, style)
			HoardReason = race .. " style mat for ALT writ use"
			return true
		end
	else
		-- main get all the rest
		for i = 1, #CJRAB.Chars do
			-- skip other char's 
			local c = CJRAB.Chars[i]
			if i ~= char and style == c.raceId then return false end
		end
		HoardReason = "style mat for MAIN use"
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
		if is_reserved(bag,slot) then return false end 		-- skip marked gear
		if isUnresearchedTraitItem(C_MAIN, link, t) then return false end

		if not isGlyph(link, t) and quality > QUALITY_NORMAL then
			-- don't get rare mats from low-level alts; send to main instead
			if char == C_MAIN then
				HoardReason = "for mats deconstruction"
				return true
			end
		else
			-- send to char with the lowest skill
			local craft = GetItemLinkCraftingSkillType(link)
			if char == CJRAB.LowestCraftLevelChar(craft) then
				HoardReason = "for XP deconstruction"
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
	-- XXX: first one that logs in gets them all, doesn't give them up
	if isCharStyleMat(char, bag, slot, link, t, style) then return true end

	-- items for deconstruction if char has the lowest skill
	if isForDeconstruction(char, bag, slot, link, t, quality) then
		return true		
	end

	---------------------------------------
	if char == C_MAIN then
		if t == ITEMTYPE_LURE then
			return true
		end
		if isAlchemy(t) and not is_writ(bag,slot)	then
			HoardReason = "alchemy archive"
			return true
		end

		-- must know all recipes
		if t == ITEMTYPE_RECIPE and not IsItemLinkRecipeKnown(link) then
			HoardReason = "recipe to learn"
			return true
		end
		-- Furnishings
		if t == ITEMTYPE_FURNISHING or t == ITEMTYPE_FURNISHING_MATERIAL then
			HoardReason = "MAIN furnishings/crafting"
			return true
		end
		-- Equip Craft mats
		if	isEquipCraft(t) and not isEquipWritMat(link, t, quality) and
						quality <= QUALITY_SUPERIOR then
			HoardReason = "MAIN crafting"
			return true
		end

		-- surveys for the current zone
		if st == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT then
			if name:find(CJRAB.CurrZone) then
				HoardReason = "Survey for current zone " .. CJRAB.CurrZone
				return true
			end
		end

		-- XXX: take all empty soul gems for filling for now
		if t == ITEMTYPE_SOUL_GEM and quality == QUALITY_NORMAL then
			HoardReason = "Empty soul gems for filling"
			return true
		end

	---------------------------------------
	elseif char == C_STYLES then
		-- archive future style mats
		if t == ITEMTYPE_STYLE_MATERIAL and not is_reserved(bag, slot) then
			HoardReason = "style mat archived for future"
			return true
		end
		-- Costumes, etc
		if t == ITEMTYPE_COSTUME or t == ITEMTYPE_DISGUISE then
			HoardReason = "costume/disguse archive"
			return true
		end
		-- XXX: cosmetic apparel (also st=0):
		if t == ITEMTYPE_ARMOR and filter == ITEMFILTERTYPE_MISCELLANEOUS then
			HoardReason = "cosmetic apparel archive"
			return true
		end

	---------------------------------------
	elseif char == C_SURVEYS then
		-- future surveys
		if st == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT then
			if not name:find(CJRAB.CurrZone) then
				HoardReason = "surveys for other zones"
				return true
			end
		end

	---------------------------------------
	elseif char == C_TRAITS then
		-- trait mats
		if t == ITEMTYPE_WEAPON_TRAIT or t == ITEMTYPE_ARMOR_TRAIT then
			HoardReason = "trait mats for future"
			return true
		end

	---------------------------------------
	elseif char == C_FUTURE then
		-- Future, crown and rare items
		--if t == ITEMTYPE_CROWN_REPAIR				then return true end
		if t == ITEMTYPE_CROWN_ITEM	or name:find("^Crown") then
			-- exceptions?
			HoardReason = "Crown items for future"
			return true
		end

		if isEnchant(t) and quality > QUALITY_SUPERIOR then
			HoardReason = "epic enchant mats for future"
			return true
		end
		if isEquipCraft(t) and quality > QUALITY_SUPERIOR then
			HoardReason = "epic craft mats for future"
			return true
		end
		if t == ITEMTYPE_POISON and quality > QUALITY_FINE then
			HoardReason = "superior poisons for future"
			return true
		end

	---------------------------------------
	elseif char == C_FOOD then
		-- Provisioning ingredients not marked as Writ
		if t == ITEMTYPE_INGREDIENT and not is_writ(bag,slot) then
			HoardReason = "unused ingredient archive"
			return true
		end

		-- low level (previous writ) food
		if t == ITEMTYPE_FOOD or t == ITEMTYPE_DRINK then
			if is_reserved(bag,slot) then
				HoardReason = "outleveled food for guild"
				return true
			end
		end
	---------------------------------------
	elseif char == C_LOWMATS then

		-- out-leveled Equip crafting mats (manually deposited)
		if	isEquipCraft(t) then
			local minRank = GetItemLinkRequiredCraftingSkillRank(link)
			if minRank < CJRAB.CURR_ALT_EQUIP_WRIT_RANK and
					quality < QUALITY_FINE then
				HoardReason = "outleveled mats"
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
	for c = 1, #CJRAB.Chars do
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

		if isEnchant(t) and quality <= QUALITY_SUPERIOR then
			HoardReason = "enchant archive"
			return true
		end

		if t== ITEMTYPE_RECIPE and IsItemLinkRecipeKnown(link) then
			HoardReason = "for any takers"
			return true
		end
		if st == SPECIALIZED_ITEMTYPE_TROPHY_SCROLL then
			HoardReason = "for all to use"
			return true
		end

		-- Alchemy and Provisioning Writ mats...
		if isAlchemy(t) or t == ITEMTYPE_POTION or
					t == ITEMTYPE_INGREDIENT or
					t == ITEMTYPE_FOOD or
					t == ITEMTYPE_DRINK then
			if is_writ(bag, slot) then
				HoardReason = "for Writs"
				return true
			end
		end

		-- Equipment (b/c/w) Writ mats (only for current rank)
		if isEquipWritMat(link, t, quality) then
			HoardReason = "for Writs"
			return true
		end

		-- Bank all unknown trait Research items for MAIN
		-- (but leave them in the bank)
		if isUnresearchedTraitItem(C_MAIN, link, t) and
					not is_reserved(bag, slot) then		-- skip marked gear
			HoardReason = "for " ..  CJRAB.CharName(C_MAIN) .. " to research"
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
	local str, count
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
	local str, count
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

	if char == C_MAIN then
		-- MAIN: withdraw all
		amount = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_BANK)
		src = CURRENCY_LOCATION_BANK
		dst = CURRENCY_LOCATION_CHARACTER
		msg = "Withdrawing"

	else
		-- ALT: deposit all but 999G
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
	if not char or not CJRAB.Chars[char].enabled then return false end

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
