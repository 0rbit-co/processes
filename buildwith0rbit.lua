-- processId: QQchTCEkPhnIu9dDSFyfR9-8mG-ftAkPt7Xs3AhtBjA
-- processName: buildWith0rbit
-- dev: @megabyte0x

Requests = Requests or {}

ACCEPTED_REQUESTS = ACCEPTED_REQUESTS or {}

function _ownerCheck(msg)
    if (msg.From ~= ao.id) then
        Handlers.utils.reply(Colors.red ..
            "You are not authorized to perform this action.")(msg)
        return false
    end
    return true
end

function addRequest(msg)
    if Requests[msg.From] then
        if (Requests[msg.From].request_processed == false) then
            Handlers.utils.reply(Colors.blue ..
                "You have already submitted a request. Please wait for the team to reach out to you.")(msg)
        elseif (Requests[msg.From].request_rejected == true) then
            Handlers.utils.reply(Colors.red ..
                "Your request has been rejected.")(msg)
        end
        return
    end

    local twitter = msg.Twitter
    local discord = msg.Discord
    local project_name = msg.Project_Name
    local project_description = msg.Project_Description
    local project_requirement = msg.Project_Requirement
    local no_of_0RBT_requested = msg.Request_Amount
    local recepient_wallet = msg.Recepient_Wallet

    Requests[msg.From] = {
        twitter = twitter,
        discord = discord,
        project_name = project_name,
        project_description = project_description,
        project_requirement = project_requirement,
        no_of_0RBT_requested = no_of_0RBT_requested,
        recepient_wallet = recepient_wallet,
        request_processed = false,
        request_rejected = false
    }

    Handlers.utils.reply(Colors.green ..
        "Your response is recorded. " ..
        Colors.red ..
        "No Action is Required from your end." .. "\n" .. Colors.blue .. "Our Team will reach out to you soon")(
            msg)
end

function rejectRequest(msg)
    if not _ownerCheck(msg) then
        return
    end

    local requestId = msg.RequestId
    if not Requests[requestId] then
        Handlers.utils.reply(Colors.red ..
            "No request found with the given ID.")(msg)
        return
    end

    Requests[requestId].request_rejected = true
    Handlers.utils.reply(Colors.red ..
        "Request " .. requestId .. "  has been rejected.")(msg)
end

function acceptRequest(msg)
    if not _ownerCheck(msg) then
        return
    end

    local requestId = msg.RequestId
    if not Requests[requestId] then
        Handlers.utils.reply(Colors.red ..
            "No request found with the given ID.")(msg)
        return
    end

    Requests[requestId].request_processed = true

    ACCEPTED_REQUESTS[requestId] = Requests[requestId]
    Requests[requestId] = nil

    Handlers.utils.reply(Colors.green ..
        "Request " .. requestId .. " has been accepted.")(msg)
end

function deleteRequest(msg)
    if not _ownerCheck(msg) then
        return
    end

    local requestId = msg.RequestId
    if not Requests[requestId] then
        Handlers.utils.reply(Colors.red ..
            "No request found with the given ID.")(msg)
        return
    end

    Requests[requestId] = nil
    Handlers.utils.reply(Colors.gray ..
        "Request " .. requestId .. " has been deleted.")(msg)
end

function info(msg)
    local info = "A form to request 0RBT Points. " ..
        "Please fill the form to request 0RBT Points. " ..
        "The team will reach out to you soon. " .. "Sample request format: " ..
        "Send({" ..
        "    Target = 'Kq_zJt98an1n9zOp2c82Vh3CBQcfRXVpPk940bd6N7U'," ..
        "    Action = 'Build-With-0rbit'," ..
        "    Twitter = 'Your Twitter Handle (ex. @megabyte0x)'," ..
        "    Discord = 'Your Discord Handle (ex. megabyte0x)'," ..
        "    Project_Name = 'Your Project Name (ex. 0rbit)'," ..
        "    Project_Description = 'Your Project Description (ex. The Decentralised Oracle Network on Arweave built using AO)'," ..
        "    Project_Requirement = 'Your project requirement for 0rbit (ex. Getting stock prices to build a prediction model)'," ..
        "    Request_Amount = 'Amount of 0RBT requested (ex. 1000)'," ..
        "    Recepient_Wallet = 'Your Arweave Wallet Address (ex. Pw6aamwaKdmlkgKMNLX1ekzvyBPO8r-S4QhIpL34QVw)'" ..
        "})"
    Handlers.utils.reply(Colors.blue .. info)(msg)

    Send({ Target = msg.From, Data = info })
end

Handlers.add(
    "CreateRequest",
    Handlers.utils.hasMatchingTag("Action", "Build-With-0rbit"),
    addRequest
)

Handlers.add(
    "RejectRequest",
    Handlers.utils.hasMatchingTag("Action", "Reject-Request"),
    rejectRequest
)

Handlers.add(
    "AcceptRequest",
    Handlers.utils.hasMatchingTag("Action", "Accept-Request"),
    acceptRequest
)

Handlers.add(
    "DeleteRequest",
    Handlers.utils.hasMatchingTag("Action", "Delete-Request"),
    deleteRequest
)

Handlers.add(
    "Info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    info
)

--[[
Sample Request

    Send({
        Target = "QQchTCEkPhnIu9dDSFyfR9-8mG-ftAkPt7Xs3AhtBjA",
        Action = "Build-With-0rbit",
        Twitter = "Your Twitter Handle (ex. @megabyte0x)",
        Discord = "Your Discord Handle (ex. megabyte0x)",
        Project_Name = "Your Project Name (ex. 0rbit)",
        Project_Description = "Your Project Description (ex. The Decentralised Oracle Network on Arweave built using AO)",
        Project_Requirement = "Your project requirement for 0rbit (ex. Getting stock prices to build a prediction model)",
        Request_Amount = "Amount of 0RBT requested (ex. 1000)",
        Recepient_Wallet = "Your Arweave Wallet Address (ex. Pw6aamwaKdmlkgKMNLX1ekzvyBPO8r-S4QhIpL34QVw)"
    })

]]
