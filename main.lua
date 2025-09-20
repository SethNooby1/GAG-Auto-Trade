-- ========================================
-- Pro Grow A Garden Auto Trade by DuckyHub
-- ========================================

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- State
local tradeAccepted = false
local petStatus = {}
local favoriteBlocked = false
local notHoldingTool = false

-- Config
local config = getgenv().Configuration
if not config then error("Configuration not found! Please set getgenv().Configuration first.") return end

local petToGive = config.petToGive
local tradeWholeInventory = config.tradeWholeInventory or false

if not tradeWholeInventory then
    if not petToGive or #petToGive == 0 then error("No pets configured for trading! Please set Configuration.petToGive or enable tradeWholeInventory.") return end
end

local targetUsername = config.targetUsername
if not targetUsername then error("No target username configured! Please set Configuration.targetUsername.") return end

local whiteScreen = config.whiteScreen or false
local leaveWhenDone = config.leaveWhenDone ~= false -- default to true if not specified

-- Check if current player is the receiver
local isReceiver = (LocalPlayer.Name == targetUsername)
if isReceiver then
    print("Auto-Receiver mode activated for player: " .. LocalPlayer.Name)
end

-- =========================================================
-- UI (Improved + Bigger)
-- =========================================================
-- Cleanup
for _, gui in pairs(game:GetService("CoreGui"):GetChildren()) do
	if gui.Name == "Auto Trade UI" or gui.Name == "Auto Trade White Screen" then
		gui:Destroy()
	end
end

-- White Screen UI
local whiteScreenEnabled = whiteScreen
local whiteScreenGui, whiteScreenText, normalUI

local function createWhiteScreen()
    whiteScreenGui = Instance.new("ScreenGui")
    whiteScreenGui.Name = "Auto Trade White Screen"
    whiteScreenGui.IgnoreGuiInset = true
    whiteScreenGui.ResetOnSpawn = false
    whiteScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    whiteScreenGui.Parent = game.CoreGui
    
    -- White background
    local whiteFrame = Instance.new("Frame")
    whiteFrame.Size = UDim2.new(1, 0, 1, 0)
    whiteFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    whiteFrame.BorderSizePixel = 0
    whiteFrame.Parent = whiteScreenGui
    
    -- Status text
    whiteScreenText = Instance.new("TextLabel")
    whiteScreenText.Size = UDim2.new(0, 400, 0, 100)
    whiteScreenText.Position = UDim2.new(0.5, -200, 0.5, -50)
    whiteScreenText.BackgroundTransparency = 1
    whiteScreenText.Text = "Auto Trade - Loading..."
    whiteScreenText.TextColor3 = Color3.fromRGB(50, 50, 50)
    whiteScreenText.TextXAlignment = Enum.TextXAlignment.Center
    whiteScreenText.TextYAlignment = Enum.TextYAlignment.Center
    whiteScreenText.Font = Enum.Font.GothamSemibold
    whiteScreenText.TextSize = 24
    whiteScreenText.TextWrapped = true
    whiteScreenText.Parent = whiteScreenGui
    
    -- Toggle button (positioned same as normal mode buttons)
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.fromOffset(60, 30)
    -- Position it at the same location as the normal mode buttons - top right of where UI would be
    toggleBtn.Position = UDim2.new(0.5, 320 - 60, 0.5, -230 - 40)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    toggleBtn.Text = "UI"
    toggleBtn.TextColor3 = Color3.fromRGB(50, 50, 50)
    toggleBtn.Font = Enum.Font.Gotham
    toggleBtn.TextSize = 16
    toggleBtn.Parent = whiteScreenGui
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)
    
    toggleBtn.MouseButton1Click:Connect(function()
        whiteScreenEnabled = not whiteScreenEnabled
        updateUIVisibility()
    end)
end

-- Root
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Auto Trade UI"
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game.CoreGui

-- Main
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.fromOffset(640, 460) -- Bigger
MainFrame.Position = UDim2.new(0.5, -320, 0.5, -230)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner", MainFrame)
MainCorner.CornerRadius = UDim.new(0, 16)
local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Thickness = 2
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
MainStroke.Color = Color3.fromRGB(70, 70, 70)

-- Top Bar
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 56)
TopBar.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 16)

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, -24, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = isReceiver and "Ducky Hub • GAG Auto Trade (RECEIVER MODE)" or "Ducky Hub • GAG Auto Trade"
Title.TextColor3 = isReceiver and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 255, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamSemibold
Title.TextSize = 22
Title.Parent = TopBar

-- Info Strip (no collision; auto height)
local INFO_H = 132
local InfoStrip = Instance.new("Frame")
InfoStrip.Name = "InfoStrip"
InfoStrip.Size = UDim2.new(1, -24, 0, INFO_H)
InfoStrip.Position = UDim2.new(0, 12, 0, 68)
InfoStrip.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
InfoStrip.BorderSizePixel = 0
InfoStrip.Parent = MainFrame
Instance.new("UICorner", InfoStrip).CornerRadius = UDim.new(0, 12)

local InfoPadding = Instance.new("UIPadding", InfoStrip)
InfoPadding.PaddingTop = UDim.new(0, 10)
InfoPadding.PaddingBottom = UDim.new(0, 10)
InfoPadding.PaddingLeft  = UDim.new(0, 12)
InfoPadding.PaddingRight = UDim.new(0, 12)

local InfoLayout = Instance.new("UIListLayout", InfoStrip)
InfoLayout.FillDirection = Enum.FillDirection.Vertical
InfoLayout.SortOrder = Enum.SortOrder.LayoutOrder
InfoLayout.Padding = UDim.new(0, 6)

local function mkInfoLabel(parent, font, size, color)
    local L = Instance.new("TextLabel")
    L.BackgroundTransparency = 1
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.Font = font
    L.TextSize = size
    L.TextColor3 = color
    L.TextWrapped = true
    L.AutomaticSize = Enum.AutomaticSize.Y
    L.Size = UDim2.new(1, 0, 0, 0)
    L.Parent = parent
    return L
end

local TargetText    = mkInfoLabel(InfoStrip, Enum.Font.Gotham,        18, Color3.fromRGB(220,220,220)); TargetText.Text = "Target: " .. targetUsername
local StatusTextLbl = mkInfoLabel(InfoStrip, Enum.Font.GothamSemibold,18, Color3.fromRGB(255,255,255));  StatusTextLbl.Text = "Status: Idle"
local AttemptText   = mkInfoLabel(InfoStrip, Enum.Font.Gotham,        17, Color3.fromRGB(210,210,210));  AttemptText.Text = "Attempt: -"
local CountdownText = mkInfoLabel(InfoStrip, Enum.Font.Gotham,        17, Color3.fromRGB(200,200,200));  CountdownText.Text = "Countdown: -"

-- Bottom Area
local BottomRow = Instance.new("Frame")
BottomRow.Name = "BottomRow"
BottomRow.Size = UDim2.new(1, -24, 1, - (68 + INFO_H + 22))
BottomRow.Position = UDim2.new(0, 12, 0, 68 + INFO_H + 14)
BottomRow.BackgroundTransparency = 1
BottomRow.Parent = MainFrame
local BottomLayout = Instance.new("UIListLayout", BottomRow)
BottomLayout.FillDirection = Enum.FillDirection.Horizontal
BottomLayout.Padding = UDim.new(0, 12)

-- Left: Pet list (scroll)
local PetPanel = Instance.new("Frame")
PetPanel.Name = "PetPanel"
PetPanel.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
PetPanel.BorderSizePixel = 0
PetPanel.Size = UDim2.new(0.6, 0, 1, 0)
PetPanel.Parent = BottomRow
Instance.new("UICorner", PetPanel).CornerRadius = UDim.new(0, 12)

local PetHeader = Instance.new("TextLabel")
PetHeader.Text = "Pet Queue"
PetHeader.Font = Enum.Font.GothamSemibold
PetHeader.TextSize = 18
PetHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
PetHeader.BackgroundTransparency = 1
PetHeader.Size = UDim2.new(1, -16, 0, 28)
PetHeader.Position = UDim2.new(0, 8, 0, 6)
PetHeader.TextXAlignment = Enum.TextXAlignment.Left
PetHeader.Parent = PetPanel

local PetList = Instance.new("ScrollingFrame")
PetList.Name = "PetList"
PetList.Size = UDim2.new(1, -16, 1, - (28 + 16))
PetList.Position = UDim2.new(0, 8, 0, 28 + 10)
PetList.BackgroundTransparency = 1
PetList.ScrollBarThickness = 6
PetList.CanvasSize = UDim2.new(0, 0, 0, 0)
PetList.Parent = PetPanel

local PetListLayout = Instance.new("UIListLayout", PetList)
PetListLayout.FillDirection = Enum.FillDirection.Vertical
PetListLayout.Padding = UDim.new(0, 6)
PetListLayout.SortOrder = Enum.SortOrder.LayoutOrder
local PetListPadding = Instance.new("UIPadding", PetList)
PetListPadding.PaddingTop = UDim.new(0, 4)
PetListPadding.PaddingLeft = UDim.new(0, 2)
PetListPadding.PaddingRight = UDim.new(0, 8)
PetListPadding.PaddingBottom = UDim.new(0, 8)

-- Right: Notes
local LogPanel = Instance.new("Frame")
LogPanel.Name = "LogPanel"
LogPanel.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
LogPanel.BorderSizePixel = 0
LogPanel.Size = UDim2.new(0.4, 0, 1, 0)
LogPanel.Parent = BottomRow
Instance.new("UICorner", LogPanel).CornerRadius = UDim.new(0, 12)

local LogHeader = Instance.new("TextLabel")
LogHeader.Text = "Notes"
LogHeader.Font = Enum.Font.GothamSemibold
LogHeader.TextSize = 18
LogHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
LogHeader.BackgroundTransparency = 1
LogHeader.Size = UDim2.new(1, -16, 0, 28)
LogHeader.Position = UDim2.new(0, 8, 0, 6)
LogHeader.TextXAlignment = Enum.TextXAlignment.Left
LogHeader.Parent = LogPanel

local Notes = Instance.new("TextLabel")
Notes.BackgroundTransparency = 1
Notes.TextXAlignment = Enum.TextXAlignment.Left
Notes.TextYAlignment = Enum.TextYAlignment.Top
Notes.Font = Enum.Font.Gotham
Notes.TextSize = 16
Notes.TextColor3 = Color3.fromRGB(210, 210, 210)
Notes.TextWrapped = true
Notes.Size = UDim2.new(1, -16, 1, - (28 + 12))
Notes.Position = UDim2.new(0, 8, 0, 28 + 6)
Notes.Text = "- Retries up to 3x per pet\n- Auto-handle favorited pets\n- Re-equips if you unhold the pet\n- Countdown shows when waiting\n- Silent recount after each trade"
Notes.Parent = LogPanel

-- Pet rows map
local petRows = {}
local function ensurePetRow(name)
	if petRows[name] and petRows[name].Parent == PetList then return petRows[name] end
	local row = Instance.new("Frame")
	row.Name = "Row_" .. name
	row.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, 34)
	row.Parent = PetList
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
	local pad = Instance.new("UIPadding", row)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "Name"
	nameLbl.BackgroundTransparency = 1
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Font = Enum.Font.GothamSemibold
	nameLbl.TextSize = 16
	nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLbl.Text = name
	nameLbl.Size = UDim2.new(0.6, 0, 1, 0)
	nameLbl.Parent = row

	local countLbl = Instance.new("TextLabel")
	countLbl.Name = "Count"
	countLbl.BackgroundTransparency = 1
	countLbl.TextXAlignment = Enum.TextXAlignment.Right
	countLbl.Font = Enum.Font.Gotham
	countLbl.TextSize = 16
	countLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
	countLbl.Text = "-"
	countLbl.Size = UDim2.new(0.4, 0, 1, 0)
	countLbl.Position = UDim2.new(0.6, 0, 0, 0)
	countLbl.Parent = row

	petRows[name] = row
	PetList.CanvasSize = UDim2.new(0, 0, 0, PetListLayout.AbsoluteContentSize.Y + 12)
	return row
end

-- Circle toggle button (floating at the top of MainFrame, top-right side)
local guiVisible = true
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleGUIButton"
ToggleButton.Size = UDim2.fromOffset(32, 32)
-- Position it right at the top-right of MainFrame
ToggleButton.Position = UDim2.new(0, MainFrame.AbsolutePosition.X + MainFrame.AbsoluteSize.X - 32, 0, MainFrame.AbsolutePosition.Y - 5)
ToggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Text = "◉"
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.TextSize = 18
ToggleButton.Parent = ScreenGui
Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(1, 0)

local tbStroke = Instance.new("UIStroke")
tbStroke.Thickness = 2
tbStroke.Color = Color3.fromRGB(70, 70, 70)
tbStroke.Parent = ToggleButton

-- White Screen toggle button (next to the GUI toggle, at the top of MainFrame)
local WhiteScreenButton = Instance.new("TextButton")
WhiteScreenButton.Name = "WhiteScreenButton"
WhiteScreenButton.Size = UDim2.fromOffset(50, 32)
WhiteScreenButton.Position = UDim2.new(0, MainFrame.AbsolutePosition.X + MainFrame.AbsoluteSize.X - 90, 0, MainFrame.AbsolutePosition.Y - 5)
WhiteScreenButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
WhiteScreenButton.TextColor3 = Color3.fromRGB(255, 255, 255)
WhiteScreenButton.Text = "WS"
WhiteScreenButton.Font = Enum.Font.GothamSemibold
WhiteScreenButton.TextSize = 14
WhiteScreenButton.Parent = ScreenGui
Instance.new("UICorner", WhiteScreenButton).CornerRadius = UDim.new(0, 8)

local wsStroke = Instance.new("UIStroke")
wsStroke.Thickness = 2
wsStroke.Color = Color3.fromRGB(70, 70, 70)
wsStroke.Parent = WhiteScreenButton

-- Keep buttons at the top of UI when you drag the MainFrame
MainFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
    ToggleButton.Position = UDim2.fromOffset(
        MainFrame.AbsolutePosition.X + MainFrame.AbsoluteSize.X - 32,
        MainFrame.AbsolutePosition.Y - 5
    )
    WhiteScreenButton.Position = UDim2.fromOffset(
        MainFrame.AbsolutePosition.X + MainFrame.AbsoluteSize.X - 90,
        MainFrame.AbsolutePosition.Y - 5
    )
end)

-- UI Visibility Management
function updateUIVisibility()
    if whiteScreenEnabled then
        -- Show white screen, hide normal UI
        ScreenGui.Enabled = false
        if not whiteScreenGui then
            createWhiteScreen()
        end
        whiteScreenGui.Enabled = true
        WhiteScreenButton.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
    else
        -- Show normal UI, hide white screen
        ScreenGui.Enabled = true
        if whiteScreenGui then
            whiteScreenGui.Enabled = false
        end
        WhiteScreenButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    end
end

-- Toggle logic
ToggleButton.MouseButton1Click:Connect(function()
    guiVisible = not guiVisible
    MainFrame.Visible = guiVisible
    ToggleButton.Text = guiVisible and "◉" or "○"
end)

WhiteScreenButton.MouseButton1Click:Connect(function()
    whiteScreenEnabled = not whiteScreenEnabled
    updateUIVisibility()
end)

-- Initialize UI
if whiteScreen then
    createWhiteScreen()
end
updateUIVisibility()


-- =========================================================
-- UI helpers
-- =========================================================
local function updateStatus(text)
	StatusTextLbl.Text = "Status: " .. text
	if whiteScreenEnabled and whiteScreenText then
		whiteScreenText.Text = text
	end
end

local function updateAttempt(attempt, maxAttempts)
	AttemptText.Text = string.format("Attempt: %d/%d", attempt, maxAttempts)
end

local function updateCountdownText(text)
	CountdownText.Text = "Countdown: " .. text
end

local function updatePetCount(petName, count)
	petStatus[petName] = count == 0 and "Completed" or tostring(count)
	ensurePetRow(petName)
	local row = petRows[petName]
	if row and row:FindFirstChild("Count") then
		row.Count.Text = petStatus[petName]
	end
end

-- =========================================================
-- Logic (same behavior, with silent recounts)
-- =========================================================
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

local function getAllPetsFromInventory()
	local allPets = {}
	local petCounts = {}
	local backpack = LocalPlayer.Backpack
	local character = LocalPlayer.Character
	
	if not backpack or not character then return {} end
	
	-- Items to exclude (not pets)
	local excludeItems = {
		"Watering Can", "Fertilizer", "Shovel", "Hoe", "Rake", "Scissors", 
		"Seed", "Plant", "Flower", "Tree", "Bush", "Grass", "Dirt", "Water",
		"Tool", "Bucket", "Pot", "Garden", "Farm", "Crop", "Harvest"
	}
	
	local function isPet(itemName)
		local basePetName = baseName(itemName)
		-- Check if it contains any excluded words
		for _, excludeWord in ipairs(excludeItems) do
			if string.find(basePetName:lower(), excludeWord:lower()) then
				return false
			end
		end
		-- Additional check: pets usually have brackets with stats like [Age 1] or [0.99 KG]
		-- or are simple names without common tool/plant keywords
		return true
	end
	
	-- Check backpack
	for _, pet in ipairs(backpack:GetChildren()) do
		if pet:IsA("Tool") and isPet(pet.Name) then
			local petName = baseName(pet.Name)
			if not petCounts[petName] then
				petCounts[petName] = true
				table.insert(allPets, petName)
			end
		end
	end
	
	-- Check character (equipped pets)
	for _, pet in ipairs(character:GetChildren()) do
		if pet:IsA("Tool") and isPet(pet.Name) then
			local petName = baseName(pet.Name)
			if not petCounts[petName] then
				petCounts[petName] = true
				table.insert(allPets, petName)
			end
		end
	end
	
	return allPets
end

local function countPetsInBackpack(petName)
	local count = 0
	local backpack = LocalPlayer.Backpack
	local character = LocalPlayer.Character
	if not backpack or not character then return 0 end
	for _, pet in ipairs(backpack:GetChildren()) do
		if baseName(pet.Name) == petName then count += 1 end
	end
	for _, pet in ipairs(character:GetChildren()) do
		if baseName(pet.Name) == petName then count += 1 end
	end
	return count
end

-- Silent recount: fast pass + delayed pass (catch replication)
local function refreshCountsFor(petName)
    task.defer(function()
        task.wait(0.2)
        updatePetCount(petName, countPetsInBackpack(petName))
        task.wait(0.8)
        updatePetCount(petName, countPetsInBackpack(petName))
    end)
end

local function refreshAllCounts()
    task.defer(function()
        task.wait(0.2)
        local petsToRefresh = tradeWholeInventory and getAllPetsFromInventory() or petToGive
        for _, name in ipairs(petsToRefresh) do
            updatePetCount(name, countPetsInBackpack(name))
        end
        task.wait(0.8)
        petsToRefresh = tradeWholeInventory and getAllPetsFromInventory() or petToGive
        for _, name in ipairs(petsToRefresh) do
            updatePetCount(name, countPetsInBackpack(name))
        end
    end)
end

local function initializePetCounts()
	updateStatus("Initializing...")
	task.wait(1)
	
	local petsToProcess = tradeWholeInventory and getAllPetsFromInventory() or petToGive
	
	for _, petName in ipairs(petsToProcess) do
		ensurePetRow(petName)
		updatePetCount(petName, countPetsInBackpack(petName))
	end
	updateCountdownText("-")
	updateAttempt(0, 3)
end

-- Remotes
local PetGiftingService = ReplicatedStorage.GameEvents.PetGiftingService
local Notification = ReplicatedStorage.GameEvents.Notification
local Favorite_Item = ReplicatedStorage.GameEvents.Favorite_Item
local GiftPet = ReplicatedStorage.GameEvents.GiftPet -- Remote for receiving trades
local AcceptPetGift = ReplicatedStorage.GameEvents.AcceptPetGift -- Remote for accepting trades

-- Auto-Receiver functionality
if isReceiver then
    updateStatus("Receiver mode")
    updateCountdownText("Ready")
    
    -- Initialize pet count tracking for receiver
    local totalReceived = 0
    
    local function refreshReceiverCounts()
        -- Get all pets from inventory and update their counts
        local allPets = getAllPetsFromInventory()
        for _, petName in ipairs(allPets) do
            local count = countPetsInBackpack(petName)
            updatePetCount(petName, count)
        end
        updatePetCount("Total Received", totalReceived)
    end
    
    local function initializeReceiverCounts()
        -- Show initial counts for all pets in inventory
        ensurePetRow("Total Received")
        updatePetCount("Total Received", 0)
        refreshReceiverCounts()
    end
    
    initializeReceiverCounts()
    
    local receiverTradeProcessing = false
    local currentTradePet = nil
    
    -- Handle incoming trade offers
    GiftPet.OnClientEvent:Connect(function(petId, petName, senderName)
        if receiverTradeProcessing then
            return
        end
        
        receiverTradeProcessing = true
        currentTradePet = petName
        
        updateStatus("Receiving trade")
        updateCountdownText("Processing")
        
        -- Auto-accept the trade using the correct remote
        AcceptPetGift:FireServer(true, petId)
    end)
    
    -- Listen for trade completion notifications
    Notification.OnClientEvent:Connect(function(message)
        if receiverTradeProcessing and type(message) == "string" then
            if message == "Trade completed!" or message == "Trade complete" or message == "Trade Complete" then
                receiverTradeProcessing = false
                
                -- Update counts after receiving trade
                if currentTradePet then
                    totalReceived = totalReceived + 1
                    currentTradePet = nil
                    
                    -- Refresh all pet counts after a short delay
                    task.defer(function()
                        task.wait(0.5)
                        refreshReceiverCounts()
                    end)
                end
                
                updateStatus("Trade completed")
                updateCountdownText("Ready")
                
                task.wait(1)
                updateStatus("Ready for next trade")
            end
        end
    end)
    
    -- Periodic count refresh
    task.spawn(function()
        while isReceiver do
            if not receiverTradeProcessing then
                refreshReceiverCounts()
            end
            task.wait(10) -- Refresh every 10 seconds
        end
    end)
    
    -- Keep the receiver script running
    while isReceiver do
        task.wait(15) -- Check every 15 seconds
    end
    return -- Exit the script for receivers
end

-- Notifications
Notification.OnClientEvent:Connect(function(message)
	if type(message) == "string" then
		if message == "Trade completed!" or message == "Trade complete" or message == "Trade Complete" then
			tradeAccepted = true
            refreshAllCounts() -- server moved items; update everything
		elseif message == "Cannot gift a favorited pet!" then
			favoriteBlocked = true
		elseif message == "You are not holding a tool!" then
			notHoldingTool = true
		end
	end
end)

-- Equip (no auto-unfavorite; only respond to server messages)
local function equipPet(petName)
	local backpack = LocalPlayer.Backpack
	for _, pet in ipairs(backpack:GetChildren()) do
		if pet:IsA("Tool") and baseName(pet.Name) == petName then
			pet.Parent = LocalPlayer.Character
			task.wait(0.5)
			return pet
		end
	end
	return nil
end

-- Countdown helper (aborts if trade completes)
local function countdownWithAbort(totalSeconds, fmt)
	for i = totalSeconds, 1, -1 do
		if tradeAccepted then return true end
		updateCountdownText(string.format(fmt, i))
		task.wait(1)
		if tradeAccepted then return true end
	end
	updateCountdownText("-")
	return false
end

-- Trade logic (with in-attempt handling of favorite/unholding)
local function tradePet(targetPlayer, petName)
	local maxAttempts = 3
	local currentAttempt = 1

	while currentAttempt <= maxAttempts do
		updateStatus(string.format("Trading %s", petName))
		updateAttempt(currentAttempt, maxAttempts)

		tradeAccepted = false
		favoriteBlocked = false
		notHoldingTool = false

		-- inner loop: retry within SAME attempt on handled errors
		while true do
			-- ensure holding
			local char = LocalPlayer.Character
			local holding = false
			if char then
				for _, tool in ipairs(char:GetChildren()) do
					if tool:IsA("Tool") and baseName(tool.Name) == petName then
						holding = true
						break
					end
				end
			end
			if not holding then
				updateStatus("Equiping Pet")
				unequipAllPets()
				local ok = equipPet(petName)
				if not ok then
					break
				end
			end

			-- send
			PetGiftingService:FireServer("GivePet", targetPlayer)

			-- wait signals
			local startTime = tick()
			local timeout = 5
			while (tick() - startTime) < timeout and not tradeAccepted and not favoriteBlocked and not notHoldingTool do
				task.wait(0.5)
			end

			if tradeAccepted then
				updateCountdownText("-")
                refreshCountsFor(petName) -- update this pet’s count silently
				return true
			end

			if favoriteBlocked then
				updateStatus("Pet favorited → unfavoriting")
				-- unfavorite held tools then small delay; same attempt
				local ch = LocalPlayer.Character
				if ch then
					for _, tool in ipairs(ch:GetChildren()) do
						if tool:IsA("Tool") then
							Favorite_Item:FireServer(tool)
						end
					end
				end
				countdownWithAbort(2, "Retrying in %d seconds...")
				favoriteBlocked = false
				notHoldingTool = false
				tradeAccepted = false
				continue
			end

			if notHoldingTool then
				updateStatus("Equiping Pet")
				unequipAllPets()
				equipPet(petName)
				task.wait(0.5)
				notHoldingTool = false
				tradeAccepted = false
				favoriteBlocked = false
				continue
			end

			-- timeout/other
			break
		end

		-- attempt fail -> next attempt
		currentAttempt += 1
		if currentAttempt <= maxAttempts then
			countdownWithAbort(5, string.format("Retrying in %%d seconds... (after attempt %d)", currentAttempt - 1))
		end
	end

	updateStatus(string.format("Failed to trade %s after 3 attempts", petName))
	updateCountdownText("-")
	return false
end

-- Find target
updateStatus("Looking for target...")
local foundPlayer = nil
while not foundPlayer do
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Name == targetUsername then
			foundPlayer = player
			updateStatus("Found player")
			break
		end
	end
	task.wait(1)
end

-- Init
initializePetCounts()

local function checkRemainingPets()
	local petsToCheck = tradeWholeInventory and getAllPetsFromInventory() or petToGive
	for _, petName in ipairs(petsToCheck) do
		if countPetsInBackpack(petName) > 0 then return true end
	end
	return false
end

-- Main loop
while true do
	updateStatus("Starting trade cycle")
	local anythingTraded = false
	
	-- Get current pet list (either from config or whole inventory)
	local currentPetList = tradeWholeInventory and getAllPetsFromInventory() or petToGive

	for _, petName in ipairs(currentPetList) do
		updateStatus("Processing " .. petName)
		unequipAllPets()

		while true do
			local petsLeft = countPetsInBackpack(petName)
			updatePetCount(petName, petsLeft)
			if petsLeft == 0 then
				updateStatus("No more " .. petName .. " left")
				break
			end

			local eq = equipPet(petName)
			if eq then
				local ok = tradePet(foundPlayer, petName)
				if ok then
					anythingTraded = true
					updateStatus("Successfully traded " .. petName)
					countdownWithAbort(2, "Cooldown %d...")
				else
					unequipAllPets()
					break
				end
			else
				updateStatus("Failed to equip " .. petName)
				countdownWithAbort(5, "Retrying in %d seconds...")
				break
			end
		end
	end

	if not checkRemainingPets() then
		updateStatus("All pets traded")
		updateCountdownText("-")
		break
	end

	if not anythingTraded then
		countdownWithAbort(10, "Retrying in %d seconds...")
	else
		countdownWithAbort(3, "Next cycle in %d seconds...")
	end
end

updateStatus("Trading completed")
updateCountdownText("-")

if leaveWhenDone then
	updateStatus("Leaving game...")
	updateCountdownText("5")
	task.wait(1)
	updateCountdownText("4")
	task.wait(1)
	updateCountdownText("3")
	task.wait(1)
	updateCountdownText("2")
	task.wait(1)
	updateCountdownText("1")
	task.wait(1)
	updateCountdownText("Goodbye!")
	task.wait(0.5)
	game:Shutdown()
else
	updateStatus("Completed - Staying in game")
	updateCountdownText("Complete")
end
