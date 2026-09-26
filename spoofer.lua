-- language: Lua (Roblox Luau), file: spoofer.lua
-- standalone Linoria build of the prism beta v1 suite.

pcall(function()
    if SpooferConn then SpooferConn:Disconnect() end
    if BurgadaSpooferUnload then pcall(BurgadaSpooferUnload) end
end)
pcall(function()
    local cg = game:GetService('CoreGui')
    for _, name in ipairs({ 'LinoriaLib', '_vs_fx', '_vs_cam', '_vs_grade' }) do
        local g = cg:FindFirstChild(name)
        if g then g:Destroy() end
    end
end)

local urls = {
    'https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/Library.lua',
    'https://raw.githubusercontent.com/mstudio45/LinoriaLib/refs/heads/main/Library.lua',
    'https://cdn.jsdelivr.net/gh/mstudio45/LinoriaLib@main/Library.lua',
}
local function tryFetch(url)
    if syn and syn.request then
        local ok, r = pcall(syn.request, { Url = url, Method = 'GET' })
        if ok and r and r.Body and #r.Body > 0 then return r.Body end
    end
    if http_request then
        local ok, r = pcall(http_request, { Url = url, Method = 'GET' })
        if ok and r and r.Body and #r.Body > 0 then return r.Body end
    end
    if request then
        local ok, r = pcall(request, { Url = url, Method = 'GET' })
        if ok and r and r.Body and #r.Body > 0 then return r.Body end
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and body and #body > 0 then return body end
    return nil
end

local libSrc
for _, u in ipairs(urls) do
    warn('[Burgada] trying', u)
    libSrc = tryFetch(u)
    if libSrc then warn('[Burgada] success from', u, '#', #libSrc); break end
    warn('[Burgada] failed:', u)
end
if not libSrc then warn('[Burgada] ALL URLS FAILED'); return end
local Library = loadstring(libSrc)()
if not Library then warn('[Burgada] Library nil'); return end

local function fetchAddon(name)
    for _, base in ipairs({
        'https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/addons/' .. name,
        'https://raw.githubusercontent.com/mstudio45/LinoriaLib/refs/heads/main/addons/' .. name,
        'https://cdn.jsdelivr.net/gh/mstudio45/LinoriaLib@main/addons/' .. name,
    }) do
        local s = tryFetch(base)
        if s then
            local ok, mod = pcall(function() return loadstring(s)() end)
            if ok and mod then return mod end
        end
    end
    return nil
end

local ThemeManager = fetchAddon('ThemeManager.lua')
local SaveManager  = fetchAddon('SaveManager.lua')
Library.ShowToggleFrameInKeybinds = true
Library.ShowCustomCursor          = false
Library.NotifySide                = 'Left'

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UIS = game:GetService('UserInputService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Lighting = game:GetService('Lighting')
local Debris = game:GetService('Debris')
local TweenService = game:GetService('TweenService')
local SoundService = game:GetService('SoundService')
local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local connections, restorers = {}, {}
local running = true
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end
connect(workspace:GetPropertyChangedSignal('CurrentCamera'), function()
    Camera = workspace.CurrentCamera
end)

local env = (getgenv and getgenv()) or _G
if env.__BurgadaSpoofer then pcall(env.__BurgadaSpoofer) end

local Window = Library:CreateWindow({
    Title     = 'Burgada Lua | Spoofer v1',
    Center    = true,
    AutoShow  = true,
    Resizable = true,
    NotifySide = 'Left',
})

local Tabs = {
    Cosmetics  = Window:AddTab('Cosmetics'),
    Weapons    = Window:AddTab('Weapons'),
    Inventory  = Window:AddTab('Inventory'),
    World      = Window:AddTab('World'),
    Spoofer    = Window:AddTab('Spoofer'),
    Misc       = Window:AddTab('Misc'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

local function notify(msg)
    pcall(function() Library:Notify(tostring(msg), 5) end)
end

local function patch(target, name, replacement)
    if target == nil then return false end
    local old = target[name]
    target[name] = replacement
    table.insert(restorers, function()
        if target[name] == replacement then target[name] = old end
    end)
    return old
end

local moduleErrors = {}
local moduleCache = setmetatable({}, {__mode='k'})
local function loadGameModule(root, names)
    local path = table.concat(names, '.')
    local node = root
    for _, name in ipairs(names) do
        node = node and node:FindFirstChild(name)
        if not node then moduleErrors[path] = 'not loaded yet'; return nil end
    end
    if not node:IsA('ModuleScript') then moduleErrors[path] = 'not a ModuleScript'; return nil end
    if moduleCache[node] then return moduleCache[node] end
    local ok, value = pcall(require, node)
    if ok and type(value) == 'table' then
        moduleCache[node] = value
        moduleErrors[path] = nil
        return value
    end
    moduleErrors[path] = tostring(value)
    return nil
end

local Rivals = {Ready = false}
local function resolveRivals()
    local scripts = LP:FindFirstChild('PlayerScripts')
    Rivals.Fighter = Rivals.Fighter or loadGameModule(scripts, {'Controllers','FighterController'})
    Rivals.Enums = Rivals.Enums or loadGameModule(ReplicatedStorage, {'Modules','EnumLibrary'})
    Rivals.Cosmetics = Rivals.Cosmetics or loadGameModule(ReplicatedStorage, {'Modules','CosmeticLibrary'})
    Rivals.ItemLib = Rivals.ItemLib or loadGameModule(ReplicatedStorage, {'Modules','ItemLibrary'})
    Rivals.SeasonLibrary = Rivals.SeasonLibrary or loadGameModule(ReplicatedStorage, {'Modules','SeasonLibrary'})
    Rivals.PlayerDataController = Rivals.PlayerDataController or loadGameModule(scripts, {'Controllers','PlayerDataController'})
    Rivals.Gun = Rivals.Gun or loadGameModule(scripts, {'Modules','ItemTypes','Gun'})
    Rivals.Ready = Rivals.Fighter ~= nil
end

local function getEquippedItem()
    local ctrl = Rivals.Fighter
    if not ctrl then return nil end
    local fighter = ctrl.LocalFighter
    if not fighter and type(ctrl.GetFighter) == 'function' then
        local ok, value = pcall(ctrl.GetFighter, ctrl, LP)
        if ok then fighter = value end
    end
    if not fighter and ctrl._player_to_fighter then fighter = ctrl._player_to_fighter[LP] end
    return fighter and fighter.EquippedItem
end

local function getHealth(player)
    local hum = player.Character and player.Character:FindFirstChildOfClass('Humanoid')
    return hum and hum.Health or 0, hum and hum.MaxHealth or 100
end

local State = { Shots = 0, Hits = 0 }

local Config = {
    GameVisuals=false, GVUnlockAll=false, GVUnlockWeapons=false,
    GVWrapInverted=false, GVEveryone=false, GVBirthHook=true,
    GVFinisherClone=true, GVRemember=true, GVRankCharmOn=false,
    GVRankCharmRank="", GVRankCharmLb=0, GVEmotes=false,
    Visuals = false, VisualsPreset = "Neutral", VisualsPerformanceMode = false,
    VisualsFullbright = false, VisualsNoFog = false, VisualsHolograms = false,
    VisualsRainbowMap = false, VisualsRainbowMapSpeed = 0.15, VisualsStretch = 1.0,
    VisualsStretchMin = 0.5, VisualsStretchMax = 1.2,
    VisualsCameraSway = false, VisualsCameraSwayAmount = 0.5,
    VisualsHologramDuration = 3.5, VisualsHologramRange = 300, VisualsHologramVisibility = 1.4,
    VisualsHologramColor = Color3.fromRGB(0, 220, 255), VisualsHologramAccent = Color3.fromRGB(255, 60, 200),
    VisualsGrade = "Crisp", VisualsGradeStrength = 0.6,
    VisualsBloom = false, VisualsBloomIntensity = 1.0,
    VisualsVignette = false, VisualsVignetteStrength = 0.6,
    VisualsLetterbox = false, VisualsLetterboxSize = 0.10,
    VisualsDOF = false, VisualsDOFDistance = 28, VisualsDOFBlur = 0.5,
    VisualsHologramStyle = "Orb", VisualsHologramLethal = true,
    VisualsHologramLethalColor = Color3.fromRGB(255, 200, 60),
    HUD = false,
    Weather = false, WeatherType = "Rain", WeatherIntensity = 1.0,
    WeatherMeteors = false, WeatherMeteorRate = 1.0, WeatherStarRate = 1.0,
    WeatherClockDial = false, WeatherClockCycleMin = 8,
    WeatherStorm = false, WeatherStormFlash = true,
    WeatherStormMin = 4, WeatherStormVar = 8,
    WeatherThunderId = "rbxassetid://9113169432",
    WeatherSoundIds = {
        rain  = "rbxassetid://9112858162",
        wind  = "rbxassetid://9112854440",
        fire  = "rbxassetid://2787093357",
        night = "rbxassetid://9112764573",
        birds = "rbxassetid://9112749254",
    },
    WeatherSoundVolume = 0.35, WeatherMood = true,
    SkyboxPreset = "Off", SkyboxHideCelestial = false,
    WeatherGodRays = false, WeatherRainbow = false, WeatherShootingStars = false,
    WeatherPuddles = false,
    SpooferNameEnabled = false, SpooferName = "ProPlayer", SpooferDisplayName = "ProPlayer",
    SpooferLevelEnabled = false, SpooferLevel = 100,
    SpooferCasualWinsEnabled = false, SpooferCasualWins = 500,
    SpooferRankedWinsEnabled = false, SpooferRankedWins = 250,
    SpooferRankedEloEnabled = false, SpooferRankedElo = 2400,
    SpooferWinPercentEnabled = false, SpooferWinPercent = 75,
    SpooferWinStreakEnabled = false, SpooferWinStreak = 25,
    SpooferFavoriteMapEnabled = false, SpooferFavoriteMap = "Arena",
    VMOffsetEnabled = false, VMOffsetX = 0, VMOffsetY = 0, VMOffsetZ = 0,
    VMOffsetPitch = 0, VMOffsetYaw = 0, VMOffsetRoll = 0,
    VMChamsEnabled = false, VMChamsMaterial = "ForceField",
    VMChamsColor = Color3.fromRGB(53,215,199), VMChamsTransparency = 0.5,
    VMDisableTextures = false,
    CameraAspectRatioEnabled = false, CameraAspectRatioX = 4, CameraAspectRatioY = 3,
    CameraFovOverride = false, CameraFovAmount = 90,
    ThirdPersonEnabled = false, ThirdPersonDistance = 12,
    ExtraRatioEnabled = false, ExtraRatioWidth = 100, ExtraRatioHeight = 100,
    ExtraSkyStars = 3000, ExtraSkySun = 20, ExtraSkyMoon = 11,
    ExtraSkyRotate = false, ExtraSkySpeed = 10,
}

local Visuals = {}
local FX = {}

;(function()
    local _origLighting = nil
    local _hologramFolder, _hologramCooldowns = nil, {}
    local _stretchBound, _rainbowConn = false, nil
    local _rainbowParts, _rainbowHue, _rainbowBatchIdx = {}, 0, 1
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
    local _WHITE = Color3.new(1, 1, 1)
    local function cfg(key, default)
        local v = Config[key]
        if v == nil then return default end
        return v
    end
    Visuals.PresetOrder = { "Neutral", "Clarity", "Cyberpunk", "Anime", "Sunset", "Vaporwave", "Toxic", "Void", "Sakura", "Nebula" }
    local function applyPreset(name)
        if not Config.Visuals or Config.VisualsPerformanceMode then return end
        local fn = Presets[name]; if not fn then return end
        pcall(fn); State.VisualsCurrentPreset = name; Config.VisualsPreset = name
    end
    function Visuals.setPreset(name) if Presets[name] then Config.VisualsPreset = name; applyPreset(name) end end
    function Visuals.togglePerf(on)
        Config.VisualsPerformanceMode = on
        if on then clearTagged(); Lighting.GlobalShadows = false; Lighting.EnvironmentDiffuseScale = 0
            Lighting.EnvironmentSpecularScale = 0; Lighting.Brightness = 2
        else applyPreset(State.VisualsCurrentPreset or Config.VisualsPreset or 'Neutral') end
    end
    function Visuals.toggleFullbright(on)
        Config.VisualsFullbright = on
        if on then
            pcall(function() Lighting.Ambient = _WHITE; Lighting.OutdoorAmbient = _WHITE; Lighting.GlobalShadows = false end)
        else applyPreset(State.VisualsCurrentPreset or Config.VisualsPreset or 'Neutral') end
    end
    function Visuals.toggleNoFog(on)
        Config.VisualsNoFog = on
        if on then
            pcall(function() Lighting.FogEnd = 1e6; Lighting.FogStart = 1e6 end)
            for _, c in ipairs(Lighting:GetChildren()) do
                if c:IsA('Atmosphere') then pcall(function() c.Density = 0 end) end
            end
        else applyPreset(State.VisualsCurrentPreset or Config.VisualsPreset or 'Neutral') end
    end
    local _stretchBound2 = false
    local function bindStretch()
        if _stretchBound2 then return end
        _stretchBound2 = true
        RunService:BindToRenderStep('VS_Stretch', Enum.RenderPriority.Last.Value + 1, function()
            if not running or not Camera then return end
            local s = Config.VisualsStretch or 1.0
            if math.abs(s - 1.0) < 0.001 and not Config.VisualsCameraSway
                and not Config.CameraAspectRatioEnabled and not Config.ThirdPersonEnabled
                and not Config.ExtraRatioEnabled and not Config.CameraFovOverride then return end
            if Config.CameraFovOverride then
                local want = math.clamp(Config.CameraFovAmount or 90, 40, 130)
                if Camera.FieldOfView ~= want then Camera.FieldOfView = want end
            end
            local c = Camera.CFrame
            if Config.VisualsCameraSway then
                local amt = math.clamp(Config.VisualsCameraSwayAmount or 0.5, 0, 1)
                local t = tick()
                local roll  = (math.sin(t * 0.9) + math.sin(t * 0.37) * 0.6) * amt
                local pitch =  math.sin(t * 1.3) * 0.7 * amt
                local yaw   =  math.sin(t * 0.7) * 0.8 * amt
                c = c * CFrame.Angles(math.rad(pitch), math.rad(yaw), math.rad(roll))
            end
            if math.abs(s - 1.0) >= 0.001 then
                c = CFrame.fromMatrix(c.Position, c.RightVector * s, c.UpVector)
            end
            if Config.ThirdPersonEnabled and LP.Character then
                local dist = math.clamp(Config.ThirdPersonDistance or 12, 4, 30)
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = { LP.Character }
                local hit = workspace:Raycast(c.Position, -c.LookVector * dist, params)
                local desired = c.Position - c.LookVector * dist
                if hit then desired = hit.Position + c.LookVector * 0.5 end
                c = (c - c.Position) + desired
            end
            Camera.CFrame = c
        end)
    end
    function Visuals.enable()
        Config.Visuals = true
        applyPreset(Config.VisualsPreset or 'Neutral')
        bindStretch()
    end
    function Visuals.disable()
        Config.Visuals = false
        clearTagged()
        restore()
    end
    function Visuals.unload()
        Visuals.disable()
        if _hologramFolder then pcall(function() _hologramFolder:Destroy() end); _hologramFolder = nil end
        if _stretchBound2 then
            pcall(function() RunService:UnbindFromRenderStep('VS_Stretch') end)
            _stretchBound2 = false
        end
    end
    function Visuals.init() snapshotLighting(); bindStretch() end
    local function getHoloFolder()
        if _hologramFolder and _hologramFolder.Parent then return _hologramFolder end
        local f = Instance.new('Folder'); f.Name = '_vs_holos'; f.Parent = workspace
        _hologramFolder = f; return f
    end
    local _GOLD = Color3.fromRGB(255,200,60)
    local function createHologram(character, lethal)
        if not character or not character.Parent then return end
        local rp = character:FindFirstChild('HitboxHead') or character:FindFirstChild('Head')
            or character:FindFirstChild('HumanoidRootPart') or character:FindFirstChild('UpperTorso')
        if not rp then return end
        if (rp.Position - Camera.CFrame.Position).Magnitude > Config.VisualsHologramRange then return end
        if #getHoloFolder():GetChildren() >= 16 then return end
        local dur = math.clamp(Config.VisualsHologramDuration or 3.5, 0.25, 10)
        local color = lethal and Config.VisualsHologramLethalColor or Config.VisualsHologramColor
        local folder = getHoloFolder()
        local function mkBall(size, transp, c)
            local b = Instance.new('Part')
            b.Shape = Enum.PartType.Ball; b.Size = Vector3.new(size, size, size)
            b.Material = Enum.Material.Neon; b.Color = c; b.Transparency = transp
            b.Anchored = true; b.CanCollide = false; b.CanQuery = false; b.CanTouch = false
            b.CastShadow = false; b.Massless = true
            b:SetAttribute('VS_Holo', true)
            return b
        end
        local core = mkBall(0.7, 0.05, color)
        local halo = mkBall(1.7, 0.65, color)
        local cf = CFrame.new(rp.Position)
        core.CFrame = cf; halo.CFrame = cf
        core.Parent = folder; halo.Parent = folder
        local startT = tick()
        local conn = RunService.Heartbeat:Connect(function()
            if not core.Parent then if conn then conn:Disconnect() end return end
            local a = math.clamp((tick() - startT) / dur, 0, 1)
            local rise = 2.5 * (1 - (1 - a) * (1 - a))
            local np = cf.Position + Vector3.new(0, rise, 0)
            core.CFrame = CFrame.new(np); halo.CFrame = CFrame.new(np)
            core.Transparency = math.clamp(0.05 + 0.95 * a, 0, 1)
            halo.Transparency = math.clamp(0.65 + 0.35 * a, 0, 1)
            if a >= 1 and conn then conn:Disconnect() end
        end)
        Debris:AddItem(core, dur + 0.2)
        Debris:AddItem(halo, dur + 0.2)
    end
    function Visuals.previewHologram(char) createHologram(char, Config.VisualsHologramLethal) end
    function Visuals.onShotHit(char)
        if not Config.VisualsHolograms or not char then return end
        local now = tick()
        if now - (_hologramCooldowns[char] or 0) < 0.15 then return end
        _hologramCooldowns[char] = now
        local hum = char:FindFirstChildOfClass('Humanoid')
        createHologram(char, hum and hum.Health <= 0)
    end
end)()

-- PART 1 ENDS HERE. Part 2 continues with FX engine, Weather,
-- GameVisuals, and the full UI tab construction.