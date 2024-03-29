-- boilerplate for each source file to encapsulate everything in CJRAB:
if CJRAB == nil then CJRAB = {} end
local CJRAB = CJRAB

-- shortcut aliases
local Msg						= CJRAB.Msg
local Err						= CJRAB.Err
local Dbg						= CJRAB.Dbg


--=============================================================================
-- Globals for use between OpenBanking and CloseBanking
local PlayerChar
local CountCharDC
local DeconstructItems = {				-- indexed by TradeskillType
	[CRAFTING_TYPE_BLACKSMITHING]       = 0,        -- 1
    [CRAFTING_TYPE_CLOTHIER]            = 0,        -- 2
    [CRAFTING_TYPE_ENCHANTING]          = 0,        -- 3
    [CRAFTING_TYPE_ALCHEMY]             = 0,        -- 4
    [CRAFTING_TYPE_PROVISIONING]        = 0,        -- 5
    [CRAFTING_TYPE_WOODWORKING]         = 0,        -- 6
    [CRAFTING_TYPE_JEWELRYCRAFTING]     = 0,        -- 7
}


--=============================================================================
-- Extra ESO Constants

--=====================================
-- ESO ITEM_QUALITY constants have weird names; use the current ones
local QUALITY_WORN					= ITEM_QUALITY_TRASH		-- 0
local QUALITY_NORMAL				= ITEM_QUALITY_NORMAL		-- 1
local QUALITY_FINE					= ITEM_QUALITY_MAGIC		-- 2
local QUALITY_SUPERIOR				= ITEM_QUALITY_ARCANE		-- 3
local QUALITY_EPIC					= ITEM_QUALITY_ARTIFACT		-- 4
local QUALITY_LEGENDARY				= ITEM_QUALITY_LEGENDARY	-- 5


--=====================================
-- Special-case ItemIds:
local ITEMID_MALACHITE_SHARD				= 0xfcb2
-- Nope, bound to character evidently
-- local ITEMID_REWARD_WORTHY					= 0x238a9
local ITEMID_CROWN_POISON					= 0x1374a
local ITEMID_CROWN_POTION					= 0xfcc6	
local ITEMID_COUNTERFEIT_PARDON_EDICT		= 0x11863

--=============================================================================
-- Other AddOn interfaces

--=====================================
local CS = CraftStoreFixedAndImprovedLongClassName

local is_reserved = function(cbag, slot)
	return cbag:IsFCOMarked(slot, CJRAB.FCO_ICON_RESERVED)
end
local is_writ = function(cbag, slot)
	return cbag:IsFCOMarked(slot, CJRAB.FCO_ICON_WRITMATS )
end


--=============================================================================
-- Shortcut item identifier functions
--	t = type  st = specific type


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

-- Solvents are now part of ALTCraft
--	if t == ITEMTYPE_POTION_BASE				then return true end
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
	if t == ITEMTYPE_JEWELRYCRAFTING_BOOSTER then return true end
	if t == ITEMTYPE_JEWELRY_TRAIT	then return true end
	if t == ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL then return true end
	if t == ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER then return true end
	if t == ITEMTYPE_JEWELRY_RAW_TRAIT then return true end
	return false
end

--=====================================
local function isCosmetic(link, t)
	local filter = GetItemLinkFilterTypeInfo(link)
	if t == ITEMTYPE_ARMOR and filter == ITEMFILTERTYPE_MISCELLANEOUS then
		-- XXX: exceptions? (also st=0)...
		return true
	end
end

--=====================================
local function isCollectible(link, t, st)
	if	st == SPECIALIZED_ITEMTYPE_TROPHY_COLLECTIBLE_FRAGMENT or
		st == SPECIALIZED_ITEMTYPE_TROPHY_KEY_FRAGMENT or
		st == SPECIALIZED_ITEMTYPE_TROPHY_RECIPE_FRAGMENT or
		st == SPECIALIZED_ITEMTYPE_TROPHY_RUNEBOX_FRAGMENT or
		st == SPECIALIZED_ITEMTYPE_RUNEBOX_UPGRADE_FRAGMENT then
		return true
	end
	if t == ITEMTYPE_COLLECTIBLE then
		--Dbg("isCollectible(%s,%d,%d) ==", CJRAB.ItemLinkName(link), t, st)
		if	st == SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE then
			return true
		end
	end

	local name = GetItemLinkName(link)
	if name:find('Aurora Firepot Spider') then
		return true
	end

	return false
end



--=====================================
local function isArchiveType(link, t)
	-- Return True if this is a Archive type item where 
	-- the RESERVED mark means to archive it.
	local id = GetItemLinkItemId(link)
	-- exceptions
	if id == ITEMID_CROWN_POTION then return false end

	if t == ITEMTYPE_FOOD then return true end
	if t == ITEMTYPE_DRINK then return true end
	if t == ITEMTYPE_POTION then return true end
	return false
end
--=====================================
local function isStyleMat(link, t)
	-- Return True if this is a Style mat
	if t == ITEMTYPE_STYLE_MATERIAL then return true end
	local id = GetItemLinkItemId(link)
	if id == ITEMID_MALACHITE_SHARD then return true end
	return false
end



--=====================================
local function isEquipBooster(t)
	if t == ITEMTYPE_WEAPON_BOOSTER		 		then return true end
	if t == ITEMTYPE_ARMOR_BOOSTER		 		then return true end
	if t == ITEMTYPE_BLACKSMITHING_BOOSTER		then return true end
	if t == ITEMTYPE_CLOTHIER_BOOSTER			then return true end
	if t == ITEMTYPE_WOODWORKING_BOOSTER		then return true end
	-- always keep >Fine jewelcrafting boosters:
	if t == ITEMTYPE_JEWELRYCRAFTING_BOOSTER	then return true end
	if t == ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER	then return true end
	return false
end

local function isRawMat(t)
	if t == ITEMTYPE_BLACKSMITHING_RAW_MATERIAL	then return true end
	if t == ITEMTYPE_CLOTHIER_RAW_MATERIAL		then return true end
	if t == ITEMTYPE_WOODWORKING_RAW_MATERIAL	then return true end
	if t == ITEMTYPE_RAW_MATERIAL				then return true end
	if CJRAB.HasJewelcrafting then
		-- only keep jewelcrafting mats if we have Jewelcrafting
		if t == ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL	then return true end
		if t == ITEMTYPE_JEWELRY_RAW_TRAIT	then return true end
	end
	return false
end

local function isEquipMat(t)
	if t == ITEMTYPE_BLACKSMITHING_MATERIAL		then return true end
	if t == ITEMTYPE_CLOTHIER_MATERIAL			then return true end
	if t == ITEMTYPE_WOODWORKING_MATERIAL		then return true end
	if CJRAB.HasJewelcrafting then
		-- only keep jewelcrafting mats if we have Jewelcrafting
		if t == ITEMTYPE_JEWELRYCRAFTING_MATERIAL		then return true end
	end
	return false
end



--=============================================================================
-- ALT Crafting functions

local function isALTCraftMat(link, t)
	-- return True if this a mat managed automatically by ALTCraftRank 
	if t == ITEMTYPE_POTION_BASE				then return true end
	if isEquipMat(t) 							then return true end
	if isRawMat(t) 								then return true end
	return false
end

local function getCraftRank(link, t)
	-- Return the craft rank of link (type t)
	-- Return nil if item is not an ALTCraftMat.
	if not isALTCraftMat(link, t) then return nil end
	local craft = GetItemLinkCraftingSkillType(link)
	if craft == 0 or craft == nil then return nil end
	local skillRank = GetItemLinkRequiredCraftingSkillRank(link)
	if skillRank == 0 or skillRank == nil then return nil end
	return skillRank
end

local function isAtLeastCraftRank(rankArray, link, t)
	-- Return true if (link,t) is an ALTCraftMat over the rank given in
	-- 'rankArray' which is an array of CraftSkill ranks.
	local rank = getCraftRank(link, t)
	if rank == nil then return false end
	local craft = GetItemLinkCraftingSkillType(link)
	if rank >= rankArray[craft] then return true else return false end
end

local function isUnderCraftRank(rankArray, link, t)
	-- Return true if (link,t) is an ALTCraftMat under the rank given in
	-- 'rankArray' which is an array of CraftSkill ranks.
	local rank = getCraftRank(link, t)
	if rank == nil then return false end
	local craft = GetItemLinkCraftingSkillType(link)
	if rank < rankArray[craft] then return true else return false end
end

local function isEqualCraftRank(rankArray, link, t)
	-- Return true if (link,t) is an ALTCraftMat equal to the rank given in
	-- 'rankArray' which is an array of CraftSkill ranks.
	local rank = getCraftRank(link, t)
	if rank == nil then return false end
	local craft = GetItemLinkCraftingSkillType(link)
	if rank == rankArray[craft] then return true else return false end
end



--=============================================================================
-- Hoard helper functions

-- A global reason for a transfer (added to the message)
local HoardReason = ""

--=====================================
local function isCharStyleMat(char, cbag, slot, link, t)
	-- return true if this is char's style mat
	if not isStyleMat(link, t) then return false end

	-- only distribute style mats marked as writ...
	if not is_writ(cbag,slot) then return false end

	-- Keep all reserved style mats in the bank
	if CJRAB.WritStyleMatsInBank then return false end

	local _, _, _, _, style = GetItemLinkInfo(link)
	if char ~= CJRAB.ROLE_CRAFTER then
		-- alts get their racial style mats
		-- XXX: raceId matches ITEMSTYLE_RACIAL_* .. imperial too?
		local c = CJRAB.Chars[char]
		if style == c.raceId then
			local race = GetRaceName(c.gender, style)
			HoardReason = race .. " style mat for ALT writ use"
			return true
		end
	else
		-- main crafter gets all the rest
		for i = 1, #CJRAB.Chars do
			-- skip other char's 
			local c = CJRAB.Chars[i]
			if i ~= char and style == c.raceId then return false end
		end
		HoardReason = "style mat for CRAFTER use"
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
		local rank = 999

		if char == PlayerChar then
			-- Don't use Leo; it doesn't update if player levels up.
			-- XXX; code taken from Leo; undocumented API?  No:
			-- https://forums.elderscrollsonline.com/en/discussion/358626/update-15-api-patch-notes-change-log-pts
			local skillType, skillIdx = GetCraftingSkillLineIndices(ctype)
			_, rank = GetSkillLineInfo(skillType, skillIdx)
--			Dbg("%s has %s rank %d", CJRAB.CharName(char), CJRAB.GetString('CJRAB_SI_CRAFTINGTYPE', ctype), rank)

		else
			-- not PlayerChar; use Leo
			if cdata then
				local craft = cdata.skills.craft[leoId]
				if craft then
					rank = craft.rank
				end
			end
		end
		if rank <= min_level then
			-- XXX: <= takes the last char of that level
			min_char = char
			min_level = rank
		end
	end
--	Dbg("%s has lowest %s crafting (%d)", CJRAB.CharName(min_char),
--			CJRAB.GetString('CJRAB_SI_CRAFTINGTYPE', ctype), min_level)
	return min_char
end


--=====================================
local function isUnresearchedTraitItem(char, link, t)
	-- Return true if item link,t is needed for trait research by char

	if not char then return false end		-- if ROLE_RESEARCH is nil
	local trait = GetItemLinkTraitInfo(link)
	if not trait or trait == 0 then return false end
	-- skip intricate and ornate 
	if isArmor(link, t) then
		if trait == ITEM_TRAIT_TYPE_ARMOR_INTRICATE then return false end
		if trait == ITEM_TRAIT_TYPE_ARMOR_ORNATE then return false end
	elseif isWeapon(link, t) then
		if trait == ITEM_TRAIT_TYPE_WEAPON_INTRICATE then return false end
		if trait == ITEM_TRAIT_TYPE_WEAPON_ORNATE then return false end
	elseif isJewelry(link, t) then
		if not CJRAB.HasJewelcrafting then return false end
		if trait == ITEM_TRAIT_TYPE_JEWELRY_INTRICATE then return false end
		if trait == ITEM_TRAIT_TYPE_JEWELRY_ORNATE then return false end
	end

	-- check CraftStore data
	if not CS then return true end		-- accept all if not installed
	local craft, line, trait = CS.GetTrait(link)
	if not craft then return false end
	local charname = CJRAB.CharName(char)

	-- (if integer, then currently being researched)
	if CS.Data.crafting.researched[charname][craft][line][trait] == false then
		return true
	end
	return false
end


--=====================================
local function isForDeconstruction(char, cbag, slot, link, t, quality)
	-- return true if the item is for deconstruction, and
	-- set HoardReason accordingly.
	if	isArmor(link, t) or isWeapon(link, t) or isGlyph(link, t) or
		(CJRAB.HasJewelcrafting and  isJewelry(link,t)) then
		local craft = GetItemLinkCraftingSkillType(link)

		if craft == CRAFTING_TYPE_INVALID then
			-- some Miscellaneous clothing has no craft type
			return false
		end

		-- companion items can't be deconstructed
		if (GetItemLinkActorCategory(link) 
						== GAMEPLAY_ACTOR_CATEGORY_COMPANION) then
			return false
		end

		if isUnresearchedTraitItem(CJRAB.ROLE_RESEARCH, link, t) then
			return false
		end

		if CJRAB.CrafterQualityDC and
			not isGlyph(link, t) and quality > QUALITY_NORMAL then
			-- don't get rare mats from low-level alts; send to crafter instead
			if char == CJRAB.ROLE_CRAFTER then
				-- don't DC any epic CP160 gear?
				if not CJRAB.BankCP160Gear or
							quality < QUALITY_EPIC or
							GetItemLinkRequiredChampionPoints(link) < 160 then
					HoardReason = "for mats deconstruction"
					if CountCharDC and char == PlayerChar then
						DeconstructItems[craft] = DeconstructItems[craft] + 1
						Dbg("isForDeconstruction(mats): %s", cbag:ItemName(slot))
					end
					return true
				end
			end
		else
			if CJRAB.ALTCraftDistribute[craft] then
				-- send to char with the lowest skill
				if char == CJRAB.LowestCraftLevelChar(craft) then
					HoardReason = "for ALT XP deconstruction"
					if CountCharDC and char == PlayerChar then
						DeconstructItems[craft] = DeconstructItems[craft] + 1
						Dbg("isForDeconstruction(ALT XP): %s", cbag:ItemName(slot))
					end
					return true
				end
			elseif char == CJRAB.ROLE_CRAFTER then
				HoardReason = "for CRAFTER XP deconstruction"
				if CountCharDC and char == PlayerChar then
					DeconstructItems[craft] = DeconstructItems[craft] + 1
						Dbg("isForDeconstruction(CRAFTER XP): %s", cbag:ItemName(slot))
				end
				return true
			end
		end
	end
	return false
end


--=============================================================================
-- HOARD DEFINITIONS

--=====================================
local function isCharSurvey(char, name)
	-- Return true of the item name is one of this character's
	-- designated Survey or Treasure Map items.
	-- NB: ROLE_QUEST has precedence in case of multiple matches.

	-- is char the quester?
	if char ~= CJRAB.ROLE_QUESTER then
		-- No, so first check if the quester wants it...
		for _, pat in ipairs(CJRAB.CharSurveys[CJRAB.ROLE_QUESTER]) do
			if name:find(pat) then
				-- quester wants it; let them have it.
				-- XXX: skip Jewelry Surveys for now (until we level it)
				if not name:find('Jewelry') then
					return false
				end
			end
		end
	end

	-- see if we want it
	for _, pat in ipairs(CJRAB.CharSurveys[char]) do
		if name:find(pat) then
			--  XXX: skip Jewelry Surveys
			if char == CJRAB.ROLE_QUESTER then
				if name:find('Jewelry') then
					return false
				end
			end
			return true
		end
	end
	return false
end

--=====================================
local function isInCharHoard(char, player, cbag, slot)
	-- Return true if the item in cbag/slot is in char's hoard. 
	-- NB: cbag is a CloneBag object
	local item = cbag:GetItem(slot)
	local t, st = item.t, item.st
	local link = item.link
	local quality = GetItemLinkQuality(link)
	local name = GetItemLinkName(link)
	-- if true then return false end		-- for debugging

	-- skip all reserved items unless they are ArchiveType
	if not isArchiveType(link, t, st) and is_reserved(cbag, slot) then
		return false
	end

	-- distribute style mats to appropriate chars
	-- XXX: first one that logs in gets them all, doesn't give them up
	if isCharStyleMat(char, cbag, slot, link, t) then return true end

	-- items for deconstruction if char has the lowest skill
	if isForDeconstruction(char, cbag, slot, link, t, quality) then
		return true		
	end

	---------------------------------------
	-- ROLES
	-- https://wiki.esoui.com/API
	-- https://wiki.esoui.com/Constant_Values#ITEMTYPE_ADDITIVE
	-- https://wiki.esoui.com/Constant_Values#SPECIALIZED_ITEMTYPE_ADDITIVE

	-- surveys for this char
	if st == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT then
		if isCharSurvey(char, name) then
			HoardReason = CJRAB.CharName(char) .. "'s survey hoard"
			return true
		end
	end
	-- treasure maps for this char
	if st == SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP then
		if isCharSurvey(char, name) then
			HoardReason = CJRAB.CharName(char) .. "'s treasure map hoard"
			return true
		end
	end

	if char == CJRAB.ROLE_QUESTER then
		-- Crown poisons (for those Endeavors)
		if t == ITEMTYPE_POISON and 
					GetItemLinkItemId(link) == ITEMID_CROWN_POISON then
			HoardReason = "for poison endeavours"
			return true
		end
	end

	if char == CJRAB.ROLE_LURE then
		if t == ITEMTYPE_LURE then
			HoardReason = "fishing lure hoard"
			return true
		end
	end

	if char == CJRAB.ROLE_ALCHEMY then
		if isAlchemy(t) and not is_writ(cbag,slot)	then
			HoardReason = "alchemy hoard"
			return true
		end
	end

	if char == CJRAB.ROLE_ENCHANT then
		if isEnchant(t) and not is_writ(cbag,slot) then
			HoardReason = "enchant hoard"
			return true
		end
	end

	if char == CJRAB.ROLE_RECIPE then
		if t == ITEMTYPE_RECIPE and not IsItemLinkRecipeKnown(link) then
			HoardReason = "provisioning recipe to learn"
			return true
		end
	end

	if char == CJRAB.ROLE_FURNISHING then
		-- Furnishings
		if t == ITEMTYPE_FURNISHING then
			HoardReason = "furnishing hoard"
			return true
		end
	end

	if char == CJRAB.ROLE_CRAFTER then
		if t == ITEMTYPE_FURNISHING_MATERIAL then
			HoardReason = "furnishing mats"
			return true
		end
		-- current and future craft mats
		if	quality <= QUALITY_SUPERIOR and
					isAtLeastCraftRank(CJRAB.CrafterRank, link, t) and
					not isEqualCraftRank(CJRAB.ALTCraftRank, link, t)  and
					not is_writ(cbag,slot) then
			HoardReason = "crafting mats (non epic)"
			return true
		end
		-- Equip boosters >= FINE
		if quality <= QUALITY_SUPERIOR and isEquipBooster(t) then
			HoardReason = "crafting boosters"
			return true
		end
		-- Raw mats if we're distributing them
		if CJRAB.DistribRawMats and isRawMat(t) then
			HoardReason = "raw mats"
			return true
		end

	end

	if char == CJRAB.ROLE_COLLECTOR then
		if isCollectible(link, t, st) then
			HoardReason = "collectible"
			return true
		end

		-- if st == SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE then
		-- nothing; per-account.  Just use them or discard... manually junk?
	end


	if char == CJRAB.ROLE_RESEARCH and not CJRAB.ResearchablesInBank then
		if isUnresearchedTraitItem(char, link, t) then
			HoardReason = "to research"
			return true
		end
	end

	if char == CJRAB.ROLE_SOULGEM then
		-- XXX: take all empty soul gems for filling for now
		if t == ITEMTYPE_SOUL_GEM and quality == QUALITY_NORMAL then
			HoardReason = "Empty soul gems for filling"
			return true
		end
	end

	if char == CJRAB.ROLE_STYLES then
		-- archive future non-writ style mats
		if isStyleMat(link, t) and not is_writ(cbag, slot) then
			HoardReason = "style mat hoard for future"
			return true
		end
	end

	if char == CJRAB.ROLE_COSTUMES then
		-- Costumes, etc
		if t == ITEMTYPE_COSTUME or t == ITEMTYPE_DISGUISE then
			HoardReason = "costume/disguse hoard"
			return true
		end
		-- cosmetic apparel
		if isCosmetic(link, t) then
			HoardReason = "cosmetic apparel hoard"
			return true
		end
	end

	if char == CJRAB.ROLE_SURVEYS then
		if	st == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT or
			st == SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP then
			local isCurr = false
			for toon, patterns in pairs(CJRAB.CharSurveys) do
				for _, pat in ipairs(patterns) do
					if name:find(pat) then
						isCurr = true
						break
					end
				end
			end
			if not isCurr then
				HoardReason = "remainder survey/treasure map hoard"
				return true
			end
		end
	end

	if char == CJRAB.ROLE_TRAITS then
		-- trait mats
		if t == ITEMTYPE_WEAPON_TRAIT or t == ITEMTYPE_ARMOR_TRAIT or
				(CJRAB.HasJewelcrafting and t == ITEMTYPE_JEWELRY_TRAIT) then
			HoardReason = "trait mats for future"
			return true
		end
	end

	if char == CJRAB.ROLE_CROWN then
		-- Future, crown and rare items
		--if t == ITEMTYPE_CROWN_REPAIR				then return true end
		if (t == ITEMTYPE_CROWN_ITEM or name:find("^Crown")) and
					-- exceptions...
					t ~= ITEMTYPE_POISON and
					t ~= ITEMTYPE_POTION and
					t ~= ITEMTYPE_FOOD and
					t ~= ITEMTYPE_STYLE_MATERIAL then
			HoardReason = "Crown items for future"
			return true
		end
	end

	if char == CJRAB.ROLE_EPIC then
		if quality > QUALITY_SUPERIOR and isEnchant(t) then
			HoardReason = "epic enchant mats for future"
			return true
		end
		if quality > QUALITY_SUPERIOR and
				(isEquipMat(t) or isEquipBooster(t) or isRawMat(t)) then
			HoardReason = "epic craft mats for future"
			return true
		end
		--[[  No; Poisons are useless
		if t == ITEMTYPE_POISON and quality > QUALITY_FINE then
			HoardReason = "superior poisons for future"
			return true
		end
		]]--
	end

	if char == CJRAB.ROLE_INGREDIENTS then
		-- Provisioning ingredients not marked as Writ
		if t == ITEMTYPE_INGREDIENT and not is_writ(cbag,slot) then
			HoardReason = "unused ingredient hoard"
			return true
		end
	end

	if char == CJRAB.ROLE_ARCHIVE then
		if isArchiveType(link, t, st) and is_reserved(cbag,slot) then
			HoardReason = "to archive hoard"
			return true
		end
	end

	if char == CJRAB.ROLE_LOWMATS then
		-- out-leveled Equip crafting mats
		if quality < QUALITY_FINE and
					isUnderCraftRank(CJRAB.CrafterRank, link, t) and
					not isEqualCraftRank(CJRAB.ALTCraftRank, link, t) then
			HoardReason = "outleveled mat hoard"
			return true
		end
	end

	return false
end


--=====================================
local function isInOtherCharHoard(char, cbag, slot)
	-- Return the charID if the item in cbag/slot is in another character's hoard
	-- (not char's), or nil otherwise.
	for c = 1, #CJRAB.Chars do
		if c ~= char then
			if isInCharHoard(c, char, cbag, slot) then return c end
		end
	end
	return nil
end


--=====================================
local function isInBankHoard(bankBag, cbag, slot)
	-- Return true if the item in cbag/slot is in the bankBag hoard.
	-- cbag is a CloneBag; bankBag is a standard bag ID (index)
	-- NB: isInCharHoard takes precedence
	-- if true then return false end		-- for debugging
	local item = cbag:GetItem(slot)
	local t, st = item.t, item.st
	local link = item.link
	local quality = GetItemLinkQuality(link)

	-- skip all reserved items unless they are ArchiveType
	if not isArchiveType(link, t, st) and is_reserved(cbag, slot) then
		return false
	end

	---------------------------------------
	if bankBag == BAG_BANK then

		if not CJRAB_ROLE_ENCHANT and isEnchant(t)
				and quality <= QUALITY_SUPERIOR then
			HoardReason = "enchant hoard in bank"
			return true
		end

		if t== ITEMTYPE_RECIPE and IsItemLinkRecipeKnown(link) then
			HoardReason = "recipe for any takers"
			return true
		end

		if	t == ITEMTYPE_RACIAL_STYLE_MOTIF then
			HoardReason = "style motif for any takers"
			return true
		end

		if isStyleMat(link, t) and CJRAB.WritStyleMatsInBank and
						is_writ(cbag,slot) then
			HoardReason = "writ style mat for any takers"
			return true
		end

		if st == SPECIALIZED_ITEMTYPE_TROPHY_SCROLL then
			-- exceptions...
			local id = GetItemLinkItemId(link)
			if id ~= ITEMID_COUNTERFEIT_PARDON_EDICT then
				HoardReason = "scroll for all to use"
				return true
			end
		end

		-- Equip Writ mats for current ALT rank
		if quality < QUALITY_FINE and
					isEqualCraftRank(CJRAB.ALTCraftRank, link, t) then
			HoardReason = "current ALT writ mats"
			return true
		end

		-- Alchemy and Provisioning Writ mats (manually marked)
		if isAlchemy(t) or
					t == ITEMTYPE_POTION_BASE or
					t == ITEMTYPE_POTION or
					t == ITEMTYPE_INGREDIENT or
					t == ITEMTYPE_FOOD or
					t == ITEMTYPE_DRINK then
			if is_writ(cbag, slot) then
				HoardReason = "marked for writs"
				return true
			end
		end

		-- Bank all unknown trait Research items for RESEARCHER
		-- (but leave them in the bank)
		if CJRAB.ResearchablesInBank and
					isUnresearchedTraitItem(CJRAB.ROLE_RESEARCH, link, t) then
			HoardReason = "for " ..  
				CJRAB.CharName(CJRAB.ROLE_RESEARCH) ..
				" to research [banked]"
			return true
		end

		-- Save any (unequipped) CP160 >=epic gear in the bank
		if		CJRAB.BankCP160Gear and
			   (isArmor(link, t) or isWeapon(link, t) or isJewelry(link, t)) and
				quality >= QUALITY_EPIC and
				GetItemLinkRequiredChampionPoints(link) >= 160 then
			HoardReason = "epic CP160 gear for any takers"
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
	local cbag = CJRAB.TransferBags[BAG_BACKPACK]

	for slot in cbag:Items() do
		local item = cbag:GetItem(slot)
--		Dbg("depositHoardables: [%d] = %s", slot, cbag:ItemName(slot))
		HoardReason = ""

		if 		not item.isCharBound and 
				not item.isStolen and
		   		not item.isJunk and
--		   		not item.isUnique and		-- Treasure Maps are unique
				not isInCharHoard(char, char, cbag, slot) then

			-- first check if it is in another char's hoard
			local reason = nil
			HoardReason = ""
			local c = isInOtherCharHoard(char, cbag, slot)
			if c then
				reason = "for " .. CJRAB.CharName(c)
			elseif isInBankHoard(bankBag, cbag, slot) then
				-- otherwise if it is in the bank's hoard
				reason = "for " .. CJRAB.BagName(bankBag)
			end

			if reason then
				if HoardReason ~= "" then
					reason = reason .. ", " .. HoardReason
				end
				if onlyFillExisting then
					CJRAB.TransferFill(BAG_BACKPACK, slot, bankBag, reason)
				else
					CJRAB.Transfer(BAG_BACKPACK, slot, bankBag, reason)
				end
			end
		end
	end
end

--=====================================
local function isCraftBaggable(item)
	-- return item.id == 0xb31b		-- Jejota
	return CanItemLinkBeVirtual(item.link)
end

--=====================================
local function CJRHasCraftBagAccess()
	if not CJRAB.EnableCraftBag then return false end
	return HasCraftBagAccess()
end

--=====================================
local function withdrawHoardables( char, bankBag )
	local str, count
	local bbag = CJRAB.TransferBags[bankBag]
	for slot in bbag:Items() do
		HoardReason = ""
		if isInCharHoard(char, char, bbag, slot) then
			CJRAB.Transfer(bankBag, slot, BAG_BACKPACK, HoardReason)
		elseif CJRHasCraftBagAccess() and 
									isCraftBaggable(bbag:GetItem(slot)) then
			HoardReason = "for CraftBag"
			CJRAB.Transfer(bankBag, slot, BAG_BACKPACK, HoardReason)
		end
	end
end

--=====================================
local function depositCraftBag( char )
	local str, count
	local cbag = CJRAB.TransferBags[BAG_BACKPACK]
	if not CJRHasCraftBagAccess() then return end

	for slot in cbag:Items() do
		if isCraftBaggable(cbag:GetItem(slot)) then
			CJRAB.Transfer(BAG_BACKPACK, slot, BAG_VIRTUAL, "")
		end
	end
end


--=============================================================================
-- Currencies

--=====================================
local function withdrawCurrency(char, curt, reserve)
	local amount, src, dst
	amount = GetCurrencyAmount(curt, CURRENCY_LOCATION_BANK)
	amount = amount - reserve
	if amount > 0 then
		src = CURRENCY_LOCATION_BANK
		dst = CURRENCY_LOCATION_CHARACTER
		Msg("Withdrawing %d %s", amount, 
			CJRAB.GetString('CJRAB_SI_CURRENCY', curt))
		if not CJRAB.DryRun then
			TransferCurrency( curt, amount, src, dst)
		end
	end
end

--=====================================
local function depositCurrency(char, curt, reserve)
	local amount, src, dst
	amount = GetCurrencyAmount(curt, CURRENCY_LOCATION_CHARACTER)
	amount = amount - reserve
	if amount > 0 then
		src = CURRENCY_LOCATION_CHARACTER
		dst = CURRENCY_LOCATION_BANK
		Msg("Depositing %d %s", amount,
			CJRAB.GetString('CJRAB_SI_CURRENCY', curt))
		if not CJRAB.DryRun then
			TransferCurrency( curt, amount, src, dst)
		end
	end
end

--=====================================
local function transferCurrencies(char)

	if char == CJRAB.ROLE_MONEY then
		-- withdraw all gold
		withdrawCurrency( char, CURT_MONEY, 0)
	else
		-- ALT: deposit all but 999G
		depositCurrency( char, CURT_MONEY, 999)
	end
	-- deposit all Tel Var stones
	depositCurrency( char, CURT_TELVAR_STONES, 0)
	-- deposit all Alliance Points
	depositCurrency( char, CURT_ALLIANCE_POINTS, 0)
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

	-- set some global vars for the duration of banking
	PlayerChar = char
	for craft, _ in ipairs(DeconstructItems) do
		DeconstructItems[craft] = 0
	end


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

	-- Initialize all the CloneBags
	CJRAB.InitTransfer(bankBag)		-- NB: discards any pending transfers

	-- Deposit any CraftBag items to clear space
	depositCraftBag(char)

	-- Deposit all bankables to existing stacks to clear backpack
	CountCharDC = true
	depositHoardables(char, bankBag, true)

	-- Withdraw all char-specific collectibles to clear bank space
	-- (includes any craftables for CraftBag deposit)
	CountCharDC = true
	withdrawHoardables(char, bankBag)

	-- Deposit any CraftBag items again
	depositCraftBag(char)

	-- Deposit all bankable now
	CountCharDC = false
	depositHoardables(char, bankBag)

	-- Initiate the transfer
	CJRAB.ProcessTransfer()

	-- Deposit/withdraw currency
	transferCurrencies(char)

	if CJRAB.DryRun then
		Msg("DryRun complete.")
	end
end

--=====================================
function CJRAB.CloseBanking(bankBag)
	-- XXX: Free up the CloneBags

	for craft, count in ipairs(DeconstructItems) do
		if count > 0 then
			Msg( "%d %s items to deconstruct.", count, 
					CJRAB.GetString('CJRAB_SI_CRAFTINGTYPE', craft))
		end
	end

	Msg("See you next time.")
end

--=====================================
function CJRAB.Inventory(bag, slot, reason)
	-- inventory bag/slot has changed
	-- NB: operate directly on bag slots, not on CloneBags
	local charname = GetUnitName("player")
	local char = CJRAB.GetChar(charname)
	local t, st = GetItemType(bag, slot)
	local link = GetItemLink(bag, slot)
	local quality = GetItemLinkQuality(link)
	local trait = GetItemLinkTraitInfo(link)
	local isJunk = false

	---------------------------------------
	-- trash
	if t == ITEMTYPE_TRASH then isJunk=true end
	if quality == ITEM_QUALITY_TRASH and (
				-- XXX: explicitly list each type here...
				t == ITEMTYPE_FOOD or t == ITEMTYPE_DRINK ) then
		isJunk = true
	end
	-- XXX: be careful here, some good rewards are Ornate...
	if quality < QUALITY_FINE then
		-- green+ stuff is DC'd for mats
		if trait == ITEM_TRAIT_TYPE_WEAPON_ORNATE then isJunk=true end
		if trait == ITEM_TRAIT_TYPE_ARMOR_ORNATE then isJunk=true end
 		if trait == ITEM_TRAIT_TYPE_JEWELRY_ORNATE then isJunk=true end
	end
	-- junk ordinary jewelery mats if we don't have Summerset
	if not CJRAB.HasJewelcrafting  then
		if quality < QUALITY_FINE and isJewelryMat(link, t) then
			isJunk = true
		end
	end

	if CJRAB.JunkUnusedIngredients then
		if t == ITEMTYPE_INGREDIENT and not is_writ(bag,slot) then
			if quality < QUALITY_FINE then
				isJunk = true
			end
		end
	end

	-- treasure items
	if st == SPECIALIZED_ITEMTYPE_TREASURE and not IsItemStolen(bag, slot) then
		isJunk = true
	end

	-- all poisons except Crown
	if t == ITEMTYPE_POISON and
					GetItemLinkItemId(link) ~= ITEMID_CROWN_POISON then
		isJunk = true
	end


	---------------------------------------
	if isJunk then
		Msg("%s marked as junk", CJRAB.ItemName(bag, slot))
		SetItemIsJunk(bag, slot, true)
	end

end
