-- language: Lua (Roblox Luau), file: burgada_loader.lua
-- executor: Delta Android (also PC)
-- paste after attaching. standalone.
-- loads Rivals.lua or Stabbed.lua from the same repo by loadstring.

-- ============================================================
-- PRE-FLIGHT CLEANUP
-- ============================================================
pcall(function()
    if _G.BurgadaActiveConn and _G.BurgadaActiveConn.Disconnect then
        _G.BurgadaActiveConn:Disconnect()
    end
    if _G.BurgadaActiveUnload then pcall(_G.BurgadaActiveUnload) end
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
-- URLS
-- ============================================================
local REPO_BASE = 'https://raw.githubusercontent.com/givemeaprobro-cmd/Burgada-lua-load-stabbed-lua/refs/heads/main/'
local URLS = {
    Rivals  = REPO_BASE .. 'Rivals.lua',
    Stabbed = REPO_BASE .. 'Stabbed.lua',
}

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

Library.ShowToggleFrameInKeybinds = true
Library.ShowCustomCursor          = false
Library.NotifySide                = 'Left'

-- ============================================================
-- WINDOW
-- ============================================================
local Window = Library:CreateWindow({
    Title                = 'Burgada Lua',
    Center               = true,
    AutoShow             = true,
    Resizable            = false,
    ShowCustomCursor     = false,
    UnlockMouseWhileOpen = false,
    NotifySide           = 'Left',
    TabPadding           = 8,
    MenuFadeTime         = 0.2,
})

local SelectTab = Window:AddTab('Select')
local GameGroup = SelectTab:AddLeftGroupbox('Game')

-- ============================================================
-- LOADER — fetch the target file, loadstring it, run it
-- ============================================================
local function loadTarget(name)
    local url = URLS[name]
    if not url then
        Library:Notify('Unknown target: ' .. tostring(name))
        return
    end

    Library:Notify('Loading ' .. name .. '...')

    local src = tryFetch(url)
    if not src or #src == 0 then
        Library:Notify('Failed to fetch ' .. name .. '.lua — check the repo path')
        warn('[Burgada] fetch failed for', url)
        return
    end

    -- sanity check: raw HTML would start with '<'
    local firstChar = src:sub(1, 1)
    if firstChar == '<' then
        Library:Notify(name .. ' URL returned HTML — use a raw URL, not a blob URL')
        warn('[Burgada] HTML returned from', url, 'len', #src)
        return
    end

    local chunk, err = loadstring(src)
    if not chunk then
        Library:Notify('Parse error in ' .. name .. ': ' .. tostring(err))
        warn('[Burgada] loadstring failed for', url, err)
        return
    end

    -- unload the selector first so the target's window replaces it cleanly
    Library:Unload()

    local ok, runErr = pcall(chunk)
    if not ok then
        warn('[Burgada] runtime error in', name, runErr)
    end
end

GameGroup:AddButton('Rivals', function()
    loadTarget('Rivals')
end)

GameGroup:AddButton('Stabbed', function()
    loadTarget('Stabbed')
end)

-- ============================================================
-- INFO
-- ============================================================
local InfoGroup = SelectTab:AddRightGroupbox('Info')
InfoGroup:AddLabel('Rivals  ->  combat, visuals, movement, anti-aim')
InfoGroup:AddLabel('Stabbed ->  rage backstab loop')
InfoGroup:AddLabel('')
InfoGroup:AddLabel('Loading replaces this window with the selected suite.')
InfoGroup:AddLabel('Re-run the loader to switch games.')

-- ============================================================
-- READY
-- ============================================================
Library:Notify('Burgada Loader ready — pick Rivals or Stabbed')
