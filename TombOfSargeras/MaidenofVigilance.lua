
-- GLOBALS: tContains, tDeleteItem

--------------------------------------------------------------------------------
-- TODO List:

--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Maiden of Vigilance", 1147, 1897)
if not mod then return end
mod:RegisterEnableMob(118289) -- Maiden of Vigilance
mod.engageId = 2052
mod.respawnTime = 30

--------------------------------------------------------------------------------
-- Locals
--

local Hud = FS.Hud

local phase = 1
local shieldActive = false
local massInstabilityCounter = 0
local hammerofCreationCounter = 0
local hammerofObliterationCounter = 0
local infusionCounter = 0
local mySide = 0
local lightList, felList = {}, {}

local bossSide = 1
local direction = {
	[1] = {
		fel = 241868, -- Left
		light = 241870 -- Right
	},
	[2] = {
		fel = 241870, -- Right
		light = 241868 -- Left
	}
}

local massInstabilityGrace = 0

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then
	L.infusionChanged = "Infusion CHANGED: %s"
	L.sameInfusion = "Same Infusion: %s"
	L.fel = "Fel"
	L.light = "Light"
	L.felHammer = "Fel Hammer"
	L.lightHammer = "Light Hammer"
end
--------------------------------------------------------------------------------
-- Initialization
--

local tank_marker = mod:AddCustomOption { "tank_marker", "Set markers matching infusion on tank players", default = true }
local infusion_only_swap = mod:AddCustomOption { "infusion_only_swap", "Only display Infusion Pulse icon when not matching your current side", default = true }
local infusion_icons_pulse = mod:AddCustomOption { "infusion_icons_pulse", "Use Infusion icons instead of arrows for Pulse", default = false }
local infusion_grace_countdown = mod:AddCustomOption { "infusion_grace_countdown", "Play Countdown sound until grace period after infusion is over", default = false }
function mod:GetOptions()
	return {
		"berserk",
		{235117, "COUNTDOWN", "FLASH", "HUD"}, -- Unstable Soul
		--241593, -- Aegwynn's Ward
		{235271, "PROXIMITY", "FLASH", "PULSE", "SAY"}, -- Infusion
		tank_marker,
		infusion_only_swap,
		infusion_icons_pulse,
		infusion_grace_countdown,
		241635, -- Hammer of Creation
		238028, -- Light Remanence
		241636, -- Hammer of Obliteration
		238408, -- Fel Remanence
		235267, -- Mass Instability
		248812, -- Blowback
		{235028, "HUD"}, -- Titanic Bulwark
		234891, -- Wrath of the Creators
		239153, -- Spontaneous Fragmentation
	},{
		["berserk"] = "general",
		[235271] = -14974, -- Stage One: Divide and Conquer
		[248812] = -14975, -- Stage Two: Watcher's Wrath
		[239153] = "mythic",
	}
end

function mod:OnBossEnable()
	-- General
	self:Log("SPELL_AURA_APPLIED", "UnstableSoul", 235117) -- Unstable Soul
	self:Log("SPELL_AURA_REMOVED", "UnstableSoulRemoved", 235117) -- Unstable Soul
	--self:Log("SPELL_AURA_APPLIED", "AegwynnsWardApplied", 241593, 236420) -- Aegwynn's Ward, Heroic, Normal
	self:Log("SPELL_AURA_APPLIED", "GroundEffectDamage", 238028, 238408) -- Light Remanence, Fel Remanence
	self:Log("SPELL_PERIODIC_DAMAGE", "GroundEffectDamage", 238028, 238408)
	self:Log("SPELL_PERIODIC_MISSED", "GroundEffectDamage", 238028, 238408)

	-- Stage One: Divide and Conquer
	self:Log("SPELL_CAST_START", "Infusion", 235271) -- Infusion
	self:Log("SPELL_AURA_APPLIED", "FelInfusion", 235240, 240219) -- Heroic, Normal
	self:Log("SPELL_AURA_APPLIED", "LightInfusion", 235213, 240218) -- Heroic, Normal
	self:Log("SPELL_CAST_START", "HammerofCreation", 241635) -- Hammer of Creation
	self:Log("SPELL_CAST_START", "HammerofObliteration", 241636) -- Hammer of Obliteration
	self:Log("SPELL_CAST_START", "MassInstability", 235267) -- Mass Instability

	-- Stage Two: Watcher's Wrath
	self:Log("SPELL_CAST_SUCCESS", "Blowback", 248812) -- Blowback
	self:Log("SPELL_AURA_APPLIED", "TitanicBulwarkApplied", 235028) -- Titanic Bulwark
	self:Log("SPELL_AURA_REMOVED", "TitanicBulwarkRemoved", 235028) -- Titanic Bulwark
	self:Log("SPELL_CAST_SUCCESS", "WrathoftheCreators", 234891) -- Wrath of the Creators
	self:Log("SPELL_AURA_APPLIED", "WrathoftheCreatorsApplied", 237339) -- Wrath of the Creators
	self:Log("SPELL_AURA_APPLIED_DOSE", "WrathoftheCreatorsApplied", 237339) -- Wrath of the Creators
	self:Log("SPELL_AURA_REMOVED", "WrathoftheCreatorsInterrupted", 234891) -- Wrath of the Creators

	-- Mythic
	self:Log("SPELL_CAST_SUCCESS", "SpontaneousFragmentation", 239153) -- Hammer of Creation
end

function mod:OnEngage()
	phase = 1
	shieldActive = false
	mySide = 0
	bossSide = 1
	wipe(lightList)
	wipe(felList)

	massInstabilityCounter = 0
	hammerofCreationCounter = 0
	hammerofObliterationCounter = 0
	infusionCounter = 0

	self:Bar(235271, 2.0) -- Infusion
	self:Bar(241635, 14.0, L.lightHammer) -- Hammer of Creation
	self:Bar(235267, 22.0) -- Mass Instability
	self:Bar(241636, 32.0, L.felHammer) -- Hammer of Obliteration
	self:Bar(248812, 42.5) -- Blowback
	self:Bar(234891, 43.5) -- Wrath of the Creators
	self:Berserk(480) -- Confirmed Heroic
end

function mod:OnBossDisable()
	if self:GetOption(tank_marker) then
		for unit in self:IterateGroup() do
			local icon = GetRaidTargetIndex(unit)
			if icon and self:Tank(unit) and (icon == 1 or icon == 4) then
				SetRaidTarget(unit, 0)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:UnstableSoul(args)
	if self:Me(args.destGUID) then
		self:TargetMessage(args.spellId, args.destName, "Personal", "Alarm")
		self:Flash(args.spellId)

		local _, _, _, _, _, _, expires = UnitDebuff(args.destName, args.spellName)
		local remaining = expires - GetTime() - 2
		self:TargetBar(args.spellId, remaining, args.destName)

		if self:Hud(args.spellId) then
			local timer = Hud:DrawTimer("player", 50, remaining):SetColor(1, 0.5, 0):Register("UnstableSoulHUD")
			local label = Hud:DrawText("player", ""):SetFont(26, "Fira Mono Medium"):Register("UnstableSoulHUD")
			local done = false

			function timer:OnUpdate()
				if not done then
					local left = timer:TimeLeft()
					label:SetText(("%2.1f"):format(left))
				end
			end

			function timer:OnDone()
				if not done then
					done = true
					mod:PlaySound(false, "Info")
					timer:SetColor(0, 1, 0)
					label:SetText("JUMP!")
				end
			end
		end

		if self:MobId(args.sourceGUID) == 118289 and GetTime() > massInstabilityGrace then
			local fel = self:SpellName(235240)
			local light = self:SpellName(235213)
			local amFel = UnitDebuff("player", fel)
			local amLight = UnitDebuff("player", light)
			for unit in mod:IterateGroup() do
				-- Range should be 3 yd, but cannot check less than 5 yd
				if not UnitIsUnit(unit, "player") and not UnitIsDead(unit) and mod:Range(unit) <= 5 then
					if amFel and UnitDebuff(unit, light) then
						self:Say(false, "I ({rt4}) may have walked over " .. UnitName(unit) .. " ({rt1}", true, "RAID")
					elseif amLight and UnitDebuff(unit, fel) then
						self:Say(false, "I ({rt1}) may have walked over " .. UnitName(unit) .. " ({rt4}", true, "RAID")
					end
				end
			end
		end
	end
end

function mod:UnstableSoulRemoved(args)
	if self:Me(args.destGUID) then
		self:StopBar(args.spellId, args.destName)
		Hud:RemoveObject("UnstableSoulHUD")
	end
end

function mod:AegwynnsWardApplied(args)
	if self:Me(args.destGUID) then
		self:Message(args.spellId, "Neutral", "Info")
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

function mod:Infusion(args)
	self:Message(args.spellId, "Neutral", nil, CL.casting:format(args.spellName))
	infusionCounter = infusionCounter + 1
	if infusionCounter == 2 then
		self:Bar(args.spellId, 38.0)
	end
end

do
	local function checkSide(self, newSide, key)
		local sideString = (newSide == 235240 or newSide == 240219) and L.fel or L.light
		if mySide ~= newSide then
			self:Message(235271, "Important", "Warning", L.infusionChanged:format(sideString), newSide)
			self:Flash(235271, self:GetOption(infusion_icons_pulse) and newSide or direction[bossSide][key])
			if mySide ~= 0 then
				self:Say(235271, (key == "light") and "{rt1}" or "{rt4}", true)
			end
			if self:GetOption(infusion_grace_countdown) then
				self:PlayInfusionCountdown()
			end
		else
			self:Message(235271, "Important", "Info", L.sameInfusion:format(sideString), newSide)
		end
		mySide = newSide
	end

	function mod:FelInfusion(args)
		if not tContains(felList, args.destName) then
			felList[#felList+1] = args.destName
		end
		tDeleteItem(lightList, args.destName)
		if self:Me(args.destGUID) then
			self:OpenProximity(235271, 5, lightList) -- Avoid people with Light debuff
			checkSide(self, args.spellId, "fel")
		end
		if self:GetOption(tank_marker) and self:Tank(args.destName) then
			SetRaidTarget(args.destName, 4)
		end
	end

	function mod:LightInfusion(args)
		if not tContains(lightList, args.destName) then
			lightList[#lightList+1] = args.destName
		end
		tDeleteItem(felList, args.destName)
		if self:Me(args.destGUID) then
			self:OpenProximity(235271, 5, felList) -- Avoid people with Fel debuff
			checkSide(self, args.spellId, "light")
		end
		if self:GetOption(tank_marker) and self:Tank(args.destName) then
			SetRaidTarget(args.destName, 1)
		end
	end

	function mod:PlayInfusionCountdown()
		self:SendMessage("BigWigs_PlayCountdownNumber", nil, 5)
		for i = 4, 1, -1 do
			self:ScheduleTimer("SendMessage", 5 - i, "BigWigs_PlayCountdownNumber", nil, i)
		end
	end
end

function mod:HammerofCreation(args)
	self:Message(args.spellId, "Urgent", "Alert", L.lightHammer)
	hammerofCreationCounter = hammerofCreationCounter + 1
	if hammerofCreationCounter == 2 then
		self:Bar(args.spellId, 36, L.lightHammer)
	end
end

function mod:HammerofObliteration(args)
	self:Message(args.spellId, "Urgent", "Alert", L.felHammer)
	hammerofObliterationCounter = hammerofObliterationCounter + 1
	if hammerofObliterationCounter == 2 then
		self:Bar(args.spellId, 36, L.felHammer)
	end
end

function mod:MassInstability(args)
	self:Message(args.spellId, "Attention", "Alert")
	massInstabilityCounter = massInstabilityCounter + 1
	massInstabilityGrace = GetTime() + 5
	if massInstabilityCounter == 2 then
		self:Bar(args.spellId, 36)
	end
end

function mod:Blowback(args)
	phase = 2
	self:Message(args.spellId, "Important", "Warning")
end

function mod:TitanicBulwarkApplied(args)
	shieldActive = true
	bossSide = (bossSide == 1) and 2 or 1
	if self:Hud(args.spellId) then
		local cast = Hud:DrawClock(args.destGUID, 80, 50):Register(args.destKey, true):SetOffset(0, -100)
		local shield = Hud:DrawSpinner(args.destGUID, 80):Register(args.destKey):SetOffset(0, -100)

		local unit = args.destUnit
		local spellName = args.spellName
		local shieldMax = false
		function shield:Progress()
			local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, absorb, _, _ = UnitBuff(unit, spellName)
			if not absorb then return 0 end
			if not shieldMax then shieldMax = absorb end
			return (shieldMax - absorb) / shieldMax
		end

		function cast:OnRemove()
			shield:SetColor(1, 0, 0)
		end
	end
end

function mod:TitanicBulwarkRemoved(args)
	shieldActive = false
	self:Message(args.spellId, "Positive", "Info", CL.removed:format(args.spellName))
	Hud:RemoveObject(args.destKey)
end

function mod:WrathoftheCreators(args)
	self:Message(args.spellId, "Attention", "Alert", CL.casting:format(args.spellName))
end

function mod:WrathoftheCreatorsApplied(args)
	if self:Interrupter(args.sourceGUID) and not shieldActive then
		self:Message(234891, "Important", "Warning", args.spellName)
	end
end

function mod:WrathoftheCreatorsInterrupted(args)
	phase = 1
	self:Message(args.spellId, "Positive", "Long", CL.interrupted:format(args.spellName))
	massInstabilityCounter = 1
	hammerofCreationCounter = 1
	hammerofObliterationCounter = 1
	infusionCounter = 1

	self:Bar(235271, 2) -- Infusion
	self:Bar(241635, 14, L.lightHammer) -- Hammer of Creation
	self:Bar(235267, 22) -- Mass Instability
	self:Bar(241636, 32, L.felHammer) -- Hammer of Obliteration
	self:Bar(248812, 81) -- Blowback
	self:Bar(234891, 83.5) -- Wrath of the Creators
end

function mod:SpontaneousFragmentation(args)
	self:Message(args.spellId, "Important", "Alarm")
end
