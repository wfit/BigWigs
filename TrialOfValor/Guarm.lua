
--------------------------------------------------------------------------------
-- TODO List:
-- - Lick timers for lfr, normal, hc

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
local foamCount = 1
local phaseStartTime = 0
local lickCount = 1
local lickTimer = {14.1, 22.7, 26.3, 33.7, 43.3, 95.8, 99.4, 106.8, 116.5, 171.9, 175.4, 182.6, 192.6}

local breathSoaked = {}

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then
	L.soak_fail = "[FAIL] %s failed to soak Guardian's Breath!"

	L.lick = "Lick"
	L.lick_desc = "Show bars for the different licks." -- For translators: short names of 228248, 228253, 228228
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
		--[[ General ]]--
		"proximity",
		"berserk",
		{228248, "SAY", "FLASH"}, -- Frost Lick
		{228253, "SAY", "FLASH"}, -- Shadow Lick
		{228228, "SAY", "FLASH"}, -- Flame Lick
		{228187, "FLASH"}, -- Guardian's Breath
		227514, -- Flashing Fangs
		227816, -- Headlong Charge
		227883, -- Roaring Leap
		soak_fails,

		--[[ Mythic ]]--
		"lick", -- Lick
		-14535, -- Volatile Foam
		foams_pulse,
	},{
		["berserk"] = "general",
		["lick"] = "mythic",
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

	self:Log("SPELL_CAST_SUCCESS", "VolatileFoam", 228824)
	self:Log("SPELL_AURA_APPLIED", "VolatileFoamApplied", 228744, 228810, 228818, 228794, 228811, 228819) -- Flaming, Briney, Shadowy + echoes

	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1")
end

function mod:OnEngage()
	breathCounter = 0
	fangCounter = 0
	leapCounter = 0
	foamCount = 1
	phaseStartTime = GetTime()
	self:Berserk(self:Mythic() and 244 or self:LFR() and 420 or 300)
	self:Bar(227514, 6) -- Flashing Fangs
	self:Bar(228187, 14.5) -- Guardian's Breath
	self:Bar(227883, 48.5) -- Roaring Leap
	self:Bar(227816, 57) -- Headlong Charge
	if self:Mythic() then
		self:Bar(-14535, 10.9, CL.count:format(self:SpellName(-14535), foamCount), 228810)
		self:StartLickTimer(1)
	end
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
		-- Upstream BigWigs says: (breathCounter % 2 == 0 and 51) or 20.7
		self:Bar(spellId, (breathCounter % 2 == 0 and 54) or 20.7, CL.count:format(spellName, breathCounter+1))
		self:Message(spellId, "Attention", "Warning")
		self:Bar(spellId, 5, CL.cast:format(spellName))
		self:Flash(spellId)
		self:CloseProximity()
		self:ScheduleTimer("SmartProximity", 5)
		self:ScheduleTimer("CheckBreathSoakers", 6)
		wipe(breathSoaked)
	elseif spellId == 228201 then -- Off the leash 30sec
		if self:Mythic() then
			self:Bar(-14535, 29.1, CL.count:format(self:SpellName(-14535), foamCount), 228810) -- Volatile Foam
		end
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
	-- Upstream BigWigs says: fangCounter == 1 and 23 or fangCounter % 2 == 0 and 52 or 20
	self:CDBar(args.spellId, fangCounter == 1 and 23.1 or fangCounter % 2 == 0 and 54 or 20.7)
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
			if not breathSoaked[UnitGUID(unit)] and not UnitIsDeadOrGhost(unit) then
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


function mod:VolatileFoam(args)
	foamCount = foamCount + 1
	local t = foamCount == 2 and 19.4 or foamCount % 3 == 1 and 17 or foamCount % 3 == 2 and 15 or 42
	self:Bar(-14535, t, CL.count:format(self:SpellName(-14535), foamCount), 228810)
end

function mod:StartLickTimer(count)
	local data = self:Mythic() and lickTimer
	local info = data and data[count]
	if not info then
		-- all out of lick data
		return
	end

	local length = floor(info - (GetTime() - phaseStartTime))

	self:CDBar("lick", length, CL.count:format(L.lick, count), 228253)

	self:ScheduleTimer("StartLickTimer", length, count + 1)
end
