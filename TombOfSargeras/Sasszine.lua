
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

local nextDreadSharkSoon = 87
local sharkVerySoon = false

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

local hydraShotMarker = mod:AddMarkerOption(true, "player", 1, 230139, 1, 2, 3, 4)
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

		self:StopBar(CL.count:format(self:SpellName(230139), hydraShotCounter)) -- Hydra Shot
		self:StopBar(CL.count:format(self:SpellName(230201), burdenCounter)) -- Burden of Pain

		consumingHungerCounter = 1
		slicingTornadoCounter = 1
		waveCounter = 1
		burdenCounter = 1

		self:Message("stages", "Neutral", "Long", CL.stage:format(phase), false)

		if phase == 2 then
			self:StopBar(232722) -- Slicing Tornado
			self:StopBar(230358) -- Thundering Shock
			self:StopBar(230384) -- Consuming Hunger

			self:Bar(232913, 11) -- Befouling Ink
			if not self:LFR() then
				self:Bar(230139, 15.9, CL.count:format(self:SpellName(230139), hydraShotCounter)) -- Hydra Shot
			end
			self:Bar(230201, 25.6, CL.count:format(self:SpellName(230201), burdenCounter)) -- Burden of Pain
			self:Bar(232827, 32.5) -- Crashing Wave
			self:Bar(234621, 41.7) -- Devouring Maw
		elseif phase == 3 then
			self:StopBar(232913) -- Befouling Ink
			self:StopBar(232827) -- Crashing Wave
			self:StopBar(234621) -- Devouring Maw

			self:CDBar(232913, 11) -- Befouling Ink
			self:Bar(230201, 25.6, CL.count:format(self:SpellName(230201), burdenCounter)) -- Burden of Pain
			self:Bar(232827, 32.5) -- Crashing Wave
			if not self:LFR() then
				self:Bar(230139, 31.6, CL.count:format(self:SpellName(230139), hydraShotCounter)) -- Hydra Shot
			end

			self:Bar(230384, 40.1) -- Consuming Hunger
			self:Bar(232722, 57.2) -- Slicing Tornado
		end
	end
end

function mod:UNIT_HEALTH_FREQUENT(unit)
	local hp = UnitHealth(unit) / UnitHealthMax(unit) * 100
	if hp < nextDreadSharkSoon then
		self:Message(239436, "Neutral", "Info", CL.soon:format(self:SpellName(239436)), false)
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
	function mod:HydraShot(args)
		list[#list+1] = args.destName

		-- Don't forget to add the SAY flag to HS if bringing this back
		--[[
		if self:Me(args.destGUID)then
			self:Say(args.spellId, not self:Easy() and CL.count_rticon:format(args.spellName, #list, #list))
		end]]

		if #list == 1 then
			self:ScheduleTimer("TargetMessage", 0.3, args.spellId, list, "Important", "Warning", nil, nil, true)
			self:CastBar(args.spellId, 6, CL.count:format(args.spellName, hydraShotCounter))
			hydraShotCounter = hydraShotCounter + 1
			self:Bar(args.spellId, phase == 2 and 30 or 40, CL.count:format(args.spellName, hydraShotCounter))
		end
		if self:Me(args.destGUID) then
			self:Flash(args.spellId, #list)
		end
		if self:GetOption(hydraShotMarker) then -- Targets: LFR: 0, 1 Normal, 3 Heroic, 4 Mythic
			SetRaidTarget(args.destName, #list)
		end
	end

	function mod:HydraShotRemoved(args)
		if self:GetOption(hydraShotMarker) then
			SetRaidTarget(args.destName, 0)
		end
	end
end

function mod:BurdenofPainCast(args)
	self:Message(args.spellId, "Attention", "Warning", CL.casting:format(args.spellName))
	burdenCounter = burdenCounter + 1
	self:Bar(args.spellId, phase == 1 and (burdenCounter == 4 and 31.5) or phase == 2 and (burdenCounter == 2 and 30.4 or burdenCounter == 3 and 29.2) or 28, CL.count:format(args.spellName, burdenCounter))
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
	self:Bar(230384, phase == 3 and (consumingHungerCounter == 2 and 47 or 42) or (consumingHungerCounter == 4 and 31.6) or 34) -- XXX Need more p3 data.
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
	self:CDBar(232913, phase == 3 and 32 or 42.5) -- XXX 32-34 in P3
end

function mod:CrashingWave(args)
	waveCounter = waveCounter + 1
	self:Message(args.spellId, "Important", "Warning")
	self:CastBar(args.spellId, self:Mythic() and 4 or 5)
	self:Bar(args.spellId, phase == 3 and (waveCounter == 3 and 49) or 42.5) -- XXX need more data in p3
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
