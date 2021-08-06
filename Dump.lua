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
	local slot
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
		-- msg = msg .. " style=" .. dstr('ITEM_STYLE_NAME', style)
		msg = msg .. " style=" .. dstr('SI_ITEMSTYLE', style)
		msg = msg .. string.format(" race=%d:%s",
					GetUnitRaceId("player"),
					GetUnitRace("player") )
		-- if IsSmithingStyleKnown(style,...?

	end

	trait = GetItemLinkTraitInfo(link)
	if trait > 0 then
		msg = msg .. " trait=" .. dstr('SI_ITEMTRAITTYPE', trait)
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
	local leoId, craft
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

