
--------------------------------------------------------------------------------
-- TODO List:
-- - Timers for heroic+mythic (using normal atm)
-- - Tune which markers are used, depending on Mythic targets

--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Mistress Sassz'ine", 1147, 1861)
if not mod then return end
mod:RegisterEnableMob(115767)
mod.engageId = 2037
mod.respawnTime = 40

--------------------------------------------------------------------------------
-- Locals
--

local phase = 1
local consumingHungerCounter = 1
local slicingTornadoCounter = 1
local waveCounter = 1
local dreadSharkCounter = 1
local burdenCounter = 1
local hydraShotCounter = 1
local shockCounter = 1
local mawCounter = 1
local slicingTimersP3 = {0, 39.0, 34.1, 42.6}
local hungerTimersP3 = {0, 31.7, 41.3, 31.6}
local waveTimersP3 = {0, 39.0, 32.8, 43}

local nextDreadSharkSoon = 87
local sharkVerySoon = false
local alreadySuicided = {}

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

local hydraShotMarker = mod:AddMarkerOption(true, "player", 1, 230139, 1, 2, 3, 6)
function mod:GetOptions()
	return {
		"stages",
		"berserk",
		{230139, "FLASH", "PULSE"}, -- Hydra Shot
		hydraShotMarker,
		{230201, "TANK", "FLASH"}, -- Burden of Pain
		230959, -- Concealing Murk
		232722, -- Slicing Tornado
		230358, -- Thundering Shock
		{230384, "FLASH"}, -- Consuming Hunger
		234621, -- Devouring Maw
		232913, -- Befouling Ink
		232827, -- Crashing Wave
		{239436, "FLASH", "PULSE"}, -- Dread Shark
		239362, -- Delicious Bufferfish
	},{
		["stages"] = "general",
		[232722] = -14591,
		[232746] = -14605,
		[239436] = "mythic",
	}
end

function mod:OnBossEnable()
	-- General
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1", "boss2", "boss3", "boss4", "boss5")
	self:Log("SPELL_AURA_APPLIED", "HydraShot", 230139)
	self:Log("SPELL_AURA_REMOVED", "HydraShotRemoved", 230139)
	self:Log("SPELL_CAST_START", "BurdenofPainCast", 230201)
	self:Log("SPELL_CAST_SUCCESS", "BurdenofPain", 230201)

	self:Log("SPELL_AURA_APPLIED", "GroundEffectDamage", 230959) -- Concealing Murk
	self:Log("SPELL_PERIODIC_DAMAGE", "GroundEffectDamage", 230959)
	self:Log("SPELL_PERIODIC_MISSED", "GroundEffectDamage", 230959)

	-- Stage One: Ten Thousand Fangs
	self:Log("SPELL_CAST_START", "SlicingTornado", 232722)
	self:Log("SPELL_CAST_START", "ThunderingShock", 230358)
	self:Log("SPELL_CAST_START", "ConsumingHunger", 230384, 234661) -- Stage 1 id + Stage 3 id
	self:Log("SPELL_AURA_APPLIED", "ConsumingHungerApplied", 230384, 234661)

	-- Stage Two: Terrors of the Deep
	self:Log("SPELL_CAST_SUCCESS", "DevouringMaw", 232745)
	self:Log("SPELL_CAST_START", "BefoulingInk", 232756) -- Summon Ossunet = Befouling Ink incoming
	self:Log("SPELL_CAST_START", "CrashingWave", 232827)

	-- Mythic
	self:Log("SPELL_AURA_APPLIED", "DeliciousBufferfish", 239362, 239375)
	self:Log("SPELL_AURA_REMOVED", "DeliciousBufferfishRemoved", 239362, 239375)
end

function mod:OnEngage()
	phase = 1
	consumingHungerCounter = 1
	slicingTornadoCounter = 1
	waveCounter = 1
	dreadSharkCounter = 1
	burdenCounter = 1
	hydraShotCounter = 1
	shockCounter = 1
	mawCounter = 1

	wipe(alreadySuicided)

	self:Bar(230358, 10.5) -- Thundering Shock
	self:Bar(230201, 15.5, CL.count:format(self:SpellName(230201), burdenCounter)) -- Burden of Pain
	self:Bar(230384, 20.5) -- Consuming Hunger
	if not self:LFR() then
		self:Bar(230139, 25, CL.count:format(self:SpellName(230139), hydraShotCounter)) -- Hydra Shot
	end
	if self:Mythic() then
		self:Bar(239362, 13) -- Bufferfish
		nextDreadSharkSoon = 87
		self:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", nil, "boss1")
	end
	self:Bar(232722, 30.3) -- Slicing Tornado
	self:Berserk(self:LFR() and 540 or 480)
end

--------------------------------------------------------------------------------
-- Event Handlers
--
function mod:UNIT_SPELLCAST_SUCCEEDED(unit, spellName, _, _, spellId)
	if spellId == 239423 then -- Dread Shark // Stage 2 + Stage 3
		dreadSharkCounter = dreadSharkCounter + 1
		if not self:Mythic() then
			phase = dreadSharkCounter
		elseif dreadSharkCounter == 3 or dreadSharkCounter == 5 then
			self:Bar(239362, 22) -- Bufferfish
			self:Message(239436, "Urgent", "Warning")
			sharkVerySoon = false
			phase = phase+1
		else
			self:Bar(239362, 22) -- Bufferfish
			self:Message(239436, "Urgent", "Warning")
			sharkVerySoon = false
			return -- No phase change yet
		end

		self:StopBar(232722) -- Slicing Tornado
		self:StopBar(230358) -- Thundering Shock
		self:StopBar(230384) -- Consuming Hunger
		self:StopBar(232913) -- Befouling Ink
		self:StopBar(234621) -- Devouring Maw
		self:StopBar(CL.count:format(self:SpellName(230139), hydraShotCounter)) -- Hydra Shot
		self:StopBar(CL.count:format(self:SpellName(230201), burdenCounter)) -- Burden of Pain
		self:StopBar(CL.count:format(self:SpellName(232827), waveCounter)) -- Crashing Wave

		consumingHungerCounter = 1
		slicingTornadoCounter = 1
		waveCounter = 1
		hydraShotCounter = 1
		burdenCounter = 1

		self:Message("stages", "Neutral", "Long", CL.stage:format(phase), false)

		if phase == 2 then
			self:Bar(232913, 11) -- Befouling Ink
			if not self:LFR() then
				self:Bar(230139, 15.9, CL.count:format(self:SpellName(230139), hydraShotCounter)) -- Hydra Shot
			end
			self:Bar(230201, 25.6, CL.count:format(self:SpellName(230201), burdenCounter)) -- Burden of Pain
			self:Bar(232827, 32.5, CL.count:format(self:SpellName(232827), waveCounter)) -- Crashing Wave
			self:Bar(234621, 41.7) -- Devouring Maw
		elseif phase == 3 then

			self:CDBar(232913, 11) -- Befouling Ink
			self:Bar(230201, 25.6, CL.count:format(self:SpellName(230201), burdenCounter)) -- Burden of Pain
			self:Bar(232827, 32.5, CL.count:format(self:SpellName(232827), waveCounter)) -- Crashing Wave
			if not self:LFR() then
				self:Bar(230139, self:Mythic() and 15.8 or 31.6, CL.count:format(self:SpellName(230139), hydraShotCounter)) -- Hydra Shot
			end

			self:Bar(230384, self:Mythic() and 45 or 40.1) -- Consuming Hunger
			self:Bar(232722, self:Mythic() and 52.3 or 57.2) -- Slicing Tornado
		end
	end
end

function mod:UNIT_HEALTH_FREQUENT(unit)
	local hp = UnitHealth(unit) / UnitHealthMax(unit) * 100
	if hp < nextDreadSharkSoon then
		self:Message(239436, "Neutral", "Beware", CL.soon:format(self:SpellName(239436)), false)
		if UnitDebuff("player", self:SpellName(239362)) then
			self:Flash(239436)
		end
		sharkVerySoon = true
		nextDreadSharkSoon = nextDreadSharkSoon - 15
		if nextDreadSharkSoon < 0 then
			self:UnregisterUnitEvent("UNIT_HEALTH_FREQUENT", unit)
		end
	end
end

do
	local list = mod:NewTargetList()
	local hydraShots = {}

	function mod:HydraShot(args)
		list[#list+1] = args.destName

		-- Don't forget to add the SAY flag to HS if bringing this back
		--[[
		if self:Me(args.destGUID)then
			self:Say(args.spellId, not self:Easy() and CL.count_rticon:format(args.spellName, #list, #list))
		end]]

		if #list == 1 then
			wipe(hydraShots)
			self:StopBar(CL.count:format(args.spellName, hydraShotCounter))
			self:ScheduleTimer("TargetMessage", 0.3, args.spellId, list, "Important", "Warning", nil, nil, true)
			self:CastBar(args.spellId, 6, CL.count:format(args.spellName, hydraShotCounter))
			hydraShotCounter = hydraShotCounter + 1
			self:Bar(args.spellId, self:Mythic() and ((phase == 3 and hydraShotCounter <= 4 and 31.5) or 30.5) or phase == 2 and 30 or 40, CL.count:format(args.spellName, hydraShotCounter))
		end

		hydraShots[#list] = args.destUnit

		if not self:Mythic() then
			local icon = (#list == 4) and 6 or #list
			if self:Me(args.destGUID) then
				self:Flash(args.spellId, icon)
				self:Say(false, "{rt" .. icon .. "}", true, "YELL")
			end
			if self:GetOption(hydraShotMarker)  then -- Targets: LFR: 0, 1 Normal, 3 Heroic, 4 Mythic
				SetRaidTarget(args.destName, icon)
			end
		elseif #list == 4 then
			self:GenMythicSoaking(args.spellId)
		end
	end

	function mod:HydraShotRemoved(args)
		if self:GetOption(hydraShotMarker) then
			SetRaidTarget(args.destName, 0)
		end
	end

	function mod:GenMythicSoaking(spellId)
		local icons = { 1, 2, 3, 6 } -- Star, Circle, Diamond, Square
		local targets = {}
		local unavailable = {}
		local groups = {
			[1] = {}, -- Tanks
			[2] = {}, -- Melees
			[3] = {}, -- Healers
			[4] = {}, -- Ranged
		}
		local suicided = { false, false, false, false }

		-- Selects prefered group based on the role of the given unit
		local function unit_prefered_group(unit)
			if self:Tank(unit) then
				return 1
			elseif self:Melee(unit, true) then
				return 2
			elseif self:Healer(unit) then
				return 3
			elseif self:Ranged(unit, true) then
				return 4
			end
		end

		-- Try placing each player in their prefered group.
		-- If a group is not empty at this point, two players from the same
		-- catergory are targets at the same time, delay attribution until a
		-- a later time.
		local delayed = {}
		for _, unit in ipairs(hydraShots) do
			local g = unit_prefered_group(unit)
			if not targets[g] then
				targets[g] = unit
			else
				table.insert(delayed, unit)
			end
		end

		-- Place each delayed unit in the first available group
		for _, unit in ipairs(delayed) do
			for i = 1, 4 do
				if not targets[i] then
					targets[i] = unit
					break
				end
			end
		end

		-- Mark targets unavailable
		for i, unit in ipairs(targets) do
			unavailable[UnitGUID(unit)] = true
		end

		-- Mark fishes as unavailable
		local DeliciousBufferfish = self:SpellName(239362)
		local HydraAcid = self:SpellName(234332)
		local fishes = {}
		local fishesCount = 0
		for unit in self:IterateGroup() do
			if UnitDebuff(unit, HydraAcid) then
				unavailable[UnitGUID(unit)] = true
			else
				local stacks = select(4, UnitDebuff(unit, DeliciousBufferfish))
				if stacks then
					unavailable[UnitGUID(unit)] = true
					fishes[unit] = stacks
					fishesCount = fishesCount + 1
				end
			end
		end

		-- Place available units in prefered groups
		local total = 0
		for unit in self:IterateGroup { strict = true, alive = true } do
			if not unavailable[UnitGUID(unit)] then
				table.insert(groups[unit_prefered_group(unit)], unit)
				total = total + 1
			end
		end

		-- If less than 8 players are available, it is impossible to put at least 2 of them
		-- in each group. If using fish players would allow to reach the 8 soakers, forfeit
		-- fishes and use these players. Prefer players with the less stacks.
		if total < 8 and (total + fishesCount) >= 8 then
			for i = 1, (8 - total) do
				local minStacks, minUnit = 1000, nil
				for unit, stacks in pairs(fishes) do
					if stacks < minStacks then
						minStacks = stacks
						minUnit = unit
					end
				end
				fishes[minUnit] = nil
				table.insert(groups[unit_prefered_group(minUnit)], minUnit)
			end
			total = 8
		end

		-- Impossible to save the 4 players, suicide time!
		--[[if total < 8 then
			local suicide = 4 - math.floor(total / 2)
			local candidates = {}
			local picked = {}

			-- Pick prefered classes
			local preferedClasses = { [2] = true, [8] = true, [12] = true } -- Paladin / Mage / Demon Hunter
			for i, unit in ipairs(targets) do
				local guid = UnitGUID(unit)
				if preferedClasses[select(3, UnitClass(unit))] and not alreadySuicided[guid] then
					table.insert(candidates, unit)
					picked[unit] = true
					alreadySuicided[guid] = true
				end
			end

			-- Pick healers
			for i, unit in ipairs(targets) do
				if not picked[unit] and self:Healer(unit) then
					table.insert(candidates, unit)
					picked[unit] = true
				end
			end

			-- Pick rest
			for i, unit in ipairs(targets) do
				if not picked[unit] then
					table.insert(candidates, unit)
				end
			end

			if suicide <= 2 then
				-- 1 or 2 suicide, empty groups and change icons
				local suicideIcons = { 8, 7 }
				local function suicide_unit(unit, k)
					for i = 1, 4 do
						if targets[i] == unit then
							icons[i] = suicideIcons[k]
							suicided[i] = true
							for u, unit in ipairs(groups[i]) do
								for j = 1, 4 do
									if not suicided[i] then
										table.insert(groups[j], unit)
									end
								end
							end
							wipe(groups[i])
						end
					end
				end
				for i = 1, suicide do
					suicide_unit(candidates[i], i)
				end
			elseif suicide == 3 then
				-- Use 1 and 2 to soak 3

			else
			end
		end]]

		-- Balancing
		if total >= 8 then
			local ok = false
			while not ok do
				ok = true
				local maxCount, maxGroup = -1, -1
				local failedGroup = -1
				for i = 1, 4 do
					local count = #groups[i]
					if count > maxCount then
						maxCount = count
						maxGroup = i
					end
					if #groups[i] < 2 then
						ok = false
						failedGroup = i
					end
				end
				if ok then break end
				table.insert(groups[failedGroup], table.remove(groups[maxGroup]))
			end
		end

		-- Set raid markers
		for i, unit in ipairs(targets) do
			local icon = icons[i]
			SetRaidTarget(unit, icon)
			if self:Me(unit) then
				self:Flash(spellId, icon)
				self:Say(false, "{rt" .. icon .. "}", true, "YELL")
				self:Emit("HYDRA_SHOT_ICON", self:SpellIcon(icon), false)
			end
		end

		-- Assign
		for i = 1, 4 do
			local icon = icons[i]
			for _, unit in ipairs(groups[i]) do
				if self:Me(unit) then
					self:Emit("HYDRA_SHOT_ICON", self:SpellIcon(icon), true)
				end
			end
		end

		-- Report
		self:Emit("HYDRA_SHOT_REPORT", targets, icons, groups, suicided)
	end
end

function mod:BurdenofPainCast(args)
	self:StopBar(CL.count:format(args.spellName, burdenCounter))
	self:Message(args.spellId, "Attention", "Warning", CL.casting:format(args.spellName))
	burdenCounter = burdenCounter + 1
	self:Bar(args.spellId, phase == 1 and (burdenCounter == 4 and 31.5) or phase > 1 and ((burdenCounter == 2 and 30.4) or (burdenCounter == 3 and 29.2)) or 28, CL.count:format(args.spellName, burdenCounter))
	if not UnitDetailedThreatSituation("player", "boss1") then
		self:Emit("BURDEN_CAST_START")
	end
end

function mod:BurdenofPain(args)
	self:TargetMessage(args.spellId, args.destName, "Urgent", "Alarm", nil, nil, true)
	if self:Me(args.destGUID) then
		self:Flash(args.spellId)
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

function mod:SlicingTornado(args)
	slicingTornadoCounter = slicingTornadoCounter + 1
	self:Message(args.spellId, "Important", "Long")
	if self:Mythic() then
		self:Bar(args.spellId, phase == 3 and slicingTimersP3[slicingTornadoCounter] or phase == 1 and (slicingTornadoCounter == 4 and 36.5) or 34) -- -- XXX Need more p3 data.
	else
		self:Bar(args.spellId, phase == 3 and (slicingTornadoCounter % 2 == 0 and 45 or 52) or 45) -- -- XXX Need more p3 data.
	end
end

function mod:ThunderingShock(args)
	self:Message(args.spellId, "Important", "Info")
	shockCounter = shockCounter + 1
	self:Bar(args.spellId, shockCounter == 2 and 36.5 or 32.8) -- was 32.8, not confirmed
end

function mod:ConsumingHunger(args)
	consumingHungerCounter = consumingHungerCounter + 1
	if self:Mythic() then
		self:Bar(230384, phase == 3 and hungerTimersP3[consumingHungerCounter] or (consumingHungerCounter == 4 and 31.6) or 34)
	else
		self:Bar(230384, phase == 3 and (consumingHungerCounter == 2 and 47 or 42) or (consumingHungerCounter == 4 and 31.6) or 34) -- XXX Need more p3 data.
	end
end

do
	local list = mod:NewTargetList()
	function mod:ConsumingHungerApplied(args)
		list[#list+1] = args.destName
		if #list == 1 then
			self:ScheduleTimer("TargetMessage", 0.3, 230384, list, "Attention", "Alert", nil, nil, true)
		end
		if phase == 1 and self:Me(args.destGUID) then
			self:Flash(230384)
		end
	end
end

function mod:DevouringMaw(args)
	self:Message(234621, "Important", "Long")
	mawCounter = mawCounter + 1
	self:Bar(234621, 42)
end

function mod:BefoulingInk(args)
	self:Message(232913, "Attention", "Info", CL.incoming:format(self:SpellName(232913))) -- Befouling Ink incoming!
	self:CDBar(232913, phase == 3 and (self:Mythic() and 25 or 32) or 42.5) -- XXX 32-34 in P3
end

function mod:CrashingWave(args)
	self:StopBar(CL.count:format(args.spellName, waveCounter))
	waveCounter = waveCounter + 1
	self:Message(args.spellId, "Important", "Warning")
	self:CastBar(args.spellId, self:Mythic() and 4 or 5)
	if self:Mythic() then
		self:Bar(args.spellId, phase == 3 and waveTimersP3[waveCounter] or 42.5, CL.count:format(args.spellName, waveCounter))
	else
		self:Bar(args.spellId, phase == 3 and (waveCounter == 3 and 49) or 42.5, CL.count:format(args.spellName, waveCounter)) -- XXX need more data in p3
	end
end

function mod:DeliciousBufferfish(args)
	if self:Me(args.destGUID) then
		if sharkVerySoon then
			self:Flash(239436)
		end
		self:TargetMessage(239362, args.destName, "Personal", "Positive")
	end
end

function mod:DeliciousBufferfishRemoved(args)
	if self:Me(args.destGUID) then
		self:TargetMessage(239362, args.destName, "Personal", "Info", CL.removed:format(args.spellName))
	end
end
