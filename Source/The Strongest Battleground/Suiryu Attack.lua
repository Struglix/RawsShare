local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local Enabled = true
local AntiDeath = true

local ids = {
    ["18896229321"] = true,
    ["95575238948327"] = true
}

local busy = false

local switch = 0.31
local lockTime = 2
local voidTime = 2.5
local gap = 3

pcall(function()
    workspace.FallenPartsDestroyHeight = -50000
end)

local function AntiDeathFunc(char)
    local hum = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")

    if not hum or not hrp then
        return
    end

    local lastHP = hum.Health

    RunService.RenderStepped:Connect(function()
        if hum and hum.Parent then
            lastHP = hum.Health
        end
    end)

    hum:GetPropertyChangedSignal("Health"):Connect(function()
        if not Enabled or not AntiDeath then
            return
        end

        if hum.Health <= 0 and hrp.Parent and hrp.Position.Y <= 0 then
            hum.Health = lastHP
        end
    end)
end

if LocalPlayer.Character then
    task.spawn(AntiDeathFunc, LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait()
    AntiDeathFunc(char)
end)

local function root(c)
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function aliveHumanoid(c)
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getPlayers()
    local result = {}
    local seen = {}

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local char = p.Character
            local r = root(char)
            local h = aliveHumanoid(char)

            if r and h and h.Health > 0 then
                if not seen[char] then
                    seen[char] = true
                    result[#result + 1] = {
                        Player = p,
                        Character = char,
                        Root = r,
                        Humanoid = h
                    }
                end
            end
        end
    end

    local live = workspace:FindFirstChild("Live")

    if live then
        for _, char in ipairs(live:GetChildren()) do
            if char:IsA("Model") and char ~= LocalPlayer.Character then
                local r = root(char)
                local h = aliveHumanoid(char)

                if r and h and h.Health > 0 then
                    if not seen[char] then
                        seen[char] = true
                        result[#result + 1] = {
                            Player = Players:GetPlayerFromCharacter(char),
                            Character = char,
                            Root = r,
                            Humanoid = h
                        }
                    end
                end
            end
        end
    end

    return result
end

local function forceFace(r, targetRoot)
    if not r or not r.Parent or not targetRoot or not targetRoot.Parent then
        return
    end

    local pos = r.Position
    local targetPos = targetRoot.Position

    local lookPos = Vector3.new(
        targetPos.X,
        pos.Y,
        targetPos.Z
    )

    local direction = lookPos - pos

    if direction.Magnitude > 0.001 then
        r.CFrame = CFrame.lookAt(
            pos,
            lookPos
        )
    end
end

local virtualFloor = Instance.new("Part")
virtualFloor.Name = "TSB_VirtualVoidFloor"
virtualFloor.Size = Vector3.new(10000, 1, 10000)
virtualFloor.Position = Vector3.new(0, -504, 0)
virtualFloor.Anchored = true
virtualFloor.CanCollide = true
virtualFloor.CanTouch = true
virtualFloor.CanQuery = true
virtualFloor.Transparency = 1
virtualFloor.Parent = workspace

local function run(c)
    if not Enabled then
        return
    end

    if busy then
        return
    end

    local r = root(c)
    local hum = aliveHumanoid(c)

    if not r or not hum then
        return
    end

    busy = true

    local old = r.CFrame
    local oldAutoRotate = hum.AutoRotate

    local started = os.clock()
    local last = 0
    local index = 0
    local target

    hum.AutoRotate = false

    local con

    con = RunService.Heartbeat:Connect(function()
        if not Enabled then
            if con then
                con:Disconnect()
            end

            busy = false

            if r.Parent then
                r.CFrame = old
            end

            if hum.Parent then
                hum.AutoRotate = oldAutoRotate
            end

            return
        end

        if not r.Parent or not hum.Parent then
            if con then
                con:Disconnect()
            end
            busy = false
            return
        end

        hum.AutoRotate = false

        local time = os.clock() - started

        if not target or time - last >= switch then
            last = time

            local list = getPlayers()

            if #list > 0 then
                index = index % #list + 1
                target = list[index]
            else
                target = nil
            end
        end

        if time < lockTime then
            local tr

            if target then
                tr = target.Root

                if not tr or not tr.Parent then
                    tr = root(target.Character)
                    target.Root = tr
                end
            end

            if tr then
                local d = tr.Position - r.Position

                if d.Magnitude > 0 then
                    local targetPos = tr.Position - d.Unit * gap

                    r.CFrame = CFrame.lookAt(
                        targetPos,
                        Vector3.new(
                            tr.Position.X,
                            targetPos.Y,
                            tr.Position.Z
                        )
                    )

                    forceFace(r, tr)
                end
            end

        else
            con:Disconnect()

            if r.Parent then
                task.spawn(function()
                    if target and target.Root and target.Root.Parent then
                        local targetPos = target.Root.Position
                        r.CFrame = CFrame.new(targetPos.X, -502.5, targetPos.Z)
                    else
                        r.CFrame = CFrame.new(old.X, -502.5, old.Z)
                    end

                    task.wait(voidTime)

                    if r.Parent and Enabled then
                        r.CFrame = old
                    end
                end)
            end

            if hum.Parent then
                hum.AutoRotate = oldAutoRotate
            end

            busy = false
        end
    end)
end

local function setup(c)
    local h = c:WaitForChild("Humanoid", 5)

    if not h then
        return
    end

    h.AnimationPlayed:Connect(function(track)
        if not Enabled then
            return
        end

        local a = track.Animation
        local id = a and a.AnimationId:match("%d+")

        if id and ids[id] then
            run(c)
        end
    end)
end

if LocalPlayer.Character then
    task.spawn(setup, LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(c)
    task.spawn(setup, c)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "GameControllerUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "Main"
frame.Size = UDim2.fromOffset(180, 72)
frame.Position = UDim2.new(0, 20, 0.5, -36)
frame.BackgroundColor3 = Color3.fromRGB(27, 27, 31)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 7)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(75, 75, 82)
stroke.Thickness = 1
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -20, 0, 27)
title.Position = UDim2.fromOffset(10, 5)
title.BackgroundTransparency = 1
title.Text = "Suiryu Attack All"
title.TextColor3 = Color3.fromRGB(235, 235, 235)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local toggle = Instance.new("TextButton")
toggle.Name = "Toggle"
toggle.Size = UDim2.new(1, -20, 0, 29)
toggle.Position = UDim2.fromOffset(10, 36)
toggle.BorderSizePixel = 0
toggle.AutoButtonColor = false
toggle.TextSize = 13
toggle.Font = Enum.Font.GothamBold
toggle.Parent = frame

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 5)
toggleCorner.Parent = toggle

local function updateUI()
    if Enabled then
        toggle.Text = "[ ON ]"
        toggle.BackgroundColor3 = Color3.fromRGB(45, 105, 62)
    else
        toggle.Text = "[ OFF ]"
        toggle.BackgroundColor3 = Color3.fromRGB(105, 45, 45)
    end
end

updateUI()

toggle.MouseButton1Click:Connect(function()
    Enabled = not Enabled
    AntiDeath = Enabled

    updateUI()

    if not Enabled then
        busy = false
    end
end)

local dragging = false
local dragStart
local startPos

local function updateDrag(input)
    local delta = input.Position - dragStart

    frame.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,

        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end

frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPos = frame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UIS.InputChanged:Connect(function(input)
    if not dragging then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then

        updateDrag(input)
    end
end)
