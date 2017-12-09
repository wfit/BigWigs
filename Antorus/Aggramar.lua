--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Aggramar", nil, 1984, 1712)
if not mod then return end
mod:RegisterEnableMob(121975)
mod.engageId = 2063
mod.respawnTime = 25

--------------------------------------------------------------------------------
-- Locals
--

local Hud = Oken.Hud

local stage = 1
local wakeOfFlameCount = 1
local techniqueStarted = 0
local comboTime = nil
local foeBreakerCount = 1
local flameRendCount = 1
local searingTempestCount = 1
local nextIntermissionSoonWarning = 0

local mobCollector = {}
local energyChecked = {}

--------------------------------------------------------------------------------
-- Initialization
--

local ember_hud = mod:AddCustomOption { "ember_hud", "Show HUD on Ember of Taeshalach.", default = true }
function mod:GetOptions()
	return {
		"stages",
		245911, -- Wrought in Flame
		{244912, "TANK", "AURA"}, -- Blazing Eruption

		--[[ Stage One: Wrath of Aggramar ]]--
		{245990, "TANK"}, -- Taeshalach's Reach
		{245994, "SAY", "FLASH"}, -- Scorching Blaze
		{244693, "SAY", "AURA"}, -- Wake of Flame
		{244688, "AURA"}, -- Taeshalach Technique
		245458, -- Foe Breaker
		245463, -- Flame Rend
		{245301, "IMPACT"}, -- Searing Tempest
		ember_hud,

		--[[ Stage Two: Champion of Sargeras ]]--
		245983, -- Flare

		--[[ Stage Three: The Avenger ]]--
		246037, -- Empowered Flare

		--[[ Mythic ]]--
		{254452, "AURA"}, -- Ravenous Blaze
		255058, -- Empowered Flame Rend
		255061 -- Empowered Searing Tempest
	},{
		["stages"] = "general",
		[245990] = -15794, -- Stage One: wrath of Aggramar
		[245983] = -15858, -- Stage Two: Champion of Sargeras
		[246037] = -15860, -- Stage Three: The Avenger
		[254452] = "mythic",
	}
end

function mod:OnBossEnable()
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1")

	--[[ Stage One: Wrath of Aggramar ]]--
	self:Log("SPELL_AURA_APPLIED", "TaeshalachsReach", 245990)
	self:Log("SPELL_AURA_APPLIED_DOSE", "TaeshalachsReach", 245990)
	self:Log("SPELL_AURA_APPLIED", "ScorchingBlaze", 245994)
	self:Log("SPELL_CAST_START", "WakeofFlame", 244693)
	self:Log("SPELL_CAST_START", "FoeBreaker", 245458)
	self:Log("SPELL_CAST_START", "FlameRend", 245463, 255058) -- Normal, Empowered
	self:Log("SPELL_CAST_START", "SearingTempest", 245301, 255061) -- Normal, Empowered

	--[[ Intermission: Fires of Taeshalach ]]--
	self:Log("SPELL_AURA_APPLIED", "CorruptAegis", 244894)
	self:Log("SPELL_AURA_REMOVED", "CorruptAegisRemoved", 244894)
	self:Log("SPELL_AURA_APPLIED", "BlazingEruption", 244912)
	self:Log("SPELL_AURA_APPLIED_DOSE", "BlazingEruption", 244912)
	self:Log("SPELL_AURA_REMOVED", "BlazingEruptionRemoved", 244912)

	--[[ Mythic ]]--
	self:Log("SPELL_AURA_APPLIED", "RavenousBlaze", 254452)

	self:RegisterNetMessage("EmberDiscovered")
end

function mod:OnEngage()
	stage = 1
	wakeOfFlameCount = 1
	techniqueStarted = 0
	comboTime = GetTime() + 35
	foeBreakerCount = 1
	flameRendCount = 1

	if self:Mythic() then
		self:Bar(254452, 4.8) -- Ravenous Blaze
	else
		self:Bar(245994, 8) -- Scorching Blaze
	end
	self:Bar(244693, 5.5) -- Wake of Flame
	self:Bar(244688, 35) -- Taeshalach Technique

	nextIntermissionSoonWarning = 82 -- happens at 80%
	self:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", nil, "boss1")
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:UNIT_HEALTH_FREQUENT(unit)
	local hp = UnitHealth(unit) / UnitHealthMax(unit) * 100
	if hp < nextIntermissionSoonWarning then
		self:Message("stages", "Positive", nil, CL.soon:format(CL.intermission), false)
		nextIntermissionSoonWarning = nextIntermissionSoonWarning - 40
		if nextIntermissionSoonWarning < 40 then
			self:UnregisterUnitEvent("UNIT_HEALTH_FREQUENT", unit)
		end
	end
end

function mod:UNIT_SPELLCAST_SUCCEEDED(_, _, _, _, spellId)
	if spellId == 244688 then -- Taeshalach Technique
		techniqueStarted = 1
		foeBreakerCount = 1
		flameRendCount = 1
		searingTempestCount = 1
		comboTime = GetTime() + 60.8

		self:Bar(spellId, 60.8)
		self:ShowAura(244688, { pin = -1, pulse = false })
		self:Emit("ARGUS_TAESHALACH_STARTS")
		if not self:Mythic() then -- Random Combo in Mythic
			self:Bar(245463, 4, CL.count:format(self:SpellName(244033), flameRendCount)) -- Flame Rend
			self:Bar(245301, 15.7) -- Searing Tempest
		end
	elseif spellId == 244792 then -- Burning Will of Taeshalach, end of Taeshalach Technique but also casted in intermission
		if techniqueStarted == 1 then -- Check if he actually ends the combo, instead of being in intermission
			techniqueStarted = 0
			self:HideAura(244688)
			self:Bar(245994, 4) -- Scorching Blaze
			if stage == 1 then
				self:Bar(244693, 5) -- Wake of Flame
			elseif stage == 2 then
				self:Bar(245983, 9) -- Flare
			elseif stage == 3 then
				self:Bar(246037, 9) -- Empowered Flare
			end
		end
	elseif spellId == 245983 then -- Flare
		self:Message(spellId, "Important", "Warning")
		if comboTime > GetTime() + 15.8 then
			self:Bar(spellId, self:Mythic() and 61 or 15.8)
		end
	elseif spellId == 246037 then -- Empowered Flare
		self:Message(spellId, "Important", "Warning")
		if comboTime > GetTime() + 16.2 then
			self:Bar(spellId, 16.2)
		end
	end
end

--[[ Stage One: Wrath of Aggramar ]]--
function mod:TaeshalachsReach(args)
	local amount = args.amount or 1
	if amount % 3 == 0 or amount > 7 then
		self:StackMessage(args.spellId, args.destName, amount, "Neutral", amount > 7 and "Info") -- Swap on 8+
	end
end

do
	local isOnMe, scheduled = nil, nil

	local function warn(self, spellId)
		if not isOnMe then
			self:Message(spellId, "Important")
		end
		isOnMe = nil
		scheduled = nil
	end

	function mod:ScorchingBlaze(args)
		if self:Me(args.destGUID) then
			isOnMe = true
			self:TargetMessage(args.spellId, args.destName, "Important", "Warning")
			self:Flash(args.spellId)
			self:Say(args.spellId)
		end
		if not scheduled then
			scheduled = self:ScheduleTimer(warn, 0.3, self, args.spellId)
			if comboTime > GetTime() + 7.3 then
				self:CDBar(args.spellId, 7.3)
			end
		end
	end
end

do
	local function printTarget(self, name, guid)
		self:TargetMessage(244693, name, "Attention", "Alert", nil, nil, true)
		if self:Me(guid) then
			self:Say(244693)
			self:ShowAura(244693, 2, "On YOU", { countdown = false }, true)
		end
	end
	function mod:WakeofFlame(args)
		self:GetBossTarget(printTarget, 0.7, args.sourceGUID)
		wakeOfFlameCount = wakeOfFlameCount + 1
		if comboTime > GetTime() + 24 then
			self:Bar(args.spellId, 24)
		end
	end
end

function mod:FoeBreaker(args)
	self:Message(args.spellId, "Neutral", "Info", CL.count:format(args.spellName, foeBreakerCount))
	self:ShowAura(244688, "Tank", { icon = args.spellIcon, stacks = "#" .. foeBreakerCount })
	foeBreakerCount = foeBreakerCount + 1
	if foeBreakerCount == 2 and not self:Mythic() then -- Random Combo in Mythic
		self:Bar(args.spellId, 7.5, CL.count:format(args.spellName, foeBreakerCount))
	end
end

function mod:FlameRend(args)
	self:Message(args.spellId, "Important", "Alarm", CL.count:format(args.spellName, flameRendCount))
	self:ShowAura(244688, "Raid", { icon = args.spellIcon, stacks = "#" .. flameRendCount })
	flameRendCount = flameRendCount + 1
	if flameRendCount == 2 and not self:Mythic() then -- Random Combo in Mythic
		self:Bar(args.spellId, 7.5, CL.count:format(args.spellName, flameRendCount))
	end
end

function mod:SearingTempest(args)
	self:ShowAura(244688, "AoE", { icon = args.spellIcon, stacks = "#" .. searingTempestCount })
	self:Message(args.spellId, "Urgent", "Warning")
	self:ImpactBar(args.spellId, 6)
	searingTempestCount = searingTempestCount + 1
end

--[[ Intermission: Fires of Taeshalach ]]--
function mod:CorruptAegis()
	techniqueStarted = 0 -- End current technique
	self:HideAura(244688) -- Taeshalach Technique
	self:Message("stages", "Neutral", "Long", CL.intermission, false)
	self:StopBar(245994) -- Scorching Blaze
	self:StopBar(244693) -- Wake of Flame
	self:StopBar(244688) -- Taeshalach Technique
	self:StopBar(245458, CL.count:format(self:SpellName(245458), foeBreakerCount)) -- Foe Breaker
	self:StopBar(245463, CL.count:format(self:SpellName(245463), flameRendCount)) -- Flame Rend
	self:StopBar(245301) -- Searing Tempest
	self:StopBar(245983) -- Flare
	self:CDBar(245911, self:Mythic() and 165 or 180) -- Wrought in Flame XXX have to see when adds spawn exactly

	if self:GetOption(ember_hud) then
		wipe(mobCollector)
		wipe(energyChecked)
		Hud:RemoveObject("Ember")
		self:RegisterTargetEvents("EmberCollector")
	end
end

function mod:EmberDiscovered(data)
	self:EmberCollector(nil, mod:GetUnitIdByGUID(data.guid), data.guid, true)
end

function mod:EmberCollector(_, unit, guid, isSync)
	if not mobCollector[guid] then
		if self:MobId(guid) == 122532 then
			mobCollector[guid] = Hud:DrawText(guid, "?"):SetOffset(0, 80):Register("Ember")
			local area = Hud:DrawArea(guid, 30):SetOffset(0, 80):Register("Ember")
			local energy = Hud:DrawSpinner(guid, 30):SetOffset(0, 80):Register("Ember")
			local progress = 0
			function energy:Progress()
				local unit = mod:GetUnitIdByGUID(guid)
				if unit then
					local power = UnitPower(unit)
					if not energyChecked[unit] then
						energyChecked[unit] = true
						if power >= 50 then
							area:SetColor(1, 0.2, 0.2, 1)
						end
					end
					local max = UnitPowerMax(unit)
					progress = 1 - (power / max)
				end
				return progress
			end
			self:UpdateEmberCounter()
			if not isSync then
				self:Send("EmberDiscovered", { guid = guid })
			end
		end
	end
end

function mod:UpdateEmberCounter()
	local list = {}
	for guid in pairs(mobCollector) do
		list[#list + 1] = guid
	end
	table.sort(list)
	for i, guid in ipairs(list) do
		mobCollector[guid]:SetText(i)
	end
end

function mod:CorruptAegisRemoved()
	stage = stage + 1
	self:Message("stages", "Neutral", "Long", CL.stage:format(stage), false)

	self:CDBar(245994, 6) -- Scorching Blaze
	self:Bar(244688, 37.5) -- Taeshalach Technique
	if stage == 2 then
		self:Bar(245983, 10.5) -- Flare
	elseif stage == 3 then
		self:Bar(246037, 10) -- Empowered Flare
	end
end

function mod:BlazingEruption(args)
	self:ShowAura(args.spellId, 15, { stacks = args.amount or 1 })
end

function mod:BlazingEruptionRemoved(args)
	self:HideAura(args.spellId)
end

--[[ Mythic ]]--
do
	local playerList = mod:NewTargetList()
	function mod:RavenousBlaze(args)
		if self:Me(args.destGUID) then
			self:Flash(args.spellId)
			self:Say(args.spellId)
			self:ShowAura(args.spellId, 8, "Move", true)
		end
		playerList[#playerList+1] = args.destName
		if #playerList == 1 then
			if comboTime > GetTime() + 38 then
				self:CDBar(args.spellId, 38)
			end
			self:ScheduleTimer("TargetMessage", 0.3, args.spellId, playerList, "Important", "Warning")
		end
	end
end
