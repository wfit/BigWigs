
--------------------------------------------------------------------------------
-- TODO List:
-- - Respawn timer
-- - Mod is untested and PTR logs were old, probably needs a lot of updates

--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Grand Magistrix Elisande", 1088, 1743)
if not mod then return end
mod:RegisterEnableMob(106643)
mod.engageId = 1872
mod.instanceId = 1530
mod.respawnTime = 30

--------------------------------------------------------------------------------
-- Locals
--

local phase = 1

local timersHeroic = {
	-- Spanning Singularity, UNIT_SPELLCAST_SUCCEEDED
	[209168] = { 25.0, 36.0, 57.0, 65.0 },
	-- Arcanetic Ring, RAID_BOSS_EMOTE
	[208807] = { 34.0, 41.0, 10.0, 62.0, 10.0, 45.0, 10.0 },
	-- Epocheric Orb, RAID_BOSS_EMOTE
	[210022] = { 27.0, 76.0, 37.0, 70.0 },
	-- Delphuric Beam, SPELL_CAST_START
	[209244] = { 72.0, 57.0, 60.0 },
	-- Conflexive Burst,
	[209597] = { 58, 52.0, 56.0, 65.0 },
	-- Summon Time Elemental - Slow, UNIT_SPELLCAST_SUCCEEDED
	[209005] = { 5.0, 49.0, 52.0, 60.0 },
	-- Summon Time Elemental - Fast, UNIT_SPELLCAST_SUCCEEDED
	[211616] = { 8.0, 88.0, 95.0, 20.0 },
}
local timersMythic = {
	-- Spanning Singularity, UNIT_SPELLCAST_SUCCEEDED
	[209168] = { 56.8, 50.0, 45.0 },
	-- Arcanetic Ring, RAID_BOSS_EMOTE
	[208807] = { 32, 40, 15, 30, 20, 10, 25, 10, 10, 13 },
	-- Epocheric Orb, RAID_BOSS_EMOTE
	[210022] = { 14.5, 85 },
	-- Delphuric Beam, SPELL_CAST_START
	[209244] = { 54.0, 50 },
	-- Conflexive Burst,
	[209597] = { },
	-- Summon Time Elemental - Slow, UNIT_SPELLCAST_SUCCEEDED
	[209005] = {
		[1] = { 5, 39, 75 },
		[2] = { 5, 39, 45, 30, },
	},
	-- Summon Time Elemental - Fast, UNIT_SPELLCAST_SUCCEEDED
	[211616] =  {
		[1] = { 8, 81, },
		[2] = { 8, 51, },
	}
}
local timers = mod:Mythic() and timersMythic or timersHeroic

local singularityCount = 1
local singularityMax = 0
local ringCount = 1
local ringMax = 0
local orbsCount = 1
local orbsMax = 0
local beamsCount = 1
local beamsMax = 0
local burstsCount = 1

local slowAddCount = 1
local fastAddCount = 1

local elementalsAlive = {}
local slowZoneCount = 0
local fastZoneCount = 0

local timeStopped = false

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then
	L.echo = "Echo: %s"
	L.echoOption = "%s (Bar Only)"
	L.fastAdd = "Add Fast"
	L.slowAdd = "Add Slow"
	L.slowZoneDespawn = "Slow Zone Despawn"
	L.fastZoneDespawn = "Fast Zone Despawn"
end

local echo = setmetatable({}, {
	__index = function(self, key)
		local name = L.echo:format(mod:SpellName(key))
		self[key] = name
		return name
	end
})

--------------------------------------------------------------------------------
-- Initialization
--

local slow_zone_despawn = mod:AddCustomOption { "szd", L.slowZoneDespawn, icon = 207013, configurable = true }
local fast_zone_despawn = mod:AddCustomOption { "fzd", L.fastZoneDespawn, icon = 207011, configurable = true }

local function echoCustomOption(key, spellId)
	return mod:AddCustomOption { key, L.echoOption:format(echo[spellId]), icon = spellId, configurable = true }
end

local spanning_echo = echoCustomOption("spanning_echo", 209168)
local ring_echo = echoCustomOption("ring_echo", 208807)
local orbs_echo = echoCustomOption("orbs_echo", 210022)
local beams_echo = echoCustomOption("beams_echo", 209244)

function mod:GetOptions()
	return {
		--[[ General ]]--
		"stages",
		"berserk",
		208887, -- Summon Time Elementals

		--[[ Recursive Elemental ]]--
		221863, -- Shield
		221864, -- Blast
		209165, -- Slow Time
		slow_zone_despawn,

		--[[ Expedient Elemental ]]--
		--209568, -- Exothermic Release
		209166, -- Fast Time
		fast_zone_despawn,

		--[[ Time Layer 1 ]]--
		208807, -- Arcanetic Ring
		ring_echo,
		209168, -- Spanning Singularity
		spanning_echo,

		--[[ Time Layer 2 ]]--
		{209244, "SAY", "FLASH"}, -- Delphuric Beam
		beams_echo,
		210022, -- Epocheric Orb
		orbs_echo,
		209973, -- Ablating Explosion

		--[[ Time Layer 3 ]]--
		{211261, "FLASH"}, -- Permeliative Torment
		{209597, "SAY", "FLASH"}, -- Conflexive Burst
		209971, -- Ablative Pulse
		{211887, "TANK"}, -- Ablated
	},{
		[208887] = "general",
		[221863] = -13226, -- Recursive Elemental
		[209568] = -13229, -- Expedient Elemental
		[208807] = -13222, -- Time Layer 1
		[209244] = -13235, -- Time Layer 2
		[211261] = -13232, -- Time Layer 3
	}
end

function mod:OnBossEnable()
	print("ENCOUNTER_START phase : " .. phase )
	--[[ General ]]--
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1")
	self:Log("SPELL_CAST_SUCCESS", "Nightwell", 208863)
	self:RegisterEvent("RAID_BOSS_EMOTE")

	--[[ Recursive Elemental ]]--
	self:Log("SPELL_AURA_APPLIED", "ShieldApplied", 221863)
	self:Log("SPELL_AURA_REMOVED", "ShieldRemoved", 221863)
	self:Log("SPELL_CAST_START", "Blast", 221864)
	self:Log("SPELL_AURA_APPLIED", "SlowTime", 209165)

	--[[ Expedient Elemental ]]--
	--self:Log("SPELL_CAST_START", "ExothermicRelease", 209568)
	self:Log("SPELL_AURA_APPLIED", "FastTime", 209166)

	--[[ Time Layer 1 ]]--
	--self:Log("SPELL_CAST_START", "ArcaneticRing", 208807)
	--self:Log("SPELL_CAST_SUCCESS", "SpanningSingularity", 209170, 233011, 233012)
	--self:Log("SPELL_AURA_APPLIED", "SingularityDamage", 209433)
	--self:Log("SPELL_PERIODIC_DAMAGE", "SingularityDamage", 209433)
	--self:Log("SPELL_PERIODIC_MISSED", "SingularityDamage", 209433)

	--[[ Time Layer 2 ]]--
	self:Log("SPELL_CAST_START", "DelphuricBeam", 214278, 214295) -- Boss: 214278, Echo: 214295
	self:Log("SPELL_AURA_APPLIED", "DelphuricBeamApplied", 209244)
	--self:Log("SPELL_CAST_SUCCESS", "EpochericOrb", 210022)
	self:Log("SPELL_AURA_APPLIED", "AblatingExplosion", 209973)

	--[[ Time Layer 3 ]]--
	self:Log("SPELL_AURA_APPLIED", "PermeliativeTorment", 211261)
	self:Log("SPELL_CAST_SUCCESS", "ConflexiveBurst", 209597)
	self:Log("SPELL_AURA_APPLIED", "ConflexiveBurstApplied", 209598)
	self:Log("SPELL_CAST_START", "AblativePulse", 209971)
	self:Log("SPELL_AURA_APPLIED", "Ablated", 211887)
	self:Log("SPELL_AURA_APPLIED_DOSE", "Ablated", 211887)
end

function mod:OnEngage()
	phase = 1
	timers = self:Mythic() and timersMythic or timersHeroic
	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	print("ENCOUNTER_START phase : " .. phase )
end

function mod:OnDisable()
	print("ENCOUNTER_END phase : " .. phase )
	phase = 1
end

function mod:ElementalBar(spellId, name, count)
	local time
	if self:Mythic() and timers[spellId][phase] then
		time = timers[spellId][phase][count]
	elseif not self:Mythic() then
		time = timers[spellId][count]
	end
	if time then
		self:Bar(208887, time, CL.count:format(name, count))
	end
end

function mod:EchoBar(basePhase, spellId, echoKey, count)
	if timers[spellId][count] then
		local key = phase == basePhase and spellId or echoKey
		local time = timers[spellId][count]
		local text = CL.count:format(phase == basePhase and self:SpellName(spellId) or echo[spellId], count)
		self:Bar(key, time, text, spellId)
	end
end

function mod:StopEchoBar(spellId, count)
	self:StopBar(CL.count:format(self:SpellName(spellId), count))
	self:StopBar(CL.count:format(echo[spellId], count))
end

--------------------------------------------------------------------------------
-- Event Handlers
--

--[[ General ]]--
do
	local prevSingularity = 0
	function mod:UNIT_SPELLCAST_SUCCEEDED(unit, spellName, _, _, spellId)
		if spellId == 211616 then -- Summon Time Elemental - Fast
			self:StopBar(CL.count:format(L.fastAdd, fastAddCount))
			self:Message(208887, "Neutral", "Info", CL.count:format(L.fastAdd, fastAddCount))
			fastAddCount = fastAddCount + 1
			--print("Fast " .. timersMythic[211616][phase][fastAddCount] or "FUCK" )
			self:ElementalBar(211616, L.fastAdd, fastAddCount)
		elseif spellId == 209005 then -- Summon Time Elemental - Slow
			self:StopBar(CL.count:format(L.slowAdd, slowAddCount))
			self:Message(208887, "Neutral", "Info", CL.count:format(L.slowAdd, slowAddCount))
			slowAddCount = slowAddCount + 1
			--print("Slow " .. timersMythic[209005][phase][slowAddCount] or "FUCK" )
			self:ElementalBar(209005, L.slowAdd, slowAddCount)
		elseif spellId == 211647 then  -- Time Stop
			self:TimeStop()
		elseif spellId == 209168 or spellId == 233012 or spellId == 233011 and GetTime() - prevSingularity > 1 then -- Spanning Singularity
			prevSingularity = GetTime()
			self:SpanningSingularity()
		end
	end
end

function mod:Nightwell(args)
	print("Nightwell " .. phase )
	singularityCount = phase == 1 and 1 or 0
	ringCount = 1
	orbsCount = 1
	beamsCount = 1
	burstsCount = 1
	slowAddCount = 1
	fastAddCount = 1
	timeStopped = false

	wipe(elementalsAlive)
	slowZoneCount = 0
	fastZoneCount = 0

	if singularityCount > 0 then
		self:EchoBar(1, 209168, spanning_echo, singularityCount)
	end
	self:EchoBar(1, 208807, ring_echo, ringCount)
	self:ElementalBar(209005, L.slowAdd, slowAddCount)
	self:ElementalBar(211616, L.fastAdd, fastAddCount)
	if phase >= 2 then
		self:EchoBar(2, 210022, orbs_echo, orbsCount)
	end
	if phase == 2 or (phase == 3 and self:Mythic()) then
		self:EchoBar(2, 209244, beams_echo, beamsCount)
	end
	if phase == 3 then
		self:Bar(209597, timers[209597][burstsCount], CL.count:format(self:SpellName(209597), burstsCount))
	end
	if self:Mythic() then
		self:Bar("berserk", 199, 26662)
	end
end

function mod:TimeStop()
	timeStopped = true
	self:StopEchoBar(209168, singularityCount)
	self:StopEchoBar(208807, ringCount)
	self:StopEchoBar(210022, orbsCount)
	self:StopEchoBar(209244, beamsCount)
	self:StopBar(CL.count:format(L.fastAdd, fastAddCount))
	self:StopBar(CL.count:format(L.slowAdd, slowAddCount))
	self:StopBar(CL.count:format(L.slowZoneDespawn, slowZoneCount))
	self:StopBar(CL.count:format(L.slowZoneDespawn, slowZoneCount - 1))
	self:StopBar(CL.count:format(L.fastZoneDespawn, fastZoneCount))
	if self:Mythic() then
		self:StopBar(26662) -- Berserk
	end
	if phase == 1 then
		singularityMax = singularityCount
		ringMax = ringCount
	elseif phase == 2 then
		orbsMax = orbsCount
		beamsMax = beamsCount
	end
	phase = phase + 1
	self:Message("stages", "Neutral", "Info", CL.phase:format(phase), false)
	self:Bar("stages", 10, CL.stage:format(phase), 211647)
end

do
	local SLOW_ELEMENTAL = 105299
	local FAST_ELEMENTAL = 105301
	local ELISANDE_GUID = 106643
	local elementalsSeen = {}
	local elisandeSeen = ""

	function mod:INSTANCE_ENCOUNTER_ENGAGE_UNIT()
		print("INSTANCE_ENCOUNTER_ENGAGE_UNIT phase : " .. phase )
		if timeStopped then
			wipe(elementalsAlive)
			return
		end

		wipe(elementalsSeen)
		for i = 1, 5 do
			local unit = ("boss%d"):format(i)
			if UnitExists(unit) then
				local guid = UnitGUID(unit)
				local mob = self:MobId(guid)
				if mob == ELISANDE_GUID and guid ~= elisandeSeen then
					elisandeSeen = guid
					phase = 1
					print("RESET : " .. guid)
				end
				if mob == SLOW_ELEMENTAL or mob == FAST_ELEMENTAL then
					elementalsSeen[guid] = true
					elementalsAlive[guid] = mob
				end
			end
		end

		for guid, mob in pairs(elementalsAlive) do
			if not elementalsSeen[guid] then
				elementalsAlive[guid] = nil
				if mob == SLOW_ELEMENTAL then
					slowZoneCount = slowZoneCount + 1
					self:Bar(slow_zone_despawn, 60, CL.count:format(L.slowZoneDespawn, slowZoneCount), 207013)
				elseif mob == FAST_ELEMENTAL then
					fastZoneCount = fastZoneCount + 1
					self:Bar(fast_zone_despawn, 30, CL.count:format(L.fastZoneDespawn, fastZoneCount), 207011)
				end
			end
		end
	end
end

function mod:RAID_BOSS_EMOTE(event, msg, npcname)
	if msg:find("spell:228877") then -- Arcanetic Ring
		self:ArcaneticRing()
	elseif msg:find("spell:210022") then -- Epocheric Orbs
		self:EpochericOrb()
	end
end

--[[ Recursive Elemental ]]--
function mod:ShieldApplied(args)
	self:Message(args.spellId, "Attention", "Info", CL.on:format(args.spellName, args.destName))
end

function mod:ShieldRemoved(args)
	self:Message(args.spellId, "Positive", "Info", CL.removed:format(args.spellName))
end

function mod:Blast(args)
	if self:Interrupter(args.sourceGUID) then
		self:Message(args.spellId, "Important", "Alert")
	end
end

function mod:SlowTime(args)
	if self:Me(args.destGUID)then
		self:TargetMessage(args.spellId, args.destName, "Personal", "Info")
		local _, _, _, _, _, _, expires = UnitDebuff("player", args.spellName)
		local t = expires - GetTime()
		self:TargetBar(args.spellId, t, args.destName)
	end
end

--[[ Expedient Elemental ]]--
function mod:ExothermicRelease(args)
	self:Message(args.spellId, "Attention", "Alarm")
end

function mod:FastTime(args)
	if self:Me(args.destGUID)then
		self:Message(args.spellId, "Positive", "Info", CL.you:format(args.spellName))
		local _, _, _, _, _, _, expires = UnitDebuff("player", args.spellName)
		local t = expires - GetTime()
		self:TargetBar(args.spellId, t, args.destName)
	end
end

--[[ Time Layer 1 ]]--
function mod:ArcaneticRing()
	self:Message(208807, "Urgent", "Alert")
	ringCount = ringCount + 1
	if phase == 1 or ringCount < ringMax then
		self:EchoBar(1, 208807, ring_echo, ringCount)
	end
end

function mod:SpanningSingularity(args)
	self:Message(209168, "Important", "Info")
	singularityCount = singularityCount + 1
	if phase == 1 or singularityCount < singularityMax then
		self:EchoBar(1, 209168, spanning_echo, singularityCount)
	end
end

--[[
do
	local prev = 0
	function mod:SingularityDamage(args)
		local t = GetTime()
		if self:Me(args.destGUID) and t-prev > 1.5 then
			prev = t
			self:Message(209168, "Personal", "Alert", CL.underyou:format(args.spellName))
		end
	end
end
]]

--[[ Time Layer 2 ]]--
function mod:DelphuricBeam(args)
	self:Message(209244, "Urgent", "Alert", CL.incoming:format(self:SpellName(209244)))
	self:Bar(209244, 8, CL.cast:format(self:SpellName(209244)))
	beamsCount = beamsCount + 1
	if phase == 2 or (self:Mythic() and beamsCount < beamsMax) then
		self:EchoBar(2, 209244, beams_echo, beamsCount)
	end
end

do
	local playerList = mod:NewTargetList()
	function mod:DelphuricBeamApplied(args)
		if self:Me(args.destGUID) then
			self:Flash(args.spellId)
			self:Say(args.spellId)
			local _, _, _, _, _, _, expires = UnitDebuff("player", args.spellName)
			local t = expires - GetTime()
			self:TargetBar(args.spellId, t, args.destName)
		end

		playerList[#playerList+1] = args.destName

		if #playerList == 1 then
			self:ScheduleTimer("TargetMessage", 0.3, args.spellId, playerList, "Important", "Alarm")
		end
	end
end

function mod:EpochericOrb()
	self:Message(210022, "Urgent", "Alert", CL.incoming:format(self:SpellName(210022)))
	self:Bar(210022, 9, CL.cast:format(self:SpellName(210022)))
	orbsCount = orbsCount + 1
	if phase == 2 or orbsCount < orbsMax then
		self:EchoBar(2, 210022, orbs_echo, orbsCount)
	end
end

function mod:AblatingExplosion(args)
	self:Bar(args.spellId, 20.7)
	self:TargetMessage(args.spellId, args.destName, "Attention", "Long")
	self:TargetBar(args.spellId, 8, args.destName)
	self:ScheduleTimer("Bar", 8, args.spellId, 7)
end

--[[ Time Layer 3 ]]--
do
	local playerList = mod:NewTargetList()
	function mod:PermeliativeTorment(args)
		if self:Me(args.destGUID) then
			self:Flash(args.spellId)
			local _, _, _, _, _, _, expires = UnitDebuff("player", args.spellName)
			local t = expires - GetTime()
			self:TargetBar(args.spellId, t, args.destName)
		end

		playerList[#playerList+1] = args.destName

		if #playerList == 1 then
			self:ScheduleTimer("TargetMessage", 0.3, args.spellId, playerList, "Important", "Alarm")
		end
	end
end


function mod:ConflexiveBurst(args)
	burstsCount = burstsCount + 1
	self:Bar(209597, timers[209597][burstsCount] or 10, CL.count:format(self:SpellName(209597), burstsCount))
end

do
	local messages = {"FAST", "NORMAL", "SLOW"}

	local playerList = mod:NewTargetList()
	function mod:ConflexiveBurstApplied(args)
		playerList[#playerList + 1] = args.destName

		if self:Me(args.destGUID) then
			--self:Flash(209597)
			--self:Say(209597)
			self:Say(209597, messages[#playerList])
			self:Emit("ELISANDE_CONFLEXIVE_ATTRIBUTION", messages[#playerList])
			if #playerList == 1 then
				self:Flash(false, 207011)
			elseif #playerList == 3 then
				self:Flash(false, 207013)
			end
			-- Need to constantly update because of fast/slow time
			--local _, _, _, _, _, _, expires = UnitDebuff("player", args.spellName)
			--local t = expires - GetTime()
			--self:TargetBar(209597, t, args.destName)
		end

		if #playerList == 1 then
			self:ScheduleTimer("TargetMessage", 0.3, 209597, playerList, "Important", "Alarm")
		end
	end
end

function mod:AblativePulse(args)
	self:Message(args.spellId, "Important", "Alert", CL.casting:format(args.spellName))
end

function mod:Ablated(args)
	local amount = args.amount or 1
	self:StackMessage(args.spellId, args.destName, amount, "Urgent", amount > 4 and "Warning")
end
