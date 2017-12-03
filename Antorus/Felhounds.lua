--------------------------------------------------------------------------------
-- TODO:
-- -- Raid Markers for Weigt of Darkness and/or Siphon Corruption?
-- -- Check which debuffs for Weight of Darkness are the correct ones

--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Felhounds of Sargeras", nil, 1987, 1712)
if not mod then return end
mod:RegisterEnableMob(122477, 122135) -- F'harg, Shatug
mod.engageId = 2074
mod.respawnTime = 5

--------------------------------------------------------------------------------
-- Locals
--

local Hud = Oken.Hud

local FEL = "Fel"
local FIRE = "Fire"

local colors = {}
local color

--------------------------------------------------------------------------------
-- Initialization
--

local color_aura = mod:AddCustomOption { "color_aura", "Show attributed color as Aura when pulling the boss" }
local corruption_filter = mod:AddCustomOption { "corruption_filter", "Filter Enflame Corruption / Siphon Corruption Impact Bars based on your own color", default = false }
function mod:GetOptions()
	return {
		color_aura,
		corruption_filter,

		--[[ F'harg ]]--
		251445, -- Burning Maw
		{244072, "SMARTCOLOR"}, -- Molten Touch
		{244768, "SAY", "AURA"}, -- Desolate Gaze
		{244057, "IMPACT"}, -- Enflame Corruption
		{248815, "SAY", "AURA", "HUD"}, -- Enflamed

		--[[ Shatug ]]--
		245098, -- Corrupting Maw
		244131, -- Consuming Sphere
		{245024, "AURA"}, -- Consumed
		{254429, "SAY"}, -- Weight of Darkness
		{244056, "IMPACT"}, -- Siphon Corruption
		{248819, "SAY", "AURA"}, -- Siphoned

		--[[ General ]]--
		{244050, "AURA"}, -- Destroyer's Boon
		251356, -- Focusing Power
	},{
		[251445] = -15842, -- F'harg
		[245098] = -15836, -- Shatug
		[244050] = "general",
	}
end

function mod:OnBossEnable()
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1", "boss2")

	self:Log("SPELL_AURA_APPLIED", "FlametouchedOrShadowtouched", 244054, 244055)

	--[[ F'harg ]]--
	self:Log("SPELL_CAST_SUCCESS", "BurningMaw", 251445)
	self:Log("SPELL_AURA_APPLIED", "MoltenTouchApplied", 244072)
	self:Log("SPELL_AURA_REMOVED", "SingedRemoved", 244091)
	self:Log("SPELL_AURA_APPLIED", "DesolateGazeApplied", 244768)
	self:Log("SPELL_AURA_REMOVED", "DesolateGazeRemoved", 244768)
	self:Log("SPELL_CAST_SUCCESS", "EnflameCorruption", 244057)
	self:Log("SPELL_AURA_APPLIED", "Enflamed", 248815)
	self:Log("SPELL_AURA_REMOVED", "EnflamedRemoved", 248815)

	--[[ Shatug ]]--
	self:Log("SPELL_CAST_SUCCESS", "CorruptingMaw", 245098)
	self:Log("SPELL_AURA_APPLIED", "ConsumedApplied", 245024)
	self:Log("SPELL_AURA_APPLIED_DOSE", "ConsumedApplied", 245024)
	self:Log("SPELL_AURA_REMOVED", "ConsumedRemoved", 245024)
	self:Log("SPELL_AURA_APPLIED", "WeightofDarknessApplied", 254429)
	self:Log("SPELL_AURA_REMOVED", "WeightofDarknessRemoved", 254429)
	self:Log("SPELL_CAST_SUCCESS", "SiphonCorruption", 244056)
	self:Log("SPELL_AURA_APPLIED", "Siphoned", 248819)
	self:Log("SPELL_AURA_REMOVED", "SiphonedRemoved", 248819)

	--[[ General ]]--
	self:Log("SPELL_AURA_APPLIED", "SargerasBlessing", 246057) -- Destroyer's Boon buff
	self:Log("SPELL_AURA_REMOVED", "SargerasBlessingRemoved", 246057) -- Destroyer's Boon buff
	self:Log("SPELL_AURA_APPLIED", "FocusingPower", 251356)
end

function mod:OnEngage()
	wipe(colors)
	color = nil

	self:CDBar(251445, 10.5) -- Burning Maw
	self:CDBar(245098, 10.5) -- Corrupting Maw
	self:Bar(244056, self:Easy() and 29 or 28) -- Siphon Corruption
	self:Bar(244057, self:Easy() and 56 or 52) -- Enflame Corruption
	self:Bar(244131, self:Easy() and 54.5 or 52.5) -- Consuming Sphere
	self:Bar(244768, self:Easy() and 89 or 84.5) -- Desolate Gaze

	if not self:Easy() then
		self:Bar(244072, 20) -- Molten Touch
		self:Bar(254429, 78) -- Weight of Darkness
	end
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:UNIT_SPELLCAST_SUCCEEDED(_, spellName, _, _, spellId)
	if spellId == 244159 then -- Consuming Sphere
		self:Message(244131, "Attention", "Alert")
		self:Bar(244131, self:Easy() and 85 or 78.5)
	elseif spellId == 244069 then -- Weight of Darkness
		self:Bar(254429, 78.5)
	elseif spellId == 244064 then -- Desolate Gaze
		self:Bar(244768, self:Easy() and 104 or 96.5)
	end
end

function mod:FlametouchedOrShadowtouched(args)
	local c = args.spellId == 244054 and FIRE or FEL
	colors[args.destGUID] = c
	if self:Me(args.destGUID) then
		color = c
		self:ShowAura(color_aura, 7, c, { icon = args.spellIcon, countdown = false }, true)
	end
end

function mod:BurningMaw(args)
	self:Message(args.spellId, "Important", "Alarm")
	self:CDBar(args.spellId, 11)
end

do
	local playerList = mod:NewTargetList()
	function mod:MoltenTouchApplied(args)
		playerList[#playerList+1] = args.destName
		if #playerList == 1 then
			self:Bar(args.spellId, 96.5)
			self:ScheduleTimer("TargetMessage", 0.3, args.spellId, playerList, "Attention", "Warning")
		end
		if self:Me(args.destGUID) then
			self:SmartColorSet(244072, 1, 0.5, 0)
			self:ScheduleTimer("SmartColorUnset", 13, 244072)
		end
	end

	function mod:SingedRemoved(args)
		if self:Me(args.destGUID) then
			self:SmartColorUnset(244072)
		end
	end
end

do
	local playerList = mod:NewTargetList()
	function mod:DesolateGazeApplied(args)
		if self:Me(args.destGUID) then
			self:Say(args.spellId)
			self:SayCountdown(args.spellId, 8)
			self:ShowAura(args.spellId, "On YOU")
		end
		playerList[#playerList+1] = args.destName
		if #playerList == 1 then
			self:ScheduleTimer("TargetMessage", 0.3, args.spellId, playerList, "Urgent", "Warning", nil, nil, true)
		end
	end

	function mod:DesolateGazeRemoved(args)
		if self:Me(args.destGUID) then
			self:CancelSayCountdown(args.spellId)
			self:HideAura(args.spellId)
		end
	end
end

function mod:EnflameCorruption(args)
	self:Message(args.spellId, "Attention", "Alert")
	self:Bar(args.spellId, self:Easy() and 104 or 95.5)
	if not self:GetOption(corruption_filter) or color ~= FIRE then
		self:ImpactBar(args.spellId, self:Mythic() and 15 or 9)
	end
end

do
	local rangeCheck
	local rangeObject

	function mod:CheckEnflamedRange()
		for unit in mod:IterateGroup() do
			if not UnitIsUnit(unit, "player") and not UnitIsDead(unit) and mod:Range(unit) <= 8 then
				rangeObject:SetColor(1, 0.2, 0.2)
				return
			end
		end
		rangeObject:SetColor(0.2, 1, 0.2)
	end

	function mod:Enflamed(args)
		if self:Me(args.destGUID) then
			self:TargetMessage(args.spellId, args.destName, "Personal", "Warning")
			self:Say(args.spellId)
			self:SayCountdown(args.spellId, 4)
			self:ShowAura(args.spellId, 4, "Move")

			if self:Hud(args.spellId) then
				rangeObject = Hud:DrawSpinner("player", 50)
				rangeCheck = self:ScheduleRepeatingTimer("CheckEnflamedRange", 0.2)
				self:CheckEnflamedRange()
			end
		end
	end

	function mod:EnflamedRemoved(args)
		if self:Me(args.destGUID) then
			self:CancelSayCountdown(args.spellId)
			self:HideAura(args.spellId)
			if rangeObject then
				self:CancelTimer(rangeCheck)
				rangeObject:Remove()
				rangeObject = nil
			end
		end
	end
end

function mod:CorruptingMaw(args)
	self:Message(args.spellId, "Important", "Alarm")
	self:CDBar(args.spellId, 11)
end

function mod:ConsumedApplied(args)
	if self:Me(args.destGUID) then
		self:ShowAura(args.spellId, "Move", { stacks = args.amount or 1 })
	end
end

function mod:ConsumedRemoved(args)
	if self:Me(args.destGUID) then
		self:HideAura(args.spellId)
	end
end

do
	local playerList = mod:NewTargetList()
	function mod:WeightofDarknessApplied(args)
		if self:Me(args.destGUID) then
			self:Say(args.spellId)
			self:SayCountdown(args.spellId, 5)
		end
		playerList[#playerList+1] = args.destName
		if #playerList == 1 then
			self:ScheduleTimer("TargetMessage", 0.3, args.spellId, playerList, "Urgent", "Warning", nil, nil, true)
		end
	end
end

function mod:WeightofDarknessRemoved(args)
	if self:Me(args.destGUID) then
		self:CancelSayCountdown(args.spellId)
	end
end

function mod:SiphonCorruption(args)
	self:Message(args.spellId, "Attention", "Alert")
	self:Bar(args.spellId, self:Easy() and 85 or 78.5)
	if not self:GetOption(corruption_filter) or color ~= FEL then
		self:ImpactBar(args.spellId, self:Mythic() and 15 or 9)
	end
end

function mod:Siphoned(args)
	if self:Me(args.destGUID) then
		self:TargetMessage(args.spellId, args.destName, "Personal", "Warning")
		self:SayCountdown(args.spellId, 4)
		self:ShowAura(args.spellId, 4, "Pack")
	end
end

function mod:SiphonedRemoved(args)
	if self:Me(args.destGUID) then
		self:CancelSayCountdown(args.spellId)
		self:HideAura(args.spellId)
	end
end

do
	local prev = 0
	function mod:SargerasBlessing(args)
		local t = GetTime()
		if t-prev > 0.5 then
			prev = t
			self:Message(244050, "Urgent", "Warning", args.spellName, args.spellId)
			self:ShowAura(244050, "Spread Boss")
		end
	end

	function mod:SargerasBlessingRemoved()
		self:HideAura(244050)
	end
end

-- XXX Only on pull?
function mod:FocusingPower(args)
	self:TargetMessage(args.spellId, args.destName, "Neutral", "Info")
	self:TargetBar(args.spellId, 15, args.destName)
end
