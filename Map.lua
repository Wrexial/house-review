-- HouseReview Map System

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

mapFrame:EnableKeyboard(true)
mapFrame:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
        self:Hide()
    end
end)

-- Add a title to the map frame
mapFrame.title = mapFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
mapFrame.title:SetPoint("TOP", 0, -20)
mapFrame.title:SetText("Neighborhood Map")

-- Add a close button
local closeButton = CreateFrame("Button", nil, mapFrame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -5, -5)

function HouseReview_UpdateMap()
    -- Use the cached neighborhood ID
    local neighborhoodID = HouseReview.currentNeighborhoodID

    -- Attempt to get the Map ID for the neighborhood
    local mapID
    if C_Housing and C_Housing.GetUIMapIDForNeighborhood then
        mapID = C_Housing.GetUIMapIDForNeighborhood(neighborhoodID)
    end

    if not mapFrame.plotIcons then
        mapFrame.plotIcons = {}
    end

    -- Remove the dialog backdrop to make it cleaner
    mapFrame:SetBackdrop(nil)
    
    -- Create/Update background texture container
    if not mapFrame.bgLayers then mapFrame.bgLayers = {} end
    
    -- Reset layers
    for _, layer in pairs(mapFrame.bgLayers) do layer:Hide() end

    -- Fallback background color (Dark Grey/Black)
    if not mapFrame.bgColor then
        mapFrame.bgColor = mapFrame:CreateTexture(nil, "BACKGROUND")
        mapFrame.bgColor:SetAllPoints(mapFrame)
        mapFrame.bgColor:SetColorTexture(0.1, 0.1, 0.1, 0.9)
        mapFrame.bgColor:SetDrawLayer("BACKGROUND", -8)
    end
    
    if mapID then
        -- Try to get layer properties first so we know how to tile
        local mapLayers = C_Map.GetMapArtLayers(mapID)
        local layerInfo = mapLayers and mapLayers[1]
        
        if layerInfo then
            local layerWidth = layerInfo.layerWidth
            local layerHeight = layerInfo.layerHeight
            local tileWidth = layerInfo.tileWidth
            local tileHeight = layerInfo.tileHeight
            
            -- Get the texture file IDs
            local textures = C_Map.GetMapArtLayerTextures(mapID, 1)
            
            if textures and layerWidth > 0 and layerHeight > 0 then
                local numCols = math.ceil(layerWidth / tileWidth)
                local numRows = math.ceil(layerHeight / tileHeight)
                
                -- Calculate scale factors to fit our 800x600 frame
                local frameWidth = mapFrame:GetWidth()
                local frameHeight = mapFrame:GetHeight()
                local scaleX = frameWidth / layerWidth
                local scaleY = frameHeight / layerHeight
                
                for i, textureID in ipairs(textures) do
                    -- Determine Row/Col from index (1-based index)
                    local rowIndex = math.floor((i - 1) / numCols)
                    local colIndex = (i - 1) % numCols
                    
                    if rowIndex < numRows then
                        local tex = mapFrame.bgLayers[i]
                        if not tex then
                            tex = mapFrame:CreateTexture(nil, "BACKGROUND")
                            tex:SetDrawLayer("BACKGROUND", -5)
                            mapFrame.bgLayers[i] = tex
                        end
                        
                        -- Handle texture ID being a table or number
                        local fileID = type(textureID) == "table" and textureID.fileDataID or textureID
                        tex:SetTexture(fileID)
                        
                        -- Calculate size and position
                        local posX = colIndex * tileWidth
                        local posY = rowIndex * tileHeight
                        
                        tex:ClearAllPoints()
                        tex:SetPoint("TOPLEFT", mapFrame, "TOPLEFT", posX * scaleX, -posY * scaleY)
                        tex:SetSize(tileWidth * scaleX, tileHeight * scaleY)
                        tex:Show()
                    end
                end
                
                -- Hide unused layers from previous updates
                for k = #textures + 1, #mapFrame.bgLayers do
                    mapFrame.bgLayers[k]:Hide()
                end
            end
        else
            -- Fallback for simple maps without detailed layer info
             local layers = C_Map.GetMapArtLayerTextures(mapID, 1)
             if layers and layers[1] and #layers == 1 then
                 local isTable = type(layers[1]) == "table"
                 if #layers == 1 then
                    local texID = isTable and layers[1].fileDataID or layers[1]
                    
                    if not mapFrame.bgLayers[1] then
                        mapFrame.bgLayers[1] = mapFrame:CreateTexture(nil, "BACKGROUND")
                        mapFrame.bgLayers[1]:SetDrawLayer("BACKGROUND", -5)
                    end
                    
                    mapFrame.bgLayers[1]:SetTexture(texID)
                    mapFrame.bgLayers[1]:SetAllPoints(mapFrame)
                    mapFrame.bgLayers[1]:Show()
                 end
             end
        end
    end


    -- Hide existing icons before redrawing
    for _, icon in ipairs(mapFrame.plotIcons) do
        icon:Hide()
    end

    if not C_HousingNeighborhood then
        print("HouseReview: C_HousingNeighborhood API not found.")
        return
    end

    local neighborhoodData = C_HousingNeighborhood.GetNeighborhoodMapData()
    if not neighborhoodData and C_Housing and C_Housing.GetNeighborhoodMapData then
        neighborhoodData = C_Housing.GetNeighborhoodMapData()
    end

    if C_HousingNeighborhood and C_HousingNeighborhood.GetNeighborhoodName then
        local name = C_HousingNeighborhood.GetNeighborhoodName()
        if name and name ~= "" then
            mapFrame.title:SetText(name)
        else
            mapFrame.title:SetText("Neighborhood Map") -- Fallback
        end
    else
        mapFrame.title:SetText("Neighborhood Map") -- Fallback
    end

    local plots = neighborhoodData and (neighborhoodData.neighborhoodPlots or neighborhoodData.plots)
    
    if not plots and type(neighborhoodData) == "table" and #neighborhoodData > 0 then
        plots = neighborhoodData
    end

    if not plots then
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
            icon:SetFrameLevel(mapFrame:GetFrameLevel() + 10)
            
            local tex = icon:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints(icon)
            tex:SetTexture(134393) 
            icon.texture = tex
            
            local highlight = icon:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints(icon)
            highlight:SetTexture(134393)
            highlight:SetAlpha(0.5)
            highlight:SetBlendMode("ADD")
            icon:SetHighlightTexture(highlight)
            icon.highlight = highlight

            mapFrame.plotIcons[i] = icon
        end

        if not icon.texture then
             local regions = {icon:GetRegions()}
             for _, r in ipairs(regions) do
                 if r:GetDrawLayer() == "ARTWORK" then icon.texture = r; break end
             end
        end
        if not icon.highlight then
            icon.highlight = icon:GetHighlightTexture()
        end

        local ownerType = plotInfo.ownerType or 0
        local isOwned = (ownerType > 0)
        local isPlayerHouse = (ownerType == 3)
        local isFriendHouse = (ownerType == 2)

        if icon.texture then
            if icon.highlight then
                icon.highlight:SetTexture(134393)
                icon.highlight:SetBlendMode("ADD")
                icon.highlight:SetAlpha(0.5)
            end

            if isPlayerHouse then
                icon.texture:SetVertexColor(0, 1, 0, 1)
                icon:SetSize(20, 20)
                if icon.highlight then 
                    icon.highlight:SetVertexColor(0, 1, 0, 0.5)
                end
            elseif isFriendHouse then
                icon.texture:SetVertexColor(0.2, 0.6, 1, 1)
                icon:SetSize(20, 20)
                if icon.highlight then 
                    icon.highlight:SetVertexColor(0.2, 0.6, 1, 0.5)
                end
            elseif not isOwned then
                icon.texture:SetVertexColor(0.5, 0.5, 0.5, 1)
                icon:SetSize(12, 12)
                if icon.highlight then 
                     icon.highlight:SetAlpha(0)
                end
            else
                icon.texture:SetVertexColor(1, 1, 1, 1)
                icon:SetSize(20, 20)
                if icon.highlight then 
                    icon.highlight:SetVertexColor(1, 1, 1, 0.5)
                end
            end
        end

        local pos = plotInfo.mapPosition or plotInfo.MapPosition or plotInfo.position or plotInfo.location or plotInfo
        if pos and pos.mapPosition and type(pos.mapPosition) == "table" then
            pos = pos.mapPosition
        elseif pos and pos.MapPosition and type(pos.MapPosition) == "table" then
            pos = pos.MapPosition
        end

        local x = pos.x or pos.posX or pos.mapX or pos.left or pos[1]
        local y = pos.y or pos.posY or pos.mapY or pos.top or pos[2]

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
            if x > 1 or y > 1 then
            end
            
            local xPos = x * 750 + 25
            local yPos = -y * 550 - 25
            icon:SetPoint("TOPLEFT", xPos, yPos)
            icon:Show()
        else
            icon:Hide()
        end

        icon:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Plot ID: " .. (plotInfo.plotID or plotID or "N/A"))
            GameTooltip:AddLine("Owner: " .. (plotInfo.ownerName or "Unowned"))
            if not x or not y then
                GameTooltip:AddLine("|cFFFF0000(No Position Data)|r")
            end
            GameTooltip:Show()
        end)
        icon:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        icon:SetScript("OnClick", function(self)
            if not (plotInfo.ownerName and plotInfo.ownerName ~= "") then return end
            
            if not neighborhoodID then
                print("HouseReview Error: Could not determine current neighborhood when map was opened.")
                return
            end

            HouseReviewFrame.selectedNeighborhood = tostring(neighborhoodID)
            HouseReviewFrame.selectedPlot = tostring(plotInfo.plotID or plotID or "Unknown")
            HouseReviewFrame:Show()
            
            local ownerNameDisplay = plotInfo.ownerName or "Unknown"
            if ownerNameDisplay:find("-") then
                ownerNameDisplay = strsplit("-", ownerNameDisplay)
            end
            HouseReviewFrameTitle:SetText("Review for " .. ownerNameDisplay .. "'s Plot")
            
            HouseReview_UpdateReviewList()
            
            local playerHasReview = false
            local bnetAccountID
            if C_BattleNet and C_BattleNet.GetAccountInfo then
                _, _, bnetAccountID = C_BattleNet.GetAccountInfo()
            end
            local playerAccountID = bnetAccountID or UnitGUID("player")
            local reviews = (HouseReviewDB[HouseReviewFrame.selectedNeighborhood] and HouseReviewDB[HouseReviewFrame.selectedNeighborhood][HouseReviewFrame.selectedPlot]) or {}
            
            for _, review in ipairs(reviews) do
                 if type(review) == "table" and review.authorGUID == playerAccountID then
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
        local neighborhoodID
        if C_Housing and C_Housing.GetCurrentNeighborhoodGUID then
            neighborhoodID = C_Housing.GetCurrentNeighborhoodGUID()
        end

        if not neighborhoodID then
            print("HouseReview: You must be in a housing neighborhood to show the map.")
            return
        end
        
        -- Cache the ID
        HouseReview.currentNeighborhoodID = neighborhoodID
        
        HouseReview_UpdateMap()
        mapFrame:Show()
        print("HouseReview: Map shown.")
    end
end