--[[
    Work at Pizza Place Auto Farm Script - Next Generation
    Clean, readable alternative to obfuscated version
    
    Features:
    - Auto pizza collection from delivery table
    - Bulk delivery system
    - Anti-AFK mechanism
    - Auto-restart on kick/death
    - Session stats tracking
    - Error handling
]]

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")

-- Player references
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local backpack = player.Backpack

-- Game locations
local pizzaPlace = Workspace:WaitForChild("Locations"):WaitForChild("PizzaPlace")
local deliveryTable = pizzaPlace:FindFirstChild("DeliveryTable")

-- Configuration
local config = {
    enabled = true,
    collectInterval = 0.1,  -- Time between box collections
    deliveryDelay = 0.5,    -- Delay before delivery teleport
    maxBoxes = 10,          -- Max boxes before delivery
    antiAFKEnabled = true
}

-- Stats tracking
local stats = {
    totalPizzas = 0,
    totalDeliveries = 0,
    sessionStart = os.time(),
    lastAction = os.time()
}

-- Status label (can be updated by UI)
local statusText = "Initializing..."

-- Helper: Check if object is a pizza box
local function IsPizzaBox(object)
    return object:IsA("Tool") and 
           (object.Name:lower():find("pizza") or 
            object.Name:lower():find("box") or
            object.Name:lower():find("order"))
end

-- Helper: Find all pizza boxes on delivery table
local function FindPizzasOnTable()
    if not deliveryTable then return {} end
    
    local boxes = {}
    for _, item in pairs(deliveryTable:GetDescendants()) do
        if IsPizzaBox(item) then
            table.insert(boxes, item)
        end
    end
    return boxes
end

-- Helper: Collect pizza boxes from table to backpack
local function CollectPizzas()
    local boxes = FindPizzasOnTable()
    local collected = 0
    
    for _, box in ipairs(boxes) do
        if box.Parent and box:FindFirstChild("Handle") then
            -- Move to backpack
            box.Parent = backpack
            collected = collected + 1
            stats.totalPizzas = stats.totalPizzas + 1
            wait(config.collectInterval)
        end
    end
    
    return collected
end

-- Helper: Count pizzas in backpack
local function CountPizzasInBackpack()
    local count = 0
    for _, item in pairs(backpack:GetChildren()) do
        if IsPizzaBox(item) then
            count = count + 1
        end
    end
    return count
end

-- Helper: Deliver pizzas to customer area
local function DeliverPizzas()
    local pizzaCount = CountPizzasInBackpack()
    if pizzaCount == 0 then return false end
    
    statusText = "Delivering " .. pizzaCount .. " pizzas..."
    
    -- Find delivery location (can be customized)
    local deliverySpot = pizzaPlace:FindFirstChild("CustomerArea") or
                        pizzaPlace:FindFirstChild("DeliveryZone")
    
    if deliverySpot then
        -- Teleport to delivery
        humanoidRootPart.CFrame = deliverySpot.CFrame + Vector3.new(0, 3, 0)
        wait(config.deliveryDelay)
        
        -- Drop all pizzas
        for _, item in pairs(backpack:GetChildren()) do
            if IsPizzaBox(item) then
                item.Parent = character
                wait(0.1)
                item.Parent = Workspace
            end
        end
        
        stats.totalDeliveries = stats.totalDeliveries + 1
        stats.lastAction = os.time()
        return true
    end
    
    return false
end

-- Anti-AFK system
local function SetupAntiAFK()
    if not config.antiAFKEnabled then return end
    
    player.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
        stats.lastAction = os.time()
    end)
end

-- Auto-restart on death/respawn
local function SetupAutoRestart()
    player.CharacterAdded:Connect(function(newChar)
        character = newChar
        humanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
        backpack = player.Backpack
        statusText = "Respawned - restarting..."
        wait(2)
    end)
end

-- Main farm loop
local function MainLoop()
    while config.enabled do
        wait(0.5)
        
        -- Check if we have room for more pizzas
        local currentPizzas = CountPizzasInBackpack()
        
        if currentPizzas >= config.maxBoxes then
            -- Deliver when full
            statusText = "Backpack full - delivering..."
            DeliverPizzas()
        else
            -- Collect more pizzas
            local collected = CollectPizzas()
            if collected > 0 then
                statusText = "Collected " .. collected .. " pizzas (Total: " .. currentPizzas .. ")"
                stats.lastAction = os.time()
            else
                statusText = "Waiting for pizzas... (Total: " .. currentPizzas .. ")"
            end
        end
        
        -- Auto-deliver periodically even if not full
        if currentPizzas > 0 and (os.time() - stats.lastAction) > 30 then
            statusText = "Auto-delivery triggered..."
            DeliverPizzas()
        end
    end
end

-- Get session stats
local function GetStats()
    local runtime = os.time() - stats.sessionStart
    local hours = math.floor(runtime / 3600)
    local minutes = math.floor((runtime % 3600) / 60)
    local seconds = runtime % 60
    
    return {
        pizzas = stats.totalPizzas,
        deliveries = stats.totalDeliveries,
        runtime = string.format("%02d:%02d:%02d", hours, minutes, seconds),
        status = statusText
    }
end

-- Start the farm
local function StartFarm()
    statusText = "Starting farm..."
    
    -- Setup systems
    SetupAntiAFK()
    SetupAutoRestart()
    
    -- Start main loop
    statusText = "Farm active!"
    spawn(MainLoop)
    
    print("=== Work at Pizza Place Auto Farm ===")
    print("Status: Active")
    print("Features: Auto-collect, Auto-deliver, Anti-AFK")
    print("=====================================")
end

-- Stop the farm
local function StopFarm()
    config.enabled = false
    statusText = "Farm stopped"
    print("Farm stopped")
end

-- Export functions for UI integration
return {
    Start = StartFarm,
    Stop = StopFarm,
    GetStats = GetStats,
    Config = config,
    Stats = stats
}

-- Auto-start if not being imported
if not getgenv then
    StartFarm()
end
