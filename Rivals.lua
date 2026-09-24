-- language: Lua (Roblox Luau), file: burgada_rivals.lua
-- executor: Delta Android (also PC)
-- paste after attaching. standalone. self-cleaning.

-- ============================================================
-- PRE-FLIGHT CLEANUP
-- ============================================================
pcall(function()
    if RivalsConn then RivalsConn:Disconnect() end
    if RivalsHitbox then RivalsHitbox:Disconnect() end
    if RivalsAA then RivalsAA:Disconnect() end
    if RivalsRender then RivalsRender:Disconnect() end
    if RivalsHud then RivalsHud:Disconnect() end
    if BurgadaRivalsUnload then pcall(BurgadaRivalsUnload) end
end)
pcall(function()
    local cg = game:GetService('CoreGui')
    for _, name in ipairs({ 'BurgadaESP', 'BurgadaHUD', 'LinoriaLib' }) do
        local g = cg:FindFirstChild(name)
        if g then g:Destroy() end
    end
end)
pcall(function()
    local pg = game.Players.LocalPlayer:FindFirstChild('PlayerGui')
    if pg then
        for _, name in ipairs({ 'BurgadaESP', 'BurgadaHUD', 'LinoriaLib' }) do
            local g = pg:FindFirstChild(name)
            if g then g:Destroy() end
        end
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
local State = {
    orbit    = { active = false, radius = 10, speed = 5 },
    hitbox   = { active = false, size = 10, applied = {} },
    voidhide = { active = false, anchored = false },
    voidspam = { active = false, dist = 15000, acc = 0, interval = 0.15 },
    sling    = { active = false, height = 10 },
    contact  = { active = false, range = 30, height = 5, cooldown = 0.15,
                 last = 0, conns = {}, rebindConn = nil },
    esp      = { active = false, box = true, name = true, dist = true,
                 teamCheck = true, maxDist = 500 },
    hud      = { active = false, gui = nil, frame = nil, labels = {}, last = 0 },
    aa = {
        upsideDown = false, sideways = false, backwards = false,
        prone = false, lyingFlat = false,
        spin360 = { active = false, speed = 720 },
        jitterYaw = { active = false, amount = 45, hz = 30 },
        jitterPitch = { active = false, amount = 30, hz = 25 },
        lean = { active = false, angle = 40 },
        rollFlip = { active = false, speed = 180 },
        microJitter = { active = false, amount = 0.4 },
        shake = { active = false, amount = 0.3, hz = 60 },
        stutter = { active = false, hz = 15 },
        bob = { active = false, amp = 0.5, hz = 2 },
        hoverOnGround = { active = false, height = 0.5 },
        sinkIntoGround = { active = false, depth = 1 },
        freezeInAir = false, zeroVelocity = false,
        cframeDesync = { active = false, offset = 0.6 },
        headSpin = { active = false, speed = 900 },
        headDown = false, headBack = false,
        headJitter = { active = false, amount = 30, hz = 40 },
        orbitHead = { active = false, radius = 1.5, speed = 6 },
        cameraLockDown = false, cameraLockUp = false, cameraLockBack = false,
        cameraSpin = { active = false, speed = 360 },
        aimBotLookingAt = false, aimBotFacingAway = false,
        crouchWalk = false,
        twerkLoop = { active = false, hz = 8 },
        tiltIdle = { active = false, angle = 15, hz = 1 },
        lastJitterYaw = 0, lastJitterPitch = 0, lastShake = 0, lastStutter = 0,
        lastBob = 0, lastTwerk = 0, lastTiltIdle = 0, lastHeadJitter = 0,
        spinAngle = 0, rollAngle = 0, camSpinAngle = 0, headSpinAngle = 0,
        orbitHeadAngle = 0, stutterToggle = false,
        conns = {},
    },
    fill = {
        active = false, running = false,
        origin = nil, floorY = nil, len = 50, wid = 30,
        step = 0.0002, acc = 0, idx = 0, cells = nil, depth = 6, anchored = false,
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

local function nearestRoot()
    local ok, _, _, myRoot = alive()
    if not ok or not myRoot then return nil end
    local best, bestD = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local r = p.Character:FindFirstChild('HumanoidRootPart')
            if r then
                local d = (myRoot.Position - r.Position).Magnitude
                if d < bestD then bestD, best = d, r end
            end
        end
    end
    return best
end

local function isEnemy(p)
    if p == LP then return false end
    if not State.esp.teamCheck then return true end
    if LP.Team and p.Team and LP.Team == p.Team then return false end
    return true
end

local function isAAActive()
    local a = State.aa
    if a.upsideDown or a.sideways or a.backwards or a.prone or a.lyingFlat then return true end
    if a.spin360.active or a.jitterYaw.active or a.jitterPitch.active then return true end
    if a.lean.active or a.rollFlip.active then return true end
    if a.microJitter.active or a.shake.active or a.stutter.active or a.bob.active then return true end
    if a.cameraLockDown or a.cameraLockUp or a.cameraLockBack or a.cameraSpin.active then return true end
    if a.headSpin.active or a.headDown or a.headBack or a.headJitter.active then return true end
    if a.hoverOnGround.active or a.sinkIntoGround.active or a.freezeInAir then return true end
    if a.cframeDesync.active or a.zeroVelocity then return true end
    if a.aimBotLookingAt or a.aimBotFacingAway or a.crouchWalk then return true end
    if a.orbitHead.active or a.twerkLoop.active or a.tiltIdle.active then return true end
    return false
end

-- ============================================================
-- CONTACT TELEPORT
-- ============================================================
local function doContactJump()
    local _, _, _, myRoot = alive()
    if not myRoot then return end
    local r = State.contact.range
    local h = State.contact.height
    local angle = math.random() * math.pi * 2
    local dist  = math.random() * r
    local dx = math.cos(angle) * dist
    local dz = math.sin(angle) * dist
    local basePos = myRoot.Position
    local target = Vector3.new(basePos.X + dx, basePos.Y + h, basePos.Z + dz)
    myRoot.CFrame = CFrame.new(target, target + myRoot.CFrame.LookVector)
    myRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
end

local function onTouch(hit)
    if not State.contact.active then return end
    if not hit or not hit.Parent then return end
    local _, c = alive()
    if not c then return end
    if hit:IsDescendantOf(c) then return end
    local now = os.clock()
    if now - State.contact.last < State.contact.cooldown then return end
    State.contact.last = now
    pcall(doContactJump)
end

local function unbindContact()
    for _, c in ipairs(State.contact.conns) do
        pcall(function() c:Disconnect() end)
    end
    State.contact.conns = {}
    if State.contact.rebindConn then
        pcall(function() State.contact.rebindConn:Disconnect() end)
        State.contact.rebindConn = nil
    end
end

local function bindContact()
    for _, c in ipairs(State.contact.conns) do
        pcall(function() c:Disconnect() end)
    end
    State.contact.conns = {}
    local ok, c = alive()
    if not ok then return end
    for _, part in ipairs(c:GetDescendants()) do
        if part:IsA('BasePart') then
            local conn = part.Touched:Connect(function(hit) onTouch(hit) end)
            table.insert(State.contact.conns, conn)
        end
    end
end

local function watchRespawn()
    if State.contact.rebindConn then
        pcall(function() State.contact.rebindConn:Disconnect() end)
    end
    State.contact.rebindConn = LP.CharacterAdded:Connect(function()
        task.wait(1)
        if State.contact.active then bindContact() end
    end)
end

-- ============================================================
-- ESP
-- ============================================================
local function newDrawing(class, props)
    local ok, d = pcall(function() return Drawing.new(class) end)
    if not ok or not d then return nil end
    for k, v in pairs(props) do d[k] = v end
    return d
end

local espParts = {}
local function espTick()
    if not State.esp.active then
        for _, tbl in pairs(espParts) do
            for _, d in pairs(tbl) do pcall(function() d.Visible = false end) end
        end
        return
    end
    if not Drawing then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local _, _, _, myRoot = alive()
    local myPos = myRoot and myRoot.Position or Vector3.zero

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and isEnemy(p) then
            local head = p.Character:FindFirstChild('Head')
            local hrp  = p.Character:FindFirstChild('HumanoidRootPart')
            local hum  = p.Character:FindFirstChildOfClass('Humanoid')
            if head and hrp and hum and hum.Health > 0 then
                local dist = (myPos - hrp.Position).Magnitude
                if dist <= State.esp.maxDist then
                    local hp, ho = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                    local fp, fo = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                    if not espParts[p] then
                        espParts[p] = {
                            box  = newDrawing('Square', { Thickness = 1, Filled = false, Color = Color3.fromRGB(255, 60, 60) }),
                            name = newDrawing('Text',   { Size = 14, Center = true, Outline = true, Color = Color3.fromRGB(255, 255, 255) }),
                            dist = newDrawing('Text',   { Size = 12, Center = true, Outline = true, Color = Color3.fromRGB(200, 200, 200) }),
                        }
                    end
                    local t = espParts[p]
                    if ho and fo then
                        local h = math.abs(fp.Y - hp.Y)
                        local w = h * 0.55
                        local x = hp.X - w / 2
                        local y = hp.Y
                        if State.esp.box then
                            t.box.Visible = true
                            t.box.Size = Vector2.new(w, h)
                            t.box.Position = Vector2.new(x, y)
                        else t.box.Visible = false end
                        if State.esp.name then
                            t.name.Visible = true
                            t.name.Text = p.Name
                            t.name.Position = Vector2.new(hp.X, y - 16)
                        else t.name.Visible = false end
                        if State.esp.dist then
                            t.dist.Visible = true
                            t.dist.Text = string.format('%dm', math.floor(dist))
                            t.dist.Position = Vector2.new(hp.X, y + h + 4)
                        else t.dist.Visible = false end
                    else
                        t.box.Visible = false
                        t.name.Visible = false
                        t.dist.Visible = false
                    end
                end
            end
        end
    end
end

-- ============================================================
-- HUD
-- ============================================================
local function ensureHudGui()
    if State.hud.gui and State.hud.gui.Parent then return end
    local gui = Instance.new('ScreenGui')
    gui.Name = 'BurgadaHUD'
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    pcall(function() gui.Parent = game:GetService('CoreGui') end)
    if not gui.Parent then pcall(function() gui.Parent = LP:WaitForChild('PlayerGui') end) end

    local frame = Instance.new('Frame')
    frame.Size = UDim2.new(0, 200, 0, 76)
    frame.Position = UDim2.new(0, 20, 0.5, -38)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = gui

    local stroke = Instance.new('UIStroke')
    stroke.Color = Color3.fromRGB(255, 60, 60)
    stroke.Thickness = 1
    stroke.Parent = frame

    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local nameL = Instance.new('TextLabel')
    nameL.BackgroundTransparency = 1
    nameL.Size = UDim2.new(1, -12, 0, 20)
    nameL.Position = UDim2.new(0, 6, 0, 4)
    nameL.Font = Enum.Font.GothamBold
    nameL.TextSize = 14
    nameL.TextXAlignment = Enum.TextXAlignment.Left
    nameL.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameL.Text = '—'
    nameL.Parent = frame

    local distL = Instance.new('TextLabel')
    distL.BackgroundTransparency = 1
    distL.Size = UDim2.new(1, -12, 0, 16)
    distL.Position = UDim2.new(0, 6, 0, 24)
    distL.Font = Enum.Font.Gotham
    distL.TextSize = 12
    distL.TextXAlignment = Enum.TextXAlignment.Left
    distL.TextColor3 = Color3.fromRGB(200, 200, 200)
    distL.Text = '—'
    distL.Parent = frame

    local hpBg = Instance.new('Frame')
    hpBg.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    hpBg.BorderSizePixel = 0
    hpBg.Size = UDim2.new(1, -12, 0, 8)
    hpBg.Position = UDim2.new(0, 6, 1, -16)
    hpBg.Parent = frame

    local hc = Instance.new('UICorner')
    hc.CornerRadius = UDim.new(0, 2)
    hc.Parent = hpBg

    local hpFg = Instance.new('Frame')
    hpFg.BackgroundColor3 = Color3.fromRGB(60, 220, 60)
    hpFg.BorderSizePixel = 0
    hpFg.Size = UDim2.new(1, 0, 1, 0)
    hpFg.Parent = hpBg

    local fc = Instance.new('UICorner')
    fc.CornerRadius = UDim.new(0, 2)
    fc.Parent = hpFg

    State.hud.gui = gui
    State.hud.frame = frame
    State.hud.labels = { name = nameL, dist = distL, hpFg = hpFg }
end

local function hudTick()
    if not State.hud.active then
        if State.hud.frame then State.hud.frame.Visible = false end
        return
    end
    ensureHudGui()
    if not State.hud.frame then return end
    local now = os.clock()
    if now - State.hud.last < 0.1 then return end
    State.hud.last = now
    local target = nearestRoot()
    if not target then State.hud.frame.Visible = false; return end
    local p = Players:GetPlayerFromCharacter(target.Parent)
    if not p or not isEnemy(p) then State.hud.frame.Visible = false; return end
    local hum = target.Parent:FindFirstChildOfClass('Humanoid')
    if not hum then State.hud.frame.Visible = false; return end
    local _, _, _, myRoot = alive()
    local dist = myRoot and math.floor((myRoot.Position - target.Position).Magnitude) or 0
    local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
    State.hud.frame.Visible = true
    State.hud.labels.name.Text = p.Name
    State.hud.labels.dist.Text = string.format('%d studs', dist)
    State.hud.labels.hpFg.Size = UDim2.new(pct, 0, 1, 0)
end

-- ============================================================
-- ANTI-AIM
-- ============================================================
local function antiAimTick(dt)
    if not isAAActive() then return end
    local ok, c, hum, myRoot = alive()
    if not ok or not myRoot then return end
    local a = State.aa
    local now = os.clock()
    local pos = myRoot.Position
    local baseCF = myRoot.CFrame

    if a.hoverOnGround.active then pos = Vector3.new(pos.X, pos.Y + a.hoverOnGround.height, pos.Z) end
    if a.sinkIntoGround.active then pos = Vector3.new(pos.X, pos.Y - a.sinkIntoGround.depth, pos.Z) end
    if a.microJitter.active then
        local amt = a.microJitter.amount
        pos = pos + Vector3.new((math.random()-0.5)*amt, (math.random()-0.5)*amt, (math.random()-0.5)*amt)
    end
    if a.shake.active then
        if now - a.lastShake >= 1 / a.shake.hz then
            a.lastShake = now
            local amt = a.shake.amount
            pos = pos + Vector3.new((math.random()-0.5)*amt, (math.random()-0.5)*amt, (math.random()-0.5)*amt)
        end
    end
    if a.cframeDesync.active then pos = pos + Vector3.new(a.cframeDesync.offset, 0, 0) end
    if a.bob.active then
        if now - a.lastBob >= 1 / a.bob.hz then
            a.lastBob = now
            pos = pos + Vector3.new(0, math.sin(now * a.bob.hz * 6.28) * a.bob.amp, 0)
        end
    end

    local rot = baseCF - pos
    local newRot = rot

    if a.upsideDown then newRot = newRot * CFrame.Angles(math.pi, 0, 0) end
    if a.sideways then newRot = newRot * CFrame.Angles(0, 0, math.pi / 2) end
    if a.backwards then newRot = newRot * CFrame.Angles(0, math.pi, 0) end
    if a.prone then newRot = newRot * CFrame.Angles(math.pi / 2, 0, 0) end
    if a.lyingFlat then newRot = newRot * CFrame.Angles(0, 0, math.pi) end
    if a.lean.active then newRot = newRot * CFrame.Angles(0, 0, math.rad(a.lean.angle)) end
    if a.spin360.active then
        a.spinAngle = a.spinAngle + math.rad(a.spin360.speed) * dt
        newRot = newRot * CFrame.Angles(0, a.spinAngle, 0)
    end
    if a.jitterYaw.active then
        if now - a.lastJitterYaw >= 1 / a.jitterYaw.hz then
            a.lastJitterYaw = now
            a.jitterYawSign = (a.jitterYawSign or 1) * -1
            newRot = newRot * CFrame.Angles(0, math.rad(a.jitterYaw.amount * a.jitterYawSign), 0)
        end
    end
    if a.jitterPitch.active then
        if now - a.lastJitterPitch >= 1 / a.jitterPitch.hz then
            a.lastJitterPitch = now
            a.jitterPitchSign = (a.jitterPitchSign or 1) * -1
            newRot = newRot * CFrame.Angles(math.rad(a.jitterPitch.amount * a.jitterPitchSign), 0, 0)
        end
    end
    if a.rollFlip.active then
        a.rollAngle = a.rollAngle + math.rad(a.rollFlip.speed) * dt
        newRot = newRot * CFrame.Angles(0, 0, a.rollAngle)
    end
    if a.tiltIdle.active then
        if now - a.lastTiltIdle >= 1 / a.tiltIdle.hz then
            a.lastTiltIdle = now
            a.tiltIdleSign = (a.tiltIdleSign or 1) * -1
            newRot = newRot * CFrame.Angles(0, 0, math.rad(a.tiltIdle.angle * a.tiltIdleSign))
        end
    end
    if a.aimBotLookingAt then
        local t = nearestRoot()
        if t then newRot = CFrame.lookAt(Vector3.zero, (t.Position - pos)) end
    end
    if a.aimBotFacingAway then
        local t = nearestRoot()
        if t then newRot = CFrame.lookAt(Vector3.zero, (pos - t.Position)) end
    end

    myRoot.CFrame = CFrame.new(pos) * newRot

    if a.zeroVelocity then
        myRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        myRoot.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
    if a.freezeInAir then myRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
    if a.stutter.active then
        if now - a.lastStutter >= 1 / a.stutter.hz then
            a.lastStutter = now
            a.stutterToggle = not a.stutterToggle
            if a.stutterToggle then myRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
        end
    end

    local head = c:FindFirstChild('Head')
    if head and (a.headSpin.active or a.headDown or a.headBack or a.headJitter.active or a.orbitHead.active) then
        local orig = head.CFrame
        local hr = CFrame.new()
        if a.headDown then hr = hr * CFrame.Angles(math.pi / 2, 0, 0) end
        if a.headBack then hr = hr * CFrame.Angles(0, math.pi, 0) end
        if a.headSpin.active then
            a.headSpinAngle = a.headSpinAngle + math.rad(a.headSpin.speed) * dt
            hr = hr * CFrame.Angles(0, a.headSpinAngle, 0)
        end
        if a.headJitter.active then
            if now - a.lastHeadJitter >= 1 / a.headJitter.hz then
                a.lastHeadJitter = now
                a.headJitterSign = (a.headJitterSign or 1) * -1
                hr = hr * CFrame.Angles(0, math.rad(a.headJitter.amount * a.headJitterSign), 0)
            end
        end
        if a.orbitHead.active then
            a.orbitHeadAngle = a.orbitHeadAngle + a.orbitHead.speed * dt
            local r = a.orbitHead.radius
            hr = hr * CFrame.new(math.cos(a.orbitHeadAngle) * r, math.sin(a.orbitHeadAngle) * r, 0)
        end
        pcall(function() head.CFrame = orig * hr end)
    end

    local cam = workspace.CurrentCamera
    if cam then
        if a.cameraLockDown then
            cam.CFrame = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + Vector3.new(0, -1, 0))
        end
        if a.cameraLockUp then
            cam.CFrame = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + Vector3.new(0, 1, 0))
        end
        if a.cameraLockBack then
            cam.CFrame = CFrame.new(cam.CFrame.Position, cam.CFrame.Position - baseCF.LookVector)
        end
        if a.cameraSpin.active then
            a.camSpinAngle = a.camSpinAngle + math.rad(a.cameraSpin.speed) * dt
            local camPos = cam.CFrame.Position
            local off = (camPos - pos).Unit * 10
            cam.CFrame = CFrame.new(camPos, pos + CFrame.Angles(0, a.camSpinAngle, 0) * off)
        end
    end

    if a.crouchWalk and hum then
        hum.CameraOffset = hum.CameraOffset:Lerp(Vector3.new(0, -1.5, 0), 0.2)
    end
    if a.twerkLoop.active then
        if now - a.lastTwerk >= 1 / a.twerkLoop.hz then
            a.lastTwerk = now
            a.twerkSign = (a.twerkSign or 1) * -1
            local hips = c:FindFirstChild('LowerTorso') or c:FindFirstChild('Torso')
            if hips then
                pcall(function() hips.CFrame = hips.CFrame * CFrame.Angles(0, 0, math.rad(15 * a.twerkSign)) end)
            end
        end
    end
end

-- ============================================================
-- RECTANGLE FILL (underground)
-- ============================================================
local function buildRectCells(originXZ, len, wid, cellSize)
    local cols = math.max(1, math.floor(len / cellSize))
    local rows = math.max(1, math.floor(wid / cellSize))
    local cells = {}
    for r = 0, rows - 1 do
        local xs, xe, st
        if r % 2 == 0 then xs, xe, st = 0, cols - 1, 1 else xs, xe, st = cols - 1, 0, -1 end
        for c = xs, xe, st do
            local ox = (c - cols / 2) * cellSize
            local oz = (r - rows / 2) * cellSize
            table.insert(cells, Vector3.new(originXZ.X + ox, 0, originXZ.Z + oz))
        end
    end
    return cells
end

local function findFloorY(x, z, y0)
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances = { LP.Character }
    local r = workspace:Raycast(Vector3.new(x, y0 + 50, z), Vector3.new(0, -200, 0), p)
    if r then return r.Position.Y end
    return y0 - 5
end

local function fillBegin()
    local _, _, _, myRoot = alive()
    if not myRoot then return end
    local f = State.fill
    f.origin = myRoot.Position
    f.floorY = findFloorY(myRoot.Position.X, myRoot.Position.Z, myRoot.Position.Y)
    f.cells = buildRectCells(myRoot.Position, f.len, f.wid, 1)
    f.idx = 0; f.acc = 0; f.running = true; f.anchored = true
    myRoot.Anchored = true
end

local function fillStop()
    local f = State.fill
    f.running = false; f.cells = nil; f.idx = 0; f.acc = 0
    pcall(function()
        local _, _, _, r = alive()
        if r then r.Anchored = false; r.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
    end)
    f.anchored = false
end

local function fillTick(dt)
    local f = State.fill
    if not f.active then
        if f.running then fillStop() end
        return
    end
    if not f.running then fillBegin() end
    if not f.cells then return end
    local _, _, _, myRoot = alive()
    if not myRoot then return end
    f.acc = f.acc + dt
    if f.acc < f.step then return end
    local n = math.floor(f.acc / f.step)
    f.acc = f.acc - n * f.step
    if n > 500 then n = 500 end
    if n < 1 then n = 1 end
    local total = #f.cells
    local target = nearestRoot()
    local lookDir
    if target then
        local away = myRoot.Position - target.Position
        away = Vector3.new(away.X, 0, away.Z)
        if away.Magnitude > 0.01 then lookDir = away.Unit
        else lookDir = Vector3.new(0, 0, 1) end
    else
        lookDir = Vector3.new(0, 0, 1)
    end
    for i = 1, n do
        f.idx = f.idx + 1
        if f.idx > total then f.idx = 1 end
    end
    local cell = f.cells[f.idx]
    local floorY = f.floorY or (f.origin.Y - 5)
    local standY = floorY - f.depth
    if standY < floorY - 40 then standY = floorY - 40 end
    local standPos = Vector3.new(cell.X, standY, cell.Z)
    myRoot.CFrame = CFrame.new(standPos, standPos + lookDir)
end

-- ============================================================
-- WINDOW
-- ============================================================
local Window = Library:CreateWindow({
    Title                = 'Burgada Lua | Rivals',
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
    Combat          = Window:AddTab('Combat'),
    Visuals         = Window:AddTab('Visuals'),
    Movement        = Window:AddTab('Movement'),
    Sling           = Window:AddTab('Sling'),
    ['Anti-Aim']    = Window:AddTab('Anti-Aim'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- ============================================================
-- COMBAT UI
-- ============================================================
local CLeft = Tabs.Combat:AddLeftGroupbox('Orbit')
CLeft:AddToggle('OrbitToggle', { Text = 'Orbit Nearest Player', Default = false,
    Callback = function(v) State.orbit.active = v end })
CLeft:AddSlider('OrbitRadius', { Text = 'Radius (studs)', Default = 10, Min = 2, Max = 50, Rounding = 0,
    Callback = function(v) State.orbit.radius = v end })
CLeft:AddSlider('OrbitSpeed', { Text = 'Speed', Default = 5, Min = 1, Max = 20, Rounding = 0,
    Callback = function(v) State.orbit.speed = v end })

local CRight = Tabs.Combat:AddRightGroupbox('Hitbox')
CRight:AddToggle('HitboxToggle', { Text = 'Expand Enemy Hitboxes', Default = false,
    Callback = function(v)
        State.hitbox.active = v
        if not v then
            for part, orig in pairs(State.hitbox.applied) do
                pcall(function() part.Size = orig end)
            end
            State.hitbox.applied = {}
        end
    end })
CRight:AddSlider('HitboxSize', { Text = 'Hitbox Size (studs)', Default = 10, Min = 2, Max = 30, Rounding = 0,
    Callback = function(v) State.hitbox.size = v end })

local SubGroup = Tabs.Combat:AddRightGroupbox('Contact Teleport')
SubGroup:AddToggle('ContactToggle', { Text = 'Contact Teleport (any touch)', Default = false,
    Callback = function(v)
        State.contact.active = v
        if v then bindContact(); watchRespawn() else unbindContact() end
    end })
SubGroup:AddSlider('ContactRange', { Text = 'Jump Range (studs)', Default = 30, Min = 5, Max = 200, Rounding = 0,
    Callback = function(v) State.contact.range = v end })
SubGroup:AddSlider('ContactHeight', { Text = 'Jump Height (studs)', Default = 5, Min = 0, Max = 30, Rounding = 0,
    Callback = function(v) State.contact.height = v end })
SubGroup:AddSlider('ContactCooldown', { Text = 'Cooldown (s)', Default = 0.15, Min = 0.03, Max = 1, Rounding = 2,
    Callback = function(v) State.contact.cooldown = v end })

-- ============================================================
-- VISUALS UI
-- ============================================================
local EspLeft = Tabs.Visuals:AddLeftGroupbox('ESP')
EspLeft:AddToggle('EspToggle', { Text = 'Enable ESP', Default = false,
    Callback = function(v) State.esp.active = v end })
EspLeft:AddToggle('EspBox',  { Text = 'Box', Default = true, Callback = function(v) State.esp.box = v end })
EspLeft:AddToggle('EspName', { Text = 'Name', Default = true, Callback = function(v) State.esp.name = v end })
EspLeft:AddToggle('EspDist', { Text = 'Distance', Default = true, Callback = function(v) State.esp.dist = v end })
EspLeft:AddToggle('EspTeam', { Text = 'Team Check', Default = true, Callback = function(v) State.esp.teamCheck = v end })
EspLeft:AddSlider('EspMaxDist', { Text = 'Max Render Distance (studs)', Default = 500, Min = 50, Max = 2000, Rounding = 0,
    Callback = function(v) State.esp.maxDist = v end })

local HudRight = Tabs.Visuals:AddRightGroupbox('Target HUD')
HudRight:AddToggle('HudToggle', { Text = 'Enable Target HUD', Default = false,
    Callback = function(v)
        State.hud.active = v
        ensureHudGui()
        if not v and State.hud.frame then State.hud.frame.Visible = false end
    end })

-- ============================================================
-- MOVEMENT UI
-- ============================================================
local MGroup = Tabs.Movement:AddLeftGroupbox('Void & Evasion')
MGroup:AddToggle('VoidHideToggle', { Text = 'Void Hiding (anchor + hide)', Default = false,
    Callback = function(v)
        State.voidhide.active = v
        if not v then
            pcall(function()
                local _, _, _, r = alive()
                if r then r.Anchored = false end
            end)
            State.voidhide.anchored = false
        end
    end })
MGroup:AddToggle('VoidspamToggle', { Text = 'Out-of-Bounds Voidspam', Default = false,
    Callback = function(v)
        State.voidspam.active = v
        if not v then
            pcall(function()
                local _, _, _, r = alive()
                if r then r.Anchored = false end
            end)
        end
    end })
MGroup:AddSlider('VoidspamDist', { Text = 'Void Distance (studs)', Default = 15000, Min = 1000, Max = 100000, Rounding = 0,
    Callback = function(v) State.voidspam.dist = v end })
MGroup:AddSlider('VoidspamHop', { Text = 'Hop Interval (s)', Default = 0.15, Min = 0.05, Max = 1, Rounding = 2,
    Callback = function(v) State.voidspam.interval = v end })

-- ============================================================
-- SLING UI
-- ============================================================
local SGroup = Tabs.Sling:AddLeftGroupbox('Sticky Sling')
SGroup:AddToggle('SlingToggle', { Text = 'Enable Snap Sling', Default = false,
    Callback = function(v) State.sling.active = v end })
SGroup:AddSlider('SlingHeight', { Text = 'Height Above Target', Default = 10, Min = 2, Max = 30, Rounding = 0,
    Callback = function(v) State.sling.height = v end })

-- ============================================================
-- ANTI-AIM UI
-- ============================================================
local AaA = Tabs['Anti-Aim']:AddLeftGroupbox('Orientation')
AaA:AddToggle('AAUpsideDown', { Text = 'Upside Down (flip only)', Default = false,
    Callback = function(v) State.aa.upsideDown = v end })
AaA:AddToggle('AASideways', { Text = 'Sideways', Default = false,
    Callback = function(v) State.aa.sideways = v end })
AaA:AddToggle('AABackwards', { Text = 'Backwards', Default = false,
    Callback = function(v) State.aa.backwards = v end })
AaA:AddToggle('AAProne', { Text = 'Prone', Default = false,
    Callback = function(v) State.aa.prone = v end })
AaA:AddToggle('AALyingFlat', { Text = 'Lying Flat', Default = false,
    Callback = function(v) State.aa.lyingFlat = v end })
AaA:AddToggle('AASpin360', { Text = 'Continuous 360 Spin', Default = false,
    Callback = function(v) State.aa.spin360.active = v end })
AaA:AddSlider('AASpin360Speed', { Text = 'Spin Speed (deg/s)', Default = 720, Min = 60, Max = 3000, Rounding = 0,
    Callback = function(v) State.aa.spin360.speed = v end })
AaA:AddToggle('AALean', { Text = 'Static Lean', Default = false,
    Callback = function(v) State.aa.lean.active = v end })
AaA:AddSlider('AALeanAngle', { Text = 'Lean Angle (deg)', Default = 40, Min = 5, Max = 90, Rounding = 0,
    Callback = function(v) State.aa.lean.angle = v end })
AaA:AddToggle('AARollFlip', { Text = 'Continuous Roll', Default = false,
    Callback = function(v) State.aa.rollFlip.active = v end })
AaA:AddSlider('AARollSpeed', { Text = 'Roll Speed (deg/s)', Default = 180, Min = 30, Max = 1440, Rounding = 0,
    Callback = function(v) State.aa.rollFlip.speed = v end })

local AaB = Tabs['Anti-Aim']:AddLeftGroupbox('Jitter')
AaB:AddToggle('AAJitterYaw', { Text = 'Yaw Jitter', Default = false,
    Callback = function(v) State.aa.jitterYaw.active = v end })
AaB:AddSlider('AAJitterYawAmt', { Text = 'Yaw Amount (deg)', Default = 45, Min = 5, Max = 180, Rounding = 0,
    Callback = function(v) State.aa.jitterYaw.amount = v end })
AaB:AddSlider('AAJitterYawHz', { Text = 'Yaw Rate (Hz)', Default = 30, Min = 1, Max = 120, Rounding = 0,
    Callback = function(v) State.aa.jitterYaw.hz = v end })
AaB:AddToggle('AAJitterPitch', { Text = 'Pitch Jitter', Default = false,
    Callback = function(v) State.aa.jitterPitch.active = v end })
AaB:AddSlider('AAJitterPitchAmt', { Text = 'Pitch Amount (deg)', Default = 30, Min = 5, Max = 180, Rounding = 0,
    Callback = function(v) State.aa.jitterPitch.amount = v end })
AaB:AddSlider('AAJitterPitchHz', { Text = 'Pitch Rate (Hz)', Default = 25, Min = 1, Max = 120, Rounding = 0,
    Callback = function(v) State.aa.jitterPitch.hz = v end })
AaB:AddToggle('AAHeadJitter', { Text = 'Head-Only Jitter', Default = false,
    Callback = function(v) State.aa.headJitter.active = v end })
AaB:AddSlider('AAHeadJitterAmt', { Text = 'Head Amount (deg)', Default = 30, Min = 5, Max = 180, Rounding = 0,
    Callback = function(v) State.aa.headJitter.amount = v end })
AaB:AddSlider('AAHeadJitterHz', { Text = 'Head Rate (Hz)', Default = 40, Min = 1, Max = 120, Rounding = 0,
    Callback = function(v) State.aa.headJitter.hz = v end })

local AaC = Tabs['Anti-Aim']:AddLeftGroupbox('Micro-Motion')
AaC:AddToggle('AAMicroJitter', { Text = 'Micro Position Jitter', Default = false,
    Callback = function(v) State.aa.microJitter.active = v end })
AaC:AddSlider('AAMicroJitterAmt', { Text = 'Amplitude (studs)', Default = 0.4, Min = 0.05, Max = 3, Rounding = 2,
    Callback = function(v) State.aa.microJitter.amount = v end })
AaC:AddToggle('AAShake', { Text = 'Body Shake', Default = false,
    Callback = function(v) State.aa.shake.active = v end })
AaC:AddSlider('AAShakeAmt', { Text = 'Shake Amount (studs)', Default = 0.3, Min = 0.05, Max = 2, Rounding = 2,
    Callback = function(v) State.aa.shake.amount = v end })
AaC:AddSlider('AAShakeHz', { Text = 'Shake Rate (Hz)', Default = 60, Min = 5, Max = 120, Rounding = 0,
    Callback = function(v) State.aa.shake.hz = v end })
AaC:AddToggle('AAStutter', { Text = 'Freeze-Thaw Stutter', Default = false,
    Callback = function(v) State.aa.stutter.active = v end })
AaC:AddSlider('AAStutterHz', { Text = 'Stutter Rate (Hz)', Default = 15, Min = 1, Max = 60, Rounding = 0,
    Callback = function(v) State.aa.stutter.hz = v end })
AaC:AddToggle('AABob', { Text = 'Idle Bob', Default = false,
    Callback = function(v) State.aa.bob.active = v end })
AaC:AddSlider('AABobAmp', { Text = 'Bob Amplitude (studs)', Default = 0.5, Min = 0.1, Max = 3, Rounding = 2,
    Callback = function(v) State.aa.bob.amp = v end })
AaC:AddSlider('AABobHz', { Text = 'Bob Rate (Hz)', Default = 2, Min = 0.5, Max = 10, Rounding = 1,
    Callback = function(v) State.aa.bob.hz = v end })

local AaD = Tabs['Anti-Aim']:AddLeftGroupbox('Position')
AaD:AddToggle('AAHoverGround', { Text = 'Hover Above Ground', Default = false,
    Callback = function(v) State.aa.hoverOnGround.active = v end })
AaD:AddSlider('AAHoverHeight', { Text = 'Hover Height (studs)', Default = 0.5, Min = 0.05, Max = 5, Rounding = 2,
    Callback = function(v) State.aa.hoverOnGround.height = v end })
AaD:AddToggle('AASinkGround', { Text = 'Sink Into Ground', Default = false,
    Callback = function(v) State.aa.sinkIntoGround.active = v end })
AaD:AddSlider('AASinkDepth', { Text = 'Sink Depth (studs)', Default = 1, Min = 0.1, Max = 5, Rounding = 2,
    Callback = function(v) State.aa.sinkIntoGround.depth = v end })
AaD:AddToggle('AAZeroVel', { Text = 'Zero All Velocity', Default = false,
    Callback = function(v) State.aa.zeroVelocity = v end })
AaD:AddToggle('AACframeDesync', { Text = 'CFrame Offset', Default = false,
    Callback = function(v) State.aa.cframeDesync.active = v end })
AaD:AddSlider('AACframeDesyncAmt', { Text = 'Offset (studs)', Default = 0.6, Min = 0.1, Max = 5, Rounding = 2,
    Callback = function(v) State.aa.cframeDesync.offset = v end })

local AaE = Tabs['Anti-Aim']:AddLeftGroupbox('Head')
AaE:AddToggle('AAHeadSpin', { Text = 'Head Spin', Default = false,
    Callback = function(v) State.aa.headSpin.active = v end })
AaE:AddSlider('AAHeadSpinSpeed', { Text = 'Spin Speed (deg/s)', Default = 900, Min = 60, Max = 3000, Rounding = 0,
    Callback = function(v) State.aa.headSpin.speed = v end })
AaE:AddToggle('AAHeadDown', { Text = 'Head Down', Default = false,
    Callback = function(v) State.aa.headDown = v end })
AaE:AddToggle('AAHeadBack', { Text = 'Head Back', Default = false,
    Callback = function(v) State.aa.headBack = v end })
AaE:AddToggle('AAOrbitHead', { Text = 'Orbit Head', Default = false,
    Callback = function(v) State.aa.orbitHead.active = v end })
AaE:AddSlider('AAOrbitHeadRadius', { Text = 'Orbit Radius (studs)', Default = 1.5, Min = 0.3, Max = 6, Rounding = 2,
    Callback = function(v) State.aa.orbitHead.radius = v end })
AaE:AddSlider('AAOrbitHeadSpeed', { Text = 'Orbit Speed', Default = 6, Min = 1, Max = 30, Rounding = 0,
    Callback = function(v) State.aa.orbitHead.speed = v end })

local AaF = Tabs['Anti-Aim']:AddRightGroupbox('Camera')
AaF:AddToggle('AACamDown', { Text = 'Camera Lock Down', Default = false,
    Callback = function(v) State.aa.cameraLockDown = v end })
AaF:AddToggle('AACamUp', { Text = 'Camera Lock Up', Default = false,
    Callback = function(v) State.aa.cameraLockUp = v end })
AaF:AddToggle('AACamBack', { Text = 'Camera Lock Backward', Default = false,
    Callback = function(v) State.aa.cameraLockBack = v end })
AaF:AddToggle('AACamSpin', { Text = 'Camera Spin', Default = false,
    Callback = function(v) State.aa.cameraSpin.active = v end })
AaF:AddSlider('AACamSpinSpeed', { Text = 'Camera Spin Speed (deg/s)', Default = 360, Min = 30, Max = 1440, Rounding = 0,
    Callback = function(v) State.aa.cameraSpin.speed = v end })

local AaG = Tabs['Anti-Aim']:AddRightGroupbox('Behavior')
AaG:AddToggle('AAAimAt', { Text = 'Always Face Nearest', Default = false,
    Callback = function(v) State.aa.aimBotLookingAt = v end })
AaG:AddToggle('AAAimAway', { Text = 'Always Face Away', Default = false,
    Callback = function(v) State.aa.aimBotFacingAway = v end })
AaG:AddToggle('AACrouchWalk', { Text = 'Crouch Walk', Default = false,
    Callback = function(v)
        State.aa.crouchWalk = v
        if not v then
            local _, c = alive()
            local h = c and c:FindFirstChildOfClass('Humanoid')
            if h then h.CameraOffset = Vector3.new(0, 0, 0) end
        end
    end })
AaG:AddToggle('AATwerkLoop', { Text = 'Twerk Loop', Default = false,
    Callback = function(v) State.aa.twerkLoop.active = v end })
AaG:AddSlider('AATwerkHz', { Text = 'Twerk Rate (Hz)', Default = 8, Min = 1, Max = 30, Rounding = 0,
    Callback = function(v) State.aa.twerkLoop.hz = v end })
AaG:AddToggle('AATiltIdle', { Text = 'Idle Tilt', Default = false,
    Callback = function(v) State.aa.tiltIdle.active = v end })
AaG:AddSlider('AATiltIdleAngle', { Text = 'Tilt Angle (deg)', Default = 15, Min = 3, Max = 90, Rounding = 0,
    Callback = function(v) State.aa.tiltIdle.angle = v end })
AaG:AddSlider('AATiltIdleHz', { Text = 'Tilt Rate (Hz)', Default = 1, Min = 0.2, Max = 5, Rounding = 1,
    Callback = function(v) State.aa.tiltIdle.hz = v end })

local AaH = Tabs['Anti-Aim']:AddRightGroupbox('Automation')
AaH:AddToggle('FillToggle', { Text = 'Rectangle Fill (underground)', Default = false,
    Callback = function(v)
        State.fill.active = v
        if not v and State.fill.running then
            State.fill.running = false
            pcall(function()
                local _, _, _, r = alive()
                if r then r.Anchored = false; r.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
            end)
            State.fill.anchored = false
        end
    end })
AaH:AddSlider('FillLength', { Text = 'Fill Length (studs)', Default = 50, Min = 10, Max = 200, Rounding = 0,
    Callback = function(v) State.fill.len = v end })
AaH:AddSlider('FillWidth', { Text = 'Fill Width (studs)', Default = 30, Min = 10, Max = 200, Rounding = 0,
    Callback = function(v) State.fill.wid = v end })
AaH:AddSlider('FillDepth', { Text = 'Dig Depth Below Floor', Default = 6, Min = 1, Max = 40, Rounding = 0,
    Callback = function(v) State.fill.depth = v end })
AaH:AddSlider('FillStep', { Text = 'Step Interval (s)', Default = 0.0002, Min = 0.00005, Max = 0.05, Rounding = 5,
    Callback = function(v) State.fill.step = v end })

-- ============================================================
-- UI SETTINGS
-- ============================================================
local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')
MenuGroup:AddButton('Unload', function()
    if BurgadaRivalsUnload then BurgadaRivalsUnload() end
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
    SaveManager:SetFolder('BurgadaLua/rivals-config')
    SaveManager:BuildConfigSection(Tabs['UI Settings'])
end

-- ============================================================
-- TICK HANDLERS
-- ============================================================
local orbitAngle = 0

local function hitboxTick()
    if not State.hitbox.active then return end
    local size = State.hitbox.size
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local r = p.Character:FindFirstChild('HumanoidRootPart')
            if r then
                if not State.hitbox.applied[r] then
                    State.hitbox.applied[r] = r.Size
                    r.CanCollide = false
                end
                r.Size = Vector3.new(size, size, size)
            end
        end
    end
    for part in pairs(State.hitbox.applied) do
        if not part.Parent then State.hitbox.applied[part] = nil end
    end
end

local function orbitTick(dt)
    if not State.orbit.active then return end
    local _, _, _, myRoot = alive()
    if not myRoot then return end
    local target = nearestRoot()
    if not target then return end
    orbitAngle = orbitAngle + State.orbit.speed * dt
    local r = State.orbit.radius
    local off = Vector3.new(math.cos(orbitAngle) * r, 2, math.sin(orbitAngle) * r)
    myRoot.CFrame = CFrame.new(target.Position + off, target.Position)
end

local function slingTick()
    if not State.sling.active then return end
    local _, _, _, myRoot = alive()
    if not myRoot then return end
    local target = nearestRoot()
    if not target then return end
    myRoot.CFrame = CFrame.new(target.Position + Vector3.new(0, State.sling.height, 0), target.Position)
end

local function voidHideTick()
    if not State.voidhide.active then return end
    local _, _, _, myRoot = alive()
    if not myRoot then return end
    if not State.voidhide.anchored then
        myRoot.Anchored = true
        myRoot.CFrame = CFrame.new(0, 99999, 0)
        State.voidhide.anchored = true
    end
end

local function voidspamTick(dt)
    if not State.voidspam.active then return end
    local _, _, _, myRoot = alive()
    if not myRoot then return end
    State.voidspam.acc = State.voidspam.acc + dt
    if State.voidspam.acc < State.voidspam.interval then return end
    State.voidspam.acc = 0
    local d = State.voidspam.dist
    myRoot.Anchored = true
    myRoot.CFrame = CFrame.new(math.random(-d, d), d, math.random(-d, d))
end

-- ============================================================
-- CONNECTIONS
-- ============================================================
RivalsConn = RunService.Heartbeat:Connect(function(dt)
    local ok = alive()
    if not ok then return end
    voidHideTick()
    voidspamTick(dt)
    if (State.voidhide.active and State.voidhide.anchored) or State.voidspam.active then return end
    fillTick(dt)
    if State.fill.active and State.fill.running then return end
    if State.sling.active then return end
    orbitTick(dt)
end)

RivalsHitbox = RunService.Heartbeat:Connect(hitboxTick)
RivalsAA = RunService.RenderStepped:Connect(antiAimTick)
RivalsRender = RunService.RenderStepped:Connect(function()
    slingTick()
    espTick()
end)
RivalsHud = RunService.Heartbeat:Connect(hudTick)

-- ============================================================
-- UNLOAD
-- ============================================================
function BurgadaRivalsUnload()
    if RivalsConn then RivalsConn:Disconnect() end
    if RivalsHitbox then RivalsHitbox:Disconnect() end
    if RivalsAA then RivalsAA:Disconnect() end
    if RivalsRender then RivalsRender:Disconnect() end
    if RivalsHud then RivalsHud:Disconnect() end

    unbindContact()
    if State.hud.gui then pcall(function() State.hud.gui:Destroy() end) end
    State.hud.gui = nil
    State.hud.frame = nil

    for part, orig in pairs(State.hitbox.applied) do
        pcall(function() part.Size = orig end)
    end
    State.hitbox.applied = {}

    if State.fill.running then fillStop() end

    if Drawing then
        for _, tbl in pairs(espParts) do
            for _, d in pairs(tbl) do pcall(function() d:Remove() end) end
        end
    end
    espParts = {}

    pcall(function()
        local _, c = alive()
        local h = c and c:FindFirstChildOfClass('Humanoid')
        if h then h.CameraOffset = Vector3.new(0, 0, 0) end
    end)
end

-- ============================================================
-- CONFIG
-- ============================================================
if SaveManager and SaveManager.LoadAutoloadConfig then
    local ok = pcall(function() SaveManager:LoadAutoloadConfig() end)
    if not ok then Library:Notify('Config load failed') end
end

Library:Notify('Burgada Lua | Rivals loaded')
