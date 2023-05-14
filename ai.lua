require "moonloader"
local sampev = require "lib.samp.events"
local json = require "dkjson"
local iconv = require("iconv")
local encoding = require 'encoding'
local socket = require("socket")
local http = require("socket.http")
-- 
local ffi = require('ffi')
local effil = require('effil')
local faicons = require('fAwesome6')
-- 

encoding.default = 'CP1251'
local u8 = encoding.UTF8

local isQueryAsk = false;
local answerQueryAsk = '';

-- ����� ���� ������� � �������� ���������, ����� ���� ����������� ����� �� ������� ������ ������ gpt ������ �������, � ���� �� ������ ��� ������� � ��������

function main()
    while not isSampAvailable() do wait(100) end
    sampAddChatMessage("��������", -1)

    local messageCoroutine = coroutine.create(processMessage) -- �� �� ����� ���� ����� ��� ��� �� �� �������� ������ �� �������
    
    while true do
        if isQueryAsk then 
            sampSendChat('/c ' .. answerQueryAsk) -- ��� ������������
            isQueryAsk = false;
        end

        wait(0)
        if coroutine.status(messageCoroutine) == "dead" then
            messageCoroutine = coroutine.create(processMessage)
        end
        coroutine.resume(messageCoroutine)
    end
end

function all_trim(s)
    return s:match( "^%s*(.-)%s*$" )
end

function processMessage()
    sampev.onServerMessage = function(id, message)
        local pattern = "(%S+_%S+)%s+������[�]?:%s+(.*)" -- ������� ����� ������ � IC ����
        local name, text = message:match(pattern) -- �������� ������ � ������� regex
        -- ��� ��� ������ ����������� ����� ��� �� ������� ��� �� ���� �� ���������
        -- ��� ����� ��� ��� ����� �� ������� �� �� ������ �����������
        if name ~= "��� ���" and text ~= "��� ����� (�����������)" and name ~= nil and text ~= nil and string.len(text) > 5 then
            local cd = iconv.new("utf-8", "windows-1251")
            local cdb = iconv.new("windows-1251", "utf-8") -- ������ ������� ������ � ������ ��������� � ��� �� ����� ����� �� �������� ������ �� �������
            local conv_text = cd:iconv(text)
            -- 
            asyncHttpRequest('POST', 'https://api.openai.com/v1/chat/completions', {
                headers = {
                    ['Authorization'] = 'Bearer ����_���_�����_open_ai', 
                    ['Content-Type'] = 'application/json'
                }, 
                data = u8(encodeJson({ -- ������ � �������� ��������, ���� �������� ���� ����������� ��� ��� ����
                    ["model"] = "gpt-3.5-turbo",
                    ["messages"] = {
                        {
                            ["role"] = "system",
                            ["content"] = "Your name is Bobby."
                        },
                        {
                            ["role"] = "user",
                            ["content"] = conv_text
                        }
                    },
                    ["temperature"] = 0.7,
                    ["max_tokens"] = 256,
                    ["top_p"] = 0.9,
                    ["frequency_penalty"] = 0.5,
                    ["presence_penalty"] = 0.5,
                    ["stop"] = {"You:"}
                }))
            },
            function(response)
                if response.status_code == 200 then
                    local RESULT = decodeJson(response.text)
                    if RESULT.choices and #RESULT.choices > 0 then
                        local text = RESULT.choices[1].message.content
                        if text ~= nil then
                            text = u8:decode(text)
                            if customCallback then
                                customCallback(text)
                            else
                                sampSendChat("/c " .. text)
                            end
                        else
                        end
                    else
                    end
                else
                end
            end,
            function(err)
                print("???: " .. err)
            end
        )
        end
    end
    coroutine.yield()
end

function asyncHttpRequest(method, url, args, resolve, reject)
    local request_thread = effil.thread(function (method, url, args)
        local requests = require 'requests'
        local result, response = pcall(requests.request, method, url, args)
        if result then
            response.json, response.xml = nil, nil
            return true, response
        else
            return false, response
        end
    end)(method, url, args)
    if not resolve then resolve = function() end end
    if not reject then reject = function() end end
    lua_thread.create(function()
        local runner = request_thread
        while true do
            local status, err = runner:status()
            if not err then
                if status == 'completed' then
                    local result, response = runner:get()
                    if result then
                        resolve(response)
                    else
                        reject(response)
                    end
                    return
                elseif status == 'canceled' then
                    return reject(status)
                end
            else
                return reject(err)
            end
            wait(0)
        end
    end)
end

function onScriptTerminate(script, quitGame)
end
