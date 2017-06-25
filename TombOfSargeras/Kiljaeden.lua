
--------------------------------------------------------------------------------
-- TODO List:
-- Rift Activating Timer
-- Count how many adds died in intermission 2?

--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Kil'jaeden", 1147, 1898)
if not mod then return end
mod:RegisterEnableMob(117269)
mod.engageId = 2051
mod.respawnTime = 30 -- XXX Unconfirmed

--------------------------------------------------------------------------------
-- Locals
--

local Hud = FS.Hud

local phase = 1
local intermissionPhase = nil
local singularityCount = 1
local armageddonCount = 1
local focusedDreadflameCount = 1
local burstingDreadflameCount = 1
local felclawsCount = 1
local flamingOrbCount = 1
local obeliskCount = 1
local focusWarned = {}
local phaseTwoTimersHeroic = {
	-- Rupturing Singularity
	[235059] = {73.5, 26, 55, 44}, -- Incomplete
	-- Armageddon
	[240910] = {50.4, 76, 35, 31}, -- Incomplete
}

local phaseTwoTimers = phaseTwoTimersHeroic

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then
	L.singularityImpact = "Singularity Impact"
	L.obeliskExplosion = "Obelisk Explosion"

	L.darkness = "Darkness" -- Shorter name for Darkness of a Thousand Souls (238999)
	L.reflectionErupting = "Reflection: Erupting" -- Shorter name for Shadow Reflection: Erupting (236710)
	L.reflectionWailing = "Reflection: Wailing" -- Shorter name for Shadow Reflection: Wailing (236378)
	L.reflectionHopeless = "Reflection: Hopeless" -- Shorter name for Shadow Reflection: Hopeless (237590)
end

--------------------------------------------------------------------------------
-- Initialization
--

local zoom_minimap = mod:AddCustomOption { "zoom_minimap", "Zoom minimap during Deceiver's Veil", default = true }
local meteors_impact = mod:AddCustomOption { "meteors_landing", "Armageddon Meteors Impact", default = true,
	configurable = true, icon = 87701, desc = "Countdown until meteors impact during Armageddon" }
function mod:GetOptions()
	return {
		"stages",
		{239932, "TANK"}, -- Felclaws
		235059, -- Rupturing Singularity
		240910, -- Armageddon
		{meteors_impact, "COUNTDOWN", "HUD"},
		{236710, "SAY", "FLASH"}, -- Shadow Reflection: Erupting
		{238430, "SAY", "FLASH"}, -- Bursting Dreadflame
		{238505, "SAY", "ICON", "FLASH"}, -- Focused Dreadflame
		{236378, "SAY", "FLASH"}, -- Shadow Reflection: Wailing
		zoom_minimap,
		{241721, "SAY"}, -- Illidan's Sightless Gaze
		{238999, "HUD"}, -- Darkness of a Thousand Souls
		-15543, -- Demonic Obelisk
		243982, -- Tear Rift
		244856, -- Flaming Orb
		{237590, "SAY", "FLASH"}, -- Shadow Reflection: Hopeless
	},{
		["stages"] = "general",
		[239932] = -14921, -- Stage One: The Betrayer
		[238430] = -15221, -- Intermission: Eternal Flame
		[236378] = -15229, -- Stage Two: Reflected Souls
		[241721] = -15394, -- Intermission: Deceiver's Veil
		[238999] = -15255, -- Stage Three: Darkness of A Thousand Souls
		[237590] = "mythic", -- Mythic
	}
end

function mod:OnBossEnable()
	-- General
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1", "boss2", "boss3", "boss4", "boss5")
	self:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")

	-- Stage One: The Betrayer
	self:Log("SPELL_CAST_START", "Felclaws", 239932)
	self:Log("SPELL_AURA_APPLIED", "FelclawsApplied", 239932)
	self:Log("SPELL_CAST_START", "Armageddon", 240910)

	self:Log("SPELL_AURA_APPLIED", "ShadowReflectionErupting", 236710) -- Shadow Reflection: Erupting

	-- Intermission: Eternal Flame
	self:Log("SPELL_AURA_APPLIED", "NetherGale", 244834) -- Intermission Start
	self:Log("SPELL_CAST_START", "FocusedDreadflame", 238502) -- Focused Dreadflame
	self:Log("SPELL_CAST_SUCCESS", "FocusedDreadflameSuccess", 238502) -- Focused Dreadflame
	self:Log("SPELL_CAST_SUCCESS", "BurstingDreadflame", 238430) -- Bursting Dreadflame
	self:Log("SPELL_AURA_REMOVED", "NetherGaleRemoved", 244834) -- Intermission End

	-- Stage Two: Reflected Souls
	self:Log("SPELL_AURA_APPLIED", "ShadowReflectionWailing", 236378) -- Shadow Reflection: Wailing

	-- Intermission: Deceiver's Veil
	self:Log("SPELL_CAST_START", "DeceiversVeilCast", 241983) -- Deceiver's Veil Cast
	self:Log("SPELL_AURA_APPLIED", "IllidansSightlessGaze", 241721) -- Illidan's Sightless Gaze
	self:Log("SPELL_AURA_REMOVED", "DeceiversVeilRemoved", 241983) -- Deceiver's Veil Over

	-- Stage Three: Darkness of A Thousand Souls
	self:Log("SPELL_CAST_START", "DarknessofaThousandSouls", 238999) -- Darkness of a Thousand Souls
	self:Log("SPELL_CAST_START", "TearRift", 243982) -- Tear Rift

	-- Mythic
	self:Log("SPELL_AURA_APPLIED", "ShadowReflectionHopeless", 237590) -- Shadow Reflection: Hopeless
end

function mod:OnEngage()
	phase = 1
	intermissionPhase = nil
	singularityCount = 1
	focusedDreadflameCount = 1
	burstingDreadflameCount = 1
	armageddonCount = 1
	felclawsCount = 1
	flamingOrbCount = 1
	obeliskCount = 1
	wipe(focusWarned)

	self:Message("stages", "Positive", "Long", self:SpellName(-14921), false) -- Stage One: The Betrayer
	self:Bar(240910, 10, CL.count:format(self:SpellName(240910), armageddonCount)) -- Armageddon
	self:Bar(236710, 20, L.reflectionErupting) -- Shadow Reflection: Erupting
	self:Bar(239932, 25) -- Fel Claws
	self:Bar(235059, 58, CL.count:format(self:SpellName(235059), singularityCount)) -- Rupturing Singularity
end

--------------------------------------------------------------------------------
-- Event Handlers
--
-- General

function mod:CHAT_MSG_RAID_BOSS_EMOTE(_, msg, sender, _, _, target)
	if msg:find("238502") then -- Focused Dreadflame Target
		self:TargetMessage(238505, target, "Attention", "Alarm", nil, nil, true)
		self:TargetBar(238505, 5, target)
		self:PrimaryIcon(238505, target)
		local guid = UnitGUID(target)
		if self:Me(guid) then
			self:Say(238505)
			self:Flash(238505)
			self:ScheduleTimer("Say", 2, 238505, 3, true)
			self:ScheduleTimer("Say", 3, 238505, 2, true)
			self:ScheduleTimer("Say", 4, 238505, 1, true)
		end
	elseif msg:find("235059") then -- Rupturing Singularity
		self:Message(235059, "Urgent", "Warning", CL.count:format(self:SpellName(235059), singularityCount))
		self:Bar(235059, 9.85, CL.count:format(L.singularityImpact, singularityCount))
		singularityCount = singularityCount + 1
		local timer = nil
		if intermissionPhase and singularityCount == 2 then -- Intermission Timers
			 timer = 30
		elseif phase == 1 and not intermissionPhase then -- Phase 1 Cooldown
			 timer = 56
		elseif phase == 2 then -- Phase 2 Timers
			timer = phaseTwoTimers[235059][singularityCount]
		end
		self:Bar(235059, timer, CL.count:format(self:SpellName(235059), singularityCount))
	end
end

function mod:UNIT_SPELLCAST_SUCCEEDED(unit, spellName, _, _, spellId)
	if spellId == 244856 then -- Flaming Orb
		self:Message(spellId, "Attention", "Alert")
		flamingOrbCount = flamingOrbCount + 1
		self:Bar(spellId, flamingOrbCount % 2 == 0 and 30 or 64)
	end
end

-- Stage One: The Betrayer
function mod:Felclaws(args)
	self:Message(args.spellId, "Important", "Alarm", CL.casting:format(args.spellName))
end

function mod:FelclawsApplied(args)
	self:Message(args.spellId, "Important", "Info")
	felclawsCount = felclawsCount + 1
	if phase == 3 and felclawsCount % 4 == 0 then
		self:Bar(args.spellId, 20)
	else
		self:Bar(args.spellId, 24)
	end
	self:TargetBar(args.spellId, 11, args.destName)
end

function mod:Armageddon(args)
	self:Message(args.spellId, "Important", "Warning", CL.count:format(args.spellName, armageddonCount))
	self:Bar(meteors_impact, 9, CL.count:format(self:SpellName(182580), armageddonCount), args.spellId) -- Meteor Impact
	if self:Hud(meteors_impact) then
		local debuff = UnitDebuff("player", self:SpellName(234310))
		local spinner = Hud:DrawSpinner("player", 50, 9)
		if debuff then
			spinner:SetColor(1, 0.5, 0)
		else
			spinner:SetColor(0.5, 1, 0.5)
		end
	end
	armageddonCount = armageddonCount + 1
	local timer = nil
	if intermissionPhase and armageddonCount == 2 then -- Intermission timer
		timer = 29.4
	elseif phase == 1 and not intermissionPhase then -- Phase 1 cooldown
		timer = 64
	elseif phase == 2 then -- Phase 2 timers
		timer = phaseTwoTimers[args.spellId][armageddonCount]
	end
	self:Bar(args.spellId, timer, CL.count:format(args.spellName, armageddonCount))
end

do
	local playerList = mod:NewTargetList()
	function mod:ShadowReflectionErupting(args)
		if self:Me(args.destGUID) then
			local _, _, _, _, _, _, expires = UnitDebuff(args.destName, args.spellName)
			local remaining = expires-GetTime()
			self:Flash(args.spellId)
			self:Say(args.spellId, L.reflectionErupting)
			self:ScheduleTimer("Say", remaining-3, args.spellId, 3, true)
			self:ScheduleTimer("Say", remaining-2, args.spellId, 2, true)
			self:ScheduleTimer("Say", remaining-1, args.spellId, 1, true)
		end
		playerList[#playerList+1] = args.destName
		if #playerList == 1 then
			if phase == 2 then
				self:Bar(args.spellId, 112, L.reflectionErupting)
			end
			self:ScheduleTimer("TargetMessage", 0.1, args.spellId, playerList, "Urgent", "Alert", L.reflectionErupting)
		end
	end
end

-- Intermission: Eternal Flame
function mod:NetherGale(args)
	self:Message("stages", "Positive", "Long", self:SpellName(-15221), false) -- Intermission: Eternal Flame

	self:StopBar(CL.count:format(self:SpellName(240910), armageddonCount)) -- Armageddon
	self:StopBar(L.reflectionErupting) -- Shadow Reflection: Erupting
	self:StopBar(239932) -- Fel Claws

	intermissionPhase = true
	singularityCount = 1
	armageddonCount = 1
	focusedDreadflameCount = 1
	felclawsCount = 1

	-- First Intermission
	self:Bar(240910, 6.1, CL.count:format(self:SpellName(240910), armageddonCount)) -- Armageddon
	self:Bar(238430, 7.7) -- Bursting Dreadflame
	self:Bar(235059, 13.3, CL.count:format(self:SpellName(235059), singularityCount)) -- Rupturing Singularity
	self:Bar(238505, 23.5) -- Focused Dreadflame
	self:Bar("stages", 60.2, args.spellName, args.spellId) -- Intermission Duration
end

function mod:FocusedDreadflame(args)
	focusedDreadflameCount = focusedDreadflameCount + 1
	if phase == 1 and focusedDreadflameCount == 2 then
		self:Bar(238505, 13.4)
	elseif phase == 2 then
		self:Bar(238505, focusedDreadflameCount % 2 == 0 and 46 or 53)
	elseif phase == 3 then
		self:Bar(238505, 95)
	end
end

function mod:FocusedDreadflameSuccess(args)
	self:PrimaryIcon(238505)
end

do
	local playerList = mod:NewTargetList()
	function mod:BurstingDreadflame(args)
		if self:Me(args.destGUID) then
			self:Flash(args.spellId)
			self:Say(args.spellId)
		end
		playerList[#playerList+1] = args.destName
		if #playerList == 1 then
			self:ScheduleTimer("TargetMessage", 0.1, args.spellId, playerList, "Important", "Warning")
			burstingDreadflameCount = burstingDreadflameCount + 1
			if phase == 1 and burstingDreadflameCount == 2 then -- Inside Intermission
				self:Bar(args.spellId, 46)
			elseif phase == 2 then
				self:Bar(args.spellId, burstingDreadflameCount == 2 and 48 or burstingDreadflameCount == 3 and 55 or 50)
			elseif phase == 3 then
				self:Bar(args.spellId, burstingDreadflameCount % 2 == 0 and 25 or 70)
			end
		end
	end
end

function mod:NetherGaleRemoved(args)
	intermissionPhase = nil
	phase = 2
	self:Message("stages", "Positive", "Long", self:SpellName(-15229), false) -- Stage Two: Reflected Souls
	focusedDreadflameCount = 1
	burstingDreadflameCount = 1
	singularityCount = 1
	armageddonCount = 1
	felclawsCount = 0 -- Start at 0 to get timers correct

	self:Bar(239932, 10.4) -- Felclaws
	self:Bar(236710, 13.9, L.reflectionErupting) -- Shadow Reflection: Erupting
	self:Bar(238505, 30.4) -- Focused Dreadflame
	self:Bar(236378, 48.4, L.reflectionWailing) -- Shadow Reflection: Wailing
	self:Bar(240910, phaseTwoTimers[240910][armageddonCount]) -- Armageddon
	self:Bar(238430, 52.4) -- Bursting Dreadflame
	self:Bar(235059, phaseTwoTimers[235059][singularityCount], CL.count:format(self:SpellName(235059), singularityCount)) -- Rupturing Singularity
end

-- Stage Two: Reflected Souls
do
	local playerList = mod:NewTargetList()
	function mod:ShadowReflectionWailing(args)
		if self:Me(args.destGUID) then
			local _, _, _, _, _, _, expires = UnitDebuff(args.destName, args.spellName)
			local remaining = expires-GetTime()
			self:Flash(args.spellId)
			self:Say(args.spellId, L.reflectionWailing)
			self:ScheduleTimer("Say", remaining-3, args.spellId, 3, true)
			self:ScheduleTimer("Say", remaining-2, args.spellId, 2, true)
			self:ScheduleTimer("Say", remaining-1, args.spellId, 1, true)
		end
		playerList[#playerList+1] = args.destName
		if #playerList == 1 then
			self:Bar(args.spellId, 114, L.reflectionWailing)
			self:ScheduleTimer("TargetMessage", 0.1, args.spellId, playerList, "Urgent", "Alert", L.reflectionWailing)
		end
	end
end

-- Intermission: Deceiver's Veil
function mod:DeceiversVeilCast(args)
	self:Message("stages", "Positive", "Long", self:SpellName(-15394), false) -- Intermission: Deceiver's Veil
	self:StopBar(CL.count:format(self:SpellName(240910), armageddonCount)) -- Armageddon
	self:StopBar(L.reflectionErupting) -- Shadow Reflection: Erupting
	self:StopBar(L.reflectionWailing) -- Shadow Reflection: Wailing
	self:StopBar(239932) -- Fel Claws
	self:StopBar(238430) -- Bursting Dreadflame
	self:StopBar(238505) -- Focused Dreadflame
	self:StopBar(CL.count:format(self:SpellName(235059), singularityCount)) -- Rupturing Singularity
	mod:ZoomMinimap()
end

function mod:DeceiversVeilRemoved(args)
	phase = 3
	burstingDreadflameCount = 1
	self:Message("stages", "Positive", "Long", self:SpellName(-15255), false) -- Stage Three: Darkness of A Thousand Souls
	self:Bar(238999, 2, L.darkness) -- Darkness of a Thousand Souls
	self:Bar(239932, 11) -- Felclaws
	self:Bar(243982, 15) -- Tear Rift
	if not self:Easy() then
		self:Bar(244856, 30) -- Flaming Orb
	end
	self:Bar(238430, 42) -- Bursting Dreadflame
	self:Bar(238505, 80) -- Focused Dreadflame
	mod:ResetMinimap()
end

function mod:IllidansSightlessGaze(args)
	if self:Me(args.destGUID) then
		self:Message(args.spellId, "Personal", "Long")
		self:Say(args.spellId)
	end
end

-- Stage Three: Darkness of A Thousand Souls
function mod:DarknessofaThousandSouls(args)
	self:Message(args.spellId, "Urgent", "Long", CL.casting:format(args.spellName))
	self:Bar(args.spellId, 90, L.darkness)
	self:CastBar(args.spellId, 9, L.darkness)
	self:StartObeliskTimer(obeliskCount == 1 and 25 or 28)
	if self:Hud(args.spellId) then
		local offset = 1.5
		local timer = Hud:DrawTimer("player", 50, 9 - offset):SetColor(1, 0.5, 0)
		local label = Hud:DrawText("player", "Wait")

		function timer:OnDone()
			mod:PlaySound(false, "Info")
			timer:SetColor(0, 1, 0)
			label:SetText("GO!")
			C_Timer.After(offset, function()
				timer:Remove()
				label:Remove()
			end)
		end
	end
end

function mod:StartObeliskTimer(t)
	self:Bar(-15543, t)
	self:ScheduleTimer("Message", t, -15543, "Attention", "Info", CL.spawned:format(self:SpellName(-15543)))
	self:ScheduleTimer("Bar", t, -15543, 13, L.obeliskExplosion)
	obeliskCount = obeliskCount + 1
	if obeliskCount % 2 == 0 then
		self:ScheduleTimer("StartObeliskTimer", t, 36)
	end
end

function mod:TearRift(args)
	self:Message(args.spellId, "Important", "Alarm")
	self:Bar(args.spellId, 95)
end

-- Mythic
do
	local playerList = mod:NewTargetList()
	function mod:ShadowReflectionHopeless(args)
		if self:Me(args.destGUID) then
			local _, _, _, _, _, _, expires = UnitDebuff(args.destName, args.spellName)
			local remaining = expires-GetTime()
			self:Flash(args.spellId)
			self:Say(args.spellId, L.reflectionHopeless)
			self:ScheduleTimer("Say", remaining-3, args.spellId, 3, true)
			self:ScheduleTimer("Say", remaining-2, args.spellId, 2, true)
			self:ScheduleTimer("Say", remaining-1, args.spellId, 1, true)
		end
		playerList[#playerList+1] = args.destName
		if #playerList == 1 then
			self:ScheduleTimer("TargetMessage", 0.1, args.spellId, playerList, "Urgent", "Alert", L.reflectionHopeless)
		end
	end
end

do
	local oldZoom = 0

	function mod:ZoomMinimap()
		if self:GetOption(zoom_minimap) then
			oldZoom = Minimap:GetZoom()
			Minimap:SetZoom(Minimap:GetZoomLevels())
		end
	end

	function mod:ResetMinimap(args)
		if self:GetOption(zoom_minimap) then
			Minimap:SetZoom(oldZoom)
		end
	end
end
