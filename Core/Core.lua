-------------------------------------------------------------------------------
-- BigWigs API
-- @module BigWigs
-- @alias addon

local addon, bossCore, pluginCore
do
	local _, tbl =...
	addon = tbl.core
	bossCore = tbl.bossPrototype
	pluginCore = tbl.pluginPrototype

	addon.name = "BigWigs"

	local at = LibStub("AceTimer-3.0")
	at:Embed(addon)
	at:Embed(bossCore)
	at:Embed(pluginCore)
end

local adb = LibStub("AceDB-3.0")
local lds = LibStub("LibDualSpec-1.0")

local C -- = BigWigs.C, set from Constants.lua
local L = BigWigsAPI:GetLocale("BigWigs")
local CL = BigWigsAPI:GetLocale("BigWigs: Common")
local loader = BigWigsLoader
addon.SendMessage = loader.SendMessage

local customBossOptions = {}
local pName = UnitName("player")

local mod, bosses, plugins = {}, {}, {}

-- Try to grab unhooked copies of critical loading funcs (hooked by some crappy addons)
local GetBestMapForUnit = loader.GetBestMapForUnit
local SendAddonMessage = loader.SendAddonMessage
local GetInstanceInfo = loader.GetInstanceInfo

-- Upvalues
local next, type, setmetatable = next, type, setmetatable
local UnitGUID = UnitGUID

-------------------------------------------------------------------------------
-- Event handling
--

do
	local noEvent = "Module %q tried to register/unregister an event without specifying which event."
	local noFunc = "Module %q tried to register an event with the function '%s' which doesn't exist in the module."

	local eventMap = {}
	local bwUtilityFrame = CreateFrame("Frame")
	bwUtilityFrame:SetScript("OnEvent", function(_, event, ...)
		for k,v in next, eventMap[event] do
			if type(v) == "function" then
				v(event, ...)
			else
				k[v](k, event, ...)
			end
		end
	end)

	function addon:RegisterEvent(event, func)
		if type(event) ~= "string" then error((noEvent):format(self.moduleName)) end
		if (not func and not self[event]) or (type(func) == "string" and not self[func]) then error((noFunc):format(self.moduleName or "?", func or event)) end
		if not eventMap[event] then eventMap[event] = {} end
		eventMap[event][self] = func or event
		bwUtilityFrame:RegisterEvent(event)
	end
	function addon:UnregisterEvent(event)
		if type(event) ~= "string" then error((noEvent):format(self.moduleName)) end
		if not eventMap[event] then return end
		eventMap[event][self] = nil
		if not next(eventMap[event]) then
			bwUtilityFrame:UnregisterEvent(event)
			eventMap[event] = nil
		end
	end

	local function UnregisterAllEvents(_, module)
		for k,v in next, eventMap do
			for j in next, v do
				if j == module then
					module:UnregisterEvent(k)
				end
			end
		end
	end
	loader.RegisterMessage(mod, "BigWigs_OnBossDisable", UnregisterAllEvents)
	loader.RegisterMessage(mod, "BigWigs_OnBossReboot", UnregisterAllEvents)
	loader.RegisterMessage(mod, "BigWigs_OnPluginDisable", UnregisterAllEvents)
end

-------------------------------------------------------------------------------
-- ENCOUNTER event handler
--

function mod:ENCOUNTER_START(_, id)
	for _, module in next, bosses do
		if module.engageId == id then
			if not module.enabled then
				module:Enable()
				if UnitGUID("boss1") then -- Only if _START fired after IEEU
					module:Engage()
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Target monitoring
--

local enablezones, enablemobs = {}, {}
local monitoring = nil

local function enableBossModule(module, sync)
	if not module.enabled then
		module:Enable()
		if sync and not module.worldBoss then
			module:Sync("Enable", module.moduleName)
		end
	end
end

local function shouldReallyEnable(unit, moduleName, mobId, sync)
	local module = bosses[moduleName]
	if not module or module.enabled then return end
	if (not module.VerifyEnable or module:VerifyEnable(unit, mobId)) then
		enableBossModule(module, sync)
	end
end

local function targetSeen(unit, targetModule, mobId, sync)
	if type(targetModule) == "string" then
		shouldReallyEnable(unit, targetModule, mobId, sync)
	else
		for i = 1, #targetModule do
			local module = targetModule[i]
			shouldReallyEnable(unit, module, mobId, sync)
		end
	end
end

local function targetCheck(unit, sync)
	if not UnitName(unit) or UnitIsCorpse(unit) or UnitIsDead(unit) or UnitPlayerControlled(unit) then return end
	local _, _, _, _, _, mobId = strsplit("-", (UnitGUID(unit)))
	local id = tonumber(mobId)
	if id and enablemobs[id] then
		targetSeen(unit, enablemobs[id], id, sync)
	end
end

local function updateMouseover() targetCheck("mouseover", true) end
local function unitTargetChanged(event, target)
	targetCheck(target .. "target")
end

local function zoneChanged()
	local _, instanceType, _, _, _, _, _, id = GetInstanceInfo()
	if instanceType == "none" then
		local mapId = GetBestMapForUnit("player")
		if mapId then
			id = -mapId
		end
	end
	if enablezones[id] then
		if not monitoring then
			monitoring = true
			addon.RegisterEvent(mod, "UPDATE_MOUSEOVER_UNIT", updateMouseover)
			addon.RegisterEvent(mod, "UNIT_TARGET", unitTargetChanged)
			targetCheck("target")
			targetCheck("mouseover")
			targetCheck("boss1")
		end
	elseif monitoring then
		monitoring = nil
		addon.UnregisterEvent(mod, "UPDATE_MOUSEOVER_UNIT")
		addon.UnregisterEvent(mod, "UNIT_TARGET")
	end
end

do
	local function add(moduleName, tbl, ...)
		for i = 1, select("#", ...) do
			local entry = select(i, ...)
			local t = type(tbl[entry])
			if t == "nil" then
				tbl[entry] = moduleName
			elseif t == "table" then
				tbl[entry][#tbl[entry] + 1] = moduleName
			elseif t == "string" then
				local tmp = tbl[entry]
				tbl[entry] = { tmp, moduleName }
			else
				error(("Unknown type in a enable trigger table at index %d for %q."):format(i, tostring(moduleName)))
			end
		end
	end
	function addon:RegisterEnableMob(module, ...) add(module.moduleName, enablemobs, ...) end
	function addon:GetEnableMobs() return enablemobs end
end

-------------------------------------------------------------------------------
-- Testing
--

do
	local callbackRegistered = nil
	local messages = {}
	local colors = {"red", "blue", "orange", "yellow", "green", "cyan", "purple"}
	local sounds = {"Long", "Info", "Alert", "Alarm", "Warning", false, false, false, false, false}

	local function barStopped(event, bar)
		local a = bar:Get("bigwigs:anchor")
		local key = bar:GetLabel()
		if a and messages[key] then
			local color = colors[random(1, #colors)]
			local sound = sounds[random(1, #sounds)]
			if random(1, 4) == 2 then
				addon:SendMessage("BigWigs_Flash", addon, key)
			end
			addon:Print(L.test .." - ".. color ..": ".. key)
			addon:SendMessage("BigWigs_Message", addon, key, color..": "..key, color, messages[key])
			addon:SendMessage("BigWigs_Sound", addon, key, sound)
			messages[key] = nil
		end
	end

	function addon:Test()
		if not callbackRegistered then
			LibStub("LibCandyBar-3.0").RegisterCallback(addon, "LibCandyBar_Stop", barStopped)
			callbackRegistered = true
		end

		local spell, icon
		local _, _, offset, numSpells = GetSpellTabInfo(2) -- Main spec
		for i = offset + 1, offset + numSpells do
			spell = GetSpellBookItemName(i, "spell")
			icon = GetSpellBookItemTexture(i, "spell")
			if not messages[spell] then break end
		end

		local time = random(11, 30)
		messages[spell] = icon

		addon:SendMessage("BigWigs_StartBar", addon, spell, spell, time, icon)
		addon:SendMessage("BigWigs_StartImpactBar", addon, spell, spell, time, icon)

		-- Aura Tracker
		do
			local stacks = math.random() < 0.4 and math.ceil(math.random() * 9) or nil
			local countdown = not stacks and math.random() < 0.7
			addon:SendMessage("BigWigs_ShowAura", addon, nil, {
				icon = icon,
				duration = time / 2,
				text = spell,
				pulse = math.random() < 0.8,
				countdown = countdown,
				stacks = stacks,
				glow = math.random() < 0.2,
				pin = math.random() < 0.2 and -1 or nil,
			})
		end
	end
end

-------------------------------------------------------------------------------
-- Communication
--

local function bossComm(_, msg, extra, sender)
	if msg == "Enable" and extra then
		local m = bosses[extra]
		if m and not m.enabled and sender ~= pName then
			enableBossModule(m)
		end
	end
end

function mod:RAID_BOSS_WHISPER(_, msg) -- Purely for Transcriptor to assist in logging purposes.
	if IsInGroup() then
		SendAddonMessage("Transcriptor", msg, IsInGroup(2) and "INSTANCE_CHAT" or "RAID")
	end
end

-------------------------------------------------------------------------------
-- Initialization
--

local initModules = {}
do
	local function InitializeModules()
		local count = #initModules
		if count > 0 then
			for i = 1, count do
				initModules[i]:Initialize()
			end
			initModules = {}
			-- For LoD users
			-- ZONE_CHANGED_NEW_AREA > LoadAddOn
			-- ADDON_LOADED > InitializeModules
			-- We're in a brand new zone that loaded a new addon and added modules.
			-- Now force a zone check to be able to enable those modules.
			zoneChanged()
		end
	end

	local function profileUpdate()
		addon:SendMessage("BigWigs_ProfileUpdate")
	end

	local addonName = ...
	function mod:ADDON_LOADED(_, name)
		if name ~= addonName then return end

		local defaults = {
			profile = {
				flash = true,
				showZoneMessages = true,
				fakeDBMVersion = false,
			},
			global = {
				optionShiftIndexes = {},
				watchedMovies = {},
			},
		}
		local db = adb:New("BigWigs3DB", defaults, true)
		lds:EnhanceDatabase(db, "BigWigs3DB")

		db.RegisterCallback(mod, "OnProfileChanged", profileUpdate)
		db.RegisterCallback(mod, "OnProfileCopied", profileUpdate)
		db.RegisterCallback(mod, "OnProfileReset", profileUpdate)
		addon.db = db

		mod.ADDON_LOADED = InitializeModules
		InitializeModules()
	end
	addon.RegisterEvent(mod, "ADDON_LOADED")
end

do
	local function EnablePlugins()
		for _, module in next, plugins do
			module:Enable()
		end
	end
	function addon:Enable()
		if not mod.enabled then
			mod.enabled = true

			loader.RegisterMessage(mod, "BigWigs_BossComm", bossComm)
			addon.RegisterEvent(mod, "ZONE_CHANGED_NEW_AREA", zoneChanged)
			addon.RegisterEvent(mod, "ENCOUNTER_START")
			addon.RegisterEvent(mod, "RAID_BOSS_WHISPER")

			if IsLoggedIn() then
				EnablePlugins()
			else
				addon.RegisterEvent(mod, "PLAYER_LOGIN", EnablePlugins)
			end

			zoneChanged()
			addon:SendMessage("BigWigs_CoreEnabled")
		end
	end
end

do
	local function DisableModules()
		for _, module in next, bosses do
			module:Disable()
		end
		for _, module in next, plugins do
			module:Disable()
		end
	end
	function addon:Disable()
		if mod.enabled then
			mod.enabled = nil

			loader.UnregisterMessage(mod, "BigWigs_BossComm")
			addon.UnregisterEvent(mod, "ZONE_CHANGED_NEW_AREA")
			addon.UnregisterEvent(mod, "ENCOUNTER_START")
			addon.UnregisterEvent(mod, "RAID_BOSS_WHISPER")

			self:CancelAllTimers()

			zoneChanged() -- Unregister zone events
			DisableModules()
			monitoring = nil
			addon:SendMessage("BigWigs_CoreDisabled")
		end
	end
end

function addon:IsEnabled()
	return mod.enabled
end

function addon:Print(msg)
	print("BigWigs: |cffffff00"..msg.."|r")
end

function addon:Error(msg)
	addon:Print(msg)
	geterrorhandler()(msg)
end

-------------------------------------------------------------------------------
-- API - if anything else is exposed on the BigWigs object, that's a mistake!
-- Well .. except the module API, obviously.
--

do
	function addon:RegisterBossOption(key, name, desc, func, icon)
		if customBossOptions[key] then
			error("The custom boss option %q has already been registered."):format(key)
		end
		customBossOptions[key] = { name, desc, func, icon }
	end

	-- Adding core generic toggles
	addon:RegisterBossOption("berserk", L.berserk, L.berserk_desc, nil, 136224) -- 136224 = "Interface\\Icons\\spell_shadow_unholyfrenzy"
	addon:RegisterBossOption("altpower", L.altpower, L.altpower_desc, nil, 429383) -- 429383 = "Interface\\Icons\\spell_arcane_invocation"
	addon:RegisterBossOption("infobox", L.infobox, L.infobox_desc, nil, 443374) -- Interface\\Icons\\INV_MISC_CAT_TRINKET05
	addon:RegisterBossOption("stages", L.stages, L.stages_desc)
	addon:RegisterBossOption("warmup", L.warmup, L.warmup_desc)
end

function addon:GetCustomBossOptions()
	return customBossOptions
end

do
	local L = GetLocale()
	if L == "enGB" then L = "enUS" end
	function addon:NewBossLocale(moduleName, locale)
		local module = bosses[moduleName]
		if module and L == locale then
			return module:GetLocale()
		end
	end
end

-------------------------------------------------------------------------------
-- Module handling
--

do
	local GetSpellInfo, C_EncounterJournal_GetSectionInfo = GetSpellInfo, C_EncounterJournal.GetSectionInfo
	local EJ_GetEncounterInfo = EJ_GetEncounterInfo

	local errorAlreadyRegistered = "%q already exists as a module in BigWigs, but something is trying to register it again."

	function addon:NewBoss(moduleName, zoneId, journalId, instanceId)
		if bosses[moduleName] then
			addon:Print(errorAlreadyRegistered:format(moduleName))
		else
			local m = setmetatable({
				name = "BigWigs_Bosses_"..moduleName, -- XXX AceAddon/AceDB backwards compat
				moduleName = moduleName,

				-- Embed callback handler
				RegisterMessage = loader.RegisterMessage,
				UnregisterMessage = loader.UnregisterMessage,
				SendMessage = loader.SendMessage,

				-- Embed event handler
				RegisterEvent = addon.RegisterEvent,
				UnregisterEvent = addon.UnregisterEvent,
			}, { __index = bossCore, __metatable = false })
			bosses[moduleName] = m
			initModules[#initModules+1] = m

			if journalId then
				m.journalId = journalId
				m.displayName = EJ_GetEncounterInfo(journalId)
			else
				m.displayName = moduleName
			end

			if zoneId > 0 then
				m.instanceId = zoneId
			else
				m.mapId = -zoneId
			end
			return m, CL
		end
	end

	function addon:NewPlugin(moduleName)
		if plugins[moduleName] then
			addon:Print(errorAlreadyRegistered:format(moduleName))
		else
			local m = setmetatable({
				name = "BigWigs_Plugins_"..moduleName, -- XXX AceAddon/AceDB backwards compat
				moduleName = moduleName,

				-- Embed callback handler
				RegisterMessage = loader.RegisterMessage,
				UnregisterMessage = loader.UnregisterMessage,
				SendMessage = loader.SendMessage,

				-- Embed event handler
				RegisterEvent = addon.RegisterEvent,
				UnregisterEvent = addon.UnregisterEvent,
			}, { __index = pluginCore, __metatable = false })
			plugins[moduleName] = m
			initModules[#initModules+1] = m

			return m, CL
		end
	end

	function addon:IterateBossModules() return next, bosses end
	function addon:GetBossModule(moduleName, silent) 
		if not silent and not bosses[moduleName] then
			error(("No boss module named '%s' found."):format(moduleName))
		else
			return bosses[moduleName]
		end
	end

	function addon:IteratePlugins() return next, plugins end
	function addon:GetPlugin(moduleName, silent)
		if not silent and not plugins[moduleName] then
			error(("No plugin named '%s' found."):format(moduleName))
		else
			return plugins[moduleName]
		end
	end

	local defaultToggles = nil

	local function setupOptions(module)
		if not C then C = addon.C end
		if not defaultToggles then
			defaultToggles = setmetatable({
				berserk = C.BAR + C.MESSAGE + C.SOUND,
				proximity = C.PROXIMITY,
				altpower = C.ALTPOWER,
				infobox = C.INFOBOX,
			}, {__index = function()
				return C.BAR + C.CASTBAR + C.MESSAGE + C.ICON + C.SOUND + C.SAY + C.SAY_COUNTDOWN + C.PROXIMITY + C.FLASH + C.ALTPOWER + C.VOICE + C.INFOBOX
			end})
		end

		if module.optionHeaders then
			for k, v in next, module.optionHeaders do
				if type(v) == "string" then
					if CL[v] then
						module.optionHeaders[k] = CL[v]
					end
				elseif type(v) == "number" then
					if v > 0 then
						local n = GetSpellInfo(v)
						if not n then addon:Error(("Invalid spell ID %d in the optionHeaders for module %s."):format(v, module.name)) end
						module.optionHeaders[k] = n or v
					else
						local tbl = C_EncounterJournal_GetSectionInfo(-v)
						if not tbl then addon:Error(("Invalid journal ID (-)%d in the optionHeaders for module %s."):format(-v, module.name)) end
						module.optionHeaders[k] = tbl.title or v
					end
				end
			end
		end

		if module.toggleOptions then
			module.toggleDefaults = {}
			for k, v in next, module.toggleOptions do
				local bitflags = 0
				local t = type(v)
				if t == "table" then
					for i = 2, #v do
						local flagName = v[i]
						if C[flagName] then
							bitflags = bitflags + C[flagName]
						else
							error(("%q tried to register '%q' as a bitflag for toggleoption '%q'"):format(module.moduleName, flagName, v[1]))
						end
					end
					v = v[1]
					t = type(v)
				end
				-- mix in default toggles for keys we know
				-- this allows for mod.toggleOptions = {1234, {"bosskill", "bar"}}
				-- while bosskill usually only has message
				for _, b in next, C do
					if bit.band(defaultToggles[v], b) == b and bit.band(bitflags, b) ~= b then
						bitflags = bitflags + b
					end
				end
				if t == "string" then
					local custom = v:match("^custom_(o[nf]f?)_.*")
					if custom then
						module.toggleDefaults[v] = custom == "on" and true or false
					else
						module.toggleDefaults[v] = bitflags
					end
				elseif t == "number" then
					if v > 0 then
						local n = GetSpellInfo(v)
						if not n then addon:Error(("Invalid spell ID %d in the toggleOptions for module %s."):format(v, module.name)) end
						module.toggleDefaults[v] = bitflags
					else
						local tbl = C_EncounterJournal_GetSectionInfo(-v)
						if not tbl then addon:Error(("Invalid journal ID (-)%d in the toggleOptions for module %s."):format(-v, module.name)) end
						module.toggleDefaults[v] = bitflags
					end
				end
			end
			module.db = addon.db:RegisterNamespace(module.name, { profile = module.toggleDefaults })
		end
	end

	local function moduleOptions(self)
		if self.GetOptions then
			local toggles, headers = self:GetOptions(CL)
			if toggles then self.toggleOptions = toggles end
			if headers then self.optionHeaders = headers end
			self.GetOptions = nil
		end
		setupOptions(self)
		self.SetupOptions = nil
	end

	function addon:RegisterBossModule(module)
		module.SetupOptions = moduleOptions

		-- Call the module's OnRegister (which is our OnInitialize replacement)
		if type(module.OnRegister) == "function" then
			module:OnRegister()
			module.OnRegister = nil
		end

		addon:SendMessage("BigWigs_BossModuleRegistered", module.moduleName, module)

		local id = module.instanceId or -(module.mapId)
		if not enablezones[id] then
			enablezones[id] = true
		end
	end

	function addon:RegisterPlugin(module)
		if type(module.defaultDB) == "table" then
			module.db = addon.db:RegisterNamespace(module.name, { profile = module.defaultDB } )
		end

		setupOptions(module)

		-- Call the module's OnRegister (which is our OnInitialize replacement)
		if type(module.OnRegister) == "function" then
			module:OnRegister()
			module.OnRegister = nil
		end
		addon:SendMessage("BigWigs_PluginRegistered", module.moduleName, module)

		if mod.enabled then
			module:Enable() -- Support LoD plugins that load after we're enabled (e.g. zone based)
		end
	end

	function addon:AddColors(moduleName, options)
		local module = bosses[moduleName]
		if not module then
			-- addon:Error(("AddColors: Invalid module %q."):format(moduleName))
			return
		end
		module.colorOptions = options
	end

	function addon:AddSounds(moduleName, options)
		local module = bosses[moduleName]
		if not module then
			-- addon:Error(("AddSounds: Invalid module %q."):format(moduleName))
			return
		end
		module.soundOptions = options
	end
end

-------------------------------------------------------------------------------
-- Global
--

BigWigs = setmetatable({}, { __index = addon, __newindex = function() end, __metatable = false })
