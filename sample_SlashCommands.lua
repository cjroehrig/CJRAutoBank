-- boilerplate for each source file to encapsulate everything in CJRAB:
if CJRAB == nil then CJRAB = {} end
local CJRAB = CJRAB

-- shortcut aliases
local Msg						= CJRAB.Msg
local Err						= CJRAB.Err
local Dbg						= CJRAB.Dbg

--=============================================================================
-- Slash commands

local function safepairs(tab, init)
    if rawequal(tab, _G) then
        return zo_insecureNext, tab, init
    else
        return next, tab, init
    end
end


--=====================================
function CJRAB.SlashCommands()

	SLASH_COMMANDS["/abtest"] = function(arg)
		local saved = CJRAB.DryRun
		CJRAB.DryRun = true
		CJRAB.OpenBanking(BAG_BANK)
		CJRAB.CloseBanking(BAG_BANK)
		CJRAB.DryRun = saved
	end
	SLASH_COMMANDS["/abmark"] = function(arg)
		-- run Inventory on all bag items
		for slot in CJRAB.BagItems(BAG_BACKPACK) do
			CJRAB.Inventory(BAG_BACKPACK, slot, nil)
		end
	end

	SLASH_COMMANDS["/dumpfcoicons"] = function(arg)
		if not FCOIS then
			d("FCO Item Saver is not installed")
			return
		end
		for i, name in ipairs(FCOIS.LAMiconsList) do
			if name then
				d(string.format("[%d] %s", i, name))
			end
		end
	end

	SLASH_COMMANDS["/laundry"] = function(arg) CJRAB.DumpLaundry() end

	SLASH_COMMANDS["/dumpcraft"] = function(name)
		CJRAB.FetchLeoData()
		if not name or name == "" then name = GetUnitName("player") end
		if name == "all" then
			for char, _ in ipairs(CJRAB.CharsEnabled) do
				name = CJRAB.CharName(char)
				Msg("dumpcraft %d:%s", char, name)
				CJRAB.DumpCraft(name)
			end
		else
			CJRAB.DumpCraft(name)
		end
	end

	SLASH_COMMANDS["/stragglers"] = function(name)
		CJRAB.FetchLeoData()
		for craft, craftname in pairs(CJRAB_SI_CRAFTINGTYPE) do
			if craft ~=  0 then
				local char = CJRAB.LowestCraftLevelChar(craft)
				if char then
					Msg("%s straggler: %s", craftname, CJRAB.CharName(char))
				end
			end
		end
	end

	SLASH_COMMANDS["/sifind"] = function(pat)
		local i = 0
		d(string.format("Searching for '%s'", pat))
		for k,v in safepairs(_G) do
			if type(k) == "string" and string.find(k, '^SI_') then
				--[[
				if i % 100 == 0 then
					d(string.format("testing %s = %s [%s]",
						tostring(k),
						tostring(v),
						GetString(v)
						))
				end
				]]--
				v = GetString(v)
				if string.find(v, pat) then
					d(string.format("%s = %s", k, v))
				end
				i = i + 1
			end
		end
	end


end
