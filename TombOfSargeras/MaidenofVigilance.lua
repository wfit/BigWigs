
-- GLOBALS: tContains, tDeleteItem

--------------------------------------------------------------------------------
-- TODO List:
-- Orbs alternate colour, maybe something like Krosus Assist?

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
local orbCounter = 1
local mySide = 0
local lightList, felList = {}, {}
local initialOrbs = nil
local orbTimers = {8, 8.5, 7.5, 10.5, 11.5, 8.0, 8.0, 10.0}

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

local soakerLabel = {
	["1-1"] = "Fel Melee Extérieur",
	["1-2"] = "Fel Melee Centre",
	["1-3"] = "Fel Melee Intérieur",
	["2-1"] = "Fel Ranged Extérieur",
	["2-2"] = "Fel Ranged Centre",
	["2-3"] = "Fel Ranged Intérieur",
	["3-1"] = "Light Melee Extérieur",
	["3-2"] = "Light Melee Centre",
	["3-3"] = "Light Melee Intérieur",
	["4-1"] = "Light Ranged Extérieur",
	["4-2"] = "Light Ranged Centre",
	["4-3"] = "Light Ranged Intérieur",
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
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1")
	self:Log("SPELL_AURA_APPLIED", "UnstableSoul", 243276, 235117) -- Mythic, Others
	self:Log("SPELL_AURA_REMOVED", "UnstableSoulRemoved", 243276, 235117) -- Mythic, Others
	--self:Log("SPELL_AURA_APPLIED", "AegwynnsWardApplied", 241593, 236420) -- Heroic, Normal
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
	orbCounter = 1
	initialOrbs = true

	self:Bar(235271, 2.0) -- Infusion
	self:Bar(241635, 14.0, L.lightHammer) -- Hammer of Creation
	self:Bar(235267, 22.0) -- Mass Instability
	self:Bar(241636, 32.0, L.felHammer) -- Hammer of Obliteration
	self:Bar(248812, 42.5) -- Blowback
	self:Bar(234891, 43.5) -- Wrath of the Creators
	if self:Mythic() then
		self:Bar(239153, 8, CL.count:format(self:SpellName(230932), orbCounter))
	end
	self:Berserk(self:Easy() and 525 or 480)
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
end

function mod:GenMythicSoakers()
	-- Load players by groups
	local groups = {}
	for i = 1, MAX_RAID_GROUPS do groups[i] = {} end
	for i = 1, GetNumGroupMembers() do
		local unit = "raid" .. i
		local _, _, subgroup, _, _, _, _, _, isDead = GetRaidRosterInfo(i)
		if not isDead then table.insert(groups[subgroup], unit) end
	end

	-- Linearize roster
	local roster = {}
	for _, subgroup in ipairs(groups) do
		for _, unit in ipairs(subgroup) do
			table.insert(roster, unit)
		end
	end

	-- Colors name
	local fel = self:SpellName(235240)
	local light = self:SpellName(235213)

	-- Roles
	local tank = function(unit) return self:Tank(unit) end
	local melee = function(unit) return self:Melee(unit) and self:Damager(unit) end
	local ranged = function(unit) return self:Ranged(unit) and self:Damager(unit) end
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

	-- Soaking ranged light on the fel side
	local fel_ranged = pick(3, light, ranged_order)

	-- Soaking ranged fel on the light side
	local light_ranged = pick(3, fel, ranged_order)

	-- Soaking melee fel
	local fel_melee = pick(3, fel, melee_order)

	-- Soaking melee light
	local light_melee = pick(3, light, melee_order)

	-- Combined soakers list
	local soakers = {
		fel_melee,
		fel_ranged,
		light_melee,
		light_ranged
	}
	self:Emit("MAIDEN_SOAKERS", soakers)

	-- Player role
	local myRole, myIcon
	for i, group in ipairs(soakers) do
		for j, unit in ipairs(group) do
			if UnitIsUnit("player", unit) then
				myRole = i .. "-" .. j
				myIcon = i < 3 and self.icons[235240] or self.icons[235213]
				break
			end
		end
		if myRole then break end
	end
	self:Emit("MAIDEN_ROLE", myRole and soakerLabel[myRole], myIcon)
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:UNIT_SPELLCAST_SUCCEEDED(unit, spellName, _, _, spellId)
	if spellId == 239153 then -- Spontaneous Fragmentation
		self:Message(spellId, "Attention", "Alert", self:SpellName(230932))
		orbCounter = orbCounter + 1
		if orbCounter <= 4 and initialOrbs then
			self:Bar(spellId, 8, CL.count:format(self:SpellName(230932), orbCounter))
		elseif not initialOrbs then
			self:Bar(spellId, orbTimers[orbCounter], CL.count:format(self:SpellName(230932), orbCounter))
		end
	end
end

function mod:UnstableSoul(args)
	if self:Me(args.destGUID) then
		self:TargetMessage(235117, args.destName, "Personal", "Alarm")
		self:Flash(235117)

		local _, _, _, _, _, _, expires = UnitDebuff(args.destName, args.spellName)
		local remaining = expires - GetTime() - 1.5
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

		if self:MobId(args.sourceGUID) == 118289 and GetTime() > massInstabilityGrace then
			local fel = self:SpellName(235240)
			local light = self:SpellName(235213)
			local amFel = UnitDebuff("player", fel)
			local amLight = UnitDebuff("player", light)
			for unit in mod:IterateGroup() do
				-- Range should be 3 yd, but cannot check less than 5 yd
				if not UnitIsUnit(unit, "player") and not UnitIsDead(unit) and mod:Range(unit) <= 5 then
					if amFel and UnitDebuff(unit, light) then
						self:Say(false, "I ({rt4}) may have walked over " .. UnitName(unit) .. " ({rt1})", true, "RAID")
					elseif amLight and UnitDebuff(unit, fel) then
						self:Say(false, "I ({rt1}) may have walked over " .. UnitName(unit) .. " ({rt4})", true, "RAID")
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
	infusionCounter = infusionCounter + 1
	if infusionCounter == 2 then
		self:Bar(args.spellId, 38.0)
	end
	if self:Mythic() then
		self:ScheduleTimer("GenMythicSoakers", 3.5)
	end
end

do
	local function checkSide(self, newSide, key)
		local sideString = (newSide == 235240 or newSide == 240219) and L.fel or L.light
		if mySide ~= newSide then
			self:Message(235271, "Important", "Warning", L.infusionChanged:format(sideString), newSide)
			self:Flash(235271, (self:GetOption(infusion_icons_pulse) or self:Mythic()) and newSide or direction[bossSide][key])
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
		local cast = Hud:DrawClock(args.destGUID, 80, 50):Register(args.destKey, true)
		local shield = Hud:DrawSpinner(args.destGUID, 80):Register(args.destKey)

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
	orbCounter = 1
	initialOrbs = nil

	self:Bar(235271, 2) -- Infusion
	if self:Mythic() then
		self:Bar(239153, 8, CL.count:format(self:SpellName(230932), orbCounter))
	end
	self:Bar(241635, 14, L.lightHammer) -- Hammer of Creation
	self:Bar(235267, 22) -- Mass Instability
	self:Bar(241636, 32, L.felHammer) -- Hammer of Obliteration
	self:Bar(248812, 81) -- Blowback
	self:Bar(234891, 83.5) -- Wrath of the Creators
end
