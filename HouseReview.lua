-- HouseReview.lua

local eventFrame = CreateFrame("Frame", "HouseReviewEventFrame", UIParent)
eventFrame:RegisterEvent("ADDON_LOADED")

-- Try to register events that might exist for neighborhood updates
-- Some might not exist depending on the exact build, so we wrap them to prevent errors
local function SafeRegisterEvent(frame, event)
    pcall(function() frame:RegisterEvent(event) end)
end

SafeRegisterEvent(eventFrame, "HOUSING_NEIGHBORHOOD_MAP_DATA_UPDATED")
SafeRegisterEvent(eventFrame, "HOUSING_NEIGHBORHOOD_LIST_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "HouseReview" then
        HouseReviewDB = HouseReviewDB or {}
        print("HouseReview addon loaded. Use /hr or /housereview to show/hide the map.")
    elseif event == "HOUSING_NEIGHBORHOOD_MAP_DATA_UPDATED" or event == "HOUSING_NEIGHBORHOOD_LIST_CHANGED" then
        if HouseReviewMapFrame:IsShown() then
            HouseReview_UpdateMap()
        end
    end
end)

-- Create a movable main frame for the map
local mapFrame = CreateFrame("Frame", "HouseReviewMapFrame", UIParent, "BackdropTemplate")
mapFrame:SetFrameStrata("FULLSCREEN")
mapFrame:SetSize(800, 600)
mapFrame:SetPoint("CENTER")
mapFrame:SetBackdrop({
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
mapFrame:SetMovable(true)
mapFrame:EnableMouse(true)
mapFrame:RegisterForDrag("LeftButton")
mapFrame:SetScript("OnDragStart", mapFrame.StartMoving)
mapFrame:SetScript("OnDragStop", mapFrame.StopMovingOrSizing)
mapFrame:Hide()

-- Add a title to the map frame
local title = mapFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
title:SetPoint("TOP", 0, -20)
title:SetText("Neighborhood Map")

-- Add a close button
local closeButton = CreateFrame("Button", nil, mapFrame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -5, -5)

-- Forward declaration of update function
local HouseReview_UpdateReviewList

function HouseReview_LikeReview(location, index)
    if not location or not index then return end
    local reviews = HouseReviewDB[location]
    if not reviews or not reviews[index] then return end
    
    local entry = reviews[index]
    -- Ensure entry is a table (migrate if needed)
    if type(entry) ~= "table" then
        entry = { text = entry, author = "Unknown", date = "", likedBy = {} }
        reviews[index] = entry
    end
    
    if not entry.likedBy then entry.likedBy = {} end
    
    local playerName = UnitName("player")
    if entry.likedBy[playerName] then
        print("You have already liked this review.")
        return
    end
    
    entry.likedBy[playerName] = true
    
    HouseReview_UpdateReviewList()
end

function HouseReview_UpdateReviewList()
    local location = HouseReviewFrame.selectedPlot
    local container = HouseReviewFrameScrollFrameReviewsContainer
    if not container or not location then return end
    
    -- Initialize row pool
    if not container.rows then container.rows = {} end
    for _, row in ipairs(container.rows) do row:Hide() end
    
    local reviews = HouseReviewDB[location] or {}
    
    -- Prepare display list with calculated likes
    local displayList = {}
    for i, r in ipairs(reviews) do
        local entry = r
        -- Handle legacy string reviews
        if type(r) ~= "table" then
            entry = { text = r, author = "Unknown", date = "", likedBy = {} }
        end
        
        -- Calculate Likes
        local likeCount = 0
        if entry.likedBy then
            for _ in pairs(entry.likedBy) do likeCount = likeCount + 1 end
        end
        
        -- Create wrapper for display sorting
        local displayEntry = {
            data = entry,
            originalIndex = i,
            calculatedLikes = likeCount
        }
        table.insert(displayList, displayEntry)
    end
    
    -- Sort by Likes (Descending)
    table.sort(displayList, function(a,b) 
        return a.calculatedLikes > b.calculatedLikes
    end)
    
    local yOffset = 0
    local width = container:GetWidth()
    
    for i, displayEntry in ipairs(displayList) do
        local entry = displayEntry.data
        local row = container.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, container, "BackdropTemplate")
            row:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 }
            })
            row:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
            row:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.5)
            
            -- Author/Date Header
            row.header = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            row.header:SetPoint("TOPLEFT", 10, -8)
            row.header:SetTextColor(0.6, 0.6, 0.6)
            
            -- Like Button
            row.likeBtn = CreateFrame("Button", nil, row)
            row.likeBtn:SetSize(16, 16)
            row.likeBtn:SetPoint("TOPRIGHT", -10, -8)
            row.likeBtn:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
            row.likeBtn:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
            row.likeBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
            
            -- Like Count
            row.likes = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.likes:SetPoint("RIGHT", row.likeBtn, "LEFT", -2, 0)
            
            -- Body Text
            row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.text:SetPoint("TOPLEFT", 10, -25)
            row.text:SetPoint("RIGHT", -10, 0)
            row.text:SetJustifyH("LEFT")
            row.text:SetWordWrap(true)
            
            container.rows[i] = row
        end
        
        -- Populate Data
        local author = entry.author or "Unknown"
        local date = entry.date or ""
        row.header:SetText(date .. " " .. author)
        
        row.text:SetText(entry.text or "")
        -- Calculate height based on text
        row.text:SetWidth(width - 20)
        local textHeight = row.text:GetStringHeight()
        row:SetHeight(math.max(40, textHeight + 35))
        
        row.likes:SetText(displayEntry.calculatedLikes .. " Likes")
        
        -- Setup Button
        row.likeBtn:SetScript("OnClick", function()
             HouseReview_LikeReview(location, displayEntry.originalIndex)
        end)
        
        -- Highlight if already liked?
        local playerName = UnitName("player")
        if entry.likedBy and entry.likedBy[playerName] then
            row.likes:SetTextColor(0, 1, 0) -- Green text if liked
            row.likeBtn:Disable()
            row.likeBtn:SetAlpha(0.5)
        else
            row.likes:SetTextColor(1, 1, 1)
            row.likeBtn:Enable()
            row.likeBtn:SetAlpha(1)
        end
        
        row:SetPoint("TOPLEFT", 0, -yOffset)
        row:SetWidth(width)
        row:Show()
        
        yOffset = yOffset + row:GetHeight() + 5
    end
    
    container:SetHeight(yOffset)
end


-- Function to update the map with plot data
function HouseReview_LikeReview(location, index)
    if not location or not index then return end
    local reviews = HouseReviewDB[location]
    if not reviews or not reviews[index] then return end
    
    local entry = reviews[index]
    -- Ensure entry is a table (migrate if needed)
    if type(entry) ~= "table" then
        entry = { text = entry, author = "Unknown", date = "", likes = 0, likedBy = {} }
        reviews[index] = entry
    end
    
    if not entry.likes then entry.likes = 0 end
    if not entry.likedBy then entry.likedBy = {} end
    
    local playerName = UnitName("player")
    if entry.likedBy[playerName] then
        print("You have already liked this review.")
        return
    end
    
    entry.likes = entry.likes + 1
    entry.likedBy[playerName] = true
    
    HouseReview_UpdateReviewList()
end

function HouseReview_UpdateReviewList()
    local location = HouseReviewFrame.selectedPlot
    local container = HouseReviewFrameScrollFrameReviewsContainer
    if not container or not location then return end
    
    -- Initialize row pool
    if not container.rows then container.rows = {} end
    for _, row in ipairs(container.rows) do row:Hide() end
    
    local reviews = HouseReviewDB[location] or {}
    
    -- Prepare display list
    local displayList = {}
    for i, r in ipairs(reviews) do
        local entry = r
        -- Handle legacy string reviews
        if type(r) ~= "table" then
            entry = { text = r, author = "Unknown", date = "", likes = 0 }
        end
        entry.originalIndex = i -- Important for mapping clicks back to DB
        table.insert(displayList, entry)
    end
    
    -- Sort by Likes (Descending)
    table.sort(displayList, function(a,b) 
        return (a.likes or 0) > (b.likes or 0) 
    end)
    
    local yOffset = 0
    local width = container:GetWidth()
    
    for i, entry in ipairs(displayList) do
        local row = container.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, container, "BackdropTemplate")
            row:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 }
            })
            row:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
            row:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.5)
            
            -- Author/Date Header
            row.header = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            row.header:SetPoint("TOPLEFT", 10, -8)
            row.header:SetTextColor(0.6, 0.6, 0.6)
            
            -- Like Button
            row.likeBtn = CreateFrame("Button", nil, row)
            row.likeBtn:SetSize(16, 16)
            row.likeBtn:SetPoint("TOPRIGHT", -10, -8)
            row.likeBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up") -- Placeholder "Coin/Circle" texture?
            -- Better texture: Thumbs up? or just a Star
            row.likeBtn:SetNormalTexture(134440) -- "Interface\\Icons\\INV_Misc_Gem_Variety_02" (Blue Gem?) 
            -- Actually let's use a heart or something familiar. 
            -- 525134 = "Interface\\Icons\\Pet_Type_Critter" (Rabbit/Heart-ish?)
            -- Let's use standard "Like" text for now to be safe, or a simple Plus.
            row.likeBtn:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
            row.likeBtn:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
            row.likeBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
            
            -- Like Count
            row.likes = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.likes:SetPoint("RIGHT", row.likeBtn, "LEFT", -2, 0)
            
            -- Body Text
            row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.text:SetPoint("TOPLEFT", 10, -25)
            row.text:SetPoint("RIGHT", -10, 0)
            row.text:SetJustifyH("LEFT")
            row.text:SetWordWrap(true)
            
            container.rows[i] = row
        end
        
        -- Populate Data
        local author = entry.author or "Unknown"
        local date = entry.date or ""
        row.header:SetText(date .. " " .. author)
        
        row.text:SetText(entry.text or "")
        -- Calculate height based on text
        row.text:SetWidth(width - 20)
        local textHeight = row.text:GetStringHeight()
        row:SetHeight(math.max(40, textHeight + 35))
        
        local likeCount = entry.likes or 0
        row.likes:SetText(likeCount .. " Likes")
        
        -- Setup Button
        row.likeBtn:SetScript("OnClick", function()
             HouseReview_LikeReview(location, entry.originalIndex)
        end)
        
        -- Highlight if already liked?
        local playerName = UnitName("player")
        if entry.likedBy and entry.likedBy[playerName] then
            row.likes:SetTextColor(0, 1, 0) -- Green text if liked
            row.likeBtn:Disable()
            row.likeBtn:SetAlpha(0.5)
        else
            row.likes:SetTextColor(1, 1, 1)
            row.likeBtn:Enable()
            row.likeBtn:SetAlpha(1)
        end
        
        row:SetPoint("TOPLEFT", 0, -yOffset)
        row:SetWidth(width)
        row:Show()
        
        yOffset = yOffset + row:GetHeight() + 5
    end
    
    container:SetHeight(yOffset)
end

function HouseReview_UpdateMap()
    -- Attempt to get the Map ID for the neighborhood
    local mapID
    if C_Map and C_Map.GetBestMapForUnit then
        mapID = C_Map.GetBestMapForUnit("player")
    end

    -- Some builds might not have a "best" map but might be accessible through zone info
    if not mapID and C_Map and C_Map.GetPlayerMap artID then
        mapID = C_Map.GetPlayerMap artID()
    end
    
    -- Final fallback if we are in a housing zone but can't get it from player
    if not mapID and C_Housing and C_Housing.GetCurrentNeighborhood then
        local neighborhoodID = C_Housing.GetCurrentNeighborhood()
        if neighborhoodID then
            -- This is a guess, the API might not exist
            local info = C_Housing.GetNeighborhoodInfo(neighborhoodID)
            mapID = info and info.mapID
        end
    end

    if not mapFrame.plotIcons then
        mapFrame.plotIcons = {}
    end


    -- Hide existing icons before redrawing
    for _, icon in ipairs(mapFrame.plotIcons) do
        icon:Hide()
    end

    if not C_HousingNeighborhood then
        print("HouseReview: C_HousingNeighborhood API not found.")
        return
    end

    -- Request an update in case data isn't cached
    if C_HousingNeighborhood.RequestNeighborhoodMapData then
        C_HousingNeighborhood.RequestNeighborhoodMapData()
    end

    local neighborhoodData = C_HousingNeighborhood.GetNeighborhoodMapData()
    if not neighborhoodData and C_Housing and C_Housing.GetNeighborhoodMapData then
        neighborhoodData = C_Housing.GetNeighborhoodMapData()
    end

    local plots = neighborhoodData and (neighborhoodData.neighborhoodPlots or neighborhoodData.plots)
    
    -- Fallback: Check if neighborhoodData itself is the array of plots
    if not plots and type(neighborhoodData) == "table" and #neighborhoodData > 0 then
        plots = neighborhoodData
    end

    if not plots then
        -- If we just requested it, it might take a moment to arrive via event
        print("Requesting neighborhood data... Please wait.")
        return
    end

    local i = 0
    for plotID, plotInfo in pairs(plots) do
        i = i + 1
        local icon = mapFrame.plotIcons[i]
        if not icon then
            icon = CreateFrame("Button", "HouseReviewPlotIcon" .. i, mapFrame)
            icon:SetSize(20, 20)
            icon:SetFrameLevel(mapFrame:GetFrameLevel() + 10) -- Ensure it's above the map frame
            
            -- Create a texture explicitly using FileDataID for reliability
            -- 134393 is the standard Hearthstone icon
            local tex = icon:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints(icon)
            tex:SetTexture(134393) 
            icon.texture = tex -- Store reference for coloring
            
            -- Add a highlight
            local highlight = icon:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints(icon)
            highlight:SetTexture(134393)
            highlight:SetAlpha(0.5)
            highlight:SetBlendMode("ADD")
            icon:SetHighlightTexture(highlight)
            icon.highlight = highlight -- Store reference

            mapFrame.plotIcons[i] = icon
        end

        -- Ensure texture reference exists if upgrading from old frames (hot reload support)
        if not icon.texture then
             local regions = {icon:GetRegions()}
             for _, r in ipairs(regions) do
                 if r:GetDrawLayer() == "ARTWORK" then icon.texture = r; break end
             end
        end
        -- Ensure highlight reference exists
        if not icon.highlight then
            icon.highlight = icon:GetHighlightTexture()
        end

        -- Apply Coloring Logic based on ownerType
        -- 0 = Empty, 1 = Other, 2 = Friend, 3 = Self (Account/Alt)
        local ownerType = plotInfo.ownerType or 0
        local isOwned = (ownerType > 0)
        local isPlayerHouse = (ownerType == 3)
        local isFriendHouse = (ownerType == 2)

        if icon.texture then
            -- Reset highlight visibility first
            if icon.highlight then
                icon.highlight:SetTexture(134393)
                icon.highlight:SetBlendMode("ADD")
                icon.highlight:SetAlpha(0.5)
            end

            if isPlayerHouse then
                icon.texture:SetVertexColor(0, 1, 0, 1) -- Green for Player
                icon:SetSize(20, 20)
                if icon.highlight then 
                    icon.highlight:SetVertexColor(0, 1, 0, 0.5) -- Green glow
                end
            elseif isFriendHouse then
                icon.texture:SetVertexColor(0.2, 0.6, 1, 1) -- Blue for Friend
                icon:SetSize(20, 20)
                if icon.highlight then 
                    icon.highlight:SetVertexColor(0.2, 0.6, 1, 0.5) -- Blue glow
                end
            elseif not isOwned then
                icon.texture:SetVertexColor(0.5, 0.5, 0.5, 1) -- Grey for Empty
                icon:SetSize(12, 12) -- Smaller for Empty
                if icon.highlight then 
                     icon.highlight:SetAlpha(0) -- Hide highlight
                end
            else
                icon.texture:SetVertexColor(1, 1, 1, 1) -- White for Others
                icon:SetSize(20, 20)
                if icon.highlight then 
                    icon.highlight:SetVertexColor(1, 1, 1, 0.5) -- White glow
                end
            end
        end

        -- Handle different possible position structures
        local pos = plotInfo.mapPosition or plotInfo.MapPosition or plotInfo.position or plotInfo.location or plotInfo
        if pos and pos.mapPosition and type(pos.mapPosition) == "table" then
            pos = pos.mapPosition
        elseif pos and pos.MapPosition and type(pos.MapPosition) == "table" then
            pos = pos.MapPosition
        end

        local x = pos.x or pos.posX or pos.mapX or pos.left or pos[1]
        local y = pos.y or pos.posY or pos.mapY or pos.top or pos[2]

        -- If we still don't have it, look for any field that might be a number
        if not x or not y then
            for k, v in pairs(pos) do
                if type(v) == "number" then
                    local key = tostring(k):lower()
                    if not x and (key:find("x") or key:find("left") or key:find("horizontal")) then x = v end
                    if not y and (key:find("y") or key:find("top") or key:find("vertical")) then y = v end
                end
            end
        end

        if x and y then
            -- Normalize coordinates if they are larger than 1 (some systems use 0-100 or map pixels)
            if x > 1 or y > 1 then
                -- Try to detect if they need scaling; for now assume 0-1 if they are small, else maybe they are already pixels
                -- But usually neighborhood data is 0.0 to 1.0
            end
            
            local xPos = x * 750 + 25 -- Padding
            local yPos = -y * 550 - 25 -- Padding
            icon:SetPoint("TOPLEFT", xPos, yPos)
            icon:Show()
        else
            icon:Hide()
        end

        -- Update tooltip data
        icon:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Plot ID: " .. (plotInfo.plotID or plotID or "N/A"))
            GameTooltip:AddLine("Owner: " .. (plotInfo.ownerName or "Unowned"))
            if not x or not y then
                GameTooltip:AddLine("|cFFFF0000(No Position Data)|r")
            end
            GameTooltip:Show()
        end)
        -- ... rest of script setup ...
        icon:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        icon:SetScript("OnClick", function(self)
            if not (plotInfo.ownerName and plotInfo.ownerName ~= "") then return end -- Ignore clicks on empty plots
            
            HouseReviewFrame.selectedPlot = tostring(plotInfo.plotID or plotID or "Unknown")
            HouseReviewFrame:Show()
            
            local ownerNameDisplay = plotInfo.ownerName or "Unknown"
            if ownerNameDisplay:find("-") then
                ownerNameDisplay = strsplit("-", ownerNameDisplay)
            end
            HouseReviewFrameTitle:SetText("Review for " .. ownerNameDisplay .. "'s Plot")
            
            -- Load existing reviews via the new list updater
            HouseReview_UpdateReviewList()
            
            -- Update Button State
            local playerHasReview = false
            local playerName = UnitName("player")
            local reviews = HouseReviewDB[HouseReviewFrame.selectedPlot] or {}
            
            for _, review in ipairs(reviews) do
                 if type(review) == "table" and review.author == playerName then
                     playerHasReview = true
                     break
                 end
            end

            if isPlayerHouse then
                HouseReviewFrameSubmitButton:Hide()
                HouseReviewFrameDeleteButton:Hide()
                HouseReviewFrameEditBox:SetText("|cFF888888You cannot review your own plot.|r")
                HouseReviewFrameEditBox:SetEnabled(false)
            elseif playerHasReview then
                HouseReviewFrameSubmitButton:Hide()
                HouseReviewFrameDeleteButton:Show()
                HouseReviewFrameEditBox:SetText("|cFF888888You have already reviewed this plot.|r")
                HouseReviewFrameEditBox:SetEnabled(false)
            else
                HouseReviewFrameSubmitButton:Show()
                HouseReviewFrameDeleteButton:Hide()
                HouseReviewFrameEditBox:SetText("")
                HouseReviewFrameEditBox:SetEnabled(true)
            end
        end)
    end
end

-- Slash command to show/hide the neighborhood map
SLASH_HOUSEREVIEW1 = "/housereview"
SLASH_HOUSEREVIEW2 = "/hr"
SlashCmdList["HOUSEREVIEW"] = function(msg)
    if mapFrame:IsShown() then
        mapFrame:Hide()
        print("HouseReview: Map hidden.")
    else
        HouseReview_UpdateMap()
        mapFrame:Show()
        print("HouseReview: Map shown.")
    end
end

-- Debug command to check API availability and data
SLASH_HOUSEREVIEWDEBUG1 = "/hrdebug"
SlashCmdList["HOUSEREVIEWDEBUG"] = function(msg)
    print("|cFFFFFF00HouseReview Debug:|r")
    if not C_HousingNeighborhood then
        print(" - C_HousingNeighborhood: |cFFFF0000MISSING|r")
    else
        print(" - C_HousingNeighborhood: |cFF00FF00FOUND|r")
        if C_HousingNeighborhood.RequestNeighborhoodMapData then
            print(" - RequestNeighborhoodMapData: |cFF00FF00FOUND|r. Calling now...")
            local success, err = pcall(C_HousingNeighborhood.RequestNeighborhoodMapData)
            if success then
                print("   - Call |cFF00FF00SUCCESSFUL|r")
            else
                print("   - Call |cFFFF0000FAILED|r: " .. tostring(err))
            end
        else
            print(" - RequestNeighborhoodMapData: |cFFFF0000MISSING|r")
        end

        local data = C_HousingNeighborhood.GetNeighborhoodMapData()
        if data then
            print(" - GetNeighborhoodMapData: |cFF00FF00DATA RETURNED|r")
            local count = 0
            local plots = data.neighborhoodPlots or data.plots or (type(data) == "table" and data)
            if plots then
                local firstPlotID, firstPlotData
                for k, v in pairs(plots) do 
                    count = count + 1 
                    if not firstPlotID then firstPlotID, firstPlotData = k, v end
                end
                print("   - Plot count: " .. count)
                if firstPlotData then
                    print("   - Sample Plot Key: " .. tostring(firstPlotID))
                    if type(firstPlotData) == "table" then
                        local keys = ""
                        for k, v in pairs(firstPlotData) do
                            keys = keys .. tostring(k) .. "(" .. type(v) .. "), "
                        end
                        print("   - Available Keys: " .. keys:sub(1, -3))
                        
                        local pos = firstPlotData.mapPosition or firstPlotData.MapPosition or firstPlotData.position or firstPlotData.location or firstPlotData
                        if type(pos) == "table" then
                            -- Check for double nesting
                            if pos.mapPosition and type(pos.mapPosition) == "table" then
                                print("   - Detected Double-Nesting (mapPosition.mapPosition)")
                                pos = pos.mapPosition
                            end

                            local x = pos.x or pos.posX or pos.mapX or pos.left or pos[1]
                            local y = pos.y or pos.posY or pos.mapY or pos.top or pos[2]
                            print("   - Detected Position: x=" .. tostring(x) .. ", y=" .. tostring(y))
                            
                            -- Dump keys AND values
                            local posKeys = ""
                            for pk, pv in pairs(pos) do 
                                posKeys = posKeys .. tostring(pk) .. "=" .. tostring(pv) .. " (" .. type(pv) .. "), " 
                            end
                            print("   - Table Contents: " .. posKeys:sub(1, -3))
                        else
                            print("   - Position data is not a table: " .. type(pos))
                        end
                    else
                        print("   - Plot data is not a table: " .. type(firstPlotData))
                    end
                end
            else
                print("   - No plots found in data structure.")
            end
        else
            print(" - GetNeighborhoodMapData: |cFFFF0000NIL|r")
        end
    end
end

-- Slash command to reset the database
SLASH_HOUSEREVIEWRESET1 = "/hrreset"
SlashCmdList["HOUSEREVIEWRESET"] = function(msg)
    HouseReviewDB = {}
    print("HouseReview: Database reset. Please reload UI (/reload) to ensure a clean state.")
end
