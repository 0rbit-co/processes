_VERSION = "0.1.1"

local json = require('json')
local bint = require('.bint')(256)

_MIN_FEE = bint(2 * 1e11)
_MAX_FEE = bint(1e12)
_FREE_CREDITS = 5
_TOKEN_PROCESS = "BUhZLMwQ6yZHguLtJYA5lLUa9LQzLXMXRfaq9FVcPJc"

BOTTLENECK = GET_REQUESTS
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
    end,
    mergeTables = function(t1, t2)
        for key, value in pairs(t2) do
            t1[key] = value -- Overwrites existing key in t1 if it exists
        end
        return t1
    end

}

function isGetRequest(Msg)
    if Msg.From == _TOKEN_PROCESS and Msg.Action == "Credit-Notice" and Msg["X-Action"] == "Get-Real-Data" then
        return true
    else
        return false
    end
end

function isPostRequest(Msg)
    if Msg.From == _TOKEN_PROCESS and Msg.Action == "Credit-Notice" and Msg["X-Action"] == "Post-Real-Data" then
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
        local headers = Msg.Tags["X-Headers"] or nil
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
        local validFor = tags["X-ValidFor"] or 0

        local sender = tags.Sender
        local url = tags["X-Url"]

        if IS_ERROR == 1 then
            Send({
                Target = sender,
                Data = Colors.red ..
                    "MAINTAINANCE: Some issue going on with process" ..
                    Colors.green ..
                    " Contact 0RBIT team"
            })
            Send({
                Target = _TOKEN_PROCESS,
                Action = "Transfer",
                Recipient = sender,
                Quantity = utils.toBalanceValue(recievedFee)
            })
            return
        end

        -- Check maxFee with Quantity
        if utils.lt(recievedFee, maxFee) then
            Send({
                Target = sender,
                Data = Colors.red ..
                    "ERROR: Transferred less fee than maxFee" ..
                    Colors.green ..
                    " Recieved:" ..
                    utils.toBalanceValue(recievedFee) .. Colors.red .. " Expected:" .. utils.toBalanceValue(maxFee)
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
            Headers = headers or nil,
            Target = ao.id
        }
        Send({
            Target = sender,
            RequestId = msgId,
            Data = "Message recieved for url:" .. url .. "\n MsgId:" .. msgId
        })

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

-- [[ Create Handler to accept 0rbit Token and add request to GET_REQUESTS ]]
Handlers.add('postData',
    isPostRequest,
    function(Msg)
        local msgId = Msg.Id
        local tags = Msg.Tags
        -- -- check timeperiod /timestamp
        local recievedFee = bint(tags.Quantity) or bint.zero()
        local headers = Msg.Tags["X-Headers"] or nil

        -- Convert 'tags["X-Min-Fee"]' to a bigint and use '_MIN_FEE' as a default if 'tags["X-Min-Fee"]' is nil
        local minFee = tags["X-Min-Fee"] and bint(tags["X-Min-Fee"]) or _MIN_FEE

        -- Convert 'tags["X-Max-Fee"]' to a bigint and use '_MAX_FEE' as a default if 'tags["X-Max-Fee"]' is nil
        local maxFee = tags["X-Max-Fee"] and bint(tags["X-Max-Fee"]) or _MAX_FEE

        local body = Msg.Tags["X-Body"] or nil

        local validFor = tags["X-ValidFor"] or 0

        local sender = tags.Sender
        local url = tags["X-Url"]

        if IS_ERROR == 1 then
            Send({
                Target = sender,
                Data = Colors.red ..
                    "MAINTAINANCE: Some issue going on with process" ..
                    Colors.green ..
                    " Contact 0RBIT team"
            })
            Send({
                Target = _TOKEN_PROCESS,
                Action = "Transfer",
                Recipient = sender,
                Quantity = utils.toBalanceValue(recievedFee)
            })
            return
        end

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
                    "ERROR: Transferred less fee than maxFee" ..
                    Colors.green ..
                    " Recieved:" ..
                    utils.toBalanceValue(recievedFee) .. Colors.red .. " Expected:" .. utils.toBalanceValue(maxFee)
            })
            Send({
                Target = _TOKEN_PROCESS,
                Action = "Transfer",
                Recipient = sender,
                Quantity = utils.toBalanceValue(recievedFee)
            })
            return
        end

        POST_REQUESTS[msgId] = {
            Url = url,
            MinFee = utils.toBalanceValue(minFee),
            MaxFee = utils.toBalanceValue(maxFee),
            ValidFor = validFor,
            Timestamp = Msg.Timestamp,
            Recipient = sender,
            Body = body or nil,
            Headers = headers or nil,
            Target = ao.id
        }
        Send({
            Target = sender,
            RequestId = msgId,
            Data = "Message recieved for url:" .. url .. "\n MsgId:" .. msgId
        })

        table.insert(LOGS, {
            MessageId = Msg.Id,
            Recipient = sender,
        })
    end
)

Handlers.add(
    "dryrunPost",
    Handlers.utils.hasMatchingTag("Read", "POST_REQUESTS"),
    function(msg)
        Handlers.utils.reply(json.encode(POST_REQUESTS))(msg)
    end
)

Handlers.add('recieveData',
    Handlers.utils.hasMatchingTag('Action', 'Receive-Response')
    -- add check for valid node or not
    ,
    function(Msg)
        local tags = Msg.Tags
        local requestId = tags["Request-Msg-Id"]
        -- First we will check processed request to make sure someone hasn't answeered already
        if PROCESSED_REQUESTS[requestId] then
            Handlers.utils.reply("ID:" .. requestId .. "Request has already been processed")(Msg)
            table.insert(LOGS, {
                MessageId = Msg.Id,
                Status = "PROCESSED"
            })
            return
        end
        if not (GET_REQUESTS[requestId] or POST_REQUESTS[requestId]) then
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

        if utils.toNumber(tags.Fee) > utils.toNumber(request.MaxFee) then
            Handlers.utils.reply("ID:" .. requestId .. "Fees asked is greater than the suggested range by the user")(Msg)
            table.insert(LOGS, {
                MessageId = Msg.Id,
                Status = "MAX_FEE_EXCEEDED"
            })
            return
        end
        if request.ValidFor ~= 0 then
            local expirationTime = request.Timestamp + request.ValidFor
            if Msg.Timestamp > expirationTime then
                FAILED_REQUESTS[requestId] = GET_REQUESTS[requestId]
                GET_REQUESTS[requestId] = nil
                -- TODO: MAKE FUBNCTIONALITY IN NODE TO READ THIS MESSAGE
                Handlers.utils.reply("ID:" .. requestId .. "Request has been timedout")(Msg)
                table.insert(LOGS, {
                    MessageId = Msg.Id,
                    Status = "TIMEDOUT"
                })
                return
            end
        end
        -- Verify data logic will come here
        -- Rewarding node logic will come here and for FREE_QUOTA reward will be sent from
        local responseMessage = {
            Target = request.Recipient,
            Data = Msg.Data,
            FeeUsed = tags.Fee,
            RequestId = requestId,
            -- add other tags that is needed also add headers
        }
        utils.mergeTables(responseMessage, Msg.Tags)
        responseMessage["Request-Msg-Id"] = nil
        Send(responseMessage)
        -- Transfer back the remaining amount
        PROCESSED_REQUESTS[requestId] = {
            ResponseMsg = Msg.Id,
            RequestMsg = request,
            Fee = tags.Fee,
            -- TimeTaken = Msg.Timestamp - (request.ValidFor + request.Timestamp)
        }
        GET_REQUESTS[requestId] = nil
        POST_REQUESTS[requestId] = nil
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
-- Send({
--     Target = "BUhZLMwQ6yZHguLtJYA5lLUa9LQzLXMXRfaq9FVcPJc",
--     Action = "Transfer",
--     Recipient = "BaMK1dfayo75s3q1ow6AO64UDpD9SEFbeE8xYrY2fyQ",
--     Quantity = "1000000000000",
--     ["X-Url"] = "https://g8way.0rbit.co/",
--     ["X-Action"] = "Get-Real-Data"
-- })

-- local json = require('json')
-- Send({
--     Target = "BUhZLMwQ6yZHguLtJYA5lLUa9LQzLXMXRfaq9FVcPJc",
--     Action = "Transfer",
--     Recipient = "BaMK1dfayo75s3q1ow6AO64UDpD9SEFbeE8xYrY2fyQ",
--     Quantity = "1000000000000",
--     ["X-Url"] = "https://g8way.0rbit.co/graphql",
--     ["X-Action"] = "Post-Real-Data",
--     ["X-Body"] = json.encode({
--         query = [[
--             query {
--                 transactions(
--                     owners: ["vh-NTHVvlKZqRxc8LyyTNok65yQ55a_PJ1zWLb9G2JI"]
--                 ) {
--                     edges {
--                         node {
--                             id
--                         }
--                     }
--                 }
--             }
--         ]]
--     })

-- })
count = 0
for key, value in pairs(PROCESSED_REQUESTS) do
    count = count + 1
end

Send({
    Target = "W1fgVvCJB2BI0BWOhmvJfN-3-Q-xyglE4Mi5bpmE2n4",
    Test = "Hi",
    Data = "Testing assign"
})
Send({
    Target = "BUhZLMwQ6yZHguLtJYA5lLUa9LQzLXMXRfaq9FVcPJc",
    Action = "Transfer",
    Recipient = "mJ7XVag8KwXkHiYDipJjj0CEliavcDJfcqNtGRLm9nQ",
    Quantity = "100000000000000"
})
Send({
    Target = "BUhZLMwQ6yZHguLtJYA5lLUa9LQzLXMXRfaq9FVcPJc",
    Action = "Balance"
})
