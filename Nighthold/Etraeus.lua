
--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Star Augur Etraeus", 1088, 1732)
if not mod then return end
mod:RegisterEnableMob(103758)
mod.engageId = 1863
mod.respawnTime = 50 -- might be wrong
mod.instanceId = 1530

--------------------------------------------------------------------------------
-- Locals
--

local phase = 1
local mobCollector = {}
local gravPullSayTimers = {}
local ejectionCount = 1
local grandConjunctionCount = 1
local felNovaCount = 1
local timers = {
	-- Icy Ejection, SPELL_CAST_SUCCESS, timers vary a lot (+-2s)
	[206936] = {25, 35, 6, 6, 48, 2, 2},

	-- Fel Ejection, SPELL_CAST_SUCCESS
	[205649] = {17, 4, 4, 2, 10, 3.5, 3.5, 32, 4, 3.5, 3.5, 3.5, 22, 7.5, 17.5, 1, 2, 1.5},

	-- Grand Conjunction, SPELL_CAST_START
	[205408] = {
		[1] = { 15.0, 14.0, 14.0, 14.0, 14.0 },
		[2] = { 27.0, 44.8, 57.7 },
		[3] = { 60.0, 44.0, 40.0 },
		[4] = {},
	},

	-- Fel Nova, SPELL_CAST_START
	[206517] = { 51.4, 48, 51 },
}

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

local marks = mod:AddTokenOption { "marks", "Automatically set raid target icons", promote = true }
local gcai = mod:AddTokenOption { "gcai", "Perform Grand Conjunction attributions", promote = true, default = false }

function mod:GetOptions()
	return {
		--[[ General ]]--
		"stages",
		marks,
		221875, -- Nether Traversal
		{205408, "FLASH", "PULSE"}, -- Grand Conjunction
		gcai,

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
	self:Log("SPELL_CAST_START", "GrandConjunctionStart", 205408)
	self:Log("SPELL_CAST_SUCCESS", "GrandConjunction", 205408)
	self:Log("SPELL_AURA_APPLIED", "StarSignApplied", 205429, 205445, 216345, 216344) -- Crab, Wolf, Hunter, Dragon
	self:Log("SPELL_AURA_REMOVED", "StarSignRemoved", 205429, 205445, 216345, 216344)
	self:RegisterNetMessage("GCDistances")
	self:RegisterNetMessage("GCPairings")

	--[[ Stage One ]]--
	self:Log("SPELL_CAST_SUCCESS", "CoronalEjection", 206464)

	--[[ Stage Two ]]--
	self:Log("SPELL_DAMAGE", "Iceburst", 206921)
	self:Log("SPELL_AURA_APPLIED", "GravitationalPullP2", 205984)
	self:Log("SPELL_CAST_SUCCESS", "GravitationalPullP2Success", 205984)
	self:Log("SPELL_AURA_APPLIED", "Chilled", 206589)
	self:Log("SPELL_CAST_SUCCESS", "IcyEjection", 206936)
	self:Log("SPELL_AURA_APPLIED", "IcyEjectionApplied", 206936)
	self:Log("SPELL_AURA_REMOVED", "IcyEjectionRemoved", 206936)
	self:Log("SPELL_CAST_START", "FrigidNova", 206949)

	--[[ Stage Three ]]--
	self:Log("SPELL_AURA_APPLIED", "GravitationalPullP3", 214167)
	self:Log("SPELL_CAST_SUCCESS", "GravitationalPullP3Success", 214167)
	self:Log("SPELL_AURA_APPLIED", "Felburst", 206388)
	self:Log("SPELL_AURA_APPLIED_DOSE", "Felburst", 206388)
	self:Log("SPELL_CAST_START", "FelNova", 206517)
	self:Log("SPELL_CAST_SUCCESS", "FelEjection", 205649)
	self:Log("SPELL_AURA_APPLIED", "FelEjectionApplied", 205649)

	--[[ Stage Four ]]--
	self:Log("SPELL_AURA_APPLIED", "GravitationalPullP4", 214335)
	self:Log("SPELL_CAST_SUCCESS", "GravitationalPullP4Success", 214335)
	self:Log("SPELL_CAST_START", "VoidNova", 207439)
	self:Log("SPELL_AURA_APPLIED", "VoidburstApplied", 206965)
	self:Log("SPELL_AURA_APPLIED_DOSE", "VoidburstApplied", 206965)
	self:Log("SPELL_AURA_REMOVED", "VoidburstRemoved", 206965)

	--[[ Thing That Should Not Be ]]--
	self:Log("SPELL_CAST_START", "WitnessTheVoid", 207720)
	self:Death("ThingDeath", 104880) -- Thing That Should Not Be
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
	self:RemarkTanks()
end

function mod:RemarkTanks()
	do return end
	if self:GetOption(marks) then
		local icon = 8
		for unit in self:IterateGroup() do
			if self:Tank(unit) then
				SetRaidTarget(unit, icon)
				icon = icon - 1
			end
		end
	end
end

function mod:OnBossDisable()
	wipe(mobCollector)

	if self:GetOption(marks) then
		for unit in self:IterateGroup() do
			SetRaidTarget(unit, 0)
		end
	end
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:UNIT_SPELLCAST_SUCCEEDED(unit, spellName, _, _, spellId)
	if spellId == 222130 then -- Phase 2 Conversation
		phase = 2
		self:Message("stages", "Neutral", "Long", CL.stage:format(2), false)
		self:StopBar(205408) -- Grand Conjunction
		ejectionCount = 1
		grandConjunctionCount = 1
		self:CDBar(206936, timers[206936][ejectionCount], CL.count:format(self:SpellName(206936), ejectionCount))
		self:Bar(205984, 30) -- Gravitational Pull
		self:Bar(206949, 53) -- Frigid Nova
		self:Bar(221875, 180) -- Nether Traversal
		if self:Mythic() then
			self:CDBar(205408, timers[205408][phase][grandConjunctionCount]) -- Grand Conjunction
		end

		for _,timer in pairs(gravPullSayTimers) do
			self:CancelTimer(timer)
		end
		wipe(gravPullSayTimers)

	elseif spellId == 222133 then -- Phase 3 Conversation
		phase = 3
		self:Message("stages", "Neutral", "Long", CL.stage:format(3), false)
		self:StopBar(CL.count:format(self:SpellName(206936, ejectionCount)))
		self:StopBar(206949) -- Frigid Nova
		self:StopBar(205408) -- Grand Conjunction
		ejectionCount = 1
		grandConjunctionCount = 1
		felNovaCount = 1
		self:CDBar(205649, timers[205649][ejectionCount], CL.count:format(self:SpellName(205649), ejectionCount))
		self:CDBar(214167, 28) -- Gravitational Pull
		self:CDBar(206517, self:Mythic() and timers[206517][felNovaCount] or 62) -- Fel Nova
		self:Bar(221875, 180) -- Nether Traversal
		if self:Mythic() then
			self:CDBar(205408, timers[205408][phase][grandConjunctionCount]) -- Grand Conjunction
		end

		for _,timer in pairs(gravPullSayTimers) do
			self:CancelTimer(timer)
		end
		wipe(gravPullSayTimers)

	elseif spellId == 222134 then -- Phase 4 Conversation
		phase = 4
		self:Message("stages", "Neutral", "Long", CL.stage:format(4), false)
		self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
		self:StopBar(CL.count:format(self:SpellName(205649, ejectionCount)))
		self:StopBar(206517) -- Fel Nova
		self:StopBar(205408) -- Grand Conjunction
		ejectionCount = 1
		grandConjunctionCount = 1
		self:CDBar(214335, 20) -- Gravitational Pull
		self:CDBar(207439, 42) -- Fel Nova
		if self:Mythic() then
			self:CDBar(205408, timers[205408][phase][grandConjunctionCount]) -- Grand Conjunction
		end
		self:Berserk(201.5, true, nil, 222761, 222761) -- Big Bang (end of cast)

		for _,timer in pairs(gravPullSayTimers) do
			self:CancelTimer(timer)
		end
		wipe(gravPullSayTimers)

	end
end

function mod:NetherTraversal(args)
	self:Bar(args.spellId, 8.5, CL.cast:format(args.spellName))
end

--[[ Grand Conjunction ]] --
do
	-- Distances database
	local distances = {}

	local function insertDistance(a, b, distance)
		if a > b then
			insertDistance(b, a, distance)
		else
			if not distances[a] then
				distances[a] = { [b] = distance }
			elseif distances[a][b] then
				distances[a][b] = (distances[a][b] + distance) / 2
			else
				distances[a][b] = distance
			end
		end
	end

	local function distance(a, b)
		if a > b then
			return distance(b, a)
		else
			return distances[a] and distances[a][b] or 25
		end
	end

	-- Cast start, snapshot distances
	function mod:GrandConjunctionStart(args)
		self:Message(args.spellId, "Attention", "Long", CL.casting:format(args.spellName))
		grandConjunctionCount = grandConjunctionCount + 1
		wipe(distances)
		self:ScheduleTimer("SnapshotGrandConjunction", 3.5)
		self:Bar(args.spellId, timers[args.spellId][phase][grandConjunctionCount])
	end

	local myDistances = {}
	local myUnitId
	function mod:SnapshotGrandConjunction()
		wipe(myDistances)
		for unit in self:IterateGroup() do
			if UnitIsUnit(unit, "player") then
				myUnitId = unit
			else
				myDistances[unit] = self:Range(unit)
			end
		end
		mod:Send("GCDistances", { player = myUnitId, distances = myDistances }, "RAID")
	end

	-- Receive distance data from players
	function mod:GCDistances(data)
		local player = data.player
		for unit, range in pairs(data.distances) do
			insertDistance(player, unit, range)
		end
	end

	-- Cast success, perform attribution
	function mod:GrandConjunction(args)
		if phase > 1 then
			if self:GetOption(gcai) then
				self:ScheduleTimer("GrandConjunctionAI", 0.1)
			end
			self:ScheduleTimer("RemarkTanks", 10)
		end
	end

	-- Computes permutations from list of players
	local function permutations(units, trail, used, pairings)
		if #units == #trail then
			local pairing = {}
			for i = 1, #units, 2 do
				pairing[units[trail[i]]] = units[trail[i + 1]]
			end
			pairings[#pairings + 1] = pairing
		else
			for i = 1, #units do
				if not used[i] then
					used[i] = true
					table.insert(trail, i)
					permutations(units, trail, used, pairings)
					table.remove(trail)
					used[i] = false
				end
			end
		end
	end

	-- Computes players pairings
	local function iteratePairings(units)
		-- Ensure we have an even number of units
		if #units % 2 == 1 then
			table.remove(units)
		end

		-- Init accumulators
		local trail = {}
		local used = {}
		local pairings = {}

		permutations(units, trail, used, pairings)
		return ipairs(pairings)
	end

	local Unsuitable = 1e5 -- Added to distance total for unsuitable pairings
	local Debuffs = { -- Debuffs to avoid during pairing evaluation
		mod:SpellName(206936), -- Icy Ejection
		mod:SpellName(205649), -- Fel Ejection
	}

	-- Score a specific set pairings
	local function computeScore(pairings)
		local score = 0
		for a, b in pairs(pairings) do
			score = score + distance(a, b)
			for _, debuff in ipairs(Debuffs) do
				if UnitDebuff(a, debuff) then
					score = score + Unsuitable
					if UnitDebuff(b, debuff) then
						score = score + Unsuitable
					end
				end
			end
		end
		return score;
	end

	local StarSigns = {
		[205429] = mod:SpellName(205429), -- Crab
		[205445] = mod:SpellName(205445), -- Wolf
		[216345] = mod:SpellName(216345), -- Hunter
		[216344] = mod:SpellName(216344), -- Dragon
	}

	function mod:GrandConjunctionAI()
		-- Collect signs
		local signs = {}
		for unit in self:IterateGroup() do
			for sign, name in pairs(StarSigns) do
				if UnitDebuff(unit, name) then
					if not signs[sign] then
						signs[sign] = {}
					end
					table.insert(signs[sign], unit)
					break
				end
			end
		end

		-- Perform pairings
		local results = {}
		for sign, units in pairs(signs) do
			local bestScore = 1e9
			local bestPairings
			for _, pairings in iteratePairings(units) do
				local score = computeScore(pairings)
				if score < bestScore then
					bestScore = score
					bestPairings = pairings
				end
			end
			results[sign] = bestPairings
		end

		mod:Send("GCPairings", results, "RAID")
	end

	-- Receive pairings distance
	function mod:GCPairings(data)
		local nextIcon = 1
		for sign, pairings in pairs(data) do
			for a, b in pairs(pairings) do
				local icon = nextIcon < 9 and nextIcon
				nextIcon = nextIcon + 1
				if icon then
					self:SetIcon(marks, b, nextIcon)
				else
					print("Missing icon for ", UnitName(b))
				end
				if icon and (UnitIsUnit(a, "player") or UnitIsUnit(b, "player")) then
					self:Say(false, ("{rt%d}"):format(icon), true, "YELL")
					self:Pulse(205408, "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. icon)
				end
			end
		end
	end

	function mod:StarSignApplied(args)
	end

	function mod:StarSignRemoved(args)
		self:SetIcon(marks, args.destUnit, 0)
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
function mod:Iceburst(args)
	if self:Tank(args.destGUID) then
		self:SetIcon(marks, args.destUnit, 8)
	end
end

function mod:GravitationalPullP2Success(args)
	self:TargetMessage(args.spellId, args.destName, "Urgent", "Warning", nil, nil, self:Tank())
	self:CDBar(args.spellId, 30)

	if self:Me(args.destGUID) then
		self:Say(args.spellId)
	end
end

function mod:GravitationalPullP2(args)
	local _, _, _, _, _, _, expires = UnitDebuff(args.destName, args.spellName)
	local remaining = expires-GetTime()
	self:TargetBar(args.spellId, remaining, args.destName)

	wipe(gravPullSayTimers) -- they will be done either way
	if self:Me(args.destGUID) then
		gravPullSayTimers[#gravPullSayTimers+1] = self:ScheduleTimer("Say", remaining-3, args.spellId, 3, true)
		gravPullSayTimers[#gravPullSayTimers+1] = self:ScheduleTimer("Say", remaining-2, args.spellId, 2, true)
		gravPullSayTimers[#gravPullSayTimers+1] = self:ScheduleTimer("Say", remaining-1, args.spellId, 1, true)
	end
end

function mod:IcyEjection(args)
	ejectionCount = ejectionCount + 1
	self:CDBar(args.spellId, timers[args.spellId][ejectionCount] or 30, CL.count:format(args.spellName, ejectionCount))
end

do
	local list = mod:NewTargetList()
	function mod:IcyEjectionApplied(args)
		list[#list+1] = args.destName
		if #list == 1 then
			self:ScheduleTimer("TargetMessage", 0.1, args.spellId, list, "Attention", "Warning")
		end

		if self:Me(args.destGUID) then
			self:Say(args.spellId)
			self:Flash(args.spellId)
			self:OpenProximity(args.spellId, 8)
			self:TargetBar(args.spellId, 10, args.destName)
			self:ScheduleTimer("Say", 7, args.spellId, 3, true)
			self:ScheduleTimer("Say", 8, args.spellId, 2, true)
			self:ScheduleTimer("Say", 9, args.spellId, 1, true)
		end
	end
end

function mod:IcyEjectionRemoved(args)
	if self:Me(args.destGUID) then
		self:CloseProximity(args.spellId)
	end
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
function mod:GravitationalPullP3Success(args)
	self:TargetMessage(args.spellId, args.destName, "Urgent", "Warning", nil, nil, self:Tank())
	self:CDBar(args.spellId, 28)

	if self:Me(args.destGUID) then
		self:Say(args.spellId)
	end
end

function mod:GravitationalPullP3(args)
	local _, _, _, _, _, _, expires = UnitDebuff(args.destName, args.spellName)
	local remaining = expires-GetTime()
	self:TargetBar(args.spellId, remaining, args.destName)

	wipe(gravPullSayTimers) -- they will be done either way
	if self:Me(args.destGUID) then
		gravPullSayTimers[#gravPullSayTimers+1] = self:ScheduleTimer("Say", remaining-3, args.spellId, 3, true)
		gravPullSayTimers[#gravPullSayTimers+1] = self:ScheduleTimer("Say", remaining-2, args.spellId, 2, true)
		gravPullSayTimers[#gravPullSayTimers+1] = self:ScheduleTimer("Say", remaining-1, args.spellId, 1, true)
	end
end

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
	ejectionCount = ejectionCount + 1
	self:CDBar(args.spellId, timers[args.spellId][ejectionCount] or 30, CL.count:format(args.spellName, ejectionCount))
end

do
	local list = mod:NewTargetList()
	function mod:FelEjectionApplied(args)
		list[#list+1] = args.destName
		if #list == 1 then
			self:ScheduleTimer("TargetMessage", 0.1, args.spellId, list, "Attention", "Warning")
		end

		if self:Me(args.destGUID) then
			self:Say(args.spellId, "{rt8}", true)
			self:Flash(args.spellId)
			self:TargetBar(args.spellId, 8, args.destName)
			self:ScheduleTimer("Message", 8, args.spellId, "Positive", "Info", CL.removed:format(args.spellName))
		end
	end
end

--[[ Stage Four ]]--
function mod:GravitationalPullP4Success(args)
	self:TargetMessage(args.spellId, args.destName, "Urgent", "Warning", nil, nil, self:Tank())
	self:CDBar(args.spellId, 62)

	if self:Me(args.destGUID) then
		self:Say(args.spellId)
	end
end

function mod:GravitationalPullP4(args)
	local _, _, _, _, _, _, expires = UnitDebuff(args.destName, args.spellName)
	local remaining = expires-GetTime()
	self:TargetBar(args.spellId, remaining, args.destName)

	wipe(gravPullSayTimers) -- they will be done either way
	if self:Me(args.destGUID) then
		gravPullSayTimers[#gravPullSayTimers+1] = self:ScheduleTimer("Say", remaining-3, args.spellId, 3, true)
		gravPullSayTimers[#gravPullSayTimers+1] = self:ScheduleTimer("Say", remaining-2, args.spellId, 2, true)
		gravPullSayTimers[#gravPullSayTimers+1] = self:ScheduleTimer("Say", remaining-1, args.spellId, 1, true)
	end
end

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
				self:Bar(207720, 12) -- Witness the Void
			end
		end
	end
end

function mod:WitnessTheVoid(args)
	self:Message(args.spellId, "Attention", "Warning", CL.casting:format(args.spellName))
	self:Bar(args.spellId, 4, CL.cast:format(args.spellName))
	self:Bar(args.spellId, 15)
end

function mod:ThingDeath(args)
	self:StopBar(207720) -- Witness the Void
end
