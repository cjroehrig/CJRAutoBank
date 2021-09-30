-- boilerplate for each source file to encapsulate everything in CJRAB:
if CJRAB == nil then CJRAB = {} end
local CJRAB = CJRAB

-- shortcut aliases
local Msg						= CJRAB.Msg
local Err						= CJRAB.Err
local Dbg						= CJRAB.Dbg

--=============================================================================
-- CloneBagItem object
function CJRAB.CloneBagItem(bag, slot)
	-- Returns a CloneBag item with all the necessary info from (bag, slot)
	-- This item can be shuffled between bags when planning the Transfers

	local this = {
		link = false;
		id = false;
		stack =0;
		max = 0;
		isFCOMarked	= nil;

	--=====================================
	IsEmpty = function(self)
		-- Return true if this is an empty item
		return self.link == false
	end;

	--=====================================
	Copy = function(self)
		-- return a copy of this item
		local new = {}
		for k,v in pairs(self) do
			new[k] = v
		end
		if self.isFCOMarked ~= nil then
			new.isFCOMarked = {}
			for k,v in ipairs(self.isFCOMarked) do
				new.isFCOMarked[k] = v
			end
		end
		return new
	end;

	--=====================================
	CanStackWith = function(self, item)
		-- Return true if self can stack with item 
		if self:IsEmpty() or item:IsEmpty() then return false end
		if self.id ~= item.id then return false end
		if self.isStolen ~= item.isStolen then return false end
		if self.isCrownCrate ~= item.isCrownCrate then return false end
		if self.isCrownStore ~= item.isCrownStore then return false end
		if self.level ~= item.level then return false end
		return true
	end;

	}		-- end of instance vars & methods
	--=========================================================================
	-- Constructor

	if bag == nil or slot == nil then return this end	-- return empty item

	-- Create a clone of item in bag, slot
	if HasItemInSlot(bag, slot) then
		local stack, max = GetSlotStackSize(bag, slot)
		local t, st = GetItemType(bag, slot)
		this.link 			= GetItemLink(bag, slot, 1)
		this.id				= GetItemId(bag, slot)
		this.level			= GetItemLevel(bag, slot)
		this.stack			= stack
		this.max			= max
		this.t				= t
		this.st				= st
		this.isCharBound	= CJRAB.IsCharBound(bag, slot)
		this.isStolen		= IsItemStolen(bag, slot)
		this.isUnique		= IsItemLinkUnique(this.link)
		this.isJunk			= IsItemJunk(bag, slot)
		this.isCrownCrate	= IsItemFromCrownCrate(bag, slot)
		this.isCrownStore	= IsItemFromCrownStore(bag, slot)
		this.isFCOMarked	= nil
		-- Add FCOItemSaver icon info
		if FCOIS then
			this.isFCOMarked = {}
--			for i, name in ipairs(FCOIS.LAMiconsList) do
			for i = CJRAB.FCO_ICON_MIN, CJRAB.FCO_ICON_MAX do
				local marked  = FCOIS.IsMarked(bag, slot, i)
--				Dbg("CloneBag: FCOMarked: %d:%s = %s",
--									i, name, tostring(marked))
				this.isFCOMarked[i] = marked
			end
		end
	end

	return this
end

--=============================================================================
-- CloneBag object
function CJRAB.CloneBag(bag)
	-- returns a CloneBag of bag that we can operate on
	-- and change quantities to plan out the transfers.
	local this = {
		bag = bag;
		items = {};

	--=========================================================================
	-- more-or-less clone of the relevant official bag API...
	--=====================================
	GetBagSize = function(self)
		return #self.items
	end;

	--=====================================
	BagName = function(self)
		return CJRAB.BagName(self.bag)
	end;

	--=====================================
	GetItemLink = function(self, slot)
		local item = self:GetItem(slot)
		return item.link
	end;

	--=====================================
	GetItemType = function(self, slot)
		local item = self:GetItem(slot)
		return item.t, item.st
	end;

	--=====================================
	HasItemInSlot = function(self, slot)
		local item = self:GetItem(slot)
		return not item:IsEmpty()
	end;

	--=====================================
	GetItemId = function(self, slot)
		local item = self:GetItem(slot)
		return item.id
	end;

	--=====================================
	GetSlotStackSize = function(self, slot)
		local item = self:GetItem(slot)
		return item.stack, item.max
	end;

	--=========================================================================
	-- other support functions...

	--=====================================
	GetItem = function(self, slot)
		-- return the CloneBagItem object at slot
		return self.items[slot+1]
	end;

	--=====================================
	IsFCOMarked = function(self, slot, icon_id)
		local item = self:GetItem(slot)
		if not item.isFCOMarked then return false end
		return item.isFCOMarked[icon_id]
	end;

	--=====================================
	ItemName = function(self, slot)
		local link = self:GetItemLink(slot)
		if link then
			return zo_strformat(SI_TOOLTIP_ITEM_NAME, link)
		else
			return ""
		end
	end;

	--=====================================
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
		local slot = -1		-- slots are offset 0
		return function()
			slot = slot + 1
			while slot < size do
				if self:HasItemInSlot(slot) then
					return slot
				end
				slot = slot + 1
			end
		end
	end;

	--=====================================
	GetStackableSlot = function(self, item)
		-- Return (slot, avail) for our first non-empty, non-full slot
		-- that can stack with 'item'.
		for slot = 0, self:GetBagSize()-1 do
			local itm = self:GetItem(slot)
			if itm:CanStackWith(item) then
				local size, max = self:GetSlotStackSize(slot)
				if size < max then
					return slot, max-size
				end
			end
		end
		return false
	end;

	--=====================================
	AddItem = function(self, slot, sbag, sslot, count)
		-- Add count items from source CloneBag sbag/sslot to slot
		local id = sbag:GetItemId(sslot)
		if self:HasItemInSlot(slot) then
			-- existing item
			if self:GetItemId(slot) == id then
				local stack, max = self:GetSlotStackSize(slot)
				if stack + count > max then
					Err("CloneBag:AddItem: %s[%d]: %d + %d would exceed max=%d",
						self:BagName(), slot,
						stack, count, max)
					return 0
				end
				self.items[slot+1].stack = stack + count
				return count
			else
				Err("CloneBag:AddItem: %s[%d] contains different item: %s",
					self:BagName(), slot,
					self:ItemName(slot))
				return 0
			end
		else
			-- new slot; copy data from sbag
			Dbg("CloneBag:AddItem: copying data from %s[%s]: %s",
				sbag:BagName(), sslot, sbag:ItemName(sslot))

			slot = slot+1 -- CloneBag.items uses offset 1 
			local item = sbag:GetItem(sslot)
			self.items[slot] = item:Copy()
			self.items[slot].stack = count
			return count
		end
	end;

	--=====================================
	RemoveItem = function(self, slot, count)
		-- Remove count items from source bag sbag/sslot to slot
		local stack, max = self:GetSlotStackSize(slot)
		if count > stack then
			Err("CloneBag:AddItem: %s[%d]: remove %d exceeds stack %d",
				self:BagName(), slot, count, stack)
			return 0
		end
		slot = slot+1 -- CloneBag.items uses offset 1 
		self.items[slot].stack = stack - count
		if self.items[slot].stack == 0 then
			-- empty slot
			self.items[slot] = CJRAB.CloneBagItem()		-- empty item
		end

		return count
	end;

	--=====================================
	Transfer = function(self, slot, dbag, dstSlot, count, msg)
		-- Transfer the item in slot to the CloneBag dbag
		-- this is essentially the same as do_transfer but operates
		-- immediately on the clone bags.
		Dbg( "CloneBag:Transfer %s[%s] --> %s[%s]   %d %s '%s'",
			self:BagName(), slot,
			dbag:BagName(), dstSlot,
			count, self:ItemName(slot),
			msg
			)

		dbag:AddItem(dstSlot, self, slot, count)
		self:RemoveItem(slot, count)
	end;

	}		-- end of instance vars & methods
	--=========================================================================
	-- Constructor

	-- copy the bag contents into our instance
	for slot = 0, GetBagSize(bag)-1 do
		this.items[slot+1] = CJRAB.CloneBagItem(bag, slot)
	end
	return this

end
