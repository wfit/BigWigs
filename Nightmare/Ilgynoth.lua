
--------------------------------------------------------------------------------
-- TODO List:
-- - TouchOfCorruption doesnt stack on normal. Do we need warnings for that?
-- - SummonNightmareHorror cd

--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Il'gynoth", 1520, 1738)
if not mod then return end
mod:RegisterEnableMob(105906, 105393, 105304) -- Eye of Il'gynoth, Il'gynoth, Dominator Tentacle
mod.engageId = 1873
mod.respawnTime = 30
mod.instanceId = 1520

--------------------------------------------------------------------------------
-- Locals
--

local mobCollector = {}
local fixateOnMe = nil
local phase = 1 -- 1 = Outside, 2 = Boss, 3 = Outside, 4 = Boss

local ichors = {}
local ichorsMarked = {}
local unknownIchorMark = {}
local ichorsMarks = {}

local function resetIchorsMarker()
	wipe(ichors)
	wipe(ichorsMarked)
	wipe(unknownIchorMark)
	ichorsMarks = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true }
end

local deathBlossomCount = 1

local phaseStartTime = 0

local spawnData = {
	[1] = { -- Outside Phase 1
		[-13190] = { -- Deathglare Tentacle, Mind Flay (208697) SPELL_CAST_START
			{ 26.5, 1}, -- 1x
			{ 88.0, 2}, -- 2x
			{183.0, 1}, -- 1x
		},
		[-13191] = { -- Corruptor Tentacle, Spew Corruption (208929) SPELL_CAST_START
			{ 82.0, 2}, -- 2x
		},
	},
	[3] = { -- Outside Phase 2, time after Stuff of Nightmares (209915) applied
		[-13190] = { -- Deathglare Tentacle, Mind Flay (208697) SPELL_CAST_START
			{ 21.5, 2}, -- 2x
			{116.5, 2}, -- 2x
		},
		[-13191] = { -- Corruptor Tentacle, Spew Corruption (208929) SPELL_CAST_START
			{ 45.0, 3}, -- 3x
			{140.0, 2}, -- 2x
			{175.0, 4}, -- 4x
		},
	}
}
local spawnDataMythic = {
	[1] = { -- Outside Phase 1
		[-13190] = { -- Deathglare Tentacle, Mind Flay (208697) SPELL_CAST_START
			{ 21.5, 1}, -- 1x
			{ 96.5, 2}, -- 2x
			{181.5, 1}, -- 1x
			{251.9, 1}, -- 1x
		},
		[-13191] = { -- Corruptor Tentacle, Spew Corruption (208929) SPELL_CAST_START
			{ 90.0, 2}, -- 2x
			{185.4, 2}, -- 2x
			{235.0, 1}, -- 1x
			{280.0, 2}, -- 2x
			{300.0, 3}, -- 3x
		},
	},
	[3] = { -- Outside Phase 2, time after Stuff of Nightmares (209915) applied
		[-13190] = { -- Deathglare Tentacle, Mind Flay (208697) SPELL_CAST_START
			{ 21.5, 1}, -- 1x
			{ 26.5, 1}, -- 1x
			{116.5, 2}, -- 2x
			{231.5, 2}, -- 2x
			{251.5, 1}, -- 1x
		},
		[-13191] = { -- Corruptor Tentacle, Spew Corruption (208929) SPELL_CAST_START
			{ 45.2, 2}, -- 2x
			{120.2, 2}, -- 2x
			{235.2, 2}, -- 2x
			{300.0, 4}, -- 4x
		},
	}
}
local nextCorruptorText = "" -- used to stop the bars
local nextDeathglareText = "" -- used to stop the bars
local blobsRemaining = 20
local blobsMissed = 0

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then
	L.forces = -13187
	L.forces_icon = "spell_nature_dryaddispelmagic" -- some weird icon, only used in options

	L.nightmare_horror = -13188 -- Nightmare Horror
	L.nightmare_horror_icon = 209387 -- Seeping Corruption icon

	L.corruptor_tentacle = -13191 -- Corruptor Tentacle
	L.corruptor_tentacle_icon = 208929 -- Spew Corruption icon

	L.deathglare_tentacle = -13190 -- Deathglare Tentacle
	L.deathglare_tentacle_icon = 208697 -- Mind Flay icon

	L.shriveled_eyestalk = -13570 -- Shriveled Eyestalk
	L.shriveled_eyestalk_icon = 208697 -- Mind Flay icon

	L.remaining = "Remaining"
	L.missed = "Missed"

	L.ichor_fail = "FAIL: %s's Ichor did not hit the boss :("
end

--------------------------------------------------------------------------------
-- Initialization
--

local ichors_marks = mod:AddTokenOption { "ichors_marks", "Set markers on Ichors", promote = true }
local ichors_flash = mod:AddCustomOption { "ichors_flash", "Pulse attribution",
	desc = "Display a Pulse alert with the symbol of the Ichor fixated on you." }
local ichors_fails = mod:AddTokenOption { "ichors_fails", "Announce Ichors fails",
	desc = "Announces name of fixated players whose ichors did not hit the boss" }

function mod:GetOptions()
	return {
		"infobox",
		{"stages", "COUNTDOWN"},
		223121, -- Final Torpor
		212886, -- Nightmare Corruption

		--[[ Stage One ]]--
		"forces",

		-- Dominator Tentacle
		{208689, "SAY", "FLASH"}, -- Ground Slam
		{215234, "TANK"}, -- Nightmarish Fury

		-- Nightmare Ichor
		210099, -- Fixate
		209469, -- Touch of Corruption
		ichors_marks,
		ichors_flash,
		ichors_fails,

		-- Nightmare Horror
		"nightmare_horror", -- Nightmare Horror
		{210984, "TANK_HEALER"}, -- Eye of Fate

		-- Corruptor Tentacle
		{208929, "SAY", "FLASH"}, -- Spew Corruption

		-- Deathglare Tentacle
		208697, -- Mind Flay

		--[[ Stage Two ]]--
		{215128, "SAY", "FLASH", "PROXIMITY"}, -- Cursed Blood

		--[[ Mythic ]]--
		218415, -- Death Blossom
		"shriveled_eyestalk",
	},{
		["infobox"] = "general",
		["forces"] = -13184, -- Stage One
		[208689] = -13189, -- Dominator Tentacle
		[210099] = -13186, -- Nightmare Ichor
		["nightmare_horror"] = -13188, -- Nightmare Horror (this looks like shit)
		[208929] = -13191, -- Corruptor Tentacle
		[208697] = -13190, -- Deathglare Tentacle
		[215128] = -13192, -- Stage Two
		[218415] = "mythic",
	}
end

function mod:OnBossEnable()
	--[[ Stage One ]]--
	self:Log("SPELL_AURA_APPLIED", "NightmareCorruption", 212886)
	self:Log("SPELL_ABSORBED", "NightmareCorruption", 212886)
	self:Log("SPELL_MISSED", "NightmareCorruption", 212886)
	self:Log("SPELL_PERIODIC_DAMAGE", "NightmareCorruption", 212886)

	-- Dominator Tentacle
	self:RegisterEvent("RAID_BOSS_WHISPER")
	self:Log("SPELL_CAST_START", "GroundSlam", 208689)
	self:Log("SPELL_AURA_APPLIED", "NightmarishFury", 215234)
	self:Log("SPELL_CAST_SUCCESS", "EyeDamageCast", 209471) -- Nightmare Explosion
	self:Log("SPELL_DAMAGE", "EyeDamage", 210048) -- Nightmare Explosion, only hits the Eye

	-- Nightmare Ichor
	self:Log("SPELL_AURA_APPLIED", "Fixate", 210099)
	self:Log("SPELL_AURA_REMOVED", "FixateRemoved", 210099)
	self:Log("SPELL_AURA_APPLIED_DOSE", "TouchOfCorruption", 209469)
	self:Death("IchorDeath", 105721)
	self:RegisterNetMessage("IchorMarked")

	-- Nightmare Horror
	self:Log("SPELL_AURA_APPLIED", "SummonNightmareHorror", 209387) -- Seeping Corruption, buffed on spawn
	self:Log("SPELL_AURA_APPLIED", "EyeOfFate", 210984)
	self:Log("SPELL_AURA_APPLIED_DOSE", "EyeOfFate", 210984)
	self:Log("SPELL_CAST_SUCCESS", "EyeOfFateCast", 210984)

	-- Corruptor Tentacle
	self:Log("SPELL_CAST_START", "CorruptorTentacleSpawn", 208929) -- They start casting Spew Corruption instantly
	self:Log("SPELL_CAST_SUCCESS", "SpewCorruption", 208929)

	-- Deathglare Tentacle
	self:Log("SPELL_CAST_START", "MindFlay", 208697) -- Also used for spawn messages

	--[[ Stage Two ]]--
	self:Log("SPELL_AURA_APPLIED", "StuffOfNightmares", 209915)
	self:Log("SPELL_AURA_REMOVED", "StuffOfNightmaresRemoved", 209915)
	self:Log("SPELL_CAST_START", "DarkReconstitution", 210781)
	self:Log("SPELL_CAST_START", "FinalTorpor", 223121)
	self:Log("SPELL_AURA_APPLIED", "CursedBlood", 215128)
	self:Log("SPELL_AURA_REMOVED", "CursedBloodRemoved", 215128)

	--[[ Mythic ]]--
	self:Log("SPELL_CAST_START", "DeathBlossom", 218415)
	self:Log("SPELL_CAST_SUCCESS", "DeathBlossomSuccess", 218415)

end

function mod:OnEngage()
	wipe(mobCollector)
	fixateOnMe = nil
	phase = 1
	deathBlossomCount = 1
	blobsRemaining = self:LFR() and 15 or self:Mythic() and 22 or 20
	blobsMissed = 0
	self:CDBar(208689, 11.5) -- Ground Slam
	self:CDBar("nightmare_horror", self:Mythic() and 79 or 65, L.nightmare_horror, L.nightmare_horror_icon) -- Summon Nightmare Horror

	self:OpenInfo("infobox", self:SpellName(-13186)) -- Nightmare Ichor
	self:SetInfo("infobox", 1, L.remaining)
	self:SetInfo("infobox", 2, blobsRemaining)
	self:SetInfo("infobox", 3, L.missed)
	self:SetInfo("infobox", 4, blobsMissed)
	if self:Mythic() then
		self:Bar(218415, 60) -- Death Blossom
	end

	phaseStartTime = GetTime()
	self:StartSpawnTimer(-13190, 1) -- Deathglare Tentacle
	self:StartSpawnTimer(-13191, 1) -- Corruptor Tentacle

	resetIchorsMarker()
	if self:GetOption(ichors_marks) then
		self:RegisterTargetEvents("IchorMark")
	end
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:StartSpawnTimer(addType, count)
	if phase == 2 or phase == 4 then return end -- No spawns in boss phase
	local data = self:Mythic() and spawnDataMythic or spawnData
	local info = data and data[phase][addType][count]
	if not info then
		-- all out of spawn data
		return
	end

	local time, numSpawns = unpack(info)
	local length = floor(time - (GetTime() - phaseStartTime))

	if addType == -13190 then
		nextDeathglareText = CL.count:format(self:SpellName(addType), numSpawns)
		self:Bar("forces", length, nextDeathglareText, L.deathglare_tentacle_icon)
	else
		nextCorruptorText = CL.count:format(self:SpellName(addType), numSpawns)
		self:Bar("forces", length, nextCorruptorText, L.corruptor_tentacle_icon)
	end

	self:ScheduleTimer("StartSpawnTimer", length, addType, count+1)
end

do
	local prev = 0
	function mod:NightmareCorruption(args)
		local t = GetTime()
		if self:Me(args.destGUID) and t-prev > 1.5 then
			prev = t
			self:Message(args.spellId, "Personal", "Alert", CL.you:format(args.spellName))
		end
	end
end

-- Dominator Tentacle
function mod:RAID_BOSS_WHISPER(_, msg, sender)
	if msg:find("208689", nil, true) then -- Ground Slam
		self:Message(208689, "Personal", "Alarm", CL.you:format(self:SpellName(208689)))
		self:Flash(208689)
		self:Say(208689)
	end
end

function mod:GroundSlam(args)
	-- Personal warning is in RAID_BOSS_WHISPER above
	self:CDBar(args.spellId, 20.5)
end

do
	local prev = 0
	function mod:NightmarishFury(args)
		local t = GetTime()
		if t-prev > 1 then
			prev = t
			self:Message(args.spellId, "Urgent")
			self:Bar(args.spellId, 10)
		end
	end
end

function mod:EyeDamageCast(args)
	if ichorsMarked[args.sourceGUID] then -- Did we mark the Ichor?
		ichorsMarks[ichorsMarked[args.sourceGUID]] = true -- Mark used is available again
	end
	if blobsRemaining > 0 then -- Don't count blobs killed after the eye dies as missed
		blobsMissed = blobsMissed + 1
		self:SetInfo("infobox", 4, blobsMissed)
	end
end

function mod:EyeDamage(args)
	blobsRemaining = blobsRemaining - 1
	blobsMissed = blobsMissed - 1
	self:SetInfo("infobox", 2, blobsRemaining)
	self:SetInfo("infobox", 4, blobsMissed)

	-- When an Ichor damages the boss, remove the record for the corresponding ichor
	-- This will prevent the death handler to announce a fail
	ichors[args.sourceGUID] = nil
end

-- Nightmare Ichor
local function send_ichor_mark(ichor, player, mark)
	mod:Send("IchorMarked", { ichor = ichor, player = player, mark = mark }, "RAID")
end

function mod:Fixate(args)
	if self:Me(args.destGUID) then
		self:TargetMessage(args.spellId, args.destName, "Attention", "Info")
		fixateOnMe = true
	end

	-- When an Ichor fixates a target, save it as the "owner" of this Ichor
	local guid = args.sourceGUID
	ichors[guid] = args.destGUID

	-- This Ichor was marked before fixating a player
	if unknownIchorMark[guid] then
		send_ichor_mark(guid, args.destGUID, unknownIchorMark[guid])
		unknownIchorMark[guid] = nil
	end
end

function mod:FixateRemoved(args)
	if self:Me(args.destGUID) then
		fixateOnMe = nil
	end
end

function mod:IchorDeath(args)
	if ichorsMarked[args.destGUID] then -- Did we mark the Ichor?
		ichorsMarks[ichorsMarked[args.destGUID]] = true -- Mark used is available again
	end

	local owner = ichors[args.destGUID]
	if owner then
		ichors[args.destGUID] = nil
		if self:Token(ichors_fails) then
			-- If an owner still exists when the Icor dies, then the owner failed!
			SendChatMessage(L.ichor_fail:format(UnitName(self:UnitId(owner))), "RAID")
		end
	end
end

function mod:IchorMarked(data)
	if self:Me(data.player) and self:GetOption(ichors_flash) then
		self:Pulse(false, "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. data.mark)
	end
end

function mod:IchorMark(event, unit)
	local guid = UnitGUID(unit)
	if self:MobId(guid) == 105721 and not ichorsMarked[guid] and self:Token(ichors_marks) then
		local icon = next(ichorsMarks)
		if icon then -- At least one icon unused
			SetRaidTarget(unit, icon)
			ichorsMarks[icon] = nil -- Mark is no longer available
			ichorsMarked[guid] = icon -- Save the tentacle we marked and the icon we marked it with

			if ichors[guid] then
				send_ichor_mark(guid, ichors[guid], icon)
			else
				unknownIchorMark[guid] = icon
			end
		end
	end
end

function mod:TouchOfCorruption(args)
	local amount = args.amount or 1
	if amount % 2 == 0 and (self:Me(args.destGUID) or (amount > 5 and self:Healer())) then
		self:StackMessage(args.spellId, args.destName, amount, "Important")
	end
end

-- Nightmare Horror
function mod:SummonNightmareHorror(args)
	self:Message("nightmare_horror", "Important", "Info", CL.spawned:format(self:SpellName(L.nightmare_horror)), L.nightmare_horror_icon)
	self:Bar("nightmare_horror", 220, L.nightmare_horror, L.nightmare_horror_icon) -- Summon Nightmare Horror < TODO beta timer, need live data
	self:Bar(210984, 13.8) -- Eye of Fate
end

function mod:EyeOfFate(args)
	local amount = args.amount or 1
	self:StackMessage(args.spellId, args.destName, amount, "Important", self:Tank() and amount > 1 and "Warning")
end

function mod:EyeOfFateCast(args)
	self:Bar(args.spellId, 10)
end

-- Corruptor Tentacle
do
	local prev = 0
	function mod:CorruptorTentacleSpawn(args)
		if not mobCollector[args.sourceGUID] then
			mobCollector[args.sourceGUID] = true
			local t = GetTime()
			if t-prev > 2 then
				prev = t
				self:Message(args.spellId, "Neutral", "Info", CL.spawned:format(self:SpellName(L.corruptor_tentacle)), L.corruptor_tentacle_icon)
			end
		end
	end
end

do
	local list = mod:NewTargetList()
	function mod:SpewCorruption(args)
		list[#list+1] = args.destName
		if #list == 1 then
			self:ScheduleTimer("TargetMessage", 0.3, args.spellId, list, "Urgent", "Alert")
		end

		if self:Me(args.destGUID) then
			self:TargetBar(args.spellId, 10, args.destName)
			self:Flash(args.spellId)
			self:Say(args.spellId)
		end
	end
end

-- Deathglare Tentacle
do
	local prev = 0
	function mod:MindFlay(args)
		if not mobCollector[args.sourceGUID] then
			mobCollector[args.sourceGUID] = true
			local t = GetTime()
			if t-prev > 2 then
				prev = t
				if self:Mythic() and phase == 4 then
					self:Message("shriveled_eyestalk", "Neutral", "Info", CL.spawned:format(self:SpellName(L.shriveled_eyestalk)), L.shriveled_eyestalk_icon)
				else
					self:Message(args.spellId, "Neutral", "Info", CL.spawned:format(self:SpellName(L.deathglare_tentacle)), L.deathglare_tentacle_icon)
				end
			end
		end

		if self:Interrupter(args.sourceGUID) then -- avoid spam
			self:Message(args.spellId, "Attention", "Info", CL.casting:format(args.spellName))
		end
	end
end

--[[ Stage Two ]]--
function mod:StuffOfNightmares()
	if self.isEngaged then -- Gets buffed when the boss spawns
		self:Message("stages", "Neutral", "Long", CL.stage:format(1), false)
		phase = phase + 1
		blobsRemaining = self:LFR() and 15 or self:Mythic() and 22 or 20
		blobsMissed = 0
		self:SetInfo("infobox", 2, blobsRemaining)
		self:SetInfo("infobox", 4, blobsMissed)

		self:Bar("nightmare_horror", 99, L.nightmare_horror, L.nightmare_horror_icon) -- Summon Nightmare Horror
		phaseStartTime = GetTime()
		self:StartSpawnTimer(-13190, 1) -- Deathglare Tentacle
		self:StartSpawnTimer(-13191, 1) -- Corruptor Tentacle

		deathBlossomCount = 1
		if self:Mythic() then
			self:Bar(218415, 80) -- Death Blossom
		end

		resetIchorsMarker()
	end
end

function mod:StuffOfNightmaresRemoved()
	self:StopBar(L.nightmare_horror)
	self:StopBar(nextCorruptorText)
	self:StopBar(nextDeathglareText)
	self:StopBar(218415) -- Death Blossom

	self:Message("stages", "Neutral", "Long", CL.stage:format(2), false)
	phase = phase + 1

	self:Bar(215128, self:Mythic() and phase == 4 and 25 or self:Mythic() and phase == 2 and 23 or 15) -- Cursed Blood

	if self:Mythic() and phase == 4 then
		self:Bar("shriveled_eyestalk", 10, L.shriveled_eyestalk, L.shriveled_eyestalk_icon)
		self:ScheduleTimer("Bar", 10, "shriveled_eyestalk", 20, L.shriveled_eyestalk, L.shriveled_eyestalk_icon)
	end
end

function mod:DarkReconstitution(args)
	local timer = self:Mythic() and 55 or 50
	self:DelayedMessage("stages", timer-10, "Neutral", CL.custom_sec:format(CL.stage:format(1), 10), args.spellId, "Info")
	self:Bar("stages", timer, CL.stage:format(1), args.spellId) -- cast after 10s in phase (5s in Mythic)
end

function mod:FinalTorpor(args)
	local timer = self:Mythic() and 55 or 90
	self:DelayedMessage(args.spellId, timer-10, "Neutral", CL.custom_sec:format(args.spellName, 10), args.spellId, "Info")
	self:Bar(args.spellId, timer) -- cast after 10s in phase (5s in Mythic)
end

do
	local proxList, isOnMe, scheduled = {}, nil, nil

	local function warn(self, spellId)
		if not isOnMe then
			self:Message(spellId, "Attention", "Alert")
		end
		scheduled = nil
	end

	function mod:CursedBlood(args)
		if self:Me(args.destGUID) then
			isOnMe = true
			self:TargetMessage(args.spellId, args.destName, "Personal", "Warning")
			self:Flash(args.spellId)
			self:Say(args.spellId)
			self:TargetBar(args.spellId, 8, args.destName)
			self:OpenProximity(args.spellId, 11)
			self:SayCountdown(args.spellId, 8)
		end

		proxList[#proxList+1] = args.destName
		if not isOnMe then
			self:OpenProximity(args.spellId, 11, proxList)
		end

		if not scheduled then
			scheduled = self:ScheduleTimer(warn, 0.1, self, args.spellId)
			self:CDBar(args.spellId, self:Mythic() and phase == 4 and 28 or self:Mythic() and phase == 2 and 27 or 15)
		end
	end

	function mod:CursedBloodRemoved(args)
		if self:Me(args.destGUID) then
			isOnMe = nil
			self:StopBar(args.spellName, args.destName)
			self:CloseProximity(args.spellId)
			self:CancelSayCountdown(args.spellId)
		end

		tDeleteItem(proxList, args.destName)

		if not isOnMe then -- Don't change proximity if it's on you and expired on someone else
			if #proxList == 0 then
				self:CloseProximity(args.spellId)
			else
				self:OpenProximity(args.spellId, 11, proxList)
			end
		end
	end
end

--[[ Mythic ]]--
function mod:DeathBlossom(args)
	self:Message(args.spellId, "Urgent", "Alarm")
	self:CastBar(args.spellId, 15)
	deathBlossomCount = deathBlossomCount + 1
end

function mod:DeathBlossomSuccess(args)
	self:Message(args.spellId, "Positive", "Long", CL.over:format(args.spellName))
	local time = deathBlossomCount == 2 and 85 or deathBlossomCount == 3 and 20 or 0
	if phase == 3 then
		time = deathBlossomCount == 2 and 60 or deathBlossomCount == 3 and 100 or 0
	end
	if time > 0 then
		self:Bar(args.spellId, time)
	end
end
