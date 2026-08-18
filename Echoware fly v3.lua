local player = game.Players.LocalPlayer
local flying = false
local speed = 80
local minimized = false

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local sg = Instance.new("ScreenGui")
sg.Name = "Echoware fly v3"
sg.ResetOnSpawn = false
sg.Parent = player:WaitForChild("PlayerGui")

-- Smaller, cleaner frame
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 120)
frame.Position = UDim2.new(0.5, -100, 0.12, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
frame.Active = true
frame.Draggable = true
frame.Parent = sg

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 0, 26)
title.Position = UDim2.new(0, 10, 0, 5)
title.BackgroundTransparency = 1
title.Text = "Echoware fly v3"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 24, 0, 24)
minimizeBtn.Position = UDim2.new(1, -56, 0, 6)
minimizeBtn.BackgroundTransparency = 1
minimizeBtn.Text = "–"
minimizeBtn.TextSize = 20
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextColor3 = Color3.new(1, 1, 1)
minimizeBtn.Parent = frame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -30, 0, 6)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "×"
closeBtn.TextSize = 22
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Parent = frame

-- Main toggle button with static accent color
local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(0.9, 0, 0, 36)
toggle.Position = UDim2.new(0.05, 0, 0, 38)
toggle.Text = "fly"
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.BackgroundColor3 = Color3.fromRGB(45, 90, 160)
toggle.TextSize = 16
toggle.Font = Enum.Font.GothamBold
toggle.Parent = frame
Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 8)

local minus10 = Instance.new("TextButton")
minus10.Size = UDim2.new(0, 45, 0, 30)
minus10.Position = UDim2.new(0.05, 0, 0, 82)
minus10.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
minus10.Text = "-10"
minus10.TextColor3 = Color3.new(1, 1, 1)
minus10.TextSize = 13
minus10.Font = Enum.Font.GothamBold
minus10.Parent = frame
Instance.new("UICorner", minus10).CornerRadius = UDim.new(0, 6)

local speedBox = Instance.new("TextBox")
speedBox.Size = UDim2.new(0, 60, 0, 30)
speedBox.Position = UDim2.new(0.5, -30, 0, 82)
speedBox.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
speedBox.Text = "80"
speedBox.TextColor3 = Color3.new(1, 1, 1)
speedBox.TextSize = 15
speedBox.Font = Enum.Font.GothamBold
speedBox.Parent = frame
Instance.new("UICorner", speedBox).CornerRadius = UDim.new(0, 6)

local plus10 = Instance.new("TextButton")
plus10.Size = UDim2.new(0, 45, 0, 30)
plus10.Position = UDim2.new(0.72, 0, 0, 82)
plus10.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
plus10.Text = "+10"
plus10.TextColor3 = Color3.new(1, 1, 1)
plus10.TextSize = 13
plus10.Font = Enum.Font.GothamBold
plus10.Parent = frame
Instance.new("UICorner", plus10).CornerRadius = UDim.new(0, 6)

local bv, bg = nil, nil

local function tweenSize(newSize)
    TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Size = newSize}):Play()
end

local function startFly()
    if flying then return end
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not root or not hum then return end

    flying = true
    hum.PlatformStand = true

    bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(99999, 99999, 99999)
    bv.Velocity = Vector3.new(0,0,0)
    bv.Parent = root

    bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(99999, 99999, 99999)
    bg.P = 12500
    bg.Parent = root

    toggle.Text = "stop"
    toggle.BackgroundColor3 = Color3.fromRGB(160, 45, 45) -- red when active
end

local function stopFly()
    flying = false
    if bv then bv:Destroy() end
    if bg then bg:Destroy() end
    local hum = player.Character and player.Character:FindFirstChild("Humanoid")
    if hum then hum.PlatformStand = false end
    toggle.Text = "fly"
    toggle.BackgroundColor3 = Color3.fromRGB(45, 90, 160) -- blue when inactive
end

toggle.MouseButton1Click:Connect(function()
    if flying then stopFly() else startFly() end
end)

minus10.MouseButton1Click:Connect(function()
    speed = math.max(10, speed - 10)
    speedBox.Text = tostring(speed)
end)

plus10.MouseButton1Click:Connect(function()
    speed = speed + 10
    speedBox.Text = tostring(speed)
end)

speedBox.FocusLost:Connect(function()
    local val = tonumber(speedBox.Text)
    if val then speed = val else speedBox.Text = tostring(speed) end
end)

minimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        toggle.Visible = false
        minus10.Visible = false
        speedBox.Visible = false
        plus10.Visible = false
        minimizeBtn.Text = "+"
        tweenSize(UDim2.new(0, 200, 0, 42))
    else
        minimizeBtn.Text = "–"
        tweenSize(UDim2.new(0, 200, 0, 120))
        task.wait(0.2)
        toggle.Visible = true
        minus10.Visible = true
        speedBox.Visible = true
        plus10.Visible = true
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    stopFly()
    frame.Visible = false

    local thank = Instance.new("TextLabel", sg)
    thank.Size = UDim2.new(0.9, 0, 0, 80)
    thank.Position = UDim2.new(0.05, 0, 0.4, 0)
    thank.BackgroundTransparency = 1
    thank.Text = "Echoware fly v3"
    thank.TextColor3 = Color3.new(1, 1, 1)
    thank.TextSize = 24
    thank.Font = Enum.Font.GothamBold
    thank.TextWrapped = true

    task.wait(2)
    sg:Destroy()
end)

local function getJoystickVector()
    local success, result = pcall(function()
        local pm = player.PlayerScripts:FindFirstChild("PlayerModule")
        if pm then
            local cm = pm:FindFirstChild("ControlModule")
            if cm then return require(cm):GetMoveVector() end
        end
        return Vector3.new(0,0,0)
    end)
    return success and result or Vector3.new(0,0,0)
end

RunService.RenderStepped:Connect(function()
    if not flying or not bv then return end
    local cam = workspace.CurrentCamera
    local move = getJoystickVector()
    local vertical = 0
    local uis = game:GetService("UserInputService")
    
    if uis:IsKeyDown(Enum.KeyCode.Space) then vertical = 1 end
    if uis:IsKeyDown(Enum.KeyCode.LeftControl) then vertical = -1 end

    local finalDir = Vector3.new(move.X, vertical, move.Z)
    if finalDir.Magnitude > 0 then
        bv.Velocity = cam.CFrame:VectorToWorldSpace(finalDir.Unit) * speed
    else
        bv.Velocity = Vector3.new(0,0,0)
    end
    if bg then bg.CFrame = cam.CFrame end
end)
