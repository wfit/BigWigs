
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

--------------------------------------------------------------------------------
-- Locals
--
local breathCounter = 0
local fangCounter = 0
local leapCounter = 0

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then
	L.foam_ok = "[FOAM] %s => OK!"
	L.foam_multiple = "[FOAM] %s => Multiple Foams!"
	L.foam_moveto_melee = "[FOAM] %s => Move to {rt%d} (melee)"
	L.foam_moveto = "[FOAM] %s => Move to {rt%d} %s"
	L.foam_soakby = "[FOAM] %s {rt%d} <= Soaked by %s"
	L.foam_noavail = "[FOAM] %s => No soaker available?"
	L.foam_noicon = "[FOAM] %s => No icon available?"
end

--------------------------------------------------------------------------------
-- Initialization
--

local foams = mod:AddCustomOption {
	key = "foams",
	title = "Pulse Volatile Foams",
	desc = "Display a Pulse warning when affected by one kind of Volatile Foam"
}

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
		foams,
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

	-- Flaming, Briney, Shadowy + echoes
	self:Log("SPELL_AURA_APPLIED", "VolatileFoamApplied", 228744, 228810, 228818, 228794, 228811, 228819)

	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1")
end

function mod:OnEngage()
	breathCounter = 0
	fangCounter = 0
	if not self:LFR() then -- Probably longer on LFR
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

do
	local foamSoakers = {
		[228744] = "MELEES",
		[228794] = "MELEES",
		[228810] = "TANKS",
		[228811] = "TANKS",
		[228818] = "RANGED",
		[228819] = "RANGED",
	}

	function mod:VolatileFoamApplied(args)
		if self:Me(args.destGUID) and self:GetOption(foams) then
			self:Pulse(false, args.spellId)
			self:PlaySound(false, "Warning")
			self:Emphasized(false, "Soak on " .. foamSoakers[args.spellId])
		end
	end
end
