
--------------------------------------------------------------------------------
-- TODO List:
-- Fix/Remove untested mythic funcs:
-- MistInfusion
-- (Mythic) Update Lantarn of Darkness initial timer.
-- (Mythic) Update Fetid Rot timers
-- (Mythic) If marking Orb targets, in p3 there is double dps

--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Helya-TrialOfValor", 1114, 1829)
if not mod then return end
mod:RegisterEnableMob(114537)
mod.engageId = 2008
mod.respawnTime = 30
mod.instanceId = 1648

--------------------------------------------------------------------------------
-- Locals
--

local taintMarkerCount = 4
local tentaclesUp = 9
local phase = 1
local mobTable = {
	[114881] = {}, -- Tentacle Strike
}
local mobCount = {
	[114881] = 0, -- Tentacle Strike
}
local strikeCount = 1
local strikeWave = {
	"CAC x 2",
	"CAC RANGE",
	"RANGE x 2",
	"RANGEx2 CAC",
	"CAC x 2",
	"CAC RANGE",
	"RANGE X 2",
	"RANGEx2 CAC",
}
local breathCount = 1
local orbCount = 1
local lastOrbTime = 0
local lastOrbTargets = {}
local mistCount = 3
local taintCount = 1
local orbTimer = { 7, 13.0, 13.0, 27.3, 10.7, 13.0, 25.0, 13.0, 13.0, 25.0, 13.0, 18.5, 19.5, 13.0, 13.0, 12.0, 12.0, 16.8, 8.2 }

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then
	L.nearTrigger = "near" -- |TInterface\\Icons\\inv_misc_monsterhorn_03.blp:20|t A %s emerges near Helya!
	L.farTrigger = "far" -- |TInterface\\Icons\\inv_misc_monsterhorn_03.blp:20|t A %s emerges far from Helya!
	L.tentacle_near = "Tentacle NEAR Helya"
	L.tentacle_near_desc = "This option can be used to emphasize or hide the messages when a Striking Tentacle spawns near Helya."
	L.tentacle_near_icon = 228730
	L.tentacle_far = "Tentacle FAR from Helya"
	L.tentacle_far_desc = "This option can be used to emphasize or hide the messages when a Striking Tentacle spawns far from Helya."
	L.tentacle_far_icon = 228730

	L.orb_melee = "Orb: Melee timer"
	L.orb_melee_desc = "Show the timer for the Orbs that spawn on Melee."
	L.orb_melee_icon = 229119
	L.orb_melee_bar = "Melee Orb"

	L.orb_ranged = "Orb: Ranged timer"
	L.orb_ranged_desc = "Show the timer for the Orbs that spawn on Ranged."
	L.orb_ranged_icon = 229119
	L.orb_ranged_bar = "Ranged Orb"

	L.gripping_tentacle = -14309
	L.grimelord = -14263
	L.mariner = -14278

	L.rot_fail = "[FAIL] Fetid rot failed: %s => %s"
	L.tentacle = "Tentacle (%s) : %s"
	L.mist = "Mistwatcher x %s"
end

--------------------------------------------------------------------------------
-- Initialization
--

local orbMarker = mod:AddMarkerOption(false, "player", 1, 229119, 1, 2, 3) -- Orb of Corruption
local taintMarker = mod:AddMarkerOption(false, "player", 4, 228054, 4, 5, 6) -- Taint of the Sea

local rot_fails = mod:AddTokenOption { "rot_fails", "Announce Fetid Rot fails", promote = false }
local axion_soak = mod:AddCustomOption { "axion_soak", "Announce Corrupted Axions soakers" }

function mod:GetOptions()
	return {
		--[[ Helya ]]--
		"stages",
		"berserk",
		{229119, "SAY", "FLASH"}, -- Orb of Corruption
		"orb_melee",
		"orb_ranged",
		orbMarker,
		227967, -- Bilewater Breath
		227992, -- Bilewater Liquefaction
		227998, -- Bilewater Corrosion
		{227982, "TANK"}, -- Bilewater Redox
		228730, -- Tentacle Strike
		"tentacle_near",
		"tentacle_far",
		{228054, "SAY"}, -- Taint of the Sea
		taintMarker,
		228872, -- Corrossive Nova
		230197, -- Dark Waters

		--[[ Stage Two: From the Mists ]]--
		228300, -- Fury of the Maw
		167910, -- Kvaldir Longboat

		--[[ Grimelord ]]--
		228390, -- Sludge Nova
		{193367, "SAY", "FLASH", "PROXIMITY"}, -- Fetid Rot
		rot_fails,
		228519, -- Anchor Slam

		--[[ Night Watch Mariner ]]--
		228619, -- Lantern of Darkness
		228633, -- Give No Quarter
		{228611, "TANK"}, -- Ghostly Rage

		--[[ Decaying Minion ]]--
		228127, -- Decay

		--[[ Helarjer Mistcaller ]]--
		228854, -- Mist Infusion

		--[[ Stage Three: Helheim's Last Stand ]]--
		{230267, "SAY", "FLASH"}, -- Orb of Corrosion
		228565, -- Corrupted Breath
		{232488, "TANK"}, -- Dark Hatred
		{232450, "INFOBOX"}, -- Corrupted Axion
		axion_soak,
		"berserk"
	},{
		["stages"] = -14213, -- Helya
		[228300] = -14222, -- Stage Two: From the Mists
		[228390] = -14263, -- Grimelord
		[228619] = -14278, -- Night Watch Mariner
		[228127] = -14223, -- Decaying Minion
		[228854] = -14544, -- Helarjer Mistcaller
		[230267] = -14224, -- Stage Three: Helheim's Last Stand
	}
end

function mod:OnBossEnable()
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1", "boss2", "boss3", "boss4", "boss5")
	self:RegisterEvent("RAID_BOSS_EMOTE")
	self:RegisterEvent("RAID_BOSS_WHISPER")

	--[[ Helya ]]--
	self:Log("SPELL_CAST_SUCCESS", "OrbOfCorruption", 227903)
	self:Log("SPELL_AURA_APPLIED", "OrbApplied", 229119)
	self:Log("SPELL_AURA_REMOVED", "OrbRemoved", 229119)
	self:Log("SPELL_DAMAGE", "OrbDamage", 227930)
	self:Log("SPELL_MISSED", "OrbDamage", 227930)
	self:Log("SPELL_AURA_APPLIED", "TaintOfTheSea", 228054)
	self:Log("SPELL_AURA_REMOVED", "TaintOfTheSeaRemoved", 228054)
	self:Log("SPELL_CAST_START", "BilewaterBreath", 227967)
	self:Log("SPELL_AURA_APPLIED", "BilewaterRedox", 227982)
	self:Log("SPELL_CAST_START", "TentacleStrike", 228730)
	self:Log("SPELL_CAST_START", "CorrossiveNova", 228872)
	self:Log("SPELL_AURA_APPLIED", "BilewaterCorrosion", 227998)
	self:Log("SPELL_PERIODIC_DAMAGE", "BilewaterCorrosion", 227998)

	self:Log("SPELL_AURA_APPLIED", "DarkWatersDamage", 230197)
	self:Log("SPELL_PERIODIC_DAMAGE", "DarkWatersDamage", 230197)
	self:Log("SPELL_PERIODIC_MISSED", "DarkWatersDamage", 230197)

	--[[ Stage Two: From the Mists ]]--
	self:Log("SPELL_AURA_APPLIED", "FuryOfTheMaw", 228300)
	self:Log("SPELL_AURA_REMOVED", "FuryOfTheMawRemoved", 228300)
	self:Log("SPELL_AURA_REMOVED", "KvaldirLongboat", 167910) -- Add Spawn

	--[[ Grimelord ]]--
	self:Log("SPELL_CAST_START", "SludgeNova", 228390)
	self:Log("SPELL_AURA_APPLIED", "FetidRot", 193367)
	self:Log("SPELL_AURA_REMOVED_DOSE", "FetidRotRemovedDose", 193367)
	self:Log("SPELL_AURA_REMOVED", "FetidRotRemoved", 193367)
	self:Log("SPELL_CAST_START", "AnchorSlam", 228519)
	self:Death("GrimelordDeath", 114709)

	--[[ Night Watch Mariner ]]--
	self:Log("SPELL_CAST_START", "LanternOfDarkness", 228619)
	self:Log("SPELL_CAST_SUCCESS", "GiveNoQuarter", 228633)
	self:Log("SPELL_CAST_SUCCESS", "GhostlyRage", 228611)
	self:Death("MarinerDeath", 114809)

	--[[ Decaying Minion ]]--
	self:Log("SPELL_AURA_APPLIED", "DecayDamage", 228127)
	self:Log("SPELL_PERIODIC_DAMAGE", "DecayDamage", 228127)
	self:Log("SPELL_PERIODIC_MISSED", "DecayDamage", 228127)

	--[[ Helarjer Mistcaller ]]--
	--self:Log("SPELL_CAST_START", "MistInfusion", 228854) -- untested

	--[[ Stage Three: Helheim's Last Stand ]]--
	self:Log("SPELL_CAST_SUCCESS", "OrbOfCorrosion", 228056)
	self:Log("SPELL_AURA_APPLIED", "OrbApplied", 230267)
	self:Log("SPELL_AURA_REMOVED", "OrbRemoved", 230267)
	self:Log("SPELL_DAMAGE", "OrbDamage", 228063)
	self:Log("SPELL_MISSED", "OrbDamage", 228063)
	self:Log("SPELL_CAST_START", "CorruptedBreath", 228565)
	self:Log("SPELL_AURA_APPLIED", "DarkHatred", 232488)
	self:Log("SPELL_AURA_APPLIED", "CorruptedAxion", 232450)
	self:Log("SPELL_CAST_START", "FotMClean", 228032)
	self:RegisterNetMessage("AxionSoakers")
end

function mod:OnEngage()
	taintMarkerCount = 4
	tentaclesUp = self:Mythic() and 8 or 9
	phase = 1
	mistCount = 3
	mobTable = {
	        [114881] = {}, -- Tentacle Strike
	}
	mobCount = {
        	[114881] = 0, -- Tentacle Strike
	}
	strikeCount = 1
	breathCount = 1
	orbCount = 1
	taintCount = 1
	self:CDBar(227967, self:Mythic() and 10.5 or self:Heroic() and 12 or 13.3, CL.count:format(self:SpellName(227967), breathCount)) -- Bilewater Breath
	self:CDBar(228054, self:Mythic() and 15.5 or self:Heroic() and 19.5 or 12, CL.count:format(self:SpellName(228054), taintCount)) -- Taint of the Sea
	self:CDBar("orb_ranged", self:Mythic() and 14 or self:Heroic() and 31 or 18, CL.count:format(L.orb_ranged_bar, orbCount), 229119) -- Orb of Corruption
	self:CDBar(228730, self:Mythic() and 35.3 or self:Heroic() and 36.7 or 53.3, L.tentacle:format(strikeCount, strikeWave[strikeCount] or "DUNNO")) -- Tentacle Strike
	if self:Mythic() then
		self:Berserk(660)
	end
end

--------------------------------------------------------------------------------
-- Local Functions
--

local function getMobNumber(mobId, guid)
        if mobTable[mobId][guid] then return mobTable[mobId][guid] end
        mobCount[mobId] = mobCount[mobId] + 1
        mobTable[mobId][guid] = mobCount[mobId]
        return mobCount[mobId]
end


--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:UNIT_SPELLCAST_SUCCEEDED(unit, spellName, _, _, spellId)
	if spellId == 228372 then -- Mists of Helheim
		phase = 2
		self:Message("stages", "Neutral", "Long", CL.stage:format(2), false)
		self:StopBar(CL.count:format(L.orb_ranged_bar, orbCount))
		self:StopBar(CL.count:format(L.orb_melee_bar, orbCount))
		self:StopBar(CL.count:format(self:SpellName(228054, taintCount))) -- Taint of the Sea
		self:StopBar(CL.count:format(self:SpellName(227967), breathCount)) -- Bilewater Breath
		if self:BarTimeLeft(CL.cast:format(self:SpellName(227967))) > 0 then -- Breath
			-- if she transitions while casting the breath she won't spawn the blobs
			self:StopBar(CL.cast:format(self:SpellName(227992))) -- Bilewater Liquefaction
		end
		self:StopBar(CL.cast:format(self:SpellName(227967))) -- Bilewater Breath
		self:StopBar(L.tentacle:format(strikeCount, strikeWave[strikeCount] or "DUNNO")) -- Tentacle Strike
		if not self:Mythic() then
			self:Bar(167910, 14, CL.adds) -- Kvaldir Longboat
		end
		self:Bar(228300, self:Mythic() and 10.5 or 50) -- Fury of the Maw
		mistCount = 3
		self:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", nil, "boss1")
	elseif spellId == 228546 then -- Helya
		self:UnregisterUnitEvent("UNIT_HEALTH_FREQUENT", "boss1")
		phase = 3
		orbCount = 1
		breathCount = 1
		self:Message("stages", "Neutral", "Long", CL.stage:format(3), false)
		self:StopBar(228300) -- Fury of the Maw
		self:StopBar(CL.cast:format(self:SpellName(228300))) -- Cast: Fury of the Maw
		self:StopBar(CL.adds)
		self:StopBar(L.mist:format(1))
		self:Bar("orb_ranged", self:Mythic() and orbTimer[orbCount] or 15.5, CL.count:format(L.orb_ranged_bar, orbCount), 230267) -- Orb of Corrosion
		self:Bar(228565, self:Mythic() and 10 or 19.5, CL.count:format(self:SpellName(228565), breathCount)) -- Corrupted Breath
		if not self:Mythic() then -- Taint comes instant in mythic, no need for timer.
			self:Bar(228054, 24.5) -- Taint of the Sea
		end
		self:Bar(228300, self:Mythic() and 35 or 30.4) -- Fury of the Maw
		-- self:Bar(167910, self:Mythic() and 44 or 38, self:SpellName(L.mariner)) -- Kvaldir Longboat
	elseif spellId == 228838 then -- Fetid Rot (Grimelord)
		self:Bar(193367, 12.2) -- Fetid Rot
	elseif spellId == 201126 then -- Bleak Eruption (Helarjar Mistwatcher)
		if mistCount < 3 then
			self:Message(228854, "Attention", "Warning", L.mist:format(mistCount))
			SetRaidTarget(unit, 8)
			mistCount = 3
		end
	end
end

function mod:RAID_BOSS_EMOTE(event, msg, npcname)
	if msg:find(L.nearTrigger) then
		self:Message("tentacle_near", "Urgent", "Long", L.tentacle_near, 228730)
	elseif msg:find(L.farTrigger) then
		self:Message("tentacle_far", "Urgent", "Long", L.tentacle_far, 228730)
	elseif msg:find("inv_misc_monsterhorn_03", nil, true) then -- Fallback for no locale
		msg = msg:gsub("|T[^|]+|t", "")
		self:Message(228730, "Urgent", "Long", msg:format(npcname), 228730)
		BigWigs:Print("Missing translation for tentacle strike.") -- XXX temp
	end
end

function mod:RAID_BOSS_WHISPER(event, msg)
	if msg:find("227920") then -- P1 Orb of Corruption
		self:Message(229119, "Personal", "Warning", CL.you:format(self:SpellName(229119))) -- Orb of Corruption
		self:Say(229119)
		self:Flash(229119)
	elseif msg:find("228058") then -- P2 Orb of Corrosion
		self:Message(230267, "Personal", "Warning", CL.you:format(self:SpellName(230267))) -- Orb of Corrosion
		self:Say(230267)
		self:Flash(230267)
	end
end

function mod:UNIT_HEALTH_FREQUENT(unit)
	local hp = UnitHealth(unit) / UnitHealthMax(unit)*100
	if phase == 2 then
		local tentaclesLeft = self:Mythic() and floor((hp-45)/2.5) or floor((hp-40)/2.77)
		if tentaclesLeft < tentaclesUp then
			tentaclesUp = tentaclesLeft
			if tentaclesLeft >= 0 then
				self:Message("stages", "Neutral", nil, CL.mob_remaining:format(self:SpellName(L.gripping_tentacle), tentaclesLeft), false)
			else
				self:UnregisterUnitEvent("UNIT_HEALTH_FREQUENT", unit)
			end
		end
	else
		self:UnregisterUnitEvent("UNIT_HEALTH_FREQUENT", unit)
	end
end

do
	local list, isOnMe, scheduled = mod:NewTargetList(), nil, nil

	local function warn(self, spellId, spellName)
		if not isOnMe then
			self:TargetMessage(spellId, list, "Urgent", "Warning", CL.count:format(spellName, orbCount - 1)) -- gets incremented on the cast
		else
			wipe(list)
		end
		scheduled = nil
		isOnMe = nil
	end

	function mod:OrbApplied(args)
		list[#list+1] = args.destName
		if #list == 1 then
			scheduled = self:ScheduleTimer(warn, 0.1, self, args.spellId, args.spellName)
			lastOrbTime = GetTime()
			wipe(lastOrbTargets)
		end

		lastOrbTargets[args.destUnit] = true

		if self:GetOption(orbMarker) then
			if self:Healer(args.destName) then
				SetRaidTarget(args.destName, 1)
			elseif self:Tank(args.destName) then
				SetRaidTarget(args.destName, 2)
			else -- Damager
				SetRaidTarget(args.destName, 3)
			end
		end

		if self:Me(args.destGUID) then -- Warning and Say are in RAID_BOSS_WHISPER
			isOnMe = true
		end
	end

	function mod:OrbRemoved(args)
		if self:GetOption(orbMarker) then
			SetRaidTarget(args.destName, 0)
		end
	end
end

function mod:OrbOfCorruption(args)
	if phase > 1 then return end
	orbCount = orbCount + 1
	if orbCount % 2 == 0 then
		self:Bar("orb_melee", self:Mythic() and 24.3 or self:Heroic() and 28 or 31.5, CL.count:format(L.orb_melee_bar, orbCount), 229119) -- Orb of Corruption
	else
		self:Bar("orb_ranged", self:Mythic() and 24.3 or self:Heroic() and 28 or 31.5, CL.count:format(L.orb_ranged_bar, orbCount), 229119) -- Orb of Corruption
	end
end

do
	local prev = 0
	function mod:OrbDamage(args)
		local t = GetTime()
		if self:Me(args.destGUID) and t-prev > 2 then
			prev = t
			self:Message(args.spellId == 228063 and 230267 or 229119, "Personal", "Alarm", CL.underyou:format(args.spellName))
		end
	end
end

function mod:BilewaterBreath(args)
	self:Message(args.spellId, "Important", "Alarm", CL.count:format(args.spellName, breathCount))
	self:Bar(args.spellId, 3, CL.cast:format(args.spellName))
	self:Bar(227992, self:Normal() and 25.5 or 20.5, CL.cast:format(self:SpellName(227992))) -- Bilewater Liquefaction
	breathCount = breathCount + 1
	self:Bar(args.spellId, self:Mythic() and 43.5 or self:Heroic() and 52 or 55.9, CL.count:format(args.spellName, breathCount))
end

function mod:BilewaterRedox(args)
	if self:Tank(args.destName) then -- others might get hit, only tank is relevant
		self:TargetMessage(args.spellId, args.destName, "Urgent", not self:Me(args.destGUID) and "Alarm", nil, nil, true)
		self:TargetBar(args.spellId, 30, args.destName)
	end
end

do
	local list = mod:NewTargetList()
	function mod:TaintOfTheSea(args)
		list[#list+1] = args.destName
		if #list == 1 then
			self:ScheduleTimer("TargetMessage", 0.1, args.spellId, list, "Attention", "Alert", CL.count:format(args.spellName, taintCount), nil, self:Dispeller("magic"))
			taintCount = taintCount + 1
			self:CDBar(args.spellId, phase == 1 and 12.1 or (self:Mythic() and 20 or 28), CL.count:format(args.spellName, taintCount))
		end

		if self:GetOption(taintMarker) then
			SetRaidTarget(args.destName, taintMarkerCount)
			taintMarkerCount = taintMarkerCount + 1
			if taintMarkerCount > 6 then taintMarkerCount = 4 end
		end
	end

	function mod:TaintOfTheSeaRemoved(args)
		SetRaidTarget(args.destName, 0)
		if self:Me(args.destGUID) then
			self:Message(args.spellId, "Personal", "Warning", CL.underyou:format(args.spellName))
			if not self:Mythic() then
				self:Say(args.spellId)
			end
		end
		if self:GetOption(taintMarker) then
			SetRaidTarget(args.destName, 0)
		end
	end
end

do
	local prev = 0
	function mod:TentacleStrike(args)
		-- Message is in RAID_BOSS_EMOTE
		self:Bar(args.spellId, 6, CL.count:format(args.spellName, getMobNumber(114881, args.sourceGUID)))
		local t = GetTime()
		if t-prev > 10 and phase == 1 then
			prev = t
			strikeCount = strikeCount + 1
			self:Bar(args.spellId, self:Mythic() and 35 or 42, L.tentacle:format(strikeCount, strikeWave[strikeCount] or "DUNNO"))
		end
	end
end

do
	local prev = 0
	function mod:BilewaterCorrosion(args)
		local t = GetTime()
		if self:Me(args.destGUID) and t - prev > 1.5 then
			prev = t
			self:Message(args.spellId, "Personal", "Alert", CL.you:format(args.spellName))
		end
	end
end

do
	local prev = 0
	function mod:CorrossiveNova(args)
		local t = GetTime()
		if t-prev > 3 then
			prev = t
			self:Message(args.spellId, "Important", self:Tank() and "Long")
		end
	end
end

do
	local prev = 0
	function mod:DarkWatersDamage(args)
		local t = GetTime()
		if self:Me(args.destGUID) and t-prev > 2 then
			prev = t
			self:Message(args.spellId, "Personal", "Alarm", CL.underyou:format(args.spellName))
		end
	end
end

function mod:FuryOfTheMaw(args)
	self:StopBar(args.spellId)
	self:Message(args.spellId, "Important", "Info")
	self:Bar(args.spellId, self:Mythic() and 24 or 32, CL.cast:format(args.spellName))
	if self:Mythic() then
		self:Bar(167910, 7, CL.adds)
        	mistCount = 2
	end
end

function mod:FuryOfTheMawRemoved(args)
	self:Message(args.spellId, "Important", nil, CL.over:format(args.spellName))
	self:Bar(args.spellId, 45)
	mistCount = 1
	self:Bar(228854, 10, L.mist:format(mistCount))
end

do
	local prev = 0

	function mod:KvaldirLongboat(args)
		local t = GetTime()
		self:Message(args.spellId, "Neutral", t-prev > 1 and "Long", args.destName) -- destName = name of the spawning add
		prev = t
		if phase == 2 then
			self:Bar(args.spellId, 76, CL.adds)
		else
			self:Bar(args.spellId, 71.7, self:SpellName(L.mariner))
		end

		if self:MobId(args.destGUID) == 114809 then -- Mariner
			self:Bar(228633, 7) -- Give No Quarter
			self:Bar(228611, 11) -- Ghostly Rage
			self:Bar(228619, self:Mythic() and 25 or phase == 2 and 30 or 35) -- Lantern of Darkness
		elseif self:MobId(args.destGUID) == 114709 then -- Grimelord
			self:Bar(193367, 7) -- Fetid Rot
			self:Bar(228519, 12) -- Anchor Slam
			self:Bar(228390, 14.5) -- Sludge Nova
		end
	end
end

--[[ Grimelord ]]--
function mod:SludgeNova(args)
	self:Message(args.spellId, "Attention", "Alert", CL.casting:format(args.spellName))
	self:Bar(args.spellId, 3, CL.cast:format(args.spellName))
	self:Bar(args.spellId, 24.3)
end

do
	local proxList, isOnMe = {}, nil

	function mod:FetidRot(args)
		if self:MobId(args.sourceGUID) == 1 and self:GetOption(rot_fails) then
			SendChatMessage(L.rot_fail:format(args.sourceName, args.destName), "RAID")
		end

		if self:Me(args.destGUID) then
			isOnMe = true
			self:TargetMessage(args.spellId, args.destName, "Personal", "Warning")
			self:Flash(args.spellId)
			self:Say(args.spellId)
			if self:Mythic() then
				self:ScheduleTimer("Say", 1, false, 2, true)
				self:ScheduleTimer("Say", 2, false, 1, true)
			else
				local _, _, _, _, _, _, expires = UnitDebuff("player", args.spellName)
				local t = expires - GetTime()
				for i = 1, 5 do
					if t - i < 0 then break end
					local alert = (i % 3 == 0) and (i .. " [" .. args.destName .. "]") or i
					self:ScheduleTimer("Say", t - i, false, alert, true)
				end
			end
			self:OpenProximity(args.spellId, 5)
		end

		proxList[#proxList+1] = args.destName
		if not isOnMe then
			self:OpenProximity(args.spellId, 5, proxList)
		end
	end

	function mod:FetidRotRemovedDose(args)
		if self:Mythic() and self:Me(args.destGUID) then
			local stacks = args.amount > 1 and " stacks" or " stack"
			self:Say(false, args.destName .. " - " .. args.amount .. stacks, true)
			self:ScheduleTimer("Say", 1, false, 2, true)
			self:ScheduleTimer("Say", 2, false, 1, true)
		end
	end

	function mod:FetidRotRemoved(args)
		if self:Me(args.destGUID) then
			isOnMe = nil
			self:StopBar(args.spellName, args.destName)
			self:CloseProximity(args.spellId)
		end

		tDeleteItem(proxList, args.destName)

		if not isOnMe then -- Don't change proximity if it's on you and expired on someone else
			if #proxList == 0 then
				self:CloseProximity(args.spellId)
			else
				self:OpenProximity(args.spellId, 5, proxList)
			end
		end
	end
end

function mod:AnchorSlam(args)
	self:Message(args.spellId, "Urgent", "Alarm", CL.casting:format(args.spellName))
	-- Upstream BigWigs says: self:Easy() and 14.6 or 12
	self:Bar(args.spellId, self:Easy() and 14.6 or 12.2)
end

function mod:GrimelordDeath(args)
	self:StopBar(228519) -- Anchor Slam
	self:StopBar(228390) -- Sludge Nova
	self:StopBar(CL.cast:format(self:SpellName(228390))) -- Sludge Nova
	self:StopBar(193367) -- Fetid Rot
end

--[[ Night Watch Mariner ]]--
function mod:LanternOfDarkness(args)
	self:Message(args.spellId, "Important", "Long")
	self:Bar(args.spellId, 7, CL.cast:format(args.spellName))
end

function mod:GiveNoQuarter(args)
	self:Message(args.spellId, "Attention", self:Ranged() and "Alert")
	self:Bar(args.spellId, self:Easy() and 9.3 or 6.1)
end

function mod:GhostlyRage(args)
	local unit = self:GetUnitIdByGUID(args.sourceGUID)
	if unit and UnitDetailedThreatSituation("player", unit) then
		self:Message(args.spellId, "Urgent", "Long", CL.on:format(args.spellName, args.sourceName))
	end
	self:Bar(args.spellId, 9.7)
end

function mod:MarinerDeath(args)
	self:StopBar(228633) -- Give No Quarter
	self:StopBar(228619) -- Lantern of Darkness
	self:StopBar(CL.cast:format(self:SpellName(228619))) -- Lantern of Darkness
	self:StopBar(228611) -- Ghostly Rage
end

--[[ Decaying Minion ]]--

do
	local prev = 0
	function mod:DecayDamage(args)
		local t = GetTime()
		if self:Me(args.destGUID) and t-prev > 3 then
			prev = t
			self:Message(args.spellId, "Personal", "Alert", CL.underyou:format(args.spellName))
		end
	end
end

--[[ Helarjer Mistcaller ]]--
function mod:MistInfusion(args) -- untested
	if self:Interrupter() then
		self:Message(args.spellId, "Attention", nil, CL.count:format(args.spellName, mistCount))
	end
end

--[[ Stage Three: Helheim's Last Stand ]]--

function mod:OrbOfCorrosion(args)
	orbCount = orbCount + 1
	if orbCount % 2 == 0 then
		self:Bar("orb_melee", self:Mythic() and orbTimer[orbCount] or 18, CL.count:format(L.orb_melee_bar, orbCount), 230267) -- Orb of Corruption
	else
		self:Bar("orb_ranged", self:Mythic() and orbTimer[orbCount] or 18, CL.count:format(L.orb_ranged_bar, orbCount), 230267) -- Orb of Corruption
	end
end

function mod:CorruptedBreath(args)
	self:Message(args.spellId, "Important", "Alarm", CL.count:format(args.spellName, breathCount))
	self:Bar(args.spellId, 4.5, CL.cast:format(args.spellName))
	if self:Mythic() then
		self:ScheduleTimer("CallAxionsSoakers", 3, breathCount)
	end
	breathCount = breathCount + 1
	self:Bar(args.spellId, self:Mythic() and 43 or self:Heroic() and 47 or 51, CL.count:format(args.spellName, breathCount))
	self:Bar(232450, 9.5) -- Corrupted Axion
end

do
	-- List of eligible soakers
	local soakers = {}

	-- Mapping of units to raid index and role
	local unitIndex = {}
	local unitRole = {}
	local unitClassPriority = {}

	-- Token for mutex of raid announce
	local announce = mod:CreateToken("axions")
	local announce_icon = mod:CreateToken("axions_icon", true)

	local healerAvailability = {
		[1] = true
	}

	local classPriority = {
		["melee"] = {
			[1] = 5, -- Warrior
			[4] = 4, -- Rogue
			[11] = 3, -- Druid
			[2] = 2, -- Paladin
		},
		["ranged"] = {
			[8] = 5, -- Mage
			[3] = 4, -- Hunter
		}
	}

	-- Sort the list of soakers based on suitableness
	local function sortSoakers(nextOrbType)
		local rolePriority = {
			["healer"] = 2,
			["melee"] = (nextOrbType == "melee" and 1 or 3),
			["ranged"] = (nextOrbType == "ranged" and 1 or 3),
		}
		return function(a, b)
			local aRole = unitRole[a]
			local bRole = unitRole[b]
			if aRole ~= bRole then
				-- Units of a different type than the next orb before units of the same type
				return rolePriority[aRole] > rolePriority[bRole]
			else
				local aPriority = unitClassPriority[a]
				local bPriority = unitClassPriority[b]
				if aPriority ~= bPriority then
					-- Units of the higher priority
					return aPriority > bPriority
				else
					-- Last units in the group
					return unitIndex[a] > unitIndex[b]
				end
			end
		end
	end

	-- Default attribution handler
	local function defaultHandler(breathId)
		wipe(soakers)
		wipe(unitIndex)
		wipe(unitRole)
		wipe(unitClassPriority)

		local healerAvailable = healerAvailability[breathId]
		local delta = GetTime() - lastOrbTime
		local nextOrbType = (orbCount % 2 == 0) and "melee" or "ranged"

		local function unitSuitable(unit)
			if not UnitExists(unit) or UnitIsDeadOrGhost(unit) then
				return false
			elseif mod:Damager(unit) then
				return not lastOrbTargets[unit] or delta > 12
			elseif mod:Healer(unit) then
				--return lastOrbTargets[unit] and healerAvailable
				return false
			else
				return false
			end
		end

		for i = 1, 20 do
			local unit = "raid" .. i
			if unitSuitable(unit) then
				soakers[#soakers + 1] = unit
				unitIndex[unit] = #soakers
				local role = mod:Role(unit)
				unitRole[unit] = role
				unitClassPriority[unit] = classPriority[role][select(3, UnitClass(unit))] or 1
			end
		end

		table.sort(soakers, sortSoakers(nextOrbType))
		return soakers
	end

	-- Override handler for specific breath
	local handlers = {}
	local soakerName = " %s(%s)"

	function mod:CallAxionsSoakers(breathId)
		if announce:IsMine() then
			local soakers = (handlers[breathId] or defaultHandler)(breathId)
			mod:Send("AxionSoakers", soakers, "RAID")
		end
	end

	function mod:AxionSoakers(soakers)
		local msg = "Axions soakers:" .. (soakerName:format("tank", 1))
		local soakersList = {}
		self:OpenInfo(232450)
		self:ScheduleTimer("CloseInfo", 10, 232450)
		self:SetInfo(232450, 1, "1")
		self:SetInfo(232450, 2, "tank")
		for i = 5, 2, -1 do
			local soaker = soakers[i - 1]
			local position = 7 - i
			self:SetInfo(232450, (position - 1) * 2 - 1, position)
			if soaker then
				msg = msg .. (soakerName:format(UnitName(soaker), position))
				soakersList[UnitName(soaker)] = position
				if UnitIsUnit("player", soaker) and self:GetOption(axion_soak) then
					self:Pulse(false, 232450)
					self:PlaySound(false, "Warning")
					self:Emphasized(false, "Soak: " .. position)
					self:Emit("HELYA_AXION_SOAK", position)
				end
				self:SetInfo(232450, (position - 1) * 2, UnitName(soaker))
				if announce_icon:IsMine() then
					SetRaidTarget(soaker, position + 2)
					self:ScheduleTimer(function()
						SetRaidTarget(soaker, 0)
					end, 10)
				end
			else
				msg = msg .. (soakerName:format("?", position))
				self:SetInfo(232450, (position - 1) * 2, "?")
			end
		end
		self:Emit("HELYA_AXION_SOAKERS", soakersList)
		if announce:IsMine() then
			SendChatMessage(msg, "RAID")
		end
	end
end

function mod:DarkHatred(args)
	if self:Tank(args.destName) then -- others might get hit, only tank is relevant
		self:TargetMessage(args.spellId, args.destName, "Urgent", not self:Me(args.destGUID) and "Alarm", nil, nil, true)
		self:TargetBar(args.spellId, 12, args.destName)
	end
end

do
	local list, isOnMe, scheduled = mod:NewTargetList(), nil, nil

	local function warn(self, spellId)
		if not isOnMe then
			if #list < 6 then -- If the pools don't get soaked, everyone gets a debuff
				self:TargetMessage(spellId, list, "Attention", "Long", nil, nil, true)
			else
				self:Message(spellId, "Attention", "Long")
			end
		end
		scheduled = nil
		isOnMe = nil
	end

	function mod:CorruptedAxion(args)
		list[#list+1] = args.destName
		if #list == 1 then
			scheduled = self:ScheduleTimer(warn, 0.1, self, args.spellId)
		end

		if self:Me(args.destGUID) then
			self:TargetMessage(args.spellId, args.destName, "Personal", "Long")
			isOnMe = true
		end
	end
end

function mod:FotMClean(args)
	self:Message(228300, "Important", "Info")
	self:Bar(228300, self:Mythic() and 56 or 71.7) -- Fury of the Maw
	self:Bar(167910, 7.7, self:SpellName(L.mariner)) -- Mariner P3
end
