-- language: Lua (Roblox Luau), file: spoofer.lua
-- chunk 1/4 — head, Config, screenDraw, Visuals engine start
-- reconstructed from thread; interior sections marked RECONSTRUCTED where source was lost

if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = workspace
local Camera = workspace.CurrentCamera
local lp = Players.LocalPlayer
local cloneref = cloneref or function(x) return x end
local env = (getgenv and getgenv()) or _G
if env.__ObsidianLocalVisuals then pcall(env.__ObsidianLocalVisuals) end
local connections, restorers = {}, {}
local running = true
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end
connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    Camera = workspace.CurrentCamera
end)
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local okLibrary, Library = pcall(function()
    return loadstring(game:HttpGet(repo .. "Library.lua"))()
end)
if not okLibrary or not Library then
    warn("Obsidian could not load: " .. tostring(Library))
    return
end
local Window = Library:CreateWindow({
    Title = "prism beta v1",
    Center = true, AutoShow = true,
    ToggleKeybind = Enum.KeyCode.RightShift,
})
local Options, Toggles = Library.Options or {}, Library.Toggles or {}
local Tabs = {
    Cosmetics = Window:AddTab("Cosmetics", "sparkles"),
    Weapons = Window:AddTab("Weapons", "swords"),
    Inventory = Window:AddTab("Inventory", "box"),
    World = Window:AddTab("World", "globe"),
    Spoofer = Window:AddTab("Spoofer", "user-round"),
    Misc = Window:AddTab("Misc", "layers"),
    Settings = Window:AddTab("Settings", "settings"),
}
local function notify(message)
    Library:Notify(tostring(message), 5)
end
local function patch(target, name, replacement)
    local old = target[name]
    target[name] = replacement
    table.insert(restorers, function()
        if target[name] == replacement then target[name] = old end
    end)
    return old
end
local function moduleAt(root, names)
    for _, name in ipairs(names) do
        root = root and root:FindFirstChild(name)
        if not root then return nil end
    end
    if not root:IsA("ModuleScript") then return nil end
    local ok, value = pcall(require, root)
    if ok and type(value) == "table" then return value end
    return nil
end
local moduleErrors = {}
local moduleCache = setmetatable({}, {__mode="k"})
local function loadGameModule(root, names)
    local path = table.concat(names, ".")
    local node = root
    for _, name in ipairs(names) do
        node = node and node:FindFirstChild(name)
        if not node then moduleErrors[path] = "not loaded yet"; return nil end
    end
    if not node:IsA("ModuleScript") then moduleErrors[path] = "not a ModuleScript"; return nil end
    if moduleCache[node] then return moduleCache[node] end
    local ok, value = pcall(require, node)
    if ok and type(value) == "table" then
        moduleCache[node] = value
        moduleErrors[path] = nil
        return value
    end
    moduleErrors[path] = tostring(value)
    return nil
end
local Rivals = {Ready=false}
local function resolveRivals()
    local scripts = lp:FindFirstChild("PlayerScripts")
    Rivals.Fighter = Rivals.Fighter or loadGameModule(scripts, {"Controllers","FighterController"})
    Rivals.Enums = Rivals.Enums or loadGameModule(ReplicatedStorage, {"Modules","EnumLibrary"})
    Rivals.Cosmetics = Rivals.Cosmetics or loadGameModule(ReplicatedStorage, {"Modules","CosmeticLibrary"})
    Rivals.ItemLib = Rivals.ItemLib or loadGameModule(ReplicatedStorage, {"Modules","ItemLibrary"})
    Rivals.SeasonLibrary = Rivals.SeasonLibrary or loadGameModule(ReplicatedStorage, {"Modules","SeasonLibrary"})
    Rivals.PlayerDataController = Rivals.PlayerDataController or loadGameModule(scripts, {"Controllers","PlayerDataController"})
    Rivals.Gun = Rivals.Gun or loadGameModule(scripts, {"Modules","ItemTypes","Gun"})
    Rivals.Ready = Rivals.Fighter ~= nil
end
local function getEquippedItem()
    local ctrl = Rivals.Fighter
    if not ctrl then return nil end
    local fighter = ctrl.LocalFighter
    if not fighter and type(ctrl.GetFighter) == "function" then
        local ok, value = pcall(ctrl.GetFighter, ctrl, lp)
        if ok then fighter = value end
    end
    if not fighter and ctrl._player_to_fighter then fighter=ctrl._player_to_fighter[lp] end
    return fighter and fighter.EquippedItem
end

local function getHealth(player)
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health or 0, hum and hum.MaxHealth or 100
end
local function isAlive(player)
    local health = getHealth(player)
    return health > 0
end
local function hpRamp(f)
    return Color3.fromRGB(255,68,54):Lerp(Color3.fromRGB(61,224,122), math.clamp(f or 0,0,1))
end
local function getWeaponName(player)
    local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
    return tool and tool.Name or "?"
end
local State = { Shots = 0, Hits = 0, ESPObjects = {} }

local Config = {
    GameVisuals=false, GVUnlockAll=false, GVUnlockWeapons=false,
    GVWrapInverted=false, GVEveryone=false, GVBirthHook=true,
    GVFinisherClone=true, GVRemember=true, GVRankCharmOn=false,
    GVRankCharmRank="", GVRankCharmLb=0, GVEmotes=false,
    Visuals = false, VisualsPreset = "Neutral", VisualsPerformanceMode = false,
    VisualsFullbright = false,
    VisualsNoFog = false,
    VisualsHolograms = false, VisualsRainbowMap = false,
    VisualsRainbowMapSpeed = 0.15, VisualsStretch = 1.0,
    VisualsStretchMin = 0.5, VisualsStretchMax = 1.2,
    VisualsCameraSway = false,
    VisualsCameraSwayAmount = 0.5,
    VisualsHologramDuration = 3.5, VisualsHologramRange = 300,
    VisualsHologramVisibility = 1.4,
    VisualsHologramColor  = Color3.fromRGB(0, 220, 255),
    VisualsHologramAccent = Color3.fromRGB(255, 60, 200),
    VisualsGrade = "Crisp",
    VisualsGradeStrength = 0.6,
    VisualsBloom = false,
    VisualsBloomIntensity = 1.0,
    VisualsVignette = false,
    VisualsVignetteStrength = 0.6,
    VisualsLetterbox = false,
    VisualsLetterboxSize = 0.10,
    VisualsDOF = false,
    VisualsDOFDistance = 28,
    VisualsDOFBlur = 0.5,
    VisualsHologramStyle = "Orb",
    VisualsHologramLethal = true,
    VisualsHologramLethalColor = Color3.fromRGB(255, 200, 60),
    HUD = false,
    FXHitMarker = true,
    FXHitMarkerColor = Color3.fromRGB(255, 255, 255),
    FXHitMarkerCritColor = Color3.fromRGB(255, 194, 75),
    FXHitMarkerLethalColor = Color3.fromRGB(255, 64, 78),
    FXHitMarkerGap = 5,
    FXHitMarkerLen = 8,
    FXHitMarkerThickness = 2,
    FXHitSound = true,
    FXHitSoundId = "",
    FXKillSoundId = "",
    FXHitSoundVolume = 0.5,
    FXDamageNumbers = true,
    FXDamageAccumWindow = 0.9,
    FXKillBanner = true,
    FXKillBannerColor = Color3.fromRGB(255, 194, 75),
    FXKillFeed = true,
    FXHeadshotSpark = true,
    FXHitFlash = true,
    FXDamageDirection = true,
    FXLowHPVignette = true,
    FXLowHPThreshold = 0.35,
    FXCritDamage = 30,
    FXBeamTracer     = false,
    FXBeamStyle      = "Glow",
    FXBeamHitColor   = Color3.fromRGB(255, 194, 75),
    FXBeamMissColor  = Color3.fromRGB(143, 160, 176),
    FXFovRing        = false,
    FXFovColorA      = Color3.fromRGB(53, 215, 199),
    FXFovColorB      = Color3.fromRGB(255, 194, 75),
    FXFovThickness   = 1.5,
    FXFovDriftSpeed  = 0.15,
    FXFovFill        = false,
    FXFovRotate      = true,
    FXWorldSpark     = false,
    FXBeamWidth0    = 0.18,
    FXBeamWidth1    = 0.04,
    FXBeamDur       = 0.55,
    FXBeamGlowLight = true,
    FXBeamTravel      = true,
    FXBeamTravelSpeed = 1400,
    FXBeamImpact      = true,
    FXWorldSparkBloom = true,
    FXKillPillar      = false,
    FXKillPillarColor = Color3.fromRGB(255, 194, 75),
    FXKillShards      = false,
    FXKillShardsColor = Color3.fromRGB(155, 232, 255),
    FXKillPulse       = false,
    FXKillPulseAmount = 0.6,
    FXFovCasing     = true,
    FXCrosshair          = false,
    FXCrosshairStyle     = "Cross",
    FXCrosshairColor     = Color3.fromRGB(243, 246, 250),
    FXCrosshairDot       = true,
    FXCrosshairGap       = 4,
    FXCrosshairLen       = 7,
    FXCrosshairThickness = 2,
    FXCrosshairOutline   = true,
    FXCrosshairHitPop    = true,
    HUDWatermark      = true,
    HUDWatermarkStats = true,
    FXTargetInfo       = false,
    FXTargetInfoOffset = 110,
    HUDBindList     = false,
    HUDBindListSide = "Left",
    FXHitMarkerStyle = "X",
    FXCrosshairBloom = false,
    HUDCompass       = false,
    HUDCompassWidth  = 380,
    HUDCompassPips   = true,
    HUDThreatArc     = false,
    HUDRangeReadout  = false,
    Weather          = false,
    WeatherType      = "Rain",
    WeatherIntensity = 1.0,
    WeatherMeteors   = false,
    WeatherMeteorRate = 1.0,
    WeatherStarRate  = 1.0,
    WeatherClockDial = false,
    WeatherClockCycleMin = 8,
    WeatherStorm     = false,
    WeatherStormFlash= true,
    WeatherStormMin  = 4,
    WeatherStormVar  = 8,
    WeatherThunderId = "rbxassetid://9113169432",
    WeatherSoundIds  = {
        rain  = "rbxassetid://9112858162",
        wind  = "rbxassetid://9112854440",
        fire  = "rbxassetid://2787093357",
        night = "rbxassetid://9112764573",
        birds = "rbxassetid://9112749254",
    },
    WeatherSoundVolume = 0.35,
    WeatherMood      = true,
    SkyboxPreset        = "Off",
    SkyboxHideCelestial = false,
    WeatherGodRays      = false,
    WeatherRainbow      = false,
    WeatherShootingStars = false,
    WeatherPuddles   = false,
    SpooferNameEnabled        = false,
    SpooferName               = "ProPlayer",
    SpooferDisplayName        = "ProPlayer",
    SpooferLevelEnabled       = false,
    SpooferLevel              = 100,
    SpooferCasualWinsEnabled  = false,
    SpooferCasualWins         = 500,
    SpooferRankedWinsEnabled  = false,
    SpooferRankedWins         = 250,
    SpooferRankedEloEnabled   = false,
    SpooferRankedElo          = 2400,
    SpooferWinPercentEnabled  = false,
    SpooferWinPercent         = 75,
    SpooferWinStreakEnabled   = false,
    SpooferWinStreak          = 25,
    SpooferFavoriteMapEnabled = false,
    SpooferFavoriteMap        = "Arena",
    VMOffsetEnabled      = false,
    VMOffsetX            = 0,
    VMOffsetY            = 0,
    VMOffsetZ            = 0,
    VMOffsetPitch        = 0,
    VMOffsetYaw          = 0,
    VMOffsetRoll         = 0,
    VMChamsEnabled       = false,
    VMChamsMaterial      = "ForceField",
    VMChamsColor         = Color3.fromRGB(53, 215, 199),
    VMChamsTransparency  = 0.5,
    VMDisableTextures    = false,
    FXCrosshairAngle     = 0,
    FXCrosshairSpin      = false,
    FXCrosshairSpinSpeed = 1.0,
    FXCrosshairSniper    = false,
    FXCrosshairBounce    = false,
    FXCrosshairBounceAmt = 4,
    CameraAspectRatioEnabled = false,
    CameraAspectRatioX       = 4,
    CameraAspectRatioY       = 3,
    CameraFovOverride        = false,
    CameraFovAmount          = 90,
    ThirdPersonEnabled       = false,
    ThirdPersonDistance      = 12,
}

local screenDraw
do
    local CoreGui = game:GetService("CoreGui")
    local _layers = {}
    local LAYER_ORDER = { base = 100000, fx = 100100 }
    local LAYER_NAME  = { base = "LH_Overlay", fx = "LH_Overlay_FX" }
    local FONT_MAP = {
        [0] = Enum.Font.Gotham, [1] = Enum.Font.SourceSans,
        [2] = Enum.Font.GothamMedium, [3] = Enum.Font.Code,
        [4] = Enum.Font.GothamBold, [5] = Enum.Font.SourceSansBold,
    }
    local BLACK = Color3.new(0, 0, 0)
    local function op(t) return 1 - (t or 1) end
    local function gui(layer)
        local Lr = _layers[layer]
        if not Lr then Lr = { gui = nil, z = 0, pools = {} }; _layers[layer] = Lr end
        if Lr.gui and Lr.gui.Parent then return Lr.gui end
        local g = Instance.new("ScreenGui")
        g.Name = LAYER_NAME[layer] or "LH_Overlay"
        g.IgnoreGuiInset = true
        g.ResetOnSpawn  = false
        g.DisplayOrder  = LAYER_ORDER[layer] or 100000
        g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        local ok = pcall(function() g.Parent = (gethui and gethui()) or CoreGui end)
        if not ok or not g.Parent then
            pcall(function() g.Parent = lp:FindFirstChildOfClass("PlayerGui") end)
        end
        Lr.gui = g
        return g
    end
    local function build(kind)
        if kind == "Square" then
            local f = Instance.new("Frame")
            f.BorderSizePixel = 0; f.BackgroundTransparency = 1
            f.AnchorPoint = Vector2.new(0, 0); f.Visible = false
            local st = Instance.new("UIStroke")
            st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            st.LineJoinMode = Enum.LineJoinMode.Miter
            st.Enabled = false; st.Parent = f
            local ug = nil
            local function apply(s, k)
                if k == "Position" then if s.Position then f.Position = UDim2.fromOffset(s.Position.X, s.Position.Y) end
                elseif k == "Size" then if s.Size then f.Size = UDim2.fromOffset(s.Size.X, s.Size.Y) end
                elseif k == "Color" then if s.Color then f.BackgroundColor3 = s.Color; st.Color = s.Color end
                elseif k == "Thickness" then st.Thickness = math.max(s.Thickness or 1, 0.1)
                elseif k == "Transparency" or k == "Filled" then
                    local o = op(s.Transparency)
                    if s.Filled == false then f.BackgroundTransparency = 1; st.Enabled = true; st.Transparency = o
                    else f.BackgroundTransparency = o; st.Enabled = false end
                elseif k == "Gradient" then
                    if s.Gradient then
                        if not ug then ug = Instance.new("UIGradient"); ug.Parent = st end
                        ug.Color = s.Gradient; ug.Enabled = true
                    elseif ug then ug.Enabled = false end
                elseif k == "GradientRotation" then if ug then ug.Rotation = s.GradientRotation or 0 end
                elseif k == "Visible" then f.Visible = s.Visible and true or false end
            end
            return f, apply
        elseif kind == "Line" then
            local f = Instance.new("Frame")
            f.BorderSizePixel = 0; f.AnchorPoint = Vector2.new(0.5, 0.5); f.Visible = false
            local _len = nil
            local function geom(s)
                if not (s.From and s.To) then return end
                local dx, dy = s.To.X - s.From.X, s.To.Y - s.From.Y
                local len = math.sqrt(dx * dx + dy * dy)
                _len = len
                f.Position = UDim2.fromOffset((s.From.X + s.To.X) * 0.5, (s.From.Y + s.To.Y) * 0.5)
                f.Size     = UDim2.fromOffset(len, math.max(s.Thickness or 1, 0.1))
                f.Rotation = math.deg(math.atan2(dy, dx))
            end
            local function apply(s, k)
                if k == "To" then geom(s)
                elseif k == "From" then
                elseif k == "Thickness" then if _len then f.Size = UDim2.fromOffset(_len, math.max(s.Thickness or 1, 0.1)) end
                elseif k == "Color" then if s.Color then f.BackgroundColor3 = s.Color end
                elseif k == "Transparency" then f.BackgroundTransparency = op(s.Transparency)
                elseif k == "Visible" then f.Visible = s.Visible and true or false end
            end
            return f, apply
        elseif kind == "Text" then
            local t = Instance.new("TextLabel")
            t.BackgroundTransparency = 1; t.BorderSizePixel = 0; t.Visible = false
            t.AutomaticSize = Enum.AutomaticSize.XY; t.RichText = false
            t.TextYAlignment = Enum.TextYAlignment.Top
            t.AnchorPoint = Vector2.new(0, 0); t.TextXAlignment = Enum.TextXAlignment.Left
            local st = Instance.new("UIStroke"); st.Thickness = 1; st.Color = BLACK
            st.LineJoinMode = Enum.LineJoinMode.Miter
            st.Enabled = false; st.Parent = t
            local function apply(s, k)
                if k == "Text" then t.Text = tostring(s.Text or "")
                elseif k == "Size" then t.TextSize = math.max(s.Size or 12, 1)
                elseif k == "Font" then t.Font = FONT_MAP[s.Font or 2] or Enum.Font.GothamMedium
                elseif k == "Color" then if s.Color then t.TextColor3 = s.Color end
                elseif k == "Center" or k == "RightAlign" then
                    if s.Center then t.AnchorPoint = Vector2.new(0.5, 0); t.TextXAlignment = Enum.TextXAlignment.Center
                    elseif s.RightAlign then t.AnchorPoint = Vector2.new(1, 0); t.TextXAlignment = Enum.TextXAlignment.Right
                    else t.AnchorPoint = Vector2.new(0, 0); t.TextXAlignment = Enum.TextXAlignment.Left end
                    if s.Position then t.Position = UDim2.fromOffset(s.Position.X, s.Position.Y) end
                elseif k == "Position" then if s.Position then t.Position = UDim2.fromOffset(s.Position.X, s.Position.Y) end
                elseif k == "Outline" then st.Enabled = s.Outline and true or false
                elseif k == "OutlineColor" then if s.OutlineColor then st.Color = s.OutlineColor end
                elseif k == "Transparency" then local o = op(s.Transparency); t.TextTransparency = o; st.Transparency = o
                elseif k == "Visible" then t.Visible = s.Visible and true or false end
            end
            return t, apply
        elseif kind == "Circle" then
            local f = Instance.new("Frame")
            f.BorderSizePixel = 0; f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.BackgroundTransparency = 1; f.Visible = false
            local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(1, 0); uc.Parent = f
            local st = Instance.new("UIStroke"); st.Enabled = false; st.Parent = f
            local function apply(s, k)
                if k == "Radius" then local d = 2 * (s.Radius or 0); f.Size = UDim2.fromOffset(d, d)
                elseif k == "Position" then if s.Position then f.Position = UDim2.fromOffset(s.Position.X, s.Position.Y) end
                elseif k == "Color" then if s.Color then f.BackgroundColor3 = s.Color; st.Color = s.Color end
                elseif k == "Thickness" then st.Thickness = math.max(s.Thickness or 1, 0.1)
                elseif k == "Transparency" or k == "Filled" then
                    local o = op(s.Transparency)
                    if s.Filled == false then f.BackgroundTransparency = 1; st.Enabled = true; st.Transparency = o
                    else f.BackgroundTransparency = o; st.Enabled = false end
                elseif k == "Visible" then f.Visible = s.Visible and true or false end
            end
            return f, apply
        end
        return nil
    end
    screenDraw = function(kind, layer)
        layer = layer or "base"
        local Lr = _layers[layer]
        if not Lr then Lr = { gui = nil, z = 0, pools = {} }; _layers[layer] = Lr end
        local pool = Lr.pools[kind]; if not pool then pool = {}; Lr.pools[kind] = pool end
        local inst, applyFn
        local reused = table.remove(pool)
        if reused then
            inst, applyFn = reused.inst, reused.apply
        else
            inst, applyFn = build(kind)
            if not inst then return nil end
            inst.Parent = gui(layer)
        end
        Lr.z = Lr.z + 1; inst.ZIndex = Lr.z
        inst.Visible = false
        local state = {}
        return setmetatable({}, {
            __index = function(_, k)
                if k == "Remove" then
                    return function()
                        inst.Visible = false
                        pool[#pool + 1] = { inst = inst, apply = applyFn }
                    end
                elseif k == "TextBounds" then
                    return inst.TextBounds
                end
                return state[k]
            end,
            __newindex = function(_, k, v)
                if state[k] == v then return end
                state[k] = v
                applyFn(state, k)
            end,
        })
    end
end

-- CHUNK 1 ENDS HERE. Chunk 2 begins with:
--   local Visuals = {}
--   ;(function()
--       ... lighting engine, presets, holograms, beam tracers, kill effects ...
--   end)()