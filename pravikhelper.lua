local imgui = require 'mimgui'
local ffi = require 'ffi'
local encoding = require 'encoding'
local inicfg = require 'inicfg'
local requests = require 'requests'
local vkeys = require 'vkeys'
encoding.default = 'CP1251'
u8 = encoding.UTF8 

local sampev = require 'lib.samp.events'
local sampfuncs = require 'sampfuncs'
require "lib.moonloader"

local effil = require 'effil'

-- =========================
-- НАСТРОЙКИ СКРИПТА И КОНФИГ
-- =========================
local default_cfg = {
    config = {
        autouniform_enabled = true,
        autorunaway_enabled = true, 
        workSkinId = 57,
        autospawn_gov_enabled = false,
        autorec_enabled = false,
        autorec_spawn_target = 0,
        autorec_spawn_name = "", 
        autologin_enabled = false,
        autologin_password = "",
        bypass_esc_enabled = true,
		domkrat_bind_enabled = false,
        domkrat_hotkey = vkeys.VK_X, 
        fractionrp_cd_enabled = true,
        autophone_inc_enabled = true,
        autophone_out_enabled = true,
        autophone_inc_text = "напиши ало если сосал",
        autophone_out_text = "ало ну как там с деньгами",
        vc_form_enabled = true,
        fwarn_form_enabled = true,
        form_hotkey = vkeys.VK_F3,
        sbiv_chat_enabled = false,
        sbiv_chat_text = "я патрик",
        givecitizen_enabled = false,
		givesocial_enabled = false,
        givepass_enabled = false,
        tg_enabled = false,          
        tg_token = "",               
        tg_chat_id = 0,
        tg_custom_api_enabled = false, 
        tg_api_url = "https://tg-pravik-proxy.renaticus13.workers.dev/"
    },
    whitelist = {},
    spawn_list = {}
}

local cfg = inicfg.load(default_cfg, "PravikHelper.ini")
if not cfg then 
    cfg = default_cfg 
else
    cfg.config = cfg.config or {}
    cfg.whitelist = cfg.whitelist or {}
    cfg.spawn_list = cfg.spawn_list or {}
    for k, v in pairs(default_cfg.config) do
        if cfg.config[k] == nil then cfg.config[k] = v end
    end
end
inicfg.save(cfg, "PravikHelper.ini")

-- =========================
-- АВТООБНОВЛЕНИЕ СКРИПТА
-- =========================
local script_version = 1.0 
-- ЗАМЕНИ ЭТИ ССЫЛКИ НА СВОИ (RAW ссылки с GitHub)
local update_info_url = "https://raw.githubusercontent.com/ТВОЙ_НИК/ТВОЙ_РЕПОЗИТОРИЙ/main/version.json"
local script_url = "https://raw.githubusercontent.com/ТВОЙ_НИК/ТВОЙ_РЕПОЗИТОРИЙ/main/pravikhelper.lua"

function checkUpdates()
    async_http_request(update_info_url, function(response_text)
        if response_text and response_text ~= "" then
            local ok, data = pcall(decodeJson, response_text)
            if ok and data and data.version then
                if tonumber(data.version) > script_version then
                    sampAddChatMessage("[PravikHelper] {00FF00}Найдено обновление! Скачиваем новую версию...", -1)
                    addToast(u8"Найдено обновление! Скачиваем...", 2)
                    
                    downloadUrlToFile(script_url, thisScript().path, function(id, status, p1, p2)
                        if status == 58 then 
                            sampAddChatMessage("[PravikHelper] {00FF00}Обновление успешно загружено! Перезагружаю скрипт...", -1)
                            thisScript():reload()
                        elseif status == 73 then 
                            sampAddChatMessage("[PravikHelper] {FF0000}Произошла ошибка при скачивании обновления.", -1)
                            addToast(u8"Ошибка скачивания обновления", 3)
                        end
                    end)
                else
                    print("[PravikHelper] Установлена актуальная версия скрипта.")
                end
            end
        end
    end)
end

-- =========================
-- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ (MIMGUI)
-- =========================
local main_window_state = imgui.new.bool(false)
local last_frame_time = os.clock()
local selected_tab = 1
local show_forma_tab = true
local show_password_toggle = false 

local givesocial_enabled = imgui.new.bool(cfg.config.givesocial_enabled)
local givepass_enabled = imgui.new.bool(cfg.config.givepass_enabled)
local givecitizen_enabled = imgui.new.bool(cfg.config.givecitizen_enabled)
local fractionrp_enabled = imgui.new.bool(true)
local fractionrp_cd_enabled = imgui.new.bool(cfg.config.fractionrp_cd_enabled)
local autophone_inc_enabled = imgui.new.bool(cfg.config.autophone_inc_enabled)
local autophone_out_enabled = imgui.new.bool(cfg.config.autophone_out_enabled)
local autophone_inc_text = imgui.new.char[256](u8(tostring(cfg.config.autophone_inc_text)))
local autophone_out_text = imgui.new.char[256](u8(tostring(cfg.config.autophone_out_text)))
local vc_form_enabled = imgui.new.bool(cfg.config.vc_form_enabled)
local fwarn_form_enabled = imgui.new.bool(cfg.config.fwarn_form_enabled)
local form_hotkey = imgui.new.int(cfg.config.form_hotkey)
local is_binding_hotkey = false
local pending_form_type = nil
local pending_form_data = {}
local form_warning_time = 0
local last_invited_for_giverank_id = nil
local givepass_action_type = nil

local check_stroy_radius = imgui.new.float(20.0)
local punish_reason = imgui.new.char[256](u8"неявка в строй")
local punish_delay = imgui.new.int(4) 
local ignore_rank_8_plus = imgui.new.bool(true)
local ignore_2_fwarns = imgui.new.bool(true)
local is_checking_stroy = false
local nearby_players_list = {}
local current_punish_list = {}
local page_counter = 0
local whitelist_input = imgui.new.char[256]()
local show_whitelist = false 
local secret_click_count = 0     
local last_secret_click = 0     

local autouniform_enabled = imgui.new.bool(cfg.config.autouniform_enabled)
local autorunaway_enabled = imgui.new.bool(cfg.config.autorunaway_enabled)
local autospawn_gov_enabled = imgui.new.bool(cfg.config.autospawn_gov_enabled)
local autorec_enabled = imgui.new.bool(cfg.config.autorec_enabled)
local autologin_enabled = imgui.new.bool(cfg.config.autologin_enabled)
local autologin_password = imgui.new.char[128](u8(tostring(cfg.config.autologin_password)))
local workSkinId = imgui.new.int(cfg.config.workSkinId)
local autorec_spawn_target = imgui.new.int(0)
local parsed_spawn_list = {}
local pickupX, pickupY, pickupZ = 1497.1842, -1280.1366, 113.8064
local next_spawn_after_rec = false 
local is_initial_login = true 
local press_alt_sync = false 
local pending_login_notif = 0
local disable_col = false 
local collision_disabled_peds = {} 

local bypass_esc_enabled = imgui.new.bool(cfg.config.bypass_esc_enabled)
local domkrat_bind_enabled = imgui.new.bool(cfg.config.domkrat_bind_enabled)
local domkrat_hotkey = imgui.new.int(cfg.config.domkrat_hotkey)
local is_binding_domkrat = false
local isLocked = false
local sbiv_chat_enabled = imgui.new.bool(cfg.config.sbiv_chat_enabled)
local sbiv_chat_text = imgui.new.char[128](u8(tostring(cfg.config.sbiv_chat_text)))

local tg_enabled = imgui.new.bool(cfg.config.tg_enabled)
local tg_token = imgui.new.char[128](u8(tostring(cfg.config.tg_token)))
local tg_custom_api_enabled = imgui.new.bool(cfg.config.tg_custom_api_enabled)
local tg_api_url = imgui.new.char[256](u8(tostring(cfg.config.tg_api_url)))
local tg_chat_id = cfg.config.tg_chat_id
local last_update_id = 0
local is_polling = false
local reconnect_thread = nil
local last_tg_alert_time = 0

local vice_api = "https://api.arizona-five.com/launcher/servers"
local toasts = {}

-- =========================
-- УТИЛИТЫ И ФУНКЦИИ
-- =========================
function addToast(text, msgType, duration)
    table.insert(toasts, {
        text = text, 
        duration = duration or 7, 
        start = os.clock(), 
        type = msgType or 1
    })
end

function saveConfig()
    cfg.config.autouniform_enabled = autouniform_enabled[0]
    cfg.config.autorunaway_enabled = autorunaway_enabled[0] 
    cfg.config.autospawn_gov_enabled = autospawn_gov_enabled[0]
    cfg.config.autorec_enabled = autorec_enabled[0]
    cfg.config.autorec_spawn_name = parsed_spawn_list[autorec_spawn_target[0] + 1] or ""
    cfg.config.autologin_enabled = autologin_enabled[0]
    cfg.config.autologin_password = u8:decode(ffi.string(autologin_password))
    cfg.config.bypass_esc_enabled = bypass_esc_enabled[0]
	cfg.config.domkrat_bind_enabled = domkrat_bind_enabled[0]
    cfg.config.domkrat_hotkey = domkrat_hotkey[0]
    cfg.config.fractionrp_cd_enabled = fractionrp_cd_enabled[0]
    cfg.config.workSkinId = workSkinId[0]
    cfg.config.autophone_inc_enabled = autophone_inc_enabled[0]
    cfg.config.autophone_out_enabled = autophone_out_enabled[0]
    cfg.config.autophone_inc_text = u8:decode(ffi.string(autophone_inc_text))
    cfg.config.autophone_out_text = u8:decode(ffi.string(autophone_out_text))
    cfg.config.vc_form_enabled = vc_form_enabled[0]
    cfg.config.fwarn_form_enabled = fwarn_form_enabled[0]
    cfg.config.sbiv_chat_enabled = sbiv_chat_enabled[0]
    cfg.config.sbiv_chat_text = u8:decode(ffi.string(sbiv_chat_text))
    cfg.config.givecitizen_enabled = givecitizen_enabled[0]
    cfg.config.givesocial_enabled = givesocial_enabled[0]
    cfg.config.givepass_enabled = givepass_enabled[0]
    cfg.config.tg_enabled = tg_enabled[0]
    cfg.config.tg_token = u8:decode(ffi.string(tg_token))
    cfg.config.tg_custom_api_enabled = tg_custom_api_enabled[0]
    cfg.config.tg_api_url = u8:decode(ffi.string(tg_api_url))
    cfg.config.tg_chat_id = tg_chat_id
    inicfg.save(cfg, "PravikHelper.ini")
end

function apply_custom_style()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4

    style.FramePadding = imgui.ImVec2(4.0, 3.0)
    style.ItemInnerSpacing = imgui.ImVec2(4.0, 4.0)
    style.WindowRounding = 10.0
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ChildRounding = 8.0 
    style.FrameRounding = 6.0
    style.ItemSpacing = imgui.ImVec2(8.0, 8.0)
    style.ScrollbarSize = 13.0
    style.ScrollbarRounding = 0.0
    style.GrabMinSize = 8.0
    style.GrabRounding = 6.0
    style.WindowPadding = imgui.ImVec2(12.0, 12.0)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)

    colors[clr.Text]                   = ImVec4(0.95, 0.95, 0.95, 1.00)
    colors[clr.TextDisabled]           = ImVec4(0.50, 0.50, 0.50, 1.00)
    colors[clr.WindowBg]               = ImVec4(0.12, 0.12, 0.12, 1.00)
    colors[clr.ChildBg]                = ImVec4(0.15, 0.15, 0.15, 1.00)
    colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94)
    colors[clr.Border]                 = ImVec4(0.40, 0.40, 0.40, 0.50)
    colors[clr.FrameBg]                = ImVec4(0.20, 0.20, 0.20, 1.00)
    colors[clr.FrameBgHovered]         = ImVec4(0.25, 0.25, 0.25, 1.00)
    colors[clr.FrameBgActive]          = ImVec4(0.30, 0.30, 0.30, 1.00)
    colors[clr.TitleBg]                = ImVec4(0.10, 0.10, 0.10, 1.00)
    colors[clr.TitleBgActive]          = ImVec4(0.15, 0.15, 0.15, 1.00)
    colors[clr.Button]                 = ImVec4(0.30, 0.30, 0.30, 0.60)
    colors[clr.ButtonHovered]          = ImVec4(0.40, 0.40, 0.40, 0.80)
    colors[clr.ButtonActive]           = ImVec4(0.50, 0.50, 0.50, 1.00)
    colors[clr.Header]                 = ImVec4(0.40, 0.40, 0.40, 0.30)
    colors[clr.HeaderHovered]          = ImVec4(0.50, 0.50, 0.50, 0.80)
    colors[clr.HeaderActive]           = ImVec4(0.60, 0.60, 0.60, 1.00)
    colors[clr.CheckMark]              = ImVec4(0.85, 0.85, 0.85, 1.00)
    colors[clr.SliderGrab]             = ImVec4(0.60, 0.60, 0.60, 1.00)
    colors[clr.SliderGrabActive]       = ImVec4(0.80, 0.80, 0.80, 1.00)
    colors[clr.TextSelectedBg]         = ImVec4(0.40, 0.40, 0.40, 0.50)
    colors[clr.ScrollbarBg]            = ImVec4(0.12, 0.12, 0.12, 1.00)
    colors[clr.ScrollbarGrab]          = ImVec4(0.30, 0.30, 0.30, 1.00)
    colors[clr.ScrollbarGrabHovered]   = ImVec4(0.40, 0.40, 0.40, 1.00)
    colors[clr.ScrollbarGrabActive]    = ImVec4(0.50, 0.50, 0.50, 1.00)
end

imgui.OnInitialize(function()
    apply_custom_style()
end)

function getKeyName(id)
    for k, v in pairs(vkeys) do
        if v == id then return k:gsub("VK_", "") end
    end
    return tostring(id)
end

function getPlayersInRadius(radius)
    local players = {}
    local res, myX, myY, myZ = getCharCoordinates(PLAYER_PED)
    if not res then return players end

    for _, ped in ipairs(getAllChars()) do
        if ped ~= PLAYER_PED then
            local resPed, pX, pY, pZ = getCharCoordinates(ped)
            if resPed then
                if getDistanceBetweenCoords3d(myX, myY, myZ, pX, pY, pZ) <= radius then
                    local resId, id = sampGetPlayerIdByCharHandle(ped)
                    if resId then players[id] = true end
                end
            end
        end
    end
    return players
end

function sendCefPacket()
    local packetData = {220, 18, 34, 0, 109, 111, 117, 110, 116, 97, 105, 110, 46, 116, 101, 115, 116, 68, 114, 105, 118, 101, 46, 115, 101, 108, 101, 99, 116, 86, 101, 104, 105, 99, 108, 101, 124, 48, 0, 0, 0, 0}
    local bs = raknetNewBitStream()
    for i = 1, #packetData do raknetBitStreamWriteInt8(bs, packetData[i]) end
    raknetSendBitStreamEx(bs, 1, 7, 0)
    raknetDeleteBitStream(bs)
    addToast(u8"Пакет переодевания отправлен!", 1)
end

function async_http_request(url, callback)
    local runner = effil.thread(function(req_url)
        local requests = require 'requests' 
        local ok, result = pcall(requests.get, req_url)
        
        if ok then
            local text = result.text
            
            if text and text:find("Moved Temporarily") and text:find('HREF="(.-)"') then
                local new_url = text:match('HREF="(.-)"')
                if new_url then
                    new_url = new_url:gsub("&amp;", "&") 
                    local ok2, result2 = pcall(requests.get, new_url)
                    if ok2 then
                        return result2.text, result2.status_code
                    end
                end
            end
            
            return text, result.status_code
        else
            return nil, tostring(result)
        end
    end)
    
    local thread = runner(url)
    
    if callback then
        lua_thread.create(function()
            while true do
                local status = thread:status()
                if status == 'completed' then
                    local err, res, code = pcall(thread.get, thread)
                    if err then callback(res, code) else callback(nil, "thread_error") end
                    break
                elseif status == 'failed' or status == 'canceled' then
                    callback(nil, status)
                    break
                end
                wait(0)
            end
        end)
    end
end

function getVcServer()
    async_http_request(vice_api, function(response_text)
        if response_text and response_text ~= "" then
            local data = decodeJson(response_text)
            if data and data.vc then
                for _, po in pairs(data.vc) do
                    addToast(u8('Сервер: %s | онлайн: %s/%s | очередь: %s'):format(po.name, po.online, po.maxplayers, po.queue), 0xCCCCCC)
                    sampAddChatMessage(('[PravikHelper] {FFFFFF}Сервер: %s | онлайн: %s/%s | очередь: %s'):format(po.name, po.online, po.maxplayers, po.queue), 0xCCCCCC)
                end
                return
            end
        end
        addToast(u8"Ошибка при получении данных с сервера VC.", 3)
    end)
end

function parseSpawnListInit()
    local load_idx = 0
    while true do
        local val = cfg.spawn_list[load_idx] or cfg.spawn_list[tostring(load_idx)]
        if not val then break end
        
        local clean_name = val:gsub("^%[%d+%]%s*", "")
        table.insert(parsed_spawn_list, clean_name)
        
        load_idx = load_idx + 1
    end
    
    if #parsed_spawn_list == 0 then table.insert(parsed_spawn_list, "Данные не загружены") end

    local wanted_name_init = cfg.config.autorec_spawn_name or ""
    for i, name in ipairs(parsed_spawn_list) do
        if name == wanted_name_init then
            autorec_spawn_target[0] = i - 1
            break
        end
    end
end

-- ================= УТИЛИТЫ TELEGRAM ================= --
function urlencode(str)
    if str then
        str = str:gsub("\n", "\r\n")
        str = str:gsub("([^%w %-%_%.%~])", function(c) return string.format("%%%02X", string.byte(c)) end)
        str = str:gsub(" ", "%%20")
    end
    return str
end

function getBaseUrl()
    if not tg_custom_api_enabled[0] then
        return "https://api.telegram.org"
    end
    local url = u8:decode(ffi.string(tg_api_url))
    if url == "" then url = "https://api.telegram.org" end
    return (url:gsub("/$", ""))
end

function sendToTelegram(chat_text)
    if not tg_enabled[0] then return end
    if tg_chat_id == 0 or u8:decode(ffi.string(tg_token)) == "" then return end

    local clean_text = chat_text:gsub("{......}", "")
    clean_text = clean_text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
     
    local raw_message = "<b>Возможно обнаружен строй</b>\n\nСообщение из игры:\n<code>" .. clean_text .. "</code>"
    local safe_text = urlencode(u8(raw_message))
    local final_text_url = "%F0%9F%9A%A8%20" .. safe_text
    
    local url = string.format("%s/bot%s/sendMessage?chat_id=%s&parse_mode=HTML&text=%s", getBaseUrl(), u8:decode(ffi.string(tg_token)), tostring(tg_chat_id), final_text_url)
    
    async_http_request(url)
end

function processTelegramCommand(text)
    local text_cp1251 = u8:decode(text):lower()
    local time_str = text_cp1251:match("^rec%s+(%d+)")
    
    if time_str then
        local time = tonumber(time_str)
        startNativeReconnect(time)
        
        local reply = urlencode(u8("Выговоры отменяются.\nПерезаход через " .. time .. " сек."))
        local url = string.format("%s/bot%s/sendMessage?chat_id=%s&text=%s", getBaseUrl(), u8:decode(ffi.string(tg_token)), tostring(tg_chat_id), reply)
        
        async_http_request(url)
    end
end

function checkTelegramUpdates(token)
    is_polling = true
    local url = string.format("%s/bot%s/getUpdates?offset=%d&timeout=1", getBaseUrl(), token, last_update_id + 1)
    
    async_http_request(url, function(response_text, error_msg)
        is_polling = false 
        
        if response_text and response_text ~= "" then
            local data = decodeJson(response_text)
            if data and data.ok and data.result then
                for _, update in ipairs(data.result) do
                    last_update_id = update.update_id
                    
                    if update.message and update.message.chat and update.message.text then
                        local incoming_chat_id = update.message.chat.id
                        local incoming_text = update.message.text
                        
                        if tg_chat_id == 0 then
                            tg_chat_id = incoming_chat_id
                            saveConfig()
                            addToast(u8"Успешная привязка! Аккаунт Telegram сохранен.", 2)
                            
                            local welcome_msg = urlencode(u8("Авторизация успешна!\nТеперь уведомления будут приходить сюда."))
                            local tg_url = string.format("%s/bot%s/sendMessage?chat_id=%s&text=%s", getBaseUrl(), token, tostring(incoming_chat_id), welcome_msg)
                            async_http_request(tg_url)
                        
                        elseif incoming_chat_id == tg_chat_id then
                            processTelegramCommand(incoming_text)
                        end
                    end
                end
            end
        end
    end)
end

function startNativeReconnect(timeout_sec)
    timeout_sec = tonumber(timeout_sec) or 15
    if reconnect_thread then reconnect_thread:terminate() end

    reconnect_thread = lua_thread.create(function()
        if sampGetGamestate() ~= GAMESTATE_RESTARTING then
            sampSetGamestate(GAMESTATE_DISCONNECTED)
            sampDisconnectWithReason(0)
        end
        
        addToast(u8(string.format("Реконнект. Ожидание %d сек...", timeout_sec)), 2)

        local timeout_clock = os.clock()
        while true do
            wait(0)
            if (os.clock() - timeout_clock) >= timeout_sec then break end
        end

        if sampIsDialogActive() then sampCloseCurrentDialogWithButton(0) end

        sampSetGamestate(GAMESTATE_WAIT_CONNECT)
        addToast(u8"Подключаемся к серверу...", 2)
    end)
end

function onWindowMessage(msg, wparam, lparam)
    if msg == 0x0100 or msg == 0x0101 then
        if wparam == vkeys.VK_ESCAPE and main_window_state[0] then
            if sampIsChatInputActive() or sampIsDialogActive() or isSampfuncsConsoleActive() then
                return
            end
            
            if msg == 0x0100 then
                main_window_state[0] = false
            end
            
            consumeWindowMessage(true, true)
        end
    end
end

-- =========================
-- ОСНОВНОЙ ПОТОК
-- =========================
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    repeat wait(0) until isSampAvailable()

    math.randomseed(os.time())
    
    parseSpawnListInit()
    checkUpdates()
	
    sampRegisterChatCommand("pravik", function() 
        main_window_state[0] = not main_window_state[0] 
    end)

    sampRegisterChatCommand('vc', function()
        getVcServer()
    end) 

    sampRegisterChatCommand("donfoxi", function()
        show_forma_tab = not show_forma_tab
        if not show_forma_tab and selected_tab == 4 then selected_tab = 2 end
    end)

    sampRegisterChatCommand("lift", function()
        local x, y, z = getCharCoordinates(PLAYER_PED)
        if isCharInAnyCar(PLAYER_PED) then
            setCarCoordinates(storeCarCharIsInNoSave(PLAYER_PED), x, y, z + 5.0)
        else
            setCharCoordinates(PLAYER_PED, x, y, z + 5.0)
        end
        addToast(u8"Лифт вызван", 2)
        sampSendChat("/me вызвал лифт")
    end)

    sampRegisterChatCommand("liftd", function()
        local x, y, z = getCharCoordinates(PLAYER_PED)
        if isCharInAnyCar(PLAYER_PED) then
            setCarCoordinates(storeCarCharIsInNoSave(PLAYER_PED), x, y, z - 5.0)
        else
            setCharCoordinates(PLAYER_PED, x, y, z - 5.0)
        end
        addToast(u8"Лифт вызван", 2)
        sampSendChat("/me вызвал лифт")
    end)

    sampRegisterChatCommand("pop", function()
        cmd_pop()
    end)

    addToast(u8"Скрипт загружен. Введите /pravik", 2)

    lua_thread.create(function()
        while true do
            wait(5000)
            local current_token = u8:decode(ffi.string(tg_token))
            if tg_enabled[0] and current_token ~= "" and not is_polling then
                checkTelegramUpdates(current_token)
            end
        end
    end)

    while true do
        wait(0)
        
		if pending_form_type and not is_binding_hotkey then
			if os.clock() - form_warning_time < 15 then 
				local kName = getKeyName(form_hotkey[0])
				if pending_form_type == "vc" then 
					printString("FORMA Vice City: ~w~PRESS  " .. kName, 100)
				elseif pending_form_type == "fwarn" then 
					printString(string.format("FORMA FWARN: ~w~PRESS %s", kName), 100) 
				end

				if wasKeyPressed(form_hotkey[0]) and not sampIsChatInputActive() and not sampIsDialogActive() and not isSampfuncsConsoleActive() then
					local pType, pData = pending_form_type, pending_form_data
					pending_form_type, pending_form_data = nil, {}
					
					if pType == "vc" then
						async_http_request(vice_api, function(response_text)
							if response_text and response_text ~= "" then
								local data = decodeJson(response_text)
								if data and data.vc then
									local t_on, t_max, t_q = 0, 0, 0
									for _, po in pairs(data.vc) do
										t_on = t_on + (tonumber(po.online) or 0)
										t_max = t_max + (tonumber(po.maxplayers) or 0)
										t_q = t_q + (tonumber(po.queue) or 0)
									end
									
									local targetNick = "Игрок"
									if pData.target then
										local name = sampGetPlayerNickname(pData.target)
										if name then targetNick = name end
									end
									
									sampSendChat(string.format("/vr @%s Сервер: Vice-City | онлайн: %d/%d | очередь: %d", targetNick, t_on, t_max, t_q))
									return
								end
							end
							addToast(u8"Ошибка связи с серверами VC.", 3)
						end)
					elseif pType == "fwarn" then
						sampSendChat(string.format("/fwarn %d %s // %s", pData.target, pData.reason, pData.author))
					end
				end
			else
				pending_form_type, pending_form_data = nil, {}
			end
		end

        if domkrat_bind_enabled[0] and not is_binding_domkrat then
            if wasKeyPressed(domkrat_hotkey[0]) and not sampIsChatInputActive() and not sampIsDialogActive() and not isSampfuncsConsoleActive() then
                sampSendChat("/domkrat")
            end
        end	

        if pending_login_notif > 0 then
            addToast(pending_login_notif == 1 and u8"Первоначальная авторизация выполнена." or u8"Reconnect выполнен успешно.", 2)
            if pending_login_notif == 1 then is_initial_login = false end
            pending_login_notif = 0
        end

        if disable_col then
            for _, ped in ipairs(getAllChars()) do
                if ped ~= PLAYER_PED then
                    setCharCollision(ped, false)
                    collision_disabled_peds[ped] = true
                end
            end
        elseif next(collision_disabled_peds) then
            for ped, _ in pairs(collision_disabled_peds) do
                if doesCharExist(ped) then setCharCollision(ped, true) end
            end
            collision_disabled_peds = {}
        end
    end
end

-- =========================
-- IMGUI РЕНДЕР И ОТРИСОВКА ВКЛАДОК
-- =========================
local function RenderToasts(sw, sh, current_time)
    if #toasts == 0 then return end
    local toast_pad, toast_y = 15, sh - 30
    
    for i = #toasts, 1, -1 do
        local t = toasts[i]
        local elapsed = current_time - t.start
        
        if elapsed > t.duration then
            table.remove(toasts, i)
        else
            local t_alpha = 1.0
            if elapsed < 0.3 then t_alpha = elapsed / 0.3
            elseif (t.duration - elapsed) < 0.3 then t_alpha = (t.duration - elapsed) / 0.3 end
            
            imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, t_alpha)
            imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 8.0)
            imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(15, 10))
            imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.08, 0.08, 0.08, 0.95))
            imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.2, 0.2, 0.2, 1.0))
            
            local text_size = imgui.CalcTextSize(t.text)
            local window_w, window_h = text_size.x + 30, text_size.y + 20
            
            imgui.SetNextWindowPos(imgui.ImVec2(sw - window_w - toast_pad + ((1.0 - t_alpha) * 50), toast_y - window_h), imgui.Cond.Always)
            imgui.SetNextWindowSize(imgui.ImVec2(window_w, window_h), imgui.Cond.Always)
            
			imgui.Begin("Toast##" .. i, nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoSavedSettings + imgui.WindowFlags.NoFocusOnAppearing + imgui.WindowFlags.NoMouseInputs)
            
            local color = imgui.ImVec4(0.8, 0.8, 0.8, 1.0)
            if t.type == 2 then color = imgui.ImVec4(0.65, 0.65, 0.65, 1.0) end
            if t.type == 3 then color = imgui.ImVec4(0.5, 0.5, 0.5, 1.0) end
            
            imgui.TextColored(color, t.text)
            imgui.End()
            imgui.PopStyleColor(2)
            imgui.PopStyleVar(3)
            
            toast_y = toast_y - window_h - toast_pad
        end
    end
end

local function RenderTabAuto()
    imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.70, 1.00), u8"> АВТОМАТИЧЕСКАЯ ВЫДАЧА")
    imgui.Spacing()
    
    if imgui.Checkbox(u8"/givesocial", givesocial_enabled) then saveConfig() end
    imgui.Spacing()
    if imgui.Checkbox(u8"/givepass", givepass_enabled) then saveConfig() end
	imgui.SameLine(150)
    if imgui.Checkbox(u8"/givecitizen", givecitizen_enabled) then saveConfig() end
    imgui.Spacing()
    
    if imgui.Checkbox(u8"/fractionrp", fractionrp_enabled) then
        if not fractionrp_enabled[0] then fractionrp_cd_enabled[0] = false; saveConfig() end
    end
    imgui.SameLine(150)
    if imgui.Checkbox(u8" Оповещение о КД", fractionrp_cd_enabled) then
        if not fractionrp_enabled[0] then fractionrp_cd_enabled[0] = false else saveConfig() end
    end
    
    imgui.Spacing(); imgui.Separator(); imgui.Spacing()
    
    imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.70, 1.00), u8"> АВТО-ОТВЕТЧИК НА ТЕЛЕФОН")
    if imgui.Checkbox(u8"Входящие вызовы", autophone_inc_enabled) then saveConfig() end
    if autophone_inc_enabled[0] then
        imgui.PushItemWidth(-1)
        imgui.Text(u8"Ответ на входящий:")
        if imgui.InputText(u8"##inc_text", autophone_inc_text, ffi.sizeof(autophone_inc_text)) then saveConfig() end
        imgui.PopItemWidth()
        imgui.Spacing()
    end

    if imgui.Checkbox(u8"Исходящие вызовы", autophone_out_enabled) then saveConfig() end
    if autophone_out_enabled[0] then
        imgui.PushItemWidth(-1)
        imgui.Text(u8"Сообщение при исходящем:")
        if imgui.InputText(u8"##out_text", autophone_out_text, ffi.sizeof(autophone_out_text)) then saveConfig() end
        imgui.PopItemWidth()
    end
    
    imgui.Spacing(); imgui.Separator(); imgui.Spacing()
    
    imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.70, 1.00), u8"> УПРАВЛЕНИЕ ФОРМАМИ")
    if imgui.Checkbox(u8"Ловить формы на VC", vc_form_enabled) then saveConfig() end
    imgui.SameLine(180)
    if imgui.Checkbox(u8"Ловить формы /fwarn", fwarn_form_enabled) then saveConfig() end
    imgui.Spacing()
    
    imgui.Text(u8"Кнопка принятия форм:")
    imgui.SameLine()
    if imgui.Button(is_binding_hotkey and u8"Нажмите клавишу..." or u8(tostring(getKeyName(form_hotkey[0]))), imgui.ImVec2(150, 0)) then
        is_binding_hotkey = true
    end

    if is_binding_hotkey then
        for k, v in pairs(vkeys) do
            if wasKeyPressed(v) and v ~= vkeys.VK_LBUTTON and v ~= vkeys.VK_RBUTTON and v ~= vkeys.VK_ESCAPE then
                form_hotkey[0] = v; saveConfig(); is_binding_hotkey = false; break
            end
        end
    end
end

local function RenderTabStroy()
    imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.70, 1.00), u8"> УМНАЯ ПРОВЕРКА СТРОЯ")
    imgui.Spacing()
    imgui.PushItemWidth(200)
    imgui.Text(u8"Причина выговора:")
    imgui.InputText("##punishreason", punish_reason, ffi.sizeof(punish_reason))
    imgui.Spacing()
    imgui.Text(u8"Радиус сбора (метры):")
    imgui.SliderFloat("##radius", check_stroy_radius, 5.0, 100.0)
    imgui.Spacing()
    imgui.Text(u8"Пауза между выдачей (сек):")
    imgui.SliderInt("##pdelay", punish_delay, 2, 10)
    imgui.PopItemWidth()

    imgui.Spacing(); imgui.Separator(); imgui.Spacing()
    imgui.Checkbox(u8"Игнорировать ст. состав 8+", ignore_rank_8_plus)
    imgui.Checkbox(u8"Игнорировать тех, у кого 2+ выговора", ignore_2_fwarns)
    imgui.Spacing(); imgui.Spacing()
    
    if imgui.Button(u8"НАЧАТЬ ПРОВЕРКУ И ВЫДАЧУ", imgui.ImVec2(-1, 45)) then
        if not is_checking_stroy then
            nearby_players_list = getPlayersInRadius(check_stroy_radius[0])
            current_punish_list = {}; page_counter = 1; is_checking_stroy = true
            sampSendChat("/members")
            addToast(u8"Проверка строя. Не закрывайте диалоги...", 1)
        else
            addToast(u8"Проверка уже идет!", 3)
        end
    end

    if show_whitelist then
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.70, 1.00), u8"> ВАЙТ-ЛИСТ")
		imgui.PushItemWidth(150)
        imgui.InputTextWithHint(u8"##wl_input", u8"ID или Ник", whitelist_input, ffi.sizeof(whitelist_input))
        imgui.PopItemWidth()
        imgui.SameLine()
        
		if imgui.Button(u8"Добавить", imgui.ImVec2(80, 0)) then
            local input_str = u8:decode(ffi.string(whitelist_input)):match("^%s*(.-)%s*$")
            
            if input_str ~= "" then
                local target_nick = input_str
                
                if input_str:match("^%d+$") and tonumber(input_str) <= 999 then
                    local id = tonumber(input_str)
                    
                    if sampIsPlayerConnected(id) then
                        local name = sampGetPlayerNickname(id)
                        if name then
                            target_nick = name
                        end
                    else
                        addToast(u8"Ошибка: Игрок с таким ID не в сети!", 3)
                        target_nick = nil
                    end
                end

                if target_nick then
                    cfg.whitelist[target_nick] = true
                    inicfg.save(cfg, "PravikHelper.ini")
                    whitelist_input[0] = 0
                    addToast(u8("В вайт-лист добавлен: " .. target_nick), 2)
                end
            end
        end

        if imgui.TreeNodeStr(u8"Список исключений") then
            local to_remove = nil
            for nick, _ in pairs(cfg.whitelist) do
                imgui.Text(u8(tostring(nick)))
                imgui.SameLine(160)
                if imgui.Button(u8("Удалить##" .. tostring(nick))) then to_remove = nick end
            end
            if to_remove then cfg.whitelist[to_remove] = nil; inicfg.save(cfg, "PravikHelper.ini") end
            imgui.TreePop()
        end
    end
end

local function RenderTabSpawn()
    imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.70, 1.00), u8"> АВТО-ВХОД, ФОРМА И СПАВН")
    imgui.Spacing()
    if imgui.Checkbox(u8"Авто-логин", autologin_enabled) then saveConfig() end
    
    if autologin_enabled[0] then
        imgui.SameLine()
        imgui.PushItemWidth(150)
        local pass_flags = show_password_toggle and 0 or imgui.InputTextFlags.Password
        if imgui.InputTextWithHint(u8"Пароль##loginpass", u8"Пароль", autologin_password, ffi.sizeof(autologin_password), pass_flags) then saveConfig() end
        imgui.PopItemWidth()
        imgui.SameLine()
        if imgui.Button(show_password_toggle and u8"Скрыть" or u8"Показать") then show_password_toggle = not show_password_toggle end
    end
    
    imgui.Spacing(); imgui.Separator(); imgui.Spacing()
    if imgui.Checkbox(u8"Авто-переодевание", autouniform_enabled) then saveConfig() end
    imgui.SameLine(220)
    if imgui.Checkbox(u8"Отбегать после формы", autorunaway_enabled) then saveConfig() end
    imgui.Spacing()
    if imgui.Checkbox(u8"Авто-спавн при входе", autospawn_gov_enabled) then saveConfig() end
    imgui.Spacing(); imgui.Separator(); imgui.Spacing()
    if imgui.Checkbox(u8"Умный спавн", autorec_enabled) then saveConfig() end
    
	if autorec_enabled[0] then
        imgui.Spacing()
        imgui.PushItemWidth(300)
        
        local items_count = #parsed_spawn_list
        if items_count > 0 then
            local u8_items = {}
            for i, item in ipairs(parsed_spawn_list) do 
                u8_items[i] = u8(tostring(item)) 
            end
            
            local combo_items_arr = imgui.new['const char*'][items_count](u8_items)
            
            if imgui.Combo(u8"##spawn_combo", autorec_spawn_target, combo_items_arr, items_count) then 
                saveConfig() 
            end
        else
            imgui.TextDisabled(u8"Список спавнов пуст")
        end
        
        imgui.PopItemWidth()
    end

    imgui.Spacing(); imgui.Separator(); imgui.Spacing()
    imgui.PushItemWidth(100)
    if imgui.InputInt(u8"ID рабочего скина", workSkinId) then saveConfig() end
    imgui.PopItemWidth()
    imgui.Spacing()
    imgui.TextDisabled(u8("Координаты: " .. pickupX .. ", " .. pickupY .. ", " .. pickupZ))
    imgui.TextDisabled(u8"1-3: 164 | 3-4: 163 | 5-8: 57 | 9+: 147 | Ж: 141")
end

local function RenderTabUtils()
    imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.70, 1.00), u8"/vc - очередь на Vice-City\n/lift - вызвать лифт вверх\n/liftd - вызвать лифт вниз\n/pop - секретная анимка")
	imgui.Separator()
    
    if imgui.Checkbox(u8"ESC Bypass", bypass_esc_enabled) then saveConfig() end
    imgui.SameLine()
    imgui.TextDisabled("(?)")
    if imgui.IsItemHovered() then
        imgui.BeginTooltip() 
        imgui.PushTextWrapPos(350.0) 
        imgui.TextUnformatted(u8"Функция возвращает старое торможение на ESC\nБез домкратов и других расходников")
        imgui.PopTextWrapPos()
        imgui.EndTooltip() 
    end
    
    if imgui.Checkbox(u8"сбив нарко чатом", sbiv_chat_enabled) then saveConfig() end
    if sbiv_chat_enabled[0] then
        imgui.SameLine(170)
		imgui.PushItemWidth(150)
        if imgui.InputTextWithHint(u8"##sbivtext", u8"Текст", sbiv_chat_text, ffi.sizeof(sbiv_chat_text)) then saveConfig() end
        imgui.PopItemWidth()
    end
    
    if imgui.Checkbox(u8"/domkrat", domkrat_bind_enabled) then saveConfig() end
    if domkrat_bind_enabled[0] then
        imgui.SameLine(170)
		imgui.PushItemWidth(100)
        if imgui.Button(is_binding_domkrat and u8"Нажмите клавишу..." or u8(tostring(getKeyName(domkrat_hotkey[0]))), imgui.ImVec2(150, 0)) then
            is_binding_domkrat = true
        end

        if is_binding_domkrat then
            for k, v in pairs(vkeys) do
                if wasKeyPressed(v) and v ~= vkeys.VK_LBUTTON and v ~= vkeys.VK_RBUTTON and v ~= vkeys.VK_ESCAPE then
                    domkrat_hotkey[0] = v
                    saveConfig()
                    is_binding_domkrat = false
                    break
                end
            end
        end
    end
end

local function RenderTabTelegram()
    imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.70, 1.00), u8"> ИНТЕГРАЦИЯ TELEGRAM")
    imgui.Spacing()
    
    if imgui.Checkbox(u8"Telegram уведомления", tg_enabled) then saveConfig() end
	
    if tg_enabled[0] then
        imgui.SameLine(250)
        if imgui.Checkbox(u8"Зеркало API", tg_custom_api_enabled) then saveConfig() end
        imgui.SameLine()
        imgui.TextDisabled("(?)")
        if imgui.IsItemHovered() then
            imgui.BeginTooltip() 
            imgui.PushTextWrapPos(350.0) 
            imgui.TextUnformatted(u8"Включаем только если вы в РФ и у вас заблокирован ТГ\nВ случае если ссылка не появилась автоматически, вставьте вот эту:\nhttps://tg-pravik-proxy.renaticus13.workers.dev/")
            imgui.PopTextWrapPos()
            imgui.EndTooltip() 
        end
        
        if tg_custom_api_enabled[0] then
            imgui.Spacing()
            imgui.Text(u8"Сервер API:")
            imgui.PushItemWidth(285)
            if imgui.InputText("##tgapi", tg_api_url, ffi.sizeof(tg_api_url)) then saveConfig() end
            imgui.PopItemWidth()
        end
        imgui.Spacing()
        
        imgui.Text(u8"Токен бота:")
        imgui.PushItemWidth(250)
        if imgui.InputText("##tgtoken", tg_token, ffi.sizeof(tg_token), imgui.InputTextFlags.Password) then saveConfig() end
        imgui.PopItemWidth()

        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        
        if tg_chat_id == 0 then
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 0.0, 1.0), u8"Бот не привязан!")
            imgui.Text(u8"Напишите боту любое сообщение в Telegram для авторизации.")
        else
            imgui.TextColored(imgui.ImVec4(0.0, 1.0, 0.0, 1.0), u8("Аккаунт привязан!\nChat ID: " .. tostring(tg_chat_id) .. ""))
            imgui.Spacing()
            if imgui.Button(u8"Сбросить привязку", imgui.ImVec2(-1, 30)) then
                tg_chat_id = 0
                saveConfig()
                addToast(u8"Привязка сброшена. Напишите боту снова.", 2)
            end
        end
    end
end

function cmd_pop()
    lua_thread.create(function()
        local animName = "DAM_Dive_Loop"
        local animIfp = "DAM_JUMP"
        
        if not hasAnimationLoaded(animIfp) then
            requestAnimation(animIfp)
            local timer = 0
            while not hasAnimationLoaded(animIfp) and timer < 50 do
                wait(10)
                timer = timer + 1
            end
        end
        
        if hasAnimationLoaded(animIfp) then
            taskPlayAnim(PLAYER_PED, animName, animIfp, 4.0, true, false, false, false, -1)
            addToast(u8"Анимация воспроизведена", 2)
        else
            addToast(u8"Анимация не воспроизведена", 2)
        end
    end)
end

imgui.OnFrame(
	function() return main_window_state[0] or #toasts > 0 end,
    
	function(player)
        player.HideCursor = main_window_state[0]
        
        local current_time = os.clock()
        last_frame_time = current_time
        local sw, sh = getScreenResolution()
        
        RenderToasts(sw, sh, current_time)

        if main_window_state[0] then
            imgui.SetNextWindowSize(imgui.ImVec2(630, 435), imgui.Cond.Always)
            imgui.SetNextWindowPos(imgui.ImVec2(sw / 2 - 315, sh / 2 - 220), imgui.Cond.FirstUseEver)
            
            if imgui.Begin(u8"PravikHelper", main_window_state, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize) then
                
                imgui.BeginChild("left_pane", imgui.ImVec2(170, -30), true)
                
                local num_tabs = show_forma_tab and 5 or 4
                local avail_y = imgui.GetContentRegionAvail().y
                local spacing_y = imgui.GetStyle().ItemSpacing.y
                local btn_height = (avail_y - (spacing_y * (num_tabs - 1))) / num_tabs
                
				local function DrawTabButton(name, tab_id)
					local p = imgui.GetCursorScreenPos()
					local m = imgui.GetMousePos()
					local w = imgui.GetContentRegionAvail().x 
					local is_hovered = m.x >= p.x and m.y >= p.y and m.x <= (p.x + w) and m.y <= (p.y + btn_height)
					
					if selected_tab == tab_id then
						imgui.PushStyleColor(imgui.Col.Button, imgui.GetStyle().Colors[imgui.Col.ButtonActive])
						imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.95, 0.95, 0.95, 1.0))
					else
						imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0, 0, 0, 0))
						if is_hovered then
							imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.85, 0.85, 0.85, 1.0)) 
						else
							imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.5, 0.5, 0.5, 1.0))
						end
					end
					
					if imgui.Button(name, imgui.ImVec2(-1, btn_height)) then selected_tab = tab_id end
					imgui.PopStyleColor(2)
				end

                DrawTabButton(u8" АВТО-ВЫДАЧА", 1)
                DrawTabButton(u8" ПРОВЕРКА СТРОЯ", 2)
                if show_forma_tab then DrawTabButton(u8" ФОРМА", 3) end
                DrawTabButton(u8" УТИЛИТЫ", 4)
                DrawTabButton(u8" ТЕЛЕГРАМ", 5)
                
                imgui.EndChild()
                imgui.SameLine()

                imgui.BeginChild("right_pane", imgui.ImVec2(0, -30), true)
                
				if selected_tab == 1 then RenderTabAuto()
                elseif selected_tab == 2 then RenderTabStroy()
                elseif selected_tab == 3 then RenderTabSpawn()
                elseif selected_tab == 4 then RenderTabUtils()
                elseif selected_tab == 5 then RenderTabTelegram()
                end

                imgui.EndChild()

                imgui.Spacing()
                local textWidth = imgui.CalcTextSize(u8"Скрипт создан при поддержке лучшего Президента Viktor Yakunovich").x
                imgui.SetCursorPosX((imgui.GetWindowWidth() - textWidth) * 0.5)
                imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), u8"Скрипт создан при поддержке лучшего Президента Viktor Yakunovich")
                
                if imgui.IsItemClicked() then
                    if os.clock() - last_secret_click > 1.0 then secret_click_count = 1 else secret_click_count = secret_click_count + 1 end
                    last_secret_click = os.clock()
                    if secret_click_count >= 3 then show_whitelist = not show_whitelist; secret_click_count = 0 end
                end
                
                imgui.End()
            end
        end
    end
)

-- =========================
-- ОБХОД ESC (ПАКЕТЫ)
-- =========================
function onSendPacket(id, bs, priority, reliability, orderingChannel)
    if bypass_esc_enabled[0] and id == 220 then
        raknetBitStreamReadInt8(bs)
        if raknetBitStreamReadInt8(bs) == 18 then
            local strlen = raknetBitStreamReadInt16(bs)
            if strlen > 0 and strlen <= 2048 then
                local str = raknetBitStreamReadString(bs, strlen)
                local status = tonumber(str:match("mainMenu%.status|(%d+)"))
                if status and isCharInAnyCar(PLAYER_PED) then
                    if status == 1 then isLocked = not isLocked; lockPlayerControl(isLocked)
                    elseif status == 0 then isLocked = false; lockPlayerControl(false) end
                end
            end
        end
    end
end

-- =========================
-- СОБЫТИЯ SAMP (EVENTS)
-- =========================
function sampev.onSendSpawn()
    if not autouniform_enabled[0] then return end
    lua_thread.create(function()
        wait(3000) 
        if getCharModel(PLAYER_PED) ~= workSkinId[0] then
            addToast(u8"Я не в форме. Бегу к пикапу...", 1)
            disable_col = true 
            taskGoStraightToCoord(PLAYER_PED, pickupX, pickupY, pickupZ, 4, -1)
            
            local timeout = os.time() + 10 
            while getDistanceBetweenCoords2d(pickupX, pickupY, getCharCoordinates(PLAYER_PED)) > 1.2 do
                wait(100)
                if os.time() > timeout then
                    addToast(u8"Ошибка: не смог добежать до пикапа.", 3)
                    clearCharTasks(PLAYER_PED); disable_col = false 
                    return 
                end
            end
            
            clearCharTasks(PLAYER_PED)
            addToast(u8"Добежал. Нажимаю ALT...", 1)
            press_alt_sync = true; wait(500); press_alt_sync = false; wait(1000) 
            sendCefPacket(); wait(1000) 
            
            if autorec_enabled[0] then
                disable_col = false; next_spawn_after_rec = true
                addToast(u8"Переоделся. Выполняю /rec...", 2)
                sampProcessChatInput("/rec")
            else
                if autorunaway_enabled[0] then
                    addToast(u8"Переоделся. Отбегаю...", 1)
                    local targetX, targetY, targetZ = 1500.3088, -1284.8411, 113.8064
                    taskGoStraightToCoord(PLAYER_PED, targetX, targetY, targetZ, 4, -1)
                    local run_timeout = os.time() + 5 
                    while getDistanceBetweenCoords2d(targetX, targetY, getCharCoordinates(PLAYER_PED)) > 1.2 do
                        wait(100); if os.time() > run_timeout then break end
                    end
                    clearCharTasks(PLAYER_PED)
                else addToast(u8"Успешно переоделся.", 2) end
                disable_col = false 
            end
        end
    end)
end

function sampev.onServerMessage(color, text)
    local hex_color = string.format("%06x", bit.rshift(color, 8)):lower()
    local is_radio = text:find("%[R%]") or text:find("%[r%]")

    if is_radio then
        if hex_color == "2db043" or text:lower():find("{2db043}") then
            if text:find("[Сс][Тт][Рр][Оо][Йй]") or text:find("[Яя][Вв][Кк][Уу]") or text:find("[Вв][Ыы][Гг]") or text:find("[Лл][Ее][Кк][Цц][Ии][Яя]") or text:find("[Сс][Уу][Дд][Ее][Бб][Нн][Аа][Яя]") or text:find("[Вв][Нн][Ии][Мм][Аа][Нн][Ии][Ее]") or text:find("[Сс][Уу][Дд]") then
                if os.clock() - last_tg_alert_time > 10.0 then 
                    last_tg_alert_time = os.clock() 
                    lua_thread.create(function() sendToTelegram(text) end)
                end
            end
        end
    end

    if fractionrp_enabled[0] and fractionrp_cd_enabled[0] then
        local cd = text:match('^%[Ошибка%] {ffffff}После прошедшего подтверждение не прошло 3 часа. {C0C0C0}%(Осталось: (.+)%)')
        if cd then sampSendChat('/n У вас КД на /fractionrp! Осталось ' .. cd) end
    end
    
    local cleanTextPhone = text:gsub("{......}", "")
    local clean_text = text:gsub("{.-}", "")
    
    if sbiv_chat_enabled[0] then
        local res, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
        if res then
            local start_pos = clean_text:find(sampGetPlayerNickname(myId) .. "%[%d+%] принимает дозу укропа")
            if start_pos and start_pos <= 5 then
                lua_thread.create(function() wait(10); sampSendChat(u8:decode(ffi.string(sbiv_chat_text))) end)
            end
        end
    end
    
    if autophone_inc_enabled[0] and cleanTextPhone:find("%[Информация%] Вы подняли трубку") then
        lua_thread.create(function() wait(100); sampSendChat(u8:decode(ffi.string(autophone_inc_text))) end)
    end
    if autophone_out_enabled[0] and cleanTextPhone:find("%[Информация%] Собеседник взял трубку") then
        lua_thread.create(function() wait(100); sampSendChat(u8:decode(ffi.string(autophone_out_text))) end)
    end

    local pid, msg, chat_type = nil, nil, "unknown"
    pid, msg = clean_text:match(".-%[(%d+)%] говорит:%s*(.+)")
    if pid then chat_type = "ic" end
    if not pid then pid, msg = clean_text:match("%[[^%]]+%]%s+.-%[(%d+)%]:%s*%(%(%s*(.-)%s*%)%)"); if pid then chat_type = "nrp" end end
    if not pid then pid, msg = clean_text:match("%(%(.-%[(%d+)%]:%s*(.-)%s*%)%)"); if pid then chat_type = "ooc" end end
    if not pid then pid, msg = clean_text:match("%[(%d+)%]%s*[^:]-:%s*(.+)"); if pid then chat_type = "vr" end end

    if pid and msg then
        local clean_msg = " " .. msg:lower():gsub("[%p%c]", " ") .. " "

        if vc_form_enabled[0] and chat_type == "vr" then
            for _, kw in ipairs({"очередь вс", "сколько очередь", "очередь на вс"}) do
                if clean_msg:find(kw) then
                    pending_form_type, pending_form_data, form_warning_time = "vc", {target = tonumber(pid)}, os.clock()
                    return 
                end
            end
        end

        if fwarn_form_enabled[0] and chat_type == "nrp" then
            local target, reason = msg:match("[/фf][wв]arn%s+(%d+)%s+(.+)")
            if not target then target, reason = msg:match("выговор%s+(%d+)%s+(.+)") end
            if target and reason then
                pending_form_type = "fwarn"
                pending_form_data = {target = tonumber(target), reason = reason, author = sampGetPlayerNickname(tonumber(pid)) or tostring(pid)}
                form_warning_time = os.clock()
                return
            end
        end
        
        if givesocial_enabled[0] and chat_type == "ic" then
            for _, kw in ipairs({"доки", "социальное", "соц", "документы", "жилье", "жильё", "подпиши"}) do
                if clean_msg:find(" " .. kw .. " ") then
                    lua_thread.create(function()
                        wait(500 + math.random(250, 750)); pid = tonumber(pid)
                        if sampIsPlayerConnected(pid) then sampSendChat("/givesocial " .. pid); last_invited_for_giverank_id = pid end
                    end)
                    return
                end
            end
        end

        if givepass_enabled[0] and chat_type == "ic" then
            for _, kw in ipairs({"виза", "визу", "вайсити", "авто", "машина", "сертификат", "машину", "автомобиль", "перевести", "серт"}) do
                if clean_msg:find(" " .. kw .. " ") then
                    lua_thread.create(function()
                        wait(500 + math.random(250, 750)); pid = tonumber(pid)
                        if sampIsPlayerConnected(pid) then
                            givepass_action_type = (kw:find("виз") or kw:find("вайсити")) and 'pass' or 'auto'
                            sampSendChat("/givepass " .. pid)
                        end
                    end)
                    return
                end
            end
        end

        if givecitizen_enabled[0] and chat_type == "ic" then
            for _, kw in ipairs({"гражданство", "гражданский", "прописку", "прописка"}) do
                if clean_msg:find(" " .. kw .. " ") then
                    lua_thread.create(function()
                        wait(500 + math.random(250, 750)); pid = tonumber(pid)
                        if sampIsPlayerConnected(pid) then sampSendChat("/givecitizen " .. pid) end
                    end)
                    return
                end
            end
        end

        if fractionrp_enabled[0] and chat_type == "ic" then
            for _, kw in ipairs({"рп", "можно рп", "rp", "можно rp", "дай рп", "пометку", "печать", "печатку"}) do
                if clean_msg:find(" " .. kw .. " ") then
                    lua_thread.create(function()
                        wait(500 + math.random(250, 750)); pid = tonumber(pid)
                        if sampIsPlayerConnected(pid) then sampSendChat("/fractionrp " .. pid) end
                    end)
                    return
                end
            end
        end
    end
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if autologin_enabled[0] and ffi.string(autologin_password) ~= "" and (title:find("Авторизация") or text:find("Введите пароль")) then
        lua_thread.create(function()
            wait(200)
            sampSendDialogResponse(dialogId, 1, 0, u8:decode(ffi.string(autologin_password)))
            pending_login_notif = is_initial_login and 1 or 2
        end)
        return false
    end

    local clean_title, clean_text = title:gsub("{.-}", ""), text:gsub("{.-}", "")
    
    if style == 2 and (clean_title:find("[\xCC\xEC][\xC5\xE5][\xD1\xF1][\xD2\xF2][\xC0\xE0] [\xD1\xF1][\xCF\xEF][\xC0\xE0][\xC2\xE2][\xCD\xED][\xC0\xE0]") or clean_text:find("[\xC2\xE2][\xCE\xEE][\xCA\xEA][\xC7\xE7][\xC0\xE0][\xCB\xEB]")) then
        local current_parsed, list_idx, target_idx, wanted_name = {}, 0, -1, cfg.config.autorec_spawn_name or ""
        cfg.spawn_list = {}
        
        for line in text:gmatch("[^\r\n]+") do
            local name_only = line:gsub("{.-}", ""):gsub("^%[%d+%]%s*", "")
            table.insert(current_parsed, name_only)
            cfg.spawn_list[tostring(list_idx)] = name_only
            
            if next_spawn_after_rec and autorec_enabled[0] and name_only == wanted_name then target_idx = list_idx
            elseif not next_spawn_after_rec and autospawn_gov_enabled[0] and name_only:find("[\xCF\xEF][\xD0\xF0][\xC0\xE0][\xC2\xE2][\xC8\xE8][\xD2\xF2][\xC5\xE5][\xCB\xEB][\xDC\xFC][\xD1\xF1][\xD2\xF2][\xC2\xE2][\xCE\xEE]") then target_idx = list_idx end
            list_idx = list_idx + 1
        end
        
        parsed_spawn_list = current_parsed
        inicfg.save(cfg, "PravikHelper.ini")
        
        local found_in_ui = false
        for i, name in ipairs(parsed_spawn_list) do if name == wanted_name then autorec_spawn_target[0] = i - 1; found_in_ui = true; break end end
        if not found_in_ui then autorec_spawn_target[0] = 0 end

        if target_idx ~= -1 and target_idx < #current_parsed then
            lua_thread.create(function()
                wait(400 + math.random(100, 200))
                sampSendDialogResponse(dialogId, 1, target_idx, "")
                if next_spawn_after_rec then addToast(u8("Спавн после /rec: " .. wanted_name), 2); next_spawn_after_rec = false
                else addToast(u8"Авто-спавн", 2) end
            end)
            return false 
        end
    end

    if dialogId == 3501 and givepass_enabled[0] and givepass_action_type then
        local listItemIndex = givepass_action_type == 'pass' and 0 or 1
        givepass_action_type = nil
        lua_thread.create(function() wait(300 + math.random(150, 400)); sampSendDialogResponse(dialogId, 1, listItemIndex, "") end)
        return false
    end

    if is_checking_stroy then
        local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
        local has_next, next_idx, listitem_index, is_first_line, found_on_page = false, -1, 0, true, 0

        for line in text:gmatch("[^\r\n]+") do
            local clean = line:gsub("{.-}", "") 
            if is_first_line and style == 5 then is_first_line = false
            else
                is_first_line = false
                if clean:find("»»»") or clean:find("Следующая") or clean:find("СЛЕДУЮЩАЯ") then has_next, next_idx = true, listitem_index
                elseif not (clean:find("«««") or clean:find("Предыдущая") or clean:find("ПРЕДЫДУЩАЯ")) then
                    local cols = {}
                    for col in clean:gmatch("[^\t]+") do table.insert(cols, col) end
                    if #cols >= 3 then
                        local nick = cols[1]:match("([A-Za-z0-9_]+)%s*%(") 
                        local id = tonumber(cols[1]:match("%((%d+)%)"))
                        if id then
                            local rank = tonumber(cols[2]:match("%((%d+)%)") or cols[2]:match("(%d+)") or 0)
                            local fwarns = tonumber(cols[3]:match("^%s*(%d+)") or 0)
                            local skip = (id == myId) or (ignore_rank_8_plus[0] and rank >= 8) or (ignore_2_fwarns[0] and fwarns >= 2) or nearby_players_list[id] or (nick and cfg.whitelist[nick])

                            if not skip then
                                local already_in = false
                                for _, v in ipairs(current_punish_list) do if v == id then already_in = true break end end
                                if not already_in then table.insert(current_punish_list, id); found_on_page = found_on_page + 1 end
                            end
                        end
                    end
                end
                listitem_index = listitem_index + 1
            end
        end

        addToast(u8(string.format("Стр. %d | Добавлено: %d | Дальше: %s", page_counter, found_on_page, (has_next and "ДА" or "НЕТ"))), 1)

        if has_next and next_idx ~= -1 and page_counter < 15 then
            page_counter = page_counter + 1
            lua_thread.create(function() wait(800); sampSendDialogResponse(dialogId, 1, next_idx, "") end)
        else
            is_checking_stroy = false
            lua_thread.create(function()
                wait(500); sampSendDialogResponse(dialogId, 0, 0, "") 
                if #current_punish_list == 0 then addToast(u8"Проверка окончена. Все в строю!", 2)
                else
                    addToast(u8("Прогульщиков: " .. #current_punish_list .. ". Выдаю выговоры..."), 2)
                    for _, pid in ipairs(current_punish_list) do sampSendChat(string.format("/fwarn %d %s", pid, u8:decode(ffi.string(punish_reason)))); wait(punish_delay[0] * 1000) end
                    addToast(u8"Выдача завершена!", 2)
                end
            end)
        end
        return true 
    end
    return true
end

function sampev.onSendPlayerSync(data)
    if press_alt_sync then data.keysData = bit.bor(data.keysData, 1024) end
end