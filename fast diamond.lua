local sampev = require("lib.samp.events")

local state = { active = false, target = 0, count = 0, pending = false, shopOpened = false }

local function sendCEF(str)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt16(bs, #str)
    raknetBitStreamWriteString(bs, str)
    raknetBitStreamWriteInt32(bs, 0)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

function sampev.onShowDialog(id, _, title, _, _, text)
    if not state.active then return end

    local clearTitle = title:gsub("{%x%x%x%x%x%x}", "")
    local clearText  = text:gsub("{%x%x%x%x%x%x}", "")

    if clearTitle:find("Панель администратора", 1, true) then
        local idx = 0
        local targetStr = ""
        for line in clearText:gmatch("[^\r\n]+") do
            if line:find("Админ%-магазин") then
                targetStr = line
                break
            end
            idx = idx + 1
        end

        lua_thread.create(function()
            wait(20)
            sampSendDialogResponse(id, 1, idx, targetStr)
            state.shopOpened = true
        end)
        return false
    end

    if clearTitle:find("Покупка предмета", 1, true) and clearText:find("Алмазный камень", 1, true) then
        lua_thread.create(function()
            wait(20)
            sampSendDialogResponse(id, 1, 0, "")
        end)
        return false
    end

    if clearText:find("Вы успешно купили Алмазный камень", 1, true) then
        lua_thread.create(function()
            wait(20)
            sampSendDialogResponse(id, 1, 0, "")
            state.count = state.count + 1
            state.pending = false

            if state.count % 5 == 0 or state.count == state.target then
                sampAddChatMessage(string.format("Куплено: %d/%d", state.count, state.target), -1)
            end
        end)
        return false
    end
end

function main()
    while not isSampLoaded() do wait(100) end

    sampRegisterChatCommand("ak", function(arg)
        if state.active then
            state.active = false
            sampAddChatMessage("Остановлено. Куплено: " .. state.count, -1)
            return
        end

        local count = tonumber(arg)
        if not count or count <= 0 then
            return sampAddChatMessage("/ak [кол-во]", -1)
        end

        state.active = true
        state.target = math.floor(count)
        state.count = 0
        state.pending = false
        state.shopOpened = false

        lua_thread.create(function()
            sampSendChat("/apanel")

            local t = os.clock()
            while not state.shopOpened and (os.clock() - t < 3.0) and state.active do
                wait(50)
            end

            if not state.shopOpened then
                sampAddChatMessage("Не удалось открыть Админ-магазин", -1)
                state.active = false
                return
            end

            wait(800)

            while state.active and state.count < state.target do
                state.pending = true
                sendCEF('clickOnBlock|{"slot": 2, "type": 16}')

                local waitTimer = os.clock()
                while state.pending and state.active and (os.clock() - waitTimer < 2.5) do
                    wait(20)
                end
                wait(500)
            end

            if state.active then
                sampAddChatMessage("Куплено: " .. state.count .. " шт.", -1)
            end
            state.active = false
        end)
    end)
    wait(-1)
end