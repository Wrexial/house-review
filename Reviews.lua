-- HouseReview Review System

function HouseReview_LikeReview(neighborhoodID, plotID, index)
    if not neighborhoodID or not plotID or not index then return end

    if not HouseReviewDB[neighborhoodID] or not HouseReviewDB[neighborhoodID][plotID] or not HouseReviewDB[neighborhoodID][plotID][index] then
        return
    end

    local entry = HouseReviewDB[neighborhoodID][plotID][index]
    
    -- Ensure entry is a table (migrate if needed)
    if type(entry) ~= "table" then
        entry = { text = entry, author = "Unknown", date = "", likes = 0, likedBy = {} }
        HouseReviewDB[neighborhoodID][plotID][index] = entry
    end
    
    if not entry.likes then entry.likes = 0 end
    if not entry.likedBy then entry.likedBy = {} end
    
    local bnetAccountID
    if C_BattleNet and C_BattleNet.GetAccountInfo then
        _, _, bnetAccountID = C_BattleNet.GetAccountInfo()
    end
    local playerAccountID = bnetAccountID or UnitGUID("player") -- Fallback

    if entry.likedBy[playerAccountID] then
        print("You have already liked this review on your account.")
        return
    end
    
    entry.likes = (entry.likes or 0) + 1
    entry.likedBy[playerAccountID] = true
    
    HouseReview_UpdateReviewList()
end

function HouseReview_UpdateReviewList()
    local neighborhoodID = HouseReviewFrame.selectedNeighborhood
    local plotID = HouseReviewFrame.selectedPlot
    local container = HouseReviewFrameScrollFrameReviewsContainer
    
    print(string.format("|cFFFFFF00HR Debug:|r UpdateReviewList - Loading for NeighborhoodID: %s, PlotID: %s", tostring(neighborhoodID), tostring(plotID)))

    if not container or not plotID or not neighborhoodID then return end
    
    -- Initialize row pool
    if not container.rows then container.rows = {} end
    for _, row in ipairs(container.rows) do row:Hide() end
    
    local reviews = (HouseReviewDB[neighborhoodID] and HouseReviewDB[neighborhoodID][plotID]) or {}

    -- Always request fresh data from the guild to reconcile reviews
    if HouseReview.Comms and HouseReview.Comms.Send then
        print("HouseReview: Requesting latest reviews from guild.")
        local payload = { neighborhood = neighborhoodID, plot = plotID }
        HouseReview.Comms:Send("REQ_REVIEWS", payload, "GUILD")
    end
    
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
    table.sort(displayList, function(a, b)
        local aLikes = 0
        if a.likedBy then
            for _ in pairs(a.likedBy) do aLikes = aLikes + 1 end
        end
        local bLikes = 0
        if b.likedBy then
            for _ in pairs(b.likedBy) do bLikes = bLikes + 1 end
        end
        return aLikes > bLikes
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
        
        local likeCount = 0
        if entry.likedBy then
            for _ in pairs(entry.likedBy) do
                likeCount = likeCount + 1
            end
        end
        row.likes:SetText(likeCount .. " Likes")
        
        -- Setup Button
        row.likeBtn:SetScript("OnClick", function()
             HouseReview_LikeReview(neighborhoodID, plotID, entry.originalIndex)
        end)
        
        -- Highlight if already liked?
        local bnetAccountID
        if C_BattleNet and C_BattleNet.GetAccountInfo then
            _, _, bnetAccountID = C_BattleNet.GetAccountInfo()
        end
        local playerAccountID = bnetAccountID or UnitGUID("player")
        if entry.likedBy and entry.likedBy[playerAccountID] then
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