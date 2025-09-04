-- Copyright (c) 2025 SethNooby1. All Rights Reserved.
-- Proprietary software. No copying, redistribution, or use without purchase.
-- Access granted only via a valid paid license from the author.

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Track trade status and pet status
local tradeAccepted = false
local petStatus = {}

-- get information from configs
local config = getgenv().Configuration
if not config then
    error("Configuration not found! Please set getgenv().Configuration first.")
    return
end

local petToGive = config.petToGive
if not petToGive or #petToGive == 0 then
    error("No pets configured for trading! Please set Configuration.petToGive.")
    return
end

local targetUsername = config.targetUsername
if not targetUsername then
    error("No target username configured! Please set Configuration.targetUsername.")
    return
end

-- Clean up existing UI
local function cleanupExistingUI()
    for _, gui in pairs(game:GetService("CoreGui"):GetChildren()) do
        if gui.Name == "Auto Trade UI" then
            gui:Destroy()
        end
    end
end

cleanupExistingUI()

-- Create UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Auto Trade UI"
local MainFrame = Instance.new("Frame")
local StatusFrame = Instance.new("Frame")
local StatusText = Instance.new("TextLabel")
local PetListFrame = Instance.new("Frame")
local PetCountText = Instance.new("TextLabel")
local UICorner = Instance.new("UICorner")
local UICorner2 = Instance.new("UICorner")
local UICorner3 = Instance.new("UICorner")

-- Configure UI
ScreenGui.Parent = game.CoreGui

-- Main container
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 400, 0, 250)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -125)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui
UICorner.Parent = MainFrame

-- Status section
StatusFrame.Size = UDim2.new(1, -20, 0, 40)
StatusFrame.Position = UDim2.new(0, 10, 0, 10)
StatusFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
StatusFrame.BorderSizePixel = 0
StatusFrame.Parent = MainFrame
UICorner2.Parent = StatusFrame

StatusText.Size = UDim2.new(1, -20, 1, 0)
StatusText.Position = UDim2.new(0, 10, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.TextColor3 = Color3.fromRGB(255, 255, 255)
StatusText.TextSize = 16
StatusText.Font = Enum.Font.GothamSemibold
StatusText.Text = "Auto Trade Status"
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.Parent = StatusFrame

-- Pet list section
PetListFrame.Size = UDim2.new(1, -20, 1, -60)
PetListFrame.Position = UDim2.new(0, 10, 0, 60)
PetListFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
PetListFrame.BorderSizePixel = 0
PetListFrame.Parent = MainFrame
UICorner3.Parent = PetListFrame

PetCountText.Size = UDim2.new(1, -20, 1, -20)
PetCountText.Position = UDim2.new(0, 10, 0, 10)
PetCountText.BackgroundTransparency = 1
PetCountText.TextColor3 = Color3.fromRGB(255, 255, 255)
PetCountText.TextSize = 16
PetCountText.Font = Enum.Font.Gotham
PetCountText.Text = "Counting pets..."
PetCountText.TextXAlignment = Enum.TextXAlignment.Left
PetCountText.TextYAlignment = Enum.TextYAlignment.Top
PetCountText.Parent = PetListFrame

-- Function to update UI
local function updateStatus(text)
    if StatusText then
        StatusText.Text = text
    end
end

local function updatePetCount(petName, count)
    if not petStatus then
        petStatus = {}
    end

    if not petToGive then
        return
    end

    petStatus[petName] = count == 0 and "Completed" or tostring(count)

    -- Build status text for all pets
    local statusText = ""
    for _, name in ipairs(petToGive) do
        if name then
            local status = petStatus[name] or "Pending"
            statusText = statusText .. name .. ": " .. status .. "\n"
        end
    end

    if PetCountText then
        PetCountText.Text = statusText
    end
end

-- Helpers
local function baseName(str)
    local n = str:match("^([^[]+)")
    return n and n:match("^%s*(.-)%s*$") or str
end

local function unequipAllPets()
    local char = LocalPlayer.Character
    local backpack = LocalPlayer.Backpack
    if not char or not backpack then return end
    for _, itm in ipairs(char:GetChildren()) do
        if itm:IsA("Tool") then
            itm.Parent = backpack
        end
    end
end

-- Function to count available pets of a specific type
local function countPetsInBackpack(petName)
    local count = 0
    local backpack = LocalPlayer.Backpack
    local character = LocalPlayer.Character

    if not backpack or not character then return 0 end

    -- Count pets in backpack
    for _, pet in ipairs(backpack:GetChildren()) do
        local basePetName = baseName(pet.Name)
        if basePetName == petName then
            count = count + 1
        end
    end

    -- Count pets in character (equipped)
    for _, pet in ipairs(character:GetChildren()) do
        local basePetName = baseName(pet.Name)
        if basePetName == petName then
            count = count + 1
        end
    end

    return count
end

-- Initialize pet counts
local function initializePetCounts()
    if not petToGive then return end

    updateStatus("Initializing pet counts...")
    task.wait(1) -- Give time for everything to load

    for _, petName in ipairs(petToGive) do
        if petName then
            local count = countPetsInBackpack(petName)
            updatePetCount(petName, count)
        end
    end
end

-- Remote
local PetGiftingService = ReplicatedStorage.GameEvents.PetGiftingService
local Notification = ReplicatedStorage.GameEvents.Notification

-- Listen for trade completion
Notification.OnClientEvent:Connect(function(message)
    if message == "Trade completed!" then
        tradeAccepted = true
    end
end)

-- Equip function
local function equipPet(petName)
    local backpack = LocalPlayer.Backpack
    for _, pet in ipairs(backpack:GetChildren()) do
        local basePetName = baseName(pet.Name)
        if basePetName == petName then
            pet.Parent = LocalPlayer.Character
            task.wait(0.5)
            return true
        end
    end
    return false
end

-- trading function with confirmation and retry logic
local function tradePet(targetPlayer, petName)
    local maxAttempts = 3
    local currentAttempt = 1

    while currentAttempt <= maxAttempts do
        updateStatus(string.format("Trading %s (Attempt %d/%d)", petName, currentAttempt, maxAttempts))
        tradeAccepted = false

        -- Send trade request
        PetGiftingService:FireServer("GivePet", targetPlayer)

        -- Wait for trade acceptance
        local startTime = tick()
        local timeout = 5 -- 5 seconds timeout

        while (tick() - startTime) < timeout and not tradeAccepted do
            task.wait(0.5)
        end

        if tradeAccepted then
            return true
        end

        currentAttempt = currentAttempt + 1
        if currentAttempt <= maxAttempts then
            -- EXISTING COUNTDOWN FORMAT (kept the same)
            for i = 5, 1, -1 do
                updateStatus(string.format("Trade attempt %d failed. Retrying in %d seconds...", currentAttempt - 1, i))
                task.wait(1)
            end
        end
    end

    updateStatus(string.format("Failed to trade %s after %d attempts. Skipping...", petName, maxAttempts))
    return false
end

-- find player's username to trade for
updateStatus("Looking for target player...")
local foundPlayer = nil
while not foundPlayer do
    for i, player in ipairs(Players:GetPlayers()) do
        if player.Name == targetUsername then
            foundPlayer = player
            updateStatus("Found player: " .. targetUsername)
            break
        end
    end
    task.wait(1)
end

-- Initialize counts
initializePetCounts()

-- Function to check if any pets still need trading
local function checkRemainingPets()
    for _, petName in ipairs(petToGive) do
        local count = countPetsInBackpack(petName)
        if count > 0 then
            return true
        end
    end
    return false
end

-- Main continuous trading loop
while true do
    updateStatus("Starting Auto Trade Cycle")
    local anythingTraded = false

    for _, petName in ipairs(petToGive) do
        updateStatus("Processing: " .. petName)

        -- Ensure nothing is equipped before starting this pet (prevents multi-equip)
        unequipAllPets()

        -- Keep trading while we can find and equip more of this pet type
        while true do
            local petsLeft = countPetsInBackpack(petName)
            updatePetCount(petName, petsLeft)

            if petsLeft == 0 then
                updateStatus("No more " .. petName .. "s left to trade")
                break
            end

            if equipPet(petName) then
                local tradeSuccess = tradePet(foundPlayer, petName)

                if tradeSuccess then
                    anythingTraded = true
                    updateStatus("Successfully traded " .. petName)
                    task.wait(2) -- Cooldown between successful trades
                else
                    -- FIX: if attempt reached 3/3 (tradePet returned false), UNEQUIP EVERYTHING, then skip to next pet
                    unequipAllPets()
                    break
                end
            else
                updateStatus("Failed to equip " .. petName)
                task.wait(5)
                break
            end
        end
    end

    -- Check if we need to continue
    if not checkRemainingPets() then
        updateStatus("All pets have been successfully traded!")
        break
    end

    -- If nothing was traded in this cycle but pets remain, wait longer before retrying
    if not anythingTraded then
        -- MISSING COUNTDOWN PART: add live countdown using the SAME simple format
        for i = 10, 1, -1 do
            updateStatus(string.format("No trades succeeded this cycle. Retrying in %d seconds...", i))
            task.wait(1)
        end
    else
        -- MISSING COUNTDOWN PART: add live countdown using the SAME simple format
        for i = 3, 1, -1 do
            updateStatus(string.format("Some pets remain. Starting new trade cycle in %d seconds...", i))
            task.wait(1)
        end
    end
end

updateStatus("Trading process completed")
