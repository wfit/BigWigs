
--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Star Augur Etraeus", 1088, 1732)
if not mod then return end
mod:RegisterEnableMob(103758)
mod.engageId = 1863
mod.respawnTime = 50
mod.instanceId = 1530

--------------------------------------------------------------------------------
-- Locals
--

local Hud = FS.Hud

local phase = 1
local mobCollector = {}
local gravPullSayTimers = {}
local ejectionCount = 1
local grandConjunctionCount = 1
local felNovaCount = 1
local devourCount = 1
local witnessCount = 1
local gravPullCount = 1
local timers = {
	-- Icy Ejection, SPELL_CAST_SUCCESS, timers vary a lot (+-2s)
	[206936] = { 25, 35, 6, 6, 48, 2, 2 },

	-- Fel Ejection, SPELL_CAST_SUCCESS
	[205649] = { 17, 4, 4, 2, 10, 3.5, 3.5, 32, 4, 3.5, 3.5, 3.5, 22, 7.5, 17.5, 1, 2, 1.5 },

	-- Grand Conjunction, SPELL_CAST_START
	[205408] = {
		[1] = { 15.0, 14.0, 14.0, 14.0, 14.0 },
		[2] = { 27.0, 44.8, 57.7 },
		[3] = { 60.0, 44.0, 40.0 },
		[4] = { 47.0, 62.0, 51.0 },
	},

	-- Fel Nova, SPELL_CAST_START
	[206517] = { 51.4, 48, 51 },

	-- World-Devouring Force,SPELL_CAST_START
	[216909] = { 21.4, 42.1, 57.9, 52.2 },
}

local defaultIcons = {
	[205429] = 205429,
	[205445] = 205445,
	[216345] = 216345,
	[216344] = 216344,
}
local icons = defaultIcons

local replacementIcons = {
	[205429] = 227498, -- Yellow/Orange
	[205445] = 227491, -- Red
	[216345] = 227500, -- Green
	[216344] = 227499, -- Blue
}

local redIcon = 189030
local greenIcon = 189032

local starSignsColor = {
	[205429] = {255, 255, 50 }, -- Crab / Yellow
	[205445] = {255, 50, 50}, -- Wolf / Red
	[216345] = {50, 255, 50}, -- Hunter / Green
	[216344] = {128, 128, 255}, -- Dragon / Blue
	["same"] = {50, 255, 50},
	["other"] = {255, 50, 50}
}

--------------------------------------------------------------------------------
-- Upvalues
--

local tDeleteItem = tDeleteItem

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then
	L.yourSign = "Your sign"
	L.with = "with"
	L[205429] = "|T1391538:15:15:0:0:64:64:4:60:4:60|t|cFFFFDD00Crab|r"
	L[205445] = "|T1391537:15:15:0:0:64:64:4:60:4:60|t|cFFFF0000Wolf|r"
	L[216345] = "|T1391536:15:15:0:0:64:64:4:60:4:60|t|cFF00FF00Hunter|r"
	L[216344] = "|T1391535:15:15:0:0:64:64:4:60:4:60|t|cFF00DDFFDragon|r"

	-- XXX replace with core option
	L.nameplate_requirement = "This feature is currently only supported by KuiNameplates. Mythic only."

	L.custom_off_icy_ejection_nameplates = "Show {206936} on friendly nameplates" -- Icy Ejection
	L.custom_off_icy_ejection_nameplates_desc = L.nameplate_requirement

	L.custom_on_fel_ejection_nameplates = "Show {205649} on friendly nameplates" -- Fel Ejection
	L.custom_on_fel_ejection_nameplates_desc = L.nameplate_requirement

	L.custom_on_gravitational_pull_nameplates = "Show {214335} on friendly nameplates" -- Gravitational Pull
	L.custom_on_gravitational_pull_nameplates_desc = L.nameplate_requirement

	L.custom_on_grand_conjunction_nameplates = "Show {205408} on friendly nameplates" -- Grand Conjunction
	L.custom_on_grand_conjunction_nameplates_desc = L.nameplate_requirement

	-- Do no replace this options below
	L.custom_off_gc_replacement_icons = "Use brighter icons for {205408}"
	L.custom_off_gc_replacement_icons_desc = "Replace the nameplate icons used by Grand Conjunction for better visibility:"

	L.custom_off_gc_redgreen_icons = "Only use red and green icons for {205408}"
	L.custom_off_gc_redgreen_icons_desc = "Change the nameplate icons for matching star signs to |T876914:15:15:0:0:64:64:4:60:4:60|t and non matching star signs to |T876915:15:15:0:0:64:64:4:60:4:60|t."
end

do -- Create the description string for the replacement icons
	local s = ""
	local tex = "|T%s:15:15:0:0:64:64:4:60:4:60|t"
	for k, v in pairs(replacementIcons) do
		local _, _, kicon = GetSpellInfo(k)
		local _, _, vicon = GetSpellInfo(v)
		s = s .. "\n" .. tex:format(kicon) .. " => " .. tex:format(vicon)
	end
	L.custom_off_gc_replacement_icons_desc = L.custom_off_gc_replacement_icons_desc .. s
end

--------------------------------------------------------------------------------
-- Initialization
--

local marks = mod:AddTokenOption { "marks", "Automatically set raid target icons", promote = true }
local BEWARE = mod:AddCustomOption { "beware", "BEWARE World-Devouring Force", default = true }
local tex_starsigns = mod:AddCustomOption { "tex_starsigns", "Display Star Signs spell texture on HUD" }
local diff_starsigns = mod:AddCustomOption { "diff_starsigns", "Display Star Signs HUD as Green / Red based on your own sign" }

function mod:GetOptions()
	return {
		--[[ General ]]--
		"stages",
		221875, -- Nether Traversal
		{205408, "FLASH", "PULSE", "HUD"}, -- Grand Conjunction
		tex_starsigns,
		diff_starsigns,
		marks,

		--[[ Stage One ]]--
		206464, -- Coronal Ejection

		--[[ Stage Two ]]--
		{205984, "SAY"}, -- Gravitational Pull
		206589, -- Chilled
		{206936, "SAY", "FLASH", "PROXIMITY"}, -- Icy Ejection
		206949, -- Frigid Nova

		--[[ Stage Three ]]--
		{214167, "SAY"}, -- Gravitational Pull
		{206388, "TANK"}, -- Felburst
		206517, -- Fel Nova
		{205649, "SAY", "FLASH"}, -- Fel Ejection
		206398, -- Felflame

		--[[ Stage Four ]]--
		{214335, "SAY"}, -- Gravitational Pull
		207439, -- Void Nova
		{206965, "FLASH"}, -- Void Burst
		222761, -- Big Bang

		--[[ Thing That Should Not Be ]]--
		207720, -- Witness the Void
		216909, -- World Devouring Force
		BEWARE,
		--{217046, "SAY", "FLASH"} -- Devouring Remnant

		--[[ Mythic Upstream ]] --
		--[["custom_off_icy_ejection_nameplates",
		"custom_on_fel_ejection_nameplates",
		"custom_on_gravitational_pull_nameplates",
		"custom_on_grand_conjunction_nameplates",
		"custom_off_gc_replacement_icons",
		"custom_off_gc_redgreen_icons",]]
	}, {
		["stages"] = "general",
		[206464] = -13033, -- Stage One
		[205984] = -13036, -- Stage Two
		[214167] = -13046, -- Stage Three
		[214335] = -13053, -- Stage Four
		[207720] = -13057, -- Thing That Should Not Be
	}
end

function mod:OnBossEnable()
	--[[ General ]]--
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1")
	self:Log("SPELL_CAST_START", "NetherTraversal", 221875)
	self:Log("SPELL_AURA_APPLIED", "GroundEffectDamage", 206398) -- Felflame
	self:Log("SPELL_AURA_APPLIED_DOSE", "GroundEffectDamage", 206398) -- Felflame

	--[[ Grand Conjunction ]] --
	self:Log("SPELL_CAST_START", "GrandConjunction", 205408)
	self:Log("SPELL_AURA_APPLIED", "StarSignApplied", 205429, 205445, 216345, 216344) -- Crab, Wolf, Hunter, Dragon)
	self:Log("SPELL_AURA_REMOVED", "StarSignRemoved", 205429, 205445, 216345, 216344) -- Crab, Wolf, Hunter, Dragon)

	--[[ Stage One ]]--
	self:Log("SPELL_CAST_SUCCESS", "CoronalEjection", 206464)

	--[[ Stage Two ]]--
	self:Log("SPELL_DAMAGE", "IceburstDamage", 206921)
	self:Log("SPELL_MISSED", "IceburstDamage", 206921)
	self:Log("SPELL_AURA_APPLIED", "GravitationalPull", 205984, 214167, 214335) -- Stage 2, Stage 3, Stage 4
	self:Log("SPELL_AURA_REMOVED", "GravitationalPullRemoved", 205984, 214167, 214335) -- Stage 2, Stage 3, Stage 4
	self:Log("SPELL_CAST_SUCCESS", "GravitationalPullSuccess", 205984, 214167, 214335) -- Stage 2, Stage 3, Stage 4
	self:Log("SPELL_AURA_APPLIED", "Chilled", 206589)
	self:Log("SPELL_CAST_SUCCESS", "IcyEjection", 206936)
	self:Log("SPELL_AURA_APPLIED", "IcyEjectionApplied", 206936)
	self:Log("SPELL_AURA_REMOVED", "IcyEjectionRemoved", 206936)
	self:Log("SPELL_CAST_START", "FrigidNova", 206949)

	--[[ Stage Three ]]--
	self:Log("SPELL_AURA_APPLIED", "Felburst", 206388)
	self:Log("SPELL_AURA_APPLIED_DOSE", "Felburst", 206388)
	self:Log("SPELL_CAST_START", "FelNova", 206517)
	self:Log("SPELL_CAST_SUCCESS", "FelEjection", 205649)
	self:Log("SPELL_AURA_APPLIED", "FelEjectionApplied", 205649)
	self:Log("SPELL_AURA_REMOVED", "FelEjectionRemoved", 205649)

	--[[ Stage Four ]]--
	self:Log("SPELL_CAST_START", "VoidNova", 207439)
	self:Log("SPELL_AURA_APPLIED", "VoidburstApplied", 206965)
	self:Log("SPELL_AURA_APPLIED_DOSE", "VoidburstApplied", 206965)
	self:Log("SPELL_AURA_REMOVED", "VoidburstRemoved", 206965)

	--[[ Thing That Should Not Be ]]--
	self:Log("SPELL_CAST_START", "WitnessTheVoid", 207720)
	self:Log("SPELL_CAST_SUCCESS", "WitnessTheVoidSuccess", 207720)
	self:Death("ThingDeath", 104880) -- Thing That Should Not Be

	--[ Mythic ]]--
	self:Log("SPELL_CAST_START", "WorldDevouringForce", 216909)
	--self:Log("SPELL_AURA_APPLIED", "DevouringRemnant", 217046)

	if self:Mythic() then
		if self:GetOption("custom_off_icy_ejection_nameplates") or -- XXX maybe add these to ShowFriendlyNameplates?
				self:GetOption("custom_on_fel_ejection_nameplates") or
				self:GetOption("custom_on_gravitational_pull_nameplates") or
				self:GetOption("custom_on_grand_conjunction_nameplates") then

			-- Experimenting with using callbacks for nameplate addons
			self:ShowFriendlyNameplates()
			self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") -- see comment above the function for explanation
		end
	end
end

function mod:OnEngage()
	phase = 1
	ejectionCount = 1
	grandConjunctionCount = 1
	wipe(mobCollector)
	wipe(gravPullSayTimers)
	self:Bar(206464, 12.5) -- Coronal Ejection
	self:Bar(221875, self:Mythic() and 60 or 20) -- Nether Traversal
	if self:Mythic() then
		self:Bar(205408, timers[205408][phase][grandConjunctionCount]) -- Grand Conjunction
	end
	starSignTables = {
		[205429] = {},
		[205445] = {},
		[216345] = {},
		[216344] = {},
	}
	if self:GetOption("custom_off_gc_replacement_icons") then
		icons = replacementIcons
	end
end

function mod:OnBossDisable()
	wipe(mobCollector)
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:UNIT_SPELLCAST_SUCCEEDED(unit, spellName, _, _, spellId)
	if spellId == 222130 then -- Phase 2 Conversation
		phase = 2
		self:Message("stages", "Neutral", "Long", "90% - ".. CL.stage:format(2), false)
		self:StopBar(205408) -- Grand Conjunction
		ejectionCount = 1
		grandConjunctionCount = 1
		self:CDBar(206936, timers[206936][ejectionCount], CL.count:format(self:SpellName(206936), ejectionCount))
		self:Bar(205984, 30) -- Gravitational Pull
		self:Bar(206949, 53) -- Frigid Nova
		self:Bar(221875, 188.5) -- Nether Traversal
		if self:Mythic() then
			self:CDBar(205408, timers[205408][phase][grandConjunctionCount]) -- Grand Conjunction
		end

	elseif spellId == 222133 then -- Phase 3 Conversation
		phase = 3
		self:Message("stages", "Neutral", "Long", "60% - ".. CL.stage:format(3), false)
		self:StopBar(CL.count:format(self:SpellName(206936, ejectionCount)))
		self:StopBar(206949) -- Frigid Nova
		self:StopBar(205408) -- Grand Conjunction
		ejectionCount = 1
		grandConjunctionCount = 1
		felNovaCount = 1
		self:CDBar(205649, timers[205649][ejectionCount], CL.count:format(self:SpellName(205649), ejectionCount))
		self:CDBar(214167, 28) -- Gravitational Pull
		self:CDBar(206517, self:Mythic() and timers[206517][felNovaCount] or 62) -- Fel Nova
		self:Bar(221875, 188.5) -- Nether Traversal
		if self:Mythic() then
			self:CDBar(205408, timers[205408][phase][grandConjunctionCount]) -- Grand Conjunction
		end

	elseif spellId == 222134 then -- Phase 4 Conversation
		phase = 4
		self:Message("stages", "Neutral", "Long", "30% - ".. CL.stage:format(4), false)
		self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
		self:StopBar(CL.count:format(self:SpellName(205649, ejectionCount)))
		self:StopBar(206517) -- Fel Nova
		self:StopBar(205408) -- Grand Conjunction
		ejectionCount = 1
		grandConjunctionCount = 1
		devourCount = 1
		gravPullCount = 1
		self:CDBar(214335, 20) -- Gravitational Pull
		self:CDBar(207439, 42) -- Fel Nova
		if self:Mythic() then
			self:CDBar(216909, timers[216909][devourCount]) -- World-Devouring Force
			self:CDBar(205408, timers[205408][phase][grandConjunctionCount]) -- Grand Conjunction
		end
		self:Berserk(201.5, true, nil, 222761, 222761) -- Big Bang (end of cast)
	end
end

function mod:NetherTraversal(args)
	self:Bar(args.spellId, 8.5, CL.cast:format(args.spellName))
end

--[[ Grand Conjunction ]] --
do
	local mySign

	function mod:GrandConjunction(args)
		self:Message(args.spellId, "Attention", "Long", CL.casting:format(args.spellName))
		mySign = nil
		grandConjunctionCount = grandConjunctionCount + 1
		self:Bar(args.spellId, timers[args.spellId][phase][grandConjunctionCount])
	end

	function mod:StarSignApplied(args)
		self:AddPlate(args.spellId, args.destName, 10)
		if self:Hud(205408) then
			local me = self:Me(args.destGUID)
			local sign = args.spellId
			if me then mySign = sign end

			-- Create object
			local obj = me and Hud:DrawTimer(args.destGUID, 50, 15) or Hud:DrawArea(args.destGUID, 50)

			-- Color management
			if self:GetOption(diff_starsigns) then
				local function set_color()
					local color = starSignsColor[mySign == sign and "same" or "other"]
					obj:SetColor(unpack(color))
				end
				if mySign then
					set_color()
				else
					function obj:OnUpdate()
						if mySign ~= nil then
							set_color()
							obj.OnUpdate = nil
						end
					end
				end
			else
				obj:SetColor(unpack(starSignsColor[args.spellId]))
			end

			-- Register
			obj:Register(args.destKey, true)

			-- Texture
			if self:GetOption(tex_starsigns) then
				Hud:DrawTexture(args.destGUID, 50, args.spellIcon):Register(args.destKey)
			end
		end
	end

	function mod:StarSignRemoved(args)
		self:RemovePlate(args.spellId, args.destName)
		Hud:RemoveObject(args.destKey)
	end
end

do
	local prev = 0
	function mod:GroundEffectDamage(args)
		local t = GetTime()
		if self:Me(args.destGUID) and t-prev > 1.5 then
			prev = t
			self:Message(args.spellId, "Personal", "Alert", CL.underyou:format(args.spellName))
		end
	end
end

--[[ Stage One ]]--
function mod:CoronalEjection(args)
	self:Message(args.spellId, "Attention", "Info")
end

--[[ Stage Two ]]--
function mod:IceburstDamage(args)
	if self:Tank(args.destGUID) then
		self:SetIcon(marks, args.destUnit, 8)
	end
end

do
	local timers = {
		[205984] = 30,
		[214167] = 28,
		[214335] = 63,
	}
	function mod:GravitationalPullSuccess(args)
		-- Only show this once by using the success event
		self:TargetMessage(args.spellId, args.destName, "Urgent", "Warning", nil, nil, self:Tank())
		self:CDBar(args.spellId, timers[args.spellId])
		if self:Me(args.destGUID) then
			self:Say(args.spellId)
		end
	end
end

function mod:GravitationalPull(args)
	local _, _, _, _, _, _, expires = UnitDebuff(args.destName, args.spellName)
	local remaining = expires-GetTime()
	self:TargetBar(args.spellId, remaining, args.destName)

	if self:Me(args.destGUID) then
		gravPullSayTimers[1] = self:ScheduleTimer("Say", remaining-3, args.spellId, 3, true)
		gravPullSayTimers[2] = self:ScheduleTimer("Say", remaining-2, args.spellId, 2, true)
		gravPullSayTimers[3] = self:ScheduleTimer("Say", remaining-1, args.spellId, 1, true)
	end

	if phase == 3 then
		self:SetIcon(marks, args.destUnit, 8)
	end

	if self:GetOption("custom_on_gravitational_pull_nameplates") then
		self:AddPlate(args.spellId, args.destName, remaining)
	end
end

function mod:GravitationalPullRemoved(args)
	self:SetIcon(marks, args.destUnit, 0)
	if self:Me(args.destGUID) then
		for i = #gravPullSayTimers, 1, -1 do
			self:CancelTimer(gravPullSayTimers[i])
			gravPullSayTimers[i] = nil
		end
	end
	self:RemovePlate(args.spellId, args.destName)
end

function mod:IcyEjection(args)
	self:StopBar(CL.count:format(args.spellName, ejectionCount))
	if phase == 2 then -- Prevent starting the bar in phase transition
		ejectionCount = ejectionCount + 1
		self:CDBar(args.spellId, timers[args.spellId][ejectionCount] or 30, CL.count:format(args.spellName, ejectionCount))
	end
end

do
	local list = mod:NewTargetList()
	function mod:IcyEjectionApplied(args)
		list[#list+1] = args.destName
		if #list == 1 then
			self:ScheduleTimer("TargetMessage", 0.1, args.spellId, list, "Attention", "Warning")
		end

		if self:Me(args.destGUID) then
			if not self:Mythic() then
				self:Say(args.spellId)
			end
			self:Flash(args.spellId)
			self:OpenProximity(args.spellId, 8)
			self:TargetBar(args.spellId, 10, args.destName)
			self:ScheduleTimer("WarnIcyEjection", 7, args.spellName, args.spellId, 3)
			self:ScheduleTimer("WarnIcyEjection", 8, args.spellName, args.spellId, 2)
			self:ScheduleTimer("WarnIcyEjection", 9, args.spellName, args.spellId, 1)
		end

		if self:GetOption("custom_off_icy_ejection_nameplates") then
			self:AddPlate(args.spellId, args.destName, 8)
		end
	end

	function mod:WarnIcyEjection(spellName, spellId, count)
		if UnitDebuff("player", spellName) then
			self:Say(spellId, count, true)
		end
	end
end

function mod:IcyEjectionRemoved(args)
	if self:Me(args.destGUID) then
		self:CloseProximity(args.spellId)
	end
	self:RemovePlate(args.spellId, args.destName)
end

function mod:FrigidNova(args)
	self:Message(args.spellId, "Important", "Alarm")
	self:Bar(args.spellId, 4, CL.cast:format(args.spellName))
	self:CDBar(args.spellId, 60)
end

function mod:Chilled(args)
	if self:Me(args.destGUID) then
		self:TargetMessage(args.spellId, args.destName, "Personal")
		self:TargetBar(args.spellId, 12, args.destName)
	end
end

--[[ Stage Three ]]--
function mod:Felburst(args)
	local amount = args.amount or 1
	if amount % 2 == 1 or amount > 5 then
		self:StackMessage(args.spellId, args.destName, amount, "Important", amount > 5 and "Warning")
	end
end

function mod:FelNova(args)
	self:Message(args.spellId, "Important", "Alarm")
	self:Bar(args.spellId, 4, CL.cast:format(args.spellName))
	felNovaCount = felNovaCount + 1
	self:CDBar(args.spellId, self:Mythic() and timers[args.spellId][felNovaCount] or 45)
end

function mod:FelEjection(args)
	self:StopBar(CL.count:format(args.spellName, ejectionCount))
	if phase == 3 then -- Prevent starting the bar in phase transition
		ejectionCount = ejectionCount + 1
		self:CDBar(args.spellId, timers[args.spellId][ejectionCount] or 30, CL.count:format(args.spellName, ejectionCount))
	end
end

do
	local list = mod:NewTargetList()
	function mod:FelEjectionApplied(args)
		list[#list+1] = args.destName
		if #list == 1 then
			self:ScheduleTimer("TargetMessage", 0.1, args.spellId, list, "Attention", "Warning")
		end

		if self:Me(args.destGUID) then
			if self:Mythic() then
				self:Say(args.spellId, "{rt8}", true)
			else
				self:Say(args.spellId)
			end
			self:Flash(args.spellId)
			self:TargetBar(args.spellId, 8, args.destName)
			self:ScheduleTimer("Message", 8, args.spellId, "Positive", "Info", CL.removed:format(args.spellName))
		end

		if self:GetOption("custom_on_fel_ejection_nameplates") then
			self:AddPlate(args.spellId, args.destName, 8)
		end
	end

	function mod:FelEjectionRemoved(args)
		self:RemovePlate(args.spellId, args.destName)
	end
end

--[[ Stage Four ]]--
function mod:VoidNova(args)
	self:Message(args.spellId, "Important", "Alarm")
	self:Bar(args.spellId, 4, CL.cast:format(args.spellName))
	self:CDBar(args.spellId, 75)
end

do
	local onMe = false

	function mod:VoidburstApplied(args)
		local amount = args.amount or 1
		if self:Me(args.destGUID) and not onMe and amount >= 15 then
			self:StackMessage(args.spellId, args.destName, amount, "Important", "Warning")
			self:Flash(args.spellId)
			onMe = true
		end
	end

	function mod:VoidburstRemoved(args)
		if self:Me(args.destGUID) then
			onMe = false
		end
	end
end

--[[ Thing That Should Not Be ]]--
function mod:INSTANCE_ENCOUNTER_ENGAGE_UNIT()
	for i = 1, 5 do
		local guid = UnitGUID(("boss%d"):format(i))
		if guid and not mobCollector[guid] then
			mobCollector[guid] = true
			local mobId = self:MobId(guid)
			if mobId == 104880 then -- Thing That Should Not Be
				witnessCount = 1
				self:Bar(207720, self:Mythic() and 11.8 or 16, CL.count:format(self:SpellName(207720), witnessCount)) -- Witness the Void
			end
		end
	end
end

function mod:WitnessTheVoid(args)
	self:Message(args.spellId, "Attention", "Warning", CL.casting:format(CL.count:format(args.spellName, witnessCount)))
	--self:Bar(args.spellId, 4, CL.cast:format(args.spellName))
	--self:Bar(args.spellId, self:Mythic() and 13.4 or 15)
end

function mod:WitnessTheVoidSuccess(args)
	--self:Message(args.spellId, "Attention", "Warning", CL.casting:format(args.spellName))
	--self:Bar(args.spellId, 4, CL.cast:format(args.spellName))
	witnessCount = witnessCount + 1
	self:Bar(args.spellId, self:Mythic() and 13.4 or 15, CL.count:format(args.spellName, witnessCount))
end

function mod:ThingDeath(args)
	self:StopBar(CL.count:format(self:SpellName(207720), witnessCount))
	--self:StopBar(207720) -- Witness the Void
end

do
	local function warnOeil(self, spellId)
		self:Message(spellId, "Attention", nil, "GROS OEIL SOOOOON !")
		PlaySoundFile("Sound\\Creature\\AlgalonTheObserver\\UR_Algalon_BHole01.ogg","Master")
	end

	function mod:WorldDevouringForce(args)
		self:Message(args.spellId, "Attention", "Warning", CL.casting:format(args.spellName))
		--self:Bar(args.spellId, 4, CL.cast:format(args.spellName))
		devourCount = devourCount + 1
		self:CDBar(args.spellId, timers[216909][devourCount])
		if timers[216909][devourCount] and self:GetOption(BEWARE) then
			self:ScheduleTimer(warnOeil, timers[216909][devourCount] - 4, self, args.spellId)
		end
	end
end

function mod:DevouringRemnant(args)
	self:TargetMessage(args.spellId, args.destName, "Urgent", "Warning")
	if self:Me(args.destGUID) then
		self:TargetBar(args.spellId, 6, args.destName)
		self:Flash(args.spellId)
		self:Say(args.spellId)
	end
end
