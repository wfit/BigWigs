-------------------------------------------------------------------------------
-- Boss Prototype
-- The API of a module created from `BigWigs:NewBoss`.
--
--### BigWigs:NewBoss (moduleName, mapId[, journalId])
--
--**Parameters:**
--  - `moduleName`:  [string] a unique module name, usually the boss name
--  - `mapId`:  [number] the map id for the map the boss is located in, negative ids are used to represent world bosses
--  - `journalId`:  [number] the journal id for the boss, used to translate the boss name (_optional_)
--
--**Returns:**
--  - boss module
--  - [common locale](https://github.com/BigWigsMods/BigWigs/blob/master/Core/Locales/common.enUS.lua) table for the current locale
--
-- @module BossPrototype
-- @alias boss
-- @usage local mod, CL = BigWigs:NewBoss("Archimonde", 1026, 1438)

local L = BigWigsAPI:GetLocale("BigWigs: Common")
local UnitAffectingCombat, UnitIsPlayer, UnitGUID, UnitPosition, UnitIsConnected = UnitAffectingCombat, UnitIsPlayer, UnitGUID, UnitPosition, UnitIsConnected
local UnitExists, UnitIsUnit, UnitName = UnitExists, UnitIsUnit, UnitName
local SetRaidTarget = SetRaidTarget
local EJ_GetSectionInfo, GetSpellInfo, GetSpellTexture, GetTime, IsSpellKnown = EJ_GetSectionInfo, GetSpellInfo, GetSpellTexture, GetTime, IsSpellKnown
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local SendChatMessage, GetInstanceInfo = BigWigsLoader.SendChatMessage, BigWigsLoader.GetInstanceInfo
local format, find, gsub, band = string.format, string.find, string.gsub, bit.band
local select, type, next, tonumber = select, type, next, tonumber
local core = BigWigs
local C = core.C
local pName = UnitName("player")
local hasVoice = BigWigsAPI:HasVoicePack()
local bossUtilityFrame = CreateFrame("Frame")
local enabledModules = {}
local allowedEvents = {}
local difficulty = 0
local UpdateDispelStatus, UpdateInterruptStatus = nil, nil
local myGUID, myRole, myDamagerRole = nil, nil, nil
local solo = false
local updateData = function(module)
	myGUID = UnitGUID("player")
	hasVoice = BigWigsAPI:HasVoicePack()

	local tree = GetSpecialization()
	if tree then
		myRole = GetSpecializationRole(tree)
		myDamagerRole = nil
		if myRole == "DAMAGER" then
			myDamagerRole = "MELEE"
			local _, class = UnitClass("player")
			if
				class == "MAGE" or class == "WARLOCK" or (class == "HUNTER" and tree ~= 3) or (class == "DRUID" and tree == 1) or
				(class == "PRIEST" and tree == 3) or (class == "SHAMAN" and tree == 1)
			then
				myDamagerRole = "RANGED"
			end
		end
	end

	local _, _, diff = GetInstanceInfo()
	difficulty = diff

	solo = true
	local _, _, _, instanceId = UnitPosition("player")
	for unit in module:IterateGroup() do
		local _, _, _, tarInstanceId = UnitPosition(unit)
		if tarInstanceId == instanceId and myGUID ~= UnitGUID(unit) and UnitIsConnected(unit) then
			solo = false
			break
		end
	end

	UpdateDispelStatus()
	UpdateInterruptStatus()
end

local Token = FS.Token
local Roster = FS.Roster
local Hud = FS.Hud

-------------------------------------------------------------------------------
-- Debug
--

local debug = false -- Set to true to get (very spammy) debug messages.
local dbg = function(self, msg) print(format("[DBG:%s] %s", self.displayName, msg)) end

-------------------------------------------------------------------------------
-- Metatables
--

local metaMap = {__index = function(self, key) self[key] = {} return self[key] end}
local eventMap = setmetatable({}, metaMap)
local unitEventMap = setmetatable({}, metaMap)
local icons = setmetatable({}, {__index =
	function(self, key)
		local value
		if type(key) == "number" then
			if key > 8 then
				value = GetSpellTexture(key)
			elseif key > 0 then
				-- Texture id list for raid icons 1-8 is 137001-137008. Base texture path is Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_%d
				value = key + 137000
			else
				local _, _, _, abilityIcon = EJ_GetSectionInfo(-key)
				value = abilityIcon or false
			end
		elseif not key:find("\\") then
			value = "Interface\\Icons\\" .. key
		else
			value = key
		end
		if not value then
			core:Print(format("An invalid spell id (%d) is being used in a boss module.", key))
		end
		self[key] = value
		return value
	end
})
local spells = setmetatable({}, {__index =
	function(self, key)
		local value
		if key > 0 then
			value = GetSpellInfo(key)
		else
			value = EJ_GetSectionInfo(-key)
		end
		if not value then
			core:Print(format("An invalid spell id (%d) is being used in a boss module.", key))
		end
		self[key] = value
		return value
	end
})


local argsVirtuals = {}

function argsVirtuals.spellName(args)
	return spells[args.spellId]
end

function argsVirtuals.spellIcon(args)
	return icons[args.spellId]
end

-------------------------------------------------------------------------------
-- Core module functionality
-- @section core
--

local boss = {}
core:GetModule("Bosses"):SetDefaultModulePrototype(boss)

--- Register the module to enable on mob id.
-- @param ... Any number of mob ids
function boss:RegisterEnableMob(...) core:RegisterEnableMob(self, ...) end

--- The encounter id as used by events ENCOUNTER_START, ENCOUNTER_END & BOSS_KILL.
-- If this is set, no engage or wipe checking is required. The module will use this id and all engage/wipe checking will be handled automatically.
-- @within Enable triggers
boss.engageId = nil

--- The time in seconds before the boss respawns after a wipe.
-- Used by the `Respawn` plugin to show a bar for the respawn time.
-- @within Enable triggers
boss.respawnTime = nil

--- The NPC/mob id of the world boss.
-- Used to specify that a module is for a world boss, not an instance boss.
-- @within Enable triggers
boss.worldBoss = nil

--- The map id the boss should be listed under in the configuration menu, generally used for world bosses.
-- @within Enable triggers
boss.otherMenu = nil

boss.spells = spells
boss.icons = icons

--- Check if a module option is enabled.
-- This is a wrapper around the self.db.profile[key] table.
-- @return boolean
function boss:GetOption(key)
	local token = self.tokens_opt and self.tokens_opt[key]
	if token then
		return token:IsMine()
	else
		return self.db.profile[key]
	end
end

--- Module type check.
-- A module is either from BossPrototype or PluginPrototype.
-- @return true
function boss:IsBossModule()
	return true
end

function boss:Initialize()
	core:RegisterBossModule(self)
	self.autoTimers = {}
	self.autoTimersLabels = {}
	self.autoTimersSummary = {}
end

function boss:OnEnable(isWipe)
	if debug then dbg(self, isWipe and "OnEnable() via Wipe()" or "OnEnable()") end

	updateData(self)
	self.sayCountdowns = {}

	-- Update enabled modules list
	for i = #enabledModules, 1, -1 do
		local module = enabledModules[i]
		if module == self then return end
	end
	enabledModules[#enabledModules+1] = self

	if self.SetupOptions then self:SetupOptions() end
	if type(self.OnBossEnable) == "function" then self:OnBossEnable() end

	self:EnableTokens()
	self:RegisterMessage("BW_NET_MSG")
	self:RegisterMessage("BigWigs_BossComm_Sync")

	if SmartColor then
		SmartColor:RegisterFilter(self)
	end

	if IsEncounterInProgress() and not isWipe then -- Safety. ENCOUNTER_END might fire whilst IsEncounterInProgress is still true and engage a module.
		self:CheckForEncounterEngage("NoEngage") -- Prevent engaging if enabling during a boss fight (after a DC)
	end

	if not isWipe then
		self:SendMessage("BigWigs_OnBossEnable", self)
	end
end

function boss:OnDisable(isWipe)
	if debug then dbg(self, isWipe and "OnDisable() via Wipe()" or "OnDisable()") end
	if type(self.OnBossDisable) == "function" then self:OnBossDisable() end

	-- Update enabled modules list
	for i = #enabledModules, 1, -1 do
		if self == enabledModules[i] then
			tremove(enabledModules, i)
		end
	end

	-- No enabled modules? Unregister the combat log!
	if #enabledModules == 0 then
		bossUtilityFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end

	-- Unregister the Unit Events for this module
	for a, b in next, unitEventMap[self] do
		for k in next, b do
			self:UnregisterUnitEvent(a, k)
		end
	end

	-- Empty the event maps for this module
	eventMap[self] = nil
	unitEventMap[self] = nil
	wipe(allowedEvents)

	-- Re-add allowed events if more than one module is enabled
	for a, b in next, eventMap do
		for k in next, b do
			allowedEvents[k] = true
		end
	end

	if not isWipe then
		self:DisableTokens()
	end

	if self.syncmsg_debounce then
		wipe(self.syncmsg_debounce)
	end

	self.sayCountdowns = nil
	self.scheduledMessages = nil
	self.scheduledScans = nil
	self.scheduledScansCounter = nil
	self.targetEventFunc = nil
	self.isWiping = nil
	self.isEngaged = nil

	-- Reset auto timers
	self:OnDisableAutoTimersSummary()
	wipe(self.autoTimers)
	wipe(self.autoTimersLabels)
	wipe(self.autoTimersSummary)

	if SmartColor then
		SmartColor:UnregisterFilter(self)
		SmartColor:UnsetAll()
	end

	if not isWipe then
		self:SendMessage("BigWigs_OnBossDisable", self)
	end
end

function boss:Reboot(isWipe)
	if debug then dbg(self, ":Reboot()") end
	if isWipe then
		-- Devs, in 99% of cases you'll want to use OnBossWipe
		self:SendMessage("BigWigs_OnBossWipe", self)
	end
	-- Reboot covers everything including hard module reboots (clicking the minimap icon)
	self:SendMessage("BigWigs_OnBossReboot", self)
	self:OnDisable(isWipe)
	self:CancelAllTimers()
	self:OnEnable(isWipe)
end

-------------------------------------------------------------------------------
-- Localization
-- @section localization
--

--- Get the current localization strings.
-- @return keyed table of localized strings
function boss:GetLocale()
	if not self.localization then
		self.localization = {}
	end
	return self.localization
end
boss.NewLocale = boss.GetLocale

--- Create a custom marking option
-- @param state Boolean value to represent default state
-- @param markType The type of string to return (player, npc)
-- @param icon An icon id to be used for the option texture
-- @param id The spell id or journal id to be translated into a name for the returned string
-- @param ... a series of raid icons being used by the marker function e.g. (1, 2, 3)
-- @return an option string to be used in conjuction with :GetOption
function boss:AddMarkerOption(state, markType, icon, id, ...)
	local l = self:GetLocale()
	local str = ""
	for i = 1, select("#", ...) do
		local num = select(i, ...)
		local icon = format("|T13700%d:15|t", num)
		str = str .. icon
	end

	local option = format(state and "custom_on_%d" or "custom_off_%d", id)
	l[option] = format(L.marker, spells[id])
	l[option.."_desc"] = format(markType == "player" and L.marker_player_desc or L.marker_npc_desc, spells[id], str)
	if icon then
		l[option.."_icon"] = icon
	end
	return option
end

function boss:AddCustomOption(settings)
	local l = self:GetLocale()
	local key = settings.key or settings[1]
	local option
	if settings.configurable then
		option = key
	else
		option = format((settings.default == false) and "custom_off_%s" or "custom_on_%s", key)
	end
	l[option] = settings.title or settings[2]
	if settings.desc then l[option .. "_desc"] = settings.desc end
	if settings.icon then l[option .. "_icon"] = settings.icon end
	return option
end

function boss:AddTokenOption(settings)
	local option = self:AddCustomOption(settings)
	local token = self:CreateToken(settings.key or settings[1], settings.promote or false, option)
	return option, token
end

-------------------------------------------------------------------------------
-- Combat log functions
-- @section combat_events
--

do
	local missingArgument = "Missing required argument when adding a listener to %q."
	local missingFunction = "%q tried to register a listener to method %q, but it doesn't exist in the module."
	local invalidId = "Module %q tried to register an invalid spell id (%s) to event %q."

	function boss:CHAT_MSG_RAID_BOSS_EMOTE(event, msg, ...)
		if eventMap[self][event][msg] then
			self[eventMap[self][event][msg]](self, msg, ...)
		else
			for emote, func in next, eventMap[self][event] do
				if find(msg, emote, nil, true) or find(msg, emote) then -- Preserve backwards compat by leaving in the 2nd check
					self[func](self, msg, ...)
				end
			end
		end
	end
	--- [DEPRECATED] Register a callback for CHAT_MSG_RAID_BOSS_EMOTE that matches text.
	-- @param func callback function, passed (module, message, sender, language, channel, target, [standard CHAT_MSG args]...)
	-- @param ... any number of strings to match
	function boss:Emote(func, ...)
		if not func then core:Print(format(missingArgument, self.moduleName)) return end
		if not self[func] then core:Print(format(missingFunction, self.moduleName, func)) return end
		if not eventMap[self].CHAT_MSG_RAID_BOSS_EMOTE then eventMap[self].CHAT_MSG_RAID_BOSS_EMOTE = {} end
		for i = 1, select("#", ...) do
			eventMap[self]["CHAT_MSG_RAID_BOSS_EMOTE"][(select(i, ...))] = func
		end
		self:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
	end

	function boss:CHAT_MSG_MONSTER_YELL(event, msg, ...)
		if eventMap[self][event][msg] then
			self[eventMap[self][event][msg]](self, msg, ...)
		else
			for yell, func in next, eventMap[self][event] do
				if find(msg, yell, nil, true) or find(msg, yell) then -- Preserve backwards compat by leaving in the 2nd check
					self[func](self, msg, ...)
				end
			end
		end
	end
	--- [DEPRECATED] Register a callback for CHAT_MSG_MONSTER_YELL that matches text.
	-- @param func callback function, passed (module, message, sender, language, channel, target, [standard CHAT_MSG args]...)
	-- @param ... any number of strings to match
	function boss:Yell(func, ...)
		if not func then core:Print(format(missingArgument, self.moduleName)) return end
		if not self[func] then core:Print(format(missingFunction, self.moduleName, func)) return end
		if not eventMap[self].CHAT_MSG_MONSTER_YELL then eventMap[self].CHAT_MSG_MONSTER_YELL = {} end
		for i = 1, select("#", ...) do
			eventMap[self]["CHAT_MSG_MONSTER_YELL"][(select(i, ...))] = func
		end
		self:RegisterEvent("CHAT_MSG_MONSTER_YELL")
	end

	local args = setmetatable({}, {
		__index = function(self, key)
			local virtual = argsVirtuals[key]
			if virtual then return virtual(self) end
		end
	})

	bossUtilityFrame:SetScript("OnEvent", function(_, _, timestamp, event, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, _, extraSpellId, amount)
		if allowedEvents[event] then
			if event == "UNIT_DIED" then
				local _, _, _, _, _, id = strsplit("-", destGUID)
				local mobId = tonumber(id)
				if mobId then
					for i = #enabledModules, 1, -1 do
						local self = enabledModules[i]
						local m = eventMap[self][event]
						if m and m[mobId] then
							local func = m[mobId]
							args.timestamp, args.mobId, args.destGUID, args.destName, args.destFlags, args.destRaidFlags = timestamp, mobId, destGUID, destName, destFlags, args.destRaidFlags
							if type(func) == "function" then
								func(args)
							else
								self[func](self, args)
							end
						end
					end
				end
			else
				for i = #enabledModules, 1, -1 do
					local self = enabledModules[i]
					local m = eventMap[self][event]
					if m and (m[spellId] or m["*"]) then
						local func = m[spellId] or m["*"]
						-- DEVS! Please ask if you need args attached to the table that we've missed out!
						args.timestamp = timestamp
						args.sourceGUID, args.sourceName, args.sourceFlags, args.sourceRaidFlags = sourceGUID, sourceName, sourceFlags, sourceRaidFlags
						args.destGUID, args.destName, args.destFlags, args.destRaidFlags = destGUID, destName, destFlags, destRaidFlags
						args.spellId, args.spellName, args.extraSpellId, args.extraSpellName, args.amount = spellId, spellName, extraSpellId, amount, amount
						if type(func) == "function" then
							func(args)
						else
							self[func](self, args)
							if debug then dbg(self, "Firing func: "..func) end
						end
					end
				end
			end
		end
	end)
	--- Register a callback for COMBAT_LOG_EVENT.
	-- @param event COMBAT_LOG_EVENT to fire for e.g. SPELL_CAST_START
	-- @param func callback function, passed a keyed table (sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, extraSpellId, extraSpellName, amount)
	-- @param ... any number of spell ids
	function boss:Log(event, func, ...)
		if not event or not func then core:Print(format(missingArgument, self.moduleName)) return end
		if type(func) ~= "function" and not self[func] then core:Print(format(missingFunction, self.moduleName, func)) return end
		if not eventMap[self][event] then eventMap[self][event] = {} end
		for i = 1, select("#", ...) do
			local id = select(i, ...)
			if (type(id) == "number" and GetSpellInfo(id)) or id == "*" then
				eventMap[self][event][id] = func
			else
				core:Print(format(invalidId, self.moduleName, tostring(id), event))
			end
		end
		allowedEvents[event] = true
		bossUtilityFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:SendMessage("BigWigs_OnBossLog", self, event, ...)
	end
	--- Remove a callback for COMBAT_LOG_EVENT.
	-- @param event COMBAT_LOG_EVENT to register for
	-- @param ... any number of spell ids
	function boss:RemoveLog(event, ...)
		if not event then core:Print(format(missingArgument, self.moduleName)) return end
		for i = 1, select("#", ...) do
			local id = select(i, ...)
			eventMap[self][event][id] = nil
		end
	end
	--- Register a callback for UNIT_DIED.
	-- @param func callback function, passed a keyed table (mobId, destGUID, destName, destFlags, destRaidFlags)
	-- @param ... any number of mob ids
	function boss:Death(func, ...)
		if not func then core:Print(format(missingArgument, self.moduleName)) return end
		if type(func) ~= "function" and not self[func] then core:Print(format(missingFunction, self.moduleName, func)) return end
		if not eventMap[self].UNIT_DIED then eventMap[self].UNIT_DIED = {} end
		for i = 1, select("#", ...) do
			eventMap[self]["UNIT_DIED"][(select(i, ...))] = func
		end
		allowedEvents.UNIT_DIED = true
		bossUtilityFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
end

-------------------------------------------------------------------------------
-- Unit-specific event update management
-- @section unit_events
--

do
	local noEvent = "Module %q tried to register/unregister a unit event without specifying which event."
	local noUnit = "Module %q tried to register/unregister a unit event without specifying any units."
	local noFunc = "Module %q tried to register a unit event with the function '%s' which doesn't exist in the module."

	local frameTbl = {}
	local eventFunc = function(_, event, unit, ...)
		for i = #enabledModules, 1, -1 do
			local self = enabledModules[i]
			local m = unitEventMap[self] and unitEventMap[self][event]
			if m and m[unit] then
				self[m[unit]](self, unit, ...)
			end
		end
	end

	--- Register a callback for a UNIT_* event for the specified units.
	-- @param event the event to register for
	-- @param func callback function, passed (unit, eventargs...)
	-- @param ... Any number of unit tokens
	function boss:RegisterUnitEvent(event, func, ...)
		if type(event) ~= "string" then core:Print(format(noEvent, self.moduleName)) return end
		if not ... then core:Print(format(noUnit, self.moduleName)) return end
		if (not func and not self[event]) or (func and not self[func]) then core:Print(format(noFunc, self.moduleName, func or event)) return end
		if not unitEventMap[self][event] then unitEventMap[self][event] = {} end
		for i = 1, select("#", ...) do
			local unit = select(i, ...)
			if not frameTbl[unit] then
				frameTbl[unit] = CreateFrame("Frame")
				frameTbl[unit]:SetScript("OnEvent", eventFunc)
			end
			unitEventMap[self][event][unit] = func or event
			frameTbl[unit]:RegisterUnitEvent(event, unit)
			if debug then dbg(self, "Adding: "..event..", "..unit) end
		end
	end
	--- Unregister a callback for unit bound events.
	-- @param event the event register for
	-- @param ... Any number of unit tokens
	function boss:UnregisterUnitEvent(event, ...)
		if type(event) ~= "string" then core:Print(format(noEvent, self.moduleName)) return end
		if not ... then core:Print(format(noUnit, self.moduleName)) return end
		if not unitEventMap[self][event] then return end
		for i = 1, select("#", ...) do
			local unit = select(i, ...)
			unitEventMap[self][event][unit] = nil
			local keepRegistered
			for j = #enabledModules, 1, -1 do
				local m = unitEventMap[enabledModules[j]][event]
				if m and m[unit] then
					keepRegistered = true
				end
			end
			if not keepRegistered then
				if debug then dbg(self, "Removing: "..event..", "..unit) end
				frameTbl[unit]:UnregisterEvent(event)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Engage / wipe checking + unit scanning
-- @section engage_status
--

do
	local function wipeCheck(module)
		if not IsEncounterInProgress() then
			if debug then dbg(module, "IsEncounterInProgress() is nil, wiped.") end
			module:Wipe()
		end
	end

	--- Start checking for a wipe.
	-- Starts a repeating timer checking IsEncounterInProgress() and reboots the module if false.
	function boss:StartWipeCheck()
		self:StopWipeCheck()
		self.isWiping = self:ScheduleRepeatingTimer(wipeCheck, 1, self)
	end
	--- Stop checking for a wipe.
	-- Stops the repeating timer checking IsEncounterInProgress() if it is running.
	function boss:StopWipeCheck()
		if self.isWiping then
			self:CancelTimer(self.isWiping)
			self.isWiping = nil
		end
	end

	--- Update module engage status from querying boss units.
	-- Engages modules if boss1-boss5 matches an registered enabled mob,
	-- disables the module if set as engaged but has no boss match.
	-- @param noEngage if set to "NoEngage", the module is prevented from engaging if enabling during a boss fight (after a DC)
	function boss:CheckForEncounterEngage(noEngage)
		local hasBoss = UnitHealth("boss1") > 0 or UnitHealth("boss2") > 0 or UnitHealth("boss3") > 0 or UnitHealth("boss4") > 0 or UnitHealth("boss5") > 0
		if not self.isEngaged and hasBoss then
			local guid = UnitGUID("boss1") or UnitGUID("boss2") or UnitGUID("boss3") or UnitGUID("boss4") or UnitGUID("boss5")
			local module = core:GetEnableMobs()[self:MobId(guid)]
			local modType = type(module)
			if modType == "string" then
				if module == self.moduleName then
					self:Engage(noEngage == "NoEngage" and noEngage)
				else
					self:Disable()
				end
			elseif modType == "table" then
				for i = 1, #module do
					if module[i] == self.moduleName then
						self:Engage(noEngage == "NoEngage" and noEngage)
						break
					end
				end
				if not self.isEngaged then self:Disable() end
			end
		end
	end

	--- Query boss units to update engage status.
	-- @see CheckForEncounterEngage
	function boss:CheckBossStatus()
		local hasBoss = UnitHealth("boss1") > 0 or UnitHealth("boss2") > 0 or UnitHealth("boss3") > 0 or UnitHealth("boss4") > 0 or UnitHealth("boss5") > 0
		if not hasBoss and self.isEngaged then
			if debug then dbg(self, ":CheckBossStatus wipeCheck scheduled.") end
			self:ScheduleTimer(wipeCheck, 6, self)
		elseif not self.isEngaged and hasBoss then
			if debug then dbg(self, ":CheckBossStatus Engage called.") end
			self:CheckForEncounterEngage()
		end
		if debug then dbg(self, ":CheckBossStatus called with no result. Engaged = "..tostring(self.isEngaged).." hasBoss = "..tostring(hasBoss)) end
	end
end

do
	local unitTable = {
		"boss1", "boss2", "boss3", "boss4", "boss5",
		"target", "targettarget",
		"mouseover", "mouseovertarget",
		"focus", "focustarget",
		"nameplate1", "nameplate2", "nameplate3", "nameplate4", "nameplate5", "nameplate6", "nameplate7", "nameplate8", "nameplate9", "nameplate10",
		"nameplate11", "nameplate12", "nameplate13", "nameplate14", "nameplate15", "nameplate16", "nameplate17", "nameplate18", "nameplate19", "nameplate20",
		"nameplate21", "nameplate22", "nameplate23", "nameplate24", "nameplate25", "nameplate26", "nameplate27", "nameplate28", "nameplate29", "nameplate30",
		"nameplate31", "nameplate32", "nameplate33", "nameplate34", "nameplate35", "nameplate36", "nameplate37", "nameplate38", "nameplate39", "nameplate40",
		"party1target", "party2target", "party3target", "party4target",
		"raid1target", "raid2target", "raid3target", "raid4target", "raid5target",
		"raid6target", "raid7target", "raid8target", "raid9target", "raid10target",
		"raid11target", "raid12target", "raid13target", "raid14target", "raid15target",
		"raid16target", "raid17target", "raid18target", "raid19target", "raid20target",
		"raid21target", "raid22target", "raid23target", "raid24target", "raid25target",
		"raid26target", "raid27target", "raid28target", "raid29target", "raid30target",
		"raid31target", "raid32target", "raid33target", "raid34target", "raid35target",
		"raid36target", "raid37target", "raid38target", "raid39target", "raid40target"
	}
	local function findTargetByGUID(id)
		local isNumber = type(id) == "number"
		for i = 1, #unitTable do
			local unit = unitTable[i]
			local guid = UnitGUID(unit)
			if guid and not UnitIsPlayer(unit) then
				if isNumber then
					local _, _, _, _, _, mobId = strsplit("-", guid)
					guid = tonumber(mobId)
				end
				if guid == id then return unit end
			end
		end
	end
	--- Fetches a unit id by scanning available targets.
	-- Scans through available targets such as bosses, nameplates and player targets
	-- in an attempt to find a valid unit id to return.
	-- @param id GUID or mob/npc id
	-- @return unit id if found, nil otherwise
	function boss:GetUnitIdByGUID(id) return findTargetByGUID(id) end

	do
		local sharedSeen = {}
		function boss:IterateUnits(safe)
			local i, max = 1, #unitTable
			local function next(seen)
				if i > max then
					return nil
				else
					local unit = unitTable[i]
					i = i + 1
					local guid = UnitGUID(unit)
					if guid and not UnitIsPlayer(unit) and not seen[guid] then
						seen[guid] = true
						return unit, guid, boss:MobId(guid)
					else
						return next(seen)
					end
				end
			end
			if not safe then wipe(sharedSeen) end
			return next, safe and {} or sharedSeen
		end
	end

	local function unitScanner(self, func, tankCheckExpiry, guid)
		local elapsed = self.scheduledScansCounter[guid] + 0.05

		local unit = findTargetByGUID(guid)
		if unit then
			local unitTarget = unit.."target"
			local playerGUID = UnitGUID(unitTarget)
			if playerGUID and ((not UnitDetailedThreatSituation(unitTarget, unit) and not self:Tank(unitTarget)) or elapsed > tankCheckExpiry) then
				local name = self:UnitName(unitTarget)
				self:CancelTimer(self.scheduledScans[guid])
				func(self, name, playerGUID, elapsed)
				self.scheduledScans[guid] = nil
			end
		end

		if elapsed > 0.8 then
			self:CancelTimer(self.scheduledScans[guid])
			self.scheduledScans[guid] = nil
		end

		self.scheduledScansCounter[guid] = elapsed
	end

	--- Register a callback to get the first non-tank target of a mob.
	-- Looks for the unit as defined by the GUID and then returns the target of that unit.
	-- If the target is a tank, it will keep looking until the designated time has elapsed.
	-- @param func callback function, passed (module, playerName, playerGUID, timeElapsed)
	-- @param tankCheckExpiry seconds to wait, if a tank is still the target after this time, it will return the tank as the target (max 0.8)
	-- @param guid GUID of the mob to get the target of
	function boss:GetUnitTarget(func, tankCheckExpiry, guid)
		if not self.scheduledScans then
			self.scheduledScans, self.scheduledScansCounter = {}, {}
		end

		if self.scheduledScans[guid] then
			self:CancelTimer(self.scheduledScans[guid]) -- Should never be needed, safety
		end

		self.scheduledScansCounter[guid] = 0
		self.scheduledScans[guid] = self:ScheduleRepeatingTimer(unitScanner, 0.05, self, func, solo and 0.1 or tankCheckExpiry, guid) -- Tiny allowance when solo
	end

	local function scan(self)
		for mobId, entry in next, core:GetEnableMobs() do
			if type(entry) == "table" then
				for i, module in next, entry do
					if module == self.moduleName then
						local unit = findTargetByGUID(mobId)
						if unit and UnitAffectingCombat(unit) then return unit end
						break
					end
				end
			elseif entry == self.moduleName then
				local unit = findTargetByGUID(mobId)
				if unit and UnitAffectingCombat(unit) then return unit end
			end
		end
	end

	--- Start a repeating timer checking if your group is in combat with a boss.
	function boss:CheckForEngage()
		if debug then dbg(self, ":CheckForEngage initiated.") end
		local go = scan(self)
		if go then
			if debug then dbg(self, "Engage scan found active boss entities, transmitting engage sync.") end
			self:Sync("Engage", self.moduleName)
		else
			if debug then dbg(self, "Engage scan did NOT find any active boss entities. Re-scheduling another engage check in 0.5 seconds.") end
			self:ScheduleTimer("CheckForEngage", .5)
		end
	end

	-- XXX What if we die and then get battleressed?
	-- XXX First of all, the CheckForWipe every 2 seconds would continue scanning.
	-- XXX Secondly, if the boss module registers for PLAYER_REGEN_DISABLED, it would
	-- XXX trigger again, and CheckForEngage (possibly) invoked, which results in
	-- XXX a new Engage sync -> :Engage -> :OnEngage on the module.
	-- XXX Possibly a concern?

	--- Start a repeating timer checking if your group has left combat with a boss.
	function boss:CheckForWipe()
		if debug then dbg(self, ":CheckForWipe initiated.") end
		local go = scan(self)
		if not go then
			if debug then dbg(self, "Wipe scan found no active boss entities, rebooting module.") end
			self:Wipe()
		else
			if debug then dbg(self, "Wipe scan found active boss entities (" .. tostring(go) .. "). Re-scheduling another wipe check in 2 seconds.") end
			self:ScheduleTimer("CheckForWipe", 2)
		end
	end

	function boss:Engage(noEngage)
		-- Engage
		if self.isEngaged then return end
		self.isEngaged = true

		if debug then dbg(self, ":Engage") end

		if not noEngage or noEngage ~= "NoEngage" then
			updateData(self)

			if self.OnEngage then
				self:OnEngage(difficulty)
			end

			self:SendMessage("BigWigs_OnBossEngage", self, difficulty)
		end
	end

	function boss:Win()
		if not self.isEngaged then return end
		if debug then dbg(self, ":Win") end
		self.lastKill = GetTime() -- Add the kill time for the enable check.
		if self.OnWin then self:OnWin() end
		self:SendMessage("BigWigs_OnBossWin", self)
		self:Disable()
		wipe(icons) -- Wipe icon cache
		wipe(spells)
	end

	function boss:Wipe()
		if not self.isEngaged then return end
		self:Reboot(true)
		if self.OnWipe then self:OnWipe() end
	end
end

do
	local bosses = {"boss1", "boss2", "boss3", "boss4", "boss5"}
	local bossTargets = {"boss1target", "boss2target", "boss3target", "boss4target", "boss5target"}
	local UnitDetailedThreatSituation = UnitDetailedThreatSituation
	local function bossScanner(self, func, tankCheckExpiry, guid)
		local elapsed = self.scheduledScansCounter[guid] + 0.05

		for i = 1, 5 do
			local unit = bosses[i]
			if UnitGUID(unit) == guid then
				local bossTarget = bossTargets[i]
				local playerGUID = UnitGUID(bossTarget)
				if playerGUID and ((not UnitDetailedThreatSituation(bossTarget, unit) and not self:Tank(bossTarget)) or elapsed > tankCheckExpiry) then
					local name = self:UnitName(bossTarget)
					self:CancelTimer(self.scheduledScans[guid])
					func(self, name, playerGUID, elapsed)
					self.scheduledScans[guid] = nil
				end
				break
			end
		end

		if elapsed > 0.8 then
			self:CancelTimer(self.scheduledScans[guid])
			self.scheduledScans[guid] = nil
		end

		self.scheduledScansCounter[guid] = elapsed
	end
	--- Register a callback to get the first non-tank target of a boss (boss1 - boss5).
	-- Looks for the boss as defined by the GUID and then returns the target of that boss.
	-- If the target is a tank, it will keep looking until the designated time has elapsed.
	-- @param func callback function, passed (module, playerName, playerGUID, timeElapsed)
	-- @param tankCheckExpiry seconds to wait, if a tank is still the target after this time, it will return the tank as the target (max 0.8)
	-- @param guid GUID of the mob to get the target of
	function boss:GetBossTarget(func, tankCheckExpiry, guid)
		if not self.scheduledScans then
			self.scheduledScans, self.scheduledScansCounter = {}, {}
		end

		if self.scheduledScans[guid] then
			self:CancelTimer(self.scheduledScans[guid]) -- Should never be needed, safety
		end

		self.scheduledScansCounter[guid] = 0
		self.scheduledScans[guid] = self:ScheduleRepeatingTimer(bossScanner, 0.05, self, func, solo and 0.1 or tankCheckExpiry, guid) -- Tiny allowance when solo
	end
end

do
	function boss:UPDATE_MOUSEOVER_UNIT(event)
		self[self.targetEventFunc](self, event, "mouseover")
	end
	function boss:UNIT_TARGET(event, unit)
		self[self.targetEventFunc](self, event, unit.."target")
	end
	--- Register a set of events commonly used for raid marking functionality and pass the unit to a designated function.
	-- UPDATE_MOUSEOVER_UNIT, UNIT_TARGET, NAME_PLATE_UNIT_ADDED, FORBIDDEN_NAME_PLATE_UNIT_ADDED.
	-- @param func callback function, passed (event, unit)
	function boss:RegisterTargetEvents(func)
		if self[func] then
			self.targetEventFunc = func
			self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
			self:RegisterEvent("UNIT_TARGET")
			self:RegisterEvent("NAME_PLATE_UNIT_ADDED", func)
			self:RegisterEvent("FORBIDDEN_NAME_PLATE_UNIT_ADDED", func)
		end
	end
	--- Unregister the events registered by `RegisterTargetEvents`.
	function boss:UnregisterTargetEvents()
		self:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
		self:UnregisterEvent("UNIT_TARGET")
		self:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
		self:UnregisterEvent("FORBIDDEN_NAME_PLATE_UNIT_ADDED")
	end
end

-------------------------------------------------------------------------------
-- Misc utility functions
-- @section utility
--

--- Get the current instance difficulty.
-- @return difficulty id
function boss:Difficulty()
	return difficulty
end

--- Check if in a Looking for Raid instance.
-- @return boolean
function boss:LFR()
	return difficulty == 7 or difficulty == 17
end

--- Check if in a Normal difficulty instance.
-- @return boolean
function boss:Normal()
	return difficulty == 1 or difficulty == 3 or difficulty == 4 or difficulty == 14
end

--- Check if in a Looking for Raid or Normal difficulty instance.
-- @return boolean
function boss:Easy()
	return difficulty == 14 or difficulty == 17 -- New normal mode or new LFR mode
end

--- Check if in a Heroic difficulty instance.
-- @return boolean
function boss:Heroic()
	return difficulty == 2 or difficulty == 5 or difficulty == 6 or difficulty == 15
end

--- Check if in a Mythic difficulty instance.
-- @return boolean
function boss:Mythic()
	return difficulty == 16 or difficulty == 23
end

--- Get the mob/npc id from a GUID.
-- @param guid GUID of a mob/npc
-- @return mob id
function boss:MobId(guid)
	if UnitExists(guid) then guid = UnitGUID(guid) end
	if not guid then return 1 end
	local _, _, _, _, _, id = strsplit("-", guid)
	return tonumber(id) or 1
end

function argsVirtuals.sourceMob(args) return boss:MobId(args.sourceGUID) end
function argsVirtuals.destMob(args) return boss:MobId(args.destGUID) end

--- Get a localized name from an id. Positive ids for spells (GetSpellInfo) and negative ids for journal entries (EJ_GetSectionInfo).
-- @return spell name
function boss:SpellName(spellId)
	return spells[spellId]
end

function boss:SpellIcon(spellId)
	return icons[spellId]
end

--- Check if a GUID is you.
-- @param guid player GUID
-- @return boolean
function boss:Me(guid)
	return myGUID == guid or (UnitExists(guid) and UnitIsUnit(guid, "player"))
end

do
	--- Get the full name of a unit.
	-- @param unit unit token or name
	-- @return unit name with the server appended if appropriate
	function boss:UnitName(unit)
		local name, server = UnitName(unit)
		if not name then
			return
		elseif server and server ~= "" then
			name = name .."-".. server
		end
		return name
	end
end

--- Check if you're the only person inside an instance, despite being in a group or not.
-- @return boolean
function boss:Solo()
	return solo
end

-------------------------------------------------------------------------------
-- Group checking
-- @section group
--

do
	local raidList = { -- Not using a for loop because... REASONS. P.S. I love Torgue.
		"raid1", "raid2", "raid3", "raid4", "raid5", "raid6", "raid7", "raid8", "raid9", "raid10",
		"raid11", "raid12", "raid13", "raid14", "raid15", "raid16", "raid17", "raid18", "raid19", "raid20",
		"raid21", "raid22", "raid23", "raid24", "raid25", "raid26", "raid27", "raid28", "raid29", "raid30",
		"raid31", "raid32", "raid33", "raid34", "raid35", "raid36", "raid37", "raid38", "raid39", "raid40"
	}
	local partyList = {"player", "party1", "party2", "party3", "party4"}
	local GetNumGroupMembers, IsInRaid = GetNumGroupMembers, IsInRaid
	--- Iterate over your group.
	-- Automatically uses "party" or "raid" tokens depending on your group type.
	-- @return iterator
	function boss:IterateGroup(a, ...)
		if a ~= nil then return Roster:Iterate(a, ...) end
		local num = GetNumGroupMembers() or 0
		local i = 0
		local size = num > 0 and num+1 or 2
		local function iter(t)
			i = i + 1
			if i < size then
				return t[i]
			end
		end
		return iter, IsInRaid() and raidList or partyList
	end

	function boss:GetPlayerUnitIdByGUID(guid)
		for unit in self:IterateGroup() do
			if UnitGUID(unit) == guid then
				return unit
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Role checking
-- @section role

function boss:Role(guid)
	if not guid then
		guid = myGUID
	elseif UnitExists(guid) then
		guid = UnitGUID(guid)
	end
	local info = Roster:GetInfo(guid)
	return info and info.spec_role_detailed or "none"
end

--- Check if your talent tree role is TANK or MELEE.
-- @return boolean
function boss:Melee(unit, strict)
	local role = self:Role(unit)
	if role == "none" and not unit then
		return (not strict and myRole == "TANK") or myDamagerRole == "MELEE"
	end
	return role == "melee" or (not strict and role == "tank")
end

--- Check if your talent tree role is HEALER or RANGED.
-- @return boolean
function boss:Ranged(unit, strict)
	local role = self:Role(unit)
	if role == "none" and not unit then
		return (not strict and myRole == "HEALER") or myDamagerRole == "RANGED"
	end
	return role == "ranged" or (not strict and role == "healer")
end

--- Check if your talent tree role is TANK.
-- @param[opt="player"] unit check if the chosen role of another unit is set to TANK, or if that unit is listed in the MAINTANK frames.
-- @return boolean
function boss:Tank(unit)
	local role = self:Role(unit)
	if role == "none" then
		if unit then
			return GetPartyAssignment("MAINTANK", unit) or UnitGroupRolesAssigned(unit) == "TANK"
		else
			return myRole == "TANK"
		end
	end
	return role == "tank"
end

--- Check if your talent tree role is HEALER.
-- @param[opt="player"] unit check if the chosen role of another unit is set to HEALER.
-- @return boolean
function boss:Healer(unit)
	local role = self:Role(unit)
	if role == "none" then
		if unit then
			return UnitGroupRolesAssigned(unit) == "HEALER"
		else
			return myRole == "HEALER"
		end
	end
	return role == "healer"
end

--- Check if your talent tree role is DAMAGER.
-- @param[opt="player"] unit check if the chosen role of another unit is set to DAMAGER.
-- @return boolean
function boss:Damager(unit)
	local role = self:Role(unit)
	if role == "none" then
		if unit then
			return UnitGroupRolesAssigned(unit) == "DAMAGER"
		else
			return myDamagerRole
		end
	end
	return role == "melee" or role == "ranged"
end

do
	local offDispel, defDispel = "", ""
	function UpdateDispelStatus()
		offDispel, defDispel = "", ""
		if IsSpellKnown(32375) or IsSpellKnown(528) or IsSpellKnown(370) or IsSpellKnown(30449) then
			-- Mass Dispel (Priest), Dispel Magic (Priest), Purge (Shaman), Spellsteal (Mage)
			offDispel = offDispel .. "magic,"
		end
		if IsSpellKnown(527) or IsSpellKnown(77130) or IsSpellKnown(115450) or IsSpellKnown(4987) or IsSpellKnown(88423) then -- XXX Add DPS priest mass dispel?
			-- Purify (Heal Priest), Purify Spirit (Heal Shaman), Detox (Heal Monk), Cleanse (Heal Paladin), Nature's Cure (Heal Druid)
			defDispel = defDispel .. "magic,"
		end
		if IsSpellKnown(527) or IsSpellKnown(213634) or IsSpellKnown(115450) or IsSpellKnown(218164) or IsSpellKnown(4987) or IsSpellKnown(213644) then
			-- Purify (Heal Priest), Purify Disease (Shadow Priest), Detox (Heal Monk), Detox (DPS Monk), Cleanse (Heal Paladin), Cleanse Toxins (DPS Paladin)
			defDispel = defDispel .. "disease,"
		end
		if IsSpellKnown(88423) or IsSpellKnown(115450) or IsSpellKnown(218164) or IsSpellKnown(4987) or IsSpellKnown(2782) or IsSpellKnown(213644) then
			-- Nature's Cure (Heal Druid), Detox (Heal Monk), Detox (DPS Monk), Cleanse (Heal Paladin), Remove Corruption (DPS Druid), Cleanse Toxins (DPS Paladin)
			defDispel = defDispel .. "poison,"
		end
		if IsSpellKnown(88423) or IsSpellKnown(2782) or IsSpellKnown(77130) or IsSpellKnown(51886) then
			-- Nature's Cure (Heal Druid), Remove Corruption (DPS Druid), Purify Spirit (Heal Shaman), Cleanse Spirit (DPS Shaman)
			defDispel = defDispel .. "curse,"
		end
	end
	--- Check if you can dispel.
	-- @param dispelType dispel type (magic, disease, poison, curse)
	-- @param[opt] isOffensive true if dispelling a buff from an enemy (magic), nil if dispelling a friendly
	-- @param[opt] key module option key to check
	-- @return boolean
	function boss:Dispeller(dispelType, isOffensive, key)
		if key then
			local o = self.db.profile[key]
			if not o then core:Print(format("Module %s uses %q as a dispel lookup, but it doesn't exist in the module options.", self.name, key)) return end
			if band(o, C.DISPEL) ~= C.DISPEL then return true end
		end
		if isOffensive then
			if find(offDispel, dispelType, nil, true) then
				return true
			end
		else
			if find(defDispel, dispelType, nil, true) then
				return true
			end
		end
	end
end

do
	local canInterrupt = false
	local spellList = {
		106839, -- Skull Bash (Druid)
		78675, -- Solar Beam (Druid-Balance)
		116705, -- Spear Hand Strike (Monk)
		147362, -- Counter Shot (Hunter)
		187707, -- Muzzle (Hunter-Survival)
		57994, -- Wind Shear (Shaman)
		47528, -- Mind Freeze (Death Knight)
		96231, -- Rebuke (Paladin)
		15487, -- Silence (Priest)
		2139, -- Counterspell (Mage)
		1766, -- Kick (Rogue)
		6552, -- Pummel (Warrior)
		183752, -- Consume Magic (Demon Hunter)
		-- XXX warlock?
	}
	function UpdateInterruptStatus()
		canInterrupt = false
		for i = 1, #spellList do
			local spell = spellList[i]
			if IsSpellKnown(spell) then
				canInterrupt = spell -- XXX check for cooldown also?
				break
			end
		end
	end
	--- Check if you can interrupt.
	-- @param[opt] guid if not nil, will only return true if the GUID matches your target or focus.
	-- @return boolean
	function boss:Interrupter(guid)
		-- We will probably need to make this smarter
		if guid then
			if canInterrupt and (UnitGUID("target") == guid or UnitGUID("focus") == guid) then
				return canInterrupt
			end
			return
		end
		return canInterrupt
	end
end

-------------------------------------------------------------------------------
-- Option flag check
-- @section toggles
--

-- Option silencer
local silencedOptions = {}
do
	bossUtilityFrame:Hide()
	BigWigsLoader.RegisterMessage(silencedOptions, "BigWigs_SilenceOption", function(event, key, time)
		if key ~= nil then -- custom bars have a nil key
			silencedOptions[key] = time
			bossUtilityFrame:Show()
		end
	end)
	local total = 0
	bossUtilityFrame:SetScript("OnUpdate", function(self, elapsed)
		total = total + elapsed
		if total >= 0.5 then
			for k, t in next, silencedOptions do
				local newT = t - total
				if newT < 0 then
					silencedOptions[k] = nil
				else
					silencedOptions[k] = newT
				end
			end
			if not next(silencedOptions) then
				self:Hide()
			end
			total = 0
		end
	end)
end

local checkFlag = nil
do
	local noDefaultError   = "Module %s uses %q as a toggle option, but it does not exist in the modules default values."
	local notNumberError   = "Module %s tried to access %q, but in the database it's a %s."
	local nilKeyError      = "Module %s tried to check the bitflags for a nil option key."
	local invalidFlagError = "Module %s tried to check for an invalid flag type %q (%q). Flags must be bits."
	local noDBError        = "Module %s does not have a .db property, which is weird."
	checkFlag = function(self, key, flag, quiet)
		if key == false then return true end -- Allow optionless abilities
		if type(key) == "nil" then core:Print(format(nilKeyError, self.moduleName)) return end
		if type(flag) ~= "number" then core:Print(format(invalidFlagError, self.moduleName, type(flag), tostring(flag))) return end
		if silencedOptions[key] then return end
		if type(self.db) ~= "table" then local msg = format(noDBError, self.moduleName) core:Print(msg) error(msg) return end
		if type(self.db.profile[key]) ~= "number" then
			if not self.toggleDefaults[key] then
				if not quiet then
					core:Print(format(noDefaultError, self.moduleName, key))
				end
				return
			end
			if debug then
				core:Print(format(notNumberError, self.moduleName, key, type(self.db.profile[key])))
				return
			end
			self.db.profile[key] = self.toggleDefaults[key]
		end

		local fullKey = self.db.profile[key]
		if band(fullKey, C.TANK) == C.TANK and not self:Tank() then return end
		if band(fullKey, C.HEALER) == C.HEALER and not self:Healer() then return end
		if band(fullKey, C.TANK_HEALER) == C.TANK_HEALER and not self:Tank() and not self:Healer() then return end
		return band(fullKey, flag) == flag
	end
	--- Check if an option has a flag set.
	-- @param key the option key
	-- @param flag the option flag
	function boss:CheckOption(key, flag)
		return checkFlag(self, key, C[flag])
	end
end

-------------------------------------------------------------------------------
-- AltPower.
-- @section AltPower
--

--- Open the "Alternate Power" display.
-- @param key the option key to check
-- @param title the title of the window, either a spell id or string
-- @param[opt] sorting "ZA" for descending sort, "AZ" or nil for ascending sort
-- @param[opt] sync if true, queries values from other players (for use if phasing prevents reliable updates)
function boss:OpenAltPower(key, title, sorting, sync)
	if checkFlag(self, key, C.ALTPOWER) then
		self:SendMessage("BigWigs_ShowAltPower", self, type(title) == "number" and spells[title] or title, sorting == "ZA" and sorting or "AZ", sync)
	end
	if sync then
		self:SendMessage("BigWigs_StartSyncingPower", self)
	end
end

--- Close the "Alternate Power" display.
-- @param[opt] key the option key to check ("altpower" if nil)
function boss:CloseAltPower(key)
	if checkFlag(self, key or "altpower", C.ALTPOWER) then
		self:SendMessage("BigWigs_HideAltPower", self)
	end
end

-------------------------------------------------------------------------------
-- InfoBox.
-- @section InfoBox
--

function boss:SetInfo(key, line, text)
	if checkFlag(self, key, C.INFOBOX) then
		self:SendMessage("BigWigs_SetInfoBoxLine", self, line, text)
	end
end

function boss:SetInfoByTable(key, tbl)
	if checkFlag(self, key, C.INFOBOX) then
		self:SendMessage("BigWigs_SetInfoBoxTable", self, tbl)
	end
end

function boss:OpenInfo(key, title)
	if checkFlag(self, key, C.INFOBOX) then
		self:SendMessage("BigWigs_ShowInfoBox", self, title or (type(key) == "number" and spells[key]))
	end
end

function boss:CloseInfo(key)
	if checkFlag(self, key, C.INFOBOX) then
		self:SendMessage("BigWigs_HideInfoBox", self)
	end
end

-------------------------------------------------------------------------------
-- Proximity.
-- @section proximity
--

--- Open the proximity display.
-- @param key the option key to check
-- @param range the distance to check
-- @param[opt] player the player name for a target proximity
-- @param[opt] isReverse if true, reverse the logic to warn if not within range
function boss:OpenProximity(key, range, player, isReverse)
	if not solo and checkFlag(self, key, C.PROXIMITY) then
		if type(key) == "number" then
			self:SendMessage("BigWigs_ShowProximity", self, range, key, player, isReverse, spells[key], icons[key])
		else
			self:SendMessage("BigWigs_ShowProximity", self, range, key, player, isReverse)
		end
	end
end

--- Close the proximity display.
-- @param[opt] key the option key to check ("proximity" if nil)
function boss:CloseProximity(key)
	if not solo and checkFlag(self, key or "proximity", C.PROXIMITY) then
		self:SendMessage("BigWigs_HideProximity", self, key or "proximity")
	end
end

-------------------------------------------------------------------------------
-- Nameplates.
-- @section nameplates
--

--- Toggle showing hostile nameplates to the enabled state.
function boss:ShowPlates()
	self:SendMessage("BigWigs_EnableHostileNameplates", self)
end

--- Toggle showing hostile nameplates to the disabled state.
function boss:HidePlates()
	self:SendMessage("BigWigs_DisableHostileNameplates", self)
end

--- Add icon to hostile nameplate.
-- @param spellId the associated spell id
-- @param guid the hostile unit guid
-- @param[opt] duration the duration of the aura
-- @param[opt] desaturate true if the texture should be desaturated
function boss:AddPlateIcon(spellId, guid, duration, desaturate)
	self:SendMessage("BigWigs_AddNameplateIcon", self, guid, icons[spellId], duration, desaturate)
end

--- Remove icon from hostile nameplate.
-- @param spellId the associated spell id, passing nil removes all icons
-- @param guid the hostile unit guid
function boss:RemovePlateIcon(spellId, guid)
	self:SendMessage("BigWigs_RemoveNameplateIcon", self, guid, spellId and icons[spellId])
end

--- Add aura to nameplate. [DEPRECATED, removed in 7.2]
-- @param spellId the associated spell id
-- @param playerName the affected player
-- @param[opt] duration the duration of the aura
-- @param[opt] isHostile if the unit is a hostile nameplate, in which case playerName should be treated as a GUID
-- @param[opt] desaturate true if the texture should be desaturated
function boss:AddPlate(spellId, playerName, duration, isHostile, desaturate)
	self:SendMessage("BigWigs_ShowNameplateAura", self, playerName, icons[spellId], duration, desaturate, isHostile)
end

--- Remove aura from nameplate. [DEPRECATED, removed in 7.2]
-- @param spellId the associated spell id, passing nil removes all icons
-- @param playerName the affected player
-- @param[opt] isHostile if the unit is a hostile nameplate, in which case playerName should be treated as a GUID
function boss:RemovePlate(spellId, playerName, isHostile)
	self:SendMessage("BigWigs_HideNameplateAura", self, playerName, spellId and icons[spellId], isHostile)
end

-------------------------------------------------------------------------------
-- Messages.
-- @section messages
--

--- Cancel a delayed message.
-- @param text the text of the message to cancel
function boss:CancelDelayedMessage(text)
	if self.scheduledMessages and self.scheduledMessages[text] then
		self:CancelTimer(self.scheduledMessages[text])
		self.scheduledMessages[text] = nil
	end
end

--- Schedule a delayed message.
-- The messages are keyed by their text, so scheduling the same message will
-- overwrite the previous message's delay.
-- @param key the option key
-- @param delay the delay in seconds
-- @param color the message color category
-- @param[opt] text the message text (if nil, key is used)
-- @param[opt] icon the message icon (spell id or texture name)
-- @param[opt] sound the message sound
function boss:DelayedMessage(key, delay, color, text, icon, sound)
	if checkFlag(self, key, C.MESSAGE) then
		self:CancelDelayedMessage(text or key)
		if not self.scheduledMessages then self.scheduledMessages = {} end
		self.scheduledMessages[text or key] = self:ScheduleTimer("Message", delay, key, color, sound, text, icon or false)
	end
end

--- Display a colored message.
-- @param key the option key
-- @param color the message color category
-- @param[opt] sound the message sound
-- @param[opt] text the message text (if nil, key is used)
-- @param[opt] icon the message icon (spell id or texture name)
function boss:Message(key, color, sound, text, icon)
	if checkFlag(self, key, C.MESSAGE) then
		local textType = type(text)

		local temp = (icon == false and 0) or (icon ~= false and icon) or (textType == "number" and text) or key
		if temp == key and type(key) == "string" then
			core:Print(("Message '%s' doesn't have an icon set."):format(textType == "string" and text or spells[text or key])) -- XXX temp
		end

		self:SendMessage("BigWigs_Message", self, key, textType == "string" and text or spells[text or key], color, icon ~= false and icons[icon or textType == "number" and text or key])
		if sound then
			if hasVoice and checkFlag(self, key, C.VOICE) then
				self:SendMessage("BigWigs_Voice", self, key, sound)
			else
				self:SendMessage("BigWigs_Sound", self, key, sound)
			end
		end
	end
end

function boss:Emphasized(key, msg, r, g, b)
	if checkFlag(self, key, C.EMPHASIZE) then
		self:SendMessage("BigWigs_EmphasizedMessage", msg, r, g, b)
	end
end

do
	local hexColors = {}
	for k, v in next, (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS) do
		hexColors[k] = format("|cff%02x%02x%02x", v.r * 255, v.g * 255, v.b * 255)
	end
	local coloredNames = setmetatable({}, {__index =
		function(self, key)
			if key then
				local shortKey = gsub(key, "%-.+", "*") -- Replace server names with *
				local _, class = UnitClass(key)
				if class then
					local newKey = hexColors[class] .. shortKey .. "|r"
					self[key] = newKey
					return newKey
				else
					return shortKey
				end
			end
		end
	})

	local mt = {
		__newindex = function(self, key, value)
			rawset(self, key, coloredNames[value])
		end
	}
	--- Get a table that colors player names based on class.
	-- @return an empty table
	function boss:NewTargetList()
		return setmetatable({}, mt)
	end

	local tmp = {}
	--- Color a player name based on class.
	-- @param player the player name
	-- @return colored player name
	function boss:ColorName(player)
		if type(player) == "table" then
			wipe(tmp)
			for i, v in ipairs(player) do
				tmp[i] = coloredNames[v]
			end
			return tmp
		else
			return coloredNames[player]
		end
	end

	--- Display a buff/debuff stack warning message.
	-- @param key the option key
	-- @param player the player to display
	-- @param stack the stack count
	-- @param color the message color category
	-- @param[opt] sound the message sound
	-- @param[opt] text the message text (if nil, key is used)
	-- @param[opt] icon the message icon (spell id or texture name)
	function boss:StackMessage(key, player, stack, color, sound, text, icon)
		if checkFlag(self, key, C.MESSAGE) then
			local textType = type(text)
			if player == pName then
				self:SendMessage("BigWigs_Message", self, key, format(L.stackyou, stack or 1, textType == "string" and text or spells[text or key]), "Personal", icon ~= false and icons[icon or textType == "number" and text or key])
			else
				self:SendMessage("BigWigs_Message", self, key, format(L.stack, stack or 1, textType == "string" and text or spells[text or key], coloredNames[player]), color, icon ~= false and icons[icon or textType == "number" and text or key])
			end
			if sound then
				if hasVoice and checkFlag(self, key, C.VOICE) then
					self:SendMessage("BigWigs_Voice", self, key, sound)
				else
					self:SendMessage("BigWigs_Sound", self, key, sound)
				end
			end
		end
	end

	--- Display a target message.
	-- @param key the option key
	-- @param player the player to display
	-- @param color the message color category
	-- @param[opt] sound the message sound
	-- @param[opt] text the message text (if nil, key is used)
	-- @param[opt] icon the message icon (spell id or texture name)
	-- @param[opt] alwaysPlaySound if true, play the sound even if player is not you
	function boss:TargetMessage(key, player, color, sound, text, icon, alwaysPlaySound)
		local textType = type(text)
		local msg = textType == "string" and text or spells[text or key]
		local texture = icon ~= false and icons[icon or textType == "number" and text or key]

		if type(player) == "table" then
			local list = table.concat(player, ", ")
			local meOnly = checkFlag(self, key, C.ME_ONLY)
			local onMe = find(list, pName, nil, true)
			if not onMe then
				if not checkFlag(self, key, C.MESSAGE) or meOnly then wipe(player) return end
				if not alwaysPlaySound then sound = nil end
			else
				if not checkFlag(self, key, C.MESSAGE) and not meOnly then wipe(player) return end
			end
			if meOnly or (onMe and #player == 1) then
				self:SendMessage("BigWigs_Message", self, key, format(L.you, msg), "Personal", texture)
			else
				self:SendMessage("BigWigs_Message", self, key, format(L.other, msg, list), color, texture)
			end
			if sound then
				if hasVoice and checkFlag(self, key, C.VOICE) then
					self:SendMessage("BigWigs_Voice", self, key, sound)
				else
					self:SendMessage("BigWigs_Sound", self, key, sound)
				end
			end
			wipe(player)
		else
			if not player then
				if checkFlag(self, key, C.MESSAGE) then
					self:SendMessage("BigWigs_Message", self, key, format(L.other, msg, "???"), color == "Personal" and "Important" or color, texture)
					if alwaysPlaySound then
						self:SendMessage("BigWigs_Sound", self, key, sound)
					end
				end
				return
			end
			if player == pName then
				if checkFlag(self, key, C.MESSAGE) or checkFlag(self, key, C.ME_ONLY) then
					self:SendMessage("BigWigs_Message", self, key, format(L.you, msg), "Personal", texture)
					if sound then
						if hasVoice and checkFlag(self, key, C.VOICE) then
							self:SendMessage("BigWigs_Voice", self, key, sound, true)
						else
							self:SendMessage("BigWigs_Sound", self, key, sound)
						end
					end
				end
			else
				if checkFlag(self, key, C.MESSAGE) and not checkFlag(self, key, C.ME_ONLY) then
					-- Change color and remove sound (if not alwaysPlaySound) when warning about effects on other players
					self:SendMessage("BigWigs_Message", self, key, format(L.other, msg, coloredNames[player]), color == "Personal" and "Important" or color, texture)
					if sound then
						if alwaysPlaySound and hasVoice and checkFlag(self, key, C.VOICE) then
							self:SendMessage("BigWigs_Voice", self, key, sound)
						elseif alwaysPlaySound then
							self:SendMessage("BigWigs_Sound", self, key, sound)
						end
					end
				end
			end
		end
	end
end


-------------------------------------------------------------------------------
-- Autotimers.
-- @section autotimers
--

local autoTimersMissing = "Missing timer until next '%s' (%s)."
local autoTimersFound = "Last '%s' was %s sec. ago."
local autoTimersSummary = "|cff64b4ff[%s]|cffffffff: %s"

local function round(value, decimals)
	return math.floor((value * 10 ^ decimals) + 0.5) / (10 ^ decimals)
end

local function autotimers(self, key, label)
	core:Print(format(autoTimersMissing, label, key))
	local now = GetTime()
	local last, lastLabel = self.autoTimers[key], self.autoTimersLabels[key]
	self.autoTimers[key], self.autoTimersLabels[key] = now, label
	if last then
		local timer = round(now - last, 2)
		core:Print(format(autoTimersFound, lastLabel, timer))
		if not self.autoTimersSummary[key] then
			self.autoTimersSummary[key] = { timer }
		else
			table.insert(self.autoTimersSummary[key], timer)
		end
	end
end

function boss:TimersCheckpoint(key)
	if not key then
		wipe(self.autoTimers)
		wipe(self.autoTimersLabels)
		for key, timers in pairs(self.autoTimersSummary) do
			table.insert(timers, "C")
		end
	else
		self.autoTimers[key] = nil
		self.autoTimersLabels[key] = nil
		if self.autoTimersSummary[key] then
			table.insert(self.autoTimersSummary[key], "C")
		end
	end
end

function boss:OnDisableAutoTimersSummary()
	if not next(self.autoTimersSummary) then return end
	core:Print("|cffffffffAuto-Timers summary:")
	for key, timers in pairs(self.autoTimersSummary) do
		local label = type(key) == "number" and (key .. "-" .. spells[key]) or key
		core:Print(autoTimersSummary:format(label, table.concat(timers, ", ")))
	end
end

-------------------------------------------------------------------------------
-- Bars.
-- @section bars
--

do
	local msg = "Attempted to start bar %q without a valid time."

	--- Display a bar.
	-- @param key the option key
	-- @param length the bar duration in seconds
	-- @param[opt] text the bar text (if nil, key is used)
	-- @param[opt] icon the bar icon (spell id or texture name)
	function boss:Bar(key, length, text, icon)
		local textType = type(text)
		local msg = textType == "string" and text or spells[text or key]

		if not length then
			return autotimers(self, key, msg)
		elseif length < 0 then
			return
		end

		if checkFlag(self, key, C.BAR) then
			self:SendMessage("BigWigs_StartBar", self, key, msg, length, icons[icon or textType == "number" and text or key])
		end
		if checkFlag(self, key, C.COUNTDOWN) then
			self:SendMessage("BigWigs_StartEmphasize", self, key, msg, length)
		end
	end

	--- Display a cooldown bar.
	-- Indicates an unreliable duration by prefixing the time with "~"
	-- @param key the option key
	-- @param length the bar duration in seconds
	-- @param[opt] text the bar text (if nil, key is used)
	-- @param[opt] icon the bar icon (spell id or texture name)
	function boss:CDBar(key, length, text, icon)
		local textType = type(text)
		local msg = textType == "string" and text or spells[text or key]

		if not length then
			return autotimers(self, key, msg)
		elseif length < 0 then
			return
		end

		if checkFlag(self, key, C.BAR) then
			self:SendMessage("BigWigs_StartBar", self, key, msg, length, icons[icon or textType == "number" and text or key], true)
		end
		if checkFlag(self, key, C.COUNTDOWN) then
			self:SendMessage("BigWigs_StartEmphasize", self, key, msg, length)
		end
	end

	--- Display a target bar.
	-- @param key the option key
	-- @param length the bar duration in seconds
	-- @param player the player name to show on the bar
	-- @param[opt] text the bar text (if nil, key is used)
	-- @param[opt] icon the bar icon (spell id or texture name)
	function boss:TargetBar(key, length, player, text, icon)
		if type(length) ~= "number" then core:Print(format(msg,key)) return end
		local textType = type(text)
		if not player and checkFlag(self, key, C.BAR) then
			self:SendMessage("BigWigs_StartBar", self, key, format(L.other, textType == "string" and text or spells[text or key], "???"), length, icons[icon or textType == "number" and text or key])
			return
		end
		if player == pName then
			local msg = format(L.you, textType == "string" and text or spells[text or key])
			if checkFlag(self, key, C.BAR) then
				self:SendMessage("BigWigs_StartBar", self, key, msg, length, icons[icon or textType == "number" and text or key])
			end
			if checkFlag(self, key, C.COUNTDOWN) then
				self:SendMessage("BigWigs_StartEmphasize", self, key, msg, length)
			end
		elseif not checkFlag(self, key, C.ME_ONLY) and checkFlag(self, key, C.BAR) then
			self:SendMessage("BigWigs_StartBar", self, key, format(L.other, textType == "string" and text or spells[text or key], gsub(player, "%-.+", "*")), length, icons[icon or textType == "number" and text or key])
		end
	end

	--- Display a cast bar.
	-- @param key the option key
	-- @param length the bar duration in seconds
	-- @param[opt] text the bar text (if nil, key is used)
	-- @param[opt] icon the bar icon (spell id or texture name)
	function boss:CastBar(key, length, text, icon)
		if type(length) ~= "number" then core:Print(format(msg, key)) return end
		local textType = type(text)
		local msg = format(L.cast, textType == "string" and text or spells[text or key])
		if checkFlag(self, key, C.BAR) then
			self:SendMessage("BigWigs_StartBar", self, key, msg, length, icons[icon or textType == "number" and text or key])
		end
		if checkFlag(self, key, C.COUNTDOWN) then
			self:SendMessage("BigWigs_StartEmphasize", self, key, msg, length)
		end
	end
end

--- Stop a bar.
-- @param text the bar text
-- @param[opt] player the player name if stopping a target bar
function boss:StopBar(text, player)
	local msg = type(text) == "number" and spells[text] or text
	if player then
		if player == pName then
			msg = format(L.you, msg)
			self:SendMessage("BigWigs_StopBar", self, msg)
			self:SendMessage("BigWigs_StopEmphasize", self, msg)
		else
			self:SendMessage("BigWigs_StopBar", self, format(L.other, msg, gsub(player, "%-.+", "*")))
		end
	else
		self:SendMessage("BigWigs_StopBar", self, msg)
		self:SendMessage("BigWigs_StopEmphasize", self, msg)
	end
end

--- Pause a bar.
-- @param key the option key
-- @param[opt] text the bar text
function boss:PauseBar(key, text)
	local msg = text or spells[key]
	self:SendMessage("BigWigs_PauseBar", self, msg)
	self:SendMessage("BigWigs_StopEmphasize", self, msg)
end

--- Resume a paused bar.
-- @param key the option key
-- @param[opt] text the bar text
function boss:ResumeBar(key, text)
	local msg = text or spells[key]
	self:SendMessage("BigWigs_ResumeBar", self, msg)
	if checkFlag(self, key, C.COUNTDOWN) then
		local length = self:BarTimeLeft(msg)
		if length > 0 then
			self:SendMessage("BigWigs_StartEmphasize", self, key, msg, length)
		end
	end
end

--- Get the time left for a running bar.
-- @param text the bar text
-- @return the remaining duration in seconds or 0
function boss:BarTimeLeft(text)
	local bars = core:GetPlugin("Bars")
	if bars then
		return bars:GetBarTimeLeft(self, type(text) == "number" and spells[text] or text)
	end
	return 0
end

-------------------------------------------------------------------------------
-- Icons.
-- @section icons
--

--- Set the primary (skull by default) raid target icon.
-- @param key the option key
-- @param[opt] player the player to mark (if nil, the icon is removed)
function boss:PrimaryIcon(key, player)
	if key and not checkFlag(self, key, C.ICON) then return end
	if not player then
		self:SendMessage("BigWigs_RemoveRaidIcon", 1)
	else
		self:SendMessage("BigWigs_SetRaidIcon", player, 1)
	end
end

--- Set the secondary (cross by default) raid target icon.
-- @param key the option key
-- @param[opt] player the player to mark (if nil, the icon is removed)
function boss:SecondaryIcon(key, player)
	if key and not checkFlag(self, key, C.ICON) then return end
	if not player then
		self:SendMessage("BigWigs_RemoveRaidIcon", 2)
	else
		self:SendMessage("BigWigs_SetRaidIcon", player, 2)
	end
end

function boss:SetIcon(key, target, icon)
	if not key or self:GetOption(key) then
		local unit = self:UnitId(target)
		if not unit or not UnitExists(unit) then return end
		SetRaidTarget(unit, icon)
	end
end

-------------------------------------------------------------------------------
-- Misc.
-- @section misc
--

--- Flash the screen edges.
-- @param key the option key
-- @param[opt] icon the icon to pulse if PULSE is set (if nil, key is used)
function boss:Flash(key, icon)
	if checkFlag(self, key, C.FLASH) then
		self:SendMessage("BigWigs_Flash", self, key)
	end
	if checkFlag(self, key, C.PULSE) then
		self:SendMessage("BigWigs_Pulse", self, key, icons[icon or key])
	end
end

function boss:Pulse(key, icon)
	if checkFlag(self, key, C.PULSE) then
		self:SendMessage("BigWigs_Pulse", self, key, icons[icon or key])
	end
end

--- Send a message in SAY.
-- @param key the option key
-- @param msg the message to say (if nil, key is used)
-- @param[opt] directPrint if true, skip formatting the message and print the string directly to chat.
function boss:Say(key, msg, directPrint, channel)
	if not checkFlag(self, key, C.SAY) then return end
	if not channel then channel = "SAY" end
	if directPrint then
		SendChatMessage(msg, channel)
	else
		SendChatMessage(format(L.on, msg and (type(msg) == "number" and spells[msg] or msg) or spells[key], pName), channel)
	end
end

--- Start a countdown using say messages.
-- @param key the option key
-- @param seconds the amount of time in seconds until the countdown expires
-- @param[opt] startAt When to start sending messages in say, default value is at 3 seconds remaining
function boss:SayCountdown(key, seconds, startAt)
	if not checkFlag(self, key, C.SAY) then return end -- XXX implement a dedicated option for 7.3
	local tbl = {}
	for i = 1, (startAt or 3) do
		tbl[i] = self:ScheduleTimer(SendChatMessage, seconds-i, i, "SAY")
	end
	self.sayCountdowns[key] = tbl
end

--- Cancel a countdown using say messages.
-- @param key the option key
function boss:CancelSayCountdown(key)
	if not checkFlag(self, key, C.SAY) then return end
	local tbl = self.sayCountdowns[key]
	if tbl then
		for i = 1, #tbl do
			self:CancelTimer(tbl[i])
		end
	end
end

--- Play a sound.
-- @param key the option key
-- @param sound the sound to play
function boss:PlaySound(key, sound)
	if not checkFlag(self, key, C.MESSAGE) then return end
	if hasVoice and checkFlag(self, key, C.VOICE) then
		self:SendMessage("BigWigs_Voice", self, key, sound)
	else
		self:SendMessage("BigWigs_Sound", self, key, sound)
	end
end


do
	local SendAddonMessage, IsInGroup = BigWigsLoader.SendAddonMessage, IsInGroup
	--- Send an addon sync to other players.
	-- @param msg the sync message/prefix
	-- @param[opt] extra other optional value you want to send
	-- @usage self:Sync("abilityPrefix", data)
	-- @usage self:Sync("ability")
	function boss:Sync(msg, extra)
		if msg then
			self:SendMessage("BigWigs_BossComm", msg, extra, pName)
			self:SendMessage("BigWigs_BossComm_Sync", msg, extra, pName)
			if IsInGroup() then
				msg = "B^".. msg
				if extra then
					msg = msg .."^".. extra
				end
				SendAddonMessage("BigWigs", msg, IsInGroup(2) and "INSTANCE_CHAT" or "RAID")
			end
		end
	end

	function boss:RegisterSync(msg, handler, debounce)
		if not self.syncmsg then
			self.syncmsg = {}
			self.syncmsg_debounce_time = {}
			self.syncmsg_debounce = {}
		end
		if type(handler) == "number" then
			debounce = handler
			handler = nil
		end
		self.syncmsg[msg] = handler or msg
		self.syncmsg_debounce_time[msg] = debounce or 2
	end

	function boss:BigWigs_BossComm_Sync(_, msg, arg)
		if not self.syncmsg or not self.syncmsg[msg] then return end
		local debounce = self.syncmsg_debounce[msg]
		if not debounce then
			debounce = {}
			self.syncmsg_debounce[msg] = debounce
		end
		local key = arg or ""
		local last = self.syncmsg_debounce[msg][key]
		local t = GetTime()
		if not last or t - last > self.syncmsg_debounce_time[msg] then
			self.syncmsg_debounce[msg][key] = t
			self[self.syncmsg[msg]](self, arg)
		end
	end
end

--- Start a "berserk" bar and show an engage message.
-- @number seconds the time before the boss enrages/berserks
-- @bool[opt] noEngageMessage if true, don't display an engage message
-- @string[opt] customBoss set a custom boss name
-- @string[opt] customBerserk set a custom berserk name (and icon if a spell id), defaults to "Berserk"
-- @string[opt] customFinalMessage set a custom message to display when the berserk timer finishes
function boss:Berserk(seconds, noEngageMessage, customBoss, customBerserk, customFinalMessage)
	local name = customBoss or self.displayName
	local key = "berserk"

	-- There are many Berserks, but we use 26662 because Brutallus uses this one.
	-- Brutallus is da bomb.
	local icon = 26662
	local berserk = spells[icon]
	if type(customBerserk) == "number" then
		key = customBerserk
		berserk = spells[customBerserk]
		icon = customBerserk
	elseif type(customBerserk) == "string" then
		berserk = customBerserk
	end

	self:Bar(key, seconds, berserk, icon)

	if not noEngageMessage then
		-- Engage warning with minutes to enrage
		self:Message(key, "Attention", nil, format(L.custom_start, name, berserk, seconds / 60), false)
	end

	-- Half-way to enrage warning.
	local half = seconds / 2
	local m = half % 60
	local halfMin = (half - m) / 60
	self:DelayedMessage(key, half + m, "Positive", format(L.custom_min, berserk, halfMin))

	self:DelayedMessage(key, seconds - 60, "Positive", format(L.custom_min, berserk, 1))
	self:DelayedMessage(key, seconds - 30, "Urgent", format(L.custom_sec, berserk, 30))
	self:DelayedMessage(key, seconds - 10, "Urgent", format(L.custom_sec, berserk, 10))
	self:DelayedMessage(key, seconds - 5, "Important", format(L.custom_sec, berserk, 5))
	self:DelayedMessage(key, seconds, "Important", customFinalMessage or format(L.custom_end, name, berserk), icon, "Alarm")
end

-------------------------------------------------------------------------------
-- Token binding functions
-- @section token_bindings
--

function boss:EnableTokens()
	if not self.tokens then return end
	self:RegisterMessage("BigWigs_FS_Option_Toggled")
	self:SyncTokensState()
end

function boss:DisableTokens()
	if not self.tokens then return end
	for token in pairs(self.tokens) do
		token:Disable()
	end
end

function boss:SyncTokensState()
	if not self.tokens then return end
	for token, opt in pairs(self.tokens) do
		if opt == true or self.db.profile[opt] then
			token:Enable()
		else
			token:Disable()
		end
	end
end

function boss:BigWigs_FS_Option_Toggled(_, module, key, value)
	if module == self then self:SyncTokensState() end
end

function boss:CreateToken(key, promote, option)
	local fullkey = (self.engageId or self:GetName()) .. ":" .. key

	if not self.tokens then
		self.tokens = {}
		self.tokens_opt = {}
	end

	local token = Token:Create(fullkey, false):RequirePromote(promote)

	self.tokens[token] = option or true
	if option then self.tokens_opt[option] = token end

	if self.instanceId then
		token:RequireZone(self.instanceId)
	else
		core:Print("Created a token without an instanceId defined [" .. fullkey .. "]")
	end

	return token
end

function boss:Token(token)
	local t = (token.IsMine and token) or (self.tokens_opt and self.tokens_opt[token])
	return t and t:IsMine() or false
end

-------------------------------------------------------------------------------
-- Networking.
-- @section network
--

function boss:Send(event, data, ...)
	FS:Send("BW_NET_MSG", { event = event, data = data }, ...)
end

function boss:RegisterNetMessage(event, handler)
	if not self.netmsgs then self.netmsgs = {} end
	self.netmsgs[event] = handler or event
end

function boss:BW_NET_MSG(_, msg, channel, source)
	local event = msg and msg.event
	if event and self.netmsgs and self.netmsgs[event] and self[self.netmsgs[event]] then
		self[self.netmsgs[event]](self, msg.data, channel, source)
	end
end

function boss:Emit(msg, ...)
	FS:SendMessage(msg, ...)
end

-------------------------------------------------------------------------------
-- Misc.
-- @section misc
--

do
	local floor = math.floor

	local function item(range, itemid)
		return {
			range = range,
			check = function(unit)
				return IsItemInRange(itemid, unit)
			end
		}
	end

	local function interact(range, index)
		return {
			range = range,
			check = function(unit)
				return CheckInteractDistance(unit, index)
			end
		}
	end

	local ranges = {
		item(5, 37727), -- Ruby Acorn
		item(8, 63427), -- Worgsaw
		interact(10, 2),
		item(11, 33278), -- Burning Torch
		item(13, 32321), -- Sparrowhawk Net
		item(18, 133940), -- Silkweave Bandage
		item(23, 21519), -- Mistletoe
		item(28, 31463), -- Zezzak's Shard
		interact(30, 4),
		item(33, 34191), -- Handful of Snowflakes
		item(38, 18904), -- Zorbin's Ultra-Shrinker
		item(43, 34471), -- Vial of the Sunwell
		item(48, 32698), -- Wrangling Rope
		item(53, 116139), -- Haunting Memento
		item(63, 32825), -- Soul Cannon
		item(73, 41265), -- Eyesore Blaster
		item(83, 35278), -- Reinforced Net
	}

	function boss:Range(unit, lower)
		unit = self:UnitId(unit)
		local prev = 0
		for _, entry in ipairs(ranges) do
			if entry.check(unit) then
				return lower and prev or entry.range
			else
				prev = entry.range
			end
		end
		return prev
	end
end

function boss:UnitId(guid)
	if type(guid) == "number" then
		return self:GetUnitIdByGUID(guid)
	elseif UnitExists(guid) then
		return guid
	elseif guid:sub(1, 6) == "Player" then
		return self:GetPlayerUnitIdByGUID(guid) or Roster:GetUnit(guid)
	else
		return self:GetUnitIdByGUID(guid)
	end
end

function argsVirtuals.sourceUnit(args) return boss:UnitId(args.sourceGUID) end
function argsVirtuals.destUnit(args) return boss:UnitId(args.destGUID) end

--- Check HUD option
-- @param key the option key
function boss:Hud(key)
	return checkFlag(self, key, C.HUD)
end

function boss:HudKey(spellId, guid)
	return (spellId or 0) .. ":" .. (guid or "")
end

-- SmartColor™
function boss:SmartColorSet(key, guid, r, g, b, targets)
	if type(guid) == "number" then
		targets = b
		b = g
		g = r
		r = guid
		guid = nil
	end
	if not guid then guid = myGUID end
	if UnitExists(guid) then guid = UnitGUID(guid) end
	if r > 1 then r = r / 255 end
	if g > 1 then g = g / 255 end
	if b > 1 then b = b / 255 end
	FS:Send("SMARTCOLOR", { action = "set", guid = guid, key = key, color = { r = r, g = g, b = b } }, targets)
end

function boss:SmartColorUnset(key, guid, targets)
	if type(guid) == "table" then
		targets = guid
		guid = nil
	end
	if not guid then guid = myGUID end
	if UnitExists(guid) then guid = UnitGUID(guid) end
	FS:Send("SMARTCOLOR", { action = "unset", guid = guid, key = key }, targets)
end

function boss:SmartColorUnsetAll(key, targets)
	FS:Send("SMARTCOLOR", { action = "unsetall", key = key }, targets)
end

function boss:SmartColorFilter(key)
	return checkFlag(self, key, C.SMARTCOLOR, true)
end

-- Virtual args
function argsVirtuals.sourceKey(args)
	return boss:HudKey(args.spellId, args.sourceGUID)
end

function argsVirtuals.destKey(args)
	return boss:HudKey(args.spellId, args.destGUID)
end
