
--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("The Coven of Shivarra", 1712, 1986)
if not mod then return end
mod:RegisterEnableMob(122468, 122467, 122469, 125436) -- Noura, Asara, Diima, Thu'raya
mod.engageId = 2073
mod.respawnTime = 21

--------------------------------------------------------------------------------
-- Locals
--

local Hud = Oken.Hud

local shivanPactCount = 0
local TORMENT_AURA_DURATION = 5

local infoboxScheduled = nil
local chilledBloodTime = 0
local chilledBloodList = {}
local chilledBloodMaxAbsorb = 1
local bloodBarPlacement = 0
local tormentIcons = {
	AmanThul = 139, -- Renew
	Norgannon = 245910, -- Army
	Khazgoroth = 245671, -- Flames
	Golganneth = 421, -- Chain Lightning
}
local upcomingTorments = {}

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then
	L.torment_of_the_titans = mod:SpellName(-16138) -- Torment of the Titans
	L.torment_of_the_titans_desc = "The Shivvara will force the titan souls to use their abilities against the players."
	L.torment_of_the_titans_icon = 245910 -- Spectral Army of Norgannon

	L.timeLeft = "%.1fs"
	L.torment = "Torment: %s"
	L.nextTorment = "Next Torment: |cffffffff%s|r"
	L.tormentHeal = "Self Heal"
	L.tormentLightning = "Spread" -- short for Chain Lightning
	L.tormentArmy = "Walls"
	L.tormentFlames = "Flames"
end

--------------------------------------------------------------------------------
-- Initialization
--

local cleave_hud = mod:AddCustomOption { "cleave_hud", "Display a Cleave HUD on Noura, Mother of Flame" }
local cosmicGlareMarker = mod:AddMarkerOption(true, "player", 3, 250912, 3,4)
function mod:GetOptions()
	return {
		--[[ General ]]--
		"stages",
		"berserk",
		"infobox",
		{253203, "AURA"}, -- Shivan Pact
		{"torment_of_the_titans", "AURA"},
		{246763, "HUD"}, -- Fury of Golganneth

		--[[ Noura, Mother of Flame ]]--
		{244899, "TANK"}, -- Fiery Strike
		245627, -- Whirling Saber
		{253520, "SAY", "AURA"}, -- Fulminating Pulse
		cleave_hud,

		--[[ Asara, Mother of Night ]]--
		{246329, "HUD"}, -- Shadow Blades
		252861, -- Storm of Darkness

		--[[ Diima, Mother of Gloom ]]--
		{245518, "TANK_HEALER"}, -- Flashfreeze
		{245586, "SMARTCOLOR", "INFOBOX"}, -- Chilled Blood
		253650, -- Orb of Frost

		--[[ Thu'raya, Mother of the Cosmos (Mythic) ]]--
		{250648, "IMPACT"}, -- Touch of the Cosmos
		{250757, "SAY", "FLASH", "AURA"}, -- Cosmic Glare
		cosmicGlareMarker,
	},{
		["stages"] = "general",
		[244899] = -15967, -- Noura, Mother of Flame
		[246329] = -15968, -- Asara, Mother of Night
		[245518] = -15969, -- Diima, Mother of Gloom
		[250648] = -16398, -- Thu'raya, Mother of the Cosmos
	}
end

function mod:OnBossEnable()
	--[[ General ]]--
	self:RegisterUnitEvent("UNIT_TARGETABLE_CHANGED", nil, "boss1", "boss2", "boss3", "boss4")
	self:Log("SPELL_AURA_APPLIED", "ShivanPact", 253203)
	self:Log("SPELL_AURA_REMOVED", "ShivanPactRemoved", 253203)
	self:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1", "boss2", "boss3", "boss4")
	self:Log("SPELL_CAST_SUCCESS", "TormentofAmanThul", 250335)
	self:Log("SPELL_CAST_SUCCESS", "TormentofKhazgoroth", 250333)
	self:Log("SPELL_CAST_SUCCESS", "TormentofGolganneth", 249793)
	self:Log("SPELL_CAST_SUCCESS", "TormentofNorgannon", 250334)

	--[[ Noura, Mother of Flame ]]--
	self:Log("SPELL_AURA_APPLIED", "FieryStrike", 244899)
	self:Log("SPELL_AURA_APPLIED_DOSE", "FieryStrike", 244899)
	self:Log("SPELL_CAST_SUCCESS", "FieryStrikeSuccess", 244899)
	self:Log("SPELL_CAST_START", "WhirlingSaber", 245627)
	self:Log("SPELL_AURA_APPLIED", "FulminatingPulse", 253520)
	self:Log("SPELL_AURA_REMOVED", "FulminatingPulseRemoved", 253520)

	--[[ Asara, Mother of Night ]]--
	self:Log("SPELL_CAST_SUCCESS", "ShadowBlades", 246329)
	self:Log("SPELL_CAST_START", "StormofDarkness", 252861)

	--[[ Diima, Mother of Gloom ]]--
	self:Log("SPELL_CAST_SUCCESS", "FlashfreezeSuccess", 245518)
	self:Log("SPELL_AURA_APPLIED", "Flashfreeze", 245518)
	self:Log("SPELL_AURA_APPLIED_DOSE", "Flashfreeze", 245518)
	self:Log("SPELL_AURA_APPLIED", "ChilledBlood", 245586)
	self:Log("SPELL_AURA_REMOVED", "ChilledBloodRemoved", 245586)
	self:Log("SPELL_CAST_START", "OrbofFrost", 253650)

	--[[ Thu'raya, Mother of the Cosmos (Mythic) ]]--
	self:Log("SPELL_CAST_START", "TouchoftheCosmos", 250648)
	self:Log("SPELL_INTERRUPT", "TouchoftheCosmosInterupted", "*")
	self:Log("SPELL_AURA_APPLIED", "CosmicGlare", 250757)
	self:Log("SPELL_AURA_REMOVED", "CosmicGlareRemoved", 250757)

	self:Log("SPELL_AURA_APPLIED", "FuryOfGolganneth", 246763)
	self:Log("SPELL_AURA_REMOVED", "FuryOfGolgannethRemoved", 246763)

	--[[ Ground effects ]]--
	self:Log("SPELL_AURA_APPLIED", "GroundEffectDamage", 245634, 253020) -- Whirling Saber, Storm of Darkness
	self:Log("SPELL_PERIODIC_DAMAGE", "GroundEffectDamage", 245634, 253020)
	self:Log("SPELL_PERIODIC_MISSED", "GroundEffectDamage", 245634, 253020)
	self:Log("SPELL_DAMAGE", "GroundEffectDamage", 245629) -- Whirling Saber (Impact)
	self:Log("SPELL_MISSED", "GroundEffectDamage", 245629)
end

function mod:OnEngage()
	shivanPactCount = 0
	chilledBloodTime = 0
	bloodBarPlacement = 0
	wipe(chilledBloodList)
	chilledBloodMaxAbsorb = 1
	wipe(upcomingTorments)

	self:Bar(245627, 8.5) -- Whirling Saber
	self:Bar(244899, 12.1) -- Fiery Strike
	if not self:Easy() then
		self:Bar(253520, 20.6) -- Fulminating Pulse
	end

	self:Bar(246329, 12.1) -- Shadow Blades
	if not self:Easy() then
		self:Bar(252861, 27.9) -- Storm of Darkness
	end

	self:CDBar("torment_of_the_titans", 82, L.torment_of_the_titans, L.torment_of_the_titans_icon)
	self:CDBar("stages", 190, -15969, "achievement_boss_argus_shivan") -- Diima, Mother of Gloom

	if self:GetOption(cleave_hud) then
		self:ScheduleTimer("NouraHUD", 2)
	end

	self:Berserk(720)
end

function mod:NouraHUD()
	for i = 1, 4 do
		local guid = UnitGUID("boss" .. i)
		if guid and self:MobId(guid) == 122468 then -- Noura, Mother of Flames
			Hud:DrawArea(guid, 60):SetColor(1, 0.2, 0.2, 1):SetOffset(0, -150)
			Hud:DrawText(guid, "Cleave"):SetOffset(0, -150)
			break
		end
	end
end

--------------------------------------------------------------------------------
-- Event Handlers
--

local updateInfoBox
do
	local tormentMarkup = {
		AmanThul = {color = "|cff81c784", text = "tormentHeal", icon = GetSpellTexture(tormentIcons.AmanThul)},
		Norgannon = {color = "|cff9575cd", text = "tormentArmy", icon = GetSpellTexture(tormentIcons.Norgannon)},
		Khazgoroth = {color = "|cffe57373", text = "tormentFlames", icon = GetSpellTexture(tormentIcons.Khazgoroth)},
		Golganneth = {color = "|cff4fc3f7", text = "tormentLightning", icon = GetSpellTexture(tormentIcons.Golganneth)},
	}

	local sort, min, sortFunc = table.sort, math.min, function(a, b)
		return a[2] > b[2]
	end
	function updateInfoBox()
		local showTorments = next(upcomingTorments)
		local showChilledBlood = mod:CheckOption(245586, "INFOBOX")
		local bloodOffset = 0

		-- Torment
		if showTorments then
			mod:OpenInfo("infobox", L.nextTorment:format(""))

			local nextTorment = tormentMarkup[upcomingTorments[1]]
			local data = ("|T%s:15:15:0:0:64:64:4:60:4:60|t%s%s|r"):format(nextTorment.icon, nextTorment.color, L[nextTorment.text])
			mod:SetInfo("infobox", 1, data)
			bloodOffset = 2
		end

		-- Chilled Blood
		if showChilledBlood then
			local timeLeft = chilledBloodTime - GetTime()

			if #chilledBloodList > 0 and timeLeft > 0 then
				if not showTorments then
					mod:OpenInfo("infobox", mod:SpellName(245586))
				end

				bloodBarPlacement = bloodOffset+1
				mod:SetInfo("infobox", bloodBarPlacement, "|cffffffff" .. mod:SpellName(245586))
				mod:SetInfo("infobox", bloodOffset+2, L.timeLeft:format(timeLeft))
				mod:SetInfoBar("infobox", bloodBarPlacement, timeLeft/10)

				sort(chilledBloodList, sortFunc)

				for i = 1, min((8-bloodOffset)/2, 3) do
					if chilledBloodList[i] then
						local player = chilledBloodList[i][1]
						local icon = GetRaidTargetIndex(player)
						mod:SetInfo("infobox", bloodOffset+1+i*2, (icon and ("|T13700%d:0|t"):format(icon) or "") .. mod:ColorName(player))
						mod:SetInfo("infobox", bloodOffset+2+i*2, mod:AbbreviateNumber(chilledBloodList[i][2]))
						mod:SetInfoBar("infobox", bloodOffset+1+i*2, chilledBloodList[i][2] / chilledBloodMaxAbsorb)
					else
						mod:SetInfo("infobox", bloodOffset+1+i*2, "")
						mod:SetInfo("infobox", bloodOffset+2+i*2, "")
						mod:SetInfoBar("infobox", bloodOffset+1+i*2, 0)
					end
				end
			else
				showChilledBlood = nil
			end
		end

		if not showChilledBlood and not showTorments then
			mod:CloseInfo("infobox")
		end
	end
end

--[[ General ]]--
function mod:UNIT_TARGETABLE_CHANGED(_, unit)
	if self:MobId(UnitGUID(unit)) == 122468 then -- Noura
		if UnitCanAttack("player", unit) then
			self:Message("stages", "green", "Long", -15967, false) -- Noura, Mother of Flame
			self:Bar(245627, 8.9) -- Whirling Saber
			self:Bar(244899, 12.5) -- Fiery Strike
			if not self:Easy() then
				self:Bar(253520, 21.1) -- Fulminating Pulse
			end
			self:StopBar(-15967) -- Noura, Mother of Flame
			if self:Mythic() then
				self:CDBar("stages", 46, -15968, "achievement_boss_argus_shivan") -- Asara, Mother of Night
			end
		else
			self:StopBar(244899) -- Fiery Strike
			self:StopBar(245627) -- Whirling Saber
			self:StopBar(253520) -- Fulminating Pulse
		end
	elseif self:MobId(UnitGUID(unit)) == 122467 then -- Asara
		if UnitCanAttack("player", unit) then
			self:Message("stages", "green", "Long", -15968, false) -- Asara, Mother of Night
			self:Bar(246329, 12.6) -- Shadow Blades
			if not self:Easy() then
				self:Bar(252861, 28.4) -- Storm of Darkness
			end
			self:StopBar(-15968) -- Asara, Mother of Night
		else
			self:StopBar(246329) -- Shadow Blades
			self:StopBar(252861) -- Storm of Darkness
		end
	elseif self:MobId(UnitGUID(unit)) == 122469 then -- Diima
		if UnitCanAttack("player", unit) then
			self:Message("stages", "green", "Long", -15969, false) -- Diima, Mother of Gloom
			self:Bar(245586, 8) -- Chilled Blood
			self:Bar(245518, 12.2) -- Flashfreeze
			if not self:Easy() then
				self:Bar(253650, 30) -- Orb of Frost
			end
			self:StopBar(-15969) -- Diima, Mother of Gloom
			if self:Mythic() then
				self:CDBar("stages", 46, -16398, "achievement_boss_argus_shivan") -- Thu'raya, Mother of the Cosmos
			else
				self:CDBar("stages", 185, -15967, "achievement_boss_argus_shivan") -- Noura, Mother of Flame
			end
		else
			self:StopBar(245518) -- Flashfreeze
			self:StopBar(245586) -- Chilled Blood
			self:StopBar(253650) -- Orb of Frost
		end
	elseif self:MobId(UnitGUID(unit)) == 125436 then -- Thu'raya
		if UnitCanAttack("player", unit) then
			self:Message("stages", "green", "Long", -16398, false) -- Thu'raya, Mother of the Cosmos
			self:Bar(250757, 5.2) -- Cosmic Glare
			self:StopBar(-16398) -- Thu'raya, Mother of the Cosmos
			self:CDBar("stages", 142, -15967, "achievement_boss_argus_shivan") -- Noura, Mother of Flame
		else
			self:StopBar(250757) -- Cosmic Glare
		end
	end
end

do
	local prev = 0
	function mod:ShivanPact(args)
		local t = GetTime()
		if t-prev > 1.5 then
			prev = t
			self:Message(args.spellId, "red", "Info")
		end
		if shivanPactCount == 0 then
			self:ShowAura(args.spellId, "Shivan Pact", { pulse = false })
		end
		shivanPactCount = shivanPactCount + 1
	end

	function mod:ShivanPactRemoved(args)
		shivanPactCount = shivanPactCount - 1
		if shivanPactCount == 0 then
			self:HideAura(args.spellId)
		end
	end
end

function mod:CHAT_MSG_RAID_BOSS_EMOTE(_, msg)
	if msg:find("250095", nil, true) then -- Machinations of Aman'thul
		self:Message("torment_of_the_titans", "orange", nil, CL.soon:format(L.torment:format(L.tormentHeal)), tormentIcons["AmanThul"])
		self:ShowAura("torment_of_the_titans", L.tormentHeal, { icon = self:SpellIcon(250095), key = "amanthul", autoremove = TORMENT_AURA_DURATION })
	elseif msg:find("245671", nil, true) then -- Flames of Khaz'goroth
		self:Message("torment_of_the_titans", "orange", nil, CL.soon:format(L.torment:format(L.tormentFlames)), tormentIcons["Khazgoroth"])
		self:ShowAura("torment_of_the_titans", L.tormentFlames, { icon = self:SpellIcon(245671), key = "kazgoroth", autoremove = TORMENT_AURA_DURATION })
	elseif msg:find("246763", nil, true) then -- Fury of Golganneth
		self:Message("torment_of_the_titans", "orange", nil, CL.soon:format(L.torment:format(L.tormentLightning)), tormentIcons["Golganneth"])
		self:ShowAura("torment_of_the_titans", L.tormentLightning, { icon = self:SpellIcon(246763), key = "golganneth", autoremove = TORMENT_AURA_DURATION })
		self:StartFuryHUD()
	elseif msg:find("245910", nil, true) then -- Spectral Army of Norgannon
		self:Message("torment_of_the_titans", "orange", nil, CL.soon:format(L.torment:format(L.tormentArmy)), tormentIcons["Norgannon"])
		self:ShowAura("torment_of_the_titans", L.tormentArmy, { icon = self:SpellIcon(245910), key = "norgannon", autoremove = TORMENT_AURA_DURATION })
	end
end

do
	local tormentLocaleLookup = {
		["AmanThul"] = "tormentHeal",
		["Norgannon"] = "tormentArmy",
		["Khazgoroth"] = "tormentFlames",
		["Golganneth"] = "tormentLightning",
	}

	function mod:UNIT_SPELLCAST_SUCCEEDED(_, _, _, spellId)
		local announceNextTorment = nil
		if spellId == 253949 then -- Machinations of Aman'thul
			self:StopBar(L.torment:format(L.tormentHeal))
			tDeleteItem(upcomingTorments, "AmanThul")
			self:Message("torment_of_the_titans", "red", "Warning", L.torment:format(L.tormentHeal), tormentIcons["AmanThul"])
			updateInfoBox()
			announceNextTorment = true
		elseif spellId == 253881 then -- Flames of Khaz'goroth
			self:StopBar(L.torment:format(L.tormentFlames))
			tDeleteItem(upcomingTorments, "Khazgoroth")
			self:Message("torment_of_the_titans", "red", "Warning", L.torment:format(L.tormentFlames), tormentIcons["Khazgoroth"])
			updateInfoBox()
			announceNextTorment = true
		elseif spellId == 253951 then  -- Fury of Golganneth
			self:StopBar(L.torment:format(L.tormentLightning))
			tDeleteItem(upcomingTorments, "Golganneth")
			self:Message("torment_of_the_titans", "red", "Warning", L.torment:format(L.tormentLightning), tormentIcons["Golganneth"])
			updateInfoBox()
			announceNextTorment = true
		elseif spellId == 253950 then -- Spectral Army of Norgannon
			self:StopBar(L.torment:format(L.tormentArmy))
			tDeleteItem(upcomingTorments, "Norgannon")
			self:Message("torment_of_the_titans", "red", "Warning", L.torment:format(L.tormentArmy), tormentIcons["Norgannon"])
			updateInfoBox()
			announceNextTorment = true
		end
		if announceNextTorment and #upcomingTorments == 1 then
			local nextTorment = upcomingTorments[1]
			self:ScheduleTimer("Message", 5, "torment_of_the_titans", "cyan", "Info", L.nextTorment:format(L[tormentLocaleLookup[nextTorment]]), tormentIcons[nextTorment])
		end
	end
end

function mod:TormentofAmanThul()
	self:StopBar(L.torment_of_the_titans)
	upcomingTorments[#upcomingTorments+1] = "AmanThul"
	if #upcomingTorments == 1 then
		self:Message("torment_of_the_titans", "cyan", "Info", L.nextTorment:format(L.tormentHeal), tormentIcons["AmanThul"])
	end
	self:Bar("torment_of_the_titans", 90, L.torment:format(L.tormentHeal), tormentIcons["AmanThul"])
	updateInfoBox()
end

function mod:TormentofKhazgoroth()
	self:StopBar(L.torment_of_the_titans)
	upcomingTorments[#upcomingTorments+1] = "Khazgoroth"
	if #upcomingTorments == 1 then
		self:Message("torment_of_the_titans", "cyan", "Info", L.nextTorment:format(L.tormentFlames), tormentIcons["Khazgoroth"])
	end
	self:Bar("torment_of_the_titans", 90, L.torment:format(L.tormentFlames), tormentIcons["Khazgoroth"])
	updateInfoBox()
end

function mod:TormentofGolganneth()
	self:StopBar(L.torment_of_the_titans)
	upcomingTorments[#upcomingTorments+1] = "Golganneth"
	if #upcomingTorments == 1 then
		self:Message("torment_of_the_titans", "cyan", "Info", L.nextTorment:format(L.tormentLightning), tormentIcons["Golganneth"])
	end
	self:Bar("torment_of_the_titans", 90, L.torment:format(L.tormentLightning), tormentIcons["Golganneth"])
	updateInfoBox()
end

function mod:TormentofNorgannon()
	self:StopBar(L.torment_of_the_titans)
	upcomingTorments[#upcomingTorments+1] = "Norgannon"
	if #upcomingTorments == 1 then
		self:Message("torment_of_the_titans", "cyan", "Info", L.nextTorment:format(L.tormentArmy), tormentIcons["Norgannon"])
	end
	self:Bar("torment_of_the_titans", 90, L.torment:format(L.tormentArmy), tormentIcons["Norgannon"])
	updateInfoBox()
end

--[[ Noura, Mother of Flame ]]--
function mod:FieryStrike(args)
	local amount = args.amount or 1
	if self:Me(args.destGUID) or amount > 2 then -- Swap above 2, always display stacks on self
		self:StackMessage(args.spellId, args.destName, amount, "cyan", "Info")
	end
end

function mod:FieryStrikeSuccess(args)
	self:Bar(args.spellId, 10.9)
end

function mod:WhirlingSaber(args)
	self:Message(args.spellId, "yellow", "Alert", CL.incoming:format(args.spellName))
	self:Bar(args.spellId, 35.3)
end

do
	local playerList = mod:NewTargetList()
	function mod:FulminatingPulse(args)
		if self:Me(args.destGUID) then
			self:Say(args.spellId)
			self:SayCountdown(args.spellId, 10)
			self:PlaySound(args.spellId, "Alarm")
			self:ShowAura(args.spellId, 10, "Move")
		end
		playerList[#playerList+1] = args.destName
		self:TargetsMessage(args.spellId, "red", playerList, 3)
		if #playerList == 1 then
			self:Bar(args.spellId, 40.1)
		end
	end

	function mod:FulminatingPulseRemoved(args)
		if self:Me(args.destGUID) then
			self:CancelSayCountdown(args.spellId)
			self:HideAura(args.spellId)
		end
	end
end

--[[ Asara, Mother of Night ]]--
function mod:ShadowBlades(args)
	self:Message(args.spellId, "yellow", "Alert")
	self:CDBar(args.spellId, 29.2)
	if self:Hud(args.spellId) then
		local area = Hud:DrawArea(args.sourceGUID, 60):SetColor(0.8, 0.5, 1):SetOffset(0, -150)
		local spinner = Hud:DrawSpinner(args.sourceGUID, 70, 4):SetColor(0.8, 0.5, 1):SetOffset(0, -150)
		local text = Hud:DrawText(args.sourceGUID, "Blades"):SetOffset(0, -150)
		C_Timer.After(4, function()
			area:Remove()
			spinner:Remove()
			text:Remove()
		end)
	end
end

function mod:StormofDarkness(args)
	self:Message(args.spellId, "red", "Alarm")
	self:Bar(args.spellId, 58.5)
end

--[[ Diima, Mother of Gloom ]]--
function mod:Flashfreeze(args)
	local amount = args.amount or 1
	if self:Me(args.destGUID) then
		self:StackMessage(args.spellId, args.destName, amount, "cyan", "Info")
	end
end

function mod:FlashfreezeSuccess(args)
	self:Bar(args.spellId, 10.9)
end

do
	local colorUpdater
	local maxAmount = -1
	local lastStatus = -1

	local playerList = mod:NewTargetList()

	local function UpdateChilledBloodInfoBoxTimeLeft()
		if chilledBloodList[1] then
			local timeLeft = chilledBloodTime - GetTime()
			mod:SetInfoBar("infobox", bloodBarPlacement, timeLeft/10)
			mod:SetInfo("infobox", bloodBarPlacement+1, L.timeLeft:format(timeLeft))
			mod:SimpleTimer(UpdateChilledBloodInfoBoxTimeLeft, 0.1)
		end
	end

	do
		local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
		function mod:UpdateChilledBloodInfoBoxAbsorbs()
			local _, subEvent, _, _, _, _, _, _, destName, _, _, spellId, _, _, _, _, _, _, _, _, _, absorbed = CombatLogGetCurrentEventInfo()
			if subEvent == "SPELL_HEAL_ABSORBED" and spellId == 245586 then -- Chilled Blood
				for i = 1, #chilledBloodList do
					if chilledBloodList[i][1] == destName then
						chilledBloodList[i][2] = chilledBloodList[i][2] - absorbed
						updateInfoBox()
						break
					end
				end
			end
		end
	end

	function mod:ChilledBlood(args)
		playerList[#playerList+1] = args.destName
		chilledBloodList[#chilledBloodList+1] = {args.destName, args.amount}

		if self:Healer() then -- Always play a sound for healers
			self:PlaySound(args.spellId, "Alarm", nil, playerList)
		elseif self:Me() then
			self:PlaySound(args.spellId, "Alarm")
		end

		self:TargetsMessage(args.spellId, "green", playerList, 3)
		if #playerList == 1 then
			chilledBloodTime = GetTime() + 10
			chilledBloodMaxAbsorb = args.amount
			self:Bar(args.spellId, 25.5)
			if self:CheckOption(args.spellId, "INFOBOX") then
				self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "UpdateChilledBloodInfoBoxAbsorbs")
				self:SimpleTimer(UpdateChilledBloodInfoBoxTimeLeft, 0.1)
			end
		end

		local debuff, _, _, _, value = self:UnitDebuff(args.destName, args.spellId)
		if debuff and value and value > 0 then
			chilledBloodList[#chilledBloodList+1] = {args.destName, value}
			chilledBloodMaxAbsorb = math.max(chilledBloodMaxAbsorb, value)
		end
		if self:Me(args.destGUID) then
			lastStatus = -1
			colorUpdater = self:ScheduleRepeatingTimer("CheckShieldStatus", 0.2, args.spellId, args.spellName)
			self:CheckShieldStatus(args.spellId, args.spellName)
		end
	end

	function mod:CheckShieldStatus(spellId, spellName)
		local amount = select(5, self:UnitDebuff("player", spellId))
		if not amount then return end
		if lastStatus == -1 then maxAmount = amount end
		local status = math.ceil(10 * amount / maxAmount) / 10
		if status ~= lastStatus then
			lastStatus = status
			local r, g, b = Oken:ColorGradient(status, 0.2, 0.8, 0.2, 0.8, 0.8, 0.2, 1, 0.2, 0.2)
			self:SmartColorSet(spellId, r, g, b)
		end
	end

	function mod:ChilledBloodRemoved(args)
		for i = #chilledBloodList, 1, -1 do
			if chilledBloodList[i][1] == args.destName then
				tremove(chilledBloodList, i)
			end
		end
		if self:Me(args.destGUID) then
			self:CancelTimer(colorUpdater)
			self:SmartColorUnset(args.spellId)
		end
		updateInfoBox()
	end
end

function mod:OrbofFrost(args)
	self:Message(args.spellId, "yellow", "Alert")
	self:Bar(args.spellId, 30.4)
end

--[[ Thu'raya, Mother of the Cosmos (Mythic) ]]--
function mod:TouchoftheCosmos(args)
	if self:Interrupter() then
		self:Message(args.spellId, "orange", "Alarm")
		self:ImpactBar(args.spellId, 2.5)
	end
end

function mod:TouchoftheCosmosInterupted(args)
	if args.extraSpellId == 250648 then
		self:StopImpactBar(args.extraSpellName)
	end
end

do
	local playerList = mod:NewTargetList()
	function mod:CosmicGlare(args)
		if self:Me(args.destGUID) then
			self:Flash(args.spellId)
			self:Say(args.spellId)
			self:SayCountdown(args.spellId, 4)
			self:ShowAura(args.spellId, 4, "Link")
			self:PlaySound(args.spellId, "Alarm")
		end

		playerList[#playerList+1] = args.destName

		self:TargetsMessage(args.spellId, "yellow", playerList, 2)
		if #playerList == 1 then
			self:CDBar(args.spellId, 15)
			if self:GetOption(cosmicGlareMarker) then
				SetRaidTarget(args.destName, 3)
			end
		elseif self:GetOption(cosmicGlareMarker) then
			SetRaidTarget(args.destName, 4)
		end
	end
end

function mod:CosmicGlareRemoved(args)
	if self:Me(args.destGUID) then
		self:CancelSayCountdown(args.spellId)
		self:HideAura(args.spellId)
	end
	if self:GetOption(cosmicGlareMarker) then
		SetRaidTarget(args.destName, 0)
	end
end

do
	local rangeCheck
	local rangeObject

	function mod:CheckFuryRange()
		for unit in mod:IterateGroup() do
			if not UnitIsUnit(unit, "player") and not UnitIsDead(unit) and mod:Range(unit) <= 5 then
				rangeObject:SetColor(1, 0.2, 0.2)
				return
			end
		end
		rangeObject:SetColor(0.2, 1, 0.2)
	end

	function mod:StartFuryHUD()
		if self:Hud(246763) and not rangeObject then
			rangeObject = Hud:DrawSpinner("player", 50)
			rangeCheck = self:ScheduleRepeatingTimer("CheckFuryRange", 0.1)
			self:CheckFuryRange()
		end
	end

	function mod:FuryOfGolganneth(args)
		if self:Me(args.destGUID) then
			self:StartFuryHUD()
		end
	end

	function mod:FuryOfGolgannethRemoved(args)
		if self:Me(args.destGUID) and rangeObject then
			if rangeObject then
				self:CancelTimer(rangeCheck)
				rangeObject:Remove()
				rangeObject = nil
			end
		end
	end
end


--[[ Ground effects ]]--
do
	local prev = 0
	local optionIds = {
		[245629] = 245627, -- Whirling Saber
		[245634] = 245627, -- Whirling Saber
		[253020] = 252861, -- Storm of Darkness
	}
	function mod:GroundEffectDamage(args)
		local t = GetTime()
		if self:Me(args.destGUID) and t-prev > 1.5 then
			prev = t
			self:Message(optionIds[args.spellId] or args.spellId, "blue", "Alert", CL.underyou:format(args.spellName))
		end
	end
end
