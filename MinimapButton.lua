-- HouseReview Minimap Button

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")

        HouseReviewDB = HouseReviewDB or {}
        HouseReviewDB.minimap = HouseReviewDB.minimap or { angle = 2.3 }

        local button = CreateFrame("Button", "HouseReviewMinimapButton", Minimap)
        button:SetSize(32, 32)
        button:SetFrameStrata("MEDIUM")

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture("Interface\\Icons\\inv_misc_house")
        icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

        local border = button:CreateTexture(nil, "OVERLAY")
        border:SetSize(53, 53)
        border:SetPoint("CENTER")
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("HouseReview")
            GameTooltip:AddLine("|cFFDDDDDDClick to toggle the map.|r")
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)

        button:RegisterForDrag("LeftButton")
        button:SetScript("OnDragStart", function(self)
            self:StartMoving()
            self.isMoving = true
        end)

        button:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            self.isMoving = false
            
            local minimapX, minimapY = Minimap:GetCenter()
            local buttonX, buttonY = self:GetCenter()
            
            local angle = atan2(buttonY - minimapY, buttonX - minimapX)
            HouseReviewDB.minimap.angle = angle
            
            local radius = 78
            self:ClearAllPoints()
            self:SetPoint("CENTER", Minimap, "CENTER", radius * cos(angle), radius * sin(angle))
        end)

        button:SetScript("OnClick", function(self)
            if self.isMoving then return end
            if HouseReviewMapFrame:IsShown() then
                HouseReviewMapFrame:Hide()
            else
                local neighborhoodID
                if C_Housing and C_Housing.GetCurrentNeighborhood then
                    neighborhoodID = C_Housing.GetCurrentNeighborhood()
                end

                if not neighborhoodID then
                    print("HouseReview: You must be in a housing neighborhood to show the map.")
                    return
                end
                
                -- Cache the ID
                HouseReview.currentNeighborhoodID = neighborhoodID

                HouseReview_UpdateMap()
                HouseReviewMapFrame:Show()
            end
        end)
        
        local radius = 78
        button:SetPoint("CENTER", Minimap, "CENTER", radius * cos(HouseReviewDB.minimap.angle), radius * sin(HouseReviewDB.minimap.angle))
    end
end)