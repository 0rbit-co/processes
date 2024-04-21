_VERSION = "0.1.0"

local json = require('json')
local bint = require('.bint')(256)

_MIN_FEE = bint(2 * 1e11)
_MAX_FEE = bint(2 * 1e12)
_FREE_CREDITS = 50
_TOKEN_PROCESS = "BUhZLMwQ6yZHguLtJYA5lLUa9LQzLXMXRfaq9FVcPJc"

GET_REQUESTS = GET_REQUESTS or {}
POST_REQUESTS = POST_REQUESTS or {}
PROCESSED_REQUESTS = PROCESSED_REQUESTS or {}
FAILED_REQUESTS = FAILED_REQUESTS or {}

IS_ERROR = IS_ERROR or 0

FREE_QUOTA = FREE_QUOTA or {}
LOGS = LOGS or {}

local utils = {
    add = function(a, b)
        return tostring(bint(a) + bint(b))
    end,
    subtract = function(a, b)
        return tostring(bint(a) - bint(b))
    end,
    toBalanceValue = function(a)
        return tostring(bint(a))
    end,
    toNumber = function(a)
        return tonumber(a)
    end,
    lt = function(a, b)
        return bint.__lt(a, b)
    end
}

function isGetRequest(Msg)
    if Msg.From == _TOKEN_PROCESS and Msg.Action == "Credit-Notice" and Msg["X-Action"] == "Get-Real-Data" then
        return true
    else
        return false
    end
end

function isValidUrl(url)
    -- This pattern checks for the following format: scheme://domain/path?query#fragment
    local pattern = "^(https):\\/\\/[^ \"]+$"
    if string.match(url, pattern) then
        return true
    else
        return false
    end
end

-- [[ Create Handler to accept 0rbit Token and add request to GET_REQUESTS ]]
Handlers.add('getData',
    isGetRequest,
    function(Msg)
        local msgId = Msg.Id
        local tags = Msg.Tags
        -- -- check timeperiod /timestamp
        local recievedFee = bint(tags.Quantity) or bint.zero()
        -- local minFee = bint(tags["X-Min-Fee"]) or _MIN_FEE
        local minFee
        if tags["X-Min-Fee"] ~= nil then
            minFee = bint(tags["X-Min-Fee"])
        else
            minFee = _MIN_FEE
        end
        -- local maxFee = bint(tags["X-Max-Fee"]) or _MAX_FEE
        local maxFee
        if tags["X-Max-Fee"] ~= nil then
            maxFee = bint(tags["X-Max-Fee"])
        else
            maxFee = _MAX_FEE
        end
        local validFor = tags.ValidFor or 0

        local sender = tags.Sender
        local url = tags["X-Url"]

        -- -- check url
        -- if not isValidUrl(url) then
        --     Send({
        --         Target = sender,
        --         Data = Colors.red ..
        --             "ERROR: URL sent is not valid"
        --     })
        --     Send({
        --         Target = _TOKEN_PROCESS,
        --         Action = "Transfer",
        --         Recipient = sender,
        --         Quantity = utils.toBalanceValue(recievedFee)
        --     })
        --     return
        -- end
        -- -- Check maxFee with Quantity
        if utils.lt(recievedFee, maxFee) then
            Send({
                Target = sender,
                Data = Colors.red ..
                    "ERROR: Transferred less fee than maxFee"
            })
            Send({
                Target = _TOKEN_PROCESS,
                Action = "Transfer",
                Recipient = sender,
                Quantity = utils.toBalanceValue(recievedFee)
            })
            return
        end

        GET_REQUESTS[msgId] = {
            Url = url,
            MinFee = utils.toBalanceValue(minFee),
            MaxFee = utils.toBalanceValue(maxFee),
            ValidFor = validFor,
            Timestamp = Msg.Timestamp,
            Recipient = sender,
            Target = ao.id
        }
        Handlers.utils.reply("Message recieved for url:" .. url)(Msg)

        table.insert(LOGS, {
            MessageId = Msg.Id,
            Recipient = sender,
        })
    end
)

Handlers.add(
    "dryrunGet",
    Handlers.utils.hasMatchingTag("Read", "GET_REQUESTS"),
    function(msg)
        Handlers.utils.reply(json.encode(GET_REQUESTS))(msg)
    end
)


Handlers.add('recieveData',
    Handlers.utils.hasMatchingTag('Action', 'Recieve-Response')
    -- add check for valid node or not
    ,
    function(Msg)
        local tags = Msg.Tags
        local requestId = tags["Request-Msg-Id"]
        -- First we will check processed request to make sure someone hasn't answeered already
        if not PROCESSED_REQUESTS[requestId] then
            Handlers.utils.reply("ID:" .. requestId .. "Request has already been processed")(Msg)
            table.insert(LOGS, {
                MessageId = Msg.Id,
                Status = "PROCESSED"
            })
            return
        end
        if not GET_REQUESTS[requestId] or not POST_REQUESTS[requestId] then
            Handlers.utils.reply("No request found with the Id of" .. requestId)(Msg)
            table.insert(LOGS, {
                MessageId = Msg.Id,
                Status = "NOT_FOUND"
            })
            return
        end
        local request

        if tags["Request-Type"] == "GET" then
            request = GET_REQUESTS[requestId]
        elseif tags["Request-Type"] == "POST" then
            request = POST_REQUESTS[requestId]
        end

        if tags.Fee > request.MaxFee then
            Handlers.utils.reply("ID:" .. requestId .. "Fees asked is greater than the suggested range by the user")(Msg)
            table.insert(LOGS, {
                MessageId = Msg.Id,
                Status = "MAX_FEE_EXCEEDED"
            })
            return
        end
        if Msg.Timestamp > (request.Timestamp + request.ValidFor) then
            FAILED_REQUESTS[requestId] = GET_REQUESTS[requestId]
            GET_REQUESTS[requestId] = nil
            Handlers.utils.reply("ID:" .. requestId .. "Request has been timedout")(Msg)
            table.insert(LOGS, {
                MessageId = Msg.Id,
                Status = "TIMEDOUT"
            })
            return
        end
        -- Verify data logic will come here
        -- Rewarding node logic will come here and for FREE_QUOTA reward will be sent from
        -- Transfer back the remaining amount
        Send({
            Target = request.Recipient,
            Data = Msg.Data,
            FeeUsed = tags.Fee
            -- add other tags that is needed also add headers
        })
        PROCESSED_REQUESTS[requestId] = {
            ResponseMsg = Msg.Id,
            RequestMsg = request,
            Fee = tags.Fee,
            TimeTaken = Msg.Timestamp - (request.ValidFor + request.Timestamp)
        }
        table.insert(LOGS, {
            MessageId = Msg.Id,
            Status = "SUCCESS"
        })
    end
)

-- [[ Create Handler to accept 0rbit Token and add request to POST_REQUESTS ]]
-- Handlers.add('postData',
--     Handlers.utils.hasMatchingTag('Action', 'Credit-Notice-For') and
--     -- Handlers.utils.hasMatchingTag('Action', 'Post-Data'),
--     function(Msg)
--         local prevTags = json.decode(Msg.PrevTags)
--         local msgId = Msg.Id
--         -- check url
--         -- check timeperiod /timestamp
--         local minFee = bint(prevTags.MinFee) or _MIN_FEE
--         local maxFee = bint(prevTags.MaxFee) or _MAX_FEE
--         local timeperiod = prevTags.Timeperiod or 0
--         POST_REQUESTS[msgId] = {
--             Url = prevTags.Url,
--             MinFee = minFee,
--             MaxFee = maxFee,
--             Timeperiod = timeperiod,
--             Recipient = prevTags.From,
--             To = ao.id,
--             RequestBody = prevTags.RequestBody,
--         }
--         Handlers.utils.reply("Message recieved for url:" .. prevTags.Url)(Msg)
--     end
-- )
-- Handlers.add(
--     "dryrunPost",
--     Handlers.utils.hasMatchingTag("Read", "POST_REQUESTS"),
--     function(msg)
--         Handlers.utils.reply(POST_REQUESTS)(msg)
--     end
-- )

-- [[ Create Handler for free tier to accept GET response from token contract(currently 0rbit only)]]

-- [[ Create Handler for free tier to accept POST response from token contract(currently 0rbit only)]]

-- [[ Create Handler to process GET response from the msg from the nodes and add reward to nodeWallet address]]

-- [[ Create Handler to accept POST response from token contract(currently 0rbit only) and add reward to nodeWallet address]]

-- [[ Distribute the rewards at a particular time ]]


-- Send({
--     Target = ao.id,
--     Action = "Transfer",
--     Quantity = "100",
--     Recipient = "WSXUI2JjYUldJ7CKq9wE1MGwXs-ldzlUlHOQszwQe0s",
--     Hello = "World",
--     Test = "1234",
--     ["X-Test"] = "456",
--     ["X-Hello"] = "World"
-- })
Send({
    Target = "BUhZLMwQ6yZHguLtJYA5lLUa9LQzLXMXRfaq9FVcPJc",
    Action = "Transfer",
    Recipient =
    "4_jJUtiNjq5Xrg8OMrEDo-_bud7p5vbSJh1e69VJ76U",
    Quantity = "1000000000000",
    ["X-Url"] = "https://www.google.com",
    ["X-Action"] = "Get-Real-Data"
})
