--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Vectis", 1861, 2166)
if not mod then return end
mod:RegisterEnableMob(134442)
mod.engageId = 2134
mod.respawnTime = 30

--------------------------------------------------------------------------------
-- Locals
--

local Hud = Oken.Hud

local omegaList = {}
local omegaIconCount = 1
local pathogenBombCount = 1
local contagionCount = 1
local immunosuppressionCount = 1
local nextLiquify = 0
local lingeringInfectionList = {}
local liquified = false
local infectionCount = 0
local gestateCount = 0

--------------------------------------------------------------------------------
-- Initialization
--

local omegaVectorMarker = mod:AddMarkerOption(true, "player", 1, 265143, 1, 2, 3, 4) -- Omega Vector
local bigwigOmega = mod:AddCustomOption { "use_bigwigs_omega", "Use the original BigWigs Omega Vector code", default = false }
function mod:GetOptions()
	return {
		{ 265143, "SAY_COUNTDOWN", "SAY", "AURA", "SAY_COUNTDOWN" }, -- Omega Vector
		omegaVectorMarker,
		bigwigOmega,
		{ 265127, "INFOBOX", "HUD" }, -- Lingering Infection
		{ 265178, "TANK" }, -- Evolving Affliction

		267242, -- Contagion
		{ 265212, "SAY", "SAY_COUNTDOWN", "ICON", "AURA" }, -- Gestate
		{ 265206, "IMPACT" }, -- Immunosuppression
		265217, -- Liquefy
		{ 266459, "HUD" }, -- Plague Bomb
	}
end

function mod:OnBossEnable()
	self:Log("SPELL_AURA_APPLIED", "OmegaVectorApplied", 265129, 265143) -- Normal, Heroic
	self:Log("SPELL_AURA_APPLIED_DOSE", "OmegaVectorApplied", 265129, 265143) -- Normal, Heroic
	self:Log("SPELL_AURA_REMOVED", "OmegaVectorRemoved", 265129, 265143) -- Normal, Heroic
	self:Log("SPELL_AURA_APPLIED", "LingeringInfection", 265127)
	self:Log("SPELL_AURA_APPLIED_DOSE", "LingeringInfection", 265127)
	self:Log("SPELL_CAST_SUCCESS", "EvolvingAffliction", 265178)
	self:Log("SPELL_AURA_APPLIED", "EvolvingAfflictionApplied", 265178)
	self:Log("SPELL_AURA_APPLIED_DOSE", "EvolvingAfflictionApplied", 265178)
	self:Log("SPELL_CAST_START", "Contagion", 267242)
	self:Log("SPELL_CAST_SUCCESS", "Gestate", 265209)
	self:Log("SPELL_AURA_APPLIED", "GestateApplied", 265212)
	self:Log("SPELL_AURA_REMOVED", "GestateRemoved", 265212)
	self:Log("SPELL_CAST_START", "Immunosuppression", 265206)
	self:Death("PlagueAmalgamDeath", 135016)
	self:Log("SPELL_CAST_START", "Liquefy", 265217)
	self:Log("SPELL_AURA_REMOVED", "LiquefyRemoved", 265217)
	self:Log("SPELL_CAST_SUCCESS", "PlagueBomb", 266459)
end

function mod:OnEngage()
	omegaList = {}
	lingeringInfectionList = {}
	omegaIconCount = 1
	contagionCount = 1

	self:Bar(267242, 20.5, CL.count:format(self:SpellName(267242), contagionCount)) -- Contagion
	self:Bar(265212, 10) -- Gestate

	nextLiquify = GetTime() + 90
	self:Bar(265217, 90) -- Liquefy

	self:OpenInfo(265127, self:SpellName(265127)) -- Lingering Infection

	liquified = false
	infectionCount = 0
	self:OmegaVectorReset()

	gestateCount = 0

	-- self:RegisterEvent("UNIT_AURA") -- XXX Blizzard does not emit SPELL_AURA_APPLIED/REMOVED for multiple stacks
end

--------------------------------------------------------------------------------
-- Omega Vector
--

local vectorKeys = { "vector_1", "vector_2", "vector_3", "vector_4" }
local soakerKeys = { "soaker_1", "soaker_2", "soaker_3", "soaker_4" }

local airborne = {}
local roster = { tank = {}, melee = {}, ranged = {}, healer = {}, index = {}, role = {} }
local playerUnit, playerIsTank
local vectors = {} -- [1-4] indexes points to the player having the vector, [units] indexes is a list of vectors for the unit
local stacks = {}
local soakers = {} -- [1-4] indexes points to the player soaking, [units] indexes point to the soaked vector for unit
local pending = {} -- Vectors not yet attributed

local function trace(color, str, ...)
	print(format("|cff" .. color .. str, ...))
end

local spamTicker

local function StopSpamming()
	if spamTicker then
		spamTicker:Cancel()
		spamTicker = nil
	end
end

local function StartSpamming(icon)
	StopSpamming()
	local msg = "{rt" .. icon .. "}"
	spamTicker = C_Timer.NewTicker(2, function()
		SendChatMessage(msg, "YELL")
	end)
end

function mod:OmegaVectorReset()
	wipe(airborne)
	wipe(vectors)
	for i = 1, (self:Mythic() and 4 or 3) do
		airborne[i] = i
		vectors[i] = false
	end
	for key in pairs(roster) do
		wipe(roster[key])
	end
	local i = 1
	for unit in self:IterateGroup { strict = true } do
		local role = (self:Tank(unit) and roster.tank) or (self:Melee(unit) and roster.melee) or roster.ranged
		role[unit] = true
		if self:Healer(unit) then
			roster.healer[unit] = true
		end
		roster.index[unit] = i
		roster.role[unit] = (role == roster.tank and "tank") or (role == roster.melee and "melee") or "ranged"
		vectors[unit] = {}
		stacks[unit] = 0
		if UnitIsUnit("player", unit) then
			playerUnit = unit
			playerIsTank = role == roster.tank
		end
		i = i + 1
	end
	wipe(soakers)
	wipe(pending)
end

local minOverall -- Min. amount of stacks (not including tanks)
local minMelee, minRanged
local function updateStats()
	minOverall = 99
	minMelee = 99
	minRanged = 99
	for unit in mod:IterateGroup { alive = true } do
		local count = stacks[unit] + (soakers[unit] and 1 or 0)
		if not roster.tank[unit] and count < minOverall then
			minOverall = count
		end
		if roster.melee[unit] and count < minMelee then
			minMelee = count
		end
		if roster.ranged[unit] and count < minRanged then
			minRanged = count
		end
	end
end

local function isEligible(unit)
	if roster.tank[unit] then
		return true -- Tanks are always eligible
	elseif #vectors[unit] > 0 or soakers[unit] then
		return false -- People with either the vector or already soaking are not
	elseif stacks[unit] == 10 and minOverall < 10 then
		return false -- People with 10 stacks are not eligible if some people have 9
	elseif stacks[unit] == 11 then
		return false -- People with 11 stacks are never eligible
	else
		return true
	end
end

local function mostSuitableFor(unit)
	local allowCrossSwitch = (minMelee - minRanged) ~= 0
	local unitRole, unitIdx = roster.role[unit], roster.index[unit]
	return function(a, b)
		local aRole, bRole = roster.role[a], roster.role[b]
		local aTank, bTank = roster.tank[a], roster.tank[b]
		if aTank ~= bTank then
			return not aTank
		elseif not allowCrossSwitch and aRole ~= bRole and (aRole == unitRole or bRole == unitRole) then
			-- Cross switch is forbidden, only one of the candidate has the same role as the unit
			return aRole == unitRole
		else
			local aStacks, bStacks = stacks[a], stacks[b]
			local aCross, bCross = unitRole ~= aRole, unitRole ~= bRole
			local aHealer, bHealer = roster.healer[a], roster.healer[b]
			if aStacks ~= bStacks then
				return aStacks < bStacks
			elseif aCross ~= bCross then
				return not aCross
			elseif aHealer ~= bHealer then
				if aCross then
					return aHealer
				else
					return not aHealer
				end
			else
				local aDistance, bDistance = math.abs(unitIdx - roster.index[a]), math.abs(unitIdx - roster.index[b])
				if aDistance ~= bDistance then
					return aDistance < bDistance
				else
					return a < b
				end
			end
		end
	end
end

local function performAttribution(spellId)
	while #pending > 0 do
		local entry = table.remove(pending)
		local vector, unit, expires = entry.id, entry.unit, entry.expires

		updateStats()
		local candidates = mod:EnumerateGroup { alive = true, filter = isEligible }
		table.sort(candidates, mostSuitableFor(unit))
		local soaker = candidates[1]
		local toTanks = roster.tank[soaker]

		soakers[vector] = soaker
		soakers[soaker] = vector

		-- Tracing
		local str = ""
		for i = 1, 4 do
			if not candidates[i] then break end
			str = str .. format(" %s(%d)", UnitName(candidates[i]), stacks[candidates[i]])
		end
		local arrow = roster.role[unit] == roster.role[soaker] and "--->" or "-X->"
		trace("ffffff", "|T%d:16:16:0:0|t %s %s%s", 137000 + vector, UnitName(unit), arrow, str)

		-- Display soaker name to player
		if unit == playerUnit then
			if toTanks then
				mod:ShowAura(spellId, "TANKS", { key = vectorKeys[vector], pulse = true, icon = "inv_shield_06" })
			else
				mod:ShowAura(spellId, UnitName(soaker), { key = vectorKeys[vector], pulse = false })
				StartSpamming(vector)
			end
		end

		-- Display unit name to soaker
		if not toTanks and soaker == playerUnit then
			local icon = vectors[unit][1]
			mod:PlaySound(spellId, "beware")
			mod:ShowAura(spellId, UnitName(unit), expires - GetTime(), {
				key = soakerKeys[vector],
				countdown = icon == vector,
				icon = icon,
				borderless = false,
				stacks = icon ~= vector and "{rt" .. vector .. "}" or nil
			})
			StartSpamming(vector)
			if liquified then
				local left = expires - GetTime()
				for t = (left - 2), 0, -2 do
					mod:Say(spellId, UnitName(unit), true, "YELL")
				end
			end
		end
	end
end

-- Enmulate SPELL_AURA_APPLIED / SPELL_AURA_REMOVED for multiple vectors on one target
local select, UnitDebuff = select, UnitDebuff
local fakeArgs = { spellId = 265143 }
function mod:UNIT_AURA(_, unit)
	if not roster.index[unit] then return end
	local count = 0
	for i = 1, 40 do
		local spellId = select(10, UnitDebuff(unit, i))
		if not spellId then
			break
		elseif spellId == 265143 or spellId == 265129 then
			count = count + 1
		end
	end
	if #vectors[unit] ~= count then
		local delta = #vectors[unit] - count
		local deltaAbs = math.abs(delta)
		trace("ffff00", "Synthesizing %d %s on %s.", deltaAbs, delta < 0 and "SPELL_AURA_APPLIED" or "SPELL_AURA_REMOVED", UnitName(unit))
		local fn = delta < 0 and self.OmegaVectorApplied or self.OmegaVectorRemoved
		fakeArgs.destUnit = unit
		for i = 1, deltaAbs do fn(self, fakeArgs) end
	end
end

--------------------------------------------------------------------------------
-- Event Handlers
--
function mod:OmegaVectorApplied(args)
	if self:Normal() or self:GetOption(bigwigOmega) or true then
		if not omegaList[args.destName] then
			omegaList[args.destName] = 1
		else
			omegaList[args.destName] = omegaList[args.destName] + 1
		end
		if self:GetOption(omegaVectorMarker) and omegaList[args.destName] == 1 then
			SetRaidTarget(args.destName, (omegaIconCount % 3) + 1) -- Normal: 1 Heroic+: 1->2->3->1
			omegaIconCount = omegaIconCount + 1
		end
		if self:Me(args.destGUID) then
			self:TargetMessage2(265143, "blue", args.destName)
			self:PlaySound(265143, "alarm")
			self:SayCountdown(265143, 10)
			self:ShowDebuffAura(265143, args.spellId)
		end
	else
		-- Target unit and Vector ID
		local unit = args.destUnit
		local isNotTank = not roster.tank[unit]
		local vector = table.remove(airborne)

		-- Remove soaker for this vector (whoever he is)
		do
			local soaker = soakers[vector]
			if soaker then
				if soaker ~= unit and isNotTank then
					trace("ff0000", "FAIL? %s was not attributed to soak %s (|T%d:16:16:0:0|t), it should have been %s!", UnitName(unit), UnitName(vectors[vector]), 137000 + vector, UnitName(soaker))
				end
				soakers[soaker] = false
				soakers[vector] = false
			end
		end

		-- Record vector and stack
		table.insert(vectors[unit], vector)
		vectors[vector] = unit
		stacks[unit] = stacks[unit] + 1
		if isNotTank then
			table.insert(pending, { id = vector, unit = unit, expires = GetTime() + 10 })

			-- Set raid target if this is the first vector on the target
			if #vectors[unit] == 1 then
				trace("aaaaaa", "%s gained vector |T%d:16:16:0:0|t", UnitName(unit), 137000 + vector)
				if self:GetOption(omegaVectorMarker) then
					SetRaidTarget(unit, vector)
				end
			else
				trace("aaaaaa", "%s gained vector |T%d:16:16:0:0|t (already has vector |T%d:16:16:0:0|t)", UnitName(unit), 137000 + vector, 137000 + vectors[unit][1])
			end

			-- Show temp aura for vector
			if unit == playerUnit then
				self:PlaySound(265143, "warning")
				self:Say(265143, format("{rt%d}", vector), true)
				self:TargetMessage2(265143, "orange", args.destName)
				infectionCount = infectionCount + 1
				self:ShowAura(265143, 10, "...", {
					key = vectorKeys[vector],
					countdown = false,
					stacks = "{rt" .. vector .. "}"
				})
			end
		end

		-- Only perform soaker attribution if no vectors are airborne
		if #airborne < 1 then performAttribution(265143) end
	end
end

function mod:OmegaVectorRemoved(args)
	if self:Normal() or self:GetOption(bigwigOmega) or true then
		omegaList[args.destName] = omegaList[args.destName] - 1
		if omegaList[args.destName] == 0 then
			omegaList[args.destName] = nil
			if self:GetOption(omegaVectorMarker) then
				SetRaidTarget(args.destName, 0)
			end
			if self:Me(args.destGUID) then
				self:CancelSayCountdown(265143)
				self:HideAura(265143)
			end
		end
	else
		local unit = args.destUnit
		local isNotTank = not roster.tank[unit]
		local vector = table.remove(vectors[unit])
		table.insert(airborne, vector)

		if isNotTank then
			if #vectors[unit] > 0 then
				trace("aaaaaa", "%s lost vector |T%d:16:16:0:0|t (switched to next vector |T%d:16:16:0:0|t)", UnitName(unit), 137000 + vector, 137000 + vectors[unit][1])
				if self:GetOption(omegaVectorMarker) then
					SetRaidTarget(unit, vectors[unit][1])
				end
			else
				trace("aaaaaa", "%s lost vector |T%d:16:16:0:0|t", UnitName(unit), 137000 + vector)
				if self:GetOption(omegaVectorMarker) then
					SetRaidTarget(unit, 0)
				end
			end

			-- Remove vector aura from player
			if unit == playerUnit then
				infectionCount = infectionCount - 1
				self:HideAura(vectorKeys[vector])
				StopSpamming()
			end
		end

		-- Update aura for soaker
		if not playerIsTank then
			if soakers[vector] == playerUnit then
				-- I'm the soaker for this vector, just remove it
				self:HideAura(soakerKeys[vector])
				StopSpamming()
			else
				local soakedVector = soakers[playerUnit]
				if vectors[soakedVector] == unit then
					-- This is the unit having the vector I'm supposed to soak, update my aura
					local stacksOverride
					if vectors[unit][1] == soakedVector then stacksOverride = false end
					-- Update icon and stacks parts
					self:ShowAura(265143, {
						key = soakerKeys[soakedVector],
						pulse = false,
						icon = vectors[unit][1],
						borderless = false,
						stacks = stacksOverride
					})
				end
			end
		end
	end
end

do
	local rangeCheck, rangeObject

	function mod:CheckRange(object, range)
		for unit in mod:IterateGroup() do
			if not UnitIsUnit(unit, "player") and not UnitIsDead(unit) and self:Range(unit) <= range then
				object:SetColor(1, 0.2, 0.2)
				return
			end
		end
		object:SetColor(0.2, 1, 0.2)
	end

	function mod:LingeringInfection(args)
		lingeringInfectionList[args.destName] = args.amount or 1
		self:SetInfoByTable(args.spellId, lingeringInfectionList)
		self:ShowAura(args.spellId, "Infection", { pin = -1, pulse = false, stacks = args.amount or 1, countdown = false })


		if self:Me(args.destGUID) then
			infectionCount = infectionCount + 1
			if infectionCount >= 6 and not rangeObject and self:Hud(args.spellId) then
				rangeObject = Hud:DrawSpinner("player", 60)
				rangeCheck = self:ScheduleRepeatingTimer("CheckRange", 0.2, rangeObject, 5)
				self:CheckRange(rangeObject, 5)
			end
		end
	end
end

function mod:EvolvingAffliction(args)
	if nextLiquify > GetTime() + 8.5 then
		self:Bar(args.spellId, 8.5)
	end
end

function mod:EvolvingAfflictionApplied(args)
	self:StackMessage(args.spellId, args.destName, args.amount, "purple")
	self:PlaySound(args.spellId, "alert", args.destName)
end

function mod:Contagion(args)
	self:Message(args.spellId, "orange", nil, CL.count:format(args.spellName, contagionCount))
	self:PlaySound(args.spellId, "alarm")
	contagionCount = contagionCount + 1
	local timer = 23.1
	if nextLiquify > GetTime() + timer then
		self:Bar(args.spellId, timer, CL.count:format(args.spellName, contagionCount))
	end
end

function mod:Gestate(args)
	local timer = 25
	gestateCount = gestateCount + 1
	if nextLiquify > GetTime() + timer then
		self:CDBar(265212, timer)
	end
	if self:Me(args.destGUID) then
		self:PlaySound(265212, "alert")
		self:Say(265212)
	end
	self:TargetMessage2(265212, "orange", args.destName)
	self:PrimaryIcon(265212, args.destName)
	immunosuppressionCount = 1
	self:CDBar(265206, 6, CL.count:format(self:SpellName(265206), immunosuppressionCount)) -- Immunosuppression
end

function mod:GestateApplied(args)
	if self:Me(args.destGUID) then
		self:SayCountdown(args.spellId, 5)
		self:ShowDebuffAura(args.spellId)
	end
end

function mod:GestateRemoved(args)
	if self:Me(args.destGUID) then
		self:CancelSayCountdown(args.spellId)
		self:HideAura(args.spellId)
	end
	self:PrimaryIcon(args.spellId)
end

do
	local function barLabel()
		return "Immunosupression (Add #" .. gestateCount .. ")"
	end

	function mod:Immunosuppression(args)
		self:Message(args.spellId, "orange", nil, CL.count:format(args.spellName, immunosuppressionCount))
		self:PlaySound(args.spellId, "alarm")
		immunosuppressionCount = immunosuppressionCount + 1
		self:Bar(args.spellId, 9.7, CL.count:format(args.spellName, immunosuppressionCount))
		self:ImpactBar(args.spellId, 3, barLabel())
	end

	function mod:PlagueAmalgamDeath(args)
		self:StopBar(CL.count:format(self:SpellName(265206), contagionCount))
		self:StopBar(barLabel())
	end
end

function mod:Liquefy(args)
	self:Message(args.spellId, "cyan", nil, CL.intermission)
	self:PlaySound(args.spellId, "long")
	self:CastBar(args.spellId, 33)

	self:StopBar(265209) -- Gestate
	self:StopBar(CL.count:format(self:SpellName(267242), contagionCount)) -- Contagion
	self:StopBar(265178) -- Evolving Affliction

	pathogenBombCount = 1
	self:Bar(266459, 13.5) -- Plague Bomb

	liquified = true
end

function mod:LiquefyRemoved(args)
	self:Message(args.spellId, "cyan", nil, CL.over:format(CL.intermission))
	self:PlaySound(args.spellId, "info")

	self:Bar(265178, 5.5) -- Evolving Affliction
	self:Bar(267242, 15.5) -- Contagion
	self:Bar(265212, 19) -- Gestate

	nextLiquify = GetTime() + 93
	self:Bar(args.spellId, 93)

	liquified = false
end

function mod:PlagueBomb(args)
	self:Message(args.spellId, "red")
	self:PlaySound(args.spellId, "warning")
	pathogenBombCount = pathogenBombCount + 1
	if pathogenBombCount < 3 then
		self:Bar(args.spellId, 12.2)
	end
	if self:Hud(args.spellId) then
		local spinner = Hud:DrawSpinner("player", 50, 8):SetColor(0.5, 1, 0.5)
		function spinner:OnDone()
			spinner:Remove()
		end
	end
end
