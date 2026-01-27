-- services
local VIM    = game:GetService("VirtualInputManager")
local UIS    = game:GetService("UserInputService")
local TS     = game:GetService("TweenService")
local CG     = game:GetService("CoreGui")
local RS     = game:GetService("RunService")
local Stats  = game:GetService("Stats")
local TP     = game:GetService("TeleportService")
local Http   = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- config
local visible = true
local minimized = false
local INTERVAL = 480 -- 8 minutos
local PLACE_ID = game.PlaceId
local CURRENT_JOB = game.JobId
local FPS_ALPHA  = 0.15
local PING_ALPHA = 0.20
local MIN_FILL = 0.5
local MAX_FILL = 0.9
local MAX_PAGES = 5

-- ================= SAVE LAST MODE =================
local lastModeFolder = Workspace:FindFirstChild("Anti AFK - Hopper") or Instance.new("Folder", Workspace)
lastModeFolder.Name = "Anti AFK - Hopper"

local lastModeValue = lastModeFolder:FindFirstChild("LastMode") or Instance.new("StringValue", lastModeFolder)
lastModeValue.Name = "LastMode"
if lastModeValue.Value == "" then
    lastModeValue.Value = "Normal"
end

local serverMode = lastModeValue.Value -- Normal ou Low

-- ================= GUI =================
local gui = Instance.new("ScreenGui")
gui.ResetOnSpawn = false
pcall(function() gui.Parent = gethui() end)
if not gui.Parent then gui.Parent = CG end

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0,260,0,140)
frame.Position = UDim2.new(0,40,0.4,0)
frame.BackgroundColor3 = Color3.fromRGB(32,32,32)
frame.BackgroundTransparency = 0.35
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)
Instance.new("UIStroke", frame).Color = Color3.new(0,0,0)

local header = Instance.new("Frame", frame)
header.Size = UDim2.new(1,0,0,32)
header.BackgroundColor3 = Color3.fromRGB(18,18,18)
Instance.new("UICorner", header).CornerRadius = UDim.new(0,8)

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(1,-60,1,0)
title.Position = UDim2.new(0,10,0,0)
title.BackgroundTransparency = 1
title.Text = "Anti AFK"
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(240,240,240)
title.TextXAlignment = Enum.TextXAlignment.Left

-- indicator
local indicator = Instance.new("Frame", header)
indicator.Size = UDim2.new(0,10,0,10)
indicator.Position = UDim2.new(1,-20,0.5,-5)
indicator.BackgroundColor3 = Color3.fromRGB(80,200,120)
Instance.new("UICorner", indicator).CornerRadius = UDim.new(1,0)
local pulse = TS:Create(indicator, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Size = UDim2.new(0,12,0,12)})
pulse:Play()

-- minimize button
local minBtn = Instance.new("TextButton", header)
minBtn.Size = UDim2.new(0,24,0,24)
minBtn.Position = UDim2.new(1,-44,0.5,-12)
minBtn.Text = "–"
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 18
minBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
minBtn.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(1,0)

-- drag
do
    local d, ds, sp
    header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            d = true; ds = i.Position; sp = frame.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if d and i.UserInputType == Enum.UserInputType.MouseMovement then
            local dx = i.Position - ds
            frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + dx.X, sp.Y.Scale, sp.Y.Offset + dx.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then d = false end
    end)
end

local body = Instance.new("Frame", frame)
body.Position = UDim2.new(0,0,0,32)
body.Size = UDim2.new(1,0,1,-32)
body.BackgroundTransparency = 1

-- ================= SERVER HOP MODE BUTTON =================
local modeBtn = Instance.new("TextButton", body)
modeBtn.Size = UDim2.new(1,-24,0,28)
modeBtn.Position = UDim2.new(0,12,0,16)
modeBtn.Text = "Mode: "..serverMode
modeBtn.Font = Enum.Font.GothamBold
modeBtn.TextSize = 14
modeBtn.TextColor3 = Color3.new(1,1,1)
modeBtn.BackgroundColor3 = Color3.fromRGB(150,150,150)
Instance.new("UICorner", modeBtn).CornerRadius = UDim.new(0,6)

modeBtn.MouseButton1Click:Connect(function()
    if serverMode == "Normal" then
        serverMode = "Low"
    else
        serverMode = "Normal"
    end
    lastModeValue.Value = serverMode
    modeBtn.Text = "Mode: "..serverMode
end)

-- ================= SERVER HOP BUTTON =================
local hopBtn = Instance.new("TextButton", body)
hopBtn.Size = UDim2.new(1,-24,0,36)
hopBtn.Position = UDim2.new(0,12,0,52)
hopBtn.Text = "SERVER HOP"
hopBtn.Font = Enum.Font.GothamBold
hopBtn.TextSize = 15
hopBtn.TextColor3 = Color3.new(1,1,1)
hopBtn.BackgroundColor3 = Color3.fromRGB(70,130,180)
Instance.new("UICorner", hopBtn).CornerRadius = UDim.new(0,6)

-- ================= SERVER HOP FUNC =================
local function getServers(cursor, sortAsc)
    local url = "https://games.roblox.com/v1/games/"..PLACE_ID.."/servers/Public?sortOrder="..(sortAsc and "Asc" or "Desc").."&limit=50"
    if cursor then url ..= "&cursor="..cursor end
    local res = game:HttpGet(url)
    return Http:JSONDecode(res)
end

local function serverHop()
    local tried = {}
    while true do
        local candidates = {}
        local fallback = {}

        local sortAsc = serverMode == "Low"
        local cursor = ""
        for page = 1, MAX_PAGES do
            local success, data = pcall(getServers, cursor, sortAsc)
            if not success or not data or not data.data then break end

            for _,srv in ipairs(data.data) do
                if srv.id ~= CURRENT_JOB and not tried[srv.id] then
                    if serverMode == "Normal" then
                        local fill = srv.playing / srv.maxPlayers
                        if fill >= MIN_FILL and fill <= MAX_FILL then
                            table.insert(candidates, srv.id)
                        else
                            table.insert(fallback, srv.id)
                        end
                    elseif serverMode == "Low" then
                        table.insert(candidates, {id = srv.id, players = srv.playing})
                    end
                end
            end

            if not data.nextPageCursor then break end
            cursor = data.nextPageCursor
        end

        local target = nil
        if serverMode == "Low" and #candidates > 0 then
            table.sort(candidates, function(a,b) return a.players < b.players end)
            target = candidates[1].id
        elseif #candidates > 0 then
            target = candidates[math.random(1,#candidates)]
        elseif #fallback > 0 then
            target = fallback[math.random(1,#fallback)]
        else
            warn("nenhum servidor encontrado")
            return
        end

        tried[target] = true
        TP:TeleportToPlaceInstance(PLACE_ID, target, Players.LocalPlayer)
        return
    end
end

hopBtn.MouseButton1Click:Connect(serverHop)

-- ================= MINIMIZE FIX =================
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    if minimized then
        frame.Size = UDim2.new(0,260,0,32)
        minBtn.Text = "+"
    else
        frame.Size = UDim2.new(0,260,0,140)
        minBtn.Text = "–"
    end
end)

-- ================= INSERT =================
do
    local t
    UIS.InputBegan:Connect(function(i,gp)
        if gp or i.KeyCode ~= Enum.KeyCode.Insert then return end
        t = tick()
    end)
    UIS.InputEnded:Connect(function(i)
        if i.KeyCode ~= Enum.KeyCode.Insert or not t then return end
        if tick()-t<5 then
            visible = not visible
            gui.Enabled = visible
        end
        t=nil
    end)
    task.spawn(function()
        while true do
            if t and tick()-t>=5 then
                gui:Destroy()
                return
            end
            task.wait(0.1)
        end
    end)
end

-- ================= FPS + PING =================
do
    local frames,last = 0,tick()
    local fpsAvg, pingAvg
    RS.RenderStepped:Connect(function() frames += 1 end)

    task.spawn(function()
        while gui.Parent do
            local now = tick()
            local fpsRaw = frames/(now-last)
            frames=0
            last=now

            fpsAvg = fpsAvg and (fpsAvg+(fpsRaw-fpsAvg)*FPS_ALPHA) or fpsRaw

            local pingRaw = 0
            pcall(function() pingRaw = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
            pingAvg = pingAvg and (pingAvg+(pingRaw-pingAvg)*PING_ALPHA) or pingRaw

            title.Text = string.format("Anti AFK - %d FPS - %d ms", math.floor(fpsAvg+0.5), math.floor(pingAvg+0.5))
            task.wait(0.1)
        end
    end)
end

-- ================= ANTI AFK =================
task.spawn(function()
    while true do
        VIM:SendKeyEvent(true, Enum.KeyCode.Space,false,game)
        task.wait(0.15)
        VIM:SendKeyEvent(false, Enum.KeyCode.Space,false,game)
        task.wait(0.2)
        for _,k in ipairs({Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D}) do
            VIM:SendKeyEvent(true,k,false,game)
            task.wait(0.08)
            VIM:SendKeyEvent(false,k,false,game)
        end
        task.wait(INTERVAL)
    end
end)
