-- boilerplate for each source file to encapsulate everything in CJRAB:
if CJRAB == nil then CJRAB = {} end
local CJRAB = CJRAB

-- shortcut aliases
local Msg						= CJRAB.Msg
local Err						= CJRAB.Err
local Dbg						= CJRAB.Dbg


--=============================================================================
-- Dump an item's info

--=====================================
local function hms(time)
	local h = math.floor(time/3600)
	local m = math.floor(math.mod(time,3600)/60)
	local s = math.floor(math.mod(time,60))
	return string.format("%d:%02d:%02d", h, m, s)
end

--=====================================
local function dstr(stype, n)
	-- Returns formatted "[%d]%s" for n where stype is the string type of n
	local s
	s = CJRAB.GetString(stype, n)
	if s then
		s = string.format("%d:%s", n, s)
	else
		s = tostring(n)
	end
	return s
end


--=====================================
function CJRAB.DumpBag(bag, pat)
	for slot = 0, GetBagSize(bag)-1 do
		if HasItemInSlot(bag, slot) then
			if pat and pat ~= "" then
				local link = GetItemLink(bag, slot)
				local name = GetItemLinkName(link)
				name = LocalizeString("<<1>>", name)
				name = name:lower()
				pat = pat:lower()
				match = name:find(pat, 1, true)
				-- Msg( "find(%s, %s)", name, pat)
			else
				match = true
			end
			if match then
				CJRAB.DumpSlot(bag, slot)
			end
		elseif not pat or pat == "" then
			d(string.format("%s[%d]: EMPTY", CJRAB.BagName(bag), slot))
		end
	end
end

--=====================================
function CJRAB.DumpSlot(bag, slot)
	local link = GetItemLink(bag, slot, LINK_STYLE_BRACKETS)
	local icon, stack, sellprice, usable, locked, equiptype, style, quality =
		GetItemInfo(bag, slot)
	local stack, max =  GetSlotStackSize(bag, slot)

	local msg = string.format("%s[%d]: %d/%d [0x%x]%s '%s'",
		CJRAB.BagName(bag), slot,
		stack, max,
		GetItemId(bag, slot), zo_strformat(SI_TOOLTIP_ITEM_NAME, link),
		GetItemLinkName(link)
	)
	t, st = GetItemType(bag, slot)
	msg = msg .. " type=" .. dstr('SI_ITEMTYPE', t)
	msg = msg .. " stype=" .. dstr('SI_SPECIALIZEDITEMTYPE', st)

	msg = msg .. " lfilter=" .. dstr('SI_ITEMFILTERTYPE',
					GetItemLinkFilterTypeInfo(link))

	msg = msg .. " qual=" .. dstr('SI_ITEMQUALITY', quality)
	msg = msg .. " lvl=" ..  GetItemLevel(bag, slot)
	if style > 0 then
		msg = msg .. string.format(" style=%d:%s", style,
					GetItemStyleName(style))
		if IsSmithingStyleKnown(style) then
			msg = msg .. "[COLLECTED]"
		end
	end

	trait = GetItemLinkTraitInfo(link)
	if trait > 0 then
		msg = msg .. " trait=" .. dstr('SI_ITEMTRAITTYPE', trait)
		local CS = CraftStoreFixedAndImprovedLongClassName
		if CS and C_MAIN then
			local craft, line, trait = CS.GetTrait(link)
			if craft then
				local charname = CJRAB.CharName(C_MAIN)
				local state= CS.Data.crafting.researched[charname][craft][line][trait]
				if state == true then
					msg = msg .. string.format("[KNOWN by %s]", charname)
				elseif state == false then
					msg = msg .. string.format("[UNKNOWN by %s]", charname)
				else
					msg = msg .. string.format("[%s is RESEARCHING]", charname)
				end
			end
		end
	end


	if IsItemChargeable(bag, slot) then
		local charge, maxcharge = GetChargeInfoForItem(bag, slot)
		if charge>0 or maxcharge>0 then
			msg = msg .. string.format(" charge=%d/%d", charge, maxcharge)
		end
	end

	msg = msg .. " reqrank=" ..  GetItemLinkRequiredCraftingSkillRank(link)

	if t == ITEMTYPE_ARMOR then
		msg = msg .. " armtyp=" ..  
		dstr('SI_ARMORTYPE',   GetItemLinkArmorType(link))
	elseif t == ITEMTYPE_WEAPON then
		msg = msg .. " weaptyp=" ..  
		dstr('SI_WEAPONTYPE',   GetItemLinkWeaponType(link))
	end

	local ctype = GetItemLinkCraftingSkillType(link)
	if ctype > 0 then
		msg = msg .. " craft=" ..  
		dstr('CJRAB_SI_CRAFTINGTYPE',   ctype)
	end
	

	local known = IsItemLinkRecipeKnown(link)
	if known then msg = msg .. " KNOWN" end

	-- if IsItemPlayerLocked(bag, slot) then
	if locked then msg = msg .. " LOCKED" end


	-- Defunct; not useful
--	msg = msg .. " mlvl=" ..  GetItemLinkMaterialLevelDescription(link)

	d(msg)
end


--=====================================
function CJRAB.DumpLaundry()
	local launder_max, launder_used, launder_time =
				GetFenceLaunderTransactionInfo()
	local fence_max, fence_used, fence_time =
				GetFenceSellTransactionInfo()
	d(string.format("Fence: %d/%d (reset %s)   Launder: %d/%d (reset: %s)",
		fence_used, fence_max, hms(fence_time),
		launder_used, launder_max, hms(launder_time)))
end

--=====================================
function CJRAB.DumpCraft(name)
	-- dump craft info for char named 'name'.

	CJRAB.FetchLeoData()
	local cdata = CJRAB.LeoData[CJRAB.GetChar(name)]
	if not cdata then
		d(string.format("No craft info for '%s'", name))
		return
	end
	for leoId, craft in pairs(cdata.skills.craft) do
		local cname = craft.name
		local clvl = craft.rank
		-- NB: first skill is always the leveling one
		local crank = craft.list[1].level
		local cskillname = craft.list[1].name

		d(string.format("%s:  %d:%s lvl=%d  rank=%d [%s]",
			name, leoId, cname,
			clvl, crank,
			cskillname))
	end
end

--=====================================
function CJRAB.DumpChar(str)
	-- dump our char info for char named 'str', or all if 'all'
	if not str or str == "" then str = GetUnitName("player") end
	for i = 1, #CJRAB.Chars do
		local c = CJRAB.Chars[i]
		if str == c.name or str == "all" then
			local msg
			msg = string.format("%d: %s", i, c.name)
			msg = msg ..  string.format(" level %d", c.level)
			if c.gender == GENDER_MALE then msg = msg .. " male"
			elseif c.gender == GENDER_FEMALE then msg = msg .. " female"
			elseif c.gender == GENDER_NEUTRAL then msg = msg .. " neutered"
			end
			msg = msg ..  string.format(" %d:%s",
						c.raceId, GetRaceName(c.gender, c.raceId))
			msg = msg ..  string.format(" %d:%s",
						c.classId, GetClassName(c.gender, c.classId))
			msg = msg ..  string.format(" [%d:%s]",
						c.allianceId, GetAllianceName(c.allianceId))
			msg = msg ..  string.format(" in %d:%s", 
						c.locationId, GetLocationName(c.locationId))
			d(msg)
		end
	end
end
--=====================================
function CJRAB.DumpCharRaw(str)
	-- dump raw char info for char named 'str', or all if 'all'
	if not str or str == "" then str = GetUnitName("player") end

	for i = 1, GetNumCharacters() do
		local name, gender, level, classId, raceId,
					allianceId, id, locationId = GetCharacterInfo(i)
		if str == name or str == "all" then
			local msg
			msg = string.format("%d: %s [%s]:", i, zo_strformat("<<1>>",name), id)
			msg = msg ..  string.format(" level %d", level)
			if gender == GENDER_MALE then msg = msg .. " male"
			elseif gender == GENDER_FEMALE then msg = msg .. " female"
			elseif gender == GENDER_NEUTRAL then msg = msg .. " neutered"
			end
			msg = msg ..  string.format(" %d:%s", 
						raceId, GetRaceName(gender, raceId))
			msg = msg ..  string.format(" %d:%s", 
						classId, GetClassName(gender, classId))
			msg = msg ..  string.format(" [%d:%s]", 
						allianceId, GetAllianceName(allianceId))
			msg = msg ..  string.format(" in %d:%s", 
						locationId, GetLocationName(locationId))
			d(msg)
		end
	end
end

