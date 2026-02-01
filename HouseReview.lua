-- HouseReview.lua
HouseReview = {} -- Main addon table

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
        if HouseReviewMapFrame and HouseReviewMapFrame:IsShown() then
            HouseReview_UpdateMap()
        end
    end
end)