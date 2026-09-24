-- language: Lua (Roblox Luau), file: burgada_stabbed.lua
-- executor: Delta Android (also PC)
-- paste after attaching. standalone.

-- ============================================================
-- PRE-FLIGHT CLEANUP
-- ============================================================
pcall(function()
    if StabbedConn then StabbedConn:Disconnect() end
    if StabbedCam then StabbedCam:Disconnect() end
    if BurgadaStabbedUnload then pcall(BurgadaStabbedUnload) end
end)
pcall(function()
    local cg = game:GetService('CoreGui')
    local g = cg:FindFirstChild('LinoriaLib')
    if g then g:Destroy() end
end)
pcall(function()
    local pg = game.Players.LocalPlayer:FindFirstChild('PlayerGui')
    if pg then
        local g = pg:FindFirstChild('LinoriaLib')
        if g then g:Destroy() end
    end
end)

-- ============================================================
-- LIBRARY BOOT
-- ============================================================
local urls = {
    'https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/Library.lua',
    'https://raw.githubusercontent.com/mstudio45/LinoriaLib/refs/heads/main/Library.lua',
    'https://cdn.jsdelivr.net/gh/mstudio45/LinoriaLib@main/Library.lua',
    'https://gitcdn.link/repo/mstudio45/LinoriaLib/main/Library.lua',
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
    if libSrc then
        warn('[Burgada] success from', u, '#', #libSrc)
        break
    end
    warn('[Burgada] failed:', u)
end

if not libSrc then
    warn('[Burgada] ALL URLS FAILED')
    return
end

local Library = loadstring(libSrc)()
if not Library then
    warn('[Burgada] Library nil')
    return
end

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

-- ============================================================
-- SERVICES
-- ============================================================
local Players    = game:GetService('Players')
local RunService = game:GetService('RunService')
local LP         = Players.LocalPlayer

-- ============================================================
-- STATE
-- ============================================================
local St = {
    rage = {
        active        = false,
        mode          = 'Sequential',
        cycleInterval = 0.0001,
        lastCycle     = 0,
        targetIndex   = 1,
        cameraLock    = true,
        freeze        = true,
        offsetBehind  = 3,
        offsetUp      = 1,
    },
}

-- ============================================================
-- HELPERS
-- ============================================================
local function alive()
    local c = LP.Character
    if not c then return false, nil, nil, nil end
    local h = c:FindFirstChildOfClass('Humanoid')
    local r = c:FindFirstChild('HumanoidRootPart')
    if h and r and h.Health > 0 then return true, c, h, r end
    return false, c, h, r
end

local function getTargets()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hrp = p.Character:FindFirstChild('HumanoidRootPart')
            local hum = p.Character:FindFirstChildOfClass('Humanoid')
            if hrp and hum and hum.Health > 0 then
                table.insert(list, { player = p, hrp = hrp, hum = hum })
            end
        end
    end
    return list
end

local function teleportToBack(target)
    local _, _, _, myRoot = alive()
    if not myRoot or not target or not target.hrp then return end
    local targetPos = target.hrp.Position
    local lookVec = target.hrp.CFrame.LookVector
    local backPos = targetPos - lookVec * St.rage.offsetBehind + Vector3.new(0, St.rage.offsetUp, 0)
    myRoot.CFrame = CFrame.new(backPos, targetPos)
end

-- ============================================================
-- RAGE TICK
-- ============================================================
local function rageTick()
    if not St.rage.active then return end
    local ok, _, _, myRoot = alive()
    if not ok or not myRoot then return end

    if St.rage.freeze then
        myRoot.AssemblyLinearVelocity  = Vector3.new(0, 0, 0)
        myRoot.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end

    local now = os.clock()
    if now - St.rage.lastCycle < St.rage.cycleInterval then return end
    St.rage.lastCycle = now

    local targets = getTargets()
    if #targets == 0 then return end

    local target
    if St.rage.mode == 'Nearest' then
        local bestD = math.huge
        for _, t in ipairs(targets) do
            local d = (myRoot.Position - t.hrp.Position).Magnitude
            if d < bestD then bestD, target = d, t end
        end
    elseif St.rage.mode == 'Random' then
        target = targets[math.random(1, #targets)]
    else
        St.rage.targetIndex = St.rage.targetIndex + 1
        if St.rage.targetIndex > #targets then St.rage.targetIndex = 1 end
        target = targets[St.rage.targetIndex]
    end

    if target then
        teleportToBack(target)
        if St.rage.cameraLock then
            local cam = workspace.CurrentCamera
            if cam then
                cam.CFrame = CFrame.new(cam.CFrame.Position, target.hrp.Position)
            end
        end
    end
end

-- ============================================================
-- WINDOW
-- ============================================================
local Window = Library:CreateWindow({
    Title                = 'Burgada Lua | Stabbed',
    Center               = true,
    AutoShow             = true,
    Resizable            = true,
    ShowCustomCursor     = false,
    UnlockMouseWhileOpen = false,
    NotifySide           = 'Left',
    TabPadding           = 8,
    MenuFadeTime         = 0.2,
})

local Tabs = {
    Rage            = Window:AddTab('Rage'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- ============================================================
-- RAGE UI
-- ============================================================
local RgBox = Tabs.Rage:AddLeftGroupbox('Rage — Backstab Loop')
RgBox:AddToggle('StabRageToggle', {
    Text = 'Enable Rage (cycle every player back)',
    Default = false,
    Callback = function(v)
        St.rage.active = v
        if not v then St.rage.targetIndex = 1 end
    end,
})
RgBox:AddDropdown('StabRageMode', {
    Values = { 'Sequential', 'Nearest', 'Random' },
    Default = 'Sequential',
    Multi = false,
    Text = 'Cycle Mode',
    Callback = function(v) St.rage.mode = v end,
})
RgBox:AddSlider('StabRageInterval', {
    Text = 'Cycle Interval (s)',
    Default = 0.0001,
    Min = 0.00001,
    Max = 0.05,
    Rounding = 5,
    Callback = function(v) St.rage.cycleInterval = v end,
})
RgBox:AddSlider('StabRageBehind', {
    Text = 'Offset Behind Target (studs)',
    Default = 3,
    Min = 1,
    Max = 10,
    Rounding = 1,
    Callback = function(v) St.rage.offsetBehind = v end,
})
RgBox:AddSlider('StabRageUp', {
    Text = 'Offset Above Target (studs)',
    Default = 1,
    Min = 0,
    Max = 8,
    Rounding = 1,
    Callback = function(v) St.rage.offsetUp = v end,
})
RgBox:AddToggle('StabRageCam', {
    Text = 'Camera Snap to Target',
    Default = true,
    Callback = function(v) St.rage.cameraLock = v end,
})
RgBox:AddToggle('StabRageFreeze', {
    Text = 'Zero Velocity Each Frame',
    Default = true,
    Callback = function(v) St.rage.freeze = v end,
})

local InfoBox = Tabs.Rage:AddRightGroupbox('Info')
InfoBox:AddLabel('Cycle teleports you to the back of each player.')
InfoBox:AddLabel('Sequential: walks the player list.')
InfoBox:AddLabel('Nearest: locks the closest.')
InfoBox:AddLabel('Random: jumps anywhere.')
InfoBox:AddLabel('')
InfoBox:AddLabel('Interval 0.0001s = every frame.')
InfoBox:AddLabel('Frames are the floor — nothing beats 60Hz.')

-- ============================================================
-- UI SETTINGS
-- ============================================================
local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')
MenuGroup:AddButton('Unload', function()
    if BurgadaStabbedUnload then BurgadaStabbedUnload() end
    Library:Unload()
end)

if ThemeManager and ThemeManager.SetLibrary then
    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder('BurgadaLua')
    ThemeManager:ApplyToTab(Tabs['UI Settings'])
end
if SaveManager and SaveManager.SetLibrary then
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetFolder('BurgadaLua/stabbed-config')
    SaveManager:BuildConfigSection(Tabs['UI Settings'])
end

-- ============================================================
-- CONNECTIONS
-- ============================================================
StabbedConn = RunService.Heartbeat:Connect(rageTick)

-- ============================================================
-- UNLOAD
-- ============================================================
function BurgadaStabbedUnload()
    St.rage.active = false
    if StabbedConn then StabbedConn:Disconnect() end
end

-- ============================================================
-- CONFIG
-- ============================================================
if SaveManager and SaveManager.LoadAutoloadConfig then
    local ok = pcall(function() SaveManager:LoadAutoloadConfig() end)
    if not ok then Library:Notify('Config load failed') end
end

Library:Notify('Burgada Lua | Stabbed loaded')
