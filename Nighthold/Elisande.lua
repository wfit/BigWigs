
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
--mod.respawnTime = 0

--------------------------------------------------------------------------------
-- Locals
--

local phase = 1

local timers = {
	-- Spanning Singularity, UNIT_SPELLCAST_SUCCEEDED
	[209168] = { 23.0, 36.0, 57.0, 65.0 },

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
	L.fastAdd = "Add Fast"
	L.slowAdd = "Add Slow"
	L.slowZoneDespawn = "Slow Zone Despawn"
	L.fastZoneDespawn = "Fast Zone Despawn"
end

--------------------------------------------------------------------------------
-- Initialization
--

local slow_zone_despawn = mod:AddCustomBarOption { "szd", L.slowZoneDespawn, icon = 207013 }
local fast_zone_despawn = mod:AddCustomBarOption { "fzd", L.fastZoneDespawn, icon = 207011 }

function mod:GetOptions()
	return {
		--[[ General ]]--
		208887, -- Summon Time Elementals
		"stages",
		"berserk",

		--[[ Recursive Elemental ]]--
		221863, -- Shield
		221864, -- Blast
		209165, -- Slow Time
		slow_zone_despawn,

		--[[ Expedient Elemental ]]--
		209568, -- Exothermic Release
		209166, -- Fast Time
		fast_zone_despawn,

		--[[ Time Layer 1 ]]--
		208807, -- Arcanetic Ring
		209168, -- Spanning Singularity

		--[[ Time Layer 2 ]]--
		{209244, "SAY", "FLASH"}, -- Delphuric Beam
		210022, -- Epocheric Orb
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
	--[[ General ]]--
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1")
	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	self:Log("SPELL_CAST_SUCCESS", "Nightwell", 208863)
	self:RegisterEvent("RAID_BOSS_EMOTE")

	--[[ Recursive Elemental ]]--
	self:Log("SPELL_AURA_APPLIED", "ShieldApplied", 221863)
	self:Log("SPELL_AURA_REMOVED", "ShieldRemoved", 221863)
	self:Log("SPELL_CAST_START", "Blast", 221864)
	self:Log("SPELL_AURA_APPLIED", "SlowTime", 209165)

	--[[ Expedient Elemental ]]--
	self:Log("SPELL_CAST_START", "ExothermicRelease", 209568)
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
end

--------------------------------------------------------------------------------
-- Event Handlers
--

--[[ General ]]--
do
	local prevSingularity = 0
	function mod:UNIT_SPELLCAST_SUCCEEDED(unit, spellName, _, _, spellId)
		local t = GetTime()
		if spellId == 211616 then -- Summon Time Elemental - Fast
			self:Message(208887, "Neutral", "Info", CL.count:format(L.fastAdd, fastAddCount))
			fastAddCount = fastAddCount + 1
			self:Bar(208887, timers[211616][fastAddCount] or 30, CL.count:format(L.fastAdd, fastAddCount))
		elseif spellId == 209005 then -- Summon Time Elemental - Slow
			self:Message(208887, "Neutral", "Info", CL.count:format(L.slowAdd, slowAddCount))
			slowAddCount = slowAddCount + 1
			self:Bar(208887, timers[209005][slowAddCount] or 30, CL.count:format(L.slowAdd, slowAddCount))
		elseif spellId == 211647 then  -- Time Stop
			self:TimeStop()
		elseif spellId == 209168 or spellId == 233012 or spellId == 233011 and t - prevSingularity > 1 then -- Spanning Singularity
			self:SpanningSingularity()
		end
	end
end

function mod:Nightwell(args)
	singularityCount = 1
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

	self:Bar(209168, timers[209168][singularityCount], CL.count:format(self:SpellName(209168), singularityCount))
	self:Bar(208807, timers[208807][ringCount], CL.count:format(self:SpellName(208807), ringCount))
	self:Bar(208887, timers[209005][slowAddCount], CL.count:format(L.slowAdd, slowAddCount))
	self:Bar(208887, timers[211616][fastAddCount], CL.count:format(L.fastAdd, fastAddCount))
	if phase >= 2 then
		self:Bar(210022, timers[210022][orbsCount], CL.count:format(self:SpellName(210022), orbsCount))
	end
	if phase == 2 or (phase == 3 and self:Mythic()) then
		self:Bar(209244, timers[209244][beamsCount], CL.count:format(self:SpellName(209244), beamsCount))
	end
	if phase == 3 then
		self:Bar(209597, timers[209597][burstsCount], CL.count:format(self:SpellName(209597), burstsCount))
	end
end

function mod:TimeStop()
	timeStopped = true
	self:StopBar(CL.count:format(self:SpellName(209168), singularityCount))
	self:StopBar(CL.count:format(self:SpellName(208807), ringCount))
	self:StopBar(CL.count:format(self:SpellName(210022), orbsCount))
	self:StopBar(CL.count:format(self:SpellName(209244), beamsCount))
	self:StopBar(CL.count:format(L.fastAdd, fastAddCount))
	self:StopBar(CL.count:format(L.slowAdd, slowAddCount))
	self:StopBar(CL.count:format(L.slowZoneDespawn, slowZoneCount))
	self:StopBar(CL.count:format(L.slowZoneDespawn, slowZoneCount - 1))
	self:StopBar(CL.count:format(L.fastZoneDespawn, fastZoneCount))
	if phase == 1 then
		singularityMax = singularityCount
		ringMax = ringCount
	elseif phase == 2 then
		orbsMax = orbsCount
		beamsMax = beamsCount
	end
	phase = phase + 1
	self:Message("stages", "Neutral", "Info", CL.phase:format(phase), false)
end

do
	local SLOW_ELEMENTAL = 105299
	local FAST_ELEMENTAL = 105301
	local elementalsSeen = {}

	function mod:INSTANCE_ENCOUNTER_ENGAGE_UNIT()
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
		self:TargetMessage(args.spellId, args.destName, "Personal", "Long")
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
		self:Message(args.spellId, "Positive", "Long", CL.you:format(args.spellName))
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
		self:Bar(208807, timers[209168][ringCount] or 30, CL.count:format(self:SpellName(208807), ringCount))
	end
end

function mod:SpanningSingularity(args)
	self:Message(209168, "Important", "Info")
	singularityCount = singularityCount + 1
	if phase == 1 or singularityCount < singularityMax then
		self:Bar(209168, timers[209168][singularityCount] or 30, CL.count:format(self:SpellName(209168), singularityCount))
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
		self:Bar(209244, timers[209244][beamsCount] or 30, CL.count:format(self:SpellName(209244), beamsCount))
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
		self:Bar(210022, timers[210022][orbsCount] or 30, CL.count:format(self:SpellName(210022), orbsCount))
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
