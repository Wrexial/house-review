-- HouseReview Debug Tools

-- Debug command to check API availability and data
SLASH_HOUSEREVIEWDEBUG1 = "/hrdebug"
SlashCmdList["HOUSEREVIEWDEBUG"] = function(msg)
    print("|cFFFFFF00HouseReview Debug:|r")
    
    -- Check C_Housing API for neighborhood ID
    if C_Housing and C_Housing.GetCurrentNeighborhoodGUID then
        print(" - C_Housing.GetCurrentNeighborhoodGUID: |cFF00FF00FOUND|r")
        local neighborhoodID = C_Housing.GetCurrentNeighborhoodGUID()
        if neighborhoodID then
            print("   - Current Neighborhood ID: " .. tostring(neighborhoodID))

            if C_Housing.GetUIMapIDForNeighborhood then
                local mapID = C_Housing.GetUIMapIDForNeighborhood(neighborhoodID)
                print("   - C_Housing.GetUIMapIDForNeighborhood returned Map ID: " .. tostring(mapID))
            else
                print("   - C_Housing.GetUIMapIDForNeighborhood: |cFFFF0000MISSING|r")
            end
        else
            print("   - C_Housing.GetCurrentNeighborhoodGUID: |cFFFF0000NIL|r")
        end
    else
        print(" - C_Housing.GetCurrentNeighborhoodGUID: |cFFFF0000MISSING|r")
    end

    if not C_HousingNeighborhood then
        print(" - C_HousingNeighborhood: |cFFFF0000MISSING|r")
    else
        print(" - C_HousingNeighborhood: |cFF00FF00FOUND|r")
        local data = C_HousingNeighborhood.GetNeighborhoodMapData()
        if data then
            print(" - GetNeighborhoodMapData: |cFF00FF00DATA RETURNED|r")
            if type(data) == "table" then
                 print("   - Full Data Dump:")
                 for k,v in pairs(data) do
                     print(string.format("     - %s (%s): %s", tostring(k), type(v), tostring(v)))
                 end
            end
            
            local count = 0
            local plots = data.neighborhoodPlots or data.plots or (type(data) == "table" and data)
            if plots and type(plots) == "table" then
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

-- Slash command to dump all data
SLASH_HOUSEREVIEWDUMP1 = "/hrdump"
SlashCmdList["HOUSEREVIEWDUMP"] = function(msg)
    print("|cFFFFFF00HouseReview Data Dump:|r")
    if not HouseReviewDB or next(HouseReviewDB) == nil then
        print(" - Database is empty.")
        return
    end

    for neighborhoodID, plots in pairs(HouseReviewDB) do
        print(string.format("|cFF00FFFFNeighborhood:|r %s", tostring(neighborhoodID)))
        if type(plots) == "table" and next(plots) then
            for location, reviews in pairs(plots) do
                print(string.format("  |cFF00CCFFPlot:|r %s", tostring(location)))
                if type(reviews) == "table" and #reviews > 0 then
                    for i, entry in ipairs(reviews) do
                        if type(entry) == "table" then
                            local author = entry.author or "Unknown"
                            local date = entry.date or "No Date"
                            local text = entry.text or ""
                            
                            local likeCount = 0
                            local likedByStr = ""
                            if type(entry.likedBy) == "table" then
                                for guid in pairs(entry.likedBy) do
                                    likeCount = likeCount + 1
                                    likedByStr = likedByStr .. guid .. ", "
                                end
                                if likedByStr ~= "" then
                                    likedByStr = likedByStr:sub(1, -3) -- Trim trailing comma and space
                                end
                            end

                            print(string.format("    [%d] |cFFDDDDDDAuthor:|r %s (%s)", i, author, date))
                            print(string.format("        |cFFDDDDDDReview:|r \"%s\"", text))
                            print(string.format("        |cFF00FF00Likes:|r %d (%s)", likeCount, likedByStr))
                        else
                            print(string.format("    [%d] Invalid review entry (not a table)", i))
                        end
                    end
                else
                    print("    - No reviews for this plot.")
                end
            end
        else
            print("  - No plots in this neighborhood.")
        end
    end
end