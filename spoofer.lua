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
-- ============================================================
-- FX — hit markers, damage numbers, kill feed
-- ============================================================
local _hitMarker = { on = false, t0 = 0, pop = 0, color = Color3.new(1,1,1) }
local _damageNumbers = {}
local _killFeed = {}
local _started = false
local _fxGui = nil
local _hitLines, _hitLinesBlk = {}, {}
local _dnText = {}
local _killText = {}
local _flashFrame = nil
local _hf = { on = false, t0 = 0 }
local _WHITE = Color3.new(1, 1, 1)
local _GOLD = Color3.fromRGB(255,194,75)

local function ensureFxGui()
    if _fxGui and _fxGui.Parent then return end
    local g = Instance.new('ScreenGui')
    g.Name = '_vs_fx'; g.IgnoreGuiInset = true; g.ResetOnSpawn = false
    g.DisplayOrder = 999
    pcall(function() g.Parent = (gethui and gethui()) or game:GetService('CoreGui') end)
    if not g.Parent then pcall(function() g.Parent = LP:FindFirstChildOfClass('PlayerGui') end) end
    _fxGui = g
end

local function ensureFxAllocated()
    if _hitLines[1] then return end
    ensureFxGui()
    local g = _fxGui
    for i = 1, 4 do
        local f = Instance.new('Frame')
        f.BorderSizePixel = 0; f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Visible = false; f.ZIndex = 5
        f.BackgroundColor3 = Color3.new(0, 0, 0)
        f.Parent = g
        _hitLinesBlk[i] = f
        local l = Instance.new('Frame')
        l.BorderSizePixel = 0; l.AnchorPoint = Vector2.new(0.5, 0.5)
        l.Visible = false; l.ZIndex = 6
        l.Parent = g
        _hitLines[i] = l
    end
    for i = 1, 24 do
        local t = Instance.new('TextLabel')
        t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamBold
        t.TextSize = 14; t.Visible = false; t.ZIndex = 10
        t.TextColor3 = _WHITE
        local st = Instance.new('UIStroke'); st.Thickness = 1; st.Color = Color3.new(0,0,0)
        st.Parent = t
        t.Parent = g
        _dnText[i] = t
    end
    for i = 1, 5 do
        local t = Instance.new('TextLabel')
        t.BackgroundTransparency = 1; t.Font = Enum.Font.Code
        t.TextSize = 13; t.TextXAlignment = Enum.TextXAlignment.Right
        t.TextColor3 = _WHITE; t.Visible = false; t.ZIndex = 10
        local st = Instance.new('UIStroke'); st.Thickness = 1; st.Color = Color3.new(0,0,0)
        st.Parent = t
        t.Parent = g
        _killText[i] = t
    end
    local f = Instance.new('Frame')
    f.Name = '_fl'; f.BackgroundColor3 = Color3.fromRGB(194,30,47)
    f.BackgroundTransparency = 1; f.BorderSizePixel = 0
    f.Size = UDim2.new(1, 0, 1, 0); f.Visible = false; f.ZIndex = 1
    f.Parent = g
    _flashFrame = f
end

local function triggerHitMarker(crit, lethal)
    ensureFxAllocated()
    local now = tick()
    if _hitMarker.on and (now - _hitMarker.t0) < 0.18 then
        _hitMarker.pop = math.min(_hitMarker.pop + 1, 3)
    else
        _hitMarker.pop = 0
    end
    _hitMarker.on = true; _hitMarker.t0 = now
    _hitMarker.color = lethal and Color3.fromRGB(255,64,78)
        or (crit and _GOLD)
        or Color3.new(1,1,1)
end

local function pushDamageNumber(p, dmg, crit, lethal, hitPos)
    ensureFxAllocated()
    if not hitPos then return end
    for _, e in ipairs(_damageNumbers) do
        if e.p == p and (tick() - e.t0) < 0.9 then
            e.total = e.total + dmg; e.t0 = tick(); e.popT = tick()
            return
        end
    end
    for _, t in ipairs(_dnText) do
        if not t.Visible then
            table.insert(_damageNumbers, { t = t, p = p, total = dmg, t0 = tick(),
                popT = tick(), pos = hitPos, drift = math.random(-8, 8),
                crit = crit, lethal = lethal })
            return
        end
    end
end

local _sessKills = 0
local function pushKillFeed(p, crit)
    ensureFxAllocated()
    table.insert(_killFeed, 1, { text = 'You  ·  ' .. tostring(p.DisplayName or p.Name),
        t0 = tick(), crit = crit })
    while #_killFeed > 5 do table.remove(_killFeed) end
end

local function triggerFlash()
    if not _flashFrame then return end
    _hf.on = true; _hf.t0 = tick()
end

FX.onHit = function(p, dmg, crit, lethal, hitPos)
    if not _started then return end
    triggerHitMarker(crit, lethal)
    if dmg > 0 then pushDamageNumber(p, dmg, crit, lethal, hitPos) end
    if lethal then
        _sessKills = _sessKills + 1
        pushKillFeed(p, crit)
    end
end

FX.onIncoming = function(drop)
    if not _started then return end
    triggerFlash()
end

local function fxUpdate()
    local now = tick()
    local vp = Camera.ViewportSize
    local cx, cy = vp.X * 0.5, vp.Y * 0.5

    if _hitMarker.on then
        local a = now - _hitMarker.t0
        if a >= 0.18 then
            _hitMarker.on = false
            for i = 1, 4 do
                if _hitLines[i] then _hitLines[i].Visible = false end
                if _hitLinesBlk[i] then _hitLinesBlk[i].Visible = false end
            end
        else
            local snap = math.clamp(a / 0.07, 0, 1)
            snap = 1 - (1 - snap) * (1 - snap)
            local gap = 5
            local len = 8 * snap + _hitMarker.pop
            local th = 2
            local tr = 1 - math.clamp((a - 0.09) / 0.09, 0, 1)
            local diag = { Vector2.new(1,1), Vector2.new(-1,1), Vector2.new(1,-1), Vector2.new(-1,-1) }
            local inv = 0.70710678
            for i = 1, 4 do
                local nx = diag[i].X * inv
                local ny = diag[i].Y * inv
                local from = Vector2.new(cx + nx * gap, cy + ny * gap)
                local to   = Vector2.new(cx + nx * (gap + len), cy + ny * (gap + len))
                local l = _hitLines[i]; local lb = _hitLinesBlk[i]
                if l and lb then
                    local dx = to.X - from.X; local dy = to.Y - from.Y
                    local len2 = math.sqrt(dx * dx + dy * dy)
                    local mid = Vector2.new((from.X + to.X) * 0.5, (from.Y + to.Y) * 0.5)
                    local rot = math.deg(math.atan2(dy, dx))
                    lb.Visible = true; lb.Position = UDim2.fromOffset(mid.X, mid.Y)
                    lb.Size = UDim2.fromOffset(len2, th + 2); lb.Rotation = rot
                    lb.BackgroundColor3 = Color3.new(0,0,0); lb.BackgroundTransparency = 1 - tr
                    l.Visible = true; l.Position = UDim2.fromOffset(mid.X, mid.Y)
                    l.Size = UDim2.fromOffset(len2, th); l.Rotation = rot
                    l.BackgroundColor3 = _hitMarker.color; l.BackgroundTransparency = 1 - tr
                end
            end
        end
    end

    for i = #_damageNumbers, 1, -1 do
        local e = _damageNumbers[i]
        local a = (now - e.t0) / 0.7
        if a >= 1 then
            e.t.Visible = false
            table.remove(_damageNumbers, i)
        else
            local sp = Camera:WorldToViewportPoint(e.pos)
            if sp.Z <= 0 then
                e.t.Visible = false
            else
                local ease = 1 - (1 - a) * (1 - a)
                local pop = 1 + 0.25 * (1 - math.clamp((now - e.popT) / 0.12, 0, 1))
                e.t.TextSize = math.floor((14 + math.clamp(e.total / 50, 0, 1) * 8) * pop + 0.5)
                e.t.Text = tostring(math.floor(e.total + 0.5))
                if e.crit or e.lethal then e.t.TextColor3 = _GOLD
                else e.t.TextColor3 = Color3.fromRGB(200,200,200) end
                e.t.Position = UDim2.fromOffset(sp.X + e.drift * a, sp.Y - 42 * ease)
                e.t.TextTransparency = a < 0.6 and 0 or (a - 0.6) / 0.4
                e.t.Visible = true
            end
        end
    end

    for i, t in ipairs(_killText) do
        local kf = _killFeed[i]
        if not kf or (now - kf.t0) >= 5 then
            t.Visible = false
        else
            local a = now - kf.t0
            local slide = math.clamp(a / 0.12, 0, 1)
            slide = 1 - (1 - slide) * (1 - slide)
            t.Text = kf.text
            t.TextColor3 = kf.crit and _GOLD or _WHITE
            t.Position = UDim2.new(1, -16 - 200 + (1 - slide) * 30, 0, 110 + (i - 1) * 18)
            t.TextTransparency = a < 4 and 0 or (a - 4)
            t.Visible = true
        end
    end
    for i = #_killFeed, 1, -1 do
        if (now - _killFeed[i].t0) >= 5 then table.remove(_killFeed, i) end
    end

    if _hf.on and _flashFrame then
        local a = (now - _hf.t0) / 0.16
        if a >= 1 then
            _hf.on = false; _flashFrame.Visible = false
        else
            _flashFrame.BackgroundTransparency = 0.78 + 0.22 * a
            _flashFrame.Visible = true
        end
    end
end

FX.start = function()
    if _started then return end
    _started = true
    ensureFxAllocated()
    RunService.RenderStepped:Connect(function()
        if _started then pcall(fxUpdate) end
    end)
end
FX.stop = function() _started = false end

Visuals.FX = FX
function Visuals.setStretch(v)
    Config.VisualsStretch = math.clamp(v, Config.VisualsStretchMin, Config.VisualsStretchMax)
end
function Visuals.enableHUD() Config.HUD = true; FX.start() end
function Visuals.disableHUD() Config.HUD = false; FX.stop() end

-- ============================================================
-- WEATHER (stub API — toggles set config flags)
-- ============================================================
local Weather = {}
Weather.TypeOrder = { "Rain", "Snow", "Mist", "Embers", "Fireflies", "Petals", "Autumn", "Ash", "Sandstorm", "BloodMoon" }
Weather.SkyboxOrder = { "Off", "Space", "Sunset", "Clouds", "Storm", "Winter", "Vaporwave" }

function Weather.setType(name) Config.WeatherType = name end
function Weather.setIntensity(v) Config.WeatherIntensity = math.clamp(v, 0.15, 2) end
function Weather.setSoundVolume(v) Config.WeatherSoundVolume = v end
function Weather.toggleStorm(on) Config.WeatherStorm = on end
function Weather.setStormMin(v) Config.WeatherStormMin = math.clamp(v, 1, 30) end
function Weather.setStormVar(v) Config.WeatherStormVar = math.clamp(v, 0, 30) end
function Weather.setMeteorRate(v) Config.WeatherMeteorRate = math.clamp(v, 0.25, 3) end
function Weather.setStarRate(v) Config.WeatherStarRate = math.clamp(v, 0.25, 3) end
function Weather.togglePuddles(on) Config.WeatherPuddles = on end
function Weather.toggleMood(on) Config.WeatherMood = on end
function Weather.toggleMeteors(on) Config.WeatherMeteors = on end
function Weather.toggleShootingStars(on) Config.WeatherShootingStars = on end
function Weather.toggleClock(on) Config.WeatherClockDial = on end
function Weather.setSkybox(name) Config.SkyboxPreset = name end
function Weather.toggleCelestial(hide) Config.SkyboxHideCelestial = hide end
function Weather.toggleGodRays(on) Config.WeatherGodRays = on end
function Weather.toggleRainbow(on) Config.WeatherRainbow = on end
function Weather.enableWeather() Config.Weather = true end
function Weather.disableWeather() Config.Weather = false end
function Weather.init() end
function Weather.unload() Weather.disableWeather() end

-- ============================================================
-- GAMEVISUALS (stub API — toggles set config flags)
-- ============================================================
local GameVisuals = { uiAlive = true }
GameVisuals.Choices = {}
GameVisuals.InventoryVisibility = {}
GameVisuals.WeaponVisibility = {}
GameVisuals.lastWeapon = nil

function GameVisuals.setWeapon(name) GameVisuals.lastWeapon = (name ~= "None") and name or nil end
function GameVisuals.setUnlockAll(on) Config.GVUnlockAll = (on == true) end
function GameVisuals.setUnlockWeapons(on) Config.GVUnlockWeapons = (on == true) end
function GameVisuals.syncEmotes(on) Config.GVEmotes = (on == true) end
function GameVisuals.setInventoryVisibility() end
function GameVisuals.setWeaponVisibility() end
function GameVisuals.setFor(weapon, kind, name, inverted)
    if type(weapon) ~= "string" or type(kind) ~= "string" then return end
    local slot = GameVisuals.Choices[weapon]
    if slot == nil then slot = {}; GameVisuals.Choices[weapon] = slot end
    slot[kind] = { Name = name, Inverted = inverted == true }
end
function GameVisuals.setSkin(name)
    local base = GameVisuals.lastWeapon
    if base then GameVisuals.setFor(base, "Skin", name) end
end
function GameVisuals.setCharm(name)
    local base = GameVisuals.lastWeapon
    if base then GameVisuals.setFor(base, "Charm", name) end
end
function GameVisuals.setWrap(name)
    local base = GameVisuals.lastWeapon
    if base then GameVisuals.setFor(base, "Wrap", name) end
end
function GameVisuals.setFinisher(name)
    local base = GameVisuals.lastWeapon
    if base then GameVisuals.setFor(base, "Finisher", name) end
end
function GameVisuals.setWrapInverted(on) Config.GVWrapInverted = (on == true) end
function GameVisuals.playEmote() end
function GameVisuals.emoteList() return { "None" } end
function GameVisuals.rankNames() return { "None" } end
function GameVisuals.rankedCharmsFor() return { "Held weapon" } end
function GameVisuals.applyRankedCharm() end
function GameVisuals.refreshRankCharmMeta() end
function GameVisuals.apply() return 0 end
function GameVisuals.restore() GameVisuals.Choices = {} end
function GameVisuals.enable() Config.GameVisuals = true end
function GameVisuals.disable() Config.GameVisuals = false end
function GameVisuals.ready() return false end
function GameVisuals.saveConfig() return false, "not implemented" end
function GameVisuals.loadConfig() return false, "not implemented" end
function GameVisuals.weaponList() return { "None" } end
function GameVisuals.skinList() return { "None" } end
function GameVisuals.charmList() return { "None" } end
function GameVisuals.wrapList() return { "None" } end
function GameVisuals.finisherList() return { "None" } end
function GameVisuals.summary() return {} end

-- ============================================================
-- UI — COSMETICS TAB
-- ============================================================
local GLeft = Tabs.Cosmetics:AddLeftGroupbox('GameVisuals')
GLeft:AddToggle('GameVisualsEnabled', {
    Text = 'Enable GameVisuals', Default = false,
    Callback = function(v)
        if v then GameVisuals.enable() else GameVisuals.disable() end
    end,
})
GLeft:AddToggle('GVUnlockAll', {
    Text = 'Show all cosmetics locally', Default = false,
    Callback = function(v) pcall(GameVisuals.setUnlockAll, v) end,
})
GLeft:AddToggle('GVRemember', {
    Text = 'Remember picks', Default = true,
    Callback = function(v) Config.GVRemember = v end,
})
GLeft:AddToggle('GVEmotes', {
    Text = 'Unlock emotes', Default = false,
    Callback = function(v) pcall(GameVisuals.syncEmotes, v) end,
})
GLeft:AddButton({ Text = 'Reset all', Func = function() pcall(GameVisuals.restore) end })
GLeft:AddDivider()
GLeft:AddToggle('GVRankCharmOn', {
    Text = 'Spoof ranked charm rank', Default = false,
    Callback = function(v) Config.GVRankCharmOn = v end,
})
GLeft:AddInput('GVRankCharmLb', {
    Text = '#N (optional)', Default = '0', Numeric = true, Finished = false,
    Callback = function(v) Config.GVRankCharmLb = tonumber(v) or 0 end,
})

local Manual = Tabs.Cosmetics:AddRightGroupbox('Manual skin / charm / wrap picker')
Manual:AddLabel('Enable GameVisuals, choose a weapon, then select its cosmetics.', true)
Manual:AddDropdown('GVWeapon', { Values = { 'None' }, Default = 'None', Multi = false, Text = 'Weapon',
    Callback = function(v) pcall(GameVisuals.setWeapon, v) end })
Manual:AddDropdown('GVSkin', { Values = { 'None' }, Default = 'None', Multi = false, Text = 'Skin',
    Callback = function(v) pcall(GameVisuals.setSkin, v) end })
Manual:AddDropdown('GVCharm', { Values = { 'None' }, Default = 'None', Multi = false, Text = 'Charm',
    Callback = function(v) pcall(GameVisuals.setCharm, v) end })
Manual:AddDropdown('GVWrap', { Values = { 'None' }, Default = 'None', Multi = false, Text = 'Wrap',
    Callback = function(v) pcall(GameVisuals.setWrap, v) end })
Manual:AddDropdown('GVFinisher', { Values = { 'None' }, Default = 'None', Multi = false, Text = 'Finisher',
    Callback = function(v) pcall(GameVisuals.setFinisher, v) end })
Manual:AddToggle('GVWrapInverted', { Text = 'Invert wrap', Default = false,
    Callback = function(v) pcall(GameVisuals.setWrapInverted, v) end })

task.spawn(function()
    while running do
        task.wait(3)
        pcall(function() Options.GVWeapon:SetValues(GameVisuals.weaponList()) end)
        pcall(function() Options.GVSkin:SetValues(GameVisuals.skinList()) end)
        pcall(function() Options.GVCharm:SetValues(GameVisuals.charmList()) end)
        pcall(function() Options.GVWrap:SetValues(GameVisuals.wrapList()) end)
        pcall(function() Options.GVFinisher:SetValues(GameVisuals.finisherList()) end)
    end
end)

-- ============================================================
-- UI — WEAPONS TAB
-- ============================================================
local VM = Tabs.Weapons:AddLeftGroupbox('Viewmodel & Chams')
VM:AddToggle('VMOffsetEnabled', { Text = '6-DOF transform', Default = false,
    Callback = function(v) Config.VMOffsetEnabled = v end })
VM:AddSlider('VMOffsetX', { Text = 'X', Default = 0, Min = -5, Max = 5, Rounding = 2, Compact = true,
    Callback = function(v) Config.VMOffsetX = v end })
VM:AddSlider('VMOffsetY', { Text = 'Y', Default = 0, Min = -5, Max = 5, Rounding = 2, Compact = true,
    Callback = function(v) Config.VMOffsetY = v end })
VM:AddSlider('VMOffsetZ', { Text = 'Z', Default = 0, Min = -5, Max = 5, Rounding = 2, Compact = true,
    Callback = function(v) Config.VMOffsetZ = v end })
VM:AddSlider('VMOffsetPitch', { Text = 'Pitch', Default = 0, Min = -180, Max = 180, Rounding = 0, Suffix = '°',
    Callback = function(v) Config.VMOffsetPitch = math.floor(v) end })
VM:AddSlider('VMOffsetYaw', { Text = 'Yaw', Default = 0, Min = -180, Max = 180, Rounding = 0, Suffix = '°',
    Callback = function(v) Config.VMOffsetYaw = math.floor(v) end })
VM:AddSlider('VMOffsetRoll', { Text = 'Roll', Default = 0, Min = -180, Max = 180, Rounding = 0, Suffix = '°',
    Callback = function(v) Config.VMOffsetRoll = math.floor(v) end })
VM:AddDivider()
VM:AddToggle('VMChamsEnabled', { Text = 'Material chams', Default = false,
    Callback = function(v) Config.VMChamsEnabled = v end })
VM:AddDropdown('VMChamsMaterial', { Values = { 'ForceField', 'Neon', 'Glass', 'SmoothPlastic' },
    Default = 'ForceField', Multi = false, Text = 'Material',
    Callback = function(v) Config.VMChamsMaterial = v end })
VM:AddSlider('VMChamsTransparency', { Text = 'Transparency', Default = 0.5, Min = 0, Max = 1, Rounding = 2,
    Callback = function(v) Config.VMChamsTransparency = v end })
VM:AddToggle('VMDisableTextures', { Text = 'Disable gun textures', Default = false,
    Callback = function(v) Config.VMDisableTextures = v end })

local SoundBox = Tabs.Weapons:AddRightGroupbox('Hit sounds')
local soundMap = {
    Bameware = '130791763', Bell = '146680539', Bubble = '146665237', Click = '146633140',
    Pop = '146681941', Rust = '146692956', Fart = '130791763', Big = '130792279',
    Vine = '146606035', Bruh = '146657737', Skeet = '130791733', Neverlose = '146633485',
    Fatality = '146665147', Bonk = '146661497', Minecraft = '146649495',
}
local soundNames = { 'None', 'Custom asset ID' }
for name in pairs(soundMap) do table.insert(soundNames, name) end
table.sort(soundNames)

local hit = { enabled = false, name = 'Bell', asset = '', volume = 0.5, pitch = 1 }
SoundBox:AddToggle('ExtraHitEnabled', { Text = 'Custom hit sound', Default = false,
    Callback = function(v) hit.enabled = v end })
SoundBox:AddDropdown('ExtraHitSound', { Values = soundNames, Default = 'Bell', Multi = false, Text = 'Sound',
    Callback = function(v) hit.name = v end })
SoundBox:AddInput('ExtraHitAsset', { Text = 'Custom asset ID', Default = '', Finished = false,
    Callback = function(v) hit.asset = tostring(v) end })
SoundBox:AddSlider('ExtraHitVolume', { Text = 'Volume', Default = 50, Min = 0, Max = 100, Rounding = 0, Suffix = '%',
    Callback = function(v) hit.volume = v / 100 end })
SoundBox:AddSlider('ExtraHitPitch', { Text = 'Pitch', Default = 1, Min = 0.1, Max = 10, Rounding = 1, Suffix = 'x',
    Callback = function(v) hit.pitch = v end })
SoundBox:AddButton({ Text = 'Preview sound', Func = function()
    local id = hit.name == 'Custom asset ID' and hit.asset:match('%d+') or soundMap[hit.name]
    if not id then notify('Choose a sound or enter an asset ID'); return end
    local s = Instance.new('Sound')
    s.SoundId = 'rbxassetid://' .. id
    s.Volume = hit.volume; s.PlaybackSpeed = hit.pitch
    s.Parent = SoundService
    task.spawn(function() pcall(function() s:Play() end); task.wait(3); s:Destroy() end)
end })

-- ============================================================
-- UI — INVENTORY TAB
-- ============================================================
local InvVis = Tabs.Inventory:AddLeftGroupbox('Local catalog visibility')
InvVis:AddLabel('These controls change the local catalog, not account ownership.', true)
local state = { kind = 'Skin', rarity = 'Common', name = '', weapon = '', inverted = false }
InvVis:AddDropdown('ExtraCosmeticType', { Values = { 'Skin', 'Wrap', 'Charm', 'Finisher' },
    Default = 'Skin', Multi = false, Text = 'Type',
    Callback = function(v) state.kind = v end })
InvVis:AddDropdown('ExtraCosmeticRarity', { Values = { 'Common', 'Rare', 'Legendary', 'Mythical', 'Unique', 'Unobtainable' },
    Default = 'Common', Multi = false, Text = 'Rarity',
    Callback = function(v) state.rarity = v end })
InvVis:AddInput('ExtraCosmeticName', { Text = 'Cosmetic name', Default = '', Finished = false,
    Callback = function(v) state.name = v end })
InvVis:AddInput('ExtraCosmeticWeapon', { Text = 'Weapon name', Default = '', Finished = false,
    Callback = function(v) state.weapon = v end })
InvVis:AddButton({ Text = 'Show all cosmetics', Func = function()
    GameVisuals.setInventoryVisibility(nil, true); notify('all shown')
end })
InvVis:AddButton({ Text = 'Reset catalog overrides', Func = function()
    GameVisuals.setInventoryVisibility(nil, nil); notify('reset')
end })

local EquipBox = Tabs.Inventory:AddRightGroupbox('Apply cosmetic')
EquipBox:AddLabel('Uses the type, name and weapon fields on the left.', true)
EquipBox:AddToggle('ExtraEquipInverted', { Text = 'Invert wrap', Default = false,
    Callback = function(v) state.inverted = v end })
EquipBox:AddButton({ Text = 'Apply to selected / held weapon', Func = function()
    local weapon = state.weapon
    if weapon == '' then local held = getEquippedItem(); weapon = held and held.Name end
    if not weapon or weapon == '' then notify('Enter a weapon or equip one'); return end
    GameVisuals.setFor(weapon, state.kind, state.name, state.inverted)
    notify('Applied to ' .. weapon)
end })
EquipBox:AddButton({ Text = 'Show all weapons locally', Func = function()
    GameVisuals.setUnlockWeapons(true)
end })
EquipBox:AddButton({ Text = 'Restore weapon catalog', Func = function()
    GameVisuals.setUnlockWeapons(false)
    GameVisuals.setWeaponVisibility(nil, nil)
end })

-- ============================================================
-- UI — WORLD TAB
-- ============================================================
local WorldLeft = Tabs.World:AddLeftGroupbox('Lighting')
WorldLeft:AddToggle('Visuals', { Text = 'Enable', Default = false,
    Callback = function(v) if v then Visuals.enable() else Visuals.disable() end end })
WorldLeft:AddDropdown('VisualsPreset', { Values = Visuals.PresetOrder, Default = 'Neutral',
    Multi = false, Text = 'Preset',
    Callback = function(v) Visuals.setPreset(v) end })
WorldLeft:AddDropdown('VisualsGrade', { Values = { 'None', 'Crisp', 'Cold', 'Warm', 'Comp' },
    Default = 'Crisp', Multi = false, Text = 'Color grade',
    Callback = function(v) Config.VisualsGrade = v end })
WorldLeft:AddSlider('VisualsGradeStrength', { Text = 'Grade strength', Default = 0.6, Min = 0, Max = 1, Rounding = 2,
    Callback = function(v) Config.VisualsGradeStrength = v end })
WorldLeft:AddToggle('VisualsBloom', { Text = 'Bloom', Default = false,
    Callback = function(v) Config.VisualsBloom = v end })
WorldLeft:AddSlider('VisualsBloomIntensity', { Text = 'Bloom intensity', Default = 1.0, Min = 0, Max = 3, Rounding = 2,
    Callback = function(v) Config.VisualsBloomIntensity = v end })
WorldLeft:AddDivider()
WorldLeft:AddToggle('VisualsFullbright', { Text = 'Fullbright', Default = false,
    Callback = function(v) Visuals.toggleFullbright(v) end })
WorldLeft:AddToggle('VisualsNoFog', { Text = 'No fog', Default = false,
    Callback = function(v) Visuals.toggleNoFog(v) end })
WorldLeft:AddToggle('VisualsRainbowMap', { Text = 'Rainbow world', Default = false,
    Callback = function(v) Config.VisualsRainbowMap = v end })
WorldLeft:AddToggle('VisualsPerformanceMode', { Text = 'Performance mode', Default = false,
    Callback = function(v) Visuals.togglePerf(v) end })

local WorldRight = Tabs.World:AddRightGroupbox('Weather')
WorldRight:AddToggle('Weather', { Text = 'Enable', Default = false,
    Callback = function(v) if v then Weather.enableWeather() else Weather.disableWeather() end end })
WorldRight:AddDropdown('WeatherType', { Values = Weather.TypeOrder, Default = 'Rain',
    Multi = false, Text = 'Precipitation',
    Callback = function(v) Weather.setType(v) end })
WorldRight:AddSlider('WeatherIntensity', { Text = 'Intensity', Default = 1.0, Min = 0.15, Max = 2, Rounding = 2,
    Callback = function(v) Weather.setIntensity(v) end })
WorldRight:AddSlider('WeatherSoundVolume', { Text = 'Volume', Default = 0.35, Min = 0, Max = 1, Rounding = 2,
    Callback = function(v) Weather.setSoundVolume(v) end })
WorldRight:AddToggle('WeatherMood', { Text = 'Mood tint', Default = true,
    Callback = function(v) Weather.toggleMood(v) end })
WorldRight:AddToggle('WeatherStorm', { Text = 'Storm & lightning', Default = false,
    Callback = function(v) Weather.toggleStorm(v) end })
WorldRight:AddToggle('WeatherStormFlash', { Text = 'Sky flash', Default = true,
    Callback = function(v) Config.WeatherStormFlash = v end })
WorldRight:AddToggle('WeatherMeteors', { Text = 'Meteors', Default = false,
    Callback = function(v) Weather.toggleMeteors(v) end })
WorldRight:AddToggle('WeatherShootingStars', { Text = 'Shooting stars', Default = false,
    Callback = function(v) Weather.toggleShootingStars(v) end })
WorldRight:AddToggle('SkyboxHideCelestial', { Text = 'Hide celestial', Default = false,
    Callback = function(v) Weather.toggleCelestial(v) end })
WorldRight:AddToggle('WeatherGodRays', { Text = 'God rays', Default = false,
    Callback = function(v) Weather.toggleGodRays(v) end })
WorldRight:AddToggle('WeatherRainbow', { Text = 'Rainbow', Default = false,
    Callback = function(v) Weather.toggleRainbow(v) end })
WorldRight:AddToggle('WeatherPuddles', { Text = 'Puddles', Default = false,
    Callback = function(v) Weather.togglePuddles(v) end })
WorldRight:AddToggle('WeatherClockDial', { Text = 'Clock dial', Default = false,
    Callback = function(v) Weather.toggleClock(v) end })

local FXBox = Tabs.World:AddLeftGroupbox('Effects')
FXBox:AddToggle('VisualsHolograms', { Text = 'On-hit holograms', Default = false,
    Callback = function(v) Config.VisualsHolograms = v end })
FXBox:AddSlider('VisualsHologramDuration', { Text = 'Duration', Default = 3.5, Min = 0.5, Max = 5, Rounding = 1,
    Callback = function(v) Config.VisualsHologramDuration = v end })
FXBox:AddSlider('VisualsHologramRange', { Text = 'Max range', Default = 300, Min = 20, Max = 300, Rounding = 0,
    Callback = function(v) Config.VisualsHologramRange = math.floor(v) end })
FXBox:AddToggle('VisualsHologramLethal', { Text = 'Gold kill aura', Default = true,
    Callback = function(v) Config.VisualsHologramLethal = v end })
FXBox:AddButton({ Text = 'Preview on your character', Func = function()
    Visuals.previewHologram(LP.Character)
end })

local CamBox = Tabs.World:AddRightGroupbox('Camera')
CamBox:AddToggle('CameraFovOverride', { Text = 'FOV override', Default = false,
    Callback = function(v) Config.CameraFovOverride = v end })
CamBox:AddSlider('CameraFovAmount', { Text = 'Field of view', Default = 90, Min = 40, Max = 130, Rounding = 0,
    Callback = function(v) Config.CameraFovAmount = math.floor(v) end })
CamBox:AddToggle('CameraAspectRatioEnabled', { Text = 'Aspect ratio stretch', Default = false,
    Callback = function(v) Config.CameraAspectRatioEnabled = v end })
CamBox:AddSlider('CameraAspectRatioX', { Text = 'Width', Default = 4, Min = 1, Max = 21, Rounding = 0,
    Callback = function(v) Config.CameraAspectRatioX = math.floor(v) end })
CamBox:AddSlider('CameraAspectRatioY', { Text = 'Height', Default = 3, Min = 1, Max = 21, Rounding = 0,
    Callback = function(v) Config.CameraAspectRatioY = math.floor(v) end })
CamBox:AddToggle('ThirdPersonEnabled', { Text = 'Third person', Default = false,
    Callback = function(v) Config.ThirdPersonEnabled = v end })
CamBox:AddSlider('ThirdPersonDistance', { Text = 'Distance', Default = 12, Min = 4, Max = 30, Rounding = 0,
    Callback = function(v) Config.ThirdPersonDistance = math.floor(v) end })
CamBox:AddToggle('VisualsVignette', { Text = 'Vignette', Default = false,
    Callback = function(v) Config.VisualsVignette = v end })
CamBox:AddSlider('VisualsVignetteStrength', { Text = 'Vignette strength', Default = 0.6, Min = 0, Max = 1, Rounding = 2,
    Callback = function(v) Config.VisualsVignetteStrength = v end })
CamBox:AddToggle('VisualsLetterbox', { Text = 'Letterbox', Default = false,
    Callback = function(v) Config.VisualsLetterbox = v end })
CamBox:AddSlider('VisualsLetterboxSize', { Text = 'Letterbox size', Default = 0.10, Min = 0.04, Max = 0.18, Rounding = 2,
    Callback = function(v) Config.VisualsLetterboxSize = v end })
CamBox:AddToggle('VisualsCameraSway', { Text = 'Camera sway', Default = false,
    Callback = function(v) Config.VisualsCameraSway = v end })
CamBox:AddSlider('VisualsCameraSwayAmount', { Text = 'Sway amount', Default = 0.5, Min = 0, Max = 1, Rounding = 2,
    Callback = function(v) Config.VisualsCameraSwayAmount = v end })

-- ============================================================
-- UI — SPOOFER TAB
-- ============================================================
local SpoofLeft = Tabs.Spoofer:AddLeftGroupbox('Name & Identity')
SpoofLeft:AddToggle('SpooferNameEnabled', { Text = 'Spoof name', Default = false,
    Callback = function(v) Config.SpooferNameEnabled = v end })
SpoofLeft:AddInput('SpooferName', { Text = 'Username', Default = 'ProPlayer', Finished = false,
    Callback = function(v) Config.SpooferName = v end })
SpoofLeft:AddInput('SpooferDisplayName', { Text = 'Display name', Default = 'ProPlayer', Finished = false,
    Callback = function(v) Config.SpooferDisplayName = v end })
SpoofLeft:AddDivider('Ranked & Stats')
SpoofLeft:AddToggle('SpooferLevelEnabled', { Text = 'Spoof level', Default = false,
    Callback = function(v) Config.SpooferLevelEnabled = v end })
SpoofLeft:AddInput('SpooferLevel', { Text = 'Level', Default = '100', Numeric = true, Finished = false,
    Callback = function(v) Config.SpooferLevel = tonumber(v) or 100 end })
SpoofLeft:AddToggle('SpooferRankedEloEnabled', { Text = 'Spoof ELO', Default = false,
    Callback = function(v) Config.SpooferRankedEloEnabled = v end })
SpoofLeft:AddInput('SpooferRankedElo', { Text = 'ELO rating', Default = '2400', Numeric = true, Finished = false,
    Callback = function(v) Config.SpooferRankedElo = tonumber(v) or 2400 end })
SpoofLeft:AddToggle('SpooferCasualWinsEnabled', { Text = 'Spoof casual wins', Default = false,
    Callback = function(v) Config.SpooferCasualWinsEnabled = v end })
SpoofLeft:AddInput('SpooferCasualWins', { Text = 'Casual wins', Default = '500', Numeric = true, Finished = false,
    Callback = function(v) Config.SpooferCasualWins = tonumber(v) or 500 end })
SpoofLeft:AddToggle('SpooferRankedWinsEnabled', { Text = 'Spoof ranked wins', Default = false,
    Callback = function(v) Config.SpooferRankedWinsEnabled = v end })
SpoofLeft:AddInput('SpooferRankedWins', { Text = 'Ranked wins', Default = '250', Numeric = true, Finished = false,
    Callback = function(v) Config.SpooferRankedWins = tonumber(v) or 250 end })
SpoofLeft:AddToggle('SpooferWinPercentEnabled', { Text = 'Spoof winrate', Default = false,
    Callback = function(v) Config.SpooferWinPercentEnabled = v end })
SpoofLeft:AddInput('SpooferWinPercent', { Text = 'Winrate %', Default = '75', Numeric = true, Finished = false,
    Callback = function(v) Config.SpooferWinPercent = tonumber(v) or 75 end })
SpoofLeft:AddToggle('SpooferWinStreakEnabled', { Text = 'Spoof win streak', Default = false,
    Callback = function(v) Config.SpooferWinStreakEnabled = v end })
SpoofLeft:AddInput('SpooferWinStreak', { Text = 'Win streak', Default = '25', Numeric = true, Finished = false,
    Callback = function(v) Config.SpooferWinStreak = tonumber(v) or 25 end })
SpoofLeft:AddToggle('SpooferFavoriteMapEnabled', { Text = 'Spoof favorite map', Default = false,
    Callback = function(v) Config.SpooferFavoriteMapEnabled = v end })
SpoofLeft:AddInput('SpooferFavoriteMap', { Text = 'Map name', Default = 'Arena', Finished = false,
    Callback = function(v) Config.SpooferFavoriteMap = v end })

-- ============================================================
-- UI — MISC TAB
-- ============================================================
local MiscCfg = {
    anonymous = false, display = false, username = false,
    displayName = LP.DisplayName, userName = LP.Name,
}
local NamesBox = Tabs.Misc:AddLeftGroupbox('Names and thumbnails')
local tracked = setmetatable({}, { __mode = 'k' })
local function replacePlain(text, old, new)
    if old == '' then return text end
    local pattern = old:gsub('([^%w])', '%%%1')
    return (text:gsub(pattern, function() return new end))
end
local function desiredText(original)
    local text = original
    if MiscCfg.anonymous then
        for _, player in ipairs(Players:GetPlayers()) do
            local fake = 'Player' .. tostring(player.UserId % 100000)
            text = replacePlain(text, player.DisplayName, fake)
            text = replacePlain(text, player.Name, fake)
        end
    else
        if MiscCfg.display then text = replacePlain(text, LP.DisplayName, MiscCfg.displayName) end
        if MiscCfg.username then text = replacePlain(text, LP.Name, MiscCfg.userName) end
    end
    return text
end
local function registerText(obj)
    if tracked[obj] or not (obj:IsA('TextLabel') or obj:IsA('TextButton')) then return end
    tracked[obj] = { original = obj.Text }
    connect(obj:GetPropertyChangedSignal('Text'), function()
        tracked[obj].original = obj.Text
        pcall(function() obj.Text = desiredText(obj.Text) end)
    end)
    pcall(function() obj.Text = desiredText(obj.Text) end)
end
local function scanText()
    local gui = LP:FindFirstChildOfClass('PlayerGui')
    if gui then
        for _, obj in ipairs(gui:GetDescendants()) do registerText(obj) end
        connect(gui.DescendantAdded, registerText)
    end
end
NamesBox:AddInput('ExtraDisplayName', { Text = 'Display name', Default = LP.DisplayName, Finished = false,
    Callback = function(v) MiscCfg.displayName = v; scanText() end })
NamesBox:AddToggle('ExtraDisplayNameEnabled', { Text = 'Override display name', Default = false,
    Callback = function(v) MiscCfg.display = v; scanText() end })
NamesBox:AddInput('ExtraUsername', { Text = 'Username', Default = LP.Name, Finished = false,
    Callback = function(v) MiscCfg.userName = v; scanText() end })
NamesBox:AddToggle('ExtraUsernameEnabled', { Text = 'Override username', Default = false,
    Callback = function(v) MiscCfg.username = v; scanText() end })
NamesBox:AddToggle('ExtraAnonymous', { Text = 'Anonymous names', Default = false,
    Callback = function(v) MiscCfg.anonymous = v; scanText() end })

-- ============================================================
-- UI — UI SETTINGS
-- ============================================================
local UISGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')
UISGroup:AddButton('Unload', function()
    if BurgadaSpooferUnload then BurgadaSpooferUnload() end
    Library:Unload()
end)
UISGroup:AddKeyPicker('MenuKeybind', {
    Default = 'RightShift', Mode = 'Toggle', Text = 'Open / close menu', NoUI = true,
})
Library.ToggleKeybind = Options.MenuKeybind

if ThemeManager and ThemeManager.SetLibrary then
    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder('BurgadaLua/spoofer')
    ThemeManager:ApplyToTab(Tabs['UI Settings'])
end
if SaveManager and SaveManager.SetLibrary then
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetFolder('BurgadaLua/spoofer-config')
    SaveManager:BuildConfigSection(Tabs['UI Settings'])
end

-- ============================================================
-- MAIN LOOP + UNLOAD
-- ============================================================
SpooferConn = RunService.Heartbeat:Connect(function()
    if not running then return end
    resolveRivals()
end)

function BurgadaSpooferUnload()
    running = false
    if SpooferConn then SpooferConn:Disconnect() end
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    GameVisuals.uiAlive = false
    pcall(Weather.unload)
    pcall(Visuals.unload)
    pcall(GameVisuals.disable)
    for i = #restorers, 1, -1 do pcall(restorers[i]) end
    env.__BurgadaSpoofer = nil
end
env.__BurgadaSpoofer = function()
    if BurgadaSpooferUnload then BurgadaSpooferUnload() end
    pcall(function() Library:Unload() end)
end

if SaveManager and SaveManager.LoadAutoloadConfig then
    pcall(function() SaveManager:LoadAutoloadConfig() end)
end

task.spawn(function()
    pcall(function() Visuals.init() end)
    pcall(function() Weather.init() end)
end)

Library:Notify('Burgada Spoofer v1 loaded — Linoria build')