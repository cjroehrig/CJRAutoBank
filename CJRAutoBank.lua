-- boilerplate for each source file to encapsulate everything in CJRAB:
if CJRAB == nil then CJRAB = {} end
local CJRAB = CJRAB

--=============================================================================
-- Globals
CJRAB.AddonName = 'CJRAutoBank'

-- these can be toggled via slashcommands
CJRAB.Logging		= true			-- log all inventory in/out
CJRAB.Debug			= false			-- log debug messages
CJRAB.DryRun		= false			-- don't do any transfers

-- TransferQueue
CJRAB.TransferQueue = {}
CJRAB.TransferBags = {}
CJRAB.TransferQueueIndex = 1
CJRAB.TransferDelay	= 250	 -- Delay between bag transfers in ms


--=============================================================================
-- Output, debugging and console I/O

--=====================================
function CJRAB.Msg(fmt, ...)
	-- printf to the active chat window
	--CHAT_SYSTEM:AddMessage(string.format(fmt, ...))
	if CJRAB.DryRun then
		d("CJRAB(DryRun): " .. string.format(fmt, ...))
	else
		d("CJRAB: " .. string.format(fmt, ...))
	end
end

function CJRAB.Err(fmt, ...)
	d("CJRAB: ERROR: " .. string.format(fmt, ...))
end

function CJRAB.Dbg(fmt, ...)
	if CJRAB.Debug then
		d("DEBUG> " .. string.format(fmt, ...))
	end
end

local Msg						= CJRAB.Msg
local Err						= CJRAB.Err
local Dbg						= CJRAB.Dbg

--=============================================================================
-- GetString with CUSTOM SI_ types

-- CRAFTING_TYPE_*
-- XXX: use GetSkillLineInfo to fill this in...?
CJRAB_SI_CRAFTINGTYPE = {
	[0]="NO_CRAFT",
	"Blacksmithing", "Clothing", "Enchanting", "Alchemy",
	"Provisioning", "Woodworking", "Jewelcrafting" }


-- bag name
CJRAB_SI_BAGNAME = {
	[0] = "EQUIP_BAG",
	"Backpack",					-- 1
	"Bank",						-- 2
	"GuildBank",				-- 3
	"BuyBackBag",				-- 4
	"VirtualBag",				-- 5
	"SubscriberBank",			-- 6
	"HouseBank1",				-- 7
	"HouseBank2",				-- 8
	"HouseBank3",				-- 9
	"HouseBank4",				-- 10
	"HouseBank5",				-- 11
	"HouseBank6",				-- 12
	"HouseBank7",				-- 13
	"HouseBank8",				-- 14
	"HouseBank9",				-- 15
	"HouseBank10",				-- 16
	"DeleteBag",				-- 17
}

--=====================================
function CJRAB.GetString(stype, n)
	-- like GetString but with custom CJRAB_SI tables
	local s = nil
	if stype then
		if stype:find("^CJRAB_SI_") then
			-- custom table
			local table = _G[stype]
			s = table[n]
		else
		-- elseif stype:find("^SI_") then
			s = GetString(stype, n)
		end
	end
	return s
end

--=============================================================================
-- Character
CJRAB.Chars = nil

function CJRAB.InitChars()
	-- initialize character table
	CJRAB.Chars = {}
	for i = 1, GetNumCharacters() do
		local name, gender, level, classId, raceId,
					allianceId, id, locId = GetCharacterInfo(i)
		local enabled = false
		if CJRAB.CharsEnabled then
			enabled = CJRAB.CharsEnabled[i]
		end
			
		CJRAB.Chars[i] = {
			name		= zo_strformat("<<1>>", name),
			gender  	= gender,
			level		= level,
			classId		= classId,
			raceId		= raceId,
			allianceId 	= allianceId,
			locationId	= locId,
			enabled		= enabled,
		}
	end
end

--=====================================
function CJRAB.CharName(char)
	-- return the character name for id 'char'
	return CJRAB.Chars[char].name
end

--=====================================
function CJRAB.GetChar(str)
	-- Return the char index for character called str.
	for i = 1, #CJRAB.Chars do
		if CJRAB.Chars[i].name == str then
			return i
		end
	end
	return nil
end

--=============================================================================
-- MISC UTILITY FUNCTIONS


--=====================================
function CJRAB.ItemName(bag, slot)
	-- Return the item's name (as it appears in the tooltip).
	local link = GetItemLink(bag, slot, LINK_STYLE_BRACKETS)
	return CJRAB.ItemLinkName(link)
end

--=====================================
function CJRAB.ItemLinkName(link)
	-- Return the item's name (as it appears in the tooltip).
	return zo_strformat(SI_TOOLTIP_ITEM_NAME, link)
end

--=====================================
function CJRAB.BagName(bag)
	-- Return the bag's name
	return CJRAB.GetString( 'CJRAB_SI_BAGNAME', bag)
end

--=====================================
function CJRAB.BagItems(bag)
	-- return an iterator for all slots containing items in bag
	local size = GetBagSize(bag)
	local slot = -1		-- slots are offset 0
	return function()
		slot = slot + 1
		while slot < size do
			if HasItemInSlot(bag, slot) then
				return slot
			end
			slot = slot + 1
		end
	end
end

--=====================================
function CJRAB.IsCharBound(bag, slot)
	return  IsItemBound(bag, slot) and
			GetItemBindType(bag, slot) == BIND_TYPE_ON_PICKUP_BACKPACK
end

--=====================================
function CJRAB.FetchLeoData()
	-- Set up a global table CJRAB.LeoData indexed by char id
	-- with data fetched from LeoAltholic
	if not LeoAltholic then return end
	if not CJRAB.LeoData then CJRAB.LeoData = {} end
	for char = 1, #CJRAB.Chars do
		CJRAB.LeoData[char] = LeoAltholic.GetCharByName(CJRAB.CharName(char))
	end
end

--=====================================
function CJRAB.GetLeoCraftID(ctype)
	-- Return LeoAltholic's craft ID (index) for CRAFTING_TYPE ctype.
	for leoId, cId in ipairs(LeoAltholic.allCrafts) do
		if cId == ctype then
			return leoId
		end
	end
	return nil
end



--=============================================================================
-- Logging

--=====================================
function CJRAB.LogSlotUpdate(bag, slot, isNew, change)
	-- Log a slot change message
	local msg

	if change < 0 then
		-- no info available for items removed :(
		--[[		-- don't bother logging
		change = -change
		if change > 1 then
			msg = string.format("%d items removed", change)
		else
			msg = "item removed"
		end
		--]]
		return
	else
		if change > 0 then
			if isNew then
				msg = "added"
			else
				msg = "transferred in"
			end
			if change > 1 then
				msg = msg .. " " .. tostring(change)
			end
		else
			msg = "changed"
		end
		msg = string.format("%s %s (total: %d)",
			msg,
			CJRAB.ItemName(bag, slot),
			GetSlotStackSize(bag, slot))
	end
	d(string.format("%s: %s", CJRAB.BagName(bag), msg))
end

--=====================================
function CJRAB.LogTradeHousePurchase(event, index)
	-- idx is the pendingPurchaseIndex... XXX: of what?
	local countstr = ""
	local unitstr = ""
	local icon, name, quality, count, seller, timeRemaining, 
		price, currency, id, pricePerUnit =
		GetTradingHouseSearchResultItemInfo(index)
	local link = GetTradingHouseSearchResultItemLink(index, 1)
	if count > 1 then
		countstr = count .. " "
		unitstr = "(" .. pricePerUnit .. " ea)"
		-- unitstr = string.format("(%.2f ea)", price/count)
	end
	Msg("Buying %s%s from %s for %d G %s",
		countstr, CJRAB.ItemLinkName(link), seller, price, unitstr)
end

--=============================================================================
-- TRANSFERS (move from one bag to another)
-- All transfers use a queue to do the actual transfers
-- which is processed asynchronously by an Update event loop
-- every CJRAB.TransferDelay milliseconds.
-- Because of this, we need to plan the transfers in advance
-- (which slots fill up, which ones are free, etc) on a
-- "clone" of the two bags which we update stack sizes on.

--=========================================================
-- CloneBag object
local function cloneBag(bag)
	-- returns a cloneBag of bag that we can operate on
	-- and change quantities to plan out the transfers
	local this = {
		bag = bag;
		items = {};
	--=====================================
	-- more-or-less clone of the relevant bag API...
	GetBagSize = function(self)
		return #self.items
	end;
	BagName = function(self)
		return CJRAB.BagName(self.bag)
	end;
	GetItemLink = function(self, slot)
		return self.items[slot+1].link
	end;
	HasItemInSlot = function(self, slot)
		return self.items[slot+1].link ~= false
	end;
	GetItemId = function(self, slot)
		return self.items[slot+1].id
	end;
	GetSlotStackSize = function(self, slot)
		return self.items[slot+1].stack, self.items[slot+1].max
	end;
	ItemName = function(self, slot)
		local link = self:GetItemLink(slot)
		if link then
			return zo_strformat(SI_TOOLTIP_ITEM_NAME, link)
		else
			return ""
		end
	end;
	FindFirstEmptySlotInBag = function(self)
		for slot = 0, self:GetBagSize()-1 do
			if not self:HasItemInSlot(slot) then
				return slot
			end
		end
		return false
	end;

	--=====================================
	Items = function(self)
		-- return an iterator for all slots containing items in bag
		local size = #self.items
		local slot = 0
		return function()
			slot = slot + 1
			while slot <= size do
				if self:HasItemInSlot(slot) then
					return slot-1
				end
				slot = slot + 1
			end
		end
	end;

	--=====================================
	AddItem = function(self, slot, sbag, sslot, count)
		-- Add count items from source bag sbag/sslot to slot
		local id = sbag:GetItemId(sslot)
		if self:HasItemInSlot(slot) then
			-- existing item
			if self:GetItemId(slot) == id then
				local stack, max = self:GetSlotStackSize(slot)
				if stack + count > max then
					Err("cloneBag:AddItem: %s[%d]: %d + %d would exceed max=%d",
						self:BagName(), slot,
						stack, count, max)
					return 0
				end
				self.items[slot+1].stack = stack + count
				return count
			else
				Err("cloneBag:AddItem: %s[%d] contains different item: %s",
					self:BagName(), slot,
					self:ItemName(slot))
				return 0
			end
		else
			-- new slot; copy data from sbag
			Dbg("cloneBag:AddItem: copying data from %s[%s]: %s",
				sbag:BagName(), sslot, sbag:ItemName(sslot))

			local stack, max = sbag:GetSlotStackSize(sslot)
			slot = slot+1 -- cloneBag.items uses offset 1 
			self.items[slot].link = sbag:GetItemLink(sslot)
			self.items[slot].id = sbag:GetItemId(sslot)
			self.items[slot].stack = count
			self.items[slot].max = max
			return count
		end
	end;

	--=====================================
	RemoveItem = function(self, slot, count)
		-- Remove count items from source bag sbag/sslot to slot
		local stack, max = self:GetSlotStackSize(slot)
		if count > stack then
			Err("cloneBag:AddItem: %s[%d]: remove %d exceeds stack %d",
				self:BagName(), slot, count, stack)
			return 0
		end
		slot = slot+1 -- cloneBag.items uses offset 1 
		self.items[slot].stack = stack - count
		if self.items[slot].stack == 0 then
			-- empty slot
			self.items[slot].id = false
			self.items[slot].link = false
			self.items[slot].max = 0
		end

		return count
	end;

	--=====================================
	Transfer = function(self, slot, dbag, dstSlot, count, msg)
		-- Transfer the item in slot to the clone bag dbag
		-- this is essentially the same as do_transfer but operates
		-- immediately on the clone bags.
		Dbg( "cloneBag:Transfer %s[%s] --> %s[%s]   %d %s '%s'",
			self:BagName(), slot,
			dbag:BagName(), dstSlot,
			count, self:ItemName(slot),
			msg
			)

		dbag:AddItem(dstSlot, self, slot, count)
		self:RemoveItem(slot, count)
	end;
	}

	-- copy the bag contents into our instance
	for slot = 0, GetBagSize(bag)-1 do
		if HasItemInSlot(bag, slot) then
			local stack, max = GetSlotStackSize(bag, slot)
			this.items[slot+1] = {
				link = GetItemLink(bag, slot, 1),
				id = GetItemId(bag, slot),
				stack = stack,
				max = max
			}
		else
			this.items[slot+1] = { link = false, id = false, stack =0, max = 0 }
		end
	end
	return this
end



--=====================================
function CJRAB.ResetTransfer()
	CJRAB.TransferQueue = {}
	CJRAB.TransferQueueIndex = 1
end
--=====================================
function CJRAB.InitTransfer(bankBag)
	-- reset any pending transfer Queue and prepare for a new
	-- transfer between backpack and bankBag
	-- for a new transfer
	CJRAB.ResetTransfer()

	-- set up the working plan cloneBags
	for i = 1, BAG_MAX_VALUE do
		CJRAB.TransferBags[i] = {}
	end
	CJRAB.TransferBags[bankBag] = cloneBag(bankBag)
	CJRAB.TransferBags[BAG_BACKPACK] = cloneBag(BAG_BACKPACK)
end


--=====================================
function CJRAB.ProcessTransfer()
	-- Process the TransferQueue in an asynchronous update loop.
	-- Every CJRAB.TransferDelay ms, dequeue the next function and execute it.

	-- disable Logging during this (extraneous messages)
	local saved_logging = CJRAB.Logging
	CJRAB.Logging = false
	-- re-enable it after a delay (just add to the TxQueue)
	-- XXX: not enough delay though; get a logged msg at the end
	table.insert(CJRAB.TransferQueue, function()
						CJRAB.Logging = saved_logging end)

	local delay = CJRAB.TransferDelay
	if not delay then delay = 1000 end
	if delay < 250 then delay = 250 end		-- don't attract ZMax attention
	EVENT_MANAGER:RegisterForUpdate(CJRAB.AddonName, delay,
		function()
			if CJRAB.TransferQueueIndex <= #CJRAB.TransferQueue then
				local func = CJRAB.TransferQueue[CJRAB.TransferQueueIndex]
				CJRAB.TransferQueueIndex = CJRAB.TransferQueueIndex + 1
				func()
			else
				CJRAB.ResetTransfer()
				EVENT_MANAGER:UnregisterForUpdate(CJRAB.AddonName)
			end
		end)
end


--=====================================
local function do_transfer(bag, slot, dstBag, dstSlot, count, msg)
	-- Transfer count items from bag/slot to dstBag/dstSlot.
	-- NB: This is run asychronously.
	-- msg is a message to display when the transfer is done
	local ret, str
	Dbg( "RequestMoveItem %s[%s] --> %s[%s]   %d %s",
		CJRAB.BagName(bag), slot,
		CJRAB.BagName(dstBag), dstSlot,
		count, CJRAB.ItemName(bag, slot)
		)
	if not CJRAB.DryRun then
		ret, str = CallSecureProtected('RequestMoveItem',
							bag, slot, dstBag, dstSlot, count)
		if not ret then
			Msg(".    RequestMoveItem FAILED: %s", str)
		end
	end
	-- output message
	if msg then
		Msg(msg)
	end
end

--=====================================
local function getExistingSlot(cbag, id)
	-- Return (slot, avail) for the first existing (non-full) slot in
	-- in cloneBag cbag containing an item with the given id
	-- (avail is the available space).
	for slot = 0, cbag:GetBagSize()-1 do
		if cbag:GetItemId(slot) == id then
			local size, max = cbag:GetSlotStackSize(slot)
			if size < max then
				return slot, max-size
			end
		end
	end
	return false
end

--=====================================
local function makeTxMessage(bag, slot, dstBag, tx_count, reason)
	local msg
	if dstBag == BAG_BACKPACK then
		msg = CJRAB.BagName(bag) .. ": withdrew"
	else -- bag == BAG_BACKPACK
		msg = CJRAB.BagName(dstBag) .. ": deposited"
	end
	if tx_count > 1 then msg = msg .. ' ' .. tx_count end
	msg = msg .. " " .. CJRAB.ItemName(bag, slot)
	if reason and reason ~= "" then
		msg = msg .. " " .. reason
	end
	return msg
end

--=====================================
function CJRAB.TransferFill(bag, slot, dstBag, reason)
	-- Transfer item from bag, slot to dstBag but only to an existing stack.
	-- No new stacks are created.
	-- Returns the count of the number of items transferred.
	local count, max, id, dst_slot, avail, msg
	local tx_count = 0
	local sbag = CJRAB.TransferBags[bag]
	local dbag = CJRAB.TransferBags[dstBag]

	-- count, max = GetSlotStackSize(bag, slot)
	count, max = sbag:GetSlotStackSize(slot)
	if count == max then return 0 end	-- full stack, forget it
	-- id = GetItemId(bag, slot)
	id = sbag:GetItemId(slot)
	dst_slot, avail = getExistingSlot(dbag, id)
	if dst_slot then
		if count <= avail then
			tx_count = count
		else
			tx_count = avail
		end
		msg = makeTxMessage(bag, slot, dstBag, tx_count, reason)

		table.insert(CJRAB.TransferQueue, function()
				do_transfer(bag, slot, dstBag, dst_slot, tx_count, msg) end)
		-- do the clone transfer to update quantities
		sbag:Transfer(slot, dbag, dst_slot, tx_count, msg)

	end
	return tx_count
end

--=====================================
function CJRAB.Transfer(bag, slot, dstBag, reason)
	-- Transfer item from bag,slot to dstBag
	-- creates another slot if required and available.
	-- Returns the count of the number of items transferred.
	local count, max, dst_slot, avail, msg
	local tx_count = 0
	local sbag = CJRAB.TransferBags[bag]
	local dbag = CJRAB.TransferBags[dstBag]

	-- count, max = GetSlotStackSize(bag, slot)
	count, max = sbag:GetSlotStackSize(slot)

	-- Fill any existing slot
	tx_count = CJRAB.TransferFill(bag, slot, dstBag, reason)

	-- transfer any remainder
	count = count - tx_count
	if count > 0 then
		tx_count = count

		-- find an empty slot
		dst_slot = dbag:FindFirstEmptySlotInBag()
		if not dst_slot then
			Msg("No space in %s for %s",
				CJRAB.BagName(dstBag), CJRAB.ItemName(bag, slot))
			return 0
		end

		msg = makeTxMessage(bag, slot, dstBag, tx_count, reason)
		table.insert(CJRAB.TransferQueue, function()
				do_transfer(bag, slot, dstBag, dst_slot, tx_count, msg) end)
		-- do the clone transfer to update quantities
		sbag:Transfer(slot, dbag, dst_slot, tx_count, msg)
	end

	return tx_count
end



--=============================================================================
-- HANDLER: EVENT_INVENTORY_SINGLE_SLOT_UPDATE
local function handle_slot(event, bag, slot, isNewItem,
				soundCat, reason, stackCountChange)
	if CJRAB.Logging then
		CJRAB.LogSlotUpdate(bag, slot, isNewItem, stackCountChange)
	end
	if stackCountChange > 0 then
		if CJRAB.Inventory then
			CJRAB.Inventory(bag, slot, reason)
		end
	end
end

--=============================================================================
-- HANDLER: EVENT_OPEN_BANK, EVENT_CLOSE_BANK
local function handle_open_bank(event, bankBag)
	if CJRAB.OpenBanking then
		CJRAB.OpenBanking(bankBag)
	end
end
local function handle_close_bank(event, bankBag)
	if CJRAB.CloseBanking then
		CJRAB.CloseBanking(bankBag)
	end
end

--=============================================================================
-- HANDLER: EVENT_TRADING_HOUSE_CONFIRM_ITEM_PURCHASE
local function handle_tradehouse_purchase(event, idx)
	CJRAB.LogTradeHousePurchase(event, idx)
end

--=============================================================================
-- HANDLER: EVENT_ADD_ON_LOADED
local function handle_addon_loaded(event, addonName)
	if addonName ~= CJRAB.AddonName then return end
	EVENT_MANAGER:UnregisterForEvent(CJRAB.AddonName, EVENT_ADD_ON_LOADED)
	CJRAB:Initialize()
end


--=============================================================================
-- INITIALIZE
function CJRAB:Initialize()
	-- initialize characters
	CJRAB.InitChars()

	-- handle_slot
	EVENT_MANAGER:RegisterForEvent( self.AddonName,
			EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
			handle_slot)
	EVENT_MANAGER:AddFilterForEvent( self.AddonName,
			EVENT_INVENTORY_SINGLE_SLOT_UPDATE, 
			REGISTER_FILTER_INVENTORY_UPDATE_REASON, 
			INVENTORY_UPDATE_REASON_DEFAULT)

	-- handle_bank
	EVENT_MANAGER:RegisterForEvent( self.AddonName, EVENT_OPEN_BANK,
			handle_open_bank)
	EVENT_MANAGER:RegisterForEvent( self.AddonName, EVENT_CLOSE_BANK,
			handle_close_bank)

	-- Guild Traders
	--[[   XXX: use AwesomeGuildStore instead (this doesn't work with it
	EVENT_MANAGER:RegisterForEvent( self.AddonName,
			EVENT_TRADING_HOUSE_CONFIRM_ITEM_PURCHASE,
			handle_tradehouse_purchase)
	--]]

	-- Slash commands
	SLASH_COMMANDS["/abdryrun"] = function(arg)
		CJRAB.DryRun = not CJRAB.DryRun
		d("CJRAB.DryRun = " .. tostring(CJRAB.DryRun))
	end

	SLASH_COMMANDS["/abdebug"] = function(arg)
		CJRAB.Debug = not CJRAB.Debug
		d("CJRAB.Debug = " .. tostring(CJRAB.Debug))
	end

	SLASH_COMMANDS["/ablogging"] = function(arg)
		CJRAB.Logging = not CJRAB.Logging
		d("CJRAB.Logging = " .. tostring(CJRAB.Logging))
	end

	SLASH_COMMANDS["/dumpbag"] = function(pat) CJRAB.DumpBag(BAG_BACKPACK, pat) end
	SLASH_COMMANDS["/dumpbank"] = function(pat) CJRAB.DumpBag(BAG_BANK, pat) end
	SLASH_COMMANDS["/dumpchar"] = function(name) CJRAB.DumpChar(name) end
	SLASH_COMMANDS["/dumpcharraw"] = function(name) CJRAB.DumpCharRaw(name) end

	-- User slash commands
	if CJRAB.SlashCommands then
		CJRAB.SlashCommands()
	end

end


EVENT_MANAGER:RegisterForEvent( CJRAB.AddonName, EVENT_ADD_ON_LOADED,
		handle_addon_loaded)

