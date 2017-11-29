--------------------------------------------------------------------------------
-- TODO:
-- -- List which Titan abilities can be used next in the infobox?
-- -- Warnings when not in a safe area during Storm of Darkness

--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("The Coven of Shivarra", nil, 1986, 1712)
if not mod then return end
mod:RegisterEnableMob(122468, 122467, 122469, 125436) -- Noura, Asara, Diima, Thu'raya
mod.engageId = 2073
mod.respawnTime = 15

local Hud = Oken.Hud

local shivanPactCount = 0
local TORMENT_AURA_DURATION = 5

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then
	L.torment_of_the_titans = mod:SpellName(-16138) -- Torment of the Titans
	L.torment_of_the_titans_desc = "The Shivvara will force the titan souls to use their abilities against the players."
	L.torment_of_the_titans_icon = 245910 -- Spectral Army of Norgannon

	L.amanthulEffect = "Adds"
	L.golgannethEffect = "Spread"
	L.kazgorothEffect = "Flames"
	L.norgannonEffect = "Walls"
end

--------------------------------------------------------------------------------
-- Initialization
--

local cosmicGlareMarker = mod:AddMarkerOption(true, "player", 3, 250912, 3,4)
function mod:GetOptions()
	return {
		--[[ General ]]--
		"stages",
		{253203, "AURA"}, -- Shivan Pact
		{"torment_of_the_titans", "AURA"},
		{246763, "HUD"}, -- Fury of Golganneth

		--[[ Noura, Mother of Flame ]]--
		{244899, "TANK"}, -- Fiery Strike
		245627, -- Whirling Saber
		253429, -- Fulminating Pulse

		--[[ Asara, Mother of Night ]]--
		245303, -- Touch of Darkness
		246329, -- Shadow Blades
		252861, -- Storm of Darkness

		--[[ Diima, Mother of Gloom ]]--
		{245518, "TANK_HEALER"}, -- Flashfreeze
		{245586, "SMARTCOLOR"}, -- Chilled Blood
		253650, -- Orb of Frost

		--[[ Thu'raya, Mother of the Cosmos (Mythic) ]]--
		250648, -- Touch of the Cosmos
		{250757, "SAY", "FLASH"}, -- Cosmic Glare
		cosmicGlareMarker,
	},{
		[253203] = "general",
		[244899] = -15967, -- Noura, Mother of Flame
		[245303] = -15968, -- Asara, Mother of Night
		[245518] = -15969, -- Diima, Mother of Gloom
		[250648] = -16398, -- Thu'raya, Mother of the Cosmos
	}
end

function mod:OnBossEnable()
	--[[ General ]]--
	self:RegisterUnitEvent("UNIT_TARGETABLE_CHANGED", nil, "boss1", "boss2", "boss3", "boss4")
	self:Log("SPELL_AURA_APPLIED", "ShivanPact", 253203)
	self:Log("SPELL_AURA_REMOVED", "ShivanPactRemoved", 253203)
	self:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
	self:Log("SPELL_CAST_SUCCESS", "Torments", 250335, 249793, 250333, 250334) -- Aman'Thul, Golganneth, Kaz'goroth, Norgannon

	--[[ Noura, Mother of Flame ]]--
	self:Log("SPELL_AURA_APPLIED", "FieryStrike", 244899)
	self:Log("SPELL_AURA_APPLIED_DOSE", "FieryStrike", 244899)
	self:Log("SPELL_CAST_SUCCESS", "FieryStrikeSuccess", 244899)
	self:Log("SPELL_CAST_START", "WhirlingSaber", 245627)
	self:Log("SPELL_AURA_APPLIED", "FulminatingPulse", 253429)
	self:Log("SPELL_AURA_REMOVED", "FulminatingPulseRemoved", 253429)

	--[[ Asara, Mother of Night ]]--
	self:Log("SPELL_CAST_START", "TouchofDarkness", 245303)
	self:Log("SPELL_CAST_SUCCESS", "ShadowBlades", 246329)
	self:Log("SPELL_CAST_START", "StormofDarkness", 252861)

	--[[ Diima, Mother of Gloom ]]--
	self:Log("SPELL_CAST_SUCCESS", "FlashfreezeSuccess", 245518)
	self:Log("SPELL_AURA_APPLIED", "Flashfreeze", 245518)
	self:Log("SPELL_AURA_APPLIED_DOSE", "Flashfreeze", 245518)
	self:Log("SPELL_AURA_APPLIED", "ChilledBlood", 245586)
	self:Log("SPELL_AURA_REMOVED", "ChilledBloodRemoved", 245586)
	self:Log("SPELL_CAST_START", "OrbofFrost", 253650)

	--[[ Thu'raya, Mother of the Cosmos (Mythic) ]]--
	self:Log("SPELL_CAST_START", "TouchoftheCosmos", 250648)
	self:Log("SPELL_AURA_APPLIED", "CosmicGlare", 250757)
	self:Log("SPELL_AURA_REMOVED", "CosmicGlareRemoved", 250757)

	self:Log("SPELL_AURA_APPLIED", "FuryOfGolganneth", 246763)
	self:Log("SPELL_AURA_REMOVED", "FuryOfGolgannethRemoved", 246763)
end

function mod:OnEngage()
	shivanPactCount = 0

	self:Bar(245627, 8.5) -- Whirling Saber
	self:Bar(244899, 12.1) -- Fiery Strike
	self:Bar(253429, 20.6) -- Fulminating Pulse

	self:Bar(246329, 12.1) -- Shadow Blades
	self:Bar(252861, 27.9) -- Storm of Darkness

	self:CDBar("torment_of_the_titans", 82, L.torment_of_the_titans, L.torment_of_the_titans_icon)
end

--------------------------------------------------------------------------------
-- Event Handlers
--

--[[ General ]]--
function mod:UNIT_TARGETABLE_CHANGED(unit)
	if self:MobId(UnitGUID(unit)) == 122468 then -- Noura
		if UnitCanAttack("player", unit) then
			self:Message("stages", "Positive", "Long", self:SpellName(-15967), false) -- Noura, Mother of Flame
			self:Bar(245627, 8.9) -- Whirling Saber
			self:Bar(244899, 12.5) -- Fiery Strike
			self:Bar(253429, 21.1) -- Fulminating Pulse
		else
			self:StopBar(244899) -- Fiery Strike
			self:StopBar(245627) -- Whirling Saber
			self:StopBar(253429) -- Fulminating Pulse
		end
	elseif self:MobId(UnitGUID(unit)) == 122467 then -- Asara
		if UnitCanAttack("player", unit) then
			self:Message("stages", "Positive", "Long", self:SpellName(-15968), false) -- Asara, Mother of Night
			self:Bar(246329, 12.6) -- Shadow Blades
			self:Bar(252861, 28.4) -- Storm of Darkness
		else
			self:StopBar(246329) -- Shadow Blades
			self:StopBar(252861) -- Storm of Darkness
		end
	elseif self:MobId(UnitGUID(unit)) == 122469 then -- Diima
		if UnitCanAttack("player", unit) then
			self:Message("stages", "Positive", "Long", self:SpellName(-15969), false) -- Diima, Mother of Gloom
			self:Bar(245586, 8) -- Chilled Blood
			self:Bar(245518, 12.2) -- Flashfreeze
			self:Bar(253650, 30) -- Orb of Frost
		else
			self:StopBar(245518) -- Flashfreeze
			self:StopBar(245586) -- Chilled Blood
			self:StopBar(253650) -- Orb of Frost
		end
	elseif self:MobId(UnitGUID(unit)) == 125436 then -- Thu'raya
		if UnitCanAttack("player", unit) then
			self:Message("stages", "Positive", "Long", self:SpellName(-16398), false) -- Thu'raya, Mother of the Cosmos
		end
	end
end

do
	local prev = 0
	function mod:ShivanPact(args)
		local t = GetTime()
		if t-prev > 1.5 then
			prev = t
			self:Message(args.spellId, "Important", "Info")
		end
		if shivanPactCount == 0 then
			self:ShowAura(args.spellId, "Shivan Pact", { pulse = false })
		end
		shivanPactCount = shivanPactCount + 1
	end

	function mod:ShivanPactRemoved(args)
		shivanPactCount = shivanPactCount - 1
		if shivanPactCount == 0 then
			self:HideAura(args.spellId)
		end
	end
end

function mod:CHAT_MSG_RAID_BOSS_EMOTE(_, msg)
	if msg:find("250095", nil, true) then -- Machinations of Aman'thul
		self:Message("torment_of_the_titans", "Important", "Warning", CL.incoming:format(self:SpellName(250095)), 250095) -- Machinations of Aman'thul
		self:CDBar("torment_of_the_titans", 93.5, L.torment_of_the_titans, L.torment_of_the_titans_icon)
		self:ShowAura("torment_of_the_titans", L.amanthulEffect, { icon = self:SpellIcon(250095), autoremove = TORMENT_AURA_DURATION })
	elseif msg:find("245671", nil, true) then -- Flames of Khaz'goroth
		self:Message("torment_of_the_titans", "Important", "Warning", CL.incoming:format(self:SpellName(245671)), 245671) -- Machinations of Aman'thul
		self:CDBar("torment_of_the_titans", 93.5, L.torment_of_the_titans, L.torment_of_the_titans_icon)
		self:ShowAura("torment_of_the_titans", L.kazgorothEffect, { icon = self:SpellIcon(245671), autoremove = TORMENT_AURA_DURATION })
	elseif msg:find("246763", nil, true) then -- Fury of Golganneth
		self:Message("torment_of_the_titans", "Important", "Warning", CL.incoming:format(self:SpellName(246763)), 246763) -- Machinations of Aman'thul
		self:CDBar("torment_of_the_titans", 93.5, L.torment_of_the_titans, L.torment_of_the_titans_icon)
		self:ShowAura("torment_of_the_titans", L.golgannethEffect, { icon = self:SpellIcon(246763), autoremove = TORMENT_AURA_DURATION })
	elseif msg:find("245910", nil, true) then -- Spectral Army of Norgannon
		self:Message("torment_of_the_titans", "Important", "Warning", CL.incoming:format(self:SpellName(245910)), 245910) -- Machinations of Aman'thul
		self:CDBar("torment_of_the_titans", 93.5, L.torment_of_the_titans, L.torment_of_the_titans_icon)
		self:ShowAura("torment_of_the_titans", L.norgannonEffect, { icon = self:SpellIcon(245910), autoremove = TORMENT_AURA_DURATION })
	end
end

function mod:Torments(args)
	local effect = args.spellId == 250335 and L.amanthulEffect or
		args.spellId == 249793 and L.golgannethEffect or
		args.spellId == 249793 and L.kazgorothEffect or
		args.spellId == 250334 and L.norgannonEffect
	self:Emit("COVEN_NEXT_EFFECT", effect)
end

--[[ Noura, Mother of Flame ]]--
function mod:FieryStrike(args)
	local amount = args.amount or 1
	if self:Me(args.destGUID) or amount > 4 then -- Swap above 4, always display stacks on self
		self:StackMessage(args.spellId, args.destName, amount, "Neutral", "Info")
	end
end

function mod:FieryStrikeSuccess(args)
	self:Bar(args.spellId, 12.2)
end

function mod:WhirlingSaber(args)
	self:Message(args.spellId, "Attention", "Alert", CL.incoming:format(args.spellName))
	self:Bar(args.spellId, 35.4)
end

do
	local playerList = mod:NewTargetList()
	function mod:FulminatingPulse(args)
		if self:Me(args.destGUID) then
			self:Say(args.spellId)
			self:SayCountdown(args.spellId, 10)
		end
		playerList[#playerList+1] = args.destName
		if #playerList == 1 then
			self:ScheduleTimer("TargetMessage", 0.3, args.spellId, playerList, "Important", "Alarm")
			self:Bar(args.spellId, 40.1)
		end
	end

	function mod:FulminatingPulseRemoved(args)
		if self:Me(args.destGUID) then
			self:CancelSayCountdown(args.spellId)
		end
	end
end

--[[ Asara, Mother of Night ]]--
function mod:TouchofDarkness(args)
	self:Message(args.spellId, "Neutral", "Info")
end

function mod:ShadowBlades(args)
	self:Message(args.spellId, "Attention", "Alert")
	self:CDBar(args.spellId, 28)
end

function mod:StormofDarkness(args)
	self:Message(args.spellId, "Important", "Alarm")
	self:Bar(args.spellId, 51)
end

--[[ Diima, Mother of Gloom ]]--
function mod:Flashfreeze(args)
	local amount = args.amount or 1
	if self:Me(args.destGUID) or amount > 4 then -- Swap above 4, always display stacks on self
		self:StackMessage(args.spellId, args.destName, amount, "Neutral", "Info")
	end
end

function mod:FlashfreezeSuccess(args)
	self:Bar(args.spellId, 10.9)
end

do
	local colorUpdater
	local maxAmount = -1
	local lastStatus = -1

	local playerList = mod:NewTargetList()
	function mod:ChilledBlood(args)
		playerList[#playerList+1] = args.destName
		if #playerList == 1 then
			self:ScheduleTimer("TargetMessage", 0.3, args.spellId, playerList, "Positive", "Alarm", nil, nil, self:Healer() and true) -- Always play a sound for healers
			self:Bar(args.spellId, 25.5)
		end
		if self:Me(args.destGUID) then
			lastStatus = -1
			colorUpdater = self:ScheduleRepeatingTimer("CheckShieldStatus", 0.2, args.spellId, args.spellName)
			self:CheckShieldStatus(args.spellId, args.spellName)
		end
	end

	function mod:ChilledBloodRemoved(args)
		if self:Me(args.destGUID) then
			self:CancelTimer(colorUpdater)
			self:SmartColorUnset(args.spellId)
		end
	end

	function mod:CheckShieldStatus(spellId, spellName)
		local amount = select(17, UnitDebuff("player", spellName))
		if not amount then return end
		if lastStatus == -1 then maxAmount = amount end
		local status = math.ceil(10 * amount / maxAmount) / 10
		if status ~= lastStatus then
			lastStatus = status
			local r, g, b = Oken:ColorGradient(status, 0.2, 0.8, 0.2, 0.8, 0.8, 0.2, 1, 0.2, 0.2)
			self:SmartColorSet(spellId, r, g, b)
		end
	end
end

function mod:OrbofFrost(args)
	self:Message(args.spellId, "Attention", "Alert")
	self:Bar(args.spellId, 30.5)
end

--[[ Thu'raya, Mother of the Cosmos (Mythic) ]]--
function mod:TouchoftheCosmos(args)
	if self:Interrupter() then
		self:Message(args.spellId, "Urgent", "Alarm")
	end
end

do
	local playerList = mod:NewTargetList()
	function mod:CosmicGlare(args)
		if self:Me(args.destGUID) then
			self:Flash(args.spellId)
			self:Say(args.spellId)
			self:SayCountdown(args.spellId, 4)
		end

		playerList[#playerList+1] = args.destName

		if #playerList == 1 then
			self:Bar(args.spellId, 25.6)
			self:ScheduleTimer("TargetMessage", 0.3, args.spellId, playerList, "Attention", "Alarm")
			if self:GetOption(cosmicGlareMarker) then
				SetRaidTarget(args.destName, 3)
			end
		elseif self:GetOption(cosmicGlareMarker) then
			SetRaidTarget(args.destName, 4)
		end
	end
end

function mod:CosmicGlareRemoved(args)
	if self:Me(args.destGUID) then
		self:CancelSayCountdown(args.spellId)
	end
	if self:GetOption(cosmicGlareMarker) then
		SetRaidTarget(args.destName, 0)
	end
end

do
	local rangeCheck
	local rangeObject

	function mod:CheckFuryRange()
		for unit in mod:IterateGroup() do
			if not UnitIsUnit(unit, "player") and not UnitIsDead(unit) and mod:Range(unit) <= 5 then
				rangeObject:SetColor(1, 0.2, 0.2)
				return
			end
		end
		rangeObject:SetColor(0.2, 1, 0.2)
	end

	function mod:FuryOfGolganneth(args)
		if self:Me(args.destGUID) and self:Hud(args.spellId) then
			rangeObject = Hud:DrawSpinner("player", 50)
			rangeCheck = self:ScheduleRepeatingTimer("CheckFuryRange", 0.1)
			self:CheckFuryRange()
		end
	end

	function mod:FuryOfGolgannethRemoved(args)
		if self:Me(args.destGUID) and rangeObject then
			if rangeObject then
				self:CancelTimer(rangeCheck)
				rangeObject:Remove()
				rangeObject = nil
			end
		end
	end
end
