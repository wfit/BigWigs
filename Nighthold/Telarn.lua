
--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("High Botanist Tel'arn", 1530, 1761)
if not mod then return end
mod:RegisterEnableMob(104528, 109038, 109040, 109041) -- heroic, 3x mythic
mod.engageId = 1886
mod.respawnTime = 29.3
mod.instanceId = 1530

--------------------------------------------------------------------------------
-- Locals
--

local Hud = Oken.Hud

local nextPhaseSoon = 80
local phase = 1

--------------------------------------------------------------------------------
-- Initialization
--

local bossMarker = mod:AddMarkerOption(false, "npc", 3, -13694, 1, 3, 4)
local callOfTheNightMarker = mod:AddMarkerOption(false, "player", 1, 218809, 2, 5, 6, 7)
local fetterMarker = mod:AddMarkerOption(false, "player", 8, 218304, 8)
function mod:GetOptions()
	return {
		--[[ General ]]--
		"stages",
		bossMarker,

		--[[ Arcanist Tel'arn ]]--
		{218809, "SAY", "FLASH", "PROXIMITY", "HUD", "SMARTCOLOR"}, -- Call of Night
		callOfTheNightMarker,
		{218503, "TANK"}, -- Recursive Strikes
		218438, -- Controlled Chaos

		--[[ Solarist Tel'arn ]]--
		218148, -- Solar Collapse
		218774, -- Summon Plasma Spheres

		--[[ Naturalist Tel'arn ]]--
		219235, -- Toxic Spores
		218927, -- Grace of Nature
		{218304, "SAY"}, -- Parasitic Fetter
		fetterMarker,
		{218342, "FLASH", "SAY"}, -- Parasitic Fixate
	}, {
		["stages"] = "general",
		[218809] = -13694, -- Arcanist Tel'arn
		[218148] = -13682, -- Solarist Tel'arn
		[219235] = -13684, -- Naturalist Tel'arn
	}
end

function mod:OnBossEnable()
	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")

	--[[ General ]]--
	self:Log("SPELL_CAST_START", "Nightosis1", 216830) -- P2
	self:Log("SPELL_CAST_START", "Nightosis2", 216877) -- P3
	self:Log("SPELL_CAST_SUCCESS", "NatureInfusion", 222020) -- Mythic P2
	self:Log("SPELL_CAST_SUCCESS", "ArcaneInfusion", 222021) -- Mythic P3

	--[[ Arcanist Tel'arn ]]--
	self:Log("SPELL_AURA_APPLIED", "CallOfNight", 218809)
	self:Log("SPELL_AURA_REMOVED", "CallOfNightRemoved", 218809)
	self:Log("SPELL_AURA_APPLIED", "RecursiveStrikes", 218503)
	self:Log("SPELL_AURA_APPLIED_DOSE", "RecursiveStrikes", 218503)
	self:Log("SPELL_CAST_START", "ControlledChaos", 218438)

	--[[ Solarist Tel'arn ]]--
	self:Log("SPELL_CAST_START", "SolarCollapse", 218148)
	self:Log("SPELL_CAST_START", "SummonPlasmaSpheres", 218774)
	self:Log("SPELL_AURA_APPLIED", "PlasmaExplosion", 218780)
	self:Log("SPELL_AURA_APPLIED_DOSE", "PlasmaExplosion", 218780)

	--[[ Naturalist Tel'arn ]]--
	self:Log("SPELL_AURA_APPLIED", "ToxicSpores", 219235)
	self:Log("SPELL_AURA_REMOVED", "ToxicSporesRemoved", 219235)
	self:Log("SPELL_CAST_START", "GraceOfNature", 218927)
	self:Log("SPELL_AURA_APPLIED", "GraceOfNatureAura", 219009)
	self:Log("SPELL_CAST_SUCCESS", "ParasiticFetterSuccess", 218424)
	self:Log("SPELL_AURA_APPLIED", "ParasiticFetter", 218304)
	self:Log("SPELL_AURA_REMOVED", "ParasiticFetterRemoved", 218304)
	self:Log("SPELL_AURA_APPLIED", "Fixate", 218342) -- Parasitic Fixate
end

function mod:OnEngage()
	nextPhaseSoon = 80
	phase = 1

	if not self:Mythic() then
		self:Bar(218148, self:Easy() and 14.3 or 10) -- Solar Collapse, to _start
		self:Bar(218304, self:Easy() and 30 or 21.5) -- Parasitic Fetter, to _success
		self:Bar(218438, self:Easy() and 50 or 35) -- Controlled Chaos, to_start
		self:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", nil, "boss1")
	else
		self:Bar(218148, 5) -- Solar Collapse, to _start
		self:Bar(218304, 16.5) -- Parasitic Fetter, to _success
		self:Bar(218438, 30) -- Controlled Chaos, to_start
		self:Bar(218774, 45) -- Summon Plasma Spheres, to _start
		self:Bar(218809, 55) -- Call of Night, to _start
		self:Bar(218927, 65) -- Grace of Nature, to _start
	end
end

--------------------------------------------------------------------------------
-- Event Handlers
--

--[[ General ]]--
function mod:Nightosis1()
	self:Message("stages", "cyan", "Info", "75% - ".. self:SpellName(-13681), false) -- Stage Two: Nightosis
	phase = 2
	self:Bar(218774, self:Easy() and 16.3 or 12) -- Summon Plasma Spheres, to _start
	self:Bar(218304, self:Easy() and 32.1 or 23.5) -- Parasitic Fetter, to _success
	self:Bar(218148, self:Easy() and 45.2 or 32) -- Solar Collapse, to _start
	self:Bar(218438, self:Easy() and 59.1 or 42) -- Controlled Chaos, to _start
end

function mod:Nightosis2()
	self:Message("stages", "cyan", "Info", "50% - ".. self:SpellName(-13683), false) -- Stage Three: Pure Forms
	phase = 3
	self:Bar(218927, self:Easy() and 13.4 or 10.5) -- Grace of Nature, to _start
	self:Bar(218809, self:Easy() and 26.8 or 20) -- Call of Night, to _success
	self:Bar(218774, self:Easy() and 36.2 or 26) -- Summon Plasma Spheres, to _start
	self:Bar(218304, self:Easy() and 49.2 or 34) -- Parasitic Fetter, to _success
	self:Bar(218148, self:Easy() and 59.2 or 42) -- Solar Collapse, to _start
	self:Bar(218438, self:Easy() and 73.4 or 52) -- Controlled Chaos, to _start
end

function mod:NatureInfusion()
	self:Message("stages", "cyan", "Info", CL.stage:format(2), false)
	phase = 2
	self:StopBar(218927) -- Grace of Nature
	self:StopBar(218304) -- Parasitic Fetter
	self:Bar(218148, 15) -- Solar Collapse, to _start
	self:Bar(218774, 25) -- Summon Plasma Spheres, to _start
	self:Bar(218809, 42) -- Call of Night, to _success
	self:Bar(218438, 55) -- Controlled Chaos, to _start
end

function mod:ArcaneInfusion()
	self:Message("stages", "cyan", "Info", CL.stage:format(3), false)
	phase = 3
	self:StopBar(218148) -- Solar Collapse
	self:StopBar(218438) -- Controlled Chaos
	self:Bar(218809, 22) -- Call of Night, to _success
	self:Bar(218774, 35) -- Summon Plasma Spheres, to _start
end

function mod:UNIT_HEALTH_FREQUENT(event, unit)
	local hp = UnitHealth(unit) / UnitHealthMax(unit) * 100
	if hp < nextPhaseSoon then
		self:Message("stages", "cyan", "Info", CL.soon:format(CL.stage:format(phase+1)), false)
		nextPhaseSoon = nextPhaseSoon - 25
		if nextPhaseSoon < 50 then
			self:UnregisterUnitEvent(event, unit)
		end
	end
end

function mod:INSTANCE_ENCOUNTER_ENGAGE_UNIT()
	for i = 1, 5 do
		local unit = ("boss%d"):format(i)
		local mob = self:MobId(unit)
		if mob == 104528 or mob == 109040 then -- Arcanist / Diamond
			self:SetIcon(bossMarker, unit, 3)
		elseif mob == 109038 then -- Solarist / Star
			self:SetIcon(bossMarker, unit, 1)
		elseif mob == 109041 then -- Naturalist / Triangle
			self:SetIcon(bossMarker, unit, 4)
		end
	end
end

--[[ Arcanist Tel'arn ]]--
do
	local playerList, proxList, isOnMe, iconsUnused = mod:NewTargetList(), {}, nil, {2,5,6,7}

	function mod:CallOfNight(args)
		proxList[#proxList+1] = args.destName

		if self:Me(args.destGUID) then
			isOnMe = true
			self:Flash(args.spellId)
			self:Say(args.spellId)
			self:OpenProximity(args.spellId, 8, proxList) -- don't stand near others with the debuff
			self:TargetBar(args.spellId, 45, args.destName)
		end

		if not isOnMe then
			self:OpenProximity(args.spellId, 8, proxList, true) -- stand near debuffed players
		end

		playerList[#playerList+1] = args.destName
		if #playerList == 1 then
			self:ScheduleTimer("TargetMessage", 0.1, args.spellId, playerList, "red", "Alert")
			self:Bar(args.spellId, (self:Mythic() and (phase == 2 and 55 or phase == 3 and 35 or 65)) or self:Easy() and 71.5 or 50)
		end

		if self:Me(args.destGUID) then
			local spellId = args.spellId
			local opacity = self:Hud(spellId) and 0.75 or 0
			local timer = Hud:DrawTimer(args.destGUID, 75, 45):SetColor(1, 1, 1, opacity):Register(args.destKey)
			local t, callOfNight = GetTime(), args.spellName
			local lastStatus = -1
			function timer:OnUpdate()
				local status = 0 -- Not soaked
				for unit in mod:IterateGroup() do
					if not UnitIsUnit(unit, "player") and not UnitIsDead(unit) and mod:Range(unit) <= 5 then
						if UnitDebuff(unit, callOfNight) then
							status = 2 -- Marks together
							break
						else
							status = 1
						end
					end
				end

				if status ~= lastStatus then
					lastStatus = status
					if status == 0 then
						self:SetColor(1, 0.5, 0, opacity)
						mod:SmartColorSet(spellId, 1, 0.5, 0)
					elseif status == 1 then
						self:SetColor(0.2, 1, 0.2, opacity)
						mod:SmartColorSet(spellId, 0.2, 1, 0.2)
					elseif status == 2 then
						self:SetColor(1, 0, 0, opacity)
						mod:SmartColorSet(spellId, 1, 0, 0)
					end
				end

				local now = GetTime()
				if now - t > 1 and status ~= 1 then
					if status == 0 then
						mod:Say(false, "SOAK", false, "YELL")
					elseif status == 2 then
						mod:Say(false, "SPREAD", false, "YELL")
					end
					t = now
				end
			end
			function timer:OnRemove()
				mod:SmartColorUnset(spellId)
			end
		end

		if self:GetOption(callOfTheNightMarker) then
			local icon = table.remove(iconsUnused, 1)
			if icon then -- At least one icon unused
				SetRaidTarget(args.destUnit, icon)
			end
		end
	end

	function mod:CallOfNightRemoved(args)
		if self:Me(args.destGUID) then
			isOnMe = nil
			self:CloseProximity(args.spellId)
			self:StopBar(args.spellId, args.destName)
		end

		tDeleteItem(proxList, args.destName)
		if not isOnMe then -- stand near others
			if #proxList == 0 then
				self:CloseProximity(args.spellId)
			else
				self:OpenProximity(args.spellId, 8, proxList, true)
			end
		end

		Hud:RemoveObject(args.destKey)

		if self:GetOption(callOfTheNightMarker) then
			local icon = GetRaidTargetIndex(args.destUnit)
			if icon and icon > 0 and icon < 7 and not tContains(iconsUnused, icon) then
				table.insert(iconsUnused, icon)
				SetRaidTarget(args.destUnit, 0)
			end
		end
	end
end

function mod:RecursiveStrikes(args)
	local amount = args.amount or 1
	if amount > 5 and amount % 2 == 0 then
		self:StackMessage(args.spellId, args.destName, amount, "yellow", amount > 7 and "Warning")
	end
end

function mod:ControlledChaos(args)
	self:Message(args.spellId, "red", "Alert", CL.incoming:format(args.spellName))
	if self:Easy() then
		self:Bar(args.spellId, phase == 2 and 57.1 or phase == 3 and 71.4 or 50)
	else
		self:Bar(args.spellId, (self:Mythic() and (phase == 2 and 55 or phase == 3 and 35 or 65)) or phase == 2 and 40 or phase == 3 and 50 or 35)
	end
end

--[[ Solarist Tel'arn ]]--
function mod:SolarCollapse(args)
	self:Message(args.spellId, "red", "Long", CL.incoming:format(args.spellName))
	if self:Easy() then
		self:Bar(args.spellId, phase == 2 and 56.8 or phase == 3 and 71.4 or 50)
	else
		self:Bar(args.spellId, (self:Mythic() and (phase == 2 and 55 or phase == 3 and 35 or 65)) or phase == 2 and 40 or phase == 3 and 50 or 35)
	end
end

function mod:SummonPlasmaSpheres(args)
	self:Message(args.spellId, "orange", "Alert")
	if self:Easy() then
		self:Bar(args.spellId, phase == 2 and 57.1 or 71.4)
	else
		self:Bar(args.spellId, (self:Mythic() and (phase == 2 and 55 or phase == 3 and 35 or 65)) or phase == 2 and 40 or 50)
	end
end

do
	local prev = 0
	function mod:PlasmaExplosion()
		local t = GetTime()
		if self:Mythic() and phase == 2 and t-prev > 5 then
			prev = t
			self:Message(218304, "yellow", self:Damager() and "Alarm", CL.spawned:format(self:SpellName(-13699))) -- Parasitic Lasher
		end
	end
end

--[[ Naturalist Tel'arn ]]--
function mod:ToxicSpores(args)
	if self:Me(args.destGUID) then
		self:TargetMessage(args.spellId, args.destName, "blue", "Info")
		self:TargetBar(args.spellId, 12, args.destName)
	end
end

function mod:ToxicSporesRemoved(args)
	if self:Me(args.destGUID) then
		self:StopBar(args.spellId, args.destName)
	end
end

function mod:GraceOfNature(args)
	self:Message(args.spellId, "red", "Long", CL.casting:format(args.spellName))
	self:Bar(args.spellId, (self:Mythic() and (phase == 2 and 55 or phase == 3 and 35 or 65)) or self:Easy() and 71.4 or 50)
end

do
	local prev = 0
	function mod:GraceOfNatureAura(args)
		local t = GetTime()
		if t-prev > 1.5 then
			prev = t
			self:TargetMessage(218927, args.destName, "orange", self:Tank() and "Alarm")
		end
	end
end

function mod:ParasiticFetterSuccess()
	if self:Easy() then
		self:Bar(218304, phase == 2 and 57.2 or phase == 3 and 71.4 or 50)
	else
		self:Bar(218304, (self:Mythic() and (phase == 2 and 55 or phase == 3 and 35 or 65)) or phase == 2 and 40 or phase == 3 and 50 or 35)
	end
end

do
	local prev = 0
	function mod:ParasiticFetter(args)
		local t = GetTime()
		if t-prev > 5 then
			prev = t
			self:TargetMessage(args.spellId, args.destName, "orange", self:Dispeller("magic") and "Alarm")
		end
		if self:Me(args.destGUID) then
			self:Say(args.spellId)
		end
		if self:GetOption(fetterMarker) then
			SetRaidTarget(args.destName, 8)
		end
	end
end

do
	local prev = 0
	function mod:ParasiticFetterRemoved(args)
		local t = GetTime()
		if t-prev > 5 then
			prev = t
			self:Message(args.spellId, "yellow", self:Damager() and "Alarm", CL.spawned:format(self:SpellName(-13699))) -- Parasitic Lasher
			if self:Mythic() and phase == 3 then
				self:Message(218438, "red", "Alert", CL.incoming:format(args.spellName))
			end
		end
		if self:GetOption(fetterMarker) and GetRaidTargetIndex(args.destName) == 8 then
			SetRaidTarget(args.destName, 0)
		end
	end
end

function mod:Fixate(args)
	if self:Me(args.destGUID) then
		self:TargetMessage(args.spellId, args.destName, "blue", "Info", self:SpellName(177643)) -- Fixate
		self:Flash(args.spellId)
		self:Say(args.spellId)
	end
end
