
--------------------------------------------------------------------------------
-- TODO List:
-- - Figure out how timers work - Breath and Charge could be on some shared cd?

--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Guarm-TrialOfValor", 1114, 1830)
if not mod then return end
mod:RegisterEnableMob(114323)
mod.engageId = 1962
mod.respawnTime = 15
mod.instanceId = 1648

--------------------------------------------------------------------------------
-- Locals
--
local breathCounter = 0
local fangCounter = 0
local leapCounter = 0
local breathSoaked = {}

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then
	L.soak_fail = "[FAIL] %s failed to soak Guardian's Breath!"
end

--------------------------------------------------------------------------------
-- Initialization
--

local foams_pulse = mod:AddCustomOption {
	key = "foams",
	title = "Pulse Volatile Foams",
	desc = "Display a Pulse warning when affected by one kind of Volatile Foam"
}

local soak_fails = mod:AddTokenOption { "fails", "Announce Guardian's Breath soaking fails.", promote = false }

function mod:GetOptions()
	return {
		"proximity",
		{228248, "SAY", "FLASH"}, -- Frost Lick
		{228253, "SAY", "FLASH"}, -- Shadow Lick
		{228228, "SAY", "FLASH"}, -- Flame Lick
		{228187, "FLASH"}, -- Guardian's Breath
		227514, -- Flashing Fangs
		227816, -- Headlong Charge
		227883, -- Roaring Leap
		foams_pulse,
		soak_fails,
		"berserk",
	}
end

function mod:OnBossEnable()
	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")

	self:Log("SPELL_AURA_APPLIED", "FrostLick", 228248)
	self:Log("SPELL_AURA_APPLIED", "ShadowLick", 228253)
	self:Log("SPELL_AURA_APPLIED", "FlameLick", 228228)

	self:Log("SPELL_CAST_START", "FlashingFangs", 227514)

	self:Log("SPELL_CAST_SUCCESS", "HeadlongCharge", 227816)

	self:Log("SPELL_CAST_SUCCESS", "RoaringLeap", 227883)

	self:Log("SPELL_DAMAGE", "BreathDamage", 232777, 232798, 232800)
	self:Log("SPELL_MISSED", "BreathDamage", 232777, 232798, 232800)

	-- Flaming, Briney, Shadowy + echoes
	self:Log("SPELL_AURA_APPLIED", "VolatileFoamApplied", 228744, 228810, 228818, 228794, 228811, 228819)

	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1")
end

function mod:OnEngage()
	breathCounter = 0
	fangCounter = 0
	if self:Mythic() then
		self:Berserk(240)
	elseif not self:LFR() then -- Probably longer on LFR
		self:Berserk(300)
	end
	self:Bar(227514, 5) -- Flashing Fangs
	self:Bar(228187, 14.5) -- Guardian's Breath
	self:Bar(227816, 58) -- Headlong Charge
	self:Bar(227883, 48) -- Roaring Leap
	self:SmartProximity()
end

function mod:SmartProximity()
	if self:Ranged() or self:Healer() then
		-- Ranged and healers have range 5 from everyone
		self:OpenProximity("proximity", 5)
	elseif self:Melee() then
		-- Melees have range 5 from everyone except melees
		local nonMelees = {}
		for unit in self:IterateGroup() do
			if not self:Melee(unit) then
				nonMelees[#nonMelees + 1] = unit
			end
		end
		self:OpenProximity("proximity", 5, nonMelees)
	else
		-- Tanks have range 5 except from the other tank
		local nonTank = {}
		for unit in self:IterateGroup() do
			if not self:Tank(unit) then
				nonTank[#nonTank + 1] = unit
			end
		end
		self:OpenProximity("proximity", 5, nonTank)
	end
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:UNIT_SPELLCAST_SUCCEEDED(_, spellName, _, _, spellId)
	if spellId == 228187 then -- Guardian's Breath (starts casting)
		breathCounter = breathCounter + 1
		self:Bar(spellId, (breathCounter % 2 == 0 and 54) or 20.7)
		self:Message(spellId, "Attention", "Warning")
		self:Bar(spellId, 5, CL.cast:format(spellName))
		self:Flash(spellId)
		self:CloseProximity()
		self:ScheduleTimer("SmartProximity", 5)
		self:ScheduleTimer("CheckBreathSoakers", 6)
		wipe(breathSoaked)
	elseif spellId == 228201 then -- Off the leash 30sec
		self:Bar(227514, 34) -- Flashing Fangs
		self:Bar(228187, 41.3) -- Guardian's Breath
		self:CloseProximity()
		self:ScheduleTimer("SmartProximity", 30)
	end
end

do
	local list = mod:NewTargetList()
	function mod:FrostLick(args)
		if self:Me(args.destGUID) then
			self:Flash(args.spellId)
			self:Say(args.spellId)
		end
		list[#list+1] = args.destName
		if #list == 1 then
			self:ScheduleTimer("TargetMessage", 0.4, args.spellId, list, "Urgent", "Alarm")
		end
	end
end

do
	local list = mod:NewTargetList()
	function mod:ShadowLick(args)
		if self:Me(args.destGUID) then
			self:Flash(args.spellId)
			self:Say(args.spellId)
		end
		list[#list+1] = args.destName
		if #list == 1 then
			self:ScheduleTimer("TargetMessage", 0.4, args.spellId, list, "Urgent", "Alarm")
		end
	end
end

do
	local list = mod:NewTargetList()
	function mod:FlameLick(args)
		if self:Me(args.destGUID) then
			self:Flash(args.spellId)
			self:Say(args.spellId)
		end
		list[#list+1] = args.destName
		if #list == 1 then
			self:ScheduleTimer("TargetMessage", 0.4, args.spellId, list, "Urgent", "Alarm")
		end
	end
end

function mod:FlashingFangs(args)
	fangCounter = fangCounter + 1
	self:Message(args.spellId, "Attention", nil, CL.casting:format(args.spellName))
	self:CDBar(args.spellId, (fangCounter % 2 == 0 and 54) or (fangCounter == 1 and 23.1) or 20.7)
end

function mod:HeadlongCharge(args)
	self:Message(args.spellId, "Important", "Long")
	self:Bar(args.spellId, 75.2)
	self:Bar(args.spellId, 7, CL.cast:format(args.spellName))
end

function mod:RoaringLeap(args)
	leapCounter = leapCounter + 1
	self:Message(args.spellId, "Urgent", "Info")
	self:Bar(args.spellId, (leapCounter % 2 == 0 and 53.5) or 21.8)
end

function mod:BreathDamage(args)
	breathSoaked[args.destGUID] = true
end

function mod:CheckBreathSoakers()
	if self:GetOption(soak_fails) then
		for unit in self:IterateGroup() do
			if not breathSoaked[UnitGUID(unit)] then
				SendChatMessage(L.soak_fail:format(UnitName(unit)), "RAID")
			end
		end
	end
end

do
	local foamSoakers = {
		[228744] = "MELEES",
		[228794] = "MELEES",
		[228810] = "TANKS",
		[228811] = "TANKS",
		[228818] = "RANGED",
		[228819] = "RANGED",
	}

	local Shadow, Fire, Frost = 228769, 228758, 228768
	local foamColor = {
		[228744] = Fire,
		[228794] = Fire,
		[228810] = Frost,
		[228811] = Frost,
		[228818] = Shadow,
		[228819] = Shadow,
	}

	local prev = 0
	function mod:VolatileFoamApplied(args)
		if self:Me(args.destGUID) and self:GetOption(foams_pulse) then
			if UnitDebuff("player", self:SpellName(foamColor[args.spellId])) then
				return
			end
			self:Pulse(false, args.spellId)
			self:PlaySound(false, "Warning")
			self:Emphasized(false, "Soak on " .. foamSoakers[args.spellId])
		end
		local t = GetTime()
		if t - prev > 15 then
			prev = t
			self:Message("foams_pulse", "Important", "Long", "Volatile Foam", 228744)	
		end
	end
end
