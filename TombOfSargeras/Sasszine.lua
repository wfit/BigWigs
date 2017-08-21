
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

local stage = 1
local slicingTornadoCounter = 1
local waveCounter = 1
local dreadSharkCounter = 1
local burdenCounter = 1
local crashingWaveStage3Mythic = {32.5, 39, 33, 45, 33}
local hydraShotCounter = 1
local bufferfishCounter = 1
local abs = math.abs

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then
	L.inks_fed_count = "Ink (%d/%d)"
	L.inks_fed = "Inks fed: %s" -- %s = List of players
end

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
		230227, -- From the Abyss // Showing this as an alternative to Burden of Pain for non-tanks, they are the same spell
		230959, -- Concealing Murk
		232722, -- Slicing Tornado
		230358, -- Thundering Shock
		{230384, "ME_ONLY", "FLASH"}, -- Consuming Hunger
		{234621, "INFOBOX"}, -- Devouring Maw
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
	self:Log("SPELL_AURA_APPLIED", "ConsumingHungerApplied", 230384, 234661) -- Stage 1, Stage 3

	-- Stage Two: Terrors of the Deep
	self:Log("SPELL_CAST_SUCCESS", "DevouringMaw", 232745)
	self:Log("SPELL_CAST_START", "BefoulingInk", 232756) -- Summon Ossunet = Befouling Ink incoming
	self:Log("SPELL_CAST_START", "CrashingWave", 232827)
	self:Log("SPELL_AURA_APPLIED", "MawApplied", 232745) -- Buffed on Sarukel
	self:Log("SPELL_AURA_REMOVED", "MawRemoved", 232745)
	self:Log("SPELL_AURA_APPLIED", "InkApplied", 232913)
	self:Log("SPELL_AURA_REMOVED", "InkRemoved", 232913)

	-- Mythic
	self:Log("SPELL_AURA_APPLIED", "DeliciousBufferfish", 239362, 239375)
	self:Log("SPELL_AURA_REMOVED", "DeliciousBufferfishRemoved", 239362, 239375)
end

function mod:OnEngage()
	stage = 1
	slicingTornadoCounter = 1
	waveCounter = 1
	dreadSharkCounter = 1
	burdenCounter = 1
	hydraShotCounter = 1
	bufferfishCounter = 1

	wipe(alreadySuicided)

	self:Bar(230358, 10.5) -- Thundering Shock
	-- Tanks: Burden of Pain
	self:Bar(230201, self:Easy() and 18 or 15.5, CL.count:format(self:SpellName(230201), burdenCounter)) -- Burden of Pain, Timer until cast_start
	-- Non-Tanks: From the Abyss
	if not self:Tank() or self:GetOption(230201) == 0 then
		self:Bar(230227, self:Easy() and 20.5 or 18, CL.count:format(self:SpellName(230227), burdenCounter))
	end
	self:Bar(230384, 20.5) -- Consuming Hunger
	if not self:LFR() then
		self:CDBar(230139, self:Normal() and 27 or 25, CL.count:format(self:SpellName(230139), hydraShotCounter)) -- Hydra Shot
	end
	self:Bar(232722, self:Easy() and 36 or 30.3) -- Slicing Tornado
	if self:Mythic() then
		self:Bar(239362, 13, CL.count:format(self:SpellName(239362), bufferfishCounter)) -- Delicious Bufferfish
	end
	self:Berserk(self:LFR() and 540 or 480)
end

--------------------------------------------------------------------------------
-- Event Handlers
--
function mod:UNIT_SPELLCAST_SUCCEEDED(_, _, _, _, spellId)
	if spellId == 239423 then -- Dread Shark // Stage 2 + Stage 3
		dreadSharkCounter = dreadSharkCounter + 1
		if not self:Mythic() then
			stage = dreadSharkCounter
		else
			bufferfishCounter = bufferfishCounter + 1
			self:Bar(239362, 22.5, CL.count:format(self:SpellName(239362), bufferfishCounter)) -- Delicious Bufferfish
			if dreadSharkCounter == 3 or dreadSharkCounter == 5 then
				self:Message(239436, "Urgent", "Warning")
				stage = stage + 1
			else
				self:Message(239436, "Urgent", "Warning")
				return -- No stage change yet
			end
		end

		self:StopBar(232722) -- Slicing Tornado
		self:StopBar(230358) -- Thundering Shock
		self:StopBar(230384) -- Consuming Hunger
		self:StopBar(232913) -- Befouling Ink
		self:StopBar(232827) -- Crashing Wave
		self:StopBar(234621) -- Devouring Maw
		self:StopBar(CL.count:format(self:SpellName(230139), hydraShotCounter)) -- Hydra Shot
		self:StopBar(CL.count:format(self:SpellName(230201), burdenCounter)) -- Burden of Pain
		self:StopBar(CL.count:format(self:SpellName(230227), burdenCounter)) -- From the Abyss

		slicingTornadoCounter = 1
		waveCounter = 1
		burdenCounter = 1
		hydraShotCounter = 1

		self:Message("stages", "Neutral", "Long", CL.stage:format(stage), false)
		if stage == 2 then
			self:Bar(232913, 11) -- Befouling Ink
			if not self:LFR() then
				self:Bar(230139, self:Normal() and 18.2 or 15.9, CL.count:format(self:SpellName(230139), hydraShotCounter)) -- Hydra Shot
			end
			-- Tanks: Burden of Pain
			self:Bar(230201, self:Easy() and 28 or 25.6, CL.count:format(self:SpellName(230201), burdenCounter)) -- Burden of Pain, Timer until cast_start
			-- Non-Tanks: From the Abyss
			if not self:Tank() or self:GetOption(230201) == 0 then
				self:Bar(230227, self:Easy() and 30.5 or 28, CL.count:format(self:SpellName(230227), burdenCounter))
			end
			self:Bar(232827, self:Easy() and 39.6 or 32.5) -- Crashing Wave
			self:Bar(234621, self:Easy() and 46.5 or 42.2) -- Devouring Maw
		elseif stage == 3 then
			self:CDBar(232913, 11) -- Befouling Ink
			-- Tanks: Burden of Pain
			self:Bar(230201, self:Easy() and 28 or 25.6, CL.count:format(self:SpellName(230201), burdenCounter)) -- Burden of Pain, Timer until cast_start
			-- Non-Tanks: From the Abyss
			if not self:Tank() or self:GetOption(230201) == 0 then
				self:Bar(230227, self:Easy() and 30.5 or 28, CL.count:format(self:SpellName(230227), burdenCounter))
			end
			self:Bar(232827, self:Easy() and 38.5 or 32.5) -- Crashing Wave
			if not self:LFR() then
				self:Bar(230139, self:Normal() and 18.2 or 15.5, CL.count:format(self:SpellName(230139), hydraShotCounter)) -- Hydra Shot
			end

			self:Bar(230384, 40.1) -- Consuming Hunger
			self:Bar(232722, self:Easy() and 51.1 or 57.2) -- Slicing Tornado
		end
	end
end

do
	local list = mod:NewTargetList()
	local hydraShots = {}

	function mod:HydraShot(args)
		local count = #list+1
		list[count] = args.destName

		-- Don't forget to add the SAY flag to HS if bringing this back
		--[[
		if self:Me(args.destGUID)then
			if self:Easy() then
				self:Say(args.spellId)
			else
				self:Say(args.spellId, CL.count_rticon:format(args.spellName, count, count))
				self:SayCountdown(args.spellId, 6, count, 4)
			end
		end]]

		if count == 1 then
			wipe(hydraShots)
			self:StopBar(CL.count:format(self:SpellName(230139), hydraShotCounter)) -- Stop previous one if early
			self:CastBar(args.spellId, 6, CL.count:format(args.spellName, hydraShotCounter))
			self:ScheduleTimer("TargetMessage", 0.3, args.spellId, list, "Important", "Warning", nil, nil, true)
			hydraShotCounter = hydraShotCounter + 1
			-- Normal stage 3 seems to swing between 41-43 or 51-53
			self:CDBar(args.spellId, self:Mythic() and 30.5 or stage == 2 and 30 or (self:Normal() and stage == 3 and 41.3) or 40, CL.count:format(args.spellName, hydraShotCounter))
		end

		hydraShots[count] = args.destUnit

		if not self:Mythic() then
			local icon = (count == 4) and 6 or count
			if self:Me(args.destGUID) then
				self:Flash(args.spellId, icon)
				self:Say(false, "{rt" .. icon .. "}", true, "YELL")
			end
			if self:GetOption(hydraShotMarker)  then -- Targets: LFR: 0, 1 Normal, 3 Heroic, 4 Mythic
				SetRaidTarget(args.destName, icon)
			end
		elseif count == 4 then
			self:GenMythicSoaking(args.spellId)
		end
	end

	function mod:HydraShotRemoved(args)
		if self:GetOption(hydraShotMarker) then
			SetRaidTarget(args.destName, 0)
		end
		if self:Me(args.destGUID) and not self:Easy() then
			self:CancelSayCountdown(args.spellId)
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
			local minCount = math.floor(total / 4)
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
					if #groups[i] < minCount then
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
	self:Message(args.spellId, "Attention", "Warning", CL.casting:format(args.spellName))
end

function mod:BurdenofPain(args)
	burdenCounter = burdenCounter + 1
	-- Tanks: Burden of Pain
	self:TargetMessage(args.spellId, args.destName, "Urgent", "Alarm", nil, nil, true)
	self:Bar(args.spellId, 25.5, CL.count:format(args.spellName, burdenCounter)) -- Timer until cast_start
	if not self:Tank() or self:GetOption(args.spellId) == 0 then -- Non-Tanks: From the Abyss
		self:Message(230227, "Urgent", "Alarm", CL.count:format(self:SpellName(230227), burdenCounter-1))
		self:Bar(230227, 28, CL.count:format(self:SpellName(230227), burdenCounter))
	end
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
		self:CDBar(args.spellId, stage == 3 and 35.3 or 34)
	else
		self:CDBar(args.spellId, stage == 3 and (slicingTornadoCounter % 2 == 0 and 45 or 52) or 45)
	end
end

function mod:ThunderingShock(args)
	self:Message(args.spellId, "Important", "Info")
	self:CDBar(args.spellId, 32.8) -- Can be delayed sometimes by other casts
end

do
	local list = mod:NewTargetList()
	function mod:ConsumingHungerApplied(args)
		list[#list+1] = args.destName
		if #list == 1 then
			self:ScheduleTimer("TargetMessage", 0.3, 230384, list, "Attention", "Alert", nil, nil, true)
		end
		if stage == 1 and self:Me(args.destGUID) then
			self:Flash(230384)
		end
	end
end

function mod:DevouringMaw()
	self:Message(234621, "Important", "Long")
	self:Bar(234621, 42)
end

function mod:BefoulingInk()
	self:Message(232913, "Attention", "Info", CL.incoming:format(self:SpellName(232913))) -- Befouling Ink incoming!
	self:CDBar(232913, stage == 3 and (self:Mythic() and 37 or 32) or 41.5)
end

function mod:CrashingWave(args)
	waveCounter = waveCounter + 1
	self:Message(args.spellId, "Important", "Warning")
	self:CastBar(args.spellId, self:LFR() and 7 or 5)
	local timer = 42
	if self:Mythic() and stage == 3 then
		timer = crashingWaveStage3Mythic[waveCounter] or 32
	elseif stage == 3 and waveCounter == 3 and (self:Heroic() or self:Normal()) then
		timer = 49
	end
	self:Bar(args.spellId, timer)
end

function mod:DeliciousBufferfish(args)
	if self:Me(args.destGUID) then
		self:TargetMessage(239362, args.destName, "Personal", "Positive")
	end
end

function mod:DeliciousBufferfishRemoved(args)
	if self:Me(args.destGUID) then
		self:Message(239362, "Personal", "Info", CL.removed:format(args.spellName))
	end
end

do
	local debuffs, inkName = {}, mod:SpellName(232913)
	local fedTable, fedCount, fedsNeeded = {}, 0, 3

	function mod:MawApplied()
		wipe(debuffs)
		wipe(fedTable)
		fedCount = 0
		fedsNeeded = self:Mythic() and 5 or 3
		self:OpenInfo(234621, L.inks_fed_count:format(fedCount, fedsNeeded))

		for unit in self:IterateGroup() do
			local _, _, _, _, _, _, expires = UnitDebuff(unit, inkName)
			debuffs[self:UnitName(unit)] = expires
		end
	end

	function mod:InkApplied(args)
		local _, _, _, _, _, _, expires = UnitDebuff(args.destName, inkName)
		debuffs[self:UnitName(args.destName)] = expires
	end

	function mod:InkRemoved(args)
		local name = args.destName
		local expires = debuffs[name] -- time when the debuff should expire
		if expires then
			local abs = abs(GetTime()-expires) -- difference between now and when it should've expired
			if abs > 0.1 then -- removed early, probably fed the fish
				fedTable[name] = (fedTable[name] or 0) + 1
				fedCount = fedCount + 1
				self:SetInfoTitle(234621, L.inks_fed_count:format(fedCount, fedsNeeded))
				self:SetInfoByTable(234621, fedTable)
			end
			debuffs[name] = nil
		end
	end

	function mod:MawRemoved(args)
		local list = ""
		local total = 0
		for name, n in pairs(fedTable) do
			if total >= fedsNeeded then
				list = list .. "..., " -- ", " will be cut
				break
			end
			if n > 1 then
				list = list .. CL.count:format(self:ColorName(name), n) .. ", "
			else
				list = list .. self:ColorName(name) .. ", "
			end
			total = total + n
		end
		self:Message(234621, "Positive", "Info", CL.over:format(args.spellName) .. " - " .. L.inks_fed:format(list:sub(0, list:len()-2)))
		self:ScheduleTimer("CloseInfo", 5, 234621) -- delay a bit to make sure the people get enough credit
	end
end
