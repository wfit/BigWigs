--------------------------------------------------------------------------------
-- Module Declaration
--

local plugin = BigWigs:NewPlugin("AuraTracker")
if not plugin then return end

--------------------------------------------------------------------------------
-- Locals
--

local tinsert, tremove, tsort = tinsert, tremove, table.sort
local pairs, ipairs = pairs, ipairs
local wipe, type, tostring = wipe, type, tostring
local GetTime, C_Timer = GetTime, C_Timer

local L = BigWigsAPI:GetLocale("BigWigs: Plugins")
local media = LibStub("LibSharedMedia-3.0")
plugin.displayName = "Aura Tracker"

local db
local anchor
local inTestMode = false

local defaultSize = 100
local defaultX = 200
local defaultY = -20

-------------------------------------------------------------------------------
-- Options
--

do
	local font = media:GetDefault("font")
	local _, size, flags = GameFontNormal:GetFont()

	plugin.defaultDB = {
		size = defaultSize,
		font = font,
		grow = "RIGHT"
	}
end

-------------------------------------------------------------------------------
-- Frame Creation
--

do
	anchor = CreateFrame("Frame", "BigWigsAuraTracker", UIParent)
	anchor:SetSize(defaultSize, defaultSize)
	anchor:SetMinResize(64, 64)
	anchor:SetClampedToScreen(true)
	anchor:SetScript("OnMouseUp", function(_, button)
		if inTestMode and button == "LeftButton" then
			plugin:SendMessage("BigWigs_SetConfigureTarget", plugin)
		end
	end)

	local bg = anchor:CreateTexture()
	bg:SetAllPoints(anchor)
	bg:SetColorTexture(0, 0, 0, 0.3)
	anchor.background = bg

	local header = anchor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	header:SetText("Aura Tracker")
	header:SetAllPoints(anchor)
	header:SetJustifyH("CENTER")
	header:SetJustifyV("MIDDLE")
	anchor.header = header

	anchor.background:Hide()
	anchor.header:Hide()

	anchor:EnableMouse(false)
end

-------------------------------------------------------------------------------
-- Initialization
--

local function resetAnchor()
	anchor:ClearAllPoints()
	anchor:SetPoint("CENTER", UIParent, "CENTER", defaultX, defaultY)
	db.posx = nil
	db.posy = nil
end

local function updateProfile()
	db = plugin.db.profile
	if anchor then
		anchor:SetSize(db.size, db.size)
		local x = db.posx
		local y = db.posy
		if x and y then
			local s = anchor:GetEffectiveScale()
			anchor:ClearAllPoints()
			anchor:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, y / s)
		else
			anchor:ClearAllPoints()
			anchor:SetPoint("CENTER", UIParent, "CENTER", defaultX, defaultY)
		end
	end
end

function plugin:OnPluginEnable()
	self:RegisterMessage("BigWigs_ShowAura")
	self:RegisterMessage("BigWigs_HideAura")

	self:RegisterMessage("BigWigs_OnBossDisable")
	self:RegisterMessage("BigWigs_OnBossReboot", "BigWigs_OnBossDisable")

	self:RegisterMessage("BigWigs_StartConfigureMode")
	self:RegisterMessage("BigWigs_StopConfigureMode")
	self:RegisterMessage("BigWigs_SetConfigureTarget")

	self:RegisterMessage("BigWigs_ProfileUpdate", updateProfile)
	self:RegisterMessage("BigWigs_ResetPositions", resetAnchor)
	updateProfile()
end

function plugin:OnPluginDisable()
	--self:Close()
end

-------------------------------------------------------------------------------
-- Options
--

do
	plugin.pluginOptions = {
		name = "Aura Tracker",
		type = "group",
		get = function(info)
			return db[info[#info]]
		end,
		set = function(info, value)
			local entry = info[#info]
			db[entry] = value
			updateProfile()
		end,
		args = {
			size = {
				type = "range",
				name = "Size",
				order = 1,
				max = 140,
				min = 60,
				step = 1,
			},
			grow = {
				type = "select",
				name = "Grow",
				order = 2,
				values = {
					["UP"] = "Up",
					["DOWN"] = "Down",
					["LEFT"] = "Left",
					["RIGHT"] = "Right",
				},
			},
			font = {
				type = "select",
				name = L.font,
				order = 3,
				values = media:List("font"),
				itemControl = "DDI-Font",
				get = function()
					for i, v in next, media:List("font") do
						if v == db.font then return i end
					end
				end,
				set = function(_, value)
					db.font = media:List("font")[value]
				end,
			},
			exactPositioning = {
				type = "group",
				name = L.positionExact,
				order = 8,
				inline = true,
				args = {
					posx = {
						type = "range",
						name = L.positionX,
						desc = L.positionDesc,
						min = 0,
						max = 2048,
						step = 1,
						order = 1,
						width = "full",
					},
					posy = {
						type = "range",
						name = L.positionY,
						desc = L.positionDesc,
						min = 0,
						max = 2048,
						step = 1,
						order = 2,
						width = "full",
					},
				},
			},
		},
	}
end

-------------------------------------------------------------------------------
-- Icon Pool
--

local pool = {}

local function inset(frame, inset)
	frame:SetPoint("LEFT", inset, 0)
	frame:SetPoint("TOP", 0, -inset)
	frame:SetPoint("RIGHT", -inset, 0)
	frame:SetPoint("BOTTOM", 0, inset)
end

local function alloc()
	local icon = tremove(pool)
	if not icon then
		icon = CreateFrame("Frame", nil, anchor)

		local container = CreateFrame("Frame", nil, icon)
		container:SetAllPoints(icon)
		icon.container = container

		local pulseIn = container:CreateAnimationGroup()
		icon.pulseIn = pulseIn
		local pulseIn1 = pulseIn:CreateAnimation("Scale")
		pulseIn1:SetDuration(0)
		pulseIn1:SetScale(0.25, 0.25)
		pulseIn1:SetOrder(1)
		local pulseIn2 = pulseIn:CreateAnimation("Scale")
		pulseIn2:SetDuration(0.20)
		pulseIn2:SetScale(8, 8)
		pulseIn2:SetOrder(2)
		pulseIn2:SetEndDelay(0.15)
		local pulseIn3 = pulseIn:CreateAnimation("Scale")
		pulseIn3:SetDuration(0.20)
		pulseIn3:SetScale(0.5, 0.5)
		pulseIn3:SetOrder(3)

		local border1 = container:CreateTexture(nil, "BORDER")
		border1:SetAllPoints(container)
		border1:SetColorTexture(0, 0, 0, 0.75)

		local border2 = container:CreateTexture(nil, "BORDER")
		inset(border2, 2)
		border2:SetColorTexture(0, 0, 0, 1)

		local tex = container:CreateTexture(nil, "ARTWORK")
		inset(tex, 3)
		tex:SetTexCoord(0.125, 0.875, 0.125, 0.875)
		icon.tex = tex

		local widgets = CreateFrame("Frame", nil, icon)
		widgets:SetAllPoints(icon)

		local fadeIn = widgets:CreateAnimationGroup()
		icon.fadeIn = fadeIn
		local fadeIn1 = fadeIn:CreateAnimation("Alpha")
		fadeIn1:SetDuration(0)
		fadeIn1:SetToAlpha(0)
		fadeIn1:SetOrder(1)
		fadeIn1:SetEndDelay(0.4)
		local fadeIn2 = fadeIn:CreateAnimation("Alpha")
		fadeIn2:SetDuration(0.3)
		fadeIn2:SetFromAlpha(0)
		fadeIn2:SetToAlpha(1)
		fadeIn2:SetOrder(2)

		local cd = CreateFrame("Cooldown", nil, widgets, "CooldownFrameTemplate")
		cd:SetAllPoints(tex)
		cd:SetDrawEdge(false)
		cd:SetHideCountdownNumbers(false)
		cd:SetReverse(true)
		cd:SetDrawBling(false)
		cd.noCooldownCount = true
		icon.cd = cd
		icon.cdText = cd:GetRegions()

		local overlay = CreateFrame("Frame", nil, widgets)
		overlay:SetAllPoints(icon)
		icon.overlay = overlay

		local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		text:SetPoint("BOTTOM", 0, -25)
		text:SetJustifyH("CENTER")
		text:SetJustifyV("BOTTOM")
		icon.text = text

		local stacks = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		stacks:SetPoint("BOTTOMRIGHT", -13, 8)
		icon.stacks = stacks
	end

	local font = media:Fetch("font", db.font)

	icon:SetSize(db.size, db.size)
	icon.text:SetFont(font, 18, "OUTLINE")
	icon.stacks:SetFont(font, 42, "OUTLINE")
	icon.cdText:SetFont(font, 42, "OUTLINE")
	icon.text:SetText("")
	icon.stacks:SetText("")

	return icon
end

local function free(icon)
	icon:Hide()
	tinsert(pool, icon)
end

-------------------------------------------------------------------------------
-- Event Handlers
--

local auras = {}
local rack = {}
local auraId = 0

local animationLength = 0.4
local animator = CreateFrame("Frame")
animator:Hide()

local function ease(t)
	return (t-1)^3+1
end

local function offset(value)
	if db.grow == "UP" then
		return 0, value
	elseif db.grow == "DOWN" then
		return 0, -value
	elseif db.grow == "RIGHT" then
		return value, 0
	elseif db.grow == "LEFT" then
		return -value, 0
	end
end

local function animate()
	local now = GetTime()
	local done = true
	for _, entry in ipairs(rack) do
		local target, start = entry.targetOffset, entry.startOffset
		if target ~= start then
			local current = (start == -1) and target or start + ((target - start) * ease((now - entry.animationStart) / animationLength))
			if start == -1  or ((target > start and current >= target) or (target < start and current <= target)) then
				entry.icon:SetPoint("CENTER", offset(target))
				entry.offset = target
				entry.startOffset = target
			else
				entry.icon:SetPoint("CENTER", offset(current))
				entry.offset = current
				done = false
			end
		end
	end
	if done then
		animator:Hide()
	end
end
animator:SetScript("OnUpdate", animate)

local function order(a, b)
	if a.pin ~= b.pin then return a.pin < b.pin end
	return a.id < b.id
end

local function setLevels(aura, id)
	id = id * 10
	aura:SetFrameLevel(id)
	aura.cd:SetFrameLevel(id + 3)
	aura.overlay:SetFrameLevel(id + 5)
	return aura
end

local function updateRack()
	tsort(rack, order)
	local offset = 0
	local needAnimation = false
	for idx, entry in ipairs(rack) do
		if entry.hasText and db.grow == "UP" and idx > 1 then
			offset = offset + 30
		end
		if entry.idx ~= idx then
			setLevels(entry.icon, idx)
			entry.idx = idx
		end
		if entry.targetOffset ~= offset then
			needAnimation = true
			entry.startOffset = entry.offset
			entry.targetOffset = offset
			entry.animationStart = GetTime()
		end
		offset = offset + db.size + 10
		if entry.hasText and db.grow == "DOWN" then
			offset = offset + 30
		end
	end
	if needAnimation then
		animator:Show()
		animate()
	end
end

local function newAura(module, key)
	auraId = auraId + 1
	return {
		id = auraId,
		icon = setLevels(alloc(), auraId),
		module = module,
		key = key,
		fresh = true,
		offset = -1,
		idx = -1
	}
end

local function auraId(module, key)
	return (tostring(module) or "<nil>") .. "::" .. (tostring(key) or "<nil>")
end

local function freeAura(entry)
	auras[auraId(entry.module, entry.key)] = nil
	for key, rackEntry in ipairs(rack) do
		if rackEntry == entry then
			tremove(rack, key)
			updateRack()
			break
		end
	end
	free(entry.icon)
end

function plugin:BigWigs_ShowAura(_, module, key, options)
	local entry
	if key then
		local id = auraId(module, key)
		entry = auras[id] or newAura(module, key)
		if entry.fresh then
			auras[id] = entry
		else
			for idx, rackEntry in ipairs(rack) do
				if rackEntry == entry then
					tremove(rack, idx)
				end
			end
		end
	elseif not options.duration then
		error("Cannot show a nil-keyed aura with no duration.")
		return
	else
		entry = newAura(module, key)
	end

	local icon = entry.icon

	if options.icon then
		icon.tex:SetTexture(options.icon)
		icon.tex:Show()
	elseif options.icon == false then
		icon.tex:Hide()
	end

	if options.text then
		entry.hasText = options.text ~= ""
		icon.text:SetText(options.text)
	elseif options.text == false then
		entry.hasText = false
		icon.text:SetText("")
	end

	if options.stacks then
		icon.stacks:SetText(options.stacks)
	elseif options.text == false then
		icon.stacks:SetText("")
	end

	if options.duration then
		icon.cd:SetCooldown(options.start or GetTime(), options.duration)
		icon.cd:SetHideCountdownNumbers(options.countdown == false)
	elseif options.duration == false then
		icon.cd:SetCooldown(0, 0)
	end

	if (options.pulse == nil and entry.fresh) or options.pulse then
		icon.fadeIn:Play()
		icon.pulseIn:Play()
	end

	if options.pin then
		entry.pin = tonumber(options.pin) or 0
	elseif entry.pin == nil then
		entry.pin = 0
	end

	tinsert(rack, entry)
	updateRack()

	icon:Show()
	entry.fresh = false

	if not key or options.autoremove then
		local delay = type(options.autoremove) == "number" and options.autoremove or options.duration
		C_Timer.After(delay, function() freeAura(entry) end)
	end
end

function plugin:BigWigs_HideAura(_, module, key)
	local id = auraId(module, key)
	local entry = auras[id]
	if entry then
		freeAura(entry)
	end
end

do
	local collectable = {}
	function plugin:BigWigs_OnBossDisable(_, module)
		wipe(collectable)
		for _, entry in ipairs(rack) do
			if entry.module == module then
				tinsert(collectable, entry)
			end
		end
		for _, entry in ipairs(auras) do
			freeAura(entry)
		end
	end
end

function plugin:BigWigs_SetConfigureTarget(_, module)
	if module == self then
		anchor.background:SetColorTexture(0.2, 1, 0.2, 0.3)
	else
		anchor.background:SetColorTexture(0, 0, 0, 0.3)
	end
end

function plugin:BigWigs_StartConfigureMode()
	inTestMode = true
	anchor.background:SetColorTexture(0, 0, 0, 0.3)

	anchor:SetMovable(true)
	anchor:RegisterForDrag("LeftButton")
	anchor:SetScript("OnDragStart", function(f) f:StartMoving() end)
	anchor:SetScript("OnDragStop", function(f)
		f:StopMovingOrSizing()
		local s = f:GetEffectiveScale()
		db.posx = f:GetLeft() * s
		db.posy = f:GetTop() * s
	end)

	anchor:SetResizable(true)
	anchor:EnableMouse(true)

	anchor.background:Show()
	anchor.header:Show()
end

function plugin:BigWigs_StopConfigureMode()
	inTestMode = false

	anchor:SetMovable(false)
	anchor:RegisterForDrag()
	anchor:SetScript("OnDragStart", nil)
	anchor:SetScript("OnDragStop", nil)

	anchor:SetResizable(false)
	anchor:EnableMouse(false)

	anchor.background:Hide()
	anchor.header:Hide()
end
