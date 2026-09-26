-- language: Lua (Roblox Luau), file: Stabbed.lua
-- executor: Delta Android (also PC)
-- standalone

-- ============================================================
-- PRE-FLIGHT
-- ============================================================
pcall(function()
    if StabbedConn then StabbedConn:Disconnect() end
    if StabbedVoid then StabbedVoid:Disconnect() end
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

Library.ShowToggleFrameInKeybinds = true
Library.ShowCustomCursor          = false
Library.NotifySide                = 'Left'

-- ============================================================
-- SERVICES
-- ============================================================
local Players    = game:GetService('Players')
local RunService = game:GetService('RunService')
local VIM        = game:GetService('VirtualInputManager')
local LP         = Players.LocalPlayer

-- ============================================================
-- STATE
-- ============================================================
local St = {
    rage = {
        active       = false,
        sticky       = false,
        stickyTarget = nil,
        mode         = 'Sequential',
        targetIndex  = 1,

        voidInterval = 0.1,     -- how often to re-yank into void
        voidDuration = 0.5,     -- how long to spam void before look+click
        voidY        = 99999,   -- void Y coordinate
        voidRand     = 50000,   -- random X/Z spread in void

        -- cycle phases: Void -> Look -> Click -> repeat
        phase        = 'Idle',
        phaseT0      = 0,
        lastVoid     = 0,
        lockedTarget = nil,
    },
    hitbox = {
        active  = false,
        scale   = 20,           -- 20x default
        applied = {},           -- [part] = original size
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

local function isValidEntry(e)
    if not e then return false end
    if not e.player or not e.hrp or not e.hum or not e.head then return false end
    if not e.hrp.Parent or not e.hum.Parent or not e.head.Parent then return false end
    if e.hum.Health <= 0 then return false end
    return true
end

local function listTargets()
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hrp = p.Character:FindFirstChild('HumanoidRootPart')
            local hum = p.Character:FindFirstChildOfClass('Humanoid')
            local head = p.Character:FindFirstChild('Head')
            if hrp and hum and head and hum.Health > 0 then
                table.insert(out, { player = p, hrp = hrp, hum = hum, head = head, char = p.Character })
            end
        end
    end
    return out
end

local function nearestTarget()
    local ok, _, _, myRoot = alive()
    if not ok or not myRoot then return nil end
    local best, bestD = nil, math.huge
    for _, e in ipairs(listTargets()) do
        local d = (myRoot.Position - e.hrp.Position).Magnitude
        if d < bestD then bestD, best = d, e end
    end
    return best
end

local function pickTarget()
    local r = St.rage
    if r.sticky then
        if isValidEntry(r.stickyTarget) then return r.stickyTarget end
        r.stickyTarget = nearestTarget()
        return r.stickyTarget
    end
    if r.mode == 'Nearest' then
        return nearestTarget()
    end
    -- sequential
    local list = listTargets()
    if #list == 0 then return nil end
    r.targetIndex = r.targetIndex + 1
    if r.targetIndex > #list then r.targetIndex = 1 end
    return list[r.targetIndex]
end

-- ============================================================
-- VOID SPAM
-- ============================================================
local function yankToVoid()
    local ok, _, _, myRoot = alive()
    if not ok or not myRoot then return end
    local spread = St.rage.voidRand
    local pos = Vector3.new(
        math.random(-spread, spread),
        St.rage.voidY,
        math.random(-spread, spread)
    )
    myRoot.Anchored = true
    myRoot.CFrame = CFrame.new(pos)
    myRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
end

local function releaseVoid()
    local ok, _, _, myRoot = alive()
    if not ok or not myRoot then return end
    myRoot.Anchored = false
    myRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
end

-- ============================================================
-- LOOK AT TARGET (body + camera)
-- ============================================================
local function lookAtTarget(t)
    if not t or not isValidEntry(t) then return end
    local ok, _, _, myRoot = alive()
    if not ok or not myRoot then return end
    local aim = t.head.Position

    -- body: point root's LookVector at their head
    myRoot.CFrame = CFrame.new(myRoot.Position, aim)

    -- camera: point camera's LookVector at their head, keeping camera position
    local cam = workspace.CurrentCamera
    if cam then
        cam.CFrame = CFrame.new(cam.CFrame.Position, aim)
    end
end

-- ============================================================
-- RIGHT CLICK
-- ============================================================
local function fireRightClick()
    pcall(function()
        VIM:SendMouseButtonEvent(0, 0, 1, true,  game, 0)   -- button 1 = right
        task.wait()
        VIM:SendMouseButtonEvent(0, 0, 1, false, game, 0)
    end)
    pcall(function() mouse2click() end)
    pcall(function() mouse2down(); mouse2up() end)
end

-- ============================================================
-- HITBOX EXPAND — 20x head
-- ============================================================
local function applyHitbox()
    local scale = St.hitbox.scale
    for _, e in ipairs(listTargets()) do
        local head = e.head
        if head and not St.hitbox.applied[head] then
            St.hitbox.applied[head] = head.Size
        end
        if head then
            local base = St.hitbox.applied[head] or head.Size
            head.Size = Vector3.new(base.X * scale, base.Y * scale, base.Z * scale)
        end
    end
    -- prune dead references
    for part in pairs(St.hitbox.applied) do
        if not part.Parent then St.hitbox.applied[part] = nil end
    end
end

local function restoreHitbox()
    for part, orig in pairs(St.hitbox.applied) do
        pcall(function() part.Size = orig end)
    end
    St.hitbox.applied = {}
end

-- ============================================================
-- RAGE TICK — void -> look -> click -> repeat
-- ============================================================
local function rageTick()
    local r = St.rage
    if not r.active then
        if r.phase ~= 'Idle' then
            releaseVoid()
            r.phase = 'Idle'
        end
        return
    end

    local ok = alive()
    if not ok then return end
    local now = os.clock()

    -- pick target at start of each cycle
    if r.phase == 'Idle' then
        local t = pickTarget()
        if not t then return end
        r.lockedTarget = t
        r.phase = 'Void'
        r.phaseT0 = now
        r.lastVoid = 0
    end

    -- target validity mid-cycle
    if not isValidEntry(r.lockedTarget) then
        r.phase = 'Idle'
        releaseVoid()
        return
    end

    -- ---------------- Void phase ----------------
    if r.phase == 'Void' then
        if now - r.lastVoid >= r.voidInterval then
            r.lastVoid = now
            yankToVoid()
        end
        if now - r.phaseT0 >= r.voidDuration then
            r.phase = 'Look'
            r.phaseT0 = now
        end
        return
    end

    -- ---------------- Look phase ----------------
    if r.phase == 'Look' then
        releaseVoid()
        lookAtTarget(r.lockedTarget)
        r.phase = 'Click'
        r.phaseT0 = now
        return
    end

    -- ---------------- Click phase ----------------
    if r.phase == 'Click' then
        lookAtTarget(r.lockedTarget)
        fireRightClick()
        r.phase = 'Idle'   -- loop restarts
        return
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
    Backstab        = Window:AddTab('Backstab'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- ============================================================
-- RAGE UI
-- ============================================================
local RgBox = Tabs.Rage:AddLeftGroupbox('Rage — Void Cycle')
RgBox:AddToggle('StabRageToggle', {
    Text = 'Enable Rage (void spam -> look -> click)', Default = false,
    Callback = function(v)
        St.rage.active = v
        if not v then
            St.rage.phase = 'Idle'
            St.rage.stickyTarget = nil
            releaseVoid()
        end
    end,
})
RgBox:AddToggle('StabRageSticky', {
    Text = 'Sticky Target', Default = false,
    Callback = function(v)
        St.rage.sticky = v
        St.rage.stickyTarget = nil
    end,
})
RgBox:AddDropdown('StabRageMode', {
    Values = { 'Nearest', 'Sequential' },
    Default = 'Sequential',
    Multi = false,
    Text = 'Cycle Mode',
    Callback = function(v) St.rage.mode = v end,
})
RgBox:AddSlider('StabVoidInterval', {
    Text = 'Void Re-Yank Interval (s)', Default = 0.1, Min = 0.02, Max = 0.5, Rounding = 2,
    Callback = function(v) St.rage.voidInterval = v end,
})
RgBox:AddSlider('StabVoidDuration', {
    Text = 'Void Phase Duration (s)', Default = 0.5, Min = 0.1, Max = 2, Rounding = 2,
    Callback = function(v) St.rage.voidDuration = v end,
})
RgBox:AddSlider('StabVoidY', {
    Text = 'Void Y Coordinate', Default = 99999, Min = 10000, Max = 500000, Rounding = 0,
    Callback = function(v) St.rage.voidY = v end,
})
RgBox:AddSlider('StabVoidRand', {
    Text = 'Void Random Spread (studs)', Default = 50000, Min = 1000, Max = 200000, Rounding = 0,
    Callback = function(v) St.rage.voidRand = v end,
})

local InfoBox = Tabs.Rage:AddRightGroupbox('Cycle')
InfoBox:AddLabel('1. Spam void every 0.1s for 0.5s.')
InfoBox:AddLabel('2. Look at target head — body AND camera.')
InfoBox:AddLabel('3. Right click once.')
InfoBox:AddLabel('4. Repeat from step 1.')

-- ============================================================
-- BACKSTAB UI
-- ============================================================
local BsBox = Tabs.Backstab:AddLeftGroupbox('Always Backstab')
BsBox:AddToggle('StabHitboxToggle', {
    Text = 'Expand Enemy Head Hitbox', Default = false,
    Callback = function(v)
        St.hitbox.active = v
        if not v then restoreHitbox() end
    end,
})
BsBox:AddSlider('StabHitboxScale', {
    Text = 'Hitbox Scale (x)', Default = 20, Min = 2, Max = 50, Rounding = 0,
    Callback = function(v) St.hitbox.scale = v end,
})

local BsInfo = Tabs.Backstab:AddRightGroupbox('How it works')
BsInfo:AddLabel('Expands every other player\'s Head part to 20x.')
BsInfo:AddLabel('Makes backstab hit regardless of facing angle.')
BsInfo:AddLabel('Restores original sizes on toggle-off.')

-- ============================================================
-- UI SETTINGS
-- ============================================================
local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')
MenuGroup:AddButton('Unload', function()
    if BurgadaStabbedUnload then BurgadaStabbedUnload() end
    Library:Unload()
end)

-- ============================================================
-- TICKS
-- ============================================================
StabbedConn = RunService.RenderStepped:Connect(function()
    local ok = alive()
    if not ok then return end
    pcall(rageTick)
end)

StabbedVoid = RunService.Heartbeat:Connect(function()
    if not St.hitbox.active then return end
    pcall(applyHitbox)
end)

-- ============================================================
-- UNLOAD
-- ============================================================
function BurgadaStabbedUnload()
    if StabbedConn then StabbedConn:Disconnect() end
    if StabbedVoid then StabbedVoid:Disconnect() end
    St.rage.active = false
    St.rage.stickyTarget = nil
    St.rage.phase = 'Idle'
    releaseVoid()
    restoreHitbox()
end

Library:Notify('Burgada Lua | Stabbed loaded')