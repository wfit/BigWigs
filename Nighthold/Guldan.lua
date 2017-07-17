
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
local windCount = 1
local soulseverCount = 1
local parasiticCount = 1
local visionsCount = 1
local flameCrashCount = 1
local azzinothCount = 1
local nightorbCount = 1
local lastVisions = 0
local nextVisions = 0
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
		-- Eye of Gul'dan, SPELL_CAST_START
		[209270] = 53.3,
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
	-- Phase 2
	[2] = {
		[209270] = { [1] = 29.1 }, -- Eye of Gul'dan, SPELL_CAST_START
	},
}

local timersMythic = {
	-- Phase 2
	[2] = {
		[206222] = 40, -- Bonds of Fel, SPELL_CAST_START
		[212258] = 165, -- Hand of Gul'dan, SPELL_CAST_START
		[209270] = { 26.1, 48, 48, 48, 48, 48, 80, 76.6 }, -- Eye of Gul'dan, SPELL_CAST_START
		[206219] = { 36.1, 33, 33, 33, 66, 33, 66, 56, 33 }, -- Liquid Hellfire, SPELL_CAST_START
		[210277] = { 20.1, 76, 88.8 }, -- Empower
	},

	-- Phase 3
	[3] = {
		-- Empowered Eye of Gul'dan, SPELL_CAST_START
		[209270] = { 26.7, 52.6, 53.2, 20.4, 84.2, 52.6, 35.8 },
		-- Storm of the Destroyer, SPELL_CAST_START
		[167819] = { 64.5, 57.8, 51.5, 64.6, 57.4 },
		-- Soul Siphon, SPELL_AURA_APPLIED
		[221891] = { 21.7, 9.5, 42, 9.5, 9.5, 50.5, 9.5, 9.5, 9.5, 45.3, 9.5, 9.5, 9.5, 9.5, 27.3, 9.5, 9.5, 9.5, 9.5, 9.5 },
		-- Black Harvest, SPELL_CAST_START
		[206744] = { 47.8, 61, 75.3, 86.7, 75.8 },
		-- Fel Wind
		[215125] = { 3.8, 87.4, 84.5, 84.5 },

		-- P4 is actually P3 to handle simultaneous Gul'dan
		-- Manifest Azzinoth, UNIT_SPELLCAST_SUCCEEDED
		[227264] = { 22, 41, 41, 42, 40, 41, 41, 41, -1 },
		-- Summon Nightorb, UNIT_SPELLCAST_SUCCEEDED
		[227283] = { 35, 45, 60, 40, -1 },

	},
}

local overridesMythic = {
	-- Phase 2
	[2] = {
		[206222] = { [1] = 6.1 }, -- Bonds of Fel
		[212258] = { [1] = 16.1 }, -- Hand of Gul'dan
	},
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

	L.hellfire = "Hellfire"
	L.emp_hellfire = "Empowered Hellfire"
	L.bonds = "Bonds"
	L.emp_bonds = "Empowered Bonds"
	L.eyes = "Eyes"
	L.emp_eye = "Empowered Eye"

	L.demonWithinStart = "Time to return the demon hunter's soul to his body"
end

--------------------------------------------------------------------------------
-- Initialization
--

local empower = mod:AddCustomOption { "empower", L.emp_bar, icon = 210277, configurable = true }
local tanks_marker = mod:AddMarkerOption(true, "player", 7, -14884, 6, 7)
local bonds_marker = mod:AddMarkerOption(true, "player", 1, 206222, 1, 2, 3, 4)
local prox_before_eyes = mod:AddCustomOption { "prox_before_eyes", "Display Proximity display before first fixate" }
local visions_cast = mod:AddCustomOption { "visions_cast", "Visions of the Dark Titan (cast bar)", icon = 227008, configurable = true }

function mod:GetOptions()
	return {
		--[[ General ]] --
		"stages",
		tanks_marker,
		"infobox",
		empower,
		215125, -- Fel Wind
		"berserk",

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
		prox_before_eyes,
		{227556, "TANK"}, -- Fury of the Fel

		--[[ Dreadlords of the Twisting Nether ]] --
		-13500,
		208672, -- Carrion Wave

		--[[ Stage Three ]]--
		167819, -- Storm of the Destroyer
		221891, -- Soul Siphon
		{208802, "PROXIMITY"}, -- Soul Corrosion
		206744, -- Black Harvest
		{221783, "SAY", "FLASH", "PROXIMITY"}, -- Flames of Sargeras
		221781, -- Desolate Ground

		--[[ The Demon Within ]] --
		{206847, "SAY", "FLASH"}, -- Parasitic Wound
		220957, -- Soulsever
		227094, -- Flame Crash
		227264, -- Manifest Azzinoth
		221382, -- Chaos Seed
		227283, -- Summon Nightorb
		211832, -- Time Stop Field
		221486, -- Purified Essence
		226975, -- Visions of the Dark Titan
		visions_cast, -- Visions of the Dark Titan (cast)
	}, {
		["stages"] = "general",
		[206219] = -14885, -- Stage One
		[-14897] = -14897, -- Inquisitor Vethriz
		[-14894] = -14894, -- Fel Lord Kuraz'mal
		[-14902] = -14902, -- D'zorykx the Trapper
		[206222] = -14062, -- Stage Two
		[-13500] = -13500, -- Dreadlords of the Twisting Nether
		[167819] = -14090, -- Stage Three
		[206847] = 211439, -- Will of the Demon Within
	}
end

function mod:OnBossEnable()
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1", "boss2", "boss3", "boss4", "boss5")
	self:RegisterUnitEvent("UNIT_TARGET", "TankMarker", "boss1")

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

	--[[ Dreadlords of the Twisting Nether ]] --
	self:Log("SPELL_CAST_START", "CarrionWave", 208672)
	self:Death("DreadlordDeath", 107232, 107233, 105295) -- Beltheris, Dalvengyr, Azagrim

	--[[ Stage Three ]]--
	self:Log("SPELL_AURA_APPLIED", "SecondTransition", 227427) -- Eye of Aman'Thul
	self:Log("SPELL_AURA_REMOVED", "Phase3", 227427) -- Eye of Aman'Thul
	self:Log("SPELL_CAST_START", "StormOfTheDestroyer", 167819)
	self:Log("SPELL_DAMAGE", "SoulSiphon", 221891)
	self:Log("SPELL_MISSED", "SoulSiphon", 221891)
	self:Log("SPELL_AURA_APPLIED", "WellOfSoulsApplied", 208536)
	self:Log("SPELL_AURA_REMOVED", "WellOfSoulsRemoved", 208536)
	self:Log("SPELL_DAMAGE", "SoulExplulsion", 228267)
	self:Log("SPELL_MISSED", "SoulExplulsion", 228267)
	self:Log("SPELL_CAST_START", "BlackHarvest", 206744)
	--self:Log("SPELL_CAST_SUCCESS", "BlackHarvestSuccess", 206744)
	self:Log("SPELL_CAST_START", "FlamesOfSargeras", 221783)
	self:Log("SPELL_AURA_APPLIED", "FlamesOfSargerasSoon", 221606)
	self:Log("SPELL_AURA_REMOVED", "FlamesOfSargerasRemoved", 221603)

	self:Log("SPELL_AURA_APPLIED", "Damage", 206515, 221781) -- Fel Efflux, Desolate Ground
	self:Log("SPELL_PERIODIC_DAMAGE", "Damage", 206515, 221781)
	self:Log("SPELL_PERIODIC_MISSED", "Damage", 206515, 221781)
	self:Log("SPELL_DAMAGE", "Damage", 217770, 221781) -- Gaze of Vethriz, Desolate Ground
	self:Log("SPELL_MISSED", "Damage", 217770, 221781)

	--[[ The Demon Within ]] --
	self:Log("SPELL_AURA_APPLIED", "ParasiticWoundApplied", 206847)
	self:Log("SPELL_CAST_START", "Soulsever", 220957)
	self:Log("SPELL_CAST_SUCCESS", "VisionsOfTheDarkTitan", 226975)
	self:Log("SPELL_CAST_START", "VisionsOfTheDarkTitanStart", 227008)
	self:Log("SPELL_CAST_START", "PurifiedEssence", 221486)
	self:Log("SPELL_AURA_APPLIED", "Wounded", 227009)
	self:Death("AzzinothDeath", 111070)
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

	-- Heroic 1st transition + mythic 10% detection
	self:RegisterEvent("CHAT_MSG_MONSTER_YELL")

	if self:Mythic() then
		-- Must be canceled once the mythic transition begins
		self:Bar("berserk", 632, 26662)
		-- Used to cancel/close Gul'dan related stuff once really in P4
		self:Death("GuldanDeath", 104154)
	else
		self:Berserk(720)
	end

	self:CDBar(206219, self:Timer(206219, liquidHellfireCount), CL.count:format(L.hellfire, liquidHellfireCount))
	self:CDBar(212258, self:Timer(212258, handOfGuldanCount), CL.count:format(self:SpellName(212258), handOfGuldanCount))
	if self:Mythic() then
		self:CDBar(206222, self:Timer(206222, bondsOfFelCount), CL.count:format(L.bonds, bondsOfFelCount))
		self:CDBar(209270, self:Timer(209270, eyeOfGuldanCount), CL.count:format(L.eyes, eyeOfGuldanCount))
		self:CDBar(empower, self:Timer(210277, empowerCount), CL.count:format(L.emp, empowerCount), 210277)
	else
		self:CDBar(206514, self:Timer(206514, felEffluxCount))
	end
end

function mod:TankMarker()
	if self:GetOption(tanks_marker) and UnitExists("boss1target") then
		local threat = UnitThreatSituation("boss1target", "boss1")
		if threat and threat > 1 then
			self:SetIcon(tanks_marker, "boss1target", 6)
		end
	end
end

function mod:OnBossDisable()
	if self:GetOption(tanks_marker) then
		for unit in self:IterateGroup() do
			if GetRaidTargetIndex(unit) == 6 then
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
			self:EmpowerSpell(L.bonds, L.emp_bonds, 206221, bondsOfFelCount)
		elseif not hellfireEmpowered then
			hellfireEmpowered = true
			self:EmpowerSpell(L.hellfire, L.emp_hellfire, 206220, liquidHellfireCount)
		elseif not eyesEmpowered then
			eyesEmpowered = true
			self:EmpowerSpell(L.eyes, L.emp_eye, 211152, eyeOfGuldanCount)
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
	elseif spellId == 227260 then
		self:Phase4()
	elseif spellId == 227094 then
		self:FlameCrash()
	elseif spellId == 227035 then
		self:ParasiticWound()
	elseif spellId == 227264 or spellId == 227277 then
		self:ManifestAzzinoth()
	elseif spellId == 221382 then
		self:ChaosSeed()
	elseif spellId == 227283 then
		self:SummonNightorb()
	elseif spellId == 208917 then
		self:TimeStopField()
	end
end

function mod:EmpowerSpell(baseSpell, empSpell, empSpellId, count)
	self:Message(empower, "Neutral", "Info", mod:SpellName(empSpellId), false)
	local unempowered = CL.count:format(baseSpell, count)
	local empowered = CL.count:format(empSpell, count)
	local timer = self:BarTimeLeft(unempowered)
	if timer then
		self:Bar(empSpellId, timer, empowered)
		self:StopBar(unempowered)
	end
end

function mod:CHAT_MSG_MONSTER_YELL(event, msg)
	if msg:find(L.firstTransi) then
		self:FirstTransition()
	elseif msg:find(L.demonWithinStart) and self:Mythic() then
		self:MythicRolePlayEvent()
	end
end

--[[ Stage One ]]--
function mod:LiquidHellfire(args)
	if inTransition then return end
	self:Message(args.spellId, "Urgent", "Alarm", CL.incoming:format(CL.count:format(args.spellName, liquidHellfireCount)))
	liquidHellfireCount = liquidHellfireCount + 1
	local label = args.spellId == 206219 and L.hellfire or L.emp_hellfire
	self:Bar(args.spellId, self:Timer(206219, liquidHellfireCount), CL.count:format(label, liquidHellfireCount))
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
	self:Message(-14897, "Neutral", "Info", nil, false)
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
	self:Message(-14894, "Neutral", "Info", nil, false)
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
	self:Message(-14902, "Neutral", "Info", nil, false)
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
	self:Bar(206219, self:Timer(206219, liquidHellfireCount), CL.count:format(L.hellfire, liquidHellfireCount))
	self:Bar(212258, self:Timer(212258, handOfGuldanCount), CL.count:format(self:SpellName(212258), handOfGuldanCount))
	self:Bar(206222, self:Timer(206222, bondsOfFelCount), CL.count:format(L.bonds, bondsOfFelCount))
	self:Bar(209270, self:Timer(209270, eyeOfGuldanCount), CL.count:format(L.eyes, eyeOfGuldanCount))
end

do
	local felBondsDebuffCount = 0

	function mod:BondsOfFelCast(args)
		self:Message(args.spellId, "Important", "Warning", CL.casting:format(args.spellName))
		felBondsDebuffCount = 0
		bondsOfFelCount = bondsOfFelCount + 1
		local label = args.spellId == 206222 and L.bonds or L.emp_bonds
		self:Bar(args.spellId, self:Timer(206222, bondsOfFelCount), CL.count:format(label, bondsOfFelCount))
	end

	local list = mod:NewTargetList()
	function mod:BondsOfFel(args)
		local key = (args.spellId == 209011) and 206222 or 206221
		felBondsDebuffCount = felBondsDebuffCount + 1
		list[#list + 1] = args.destName
		if #list == 1 then
			self:ScheduleTimer("TargetMessage", 1, key, list, "Important")
		end
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

do
	local eyesActive = 0
	local eyesTargets = {}
	local onMe = 0

	function mod:EyeOfGuldan(args)
		self:Message(args.spellId, "Urgent", "Alert")
		eyesActive = 0
		wipe(eyesTargets)
		onMe = 0
		if self:GetOption(prox_before_eyes) and (self:Ranged() or self:Healer()) then
			self:OpenProximity(args.spellId, 8)
		end
		eyeOfGuldanCount = eyeOfGuldanCount + 1
		local label = args.spellId == 209270 and L.eyes or L.emp_eye
		self:Bar(args.spellId, self:Timer(209270, eyeOfGuldanCount), CL.count:format(label, eyeOfGuldanCount))
	end

	function mod:EyeOfGuldanApplied(args)
		eyesActive = eyesActive + 1
		eyesTargets[#eyesTargets + 1] = args.destName
		self:UpdateEyeProximity(args.spellId)
		if self:Me(args.destGUID) then
			local key = (args.spellId == 209454) and 209270 or 211152
			self:Say(key, "{rt8}")
			self:Flash(key)
			onMe = onMe + 1
		end
	end

	function mod:EyeOfGuldanRemoved(args)
		eyesActive = eyesActive - 1
		for i, target in ipairs(eyesTargets) do
			if UnitIsUnit(target, eyesTargets[i]) then
				table.remove(eyesTargets, i)
				break
			end
		end
		if self:Me(args.destGUID) then
			onMe = onMe - 1
		end
		self:UpdateEyeProximity(args.spellId)
		if eyesActive == 0 then
			self:ScheduleTimer("UpdateEyeProximity", 2.5, args.spellId, true)
		end
	end

	function mod:UpdateEyeProximity(spellId, canClose)
		local key = (spellId == 209454) and 209270 or 211152
		if eyesActive == 0 and canClose then
			self:CloseProximity(key)
		else
			self:OpenProximity(key, 8, onMe < 1 and eyesTargets or nil)
		end
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

--[[ Dreadlords of the Twisting Nether ]] --
function mod:DreadlordSpawn()
	self:Message(-13500, "Neutral", "Info", nil, false)
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
	self:StopBar(CL.count:format(L.emp_hellfire, liquidHellfireCount))
	self:StopBar(CL.count:format(L.emp_bonds, bondsOfFelCount))
	self:StopBar(CL.count:format(L.emp_eye, eyeOfGuldanCount))
	self:Message("stages", "Neutral", "Long", "Second Transition", false)
	self:Bar("stages", 8, CL.stage:format(phase + 1), 227427)
end

function mod:Phase3(args)
	self:TimersCheckpoint()
	phase = 3
	self:Message("stages", "Neutral", "Long", CL.stage:format(phase), false)
	eyeOfGuldanCount = 1
	stormCount = 1
	soulSiphonCount = 1
	harvestCount = 1
	windCount = 1
	soulsRemaining = 0
	self:Bar(211152, self:Timer(209270, eyeOfGuldanCount), CL.count:format(L.emp_eye, eyeOfGuldanCount))
	self:Bar(167819, self:Timer(167819, stormCount), CL.count:format(self:SpellName(167819), stormCount))
	self:Bar(221891, self:Timer(221891, soulSiphonCount))
	self:Bar(206744, self:Timer(206744, harvestCount), CL.count:format(self:SpellName(206744), harvestCount))
	self:Bar(221783, self:Mythic() and 16.6 or 18.2) -- Flames of Sargeras
	if self:Mythic() then
		local windTimer = self:Timer(215125, windCount)
		self:Bar(215125, windTimer)
		self:ScheduleTimer("FelWind", windTimer, 215125)
	end
	self:OpenInfo("infobox", self:SpellName(221891))
	self:SetInfo("infobox", 1, L.remaining)
	self:SetInfo("infobox", 2, soulsRemaining)
end

function mod:FelWind(spellId)
	self:Message(spellId, "Attention", "Long")
	windCount = windCount + 1
	local timer = self:Timer(spellId, windCount)
	if timer then
		self:Bar(spellId, timer)
		self:ScheduleTimer("FelWind", timer, spellId)
	end
end

function mod:StormOfTheDestroyer(args)
	self:Message(args.spellId, "Important", "Long", CL.casting:format(CL.count:format(args.spellName, stormCount)))
	self:Bar(args.spellId, 10, CL.cast:format(args.spellName))
	stormCount = stormCount + 1
	self:Bar(167819, self:Timer(167819, stormCount), CL.count:format(args.spellName, stormCount))
end

do
	local t = 0
	function mod:SoulSiphon(args)
		soulsRemaining = soulsRemaining + 1
		self:SetInfo("infobox", 2, soulsRemaining)
		if GetTime() - t > 5 then
			t = GetTime()
			self:Message(args.spellId, "Attention", "Alert")
			soulSiphonCount = soulSiphonCount + 1
			self:Bar(args.spellId, self:Timer(221891, soulSiphonCount))
		end
	end
end

function mod:WellOfSoulsApplied(args)
	if self:Me(args.destGUID) then
		self:OpenProximity(208802, 5)
	end
end

function mod:WellOfSoulsRemoved(args)
	if self:Me(args.destGUID) then
		self:CloseProximity(208802)
	end
end

do
	local last = 0
	function mod:SoulExplulsion(args)
		if last ~= args.timestamp then
			last = args.timestamp
			soulsRemaining = soulsRemaining - 1
			self:SetInfo("infobox", 2, soulsRemaining)
		end
	end
end

function mod:BlackHarvest(args)
	self:Message(args.spellId, "Urgent", "Alert", CL.incoming:format(args.spellName))
	harvestCount = harvestCount + 1
	self:CDBar(206744, self:Timer(206744, harvestCount), CL.count:format(args.spellName, harvestCount)) -- Black Harvest
	self:ScheduleTimer("ResetSouls", 6)
end

function mod:ResetSouls()
	soulsRemaining = 0
	self:SetInfo("infobox", 2, soulsRemaining)
end

function mod:FlamesOfSargeras(args)
	self:Message(args.spellId, "Urgent", "Warning", CL.incoming:format(args.spellName))
	self:Bar(args.spellId, self:Mythic() and 43.1 or 51.3) -- Flames of Sargeras
	-- Debuffs waves
	local delay = self:Mythic() and 7.4 or 8.7
	self:Bar(args.spellId, delay, CL.next:format(args.spellName))
	self:ScheduleTimer("Bar", delay, args.spellId, delay, CL.next:format(args.spellName))
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

--[[ The Demon Within ]] --
function mod:MythicRolePlayEvent()
	self:Message("stages", "Neutral", "Long", CL.incoming:format(self:SpellName(211439)), false)
	self:Bar("stages", 42.6, 211439) -- Will of the Demon Within
	self:StopBar(26662) -- Gul'dan can no longer berserk once under 10% health
end

function mod:GuldanDeath()
	self:StopBar(CL.count:format(L.emp_eye, eyeOfGuldanCount))
	self:StopBar(CL.count:format(self:SpellName(167819), stormCount))
	self:StopBar(CL.count:format(self:SpellName(206744), harvestCount))
	self:StopBar(221891) -- Soul Siphon
	self:StopBar(221783) -- Flames of Sargeras
	self:CloseInfo("infobox")
end

function mod:Phase4()
	-- We'll just pretend we are in phase 4 without actually updating the phase variable
	-- because it is possible for Gul'dan to still be alive during that phase and we don't
	-- want to fuck up his timers.
	self:Message("stages", "Neutral", "Long", CL.stage:format(4), false)
	parasiticCount = 1
	soulseverCount = 1
	flameCrashCount = 1
	visionsCount = 1
	nightorbCount = 1
	azzinothCount = 1
	lastVisions = GetTime()
	nextVisions = lastVisions + 90
	self:Bar(206847, 4, CL.count:format(self:SpellName(206847), parasiticCount))
	self:Bar(220957, 15, CL.count:format(self:SpellName(220957), soulseverCount))
	self:Bar(227094, 25, CL.count:format(self:SpellName(227094), flameCrashCount))
	self:Bar(226975, 90, CL.count:format(self:SpellName(227008), visionsCount))
	self:Bar(227264, self:Timer(227264, azzinothCount), CL.count:format(self:SpellName(227264), azzinothCount), 195304)
	self:Bar(227283, self:Timer(227283, nightorbCount), CL.count:format(self:SpellName(227283), nightorbCount), 155145)
end

function mod:ParasiticWound()
	parasiticCount = parasiticCount + 1
	if parasiticCount < 11 then
		self:Bar(206847, 36, CL.count:format(self:SpellName(206847), parasiticCount))
	end
end

do
	local list = mod:NewTargetList()
	function mod:ParasiticWoundApplied(args)
		list[#list + 1] = args.destName
		if #list == 1 then
			self:ScheduleTimer("TargetMessage", 0.2, 206847, list, "Important", "Alert", nil, nil, true)
		end
		if self:Me(args.destGUID) then
			self:Flash(206847)
			self:Say(206847)
			local _, _, _, _, _, _, expires = UnitDebuff("player", args.spellName)
			local t = expires - GetTime()
			self:ScheduleTimer("Say", t-3, 206847, 3, true)
			self:ScheduleTimer("Say", t-2, 206847, 2, true)
			self:ScheduleTimer("Say", t-1, 206847, 1, true)
		end
	end
end

function mod:Soulsever(args)
	self:Message(args.spellId, "Urgent", "Warning", CL.casting:format(args.spellName))
	soulseverCount = soulseverCount + 1
	if GetTime() + 20 < nextVisions then
		self:Bar(args.spellId, 20, CL.count:format(args.spellName, soulseverCount))
	end
end

function mod:FlameCrash(spellId)
	self:Message(227094, "Urgent", "Alert")
	flameCrashCount = flameCrashCount + 1
	if GetTime() + 20 < nextVisions then
		self:Bar(227094, 20, CL.count:format(self:SpellName(227094), flameCrashCount))
	end
end

function mod:ManifestAzzinoth()
	self:Message(227264, "Neutral", "Info", nil, 195304)
	self:CDBar(221382, 7) -- Chaos Seed
	azzinothCount = azzinothCount + 1
	self:Bar(227264, self:Timer(227264, azzinothCount), CL.count:format(self:SpellName(227264), azzinothCount), 195304)
end

do
	local t = 0
	function mod:ChaosSeed()
		if GetTime() - t > 1 then
			t = GetTime()
			self:Message(221382, "Attention", "Alert")
			self:Bar(221382, 10)
		end
	end
end

function mod:AzzinothDeath()
	self:StopBar(221382) -- Chaos Seed
end

function mod:SummonNightorb()
	self:Message(227283, "Neutral", "Info", nil, 155145)
	nightorbCount = nightorbCount + 1
	self:Bar(227283, self:Timer(227283, nightorbCount), CL.count:format(self:SpellName(227283), nightorbCount), 155145)
end

function mod:TimeStopField()
	self:Message(211832, "Positive", "Info")
	self:Bar(211832, 10, CL.over:format(self:SpellName(211832)))
end

function mod:PurifiedEssence(args)
	self:Message(args.spellId, "Important", "Long", CL.incoming:format(args.spellName))
	self:Bar(args.spellId, 4)
end

function mod:VisionsOfTheDarkTitan(args)
	self:Message(args.spellId, "Urgent", "Long", CL.incoming:format(args.spellName))
	visionsCount = visionsCount + 1
	if visionsCount < 4 then
		lastVisions = GetTime()
		nextVisions = lastVisions + (visionsCount < 3 and 90 or 150)
		if visionsCount < 3 then
			self:Bar(args.spellId, 90, CL.count:format(args.spellName, visionsCount))
		else
			self:Bar("berserk", 150, 26662)
		end
	end
end

function mod:VisionsOfTheDarkTitanStart(args)
	self:Bar(visions_cast, 9, CL.cast:format(args.spellName), 226975)
end

function mod:Wounded()
	local now = GetTime()
	local nextSoulsever = lastVisions + 35
	local nextFlameCrash = lastVisions + 45
	local removeTime = now + 15
	if removeTime > (nextSoulsever - 10) then
		nextSoulsever = nextSoulsever + 20
	end
	self:Bar(220957, nextSoulsever - now, CL.count:format(self:SpellName(220957), soulseverCount))
	self:Bar(227094, nextFlameCrash - now, CL.count:format(self:SpellName(227094), flameCrashCount))
end

--[[ Generic Damage Warnings ]] --
do
	local mapping = {
		[206515] = 206514, -- Fel Efflux
		[209518] = 209270, -- Eye of Guldan
		[211132] = 211152, -- Empowered Eye of Gul'dan
		[221326] = 221382,
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
