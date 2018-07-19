
-- GLOBALS: tContains, tDeleteItem

--------------------------------------------------------------------------------
-- TODO List:
-- Orbs alternate colour, maybe something like Krosus Assist?

--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Maiden of Vigilance", 1676, 1897)
if not mod then return end
mod:RegisterEnableMob(118289) -- Maiden of Vigilance
mod.engageId = 2052
mod.respawnTime = 30

--------------------------------------------------------------------------------
-- Locals
--

local Hud = Oken.Hud

local bossActive = false
local shieldActive = false
local massInstabilityCounter = 0
local hammerofCreationCounter = 0
local hammerofObliterationCounter = 0
local infusionCounter = 0
local orbCounter = 1
local mySide = 0
local lightList, felList = {}, {}
local initialOrbs = nil
local orbTimers = {8, 8.5, 7.5, 10.5, 11.5, 8.0, 8.0, 10.0}
local wrathStacks = 0

local bossSide = 1
local direction = {
	[1] = {
		fel = 241870, -- Right
		light = 241868 -- Left
	},
	[2] = {
		fel = 241868, -- Left
		light = 241870 -- Right
	},
}

local massInstabilityGrace = 0

local soakerLabel = {
	["1-1"] = "Fel Melee Trou",
	["1-2"] = "Fel Melee Centre",
	["1-3"] = "Fel Melee Mur",
	["2-1"] = "Fel Ranged Mur",
	["2-2"] = "Fel Ranged Centre",
	["2-3"] = "Fel Ranged Trou",
	["3-1"] = "Light Melee Trou",
	["3-2"] = "Light Melee Centre",
	["3-3"] = "Light Melee Mur",
	["4-1"] = "Light Ranged Mur",
	["4-2"] = "Light Ranged Centre",
	["4-3"] = "Light Ranged Trou",
}

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then
	L.infusionChanged = "Infusion CHANGED: %s"
	L.sameInfusion = "Same Infusion: %s"
	L.fel = "Fel"
	L.light = "Light"
	L.felHammer = "Fel Hammer" -- Better name for "Hammer of Obliteration"
	L.lightHammer = "Light Hammer" -- Better name for "Hammer of Creation"
	L.absorb = "Absorb"
	L.absorb_text = "%s (|cff%s%.0f%%|r)"
	L.cast = "Cast"
	L.cast_text = "%.1fs (|cff%s%.0f%%|r)"
	L.stacks = "Stacks"
end
--------------------------------------------------------------------------------
-- Initialization
--

local tank_marker = mod:AddCustomOption { "tank_marker", "Set markers matching infusion on tank players", default = true }
local infusion_only_swap = mod:AddCustomOption { "infusion_only_swap", "Only display Infusion Pulse icon when not matching your current side", default = true }
local infusion_icons_pulse = mod:AddCustomOption { "infusion_icons_pulse", "Use Infusion icons instead of arrows for Pulse", desc = "This option is always active in Mythic difficulty", default = false }
local infusion_no_mm_pulse = mod:AddCustomOption { "infusion_no_mm_pulse", "Do not show Pulse in Mythic difficulty", default = false }
local infusion_grace_countdown = mod:AddCustomOption { "infusion_grace_countdown", "Play Countdown sound until grace period after infusion is over", default = false }
function mod:GetOptions()
	return {
		"berserk",
		{235117, "COUNTDOWN", "FLASH", "HUD", "SMARTCOLOR"}, -- Unstable Soul
		--241593, -- Aegwynn's Ward
		{235271, "PROXIMITY", "FLASH", "PULSE", "SAY"}, -- Infusion
		tank_marker,
		infusion_only_swap,
		infusion_icons_pulse,
		infusion_no_mm_pulse,
		infusion_grace_countdown,
		241635, -- Hammer of Creation
		238028, -- Light Remanence
		241636, -- Hammer of Obliteration
		238408, -- Fel Remanence
		235267, -- Mass Instability
		248812, -- Blowback
		{235028, "HUD", "INFOBOX"}, -- Titanic Bulwark
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
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1")
	self:Log("SPELL_AURA_APPLIED", "UnstableSoul", 243276, 240209, 235117) -- Mythic, LFR, Normal/Heroic
	self:Log("SPELL_AURA_REFRESH", "UnstableSoul", 243276, 240209, 235117) -- Mythic, LFR, Normal/Heroic
	self:Log("SPELL_AURA_REMOVED", "UnstableSoulRemoved", 243276, 240209, 235117) -- Mythic, LFR, Normal/Heroic
	--self:Log("SPELL_AURA_APPLIED", "AegwynnsWardApplied", 241593, 236420) -- Heroic, Normal/LFR
	self:Log("SPELL_AURA_APPLIED", "GroundEffectDamage", 238028, 238408) -- Light Remanence, Fel Remanence
	self:Log("SPELL_PERIODIC_DAMAGE", "GroundEffectDamage", 238028, 238408)
	self:Log("SPELL_PERIODIC_MISSED", "GroundEffectDamage", 238028, 238408)

	-- Stage One: Divide and Conquer
	self:Log("SPELL_CAST_START", "Infusion", 235271)
	self:Log("SPELL_AURA_APPLIED", "FelInfusion", 235240)
	self:Log("SPELL_AURA_APPLIED", "LightInfusion", 235213)
	self:Log("SPELL_AURA_APPLIED", "InfusionLFR", 240219, 240218) -- Fel Infusion (LFR), Light Infusion (LFR)
	self:Log("SPELL_CAST_START", "HammerofCreation", 241635)
	self:Log("SPELL_CAST_START", "HammerofObliteration", 241636)
	self:Log("SPELL_CAST_START", "MassInstability", 235267)

	-- Stage Two: Watcher's Wrath
	self:Log("SPELL_CAST_SUCCESS", "Blowback", 248812)
	self:Log("SPELL_AURA_APPLIED", "TitanicBulwarkApplied", 235028)
	self:Log("SPELL_AURA_REMOVED", "TitanicBulwarkRemoved", 235028)
	self:Log("SPELL_CAST_SUCCESS", "WrathoftheCreators", 234891)
	self:Log("SPELL_AURA_REMOVED", "WrathoftheCreatorsInterrupted", 234891)
end

function mod:OnEngage()
	bossActive = true
	shieldActive = false
	mySide = 0
	bossSide = 1
	wipe(lightList)
	wipe(felList)

	massInstabilityCounter = 0
	hammerofCreationCounter = 0
	hammerofObliterationCounter = 0
	infusionCounter = 0
	orbCounter = 1
	initialOrbs = true
	wrathStacks = 0

	if not self:LFR() then
		self:Bar(235271, 2) -- Infusion
		self:Bar(241635, 12, L.lightHammer) -- Hammer of Creation
		self:Bar(235267, 22) -- Mass Instability
		self:Bar(241636, 32, L.felHammer) -- Hammer of Obliteration
		self:Bar(248812, 42.5) -- Blowback
		self:Bar(234891, 43.5) -- Wrath of the Creators
	else
		self:Bar(235267, 6) -- Mass Instability
		self:Bar(235271, 41) -- Infusion
		self:Bar(248812, 46) -- Blowback
		self:Bar(234891, 47.5) -- Wrath of the Creators
	end

	if self:Mythic() then
		self:Bar(239153, 8, CL.count:format(self:SpellName(230932), orbCounter))
	end
	if not self:LFR() then
		self:Berserk(480)
	end
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
	self:Emit("MAIDEN_SOAKERS", nil)
	self:Emit("MAIDEN_ROLE", nil, nil)
	bossActive = false
end

function mod:GenMythicSoakers()
	if not bossActive then return end
	if infusionCounter == 2 then return end
	local roster = self:EnumerateGroup { strict = true, alive = true }

	-- Colors name
	local fel = self:SpellName(235240)
	local light = self:SpellName(235213)

	-- Roles
	local tank = function(unit) return self:Tank(unit) end
	local melee = function(unit) return self:Melee(unit, true) end
	local ranged = function(unit) return self:Ranged(unit, true) end
	local healer = function(unit) return self:Healer(unit) end

	-- Ordering
	local ranged_order = { ranged, healer, tank, melee }
	local melee_order = { tank, melee, ranged, healer }

	-- Picker
	local picked = {}
	local function pick(count, color, roles)
		local list = {}
		for _, filter in ipairs(roles) do
			for _, unit in ipairs(roster) do
				if #list == count then return list end
				if not picked[unit] and UnitDebuff(unit, color) and filter(unit) then
					picked[unit] = true
					table.insert(list, unit)
				end
			end
		end
		return list
	end

	-- Soaking melee fel
	local fel_melee = pick(3, fel, melee_order)

	-- Soaking melee light
	local light_melee = pick(3, light, melee_order)

	-- Soaking ranged light on the fel side
	local fel_ranged = pick(3, light, ranged_order)

	-- Soaking ranged fel on the light side
	local light_ranged = pick(3, fel, ranged_order)

	-- Combined soakers list
	local soakers = {
		fel_melee,
		fel_ranged,
		light_melee,
		light_ranged
	}
	self:Emit("MAIDEN_SOAKERS2", soakers)

	-- Player role
	local function selfAttribs()
		for i, group in ipairs(soakers) do
			for j, unit in ipairs(group) do
				if UnitIsUnit("player", unit) then
					local side = (i < 3) and (bossSide == 1 and ">>>" or "<<<") or (bossSide == 1 and "<<<" or ">>>")
					local unusual = (i % 2 == 1 and mod:Ranged()) or (i % 2 == 0 and mod:Melee())
					return (side .. "\n" .. soakerLabel[i .. "-" .. j]),
					       (i < 3 and mod.icons[235240] or mod.icons[235213]),
					       unusual
				end
			end
		end
	end

	local label, icon, unusual = selfAttribs()
	self:Emit("MAIDEN_ROLE2", label, icon, unusual)

	if label then
		self:ShowAura(false, label, { icon = icon, pulse = true })
	else
		self:HideAura(false)
	end
end

function mod:UnitDied(args)
	if not args.mobId then -- Player died
		--self:GenMythicSoakers()
	end
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:UNIT_SPELLCAST_SUCCEEDED(_, _, _, spellId)
	if spellId == 239153 then -- Spontaneous Fragmentation
		self:Message(spellId, "Attention", "Alert", self:SpellName(230932))
		orbCounter = orbCounter + 1
		if orbCounter <= 4 and initialOrbs then
			self:Bar(spellId, 8, CL.count:format(self:SpellName(230932), orbCounter))
		elseif not initialOrbs and orbTimers[orbCounter] then
			self:Bar(spellId, orbTimers[orbCounter], CL.count:format(self:SpellName(230932), orbCounter))
		end
	elseif spellId == 234917 or spellId == 236433 then -- Wrath of the Creators
		-- Blizzard didn't give us SPELL_AURA_APPLIED_DOSE events for the stacks,
		-- so we have to count the casts.
		wrathStacks = wrathStacks + 1
		if (wrathStacks >= 10 and wrathStacks % 5 == 0) or (wrathStacks >= 25) then -- 10,15,20,25,26,27,28,29,30
			self:Message(234891, "Urgent", wrathStacks >= 25 and "Alert", CL.count:format(self:SpellName(spellId), wrathStacks))
		end
	end
end

do
	local prev = 0
	function mod:UnstableSoul(args)
		if self:Me(args.destGUID) then
			local t = GetTime()
			if t-prev > 1.5 then
				prev = t
				self:TargetMessage(235117, args.destName, "Personal", "Alarm")
			end
			-- Duration can be longer if the debuff gets refreshed
			local _, _, _, expires = self:UnitDebuff(args.destName, args.spellName)
			local remaining = expires-GetTime()-1.5
			self:TargetBar(235117, remaining, args.destName)

			if self:Hud(235117) then
				local timer = Hud:DrawTimer("player", 50, remaining):SetColor(1, 0.5, 0):Register("UnstableSoulHUD")
				local label = Hud:DrawText("player", "Wait"):Register("UnstableSoulHUD")
				local done = false

				function timer:OnDone()
					if not done then
						done = true
						mod:PlaySound(false, "Info")
						timer:SetColor(0.2, 1, 0.2)
						label:SetText("JUMP!")
					end
				end
			end
		end
	end
end

function mod:UnstableSoulRemoved(args)
	if self:Me(args.destGUID) then
		self:StopBar(235117, args.destName)
		Hud:RemoveObject("UnstableSoulHUD")
		self:SmartColorUnset(235117)
	end
end

function mod:AegwynnsWardApplied(args)
	if self:Me(args.destGUID) then
		self:Message(241593, "Neutral", "Info")
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
	if self:LFR() then return end
	infusionCounter = infusionCounter + 1
	if infusionCounter == 2 then
		self:Bar(args.spellId, 38.0)
	end
	if self:Mythic() then
		self:ScheduleTimer("GenMythicSoakers", 3.5)
	end
end

do
	local function checkSide(self, newSide, key, spellName)
		local sideString = newSide == 235240 and L.fel or L.light
		if mySide ~= newSide then
			self:Message(235271, "Important", "Warning", mySide == 0 and spellName or L.infusionChanged:format(sideString), newSide)
			if not self:Mythic() or not mod:GetOption(infusion_no_mm_pulse) then
				self:Flash(235271, (self:GetOption(infusion_icons_pulse) or self:Mythic()) and newSide or direction[bossSide][key])
			end
			if mySide ~= 0 then
				self:Say(235271, (key == "light") and "{rt1}" or "{rt4}", true)
			end
			if self:GetOption(infusion_grace_countdown) then
				self:PlayInfusionCountdown()
			end
		else
			self:Message(235271, "Positive", "Info", L.sameInfusion:format(sideString), newSide)
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
			checkSide(self, args.spellId, "fel", args.spellName)
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
			checkSide(self, args.spellId, "light", args.spellName)
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

function mod:InfusionLFR(args)
	if self:Me(args.destGUID) then
		self:Message(235271, "Positive", "Info", args.spellName)
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
	if self:LFR() then
		if massInstabilityCounter < 5 then
			self:Bar(args.spellId, 12)
		end
	else
		if massInstabilityCounter == 2 then
			self:Bar(args.spellId, 36)
		end
	end
end

function mod:Blowback(args)
	self:Message(args.spellId, "Important", "Warning")
	if bossSide == 1 then bossSide = 2 else bossSide = 1 end
end

do
	local timer, castOver, maxAbsorb = nil, 0, 0
	local red, yellow, green = {.6, 0, 0, .6}, {.7, .5, 0}, {0, .5, 0}

	local function updateInfoBox(self, spellId)
		local castTimeLeft = castOver - GetTime()
		local castPercentage = castTimeLeft / 50
		local absorb = UnitGetTotalAbsorbs("boss1")
		local absorbPercentage = absorb / maxAbsorb

		local diff = castPercentage - absorbPercentage
		local hexColor = "ff0000"
		local rgbColor = red
		if diff > 0.1 then -- over 10%
			hexColor = "00ff00"
			rgbColor = green
		elseif diff > 0  then -- below 10%, so it's still close
			hexColor = "ffff00"
			rgbColor = yellow
		end

		self:SetInfoBar(spellId, 1, absorbPercentage, unpack(rgbColor))
		self:SetInfo(spellId, 2, L.absorb_text:format(self:AbbreviateNumber(absorb), hexColor, absorbPercentage * 100))
		self:SetInfoBar(spellId, 3, castPercentage)
		self:SetInfo(spellId, 4, L.cast_text:format(castTimeLeft, hexColor, castPercentage * 100))
		self:SetInfo(spellId, 6, ("%d/30"):format(wrathStacks))
	end

	function mod:TitanicBulwarkApplied(args)
		wrathStacks = 0
		self:ScheduleTimer("HideAura", 20, false)
		if self:CheckOption(args.spellId, "INFOBOX") then
			self:OpenInfo(args.spellId, args.spellName)
			self:SetInfo(args.spellId, 1, L.absorb)
			self:SetInfo(args.spellId, 3, L.cast)
			self:SetInfo(args.spellId, 5, L.stacks)
			castOver = GetTime() + 50 -- Time to 30 stacks
			maxAbsorb = UnitGetTotalAbsorbs("boss1")
			timer = self:ScheduleRepeatingTimer(updateInfoBox, 0.1, self, args.spellId)
		end
	end

	function mod:TitanicBulwarkRemoved(args)
		self:Message(args.spellId, "Positive", "Info", CL.removed:format(args.spellName))

	end

	function mod:WrathoftheCreators(args)
		self:Message(args.spellId, "Attention", "Alert", CL.casting:format(args.spellName))
	end

	function mod:WrathoftheCreatorsInterrupted(args)
		self:Message(args.spellId, "Positive", "Long", CL.interrupted:format(args.spellName))
		massInstabilityCounter = 1
		hammerofCreationCounter = 1
		hammerofObliterationCounter = 1
		infusionCounter = 1
		orbCounter = 1
		initialOrbs = nil
		if timer then
			self:CancelTimer(timer)
			timer = nil
		end
		self:CloseInfo(235028) -- Titanic Bulwark

		if not self:LFR() then
			self:Bar(235271, 2) -- Infusion
			self:Bar(241635, 14, L.lightHammer) -- Hammer of Creation
			self:Bar(235267, 22) -- Mass Instability
			self:Bar(241636, 32, L.felHammer) -- Hammer of Obliteration
			self:Bar(248812, 82.5) -- Blowback
			self:Bar(234891, 83.5) -- Wrath of the Creators
		else
			self:Bar(235267, 8) -- Mass Instability
			self:Bar(248812, 66) -- Blowback
			self:Bar(234891, 68) -- Wrath of the Creators
		end
		if self:Mythic() then
			self:Bar(239153, 8, CL.count:format(self:SpellName(230932), orbCounter))
		end
	end
end
