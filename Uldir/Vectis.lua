if not C_ChatInfo then return end -- XXX Don't load outside of 8.0

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

local pathogenBombCount = 1
local nextLiquify = 0
local liquified = false

--------------------------------------------------------------------------------
-- Initialization
--

local omegaVectorMarker = mod:AddMarkerOption(true, "player", 1, 265129, 1, 2, 3, 4)
--local omegaVectorRL = mod:AddTokenOption { "omega_rl", "Automatically raid lead Omega Vector soaking.", promote = true }
function mod:GetOptions()
	return {
		{265178, "TANK"}, -- Evolving Affliction
		{265129, "SAY", "AURA"}, -- Omega Vector
		omegaVectorMarker,
		--omegaVectorRL,
		{265127, "AURA"}, -- Lingering Infection

		267242, -- Contagion
		{265212, "SAY", "ICON", "AURA"}, -- Gestate
		265217, -- Liquefy
		266459, -- Pathogen Bomb
	}
end

function mod:OnBossEnable()
	self:Log("SPELL_CAST_SUCCESS", "EvolvingAffliction", 265178)
	self:Log("SPELL_AURA_APPLIED", "EvolvingAfflictionApplied", 265178)
	self:Log("SPELL_AURA_APPLIED_DOSE", "EvolvingAfflictionApplied", 265178)
	self:Log("SPELL_AURA_APPLIED", "OmegaVectorApplied", 265129)
	self:Log("SPELL_AURA_REMOVED", "OmegaVectorRemoved", 265129)
	self:Log("SPELL_AURA_APPLIED", "LingeringInfectionApplied", 265127)
	self:Log("SPELL_AURA_APPLIED_DOSE", "LingeringInfectionApplied", 265127)
	self:Log("SPELL_CAST_START", "Contagion", 267242)
	self:Log("SPELL_CAST_START", "Gestate", 265209)
	self:Log("SPELL_AURA_APPLIED", "GestateApplied", 265212)
	self:Log("SPELL_AURA_REMOVED", "GestateRemoved", 265212)
	self:Log("SPELL_CAST_START", "Liquefy", 265217)
	self:Log("SPELL_AURA_REMOVED", "LiquefyRemoved", 265217)
	self:Log("SPELL_CAST_SUCCESS", "PathogenBomb", 266459)
end

function mod:OnEngage()
	self:Bar(267242, self:Easy() and 20.5 or 11.5) -- Contagion
	self:Bar(265212, self:Easy() and 10.5 or 14.5) -- Gestate

	nextLiquify = GetTime() + 90
	self:Bar(265217, 90) -- Liquefy

	liquified = false
	self:OmegaVectorReset()
	self:RegisterEvent("UNIT_AURA") -- XXX Blizzard does not emit SPELL_AURA_APPLIED/REMOVED for multiple stacks
end

--------------------------------------------------------------------------------
-- Omega Vector
--

do
	local vectorKeys = { "vector_1", "vector_2", "vector_3", "vector_4" }
	local soakerKeys = { "soaker_1", "soaker_2", "soaker_3", "soaker_4" }

	local airborne = {}
	local roster = { tank = {}, melee = {}, ranged = {}, healer = {}, index = {}, role = {} }
	local playerUnit
	local vectors = {} -- [1-4] indexes points to the player having the vector, [units] indexes is a list of vectors for the unit
	local stacks = {}
	local soakers = {} -- [1-4] indexes points to the player soaking, [units] indexes point to the soaked vector for unit
	local pending = {} -- Vectors not yet attributed

	local function trace(color, str, ...)
		print(format("|cff" .. color .. str, ...))
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
			trace("ffffff", "|T%d:16:16:0:0|t %s %s%s [%s]", 137000 + vector, UnitName(unit), arrow, str)

			-- Display soaker name to player
			if unit == playerUnit then
				if toTanks then
					mod:ShowAura(spellId, "TANKS", { key = vectorKeys[vector], pulse = true, icon = "inv_shield_06" })
				else
					mod:ShowAura(spellId, UnitName(soaker), { key = vectorKeys[vector], pulse = false })
				end
			end

			-- Display unit name to soaker
			if not toTanks and soaker == playerUnit then
				local icon = vectors[unit][1]
				mod:ShowAura(spellId, UnitName(unit), expires - GetTime(), {
					key = soakerKeys[vector],
					countdown = icon == vector,
					icon = icon,
					borderless = false,
					stacks = icon ~= vector and "{rt" .. vector .. "}" or nil
				})
				if liquified then
					-- TODO: spam soaked name
				end
			end
		end
	end

	function mod:OmegaVectorApplied(args)
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
				self:ShowAura(args.spellId, 10, "...", {
					key = vectorKeys[vector],
					countdown = false,
					stacks = "{rt" .. vector .. "}"
				})
			end
		end

		-- Only perform soaker attribution if no vectors are airborne
		if #airborne < 1 then performAttribution(args.spellId) end
	end

	function mod:OmegaVectorRemoved(args)
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
				self:HideAura(vectorKeys[vector])
			end
		end

		-- Update aura for soaker
		if soakers[vector] == playerUnit then
			-- I'm the soaker for this vector, just remove it
			self:HideAura(soakerKeys[vector])
		else
			local soakedVector = soakers[playerUnit]
			if vectors[soakedVector] == unit then
				-- This is the unit having the vector I'm supposed to soak, update my aura
				local stacksOverride
				if vectors[unit][1] == soakedVector then stacksOverride = false end
				-- Update icon and stacks parts
				self:ShowAura(args.spellId, {
					key = soakerKeys[soakedVector],
					pulse = false,
					icon = vectors[unit][1],
					borderless = false,
					stacks = stacksOverride
				})
			end
		end
	end

	-- Enmulate SPELL_AURA_APPLIED / SPELL_AURA_REMOVED for multiple vectors on one target
	local select, UnitDebuff = select, UnitDebuff
	local fakeArgs = { spellId = 265129 }
	function mod:UNIT_AURA(_, unit)
		if not roster.index[unit] then return end
		local count = 0
		for i = 1, 40 do
			local spellId = select(10, UnitDebuff(unit, i))
			if not spellId then
				break
			elseif spellId == 265129 then
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
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:EvolvingAffliction(args)
	if nextLiquify > GetTime() + 8.5 then
		self:Bar(args.spellId, 8.5)
	end
end

function mod:EvolvingAfflictionApplied(args)
	self:StackMessage(args.spellId, args.destName, args.amount, "red")
	self:PlaySound(args.spellId, "alert", args.destName)
end

function mod:LingeringInfectionApplied(args)
	if self:Me(args.destGUID) then
		self:ShowAura(args.spellId, "Infection", { pin = -1, pulse = false, stacks = args.amount or 1 })
	end
end

function mod:Contagion(args)
	self:Message(args.spellId, "orange")
	self:PlaySound(args.spellId, "alarm")
	local timer = self:Easy() and 23.1 or 13.5
	if nextLiquify > GetTime() + timer then
		self:Bar(args.spellId, timer)
	end
end

do
	local targetFound = false
	local function printTarget(self, name, guid)
		if not self:Tank(name) then
			targetFound = true
			if self:Me(guid) then
				self:PlaySound(265212, "alert", nil, name)
				self:Say(265212)
			end
			self:TargetMessage2(265212, "orange", name)
			self:PrimaryIcon(265212, name)
		end
	end

	function mod:Gestate(args)
		targetFound = false
		self:GetBossTarget(printTarget, 0.5, args.sourceGUID)
		local timer = self:Easy() and 25 or 30
		if nextLiquify > GetTime() + timer then
			self:CDBar(265212, timer)
		end
	end

	function mod:GestateApplied(args)
		if not targetFound then
			if self:Me(args.destGUID) then
				self:PlaySound(args.spellId, "alert")
				self:Say(args.spellId)
				self:SayCountdown(args.spellId, 5)
				self:ShowDebuffAura(args.spellId)
			end
			self:TargetMessage2(args.spellId, "orange", args.destName)
			self:PrimaryIcon(265212, args.destName)
		elseif self:Me(args.destGUID) then
			self:SayCountdown(args.spellId, 5)
		end
	end

	function mod:GestateRemoved(args)
		if self:Me(args.destGUID) then
			self:CancelSayCountdown(args.spellId)
			self:HideAura(args.spellId)
		end
		self:PrimaryIcon(args.spellId)
	end
end

function mod:Liquefy(args)
	self:Message(args.spellId, "cyan", nil, CL.intermission)
	self:PlaySound(args.spellId, "long")
	self:CastBar(args.spellId, 33)

	self:StopBar(265209) -- Gestate
	self:StopBar(267242) -- Contagion
	self:StopBar(265178) -- Evolving Affliction

	pathogenBombCount = 1
	self:Bar(266459, 13.5) -- Pathogen Bomb

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



function mod:PathogenBomb(args)
	self:Message(args.spellId, "red")
	self:PlaySound(args.spellId, "warning")
	pathogenBombCount = pathogenBombCount + 1
	if pathogenBombCount < 3 then
		self:Bar(args.spellId, 12.2)
	end
end
