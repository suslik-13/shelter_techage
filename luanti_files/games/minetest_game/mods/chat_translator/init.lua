--[[
    Minetest Chat Translator
    Version: 1
    License: AGPLv3
    
    LibreTranslate
    Free and Open Source Machine Translation API
    License: AGPLv3 
]]--

local languages = {}
local http = minetest.request_http_api()

-- Per-player translation preferences (persist across server restarts)
local storage = minetest.get_mod_storage()

-- Minimum confidence (%) from LibreTranslate's language detector required
-- before we trust the detected language over the player's declared interface language.
local MIN_DETECTION_CONFIDENCE = 50

--returns true if the player wants to see translations of incoming messages (default true)
local function receive_translation_enabled(name)
    local stored = storage:get_string("recv_" .. name)
    if stored == "" then return true end
    return stored == "true"
end

--returns true if the player allows their outgoing messages to be translated (default true)
local function send_translation_enabled(name)
    local stored = storage:get_string("send_" .. name)
    if stored == "" then return true end
    return stored == "true"
end

--detects the real language of a message via LibreTranslate's /detect endpoint.
--callback is called with (language_code, confidence), or with (nil) if detection failed
local function detect_message_language(message, callback)
    if not http then
        callback(nil)
        return
    end
    local url = 'http://libretranslate:5000/detect'
    local post_data = { q = message }
    local headers = {
        ["Accept"] = "accept: application/json",
        ["Content-Type"] = "application/x-www-form-urlencoded"
    }
    http.fetch({ url = url, post_data = post_data, extra_headers = headers }, function(response)
        if not response or not response.completed or not response.data or response.data == "" then
            callback(nil)
            return
        end
        if response.code and response.code ~= 200 then
            callback(nil)
            return
        end
        local ok, data_json = pcall(minetest.parse_json, response.data)
        if ok and data_json and data_json[1] and data_json[1].language then
            callback(data_json[1].language, data_json[1].confidence)
        else
            callback(nil)
        end
    end)
end

--picks the effective source language for a message.
--If the detector identified the message's real language with enough confidence and
--that language differs from the player's interface language (and is supported by
--LibreTranslate), we use the detected language instead — otherwise, for example,
--Russian text typed by a player with an English interface would be translated as
--if it were English.
--If neither the declared nor the detected language is known, returns "" (translation
--is not possible — we must not fall back to "en" by default).
local function resolve_source_language(declared_language, detected_language, confidence)
    if detected_language and detected_language ~= "" and language_available(detected_language)
        and (confidence == nil or confidence >= MIN_DETECTION_CONFIDENCE) then
        return detected_language
    end
    return declared_language or ""
end

--returns an error if the mod is not trusted
 minetest.register_on_prejoinplayer(function(pname)
    if not http then
        return "\n\nChat Translator needs to be added to your trusted mods list.\n" ..
            "To do so, click on the 'Settings' tab in the main menu.\n" ..
            "Click the 'All Settings' button and in the search bar, enter 'trusted'.\n" ..
            "Click the 'Edit' button and add 'chat_translator' to the list."
    end
    -- Try to load languages when player joins
    minetest.after(2, function()
        if http then
            http.fetch({ url = "http://libretranslate:5000/languages" }, get_languages)
        end
    end)
end)

--intercepts chat messages and sends an http request to libretranslate
minetest.after(0, minetest.register_on_chat_message, function(name, message)
--minetest.register_on_chat_message(function(name, message)
    if http then
        local declared_language = minetest.get_player_information(name).lang_code or ""
        minetest.log("action", "Chat Translator: DEBUG " .. name .. " declared_language='" .. declared_language .. "'")
        detect_message_language(message, function(detected_language, confidence)
            minetest.log("action", "Chat Translator: DEBUG " .. name .. " detected_language=" .. tostring(detected_language) .. " confidence=" .. tostring(confidence))
            local sender_language = resolve_source_language(declared_language, detected_language, confidence)
            minetest.log("action", "Chat Translator: DEBUG " .. name .. " resolved sender_language='" .. sender_language .. "' language_available=" .. tostring(language_available(sender_language)))
            send_to_all(message, name, sender_language, false)
        end)
        -- We've handled broadcasting/translation for players ourselves,
        -- so suppress the engine's default broadcast to avoid duplicates.
        -- Discord relay receives the original via `discord.send` or the
        -- `_discord_pending` queue, so it's safe to return true here.
        return true
    end
end)

--overrides the builtin direct message function
minetest.override_chatcommand("msg", {
    params = "",
    description = "",
    privs = { shout = true },
    func = function(name, param)
        local receiver_name, message = param:match("^(%S+)%s(.+)$")
        if not receiver_name then
            send_server_msg("Invalid usage. Try " .. "[/msg name message]", name)
            return true
        end
        if not minetest.get_player_by_name(receiver_name) then
            send_server_msg("The recipient is not online.", name)
            return true
        end
        send_dm(message, name, receiver_name)
        send_server_msg("Message sent.", name)
        return true
    end,
})

--overrides the builtin emote function
minetest.override_chatcommand("me", {
    params = "",
    description = "",
    privs = { shout = true },
    func = function(name, param)
        if param ~= "" then
            local declared_language = minetest.get_player_information(name).lang_code or ""
            detect_message_language(param, function(detected_language, confidence)
                local sender_language = resolve_source_language(declared_language, detected_language, confidence)
                send_to_all(param, name, sender_language, true)
            end)
            return true
        else
            send_server_msg("Invalid usage. Try [/me does something]", name)
            return true
        end
    end,
})

--lets a player disable translation of incoming messages (see everything in the original language)
minetest.register_chatcommand("no_translate", {
    params = "",
    description = "Disable translation of incoming messages from other players",
    func = function(name)
        storage:set_string("recv_" .. name, "false")
        return true, "Translation of incoming messages is now disabled. You will see messages in their original language."
    end,
})

--lets a player re-enable translation of incoming messages
minetest.register_chatcommand("translate", {
    params = "",
    description = "Enable translation of incoming messages from other players",
    func = function(name)
        storage:set_string("recv_" .. name, "true")
        return true, "Translation of incoming messages is now enabled."
    end,
})

--stops a player's own messages from being translated for others
minetest.register_chatcommand("no_translate_me", {
    params = "",
    description = "Prevent your messages from being translated for other players",
    func = function(name)
        storage:set_string("send_" .. name, "false")
        return true, "Your messages will no longer be translated for other players."
    end,
})

--allows a player's own messages to be translated for others again
minetest.register_chatcommand("translate_me", {
    params = "",
    description = "Allow your messages to be translated for other players",
    func = function(name)
        storage:set_string("send_" .. name, "true")
        return true, "Your messages will be translated for other players again."
    end,
})
 
 --sends a translated message from the server to a player
function send_server_msg(message, receiver_name)
    local receiver_language = minetest.get_player_information(receiver_name).lang_code
    local params = {
        message = message,
        sender_name = "Minetest",
        receiver_name = receiver_name,
        sender_language = "en",
        receiver_language = receiver_language,
        prefix = "<",
        suffix = "> "
    }
    if language_available(receiver_language) == false or receiver_language == "en" or not receive_translation_enabled(receiver_name) then
        minetest.chat_send_player(params.receiver_name, minetest.format_chat_message(params.sender_name, message))
    else
        send_message(params)
    end
end
 
--translates and sends a direct message
function send_dm(message, sender_name, receiver_name)
    local declared_sender_language = minetest.get_player_information(sender_name).lang_code or ""
    detect_message_language(message, function(detected_language, confidence)
        local sender_language = resolve_source_language(declared_sender_language, detected_language, confidence)
        local receiver_language = minetest.get_player_information(receiver_name).lang_code or ""
        local sender_lang_known = sender_language ~= "" and language_available(sender_language)
        local receiver_lang_known = receiver_language ~= "" and language_available(receiver_language)
        local params = {
            message = message,
            sender_name = sender_name,
            receiver_name = receiver_name,
            sender_language = sender_language,
            receiver_language = receiver_language,
            prefix = "<",
            suffix = "> ► <" .. receiver_name .. "> "
        }
        if not sender_lang_known or not receiver_lang_known or sender_language == receiver_language
            or not send_translation_enabled(sender_name) or not receive_translation_enabled(receiver_name) then
            minetest.chat_send_player(params.receiver_name, minetest.format_chat_message(params.sender_name, message))
        else
            send_message(params)
        end
    end)
end

--translates and delivers the message to all players
function send_to_all(message, sender_name, sender_language, emote)
    local prefix = emote and "* " or "<" 
    local suffix = emote and " " or "> "
    -- If a Discord relay mod is present, send the original player's message once.
    -- Otherwise queue it in `_discord_pending` so the relay can drain it later.
    if rawget(_G, "discord") and type(discord.send) == "function" then
        pcall(function()
            discord.send(('<%s> %s'):format(sender_name, message))
        end)
    else
        _G._discord_pending = _G._discord_pending or {}
        table.insert(_G._discord_pending, ('%s: %s'):format(sender_name, message))
    end
    local sender_translate_ok = send_translation_enabled(sender_name)
    -- If the sender's language is unknown (empty string) or not supported by
    -- LibreTranslate, translation is simply not possible — do not fall back to "en".
    local sender_lang_known = sender_language ~= "" and language_available(sender_language)
    for _,player in pairs(minetest.get_connected_players()) do
        local receiver_name = player:get_player_name()
        local receiver_language = minetest.get_player_information(receiver_name).lang_code
        -- Same reasoning for the receiver: if their language is unknown, we can't
        -- translate for them either — send the original instead of guessing "en".
        local receiver_lang_known = receiver_language ~= "" and language_available(receiver_language)
        minetest.log("action", "Chat Translator: DEBUG receiver=" .. receiver_name ..
            " receiver_language='" .. tostring(receiver_language) .. "'" ..
            " receiver_lang_known=" .. tostring(receiver_lang_known) ..
            " sender_lang_known=" .. tostring(sender_lang_known) ..
            " sender_translate_ok=" .. tostring(sender_translate_ok) ..
            " receive_translation_enabled=" .. tostring(receive_translation_enabled(receiver_name)) ..
            " same_language=" .. tostring(sender_language == receiver_language))
        if not sender_lang_known or not receiver_lang_known or sender_language == receiver_language
            or not sender_translate_ok or not receive_translation_enabled(receiver_name) then
            minetest.chat_send_player(receiver_name, minetest.format_chat_message(sender_name, message))
        else
            local params = {
                message = message,
                sender_name = sender_name,
                receiver_name = receiver_name,
                sender_language = sender_language,
                receiver_language = receiver_language,
                prefix = prefix,
                suffix = suffix
            }
            send_message(params)
        end
    end
end

--translates the message and sends it to the receiver
function send_message(params)
    local url = 'http://libretranslate:5000/translate'
    local post_data = { 
        q = params.message,
        source = params.sender_language,
        target = params.receiver_language 
    }
    local headers = {
        ["Accept"] = "accept: application/json", 
        ["Content-Type"] = "application/x-www-form-urlencoded" 
    }
    local request = { url = url, post_data = post_data, extra_headers = headers }
    http.fetch(request, function(response)
        -- If the request did not complete, log and send original message
        if not response or not response.completed then
            minetest.log("error", "Chat Translator: HTTP request not completed or no response object")
            minetest.chat_send_player(params.receiver_name, minetest.format_chat_message(params.sender_name, params.message))
            return
        end

        -- Guard against empty body
        if not response.data or response.data == "" then
            minetest.log("error", "Chat Translator: empty response body from translate endpoint")
            minetest.chat_send_player(params.receiver_name, minetest.format_chat_message(params.sender_name, params.message))
            return
        end

        -- Check HTTP status code
        if response.code and response.code ~= 200 then
            minetest.log("error", "Chat Translator: HTTP error " .. tostring(response.code) .. ": " .. (response.data or "no response data"))
            minetest.chat_send_player(params.receiver_name, minetest.format_chat_message(params.sender_name, params.message))
            return
        end

        local msg = params.message
        local ok, data_json = pcall(minetest.parse_json, response.data)
        if ok and data_json and (data_json.translatedText or data_json.translated_text) then
            msg = data_json.translatedText or data_json.translated_text
        else
            minetest.log("error", "Chat Translator: failed to parse translation JSON or missing translatedText field")
            minetest.chat_send_player(params.receiver_name, minetest.format_chat_message(params.sender_name, params.message))
            return
        end

        if msg then
            -- Let the receiver know this message was translated, and from which language
            local translated_note = minetest.colorize("yellow", " (translated from: " .. params.sender_language:upper() .. ")")
            minetest.chat_send_player(params.receiver_name, minetest.format_chat_message(params.sender_name, msg) .. translated_note)
        else
            minetest.log("error", "Chat Translator: msg is nil, cannot send message")
            minetest.chat_send_player(params.receiver_name, minetest.format_chat_message(params.sender_name, params.message))
        end
    end)
end

--gets all language codes from libretranslate
function get_languages(response)
    if not response.completed then
        minetest.log("error", "Chat Translator: HTTP request to LibreTranslate failed")
        return
    end
    local data_json = minetest.parse_json(response.data)
    if data_json then
        languages = {}
        for _, language in pairs(data_json) do
            table.insert(languages, language.code)
        end
        minetest.log("action", "Chat Translator: Successfully loaded " .. #languages .. " languages")
        minetest.log("action", "Chat Translator: DEBUG languages list = " .. table.concat(languages, ", "))
    else
        handle_failure("Failed to retrieve list of languages from libretranslate.")
        -- Retry after 10 seconds
        minetest.after(10, function()
            if http then
                http.fetch({ url = "http://libretranslate:5000/languages" }, get_languages)
            end
        end)
    end
end

--handles failed http requests
function handle_failure(message)
    minetest.log("error", "Chat Translator: " .. message)
    minetest.log("error", "Please ensure libretranslate is available at http://libretranslate:5000/translate")
end

--checks if libretranslate supports the language
function language_available(language)
    if #languages == 0 then
        if http then
            http.fetch({ url = "http://libretranslate:5000/languages" }, get_languages)
        end
    end
    return contains_value(languages, language)
end

--returns true if the table contains the given value
function contains_value(tbl, value)
    for k, v in pairs(tbl) do
        if v == value then return true end
    end
    return false
end
