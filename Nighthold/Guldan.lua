
--------------------------------------------------------------------------------
-- TODO List:
-- - Ugliest module in BigWigs so far. Clean me up please!
-- - Soul Siphon CD

--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Gul'dan", 1088, 1737)
if not mod then return end
mod:RegisterEnableMob(104154)
mod.engageId = 1866
mod.respawnTime = 30
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
local empowerCount = 1
local soulsRemaining = 0
local bondsEmpowered = false
local hellfireEmpowered = false
local eyesEmpowered = false
local inTransition = false

local timersHeroic = {
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
		[209270] = { 30.6, 62.5, 62.5, 25.0 },
		-- Storm of the Destroyer, SPELL_CAST_START
		[167819] = { 75.8, 68.8, 61.2 },
		-- Soul Siphon, SPELL_AURA_APPLIED
		[221891] = { 24.8, 10.2, 49.0, 10.2, 10.2, 59.0, 10.3, 10.2, 10.2 },
		-- Black Harvest, SPELL_CAST_START
		[206744] = { 55.8, 72.5, 87.6 },
	}
}

local overridesHeroic = {
	-- Nothing
}

local timersMythic = {
	-- Phase 2
	[2] = {
		[206222] = 40, -- Bonds of Fel, SPELL_CAST_START
		[212258] = 165, -- Hand of Gul'dan, SPELL_CAST_START
		[209270] = 48, -- Eye of Gul'dan, SPELL_CAST_START
		[206219] = 33, -- Liquid Hellfire, SPELL_CAST_START
		[210277] = { 20.1, 76, 88.8 }, -- Empower
	},
}

local overridesMythic = {
	-- Phase 2
	[2] = {
		[206222] = { [1] = 6.1 }, -- Bonds of Fel
		[212258] = { [1] = 16.1 }, -- Hand of Gul'dan
		[209270] = { [1] = 26.1 }, -- Eye of Gul'dan
		[206219] = { [1] = 36.1, [5] = 66.0 }, -- Liquid Hellfire
	}
}

local timers = mod:Mythic() and timersMythic or timersHeroic
local overrides = mod:Mythic() and overridesMythic or overridesHeroic

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then
	L.remaining = "Remaining"
	L.firstTransi = "indulge"
	L.emp_bar = "Gul'dan Empower"
	L.emp = "Empower"
end

--------------------------------------------------------------------------------
-- Initialization
--

local empower = mod:AddCustomOption { "empower", L.emp_bar, icon = 210277, configurable = true }
local tanks_marker = mod:AddMarkerOption(true, "player", 7, 71038, 6, 7)
local bonds_marker = mod:AddMarkerOption(true, "player", 1, 206222, 1, 2, 3, 4)

function mod:GetOptions()
	return {
		--[[ General ]] --
		"stages",
		tanks_marker,
		"infobox",
		"berserk",
		empower,

		--[[ Stage One ]]--
		206219, -- Liquid Hellfire
		206514, -- Fel Efflux
		212258, -- Hand of Gul'dan

		--[[ Inquisitor Vethriz ]]--
		-14897,
		207938, -- Shadowblink
		212568, -- Drain
		217770, -- Gaze of Vethriz

		--[[ Fel Lord Kuraz'mal ]]--
		-14894,
		{206675, "TANK"}, -- Shatter Essence
		210273, -- Fel Obelisk

		--[[ D'zorykx the Trapper ]]--
		-14902,
		208545, -- Anguished Spirits
		206883, -- Soul Vortex
		{206896, "TANK"}, -- Torn Soul

		--[[ Stage Two ]]--
		{206222, "SAY", "FLASH"}, -- Bonds of Fel
		{206221, "SAY", "FLASH"}, -- Empowered Bonds of Fel
		bonds_marker,
		206220, -- Empowered Liquid Hellfire
		{209270, "SAY", "FLASH", "PROXIMITY"}, -- Eye of Gul'dan
		{211152, "SAY", "FLASH", "PROXIMITY"}, -- Empowered Eye of Gul'dan
		{227556, "TANK"}, -- Fury of the Fel
		208672, -- Carrion Wave

		--[[ Stage Three ]]--
		167819, -- Storm of the Destroyer
		221891, -- Soul Siphon
		208802, -- Soul Corrosion
		206744, -- Black Harvest
		{221783, "SAY", "FLASH", "PROXIMITY"}, -- Flames of Sargeras
		221781, -- Desolate Ground
	}, {
		["stages"] = "general",
		[206219] = -14885, -- Stage One
		[-14897] = -14897, -- Inquisitor Vethriz
		[-14894] = -14894, -- Fel Lord Kuraz'mal
		[-14902] = -14902, -- D'zorykx the Trapper
		[209011] = -14062, -- Stage Two
		[167819] = -14090, -- Stage Three
	}
end

function mod:OnBossEnable()
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1", "boss2", "boss3", "boss4", "boss5")

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
	self:Log("SPELL_CAST_SUCCESS", "SoulVortex", 206883)
	self:Log("SPELL_AURA_APPLIED", "TornSoul", 206896)
	self:Log("SPELL_AURA_APPLIED_DOSE", "TornSoul", 206896)
	self:Log("SPELL_AURA_REMOVED", "TornSoulRemoved", 206896)
	self:Death("TrapperDeath", 104534)

	--self:Death("FirstTransition", 104534, 104536, 104537)

	--[[ Stage Two ]]--
	self:Log("SPELL_AURA_REMOVED", "Phase2", 206516) -- Eye of Aman'Thu
	self:Log("SPELL_CAST_START", "BondsOfFelCast", 206222, 206221)
	self:Log("SPELL_AURA_APPLIED", "BondsOfFel", 209011, 206366)
	self:Log("SPELL_AURA_REMOVED", "BondsOfFelRemoved", 209011, 206384) -- Emp. Bonds switch from 206366 to 206384 once the target hits the ground
	self:Log("SPELL_CAST_START", "EyeOfGuldan", 209270, 211152)
	self:Log("SPELL_AURA_APPLIED", "EyeOfGuldanApplied", 209454, 221728)
	self:Log("SPELL_AURA_REMOVED", "EyeOfGuldanRemoved", 209454, 221728)
	self:Log("SPELL_AURA_APPLIED", "FuryOfTheFel", 227556)
	self:Log("SPELL_AURA_APPLIED_DOSE", "FuryOfTheFel", 227556)
	self:Log("SPELL_CAST_START", "CarrionWave", 208672)
	self:Death("DreadlordDeath", 107232, 107233, 105295) -- Beltheris, Dalvengyr, Azagrim

	--[[ Stage Three ]]--
	self:Log("SPELL_AURA_APPLIED", "SecondTransition", 227427) -- Eye of Aman'Thul
	self:Log("SPELL_AURA_REMOVED", "Phase3", 227427) -- Eye of Aman'Thul
	self:Log("SPELL_CAST_START", "StormOfTheDestroyer", 167819)
	self:Log("SPELL_AURA_APPLIED", "SoulSiphon", 221891)
	self:Log("SPELL_AURA_APPLIED", "SoulCorrosion", 208802)
	self:Log("SPELL_AURA_APPLIED_DOSE", "SoulCorrosion", 208802)
	self:Log("SPELL_CAST_START", "BlackHarvest", 206744)
	self:Log("SPELL_CAST_SUCCESS", "BlackHarvestSuccess", 206744)
	self:Log("SPELL_CAST_START", "FlamesOfSargeras", 221783)
	self:Log("SPELL_AURA_APPLIED", "FlamesOfSargerasSoon", 221606)
	self:Log("SPELL_AURA_REMOVED", "FlamesOfSargerasRemoved", 221603)

	self:Log("SPELL_AURA_APPLIED", "Damage", 206515, 221781) -- Fel Efflux, Desolate Ground
	self:Log("SPELL_PERIODIC_DAMAGE", "Damage", 206515, 221781)
	self:Log("SPELL_PERIODIC_MISSED", "Damage", 206515, 221781)
	self:Log("SPELL_DAMAGE", "Damage", 217770, 221781) -- Gaze of Vethriz, Desolate Ground
	self:Log("SPELL_MISSED", "Damage", 217770, 221781)
end

function mod:OnEngage()
	timers = self:Mythic() and timersMythic or timersHeroic
	overrides = mod:Mythic() and overridesMythic or overridesHeroic
	phase = self:Mythic() and 2 or 1

	liquidHellfireCount = 1
	felEffluxCount = 1
	handOfGuldanCount = 1
	bondsOfFelCount = 1
	eyeOfGuldanCount = 1
	empowerCount = 1

	bondsEmpowered = false
	hellfireEmpowered = false
	eyesEmpowered = false

	inTransition = false

	if not self:Mythic() then
		-- First transition detection
		self:RegisterEvent("CHAT_MSG_MONSTER_YELL")
	end

	self:CDBar(206219, self:Timer(206219, liquidHellfireCount), CL.count:format(self:SpellName(206219), liquidHellfireCount))
	self:CDBar(212258, self:Timer(212258, handOfGuldanCount), CL.count:format(self:SpellName(212258), handOfGuldanCount))
	if self:Mythic() then
		self:CDBar(206222, self:Timer(206222, bondsOfFelCount), CL.count:format(self:SpellName(206222), bondsOfFelCount))
		self:CDBar(209270, self:Timer(209270, eyeOfGuldanCount), CL.count:format(self:SpellName(209270), eyeOfGuldanCount))
		self:CDBar(empower, self:Timer(210277, empowerCount), CL.count:format(L.emp, empowerCount), 210277)
	else
		self:CDBar(206514, self:Timer(206514, felEffluxCount))
	end

	if self:GetOption(tanks_marker) then
		local marked = 0
		for unit in self:IterateGroup() do
			if self:Tank(unit) then
				self:SetIcon(tanks_marker, unit, 7 - marked)
				marked = marked + 1
				if marked == 2 then break end
			end
		end
	end

	self:Berserk(720)
end

function mod:OnBossDisable()
	if self:GetOption(tanks_marker) then
		for unit in self:IterateGroup() do
			if self:Tank(unit) then
				self:SetIcon(tanks_marker, unit, 0)
			end
		end
	end
end

function mod:Timer(spell, count)
	-- Override
	if overrides[phase] and overrides[phase][spell] and overrides[phase][spell][count] then
		return overrides[phase][spell][count]
	end
	-- Basic timer
	local timer = timers[phase] and timers[phase][spell] and timers[phase][spell]
	if type(timer) == "table" then
		return timer[count]
	elseif type(timer) == "number" then
		return timer
	else
		return nil
	end
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:UNIT_SPELLCAST_SUCCEEDED(unit, spellName, _, _, spellId)
	if spellId == 210273 then -- Fel Obelisk
		self:FelObelisk(spellId)
	elseif spellId == 210277 then -- Gul'dan, spell empowerement
		if not bondsEmpowered then
			bondsEmpowered = true
			self:EmpowerSpell(206222, 206221, bondsOfFelCount)
		elseif not hellfireEmpowered then
			hellfireEmpowered = true
			self:EmpowerSpell(206219, 206220, liquidHellfireCount)
		elseif not eyesEmpowered then
			eyesEmpowered = true
			self:EmpowerSpell(209270, 211152, eyeOfGuldanCount)
		end
		empowerCount = empowerCount + 1
		if self:Mythic() and empowerCount < 4 then
			self:CDBar(empower, self:Timer(210277, empowerCount), CL.count:format(L.emp, empowerCount), 210277)
		end
	elseif spellId == 215736 then -- Summon Fel Lord Kuraz'mal
		self:FellordSpawn()
	elseif spellId == 215738 then -- Summon Inquisitor Vethriz
		self:InquisitorSpawn()
	elseif spellId == 215739 then -- Summon D'zorykx the Trapper
		self:TrapperSpawn()
	elseif spellId == 212721 or spellId == 212722 or spellId == 209126 then -- Summon Dreadlord
		self:DreadlordSpawn()
	end
end

function mod:EmpowerSpell(baseSpellId, empSpellId, count)
	self:Message(empower, "Neutral", "Info", mod:SpellName(empSpellId), false)
	local unempowered = CL.count:format(self:SpellName(baseSpellId), count)
	local empowered = CL.count:format(self:SpellName(empSpellId), count)
	local timer = self:BarTimeLeft(unempowered)
	if timer then
		self:Bar(empSpellId, timer, empowered)
		self:StopBar(unempowered)
	end
end

function mod:CHAT_MSG_MONSTER_YELL(event, msg)
	if msg:find(L.firstTransi) then
		self:FirstTransition()
	end
end

--[[ Stage One ]]--
function mod:LiquidHellfire(args)
	if inTransition then return end
	self:Message(args.spellId, "Urgent", "Alarm", CL.incoming:format(CL.count:format(args.spellName, liquidHellfireCount)))
	liquidHellfireCount = liquidHellfireCount + 1
	self:Bar(args.spellId, self:Timer(206219, liquidHellfireCount), CL.count:format(args.spellName, liquidHellfireCount))
end

function mod:FelEfflux(args)
	if inTransition then return end
	self:Message(args.spellId, "Important", "Alert")
	felEffluxCount = felEffluxCount + 1
	self:CDBar(args.spellId, self:Timer(206514, felEffluxCount))
end

function mod:HandOfGuldan(args)
	if inTransition then return end
	self:Message(args.spellId, "Attention", "Info")
	handOfGuldanCount = handOfGuldanCount + 1
	if handOfGuldanCount < (self:Mythic() and 3 or 4) then
		self:Bar(args.spellId, self:Timer(212258, handOfGuldanCount), CL.count:format(args.spellName, handOfGuldanCount))
	end
end

--[[ Inquisitor Vethriz ]]--
function mod:InquisitorSpawn()
	self:Message(-14897, "Attention", "Info", nil, 215738)
	-- TODO if present in Mythic encounter
end

function mod:Shadowblink(args)
	self:Message(args.spellId, "Attention", "Info")
end

function mod:Drain(args)
	if self:Dispeller("magic") or self:Me(args.destGUID) then
		self:TargetMessage(args.spellId, args.destName, "Urgent", "Alarm")
	end
end

--[[ Fel Lord Kuraz'mal ]]--
function mod:FellordSpawn()
	self:Message(-14894, "Attention", "Info", nil, 215736)
	self:Bar(210273, 11) -- Fel Obelisk
end

function mod:ShatterEssence(args)
	self:Message(args.spellId, "Important", "Warning", CL.casting:format(args.spellName))
	self:Bar(args.spellId, 3, CL.cast:format(args.spellName))
	self:Bar(args.spellId, self:Mythic() and 21 or 53.5)
end

function mod:FelObelisk(spellId)
	self:Message(spellId, "Attention", "Alarm")
	self:CDBar(spellId, 23)
end

function mod:FelLordDeath(args)
	self:StopBar(206675) -- Shatter Essence
	self:StopBar(210273) -- Fel Obelisk
end

--[[ D'zorykx the Trapper ]]--
function mod:TrapperSpawn()
	self:Message(-14902, "Attention", "Info", nil, 215739)
	self:Bar(206883, 6) -- Soul Vortex
end

function mod:AnguishedSpirits(args)
	self:Message(args.spellId, "Attention", "Alert", CL.incoming:format(args.spellName))
end

function mod:SoulVortex(args)
	self:Message(args.spellId, "Urgent", "Long")
	self:Bar(args.spellId, 21)
end

function mod:TornSoul(args)
	if self:Me(args.destGUID) then
		local amount = args.amount or 1
		self:StackMessage(args.spellId, args.destName, amount, "Urgent", amount > 1 and "Warning") -- check sound amount
		self:TargetBar(args.spellId, 30, args.destName)
	end
end

function mod:TornSoulRemoved(args)
	if self:Me(args.destGUID) then
		self:StopBar(args.spellId, args.destName)
	end
end

function mod:TrapperDeath()
	self:StopBar(206883) -- Soul Vortex
end

--[[ Stage Two ]]--
function mod:FirstTransition(args)
	inTransition = true
	self:StopBar(206514) -- Fel Efflux
	self:StopBar(CL.count:format(self:SpellName(212258), handOfGuldanCount)) -- Hand of Gul'dan
	self:Message("stages", "Neutral", "Long", "First Transition", false)
	self:Bar("stages", 19, CL.stage:format(phase + 1), 206516)
end

function mod:Phase2(args)
	inTransition = false
	phase = 2
	self:Message("stages", "Neutral", "Long", CL.stage:format(phase), false)
	liquidHellfireCount = 1
	handOfGuldanCount = 1
	self:Bar(206219, self:Timer(206219, liquidHellfireCount), CL.count:format(self:SpellName(206219), liquidHellfireCount)) -- Liquid Hellfire
	self:Bar(212258, self:Timer(212258, handOfGuldanCount), CL.count:format(self:SpellName(212258), handOfGuldanCount)) -- Hand of Gul'dan
	self:Bar(206222, self:Timer(206222, bondsOfFelCount), CL.count:format(self:SpellName(206222), bondsOfFelCount)) -- Bonds of Fel
	self:Bar(209270, 29.1) -- Eye of Gul'dan
end

do
	local felBondsDebuffCount = 0

	function mod:BondsOfFelCast(args)
		self:Message(args.spellId, "Attention", "Info", CL.casting:format(args.spellName))
		bondsOfFelCount = bondsOfFelCount + 1
		self:Bar(args.spellId, self:Timer(206222, bondsOfFelCount), CL.count:format(args.spellName, bondsOfFelCount))
		felBondsDebuffCount = 0
	end

	local list = mod:NewTargetList()
	function mod:BondsOfFel(args)
		local key = (args.spellId == 209011) and 206222 or 206221
		felBondsDebuffCount = felBondsDebuffCount + 1
		--list[#list + 1] = args.destName
		--if #list == 1 then
		--	self:ScheduleTimer("TargetMessage", 0.7, key, list, "Important", "Warning", nil, nil, true)
		--end
		if self:Me(args.destGUID) then
			--self:Say(key, CL.count:format(args.spellName, #list))
			self:Flash(key)
		end
		if not GetRaidTargetIndex(args.destUnit) then
			self:SetIcon(bonds_marker, args.destUnit, felBondsDebuffCount)
		end
	end

	function mod:BondsOfFelRemoved(args)
		local icon = GetRaidTargetIndex(args.destUnit)
		if icon and icon <= felBondsDebuffCount then
			self:SetIcon(bonds_marker, args.destUnit, 0)
		end
	end
end

function mod:EyeOfGuldan(args)
	self:Message(args.spellId, "Urgent", "Alert")
	if phase == 2 and not self:Mythic() then
		self:Bar(args.spellId, 53.3)
	else
		eyeOfGuldanCount = eyeOfGuldanCount + 1
		self:Bar(args.spellId, self:Timer(209270, eyeOfGuldanCount), CL.count:format(args.spellName, eyeOfGuldanCount))
	end
end

function mod:EyeOfGuldanApplied(args)
	if self:Me(args.destGUID) then
		local key = (args.spellId == 209454) and 209270 or 211152
		self:Say(key)
		self:Flash(key)
		self:OpenProximity(key, 8)
	end
end

function mod:EyeOfGuldanRemoved(args)
	if self:Me(args.destGUID) then
		self:CloseProximity((args.spellId == 209454) and 209270 or 211152)
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

--[[ Dreadlord ]] --
function mod:DreadlordSpawn()
	carrionCount = 1
	self:CDBar(208672, 5, CL.count:format(self:SpellName(208672), carrionCount)) -- Carrion Wave
end

function mod:CarrionWave(args)
	if self:Interrupter() then
		self:StopBar(CL.count:format(args.spellName, carrionCount))
		self:Message(args.spellId, "Attention", "Long", CL.count:format(args.spellName, carrionCount))
		carrionCount = carrionCount + 1
		self:Bar(args.spellId, 6.1, CL.count:format(args.spellName, carrionCount))
	end
end

function mod:DreadlordDeath()
	self:StopBar(CL.count:format(208672, carrionCount))
end

--[[ Stage Three ]]--
function mod:SecondTransition(args)
	self:StopBar(CL.count:format(self:SpellName(206220), liquidHellfireCount)) -- Emp. Hellfire
	self:StopBar(CL.count:format(self:SpellName(206221), bondsOfFelCount)) -- Emp. Bonds
	self:StopBar(211152) -- Emp. Eyes
	self:Message("stages", "Neutral", "Long", "Second Transition", false)
	self:Bar("stages", 8, CL.stage:format(phase + 1), 227427)
end

function mod:Phase3(args)
	phase = 3
	self:Message("stages", "Neutral", "Long", CL.stage:format(phase), false)
	eyeOfGuldanCount = 1
	stormCount = 1
	soulSiphonCount = 1
	harvestCount = 1
	soulsRemaining = 0
	self:Bar(211152, self:Timer(211152, eyeOfGuldanCount)) -- Empowered Eye of Gul'dan
	self:Bar(167819, self:Timer(167819, stormCount), CL.count:format(self:SpellName(167819), stormCount)) -- Storm of the Destroyer
	self:Bar(221891, self:Timer(221891, soulSiphonCount)) -- Soul Siphon
	self:Bar(206744, self:Timer(206744, harvestCount), CL.count:format(self:SpellName(206744), harvestCount)) -- Black Harvest
	self:Bar(221783, 18.2) -- Flames of Sargeras
	self:OpenInfo("infobox", self:SpellName(221891))
	self:SetInfo("infobox", 1, L.remaining)
	self:SetInfo("infobox", 2, soulsRemaining)
end

function mod:StormOfTheDestroyer(args)
	self:Message(args.spellId, "Important", "Long", CL.casting:format(CL.count:format(args.spellName, stormCount)))
	self:Bar(args.spellId, 10, CL.cast:format(args.spellName))
	stormCount = stormCount + 1
	self:Bar(167819, self:Timer(167819, stormCount), CL.count:format(args.spellName, stormCount))
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
			self:Bar(args.spellId, self:Timer(221891, soulSiphonCount))
		end
		soulsRemaining = soulsRemaining + 1
		self:SetInfo("infobox", 2, soulsRemaining)
	end

	function mod:SoulCorrosion(args)
		local amount = args.amount or 1
		soulsRemaining = soulsRemaining - 1
		self:SetInfo("infobox", 2, soulsRemaining)
		if self:Me(args.destGUID) and amount == 9 then
			self:Message(args.spellId, "Personal", "Warning", "You cant soak anymore!!")
		end
	end
end

function mod:BlackHarvest(args)
	self:Message(args.spellId, "Urgent", "Alert", CL.incoming:format(args.spellName))
	harvestCount = harvestCount + 1
	self:CDBar(206744, self:Timer(206744, harvestCount), CL.count:format(args.spellName, harvestCount)) -- Black Harvest
end

function mod:BlackHarvestSuccess(args)
	soulsRemaining = 0
	self:SetInfo("infobox", 2, soulsRemaining)
end

function mod:FlamesOfSargeras(args)
	self:Message(args.spellId, "Urgent", "Warning", CL.incoming:format(args.spellName))
	self:Bar(args.spellId, 51.3) -- Flames of Sargeras
	-- Debuffs waves
	self:ScheduleTimer("Bar", 3, args.spellId, 7.7, CL.next:format(args.spellName))
	self:ScheduleTimer("Bar", 10.7, args.spellId, 8.7, CL.next:format(args.spellName))
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
