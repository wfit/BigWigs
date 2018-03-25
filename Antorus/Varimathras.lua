--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Varimathras", 1712, 1983)
if not mod then return end
mod:RegisterEnableMob(122366)
mod.engageId = 2069
mod.respawnTime = 30
mod.instanceId = 1712

--------------------------------------------------------------------------------
-- Locals
--

local Hud = Oken.Hud

local tormentActive = 0 -- 1: Flames, 2: Frost, 3: Fel, 4: Shadows
local mobCollector = {}
local felTick = 0
local necroticEmbraceCount = 0

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then
	L.shadowOfVarimathras_icon = "spell_warlock_demonsoul"
end

--------------------------------------------------------------------------------
-- Initialization
--

local necroticEmbraceMarker = mod:AddMarkerOption(true, "player", 7, 244094, 7, 3, 4, 6)
function mod:GetOptions()
	return {
		"stages", -- Torment of Flames, Frost, Fel, Shadows
		"berserk",
		243961, -- Misery
		{243960, "TANK"}, -- Shadow Strike
		243999, -- Dark Fissure
		{244042, "SAY", "FLASH", "ICON", "AURA"}, -- Marked Prey
		{244094, "SAY", "FLASH", "AURA", "HUD", "SMARTCOLOR", "PROXIMITY"}, -- Necrotic Embrace
		necroticEmbraceMarker,
		{243980, "AURA"}, -- Torment of Fel
		-16350, -- Shadow of Varimathras
	},{
		["stages"] = "general",
		[-16350] = "mythic",
	}
end

function mod:OnBossEnable()
	--[[ Stages ]]--
	self:Log("SPELL_AURA_APPLIED", "TormentofFlames", 243968)
	self:Log("SPELL_AURA_APPLIED", "TormentofFrost", 243977)
	self:Log("SPELL_AURA_APPLIED", "TormentofFel", 243980)
	self:Log("SPELL_AURA_APPLIED", "TormentofShadows", 243973)

	--[[ General ]]--
	self:Log("SPELL_AURA_APPLIED", "Misery", 243961)
	self:Log("SPELL_CAST_SUCCESS", "ShadowStrike", 243960, 257644) -- Heroic, Normal
	self:Log("SPELL_CAST_START", "DarkFissureStart", 243999)
	self:Log("SPELL_CAST_SUCCESS", "DarkFissure", 243999)
	self:Log("SPELL_AURA_APPLIED", "MarkedPrey", 244042)
	self:Log("SPELL_AURA_REMOVED", "MarkedPreyRemoved", 244042)
	self:Log("SPELL_CAST_SUCCESS", "NecroticEmbraceSuccess", 244093)
	self:Log("SPELL_AURA_APPLIED", "NecroticEmbrace", 244094)
	self:Log("SPELL_AURA_REMOVED", "NecroticEmbraceRemoved", 244094)
	self:Log("SPELL_AURA_APPLIED", "GroundEffectDamage", 244005) -- Dark Fissure
	self:Log("SPELL_PERIODIC_DAMAGE", "GroundEffectDamage", 244005) -- Dark Fissure
	self:Log("SPELL_PERIODIC_MISSED", "GroundEffectDamage", 244005) -- Dark Fissure
end

function mod:OnEngage()
	tormentActive = 0
	necroticEmbraceCount = 0
	wipe(mobCollector)

	self:CDBar("stages", 5, self:SpellName(243968), 243968) -- Torment of Flames
	self:CDBar(243960, 9.7) -- Shadow Strike
	self:CDBar(243999, 17.8) -- Dark Fissure
	self:CDBar(244042, 25.5) -- Marked Prey
	if not self:Easy() then
		self:CDBar(244094, 35.3) -- Necrotic Embrace
	end

	self:Berserk(310)
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:CheckRange(object)
	local inRange = 0
	for unit in mod:IterateGroup() do
		if not UnitIsUnit(unit, "player") and not UnitIsDead(unit) and self:Range(unit) <= 10 then
			inRange = inRange + 1
			if inRange >= 2 then
				object:SetColor(1, 0.2, 0.2)
				return
			end
		end
	end
	object:SetColor(0.2, 1, 0.2)
end

function mod:TormentofFlames(args)
	if tormentActive ~= 1 then
		tormentActive = 1
		self:Message("stages", "Positive", "Long", args.spellName, args.spellId)
		if self:Easy() then
			self:CDBar("stages", 355, self:SpellName(243973), 243973) -- Torment of Shadows
		else
			self:CDBar("stages", self:Mythic() and 100 or 120, self:SpellName(243977), 243977) -- Torment of Frost
		end
	end
end

function mod:TormentofFrost(args)
	if tormentActive ~= 2 then
		tormentActive = 2
		self:Message("stages", "Positive", "Long", args.spellName, args.spellId)
		self:CDBar("stages", self:Mythic() and 100 or 114, self:SpellName(243980), 243980) -- Torment of Fel
	end
end

function mod:TormentofFel(args)
	if tormentActive ~= 3 then
		tormentActive = 3
		felTick = 0
		self:Message("stages", "Positive", "Long", args.spellName, args.spellId)
		self:CDBar("stages", self:Mythic() and 90 or 121, self:SpellName(243973), 243973) -- Torment of Shadows

		self:ShowAura(243980, { pulse = false, pin = -1 })
		self:Log("SPELL_PERIODIC_DAMAGE", "TormentofFelTick", 243980)
		self:Log("SPELL_PERIODIC_MISSED", "TormentofFelTick", 243980)
	end
end

do
	local prev = 0
	function mod:TormentofFelTick()
		local t = GetTime()
		if t - prev > 1.5 then
			prev = t
			felTick = felTick + 1
			self:ShowAura(243980, 5, { stacks = felTick, countdown = false })
		end
	end
end

function mod:TormentofShadows(args)
	if tormentActive ~= 4 then
		tormentActive = 4
		self:Message("stages", "Positive", "Long", args.spellName, args.spellId)

		self:RemoveLog("SPELL_PERIODIC_DAMAGE", "TormentofFelTick", 243980)
		self:RemoveLog("SPELL_PERIODIC_MISSED", "TormentofFelTick", 243980)
		self:HideAura(243980)
	end
end

function mod:Misery(args)
	if self:Me(args.destGUID) then
		self:Message(args.spellId, "Personal", "Alarm", CL.you:format(args.spellName))
	end
end

function mod:ShadowStrike()
	self:Message(243960, "Urgent", "Warning")
	self:CDBar(243960, 9.8)
end

function mod:DarkFissureStart(args)
	self:CDBar(243960, 5.3) -- Shadow Strike
end

function mod:DarkFissure(args)
	self:Message(args.spellId, "Attention", "Alert")
	self:CDBar(args.spellId, 32.9)
end

function mod:MarkedPrey(args)
	if self:Me(args.destGUID) then
		self:Flash(args.spellId)
		self:Say(args.spellId)
		self:SayCountdown(args.spellId, 5)
		self:ShowAura(args.spellId, 5, "On YOU")
	end
	self:PrimaryIcon(args.spellId, args.destName)
	self:TargetMessage(args.spellId, args.destName, "Important", "Alarm")
	self:TargetBar(args.spellId, 5, args.destName)
	self:CDBar(args.spellId, 32.8)
end

function mod:MarkedPreyRemoved(args)
	self:PrimaryIcon(args.spellId)
	self:StopBar(args.spellId, args.destName)
	if self:Me(args.destGUID) then
		self:CancelSayCountdown(args.spellId)
		self:HideAura(args.spellId)
	end
end

do
	local rangeCheck, rangeObject
	local playerList, scheduled, isOnMe, proxList = mod:NewTargetList(), nil, nil, {}

	function mod:NecroticEmbraceSuccess()
		self:CDBar(244094, 30.5)
		necroticEmbraceCount = necroticEmbraceCount + 1
		wipe(proxList)
	end

	local function warn(self, spellId)
		if not isOnMe then
			self:TargetMessage(spellId, playerList, "Urgent")
		else
			wipe(playerList)
		end
		scheduled = nil
	end

	function mod:NecroticEmbrace(args)
		if #playerList >= 2 then return end -- Avoid spam if something goes wrong
		if tContains(proxList, args.destName) then return end -- Don't annouce someone twice
		local marker = (necroticEmbraceCount % 2 == 1) and (#playerList == 0 and 7 or 3) or (#playerList == 0 and 4 or 6)
		playerList[#playerList+1] = args.destName
		if self:Me(args.destGUID) then
			self:TargetMessage(args.spellId, args.destName, "Urgent", "Warning", CL.count_icon:format(args.spellName, #playerList, marker))
			self:Say(args.spellId, CL.count_rticon:format(args.spellName, #playerList, marker))
			self:Flash(args.spellId, marker)
			self:SayCountdown(args.spellId, 6, marker)
			self:OpenProximity(args.spellId, 10)
			self:ShowAura(args.spellId, 6, "Necro", { icon = marker, borderless = false }) -- { icon = 450908 }
			self:SmartColorSet(args.spellId, 1, 0, 0)
			if self:Hud(args.spellId) then
				rangeObject = Hud:DrawSpinner("player", 50)
				rangeCheck = self:ScheduleRepeatingTimer("CheckRange", 0.1, rangeObject)
				self:CheckRange(rangeObject)
			end
			isOnMe = true
		end

		proxList[#proxList+1] = args.destName
		if not isOnMe then
			self:OpenProximity(args.spellId, 10, proxList)
		end

		if not scheduled then
			scheduled = self:ScheduleTimer(warn, 0.3, self, args.spellId)
		end

		if self:GetOption(necroticEmbraceMarker) then
			SetRaidTarget(args.destName, marker)
		end
	end

	function mod:NecroticEmbraceRemoved(args)
		if self:Me(args.destGUID) then
			self:Message(args.spellId, "Positive", "Info", CL.removed:format(args.spellName))
			isOnMe = nil
			self:CancelSayCountdown(args.spellId)
			self:CloseProximity(args.spellId)
			self:HideAura(args.spellId)
			self:SmartColorUnset(args.spellId)
			if rangeObject then
				self:CancelTimer(rangeCheck)
				rangeObject:Remove()
				rangeObject = nil
			end
		end

		if self:GetOption(necroticEmbraceMarker) then
			SetRaidTarget(args.destName, 0)
		end

		tDeleteItem(proxList, args.destName)

		if not isOnMe then -- Don't change proximity if it's on you and expired on someone else
			if #proxList == 0 then
				self:CloseProximity(args.spellId)
			else -- Update proximity
				self:OpenProximity(args.spellId, 10, proxList)
			end
		end
	end
end

do
	local prev = 0
	function mod:GroundEffectDamage(args)
		local t = GetTime()
		if self:Me(args.destGUID) and t-prev > 1.5 then
			prev = t
			self:Message(243999, "Personal", "Alert", CL.underyou:format(args.spellName)) -- Dark Fissure
		end
	end
end
