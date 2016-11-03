
--------------------------------------------------------------------------------
-- TODO List:


--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Guarm-TrialOfValor", 1114, 1830)
if not mod then return end
mod:RegisterEnableMob(114323)
mod.engageId = 1962
mod.respawnTime = 15
mod.instanceId = 1648

--------------------------------------------------------------------------------
-- Locals
--



--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then
	L.foam_ok = "[FOAM] %s => OK!"
	L.foam_multiple = "[FOAM] %s => Multiple Foams!"
	L.foam_moveto_melee = "[FOAM] %s => Move to {rt%d} (melee)"
	L.foam_moveto = "[FOAM] %s => Move to {rt%d} %s"
	L.foam_soakby = "[FOAM] %s {rt%d} <= Soaked by %s"
	L.foam_noavail = "[FOAM] %s => No soaker available?"
	L.foam_noicon = "[FOAM] %s => No icon available?"
end

--------------------------------------------------------------------------------
-- Initialization
--

local foams_ai = mod:AddTokenOption { "foams_ai", "Automatically call movements for Volatile Foams dispells.", promote = true }

function mod:GetOptions()
	return {
		228248, -- Frost Lick
		228253, -- Shadow Lick
		228228, -- Flame Lick
		{228187, "FLASH"}, -- Guardian's Breath
		227514, -- Flashing Fangs
		227816, -- Headlong Charge
		227883, -- Roaring Leap
		foams_ai,
		"berserk"
	}
end

function mod:OnBossEnable()
	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")

	self:Log("SPELL_AURA_APPLIED", "FrostLick", 228248)
	self:Log("SPELL_AURA_APPLIED", "ShadowLick", 228253)
	self:Log("SPELL_AURA_APPLIED", "FlameLick", 228228)

	self:Log("SPELL_CAST_START", "GuardiansBreath", 227669, 227658, 227660, 227666, 227673, 227667)
	self:Log("SPELL_CAST_START", "FlashingFangs", 227514)

	self:Log("SPELL_CAST_SUCCESS", "HeadlongCharge", 227816)

	self:Log("SPELL_CAST_SUCCESS", "RoaringLeap", 227883)

	self:Log("SPELL_CAST_SUCCESS", "VolatileFoamCast", 227883)
	self:Log("SPELL_AURA_APPLIED", "VolatileFoamApplied", 228744, 228810, 228818, 228794, 228811, 228819) -- Flaming, Briney, Shadowy + echoes
	self:Log("SPELL_AURA_REMOVED", "VolatileFoamRemoved", 228744, 228810, 228818, 228794, 228811, 228819)
	self:RegisterNetMessage("VolatileFoamRanges")
	self:RegisterNetMessage("VolatileFoamMove")
end

function mod:OnEngage()
	if not self:LFR() then -- Probably longer on LFR
		self:Berserk(242)
	end
	self:Bar(228187, 13) -- Guardian's Breath
end

--------------------------------------------------------------------------------
-- Event Handlers
--

do
	local list = mod:NewTargetList()
	function mod:FrostLick(args)
		list[#list+1] = args.destName
		if #list == 1 then
			self:ScheduleTimer("TargetMessage", 0.4, args.spellId, list, "Urgent", "Alarm")
		end
	end
end

do
	local list = mod:NewTargetList()
	function mod:ShadowLick(args)
		list[#list+1] = args.destName
		if #list == 1 then
			self:ScheduleTimer("TargetMessage", 0.4, args.spellId, list, "Urgent", "Alarm")
		end
	end
end

do
	local list = mod:NewTargetList()
	function mod:FlameLick(args)
		list[#list+1] = args.destName
		if #list == 1 then
			self:ScheduleTimer("TargetMessage", 0.4, args.spellId, list, "Urgent", "Alarm")
		end
	end
end

function mod:GuardiansBreath(args)
	self:Message(228187, "Attention", "Warning")
	self:Bar(228187, 5, CL.cast:format(args.spellName))
	self:Flash(228187)
end

function mod:FlashingFangs(args)
	self:Message(args.spellId, "Positive", self:Melee() and "Alert")
end

function mod:HeadlongCharge(args)
	self:Message(args.spellId, "Important", "Long")
end

function mod:RoaringLeap(args)
	self:Message(args.spellId, "Urgent", "Info")
end

--------------------------------------------------------------------------------
-- Volatile Foams
--

do
	local UnitGUID, UnitDebuff = UnitGUID, UnitDebuff

	-- Mobilities
	local mobilities = {
		[105] = 13, -- Druid Resto
		[65] = 12, -- Paladin Holy
		[264] = 12, -- Shaman Resto
		[257] = 11, -- Priest Holy
		[256] = 11, -- Priest Discipline
		[270] = 11, -- Monk Mistweaver
		[253] = 10, -- Hunter BM
		[63] = 7, -- Mage Fire
		[62] = 6, -- Mage Arcane
		[254] = 5, -- Hunter Marksman
		[258] = function(unit) return UnitBuff(unit, mod:SpellName(193223)) and 9 or 5 end, -- Priest Shadow
		[262] = 2, -- Shaman Elemental
		[267] = 1, -- Warlock Destruction
		[102] = 1, -- Druid Balance
	}

	local function Mobility(unit)
		local info = FS.Roster:GetInfo(UnitGUID(unit))
		if info then
			local mobility = mobilities[info.global_spec_id]
			if type(mobility) == "function" then
				mobility = mobility(unit)
			end
			return mobility
		end
		return 5
	end

	-- Foams constants
	local Shadow, Fire, Frost = 228769, 228758, 228768
	local colors = { Shadow, Fire, Frost }
	local foams = {
		[228744] = Fire,
		[228794] = Fire,
		[228810] = Frost,
		[228811] = Frost,
		[228818] = Shadow,
		[228819] = Shadow,
	}
	local echoes = {
		[228794] = true,
		[228811] = true,
		[228819] = true,
	}
	local meleeIcon = {
		[228744] = 7, -- Cross
		[228794] = 7, -- Cross
		[228810] = 6, -- Square
		[228811] = 6, -- Square
		[228818] = 3, -- Diamond
		[228819] = 3, -- Diamond
	}

	-- Checks if the unit is suitable to let the foam debuff expire
	local function IsSuitableExpire(unit, debuff)
		-- Unit must not have a different color
		for _, color in ipairs(colors) do
			if color ~= foams[debuff] and UnitDebuff(unit, mod:SpellName(color)) then
				return false
			end
		end
		return true
	end

	-- Checks if the unit is suitable to receive the foam debuff
	local function IsSuitableReceive(unit, debuff, blacklist)
		-- Unit must not be on the blacklist
		if blacklist and blacklist[UnitGUID(unit)] then
			return false
		end
		-- Unit must be ranged player
		if not mod:Ranged(unit) then
			return false
		end
		-- Unit must not have another foam
		for foam in pairs(foams) do
			if UnitDebuff(unit, mod:SpellName(foam)) then
				return false
			end
		end
		-- Debuff should be suitable to expire on the target
		return IsSuitableExpire(unit, debuff)
	end

	-- Builds the range list for the current player
	local function BuildRanges(debuff)
		local ranges = {}
		for unit in mod:IterateGroup(20) do
			if IsSuitableReceive(unit, debuff) then
				ranges[UnitGUID(unit)] = mod:Range(unit)
			end
		end
		return ranges
	end

	local function GetFoam(unit)
		local unitFoam = false
		for foam in pairs(foams) do
			if UnitDebuff(unit, mod:SpellName(foam)) then
				if unitFoam and foams[unitFoam] ~= foams[foam] then
					return "multiple"
				else
					unitFoam = foam
				end
			end
		end
		return unitFoam
	end

	local ranges = {}
	local rangesReceived = 0
	local initialAttributionDone = false
	local blacklist = {}
	local pendingFoams = {}
	local rangedIcons = { [1] = true, [2] = true, [4] = true, [5] = true }
	local rangedIconsUsed = {}
	local rangedIconsUsedOn = {}

	local function EstimatedRange(fromGUID, toGUID)
		if ranges[fromGUID] then
			return ranges[fromGUID][toGUID] or 20
		end
		return 20
	end

	function mod:VolatileFoamCast(args)
		wipe(ranges)
		rangesReceived = 0
		initialAttributionDone = false
		wipe(blacklist)
		wipe(pendingFoams)
		rangedIcons = { [1] = true, [2] = true, [4] = true, [5] = true }
		wipe(rangedIconsUsed)
		wipe(rangedIconsUsedOn)
		self:ScheduleTimer("VolatileFoamAI", 0.5)
	end

	function mod:VolatileFoamApplied(args)
		if not self:Me(args.destGUID) then
			-- Only send message when foam is on us
			return
		elseif IsSuitableExpire("player", args.spellId) or self:Melee() then
			-- Suitable target or melee, send a dummy message without ranges
			self:Send("VolatileFoamRanges", {
				player = args.destGUID,
				spell = args.spellId,
			}, "RAID")
		else
			-- Unsuitable ranged taget, send ranges listing
			self:Send("VolatileFoamRanges", {
				player = args.destGUID,
				spell = args.spellId,
				ranges = BuildRanges(args.spellId)
			}, "RAID")
		end
	end

	function mod:VolatileFoamRemoved(args)
		local guid = args.destGUID
		-- Free icon allocated for this pair of players
		local icon = rangedIconsUsed[guid]
		if icon then
			rangedIcons[icon] = true
			rangedIconsUsed[guid] = nil
			SetRaidTarget(rangedIconsUsedOn[icon], 0)
			rangedIconsUsedOn[icon] = nil
		end
		-- Remove soaker from blacklist once the target loses its debuff
		for soaker, target in pairs(blacklist) do
			if target == guid then
				blacklist[soaker] = nil
				break
			end
		end
	end

	-- Received ranges data
	function mod:VolatileFoamRanges(data)
		if data.ranges then
			-- No ranges available when target is suitable or melee
			ranges[data.player] = data.ranges
		end
		rangesReceived = rangesReceived + 1
		if not initialAttributionDone and rangesReceived == 3 then
			-- Shortcut for initial attribution
			self:VolatileFoamAI()
		elseif initialAttributionDone and echoes[data.spell] then
			-- Echoes are handled immediately
			-- (but after initial attributions, to work around stupid Blizzard devs)
			if not pendingFoams[data.player] then
				pendingFoams[data.player] = true
				self:ScheduleTimer("VolatileFoamAIPlayer", 0.3, data.player)
			end
		end
	end

	-- Perform raid-wide attributions
	function mod:VolatileFoamAI()
		if initialAttributionDone then return end
		if self:Token(foams_ai) then
			initialAttributionDone = true
			for unit in mod:IterateGroup(20) do
				self:VolatileFoamAIPlayer(unit, true)
			end
		end
	end

	-- Perform attribution for a specific player
	function mod:VolatileFoamAIPlayer(player, force)
		if not initialAttributionDone then return end

		-- Normalize inputs
		local unit = self:UnitId(player)
		local guid = UnitGUID(unit)

		-- Ensure there is a pending attribution for this player
		if pendingFoams[guid] or force then
			pendingFoams[guid] = nil
		else
			return
		end

		local foam = GetFoam(unit)
		if foam then
			if foam == "multiple" then
				-- I HATE YOU BLIZZARD
				self:Send("VolatileFoamMove", {
					player = UnitGUID(unit),
					multiple = true
				}, "RAID")
				SendChatMessage(L.foam_multiple:format(UnitName(unit)), "RAID")
			elseif IsSuitableExpire(unit, foam) then
				-- Happy little suitable player
				-- Nothing to do, just let it expire
				SendChatMessage(L.foam_ok:format(UnitName(unit)), "RAID")
			elseif self:Melee(unit) then
				-- Unsuitable melees go on the correct sign
				self:Send("VolatileFoamMove", {
					player = UnitGUID(unit),
					icon = meleeIcon[foam]
				}, "RAID")
				SendChatMessage(L.foam_moveto_melee:format(UnitName(unit), meleeIcon[foam]), "RAID")
			else
				local soakers = {}
				for soaker in mod:IterateGroup(20) do
					if IsSuitableReceive(soaker, foam, blacklist) then
						table.insert(soakers, {
							unit = soaker,
							mobility = Mobility(soaker) - (EstimatedRange(guid, UnitGUID(soaker)) / 10)
						})
					end
				end
				if #soakers > 1 then
					table.sort(soakers, function(a, b)
						return a.mobility > b.mobility
					end)
				end
				if #soakers == 0 then
					-- No soakers available ?
					SendChatMessage(L.foam_noavail:format(UnitName(unit)), "RAID")
				else
					local icon = next(rangedIcons)
					if not icon then
						SendChatMessage(L.foam_noicon:format(UnitName(unit)), "RAID")
					else
						rangedIcons[icon] = nil
						rangedIconsUsed[guid] = icon

						-- Soaker's unit
						local soaker = soakers[1].unit
						blacklist[UnitGUID(soaker)] = guid
						local msg = L.foam_moveto

						-- If soaker is less mobile than affected unit, unit will move to soaker!
						if soakers[1].mobility <= Mobility(unit) then
							soaker, unit = unit, soaker
							msg = L.foam_soakby
						end

						self:Send("VolatileFoamMove", {
							player = UnitGUID(soaker),
							icon = icon
						}, "RAID")

						SetRaidTarget(unit, icon)
						rangedIconsUsedOn[icon] = unit

						SendChatMessage(msg:format(UnitName(unit), icon, UnitName(soaker)), "RAID")
					end
				end
			end
		end
	end

	-- Received movement instructions
	function mod:VolatileFoamMove(data)
		if not data.player or self:Me(data.player) then
			local icon, msg
			if data.multiple then
				icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
				msg = "MULTIPLE Foams"
			else
				icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. data.icon
				msg = "Move to \124T" .. icon .. ":0\124t"
			end
			self:Emphasized(false, msg)
			self:Pulse(false, icon)
			self:PlaySound(false, "Warning")
		end
	end
end
