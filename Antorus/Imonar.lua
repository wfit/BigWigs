--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Imonar the Soulhunter", nil, 2009, 1712)
if not mod then return end
mod:RegisterEnableMob(124158)
mod.engageId = 2082
mod.respawnTime = 30

--------------------------------------------------------------------------------
-- Locals
--

local Hud = Oken.Hud

local stage = 1
local inIntermission = false
local empoweredSchrapnelBlastCount = 1
local nextIntermissionWarning = 0
local canisterProxList = {}

local canisterRole
local canisterHUD
local canisterActive
local canisterTimer
local canisterInFlight
local canisterOnMe

local timersHeroic = {
	--[[ Empowered Shrapnel Blast ]]--
	[248070] = {15.3, 22, 19.5, 18, 16, 16, 13.5, 10, 9.5}, -- XXX Need more data to confirm
}
local timersMythic = {
	--[[ Empowered Shrapnel Blast ]]--
	[248070] = {15.7, 15.7, 15.7, 14.5, 14.5, 12.2, 12.2, 9.7, 9.7}, -- XXX Need more data to confirm
}
local timers = mod:Mythic() and timersMythic or timersHeroic

--------------------------------------------------------------------------------
-- Initialization
--

local canisterMarker = mod:AddMarkerOption(true, "player", 3, 254244, 3, 4)
function mod:GetOptions()
	return {
		"stages",
		"berserk",

		--[[ Stage One: Attack Force ]]--
		{247367, "TANK"}, -- Shock Lance
		{254244, "SAY", "FLASH", "PROXIMITY", "AURA", "SMARTCOLOR", "HUD"}, -- Sleep Canister
		canisterMarker,
		247376, -- Pulse Grenade

		--[[ Stage Two: Contract to Kill ]]--
		{247687, "TANK"}, -- Sever
		248254, -- Charged Blasts
		247923, -- Shrapnel Blast

		--[[ Stage Three: The Perfect Weapon ]]--
		{250255, "TANK"}, -- Empowered Shock Lance
		{248068, "AURA", "SAY", "FLASH"}, -- Empowered Pulse Grenade
		248070, -- Empowered Shrapnel Blast

		--[[ Intermission: On Deadly Ground ]]--
		253302, -- Conflagration

	},{
		["stages"] = "general",
		[247367] = -16577, -- Stage One: Attack Force
		[247687] = -16206, -- Stage Two: Contract to Kill
		[250255] = -16208, -- Stage Three: The Perfect Weapon
		[253302] = -16205, -- Intermission: On Deadly Ground
	}
end

function mod:OnBossEnable()
	self:RegisterEvent("RAID_BOSS_WHISPER")
	self:RegisterMessage("BigWigs_BossComm") -- Syncing the Sleep Canisters
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1")
	self:Log("SPELL_AURA_REMOVED", "IntermissionOver", 248233, 250135) -- Conflagration: Intermission 1, Intermission 2

	--[[ Stage One: Attack Force ]]--
	self:Log("SPELL_AURA_APPLIED", "ShockLance", 247367)
	self:Log("SPELL_AURA_APPLIED_DOSE", "ShockLance", 247367)
	self:Log("SPELL_CAST_SUCCESS", "ShockLanceSuccess", 247367)
	self:Log("SPELL_CAST_SUCCESS", "SleepCanister", 254244)
	self:Log("SPELL_AURA_APPLIED", "SleepCanisterApplied", 255029)
	self:Log("SPELL_AURA_REMOVED", "SleepCanisterRemoved", 255029)
	self:Log("SPELL_MISSED", "SleepCanisterRemoved", 255029)
	self:Log("SPELL_CAST_START", "PulseGrenade", 247376)

	--[[ Stage Two: Contract to Kill ]]--
	self:Log("SPELL_AURA_APPLIED", "Sever", 247687)
	self:Log("SPELL_AURA_APPLIED_DOSE", "Sever", 247687)
	self:Log("SPELL_CAST_SUCCESS", "SeverSuccess", 247687)
	self:Log("SPELL_CAST_SUCCESS", "ChargedBlasts", 248254)
	self:Log("SPELL_CAST_START", "ShrapnelBlast", 247923)

	--[[ Stage Three: The Perfect Weapon ]]--
	self:Log("SPELL_AURA_APPLIED", "EmpoweredShockLance", 250255)
	self:Log("SPELL_AURA_APPLIED_DOSE", "EmpoweredShockLance", 250255)
	self:Log("SPELL_CAST_SUCCESS", "EmpoweredShockLanceSuccess", 250255)
	self:Log("SPELL_CAST_START", "EmpoweredPulseGrenade", 248068)
	self:Log("SPELL_AURA_APPLIED", "EmpoweredPulseGrenadeApplied", 250006)
	self:Log("SPELL_CAST_REMOVED", "EmpoweredPulseGrenadeRemoved", 250006)
	self:Log("SPELL_CAST_START", "EmpoweredShrapnelBlast", 248070)

	--[[ Intermission: On Deadly Ground ]]--
end

function mod:OnEngage()
	timers = self:Mythic() and timersMythic or timersHeroic
	stage = 1
	inIntermission = false
	wipe(canisterProxList)

	self:CDBar(247367, self:Mythic() and 4.8 or 4.5) -- Shock Lance
	self:CDBar(254244, self:Mythic() and 7.2 or 7.3) -- Sleep Canister
	if self:Mythic() then
		self:CDBar(248068, 13.4) -- Empowered Pulse Grenade
		self:Berserk(480)
	else
		self:CDBar(247376, 12.2) -- Pulse Grenade
	end
	nextIntermissionWarning = self:Mythic() and 83 or 69
	self:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", nil, "boss1")

	self:InitSleepCanisterHUD()
end

function mod:OnBossDisable()
	if canisterTimer then
		self:CancelTimer(canisterTimer)
	end
	if canisterHUD then
		canisterHUD:Remove()
		canisterHUD = nil
	end
end

function mod:InitSleepCanisterHUD()
	if not self:Hud(254244) then return end
	canisterRole = self:Melee() and "melee" or "ranged"
	canisterActive = false
	canisterHUD = Hud:DrawSpinner("player", 50)
	canisterHUD:SetColor(0, 0, 0, 0)
	function canisterHUD:OnRemove()
		canisterHUD = nil
	end
	canisterInFlight = false
	canisterOnMe = false
	self:UpdateSleepCanisterHUD()
end

do
	local since = 0
	local status, lastStatus = 0, 0 -- 0 -> Invisible; 1 -> Green; 2 -> Red

	function mod:UpdateSleepCanisterHUD()
		if not self:Hud(254244) then return end
		local now = GetTime()
		if not inIntermission and ((self:Mythic() and stage ~= 2) or (not self:Mythic() and stage == 1)) then
			-- Invisible if ok since more than 2 sec, green otherwise
			status = (now - since > 2) and 0 or 1
			canisterActive = true
			if canisterRole == "ranged" and stage >= 3 then
				for unit in mod:IterateGroup() do
					if not UnitIsUnit(unit, "player") and not UnitIsDead(unit) and mod:Range(unit) <= 10 then
						status = 2
						break
					end
				end
			elseif canisterInFlight and canisterOnMe then
				for unit in mod:IterateGroup() do
					if not UnitIsUnit(unit, "player") and not UnitIsDead(unit) and mod:Range(unit) <= 10 then
						status = 2
						break
					end
				end
			elseif not canisterInFlight and not canisterOnMe and #canisterProxList > 0 then
				for _, unit in ipairs(canisterProxList) do
					if not UnitIsUnit(unit, "player") and mod:Range(unit) <= 10 then
						status = 2
						break
					end
				end
			else
				canisterActive = false
			end
		else
			canisterActive = false -- No canister during this phase
		end

		-- HUD activation state
		if canisterActive then
			if not not canisterTimer then
				canisterTimer = self:ScheduleRepeatingTimer("UpdateSleepCanisterHUD", 0.2)
			end
		else
			status = 0
			if canisterTimer then
				self:CancelTimer(canisterTimer)
			end
		end

		-- HUD visibility and color
		if status ~= lastStatus then
			lastStatus = status
			if status == 0 then
				canisterHUD:SetColor(0, 0, 0, 0) -- Invisibe
			elseif status == 1 then
				canisterHUD:SetColor(0.2, 1.0, 0.2, 1) -- Green
			elseif status == 2 then
				canisterHUD:SetColor(1.0, 0.2, 0.2, 1) -- Red
				since = now
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:UNIT_HEALTH_FREQUENT(unit)
	local hp = UnitHealth(unit) / UnitHealthMax(unit) * 100
	if hp < nextIntermissionWarning then
		self:Message("stages", "Positive", nil, CL.soon:format(CL.intermission), false)
		nextIntermissionWarning = nextIntermissionWarning - (self:Mythic() and 20 or 33)
		if nextIntermissionWarning < 20 then
			self:UnregisterUnitEvent("UNIT_HEALTH_FREQUENT", unit)
		end
	end
end

do
	local playerList, isOnMe, scheduled = mod:NewTargetList(), nil, nil
	local canisterMarks = {false, false}

	local rangeCheck
	local lastStatus = -1

	function mod:CheckSleepRange(spellId)
		local status = 1
		for unit in mod:IterateGroup() do
			if not UnitIsUnit(unit, "player") and not UnitIsDead(unit) and mod:Range(unit) <= 10 then
				status = 0
				break
			end
		end
		if status ~= lastStatus then
			lastStatus = status
			if status == 0 then
				-- Cannot be dispelled
				self:SmartColorSet(spellId, 1, 0.5, 0)
			elseif status == 1 then
				-- Can be dispelled
				self:SmartColorSet(spellId, 0.2, 1, 0.2)
			end
		end
	end

	local function nameToUnit(name)
		for unit in mod:IterateGroup() do
			if UnitIsUnit(name, unit) then
				return unit
			end
		end
		return name
	end

	local function warn(self)
		if not isOnMe then
			self:TargetMessage(254244, playerList, "Important")
		end
		scheduled = nil
	end

	local function addPlayerToList(self, name)
		local unit = nameToUnit(name)
		if not tContains(canisterProxList, unit) then
			canisterProxList[#canisterProxList+1] = unit
			playerList[#playerList+1] = name

			if self:GetOption(canisterMarker) then
				for i = 3, 4 do
					if not canisterMarks[i] then
						canisterMarks[i] = unit
						SetRaidTarget(unit, i)
						break
					end
				end
			end

			if #playerList == (self:Easy() and 1 or 2) then
				if scheduled then
					self:CancelTimer(scheduled)
				end
				warn(self)
			elseif not scheduled then
				scheduled = self:ScheduleTimer(warn, 0.3, self)
			end
		end
		self:OpenProximity(254244, 10, canisterProxList)
	end

	function mod:RAID_BOSS_WHISPER(_, msg)
		if msg:find("254244", nil, true) then -- Sleep Canister
			isOnMe = true
			self:Message(254244, "Personal", "Alarm", CL.you:format(self:SpellName(254244)))
			self:Flash(254244)
			self:Say(254244)
			self:ShowAura(254244, "On YOU", { autoremove = 3 })
			addPlayerToList(self, self:UnitName("player"))
			self:Sync("SleepCanister")
			canisterOnMe = true
			self:UpdateSleepCanisterHUD()
		end
	end

	function mod:BigWigs_BossComm(_, msg, _, name)
		if msg == "SleepCanister" then
			--addPlayerToList(self, name)
		end
	end

	function mod:SleepCanister(args)
		isOnMe = nil
		wipe(playerList)
		canisterMarks = {false, false}
		self:Bar(args.spellId, self:Mythic() and 12.1 or 10.9)
		canisterOnMe = false
		canisterInFlight = true
		self:UpdateSleepCanisterHUD()
	end

	function mod:SleepCanisterApplied(args)
		if self:Me(args.destGUID) then
			self:HideAura(254244)
			lastStatus = -1
			rangeCheck = self:ScheduleRepeatingTimer("CheckSleepRange", 0.1, 254244)
			self:CheckSleepRange(254244)
			canisterOnMe = true
		end
		addPlayerToList(self, args.destName)
		if self:Healer() and #canisterProxList > 0 then
			self:PlaySound(254244, "Alert")
		end
		canisterInFlight = false
		self:UpdateSleepCanisterHUD()
	end

	function mod:SleepCanisterRemoved(args)
		tDeleteItem(canisterProxList, nameToUnit(args.destName))
		if #canisterProxList > 0 then
			self:OpenProximity(254244, 10, canisterProxList)
		end
		if self:Me(args.destGUID) then
			self:HideAura(254244)
			self:CancelTimer(rangeCheck)
			self:SmartColorUnset(254244)
			canisterOnMe = false
		end
		if self:GetOption(canisterMarker) then
			for i = 3, 4 do
				if canisterMarks[i] == self:UnitName(args.destName) then
					canisterMarks[i] = false
					SetRaidTarget(args.destName, 0)
					break
				end
			end
		end
		canisterInFlight = false
		self:UpdateSleepCanisterHUD()
	end
end

function mod:UNIT_SPELLCAST_SUCCEEDED(_, _, _, _, spellId)
	if spellId == 248995 or spellId == 248194 then -- Jetpacks (Intermission 1), Jetpacks (Intermission 2)
		self:Message("stages", "Positive", "Long", CL.intermission, false)
		-- Stage 1 timers
		self:StopBar(247367) -- Shock Lance
		self:StopBar(254244) -- Sleep Canister
		self:StopBar(247376) -- Pulse Grenade
		-- Stage 2 timers
		self:StopBar(247687) -- Sever
		self:StopBar(248254) -- Charged Blast
		self:StopBar(247923) -- Shrapnel Blast
		-- Mythic timers
		self:StopBar(248068) -- Empowered Pulse Grenade
		self:StopBar(248070) -- Empowered Shrapnel Blast

		inIntermission = true
		self:UpdateSleepCanisterHUD()
	end
end


function mod:IntermissionOver()
	stage = stage + 1
	self:Message("stages", "Positive", "Long", CL.stage:format(stage), false)
	if stage == 2 then
		self:CDBar(247687, 7.7) -- Sever
		self:CDBar(248254, 10.6) -- Charged Blast
		self:CDBar(247923, 12.8) -- Shrapnel Blast
	elseif stage == 3 then
		if self:Mythic() then
			self:CDBar(254244, 7.3) -- Sleep Canister
			self:CDBar(248068, 6.8) -- Empowered Pulse Grenade
			self:CDBar(247923, 12.8) -- Shrapnel Blast
		else
			empoweredSchrapnelBlastCount = 1
			self:CDBar(250255, 4.3) -- Empowered Shock Lance
			self:CDBar(248068, 6.8) -- Empowered Pulse Grenade
			self:CDBar(248070, timers[248070][empoweredSchrapnelBlastCount]) -- Empowered Shrapnel Blast
		end
	elseif stage == 4 then -- Mythic only
		empoweredSchrapnelBlastCount = 1
		self:CDBar(254244, 7.3) -- Sleep Canister
		self:CDBar(248070, 15) -- Empowered Shrapnel Blast
		self:CDBar(248254, 10.6) -- Charged Blast
	elseif stage == 5 then -- Mythic only
		empoweredSchrapnelBlastCount = 1
		self:CDBar(254244, 7.3) -- Sleep Canister
		self:CDBar(250255, 4.3) -- Empowered Shock Lance
		self:CDBar(248068, 6.8) -- Empowered Pulse Grenade
		self:CDBar(248070, timers[248070][empoweredSchrapnelBlastCount]) -- Empowered Shrapnel Blast
	end
	inIntermission = false
	self:UpdateSleepCanisterHUD()
end

--[[ Stage One: Attack Force ]]--
function mod:ShockLance(args)
	local amount = args.amount or 1
	self:StackMessage(args.spellId, args.destName, amount, "Important", amount > 6 and "Warning" or amount > 4 and "Alarm") -- Swap on 5, increase warning at 7
end

function mod:ShockLanceSuccess(args)
	self:Bar(args.spellId, 4.9)
end

function mod:PulseGrenade(args)
	self:Message(args.spellId, "Attention", "Alert")
	self:Bar(args.spellId, 17.0)
end

--[[ Stage Two: Contract to Kill ]]--
function mod:Sever(args)
	local amount = args.amount or 1
	self:StackMessage(args.spellId, args.destName, amount, "Important", amount > 3 and "Warning" or amount > 1 and "Alarm") -- Swap on 2
end

function mod:SeverSuccess(args)
	self:Bar(args.spellId, 7.3)
end

function mod:ChargedBlasts(args)
	self:Message(args.spellId, "Urgent", "Warning", CL.incoming:format(args.spellName))
	self:CastBar(args.spellId, 8.6)
	self:Bar(args.spellId, self:Mythic() and (stage == 2 and 14.5 or 18.2) or 18.2)
end

function mod:ShrapnelBlast(args)
	self:Message(args.spellId, "Attention", "Alert")
	self:Bar(args.spellId, self:Mythic() and (stage == 2 and 17 or 14.6) or 13.4)
end

--[[ Stage Three: The Perfect Weapon ]]--
function mod:EmpoweredShockLance(args)
	local amount = args.amount or 1
	self:StackMessage(args.spellId, args.destName, amount, "Important", amount % 2 == 0 and "Alarm")
end

function mod:EmpoweredShockLanceSuccess(args)
	self:Bar(args.spellId, self:Mythic() and 6 or 9.7)
end

function mod:EmpoweredPulseGrenade(args)
	self:Message(args.spellId, "Attention", "Alert")
	self:Bar(args.spellId, stage == 5 and 13.3 or 26.7) -- Stage 5 mythic only
end

function mod:EmpoweredPulseGrenadeApplied(args)
	if self:Me(args.destGUID) then
		self:Message(248068, "Personal", "Alarm", CL.you:format(self:SpellName(248068)))
		self:Flash(248068)
		self:Say(248068)
		self:ShowAura(248068, "Spread", 75, true)
	end
end

function mod:EmpoweredPulseGrenadeRemoved(args)
	if self:Me(args.destGUID) then
		self:HideAura(248068)
	end
end

function mod:EmpoweredShrapnelBlast(args)
	self:Message(args.spellId, "Urgent", "Warning")
	empoweredSchrapnelBlastCount = empoweredSchrapnelBlastCount + 1
	self:CDBar(args.spellId, stage == 4 and 26.8 or timers[args.spellId][empoweredSchrapnelBlastCount])
end
