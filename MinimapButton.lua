-- HouseReview Minimap Button using LibDataBroker

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")

        HouseReviewDB = HouseReviewDB or {}
        HouseReviewDB.minimap = HouseReviewDB.minimap or {}

        local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
        if not ldb then return end

        local dataobj = ldb:NewDataObject("HouseReview", {
            type = "launcher",
            icon = "Interface\\AddOns\\HouseReview\\Media\\minimap-icon.tga",
            label = "House Review",
            OnClick = function(_, button)
                if button == "LeftButton" then
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
                end
            end,
            OnTooltipShow = function(tooltip)
                if not tooltip or not tooltip.AddLine then return end
                tooltip:AddLine("HouseReview")
                tooltip:AddLine("|cffeda55fClick|r to toggle the map.")
            end
        })

        local icon = LibStub("LibDBIcon-1.0", true)
        if icon then
            icon:Register("HouseReview", dataobj, HouseReviewDB.minimap)
        end
    end
end)
