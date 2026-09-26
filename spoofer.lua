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
-- language: Lua (Roblox Luau), file: spoofer.lua
-- chunk 2/4 — Visuals engine (lighting, holograms, beams, FX UI)

local Visuals = {}
;(function()
    local _origLighting, _origClones = nil, {}
    local _hologramFolder, _hologramCooldowns = nil, {}
    local _stretchBound, _rainbowConn = false, nil
    local _rainbowParts, _rainbowHue, _rainbowBatchIdx = {}, 0, 1
    local _perfBackup, _origParticleRates = nil, {}
    local _reassertConn, _reassertLastT = nil, 0
    local LIGHTING_PROPS = {
        "Brightness","ExposureCompensation","GlobalShadows","ShadowSoftness",
        "EnvironmentDiffuseScale","EnvironmentSpecularScale","ClockTime",
        "OutdoorAmbient","Ambient","FogEnd","FogStart","FogColor",
        "ColorShift_Top","ColorShift_Bottom",
    }
    local function snapshotLighting()
        if _origLighting then return end
        _origLighting = {}
        for _, p in ipairs(LIGHTING_PROPS) do
            local ok, v = pcall(function() return Lighting[p] end)
            if ok then _origLighting[p] = v end
        end
        for _, c in ipairs(Lighting:GetChildren()) do
            if not c:GetAttribute("VS_Custom") then
                local ok, clone = pcall(function() return c:Clone() end)
                if ok and clone then table.insert(_origClones, clone) end
            end
        end
    end
    local function clearTagged()
        for _, c in ipairs(Lighting:GetChildren()) do
            if c:GetAttribute("VS_Custom") then c:Destroy() end
        end
    end
    local function restore()
        if not _origLighting then return end
        clearTagged()
        for k, v in pairs(_origLighting) do pcall(function() Lighting[k] = v end) end
        local exist = {}
        for _, c in ipairs(Lighting:GetChildren()) do exist[c.Name] = true end
        for _, clone in ipairs(_origClones) do
            if not exist[clone.Name] then clone:Clone().Parent = Lighting end
        end
    end
    local function fx(cls, props)
        local f = Instance.new(cls)
        f:SetAttribute("VS_Custom", true)
        for k, v in pairs(props) do f[k] = v end
        f.Parent = Lighting
        return f
    end
    local Presets = {}
    Presets.Neutral = function()
        clearTagged()
        Lighting.Brightness = 2; Lighting.ExposureCompensation = 0
        Lighting.GlobalShadows = false; Lighting.ShadowSoftness = 0.2
        Lighting.EnvironmentDiffuseScale = 0.5; Lighting.EnvironmentSpecularScale = 0.5
        Lighting.ClockTime = 14; Lighting.OutdoorAmbient = Color3.fromRGB(70,70,70)
        Lighting.Ambient = Color3.fromRGB(0,0,0); Lighting.FogEnd = 100000
        fx("Atmosphere", { Density=0.3, Offset=0.25, Color=Color3.fromRGB(199,199,199),
            Decay=Color3.fromRGB(106,112,125), Glare=0, Haze=0 })
    end
    Presets.Cyberpunk = function()
        clearTagged()
        Lighting.Brightness = 2.6; Lighting.ExposureCompensation = 0.5
        Lighting.GlobalShadows = false; Lighting.ShadowSoftness = 0.7
        Lighting.EnvironmentDiffuseScale = 0.7; Lighting.EnvironmentSpecularScale = 1
        Lighting.ClockTime = 0; Lighting.OutdoorAmbient = Color3.fromRGB(120,80,165)
        Lighting.Ambient = Color3.fromRGB(80,55,120)
        fx("Atmosphere", { Density=0.3, Offset=0.3, Color=Color3.fromRGB(160,70,215),
            Decay=Color3.fromRGB(75,200,240), Glare=2.2, Haze=1 })
        fx("BloomEffect", { Intensity=1.15, Size=24, Threshold=0.72 })
        fx("ColorCorrectionEffect", { Brightness=0.04, Contrast=0.2, Saturation=0.45,
            TintColor=Color3.fromRGB(220,195,255) })
    end
    Presets.Anime = function()
        clearTagged()
        Lighting.Brightness = 2.3; Lighting.ExposureCompensation = 0.2
        Lighting.GlobalShadows = false; Lighting.ShadowSoftness = 0.7
        Lighting.EnvironmentDiffuseScale = 0.7; Lighting.EnvironmentSpecularScale = 0.7
        Lighting.ClockTime = 15; Lighting.OutdoorAmbient = Color3.fromRGB(150,140,170)
        Lighting.Ambient = Color3.fromRGB(95,85,120)
        fx("Atmosphere", { Density=0.28, Offset=0.35, Color=Color3.fromRGB(255,200,230),
            Decay=Color3.fromRGB(150,195,255), Glare=1, Haze=0.8 })
        fx("BloomEffect", { Intensity=1.0, Size=26, Threshold=0.8 })
        fx("ColorCorrectionEffect", { Brightness=0.03, Contrast=0.14, Saturation=0.32,
            TintColor=Color3.fromRGB(255,228,242) })
    end
    Presets.Sunset = function()
        clearTagged()
        Lighting.Brightness = 2.3; Lighting.ExposureCompensation = 0.4
        Lighting.GlobalShadows = false; Lighting.ShadowSoftness = 0.5
        Lighting.EnvironmentDiffuseScale = 0.75; Lighting.EnvironmentSpecularScale = 0.9
        Lighting.ClockTime = 17.75; Lighting.OutdoorAmbient = Color3.fromRGB(185,115,80)
        Lighting.Ambient = Color3.fromRGB(105,60,45)
        fx("Atmosphere", { Density=0.38, Offset=0.55, Color=Color3.fromRGB(255,150,80),
            Decay=Color3.fromRGB(255,105,60), Glare=1.8, Haze=1.6 })
        fx("BloomEffect", { Intensity=0.9, Size=24, Threshold=0.78 })
        fx("ColorCorrectionEffect", { Brightness=0.03, Contrast=0.16, Saturation=0.32,
            TintColor=Color3.fromRGB(255,195,150) })
    end
    Presets.Vaporwave = function()
        clearTagged()
        Lighting.Brightness = 2.3; Lighting.ExposureCompensation = 0.4
        Lighting.GlobalShadows = false; Lighting.ShadowSoftness = 0.7
        Lighting.EnvironmentDiffuseScale = 0.6; Lighting.EnvironmentSpecularScale = 0.9
        Lighting.ClockTime = 18.4; Lighting.OutdoorAmbient = Color3.fromRGB(150,90,165)
        Lighting.Ambient = Color3.fromRGB(95,60,120)
        fx("Atmosphere", { Density=0.34, Offset=0.4, Color=Color3.fromRGB(255,130,205),
            Decay=Color3.fromRGB(110,200,255), Glare=1.8, Haze=1.3 })
        fx("BloomEffect", { Intensity=1.05, Size=26, Threshold=0.74 })
        fx("ColorCorrectionEffect", { Brightness=0.04, Contrast=0.18, Saturation=0.38,
            TintColor=Color3.fromRGB(255,205,240) })
    end
    Presets.Void = function()
        clearTagged()
        Lighting.Brightness = 2.0; Lighting.ExposureCompensation = 0.25
        Lighting.GlobalShadows = false; Lighting.ShadowSoftness = 0.9
        Lighting.EnvironmentDiffuseScale = 0.5; Lighting.EnvironmentSpecularScale = 0.7
        Lighting.ClockTime = 0; Lighting.OutdoorAmbient = Color3.fromRGB(85,95,135)
        Lighting.Ambient = Color3.fromRGB(55,62,95)
        fx("Atmosphere", { Density=0.35, Offset=0.2, Color=Color3.fromRGB(55,65,110),
            Decay=Color3.fromRGB(95,110,180), Glare=0.3, Haze=0.8 })
        fx("BloomEffect", { Intensity=0.8, Size=22, Threshold=0.76 })
        fx("ColorCorrectionEffect", { Brightness=0.03, Contrast=0.16, Saturation=-0.2,
            TintColor=Color3.fromRGB(190,200,255) })
    end
    Presets.Clarity = function()
        clearTagged()
        Lighting.Brightness = 2.6; Lighting.ExposureCompensation = 0
        Lighting.GlobalShadows = false; Lighting.ShadowSoftness = 1
        Lighting.EnvironmentDiffuseScale = 0.2; Lighting.EnvironmentSpecularScale = 0.1
        Lighting.ClockTime = 14; Lighting.OutdoorAmbient = Color3.fromRGB(150,150,155)
        Lighting.Ambient = Color3.fromRGB(120,120,125); Lighting.FogEnd = 1000000
        fx("ColorCorrectionEffect", { Brightness=0.05, Contrast=0.25, Saturation=-0.2,
            TintColor=Color3.fromRGB(255,255,255) })
    end
    Presets.Toxic = function()
        clearTagged()
        Lighting.Brightness = 2.2; Lighting.ExposureCompensation = 0.35
        Lighting.GlobalShadows = false; Lighting.ShadowSoftness = 0.7
        Lighting.EnvironmentDiffuseScale = 0.6; Lighting.EnvironmentSpecularScale = 0.8
        Lighting.ClockTime = 1; Lighting.OutdoorAmbient = Color3.fromRGB(80,135,70)
        Lighting.Ambient = Color3.fromRGB(45,85,50)
        fx("Atmosphere", { Density=0.34, Offset=0.35, Color=Color3.fromRGB(95,220,110),
            Decay=Color3.fromRGB(55,180,80), Glare=1.8, Haze=1.4 })
        fx("BloomEffect", { Intensity=1.1, Size=24, Threshold=0.74 })
        fx("ColorCorrectionEffect", { Brightness=0.04, Contrast=0.2, Saturation=0.45,
            TintColor=Color3.fromRGB(210,255,205) })
    end
    Presets.Sakura = function()
        clearTagged()
        Lighting.Brightness = 2.2; Lighting.ExposureCompensation = 0.35
        Lighting.GlobalShadows = false; Lighting.ShadowSoftness = 0.8
        Lighting.EnvironmentDiffuseScale = 0.7; Lighting.EnvironmentSpecularScale = 0.7
        Lighting.ClockTime = 15.5; Lighting.OutdoorAmbient = Color3.fromRGB(200,155,180)
        Lighting.Ambient = Color3.fromRGB(120,85,110)
        fx("Atmosphere", { Density=0.3, Offset=0.4, Color=Color3.fromRGB(255,205,225),
            Decay=Color3.fromRGB(255,175,215), Glare=1.2, Haze=1 })
        fx("BloomEffect", { Intensity=1.1, Size=26, Threshold=0.78 })
        fx("ColorCorrectionEffect", { Brightness=0.04, Contrast=0.15, Saturation=0.28,
            TintColor=Color3.fromRGB(255,225,240) })
    end
    Presets.Nebula = function()
        clearTagged()
        Lighting.Brightness = 2.2; Lighting.ExposureCompensation = 0.4
        Lighting.GlobalShadows = false; Lighting.ShadowSoftness = 0.9
        Lighting.EnvironmentDiffuseScale = 0.55; Lighting.EnvironmentSpecularScale = 0.85
        Lighting.ClockTime = 0; Lighting.OutdoorAmbient = Color3.fromRGB(128,94,168)
        Lighting.Ambient = Color3.fromRGB(82,60,120)
        fx("Atmosphere", { Density=0.34, Offset=0.25, Color=Color3.fromRGB(120,70,180),
            Decay=Color3.fromRGB(220,90,190), Glare=1.4, Haze=1.1 })
        fx("BloomEffect", { Intensity=1.15, Size=24, Threshold=0.72 })
        fx("ColorCorrectionEffect", { Brightness=0.03, Contrast=0.2, Saturation=0.4,
            TintColor=Color3.fromRGB(235,205,255) })
    end
    local PresetScalars = {
        Neutral   = { Brightness=2,   ExposureCompensation=0,    ClockTime=14,   OutdoorAmbient=Color3.fromRGB(70,70,70),
                      Ambient=Color3.fromRGB(0,0,0),      FogEnd=100000,
                      EnvironmentDiffuseScale=0.5,  EnvironmentSpecularScale=0.5 },
        Clarity   = { Brightness=2.6, ExposureCompensation=0,    ClockTime=14,   OutdoorAmbient=Color3.fromRGB(150,150,155),
                      Ambient=Color3.fromRGB(120,120,125), FogEnd=1000000,
                      EnvironmentDiffuseScale=0.2,  EnvironmentSpecularScale=0.1 },
        Cyberpunk = { Brightness=2.6, ExposureCompensation=0.5,  ClockTime=0,    OutdoorAmbient=Color3.fromRGB(120,80,165),
                      Ambient=Color3.fromRGB(80,55,120),
                      EnvironmentDiffuseScale=0.7,  EnvironmentSpecularScale=1 },
        Anime     = { Brightness=2.3, ExposureCompensation=0.2,  ClockTime=15,   OutdoorAmbient=Color3.fromRGB(150,140,170),
                      Ambient=Color3.fromRGB(95,85,120),
                      EnvironmentDiffuseScale=0.7,  EnvironmentSpecularScale=0.7 },
        Sunset    = { Brightness=2.3, ExposureCompensation=0.4,  ClockTime=17.75, OutdoorAmbient=Color3.fromRGB(185,115,80),
                      Ambient=Color3.fromRGB(105,60,45),
                      EnvironmentDiffuseScale=0.75, EnvironmentSpecularScale=0.9 },
        Vaporwave = { Brightness=2.3, ExposureCompensation=0.4,  ClockTime=18.4, OutdoorAmbient=Color3.fromRGB(150,90,165),
                      Ambient=Color3.fromRGB(95,60,120),
                      EnvironmentDiffuseScale=0.6,  EnvironmentSpecularScale=0.9 },
        Toxic     = { Brightness=2.2, ExposureCompensation=0.35, ClockTime=1,    OutdoorAmbient=Color3.fromRGB(80,135,70),
                      Ambient=Color3.fromRGB(45,85,50),
                      EnvironmentDiffuseScale=0.6,  EnvironmentSpecularScale=0.8 },
        Void      = { Brightness=2.0, ExposureCompensation=0.25, ClockTime=0,    OutdoorAmbient=Color3.fromRGB(85,95,135),
                      Ambient=Color3.fromRGB(55,62,95),
                      EnvironmentDiffuseScale=0.5,  EnvironmentSpecularScale=0.7 },
        Sakura    = { Brightness=2.2, ExposureCompensation=0.35, ClockTime=15.5, OutdoorAmbient=Color3.fromRGB(200,155,180),
                      Ambient=Color3.fromRGB(120,85,110),
                      EnvironmentDiffuseScale=0.7,  EnvironmentSpecularScale=0.7 },
        Nebula    = { Brightness=2.2, ExposureCompensation=0.4,  ClockTime=0,    OutdoorAmbient=Color3.fromRGB(128,94,168),
                      Ambient=Color3.fromRGB(82,60,120),
                      EnvironmentDiffuseScale=0.55, EnvironmentSpecularScale=0.85 },
    }
    local _WHITE = Color3.new(1, 1, 1)
    local function applyFullbrightOverride()
        if not Config.VisualsFullbright then return end
        pcall(function() if Lighting.Ambient ~= _WHITE then Lighting.Ambient = _WHITE end end)
        pcall(function() if Lighting.OutdoorAmbient ~= _WHITE then Lighting.OutdoorAmbient = _WHITE end end)
        pcall(function() if Lighting.GlobalShadows ~= false then Lighting.GlobalShadows = false end end)
        pcall(function() if Lighting.Brightness < 2 then Lighting.Brightness = 2 end end)
    end
    local function applyFogOverride()
        if not Config.VisualsNoFog then return end
        pcall(function() if Lighting.FogEnd ~= 1e6 then Lighting.FogEnd = 1e6 end end)
        pcall(function() if Lighting.FogStart ~= 1e6 then Lighting.FogStart = 1e6 end end)
        for _, c in ipairs(Lighting:GetChildren()) do
            if c:IsA("Atmosphere") then
                pcall(function() if c.Density ~= 0 then c.Density = 0 end end)
            end
        end
    end
    local function cfg(key, default)
        local v = Config[key]
        if v == nil then return default end
        return v
    end
    local _GRADES = {
        Crisp = { B = 0.03,  C = 0.20, S = 0.18,  tint = _WHITE },
        Cold  = { B = -0.03, C = 0.28, S = -0.22, tint = Color3.fromRGB(196, 220, 255) },
        Warm  = { B = 0.04,  C = 0.22, S = 0.15,  tint = Color3.fromRGB(255, 222, 180) },
        Comp  = { B = -0.01, C = 0.40, S = 0.28,  tint = Color3.fromRGB(255, 248, 236) },
    }
    local _gradeFx = nil
    local function getGradeFx()
        if _gradeFx and _gradeFx.Parent then return _gradeFx end
        local cc = Instance.new("ColorCorrectionEffect")
        cc.Name = "_vs_grade"
        cc:SetAttribute("VS_Grade", true)
        cc.Parent = Lighting
        _gradeFx = cc
        return cc
    end
    local function reassertGrade()
        local g = _GRADES[cfg("VisualsGrade", "None")]
        if not g then
            if _gradeFx and _gradeFx.Parent then
                pcall(function() if _gradeFx.Enabled then _gradeFx.Enabled = false end end)
            end
            return
        end
        local s  = math.clamp(cfg("VisualsGradeStrength", 1), 0, 1)
        local tB, tC, tS = g.B * s, g.C * s, g.S * s
        local tT = g.tint:Lerp(_WHITE, 1 - s)
        local cc = getGradeFx()
        pcall(function()
            if not cc.Enabled then cc.Enabled = true end
            if math.abs(cc.Brightness - tB) > 0.001 then cc.Brightness = tB end
            if math.abs(cc.Contrast   - tC) > 0.001 then cc.Contrast   = tC end
            if math.abs(cc.Saturation - tS) > 0.001 then cc.Saturation = tS end
            if cc.TintColor ~= tT then cc.TintColor = tT end
        end)
    end
    local function clearGrade()
        if _gradeFx then pcall(function() _gradeFx:Destroy() end); _gradeFx = nil end
    end
    local _bloomFx = nil
    local function getBloomFx()
        if _bloomFx and _bloomFx.Parent then return _bloomFx end
        local b = Instance.new("BloomEffect")
        b.Name = "_vs_bloom"; b:SetAttribute("VS_Bloom", true)
        b.Size = 24; b.Threshold = 0.8; b.Intensity = 0
        b.Parent = Lighting
        _bloomFx = b
        return b
    end
    local function reassertBloom()
        if not cfg("VisualsBloom", false) then
            if _bloomFx and _bloomFx.Parent then
                pcall(function() if _bloomFx.Enabled then _bloomFx.Enabled = false end end)
            end
            return
        end
        local tI = math.clamp(cfg("VisualsBloomIntensity", 1), 0, 3)
        local b = getBloomFx()
        pcall(function()
            if not b.Enabled then b.Enabled = true end
            if math.abs(b.Intensity - tI) > 0.01 then b.Intensity = tI end
        end)
    end
    local function clearBloom()
        if _bloomFx then pcall(function() _bloomFx:Destroy() end); _bloomFx = nil end
    end
    local function reassertScalars()
        local sc = PresetScalars[State.VisualsCurrentPreset or Config.VisualsPreset]
        if sc then
            for k, v in pairs(sc) do pcall(function() if Lighting[k] ~= v then Lighting[k] = v end end) end
            pcall(function() if Lighting.GlobalShadows ~= false then Lighting.GlobalShadows = false end end)
        end
        applyFullbrightOverride()
        applyFogOverride()
        reassertGrade()
        reassertBloom()
    end
    local function startReassert()
        if _reassertConn then return end
        _reassertConn = RunService.Heartbeat:Connect(function()
            if not Config.Visuals or Config.VisualsPerformanceMode then return end
            local now = tick()
            if (now - _reassertLastT) < 1.0 then return end
            _reassertLastT = now
            reassertScalars()
        end)
    end
    local function stopReassert()
        if _reassertConn then _reassertConn:Disconnect(); _reassertConn = nil end
    end
    Visuals.PresetOrder = { "Neutral", "Clarity", "Cyberpunk", "Anime", "Sunset", "Vaporwave", "Toxic", "Void", "Sakura", "Nebula" }
    local function applyPreset(name)
        if not Config.Visuals or Config.VisualsPerformanceMode then return end
        local fn = Presets[name]; if not fn then return end
        pcall(fn); State.VisualsCurrentPreset = name; Config.VisualsPreset = name
        reassertGrade()
        reassertBloom()
    end
    local function getHoloFolder()
        if _hologramFolder and _hologramFolder.Parent then return _hologramFolder end
        local f = Instance.new("Folder"); f.Name = "_vs_holos"; f.Parent = Workspace
        _hologramFolder = f; return f
    end
    local _GOLD = Color3.fromRGB(255, 200, 60)
    local _EDGE    = Color3.fromRGB(155, 232, 255)
    local _VISIBLE = Color3.fromRGB(41, 224, 255)
    local function easeInOut(a) return a * a * (3 - 2 * a) end
    local function fadePop(container, parts, hl, dur, tr0)
        tr0 = tr0 or 0.55
        local startT = tick()
        local conn
        conn = RunService.Heartbeat:Connect(function()
            if not container.Parent then if conn then conn:Disconnect() end return end
            local a  = math.clamp((tick() - startT) / dur, 0, 1)
            local e  = easeInOut(a)
            local tr = tr0 + (1 - tr0) * e
            for _, b in ipairs(parts) do b.Transparency = tr end
            if hl then hl.OutlineTransparency = e end
            if a >= 1 and conn then conn:Disconnect() end
        end)
        Debris:AddItem(container, dur + 0.2)
    end
    local function createHologram(character, lethal)
        if not character or not character.Parent then return end
        local rp = character:FindFirstChild("HitboxHead")
            or character:FindFirstChild("Head")
            or character:FindFirstChild("HumanoidRootPart")
            or character:FindFirstChild("UpperTorso")
        if not rp then return end
        if (rp.Position - Camera.CFrame.Position).Magnitude > Config.VisualsHologramRange then return end
        if #getHoloFolder():GetChildren() >= 16 then return end
        local dur = math.clamp(Config.VisualsHologramDuration or 3.5, 0.25, 10)
        local lethalOn  = lethal and cfg("VisualsHologramLethal", true)
        local mainColor = lethalOn and cfg("VisualsHologramLethalColor", _GOLD) or Config.VisualsHologramColor
        local folder = getHoloFolder()
        local function mkBall(size, transp, color)
            local b = Instance.new("Part")
            b.Shape = Enum.PartType.Ball
            b.Size = Vector3.new(size, size, size)
            b.Material = Enum.Material.Neon
            b.Color = color
            b.Transparency = transp
            b.Anchored = true; b.CanCollide = false; b.CanQuery = false
            b.CanTouch = false; b.CastShadow = false; b.Massless = true
            b:SetAttribute("VS_Holo", true)
            return b
        end
        local vis = math.clamp(cfg("VisualsHologramVisibility", 1.4), 0.2, 2)
        local sc  = 0.75 + 0.25 * vis
        local h0  = math.clamp(0.65 / vis, 0.1, 0.9)
        local core = mkBall(0.7 * sc, 0.05, mainColor)
        local halo = mkBall(1.7 * sc, h0, mainColor)
        local startCF = CFrame.new(rp.Position)
        core.CFrame = startCF; halo.CFrame = startCF
        core.Name = "_h" .. math.random(10000, 99999); halo.Name = core.Name .. "_g"
        core.Parent = folder; halo.Parent = folder
        local startT = tick()
        local conn
        conn = RunService.Heartbeat:Connect(function()
            if not core.Parent then if conn then conn:Disconnect() end return end
            local alpha = math.clamp((tick() - startT) / dur, 0, 1)
            local rise  = 2.5 * (1 - (1 - alpha) * (1 - alpha))
            local cf    = startCF + Vector3.new(0, rise, 0)
            core.CFrame = cf; halo.CFrame = cf
            core.Transparency = math.clamp(0.05 + 0.95 * alpha, 0, 1)
            halo.Transparency = math.clamp(h0 + (1 - h0) * alpha, 0, 1)
            if alpha >= 1 and conn then conn:Disconnect() end
        end)
        Debris:AddItem(core, dur + 0.2)
        Debris:AddItem(halo, dur + 0.2)
    end
    function Visuals.previewHologram(character)
        createHologram(character, Config.VisualsHologramLethal)
    end
    function Visuals.onShotHit(character)
        if not Config.VisualsHolograms or not character then return end
        local now=tick()
        if now-(_hologramCooldowns[character] or 0)<0.15 then return end
        _hologramCooldowns[character]=now
        local hum=character:FindFirstChildOfClass("Humanoid")
        createHologram(character,hum and hum.Health<=0)
    end
    local _hpPrev = {}
    function Visuals.notifyTarget(p, info)
        if not p or p == lp or not p.Character then return end
        local cur, maxHP = getHealth(p)
        local dmg = math.max(0, (_hpPrev[p] or maxHP) - cur)
        _hpPrev[p] = cur
        local lethal = (not isAlive(p)) or cur <= 0
        local char = p.Character
        local rp = char:FindFirstChild("HitboxHead")
            or char:FindFirstChild("Head")
            or char:FindFirstChild("HumanoidRootPart")
            or char:FindFirstChild("UpperTorso")
        local hitPos = rp and rp.Position or nil
        local crit = (info and info.crit) or (dmg >= cfg("FXCritDamage", 30))
        if Config.VisualsHolograms then
            local now = tick()
            if (now - (_hologramCooldowns[p] or 0)) >= 0.35 then
                _hologramCooldowns[p] = now
                createHologram(char, lethal)
            end
        end
        FX.onHit(p, dmg, crit, lethal, hitPos)
    end
    local _fovSaved = nil
    local _tpRP = nil
    local function bindStretch()
        if _stretchBound then return end
        _stretchBound = true
        RunService:BindToRenderStep("VS_Stretch", Enum.RenderPriority.Last.Value+1, function()
            if not running or not Camera then return end
            local s = Config.VisualsStretch or 1.0
            local doStretch = math.abs(s - 1.0) >= 0.001
            local doSway = Config.VisualsCameraSway
            local doAspect = Config.CameraAspectRatioEnabled
            local doThird  = Config.ThirdPersonEnabled
            local doExtra = Config.ExtraRatioEnabled
            if Config.CameraFovOverride then
                local want = math.clamp(Config.CameraFovAmount or 90, 40, 130)
                if _fovSaved == nil then _fovSaved = Camera.FieldOfView end
                if Camera.FieldOfView ~= want then Camera.FieldOfView = want end
            elseif _fovSaved ~= nil then
                Camera.FieldOfView = _fovSaved; _fovSaved = nil
            end
            if not (doStretch or doSway or doAspect or doThird or doExtra) then return end
            local c = Camera.CFrame
            if doSway then
                local amt = math.clamp(Config.VisualsCameraSwayAmount or 0.5, 0, 1)
                local t = tick()
                local roll  = (math.sin(t * 0.9) + math.sin(t * 0.37) * 0.6) * amt
                local pitch =  math.sin(t * 1.3) * 0.7 * amt
                local yaw   =  math.sin(t * 0.7) * 0.8 * amt
                c = c * CFrame.Angles(math.rad(pitch), math.rad(yaw), math.rad(roll))
            end
            if doStretch then
                c = CFrame.fromMatrix(c.Position, c.RightVector * s, c.UpVector)
            end
            if doAspect then
                local rx = math.clamp(Config.CameraAspectRatioX or 4, 1, 21)
                local ry = math.clamp(Config.CameraAspectRatioY or 3, 1, 21)
                c = CFrame.fromMatrix(c.Position, c.RightVector * ((rx / ry) / math.max(Camera.ViewportSize.X / math.max(Camera.ViewportSize.Y, 1), 0.01)), c.UpVector)
            end
            if doExtra then
                local w=math.clamp(Config.ExtraRatioWidth or 100,10,150)/100
                local h=math.clamp(Config.ExtraRatioHeight or 100,10,150)/100
                c=CFrame.fromMatrix(c.Position,c.RightVector,c.UpVector*h,-c.LookVector*(w/h))
            end
            if doThird and lp.Character then
                local dist = math.clamp(Config.ThirdPersonDistance or 12, 4, 30)
                local desiredPos = c.Position - c.LookVector * dist
                if _tpRP == nil then
                    _tpRP = RaycastParams.new()
                    _tpRP.FilterType = Enum.RaycastFilterType.Exclude
                end
                _tpRP.FilterDescendantsInstances = { lp.Character }
                local hit = Workspace:Raycast(c.Position, -c.LookVector * dist, _tpRP)
                if hit then desiredPos = hit.Position + c.LookVector * 0.5 end
                c = (c - c.Position) + desiredPos
            end
            Camera.CFrame = c
        end)
    end
    local function startRainbow()
        if _rainbowConn then return end
        _rainbowBatchIdx = 1; table.clear(_rainbowParts)
        local charSet = {}
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl.Character then charSet[pl.Character] = true end
        end
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("BasePart") and not d:GetAttribute("VS_Holo")
                and not charSet[d.Parent]
                and d.Name ~= "Terrain" then
                table.insert(_rainbowParts, { part = d, originalColor = d.Color })
            end
        end
        _rainbowConn = RunService.Heartbeat:Connect(function(dt)
            if not Config.Visuals or not Config.VisualsRainbowMap then return end
            _rainbowHue = (_rainbowHue + dt * Config.VisualsRainbowMapSpeed) % 1
            local total = #_rainbowParts; if total == 0 then return end
            local batch = math.min(250, total)
            for i = 1, batch do
                local idx = ((_rainbowBatchIdx - 1 + i - 1) % total) + 1
                local e   = _rainbowParts[idx]
                if e and e.part and e.part.Parent then
                    e.part.Color = Color3.fromHSV((_rainbowHue + (idx / total) * 0.3) % 1, 0.85, 1)
                end
            end
            _rainbowBatchIdx = ((_rainbowBatchIdx + batch - 1) % total) + 1
        end)
    end
    local function stopRainbow()
        if _rainbowConn then _rainbowConn:Disconnect(); _rainbowConn = nil end
        for _, e in ipairs(_rainbowParts) do
            if e.part and e.part.Parent then pcall(function() e.part.Color = e.originalColor end) end
        end
        table.clear(_rainbowParts)
    end
    function Visuals.toggleRainbowMap(on)
        Config.VisualsRainbowMap = on
        if on and Config.Visuals then startRainbow() else stopRainbow() end
    end
    function Visuals.setStretch(v)
        Config.VisualsStretch = math.clamp(v, Config.VisualsStretchMin, Config.VisualsStretchMax)
    end
    function Visuals.togglePerf(on)
        Config.VisualsPerformanceMode = on
        if on then
            clearTagged(); clearGrade(); clearBloom()
            Lighting.GlobalShadows = false; Lighting.EnvironmentDiffuseScale = 0
            Lighting.EnvironmentSpecularScale = 0; Lighting.Brightness = 2
        else
            applyPreset(State.VisualsCurrentPreset or Config.VisualsPreset or 'Neutral')
        end
    end
    function Visuals.setPreset(name) if Presets[name] then Config.VisualsPreset = name; applyPreset(name) end end
    function Visuals.toggleHolograms(on) Config.VisualsHolograms = on end
    function Visuals.setHologramStyle(name) Config.VisualsHologramStyle = name end
    Visuals.HologramStyleOrder = { "Orb", "Skeleton", "Wraith" }
    Visuals.GradeOrder = { "None", "Crisp", "Cold", "Warm", "Comp" }
    function Visuals.setGrade(name)
        Config.VisualsGrade = name
        if not Config.Visuals or Config.VisualsPerformanceMode then return end
        reassertGrade()
    end
    function Visuals.setGradeStrength(v)
        Config.VisualsGradeStrength = math.clamp(v, 0, 1)
        if not Config.Visuals or Config.VisualsPerformanceMode then return end
        reassertGrade()
    end
    function Visuals.setBloom(on)
        Config.VisualsBloom = on
        if not Config.Visuals or Config.VisualsPerformanceMode then return end
        reassertBloom()
    end
    function Visuals.setBloomIntensity(v)
        Config.VisualsBloomIntensity = math.clamp(v, 0, 3)
        if not Config.Visuals or Config.VisualsPerformanceMode then return end
        reassertBloom()
    end
    function Visuals.toggleFullbright(on)
        Config.VisualsFullbright = on
        if not Config.Visuals or Config.VisualsPerformanceMode then return end
        if on then applyFullbrightOverride()
        else applyPreset(State.VisualsCurrentPreset or Config.VisualsPreset or "Neutral") end
    end
    function Visuals.toggleNoFog(on)
        Config.VisualsNoFog = on
        if not Config.Visuals or Config.VisualsPerformanceMode then return end
        if on then applyFogOverride()
        else applyPreset(State.VisualsCurrentPreset or Config.VisualsPreset or "Neutral") end
    end
    function Visuals.enable()
        Config.Visuals = true; applyPreset(Config.VisualsPreset or "Neutral")
        if not Config.VisualsPerformanceMode then
            applyFullbrightOverride(); applyFogOverride()
        end
        bindStretch()
        if Config.VisualsRainbowMap then startRainbow() end
        if Config.VisualsPerformanceMode then Visuals.togglePerf(true) end
        startReassert()
    end
    function Visuals.disable()
        Config.Visuals = false; stopRainbow(); stopReassert()
        clearGrade(); clearBloom()
        restore()
        if _fovSaved ~= nil then
            pcall(function() Camera.FieldOfView = _fovSaved end)
            _fovSaved = nil
        end
    end
    function Visuals.unload()
        Visuals.disable(); stopReassert()
        if _fovSaved ~= nil then
            pcall(function() Camera.FieldOfView = _fovSaved end)
            _fovSaved = nil
        end
        if _hologramFolder then pcall(function() _hologramFolder:Destroy() end); _hologramFolder = nil end
        if _stretchBound then
            pcall(function() RunService:UnbindFromRenderStep("VS_Stretch") end)
            _stretchBound = false
        end
    end
    function Visuals.init()
        snapshotLighting()
        bindStretch()
    end
end)()

-- CHUNK 2 ENDS HERE. Chunk 3 adds:
--   Weather engine + GameVisuals core + all the UI tabs