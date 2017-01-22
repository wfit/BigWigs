
--------------------------------------------------------------------------------
-- TODO List:
-- - Mod is untested, probably needs a lot of updates

--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Gul'dan", 1088, 1737)
if not mod then return end
mod:RegisterEnableMob(104154)
mod.engageId = 1866
--mod.respawnTime = 0
mod.instanceId = 1530

--------------------------------------------------------------------------------
-- Locals
--

local phase = 1
local liquidHellfireCount = 1
local felEffluxCount = 1
local handOfGuldanCount = 1
local bondsOfFelCount = 1
local eyeOfGuldanCount = 1
local stormCount = 1
local soulSiphonCount = 1
local harvestCount = 1
local carrionCount = 1
local addKilled = 0
local soulsRemaining = 0
local bondsEmpowered = false
local hellfireEmpowered = false
local eyesEmpowered = false

local timers = {
	-- Phase 1
	[1] = {
		-- Liquid Hellfire, SPELL_CAST_START
		[206219] = { 2.0, 15.0, 24.0, 27.4 },
		-- Fel Efflux, SPELL_CAST_START
		[206514] = { 11.0, 14.0, 19.8, 12.0, 15.1 },
		-- Hand of Gul'dan, SPELL_CAST_START
		[212258] = { 7.1, 14.0, 10.0 },
	},

	-- Phase 2
	[2] = {
		-- Liquid Hellfire, SPELL_CAST_START
		[206219] = { 40.1, 36.7, 36.7, 36.7, 73.3, 36.7, 73.3 },
		-- Hand of Gul'dan, SPELL_CAST_START
		[212258] = { 13.5, 48.9, 138.9 },
		-- Bonds of Fel, SPELL_CAST_START
		[206222] = { 6.8, 44.4, 44.4, 44.4, 44.4, 44.4, 44.4, 44.4, 21.2 },
	},

	-- Phase 3
	[3] = {
		-- Empowered Eye of Gul'dan, SPELL_CAST_START
		[211152] = { 30.6, 62.5, 62.5, 25.0 },
		-- Storm of the Destroyer, SPELL_CAST_START
		[167819] = { 75.8, 68.8, 61.2 },
		-- Soul Siphon, SPELL_AURA_APPLIED
		[221891] = { 24.8, 10.2, 49.0, 10.2, 10.2, 59.0, 10.3, 10.2, 10.2 },
		-- Black Harvest, SPELL_CAST_START
		[206744] = { 55.8, 72.5, 87.6 },
	}
}


--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then
	L.remaining = "Remaining"
end

--------------------------------------------------------------------------------
-- Initialization
--

local tank_marker = mod:AddMarkerOption(true, "player", 1, 71038, 6, 7)

function mod:GetOptions()
	return {
		--[[ General ]] --
		"stages",
		tank_marker,
		"infobox",

		--[[ Stage One ]]--
		206219, -- Liquid Hellfire
		206514, -- Fel Efflux
		212258, -- Hand of Gul'dan

		--[[ Inquisitor Vethriz ]]--
		207938, -- Shadowblink
		212568, -- Drain
		217770, -- Gaze of Vethriz

		--[[ Fel Lord Kuraz'mal ]]--
		{206675, "TANK"}, -- Shatter Essence
		210273, -- Fel Obelisk

		--[[ D'zorykx the Trapper ]]--
		208545, -- Anguished Spirits
		206883, -- Soul Vortex
		{206896, "TANK"}, -- Torn Soul

		--[[ Stage Two ]]--
		{206222, "SAY", "FLASH"}, -- Bonds of Fel
		{206221, "SAY", "FLASH"}, -- Empowered Bonds of Fel
		206220, -- Empowered Liquid Hellfire
		{209270, "SAY", "PROXIMITY"}, -- Eye of Gul'dan
		{211152, "SAY", "PROXIMITY"}, -- Empowered Eye of Gul'dan
		{227556, "TANK"}, -- Fury of the Fel
		208672, -- Carrion Wave

		--[[ Stage Three ]]--
		167819, -- Storm of the Destroyer
		{221891, "HEALER"}, -- Soul Siphon
		206744, -- Black Harvest
		{221783, "SAY", "FLASH", "PROXIMITY"}, -- Flames of Sargeras
		221781, -- Desolate Ground
	}, {
		--[210339] = -14886, -- Essence of Aman'Thul
		[206219] = -14885, -- Stage One
		[207938] = -14897, -- Inquisitor Vethriz
		[206675] = -14894, -- Fel Lord Kuraz'mal
		[208545] = -14902, -- D'zorykx the Trapper
		[209011] = -14062, -- Stage Two
		[167819] = -14090, -- Stage Three
	}
end

function mod:OnBossEnable()
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1", "boss2", "boss3", "boss4", "boss5")
	self:RegisterEvent("RAID_BOSS_EMOTE")

	--[[ Stage One ]]--
	self:Log("SPELL_CAST_START", "LiquidHellfire", 206219, 206220)
	self:Log("SPELL_CAST_START", "FelEfflux", 206514)
	self:Log("SPELL_CAST_START", "HandOfGuldan", 212258)

	--[[ Inquisitor Vethriz ]]--
	self:Log("SPELL_CAST_SUCCESS", "Shadowblink", 207938)
	self:Log("SPELL_AURA_APPLIED", "Drain", 212568)

	--[[ Fel Lord Kuraz'mal ]]--
	self:Log("SPELL_CAST_START", "ShatterEssence", 206675)
	self:Death("FelLordDeath", 104537)

	--[[ D'zorykx the Trapper ]]--
	self:Log("SPELL_CAST_START", "AnguishedSpirits", 208545)
	self:Log("SPELL_CAST_START", "SoulVortex", 206883)
	self:Log("SPELL_AURA_APPLIED", "TornSoul", 206896)
	self:Log("SPELL_AURA_APPLIED_DOSE", "TornSoul", 206896)
	self:Log("SPELL_AURA_REMOVED", "TornSoulRemoved", 206896)

	self:Death("FirstTransition", 104534, 104536, 104537)

	--[[ Stage Two ]]--
	self:Log("SPELL_AURA_REMOVED", "Phase2", 206516) -- Eye of Aman'Thu
	self:Log("SPELL_CAST_START", "BondsOfFelCast", 206222, 206221)
	self:Log("SPELL_AURA_APPLIED", "BondsOfFel", 209011, 206366)
	self:Log("SPELL_CAST_START", "EyeOfGuldan", 209270, 211152)
	self:Log("SPELL_AURA_APPLIED", "EyeOfGuldanApplied", 209454, 206384)
	self:Log("SPELL_AURA_REMOVED", "EyeOfGuldanRemoved", 209454, 206384)
	self:Log("SPELL_AURA_APPLIED", "FuryOfTheFel", 227556)
	self:Log("SPELL_AURA_APPLIED_DOSE", "FuryOfTheFel", 227556)
	self:Log("SPELL_CAST_START", "CarrionWave", 208672)

	--[[ Stage Three ]]--
	self:Log("SPELL_AURA_APPLIED", "SecondTransition", 227427) -- Eye of Aman'Thul
	self:Log("SPELL_AURA_REMOVED", "Phase3", 227427) -- Eye of Aman'Thul
	self:Log("SPELL_CAST_START", "StormOfTheDestroyer", 167819)
	self:Log("SPELL_AURA_APPLIED", "SoulSiphon", 221891)
	self:Log("SPELL_AURA_REMOVED", "SoulSiphonRemoved", 221891)
	self:Log("SPELL_CAST_START", "BlackHarvest", 206744)
	self:Log("SPELL_CAST_START", "FlamesOfSargeras", 221783)
	self:Log("SPELL_AURA_APPLIED", "FlamesOfSargerasSoon", 221606)
	self:Log("SPELL_AURA_REMOVED", "FlamesOfSargerasRemoved", 221603)

	self:Log("SPELL_AURA_APPLIED", "Damage", 206515, 209518, 211132, 221781) -- Fel Efflux, Eye of Gul'dan, Empowered Eye of Gul'dan, Desolate Ground
	self:Log("SPELL_PERIODIC_DAMAGE", "Damage", 206515, 209518, 211132, 221781)
	self:Log("SPELL_PERIODIC_MISSED", "Damage", 206515, 209518, 211132, 221781)
	self:Log("SPELL_DAMAGE", "Damage", 217770, 209518, 211132, 221781) -- Gaze of Vethriz, Eye of Gul'dan, Empowered Eye of Gul'dan, Desolate Ground
	self:Log("SPELL_MISSED", "Damage", 217770, 209518, 211132, 221781)
end

function mod:OnEngage()
	phase = 1

	liquidHellfireCount = 1
	felEffluxCount = 1
	handOfGuldanCount = 1
	addKilled = 0

	self:Bar(206219, timers[phase][206219][liquidHellfireCount], CL.count:format(self:SpellName(206219), liquidHellfireCount)) -- Liquid Hellfire
	self:Bar(206514, timers[phase][206514][felEffluxCount]) -- Fel Efflux
	self:Bar(212258, timers[phase][212258][handOfGuldanCount], CL.count:format(self:SpellName(212258), handOfGuldanCount)) -- Hand of Gul'dan

	if self:GetOption(tank_marker) then
		local marked = 0
		for unit in self:IterateGroup() do
			if self:Tank(unit) then
				SetRaidTarget(unit, 7 - marked)
				marked = marked + 1
				if marked == 2 then break end
			end
		end
	end
end

function mod:OnBossDisable()
	if self:GetOption(tank_marker) then
		for unit in self:IterateGroup() do
			if self:Tank(unit) then
				SetRaidTarget(unit, 0)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:UNIT_SPELLCAST_SUCCEEDED(unit, spellName, _, _, spellId)
	if spellId == 210273 then -- Fel Obelisk
		self:Message(spellId, "Attention", "Alarm")
		self:CDBar(spellId, 23)
	end
end

function mod:RAID_BOSS_EMOTE(event, msg, npcname)
	if msg:find("spell:206221") and not bondsEmpowered then -- 85%: Empowered Bonds of Fel
		bondsEmpowered = true
		self:Message("stages", "Neutral", "Info", CL.other:format("85%", mod:SpellName(206221)), false)
		local unempowered = CL.count:format(self:SpellName(206222), bondsOfFelCount)
		local time = self:BarTimeLeft(unempowered)
		self:StopBar(unempowered)
		self:Bar(206221, time, CL.count:format(self:SpellName(206221), bondsOfFelCount))
	elseif msg:find("spell:206220") and not hellfireEmpowered then -- 70%: Empowered Liquid Hellfire
		hellfireEmpowered = true
		self:Message("stages", "Neutral", "Info", CL.other:format("70%", mod:SpellName(206220)), false)
		local unempowered = CL.count:format(self:SpellName(206219), liquidHellfireCount)
		local time = self:BarTimeLeft(unempowered)
		self:StopBar(unempowered)
		self:Bar(206220, time, CL.count:format(self:SpellName(206220), liquidHellfireCount))
	elseif msg:find("spell:211152") and not eyesEmpowered then -- 55%: Empowered Eye of Gul'dan
		eyesEmpowered = true
		self:Message("stages", "Neutral", "Info", CL.other:format("55%", mod:SpellName(211152)), false)
		local time = self:BarTimeLeft(mod:SpellName(209270))
		self:StopBar(mod:SpellName(209270))
		self:Bar(211152, time)
	end
end

--[[ Stage One ]]--
function mod:LiquidHellfire(args)
	self:Message(args.spellId, "Urgent", "Alarm", CL.incoming:format(CL.count:format(args.spellName, liquidHellfireCount)))
	liquidHellfireCount = liquidHellfireCount + 1
	self:Bar(args.spellId, timers[phase][206219][liquidHellfireCount] or 36.7, CL.count:format(args.spellName, liquidHellfireCount), args.spellId)
end

function mod:FelEfflux(args)
	self:Message(args.spellId, "Important", "Alert")
	felEffluxCount = felEffluxCount + 1
	self:Bar(args.spellId, timers[phase][args.spellId][felEffluxCount] or 15.1)
end

function mod:HandOfGuldan(args)
	self:Message(args.spellId, "Attention", "Info")
	handOfGuldanCount = handOfGuldanCount + 1
	if handOfGuldanCount < 4 then
		self:Bar(args.spellId, timers[phase][args.spellId][handOfGuldanCount], CL.count:format(args.spellName, handOfGuldanCount))
	end
	if phase == 2 and not self:Mythic() then
		carrionCount = 1
		self:CDBar(208672, 9, CL.count:format(self:SpellName(208672), carrionCount))
	end
end

--[[ Inquisitor Vethriz ]]--
function mod:Shadowblink(args)
	self:Message(args.spellId, "Attention", "Info")
end

function mod:Drain(args)
	if self:Dispeller("magic") or self:Me(args.destGUID) then
		self:TargetMessage(args.spellId, args.destName, "Urgent", "Alarm")
	end
end

--[[ Fel Lord Kuraz'mal ]]--
function mod:ShatterEssence(args)
	self:Message(args.spellId, "Important", "Warning", CL.casting:format(args.spellName))
	self:Bar(args.spellId, 3, CL.cast:format(args.spellName))
	self:Bar(args.spellId, 53.5)
end

function mod:FelLordDeath(args)
	self:StopBar(206675) -- Shatter Essence
	self:StopBar(210273) -- Fel Obelisk
end

--[[ D'zorykx the Trapper ]]--
function mod:AnguishedSpirits(args)
	self:Message(args.spellId, "Attention", "Alert", CL.incoming:format(args.spellName))
end

function mod:SoulVortex(args)
	self:Message(args.spellId, "Urgent", "Long")
	self:Bar(args.spellId, 3, CL.cast:format(args.spellName)) -- actual cast
	self:ScheduleTimer("Bar", 3, args.spellId, 6, CL.cast:format(args.spellName)) -- pull in
end

function mod:TornSoul(args)
	local amount = args.amount or 1
	self:StackMessage(args.spellId, args.destName, amount, "Urgent", amount > 1 and "Warning") -- check sound amount
	self:TargetBar(args.spellId, 30, args.destName)
end

function mod:TornSoulRemoved(args)
	self:StopBar(args.spellId, args.destName)
end

--[[ Stage Two ]]--
function mod:FirstTransition(args)
	addKilled = addKilled + 1
	if addKilled == 3 then
		self:StopBar(206514) -- Fel Efflux
		self:StopBar(212258) -- Hand of Gul'dan
		self:Message("stages", "Neutral", "Long", "First Transition")
		self:Bar("stages", 19, CL.phase:format(2), 206516)
	end
end

function mod:Phase2(args)
	phase = 2
	self:Message("stages", "Neutral", "Long", CL.phase:format(phase))
	liquidHellfireCount = 1
	handOfGuldanCount = 1
	bondsOfFelCount = 1
	bondsEmpowered = false
	hellfireEmpowered = false
	eyesEmpowered = false
	self:Bar(206219, timers[phase][206219][liquidHellfireCount], CL.count:format(self:SpellName(206219), liquidHellfireCount)) -- Liquid Hellfire
	self:Bar(212258, timers[phase][212258][handOfGuldanCount], CL.count:format(self:SpellName(212258), handOfGuldanCount)) -- Hand of Gul'dan
	self:Bar(206222, timers[phase][206222][bondsOfFelCount], CL.count:format(self:SpellName(206222), bondsOfFelCount)) -- Bonds of Fel
	self:Bar(209270, 29.1) -- Eye of Gul'dan
end

function mod:BondsOfFelCast(args)
	self:Message(args.spellId, "Attention", "Info", CL.casting:format(args.spellName))
	bondsOfFelCount = bondsOfFelCount + 1
	self:Bar(args.spellId, timers[phase][206222][handOfGuldanCount] or 21.2, CL.count:format(args.spellName, bondsOfFelCount))
end

do
	local list = mod:NewTargetList()
	function mod:BondsOfFel(args)
		local key = (args.destId == 209011) and 206222 or 206221
		list[#list+1] = args.destName
		if #list == 1 then
			self:ScheduleTimer("TargetMessage", 0.5, key, list, "Important", "Warning", nil, nil, true)
		end
		if self:Me(args.destGUID) then
			self:Say(key, CL.count:format(args.spellName, #list))
			self:Flash(key)
		end
	end
end

function mod:EyeOfGuldan(args)
	self:Message(args.spellId, "Urgent", "Alert")
	if phase == 2 then
		self:Bar(args.spellId, 53.3)
	else
		eyeOfGuldanCount = eyeOfGuldanCount + 1
		self:Bar(args.spellId, timers[phase][args.spellId][eyeOfGuldanCount] or 25)
	end
end

function mod:EyeOfGuldanApplied(args)
	if self:Me(args.destGUID) then
		self:Say(args.spellId)
		self:OpenProximity(args.spellId, 8)
	end
end

function mod:EyeOfGuldanRemoved(args)
	if self:Me(args.destGUID) then
		self:CloseProximity(args.spellId)
	end
end

do
	local prev = 0
	function mod:FuryOfTheFel(args)
		local t = GetTime()
		if t - prev > 5 then
			local amount = args.amount or 1
			self:Message(args.spellId, "Positive", "Info", CL.count:format(args.spellName, amount))
		end
	end
end

function mod:CarrionWave(args)
	if self:Interrupter() then
		self:StopBar(CL.count:format(args.spellName, carrionCount))
		self:Message(args.spellId, "Attention", "Long", CL.count:format(args.spellName, carrionCount))
		carrionCount = carrionCount + 1
		self:Bar(args.spellId, 6.1, CL.count:format(args.spellName, carrionCount))
	end
end

--[[ Stage Three ]]--
function mod:SecondTransition(args)
	self:StopBar(CL.count:format(self:SpellName(206220), liquidHellfireCount)) -- Emp. Hellfire
	self:StopBar(CL.count:format(self:SpellName(206221), bondsOfFelCount)) -- Emp. Bonds
	self:StopBar(211152) -- Emp. Eyes
	self:Message("stages", "Neutral", "Long", "Second Transition")
	self:Bar("stages", 8, CL.phase:format(3), 227427)
end

function mod:Phase3(args)
	phase = 3
	self:Message("stages", "Neutral", "Long", CL.phase:format(phase))
	eyeOfGuldanCount = 1
	stormCount = 1
	soulSiphonCount = 1
	harvestCount = 1
	soulsRemaining = 0
	self:Bar(211152, timers[phase][211152][eyeOfGuldanCount]) -- Empowered Eye of Gul'dan
	self:Bar(167819, timers[phase][167819][stormCount], CL.count:format(self:SpellName(167819), stormCount)) -- Storm of the Destroyer
	self:Bar(221891, timers[phase][221891][soulSiphonCount]) -- Soul Siphon
	self:Bar(206744, timers[phase][206744][harvestCount], CL.count:format(self:SpellName(206744), harvestCount)) -- Black Harvest
	self:Bar(221783, 13.8) -- Flames of Sargeras
	self:OpenInfo("infobox", self:SpellName(221891))
	self:SetInfo("infobox", 1, L.remaining)
	self:SetInfo("infobox", 2, soulsRemaining)
end

function mod:StormOfTheDestroyer(args)
	self:Message(args.spellId, "Important", "Long", CL.casting:format(CL.count:format(args.spellName, stormCount)))
	self:Bar(args.spellId, 10, CL.cast:format(args.spellName))
	stormCount = stormCount + 1
	self:Bar(167819, timers[phase][167819][stormCount] or 60, CL.count:format(args.spellName, stormCount))
end

do
	local list = mod:NewTargetList()
	local function warn(self, spellId, spellName)
		self:Message(spellId, "Important", "Warning", ("Soul Siphon +%d"):format(#list))
		wipe(list)
	end

	function mod:SoulSiphon(args)
		list[#list+1] = args.destName
		if #list == 1 then
			self:ScheduleTimer(warn, 1, self, args.spellId, args.spellName)
			soulSiphonCount = soulSiphonCount + 1
			self:Bar(args.spellId, timers[phase][args.spellId][soulSiphonCount] or 10.2)
		end
		soulsRemaining = soulsRemaining + 1
		self:SetInfo("infobox", 2, soulsRemaining)
	end

	function mod:SoulSiphonRemoved(args)
		soulsRemaining = soulsRemaining - 1
		self:SetInfo("infobox", 2, soulsRemaining)
	end
end

function mod:BlackHarvest(args)
	self:Message(args.spellId, "Urgent", "Alert", CL.incoming:format(args.spellName))
	harvestCount = harvestCount + 1
	self:Bar(206744, timers[phase][206744][harvestCount] or 70, CL.count:format(args.spellName, harvestCount)) -- Black Harvest
end

function mod:FlamesOfSargeras(args)
	self:Message(args.spellId, "Urgent", "Warning", CL.incoming:format(args.spellName))
	self:Bar(args.spellId, 51.3) -- Flames of Sargeras
end

do
	local list = mod:NewTargetList()
	function mod:FlamesOfSargerasSoon(args)
		list[#list + 1] = args.destName
		if #list == 1 then
			self:ScheduleTimer("TargetMessage", 0.2, 221783, list, "Important", "Warning", nil, nil, true)
		end
		if self:Me(args.destGUID) then
			self:TargetMessage(221783, args.destName, "Personal", "Warning", CL.soon:format(args.spellName))
			self:Say(221783)
			self:Flash(221783)
			self:TargetBar(221783, 7, args.destName)
			self:OpenProximity(221783, 8)
		end
	end
end

function mod:FlamesOfSargerasRemoved(args)
	if self:Me(args.destGUID) then
		self:CloseProximity(221783)
	end
end

do
	local mapping = {
		[206515] = 206514, -- Fel Efflux
		[209518] = 209270, -- Eye of Guldan
		[211132] = 211152, -- Empowered Eye of Gul'dan
	}
	local prev = 0
	function mod:Damage(args)
		local t = GetTime()
		if self:Me(args.destGUID) and t - prev > 1.5 then
			prev = t
			local id = mapping[args.spellId] or args.spellId
			self:Message(id, "Personal", "Alarm", CL.underyou:format(args.spellName))
		end
	end
end
