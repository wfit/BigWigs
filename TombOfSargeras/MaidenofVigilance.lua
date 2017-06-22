
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

local side = 1
local color = -1
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

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then

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
		{235117, "FLASH", "HUD"}, -- Unstable Soul
		--241593, -- Aegwynn's Ward
		{235271, "PROXIMITY", "FLASH", "PULSE"}, -- Infusion
		tank_marker,
		infusion_only_swap,
		infusion_icons_pulse,
		infusion_grace_countdown,
		241635, -- Hammer of Creation
		241636, -- Hammer of Obliteration
		235267, -- Mass Instability
		248812, -- Blowback
		235028, -- Titanic Bulwark
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
	--self:Log("SPELL_AURA_APPLIED", "AegwynnsWardApplied", 241593) -- Aegwynn's Ward

	-- Stage One: Divide and Conquer
	self:Log("SPELL_CAST_START", "Infusion", 235271) -- Infusion
	self:Log("SPELL_AURA_APPLIED", "FelInfusion", 235240, 240219) -- Fel Infusion
	self:Log("SPELL_AURA_APPLIED", "LightInfusion", 235213, 240218) -- Light Infusion
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
	side = 1
	color = -1
	shieldActive = false

	massInstabilityCounter = 0
	hammerofCreationCounter = 0
	hammerofObliterationCounter = 0
	infusionCounter = 0

	self:Bar(235271, 2.0) -- Infusion
	self:Bar(241635, 14.0) -- Hammer of Creation
	self:Bar(235267, 22.0) -- Mass Instability
	self:Bar(241636, 32.0) -- Hammer of Obliteration
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
		local spellId = args.spellId
		self:TargetMessage(spellId, args.destName, "Personal", "Alarm")
		self:Flash(spellId)

		if self:Hud(spellId) then
			local _, _, _, _, _, _, expires = UnitDebuff("player", args.spellName)
			local remaining = expires - GetTime()

			local timer = Hud:DrawSpinner("player", 50, remaining - 1.75):SetColor(1, 0.5, 0):Register("UnstableSoulHUD")
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
					mod:PlaySound(spellId, "Info")
					timer:SetColor(0, 1, 0)
					label:SetText("JUMP!")
				end
			end
		end
	end
end

function mod:UnstableSoulRemoved(args)
	if self:Me(args.destGUID) then
		Hud:RemoveObject("UnstableSoulHUD")
	end
end

function mod:AegwynnsWardApplied(args)
	if self:Me(args.destGUID) then
		self:Message(args.spellId, "Neutral", "Info")
	end
end

function mod:Infusion(args)
	self:Message(args.spellId, "Neutral", "Info", CL.casting:format(args.spellName))
	infusionCounter = infusionCounter + 1
	if infusionCounter == 2 then
		self:Bar(args.spellId, 38.0)
	end
end

do
	local lightList, felList = {}, {}

	function mod:FelInfusion(args)
		felList[#felList+1] = args.destName
		tDeleteItem(lightList, args.destName)
		if self:Me(args.destGUID) then
			self:TargetMessage(235271, args.destName, "Personal", "Warning", args.spellName, args.spellId)
			self:OpenProximity(235271, 5, lightList) -- Avoid people with Light debuff
			if color ~= 1 or not self:GetOption(infusion_only_swap) then
				self:Flash(235271, self:GetOption(infusion_icons_pulse) and args.spellId or direction[side].fel) -- Left
				color = 1
			end
			if self:GetOption(infusion_grace_countdown) then
				self:PlayInfusionCountdown()
			end
		end
		if self:GetOption(tank_marker) and self:Tank(args.destName) then
			SetRaidTarget(args.destName, 4)
		end
	end

	function mod:LightInfusion(args)
		lightList[#lightList+1] = args.destName
		tDeleteItem(felList, args.destName)
		if self:Me(args.destGUID) then
			self:TargetMessage(235271, args.destName, "Personal", "Warning", args.spellName, args.spellId)
			self:OpenProximity(235271, 5, felList) -- Avoid people with Fel debuff
			if color ~= 2 or not self:GetOption(infusion_only_swap) then
				self:Flash(235271, self:GetOption(infusion_icons_pulse) and args.spellId or direction[side].light) -- Right
				color = 2
			end
			if self:GetOption(infusion_grace_countdown) then
				self:PlayInfusionCountdown()
			end
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
	self:Message(args.spellId, "Urgent", "Alert")
	hammerofCreationCounter = hammerofCreationCounter + 1
	if hammerofCreationCounter == 2 then
		self:Bar(args.spellId, 36)
	end
end

function mod:HammerofObliteration(args)
	self:Message(args.spellId, "Urgent", "Alert")
	hammerofObliterationCounter = hammerofObliterationCounter + 1
	if hammerofObliterationCounter == 2 then
		self:Bar(args.spellId, 36)
	end
end

function mod:MassInstability(args)
	self:Message(args.spellId, "Attention", "Alert")
	massInstabilityCounter = massInstabilityCounter + 1
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
	side = (side == 1) and 2 or 1
end

function mod:TitanicBulwarkRemoved(args)
	shieldActive = false
	self:Message(args.spellId, "Positive", "Info", CL.removed:format(args.spellName))
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
	self:Bar(241635, 14) -- Hammer of Creation
	self:Bar(235267, 22) -- Mass Instability
	self:Bar(241636, 32) -- Hammer of Obliteration
	self:Bar(248812, 81) -- Blowback
	self:Bar(234891, 83.5) -- Wrath of the Creators
end

function mod:SpontaneousFragmentation(args)
	self:Message(args.spellId, "Important", "Alarm")
end