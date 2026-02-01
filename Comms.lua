-- HouseReview Communication System
HouseReview.Comms = {}

local Comms = HouseReview.Comms
local ADDON_PREFIX = "HRV01" -- HouseReview Version 1

local commsFrame = CreateFrame("Frame", "HouseReviewCommsFrame")

-- This serializer handles the types of data we expect in a review
-- (strings, numbers, booleans, and non-recursive tables).
function Comms:Serialize(data)
    if type(data) == "string" then
        return ("%q"):format(data)
    elseif type(data) == "number" or type(data) == "boolean" then
        return tostring(data)
    elseif type(data) == "table" then
        local parts = {}
        local isArray = #data > 0

        if isArray then -- Simple array
            for i = 1, #data do
                table.insert(parts, Comms:Serialize(data[i]))
            end
        else -- Hash table
            for k, v in pairs(data) do
                if type(k) == "string" then
                    table.insert(parts, string.format("[%q]=%s", k, Comms:Serialize(v)))
                end
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    else
        return "nil"
    end
end

-- Deserializes a string back into a Lua table/value
function Comms:Deserialize(str)
    if not str or str == "" then return nil end
    local func, err = load("return " .. str)
    if not func then
        print("HouseReview Comms Error: Could not deserialize string: " .. tostring(err))
        return nil
    end
    local success, data = pcall(func)
    if not success then
        print("HouseReview Comms Error: Deserialization failed: " .. tostring(data))
        return nil
    end
    return data
end

-- Sends a message to the specified channel.
-- Messages are limited in length, so we check that before sending.
function Comms:Send(command, payload, channel, target)
    local serializedPayload = self:Serialize(payload)
    local message = command .. "|" .. (serializedPayload or "nil")

    if #message > 250 then
        print("HouseReview Comms Error: Message too long to send.")
        return
    end

    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, message, channel, target)
end

-- Handles all incoming addon messages
function Comms:OnCommReceived(prefix, message, channel, sender)
    if prefix ~= ADDON_PREFIX then return end

    local command, payload = message:match("([^|]+)|(.*)")
    if not command then return end
    
    local data = self:Deserialize(payload)
    if not data then return end -- Deserialization failed, abort

    if command == "REQ_REVIEWS" then
        local neighborhood = tostring(data.neighborhood)
        local plot = tostring(data.plot)
        
        if HouseReviewDB[neighborhood] and HouseReviewDB[neighborhood][plot] then
            print("HouseReview: Received request for reviews for " .. plot .. " from " .. sender .. ". Sending our data.")
            local responsePayload = {
                neighborhood = neighborhood,
                plot = plot,
                reviews = HouseReviewDB[neighborhood][plot]
            }
            -- Whisper the data back to the person who asked
            self:Send("REVIEW_DATA", responsePayload, "WHISPER", sender)
        end

    elseif command == "REVIEW_DATA" then
        local incomingReviews = data.reviews
        local neighborhood = tostring(data.neighborhood)
        local plot = tostring(data.plot)
        
        if not HouseReviewDB[neighborhood] then HouseReviewDB[neighborhood] = {} end
        if not HouseReviewDB[neighborhood][plot] then HouseReviewDB[neighborhood][plot] = {} end
        
        local localReviews = HouseReviewDB[neighborhood][plot]
        local existingAuthors = {}
        for _, review in ipairs(localReviews) do
            if review.authorGUID then
                existingAuthors[review.authorGUID] = true
            end
        end
        
        local newDataAdded = false
        for _, incomingReview in ipairs(incomingReviews) do
            if incomingReview.authorGUID and not existingAuthors[incomingReview.authorGUID] then
                table.insert(localReviews, incomingReview)
                newDataAdded = true
            end
        end
        
        if newDataAdded then
            print("HouseReview: Merged new review data for plot " .. plot .. " from " .. sender)
            -- If we are currently viewing that plot, refresh the list
            if HouseReviewFrame:IsShown() and HouseReviewFrame.selectedNeighborhood == neighborhood and HouseReviewFrame.selectedPlot == plot then
                HouseReview_UpdateReviewList()
            end
        end

    elseif command == "NEW_REVIEW" then
        local reviewData = data.review
        local neighborhood = tostring(data.neighborhood)
        local plot = tostring(data.plot)
        
        if not HouseReviewDB[neighborhood] then HouseReviewDB[neighborhood] = {} end
        if not HouseReviewDB[neighborhood][plot] then HouseReviewDB[neighborhood][plot] = {} end
        
        -- Check for duplicates before adding
        local found = false
        for _, existingReview in ipairs(HouseReviewDB[neighborhood][plot]) do
            if existingReview.authorGUID == reviewData.authorGUID then
                found = true; break;
            end
        end
        
        if not found then
            table.insert(HouseReviewDB[neighborhood][plot], reviewData)
            print("HouseReview: Received new review for plot " .. plot .. " from " .. sender)
            if HouseReviewFrame:IsShown() and HouseReviewFrame.selectedNeighborhood == neighborhood and HouseReviewFrame.selectedPlot == plot then
                HouseReview_UpdateReviewList()
            end
        end
    end
end

-- Initializes the comms system by registering the prefix and event handler
function Comms:Init()
    C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
    commsFrame:RegisterEvent("CHAT_MSG_ADDON")
    commsFrame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
        if event == "CHAT_MSG_ADDON" then
            Comms:OnCommReceived(prefix, message, channel, sender)
        end
    end)
    print("HouseReview Comms Initialized.")
end
