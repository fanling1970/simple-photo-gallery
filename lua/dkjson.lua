-- dkjson.lua - JSON library for Lua
-- https://github.com/LuaDist/dkjson
local dkjson = {}
local json = dkjson

local function encode_helper(value, state)
    local t = type(value)
    if t == "nil" then return "null" end
    if t == "boolean" then return value and "true" or "false" end
    if t == "number" then
        if value ~= value then return "null" end
        if value == 1/0 then return "null" end
        if value == -1/0 then return "null" end
        return tostring(value)
    end
    if t == "string" then
        return '"' .. value:gsub('["\\\b\f\n\r\t]', {
            ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b',
            ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t'
        }) .. '"'
    end
    if t == "table" then
        local is_array = true
        local max_idx = 0
        for k, v in pairs(value) do
            if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                is_array = false
                break
            end
            if k > max_idx then max_idx = k end
        end
        if is_array then
            local arr = {}
            for i = 1, max_idx do
                arr[i] = encode_helper(value[i], state)
            end
            return "[" .. table.concat(arr, ",") .. "]"
        else
            local obj = {}
            for k, v in pairs(value) do
                local key = encode_helper(tostring(k), state)
                local val = encode_helper(v, state)
                table.insert(obj, key .. ":" .. val)
            end
            return "{" .. table.concat(obj, ",") .. "}"
        end
    end
    return "null"
end

function dkjson.encode(value)
    return encode_helper(value, {})
end

local function decode_helper(str, pos)
    pos = pos or 1
    local c = str:sub(pos, pos)
    while c == " " or c == "\t" or c == "\n" or c == "\r" do
        pos = pos + 1
        c = str:sub(pos, pos)
    end
    if c == "{" then
        local obj = {}
        pos = pos + 1
        while true do
            local k, v
            k, pos = decode_helper(str, pos)
            if k == nil then break end
            while str:sub(pos,pos):match("%s") do pos = pos+1 end
            if str:sub(pos,pos) ~= ":" then return nil, pos end
            pos = pos + 1
            v, pos = decode_helper(str, pos)
            obj[k] = v
            while str:sub(pos,pos):match("%s") do pos = pos+1 end
            if str:sub(pos,pos) == "}" then pos = pos+1; break end
            if str:sub(pos,pos) ~= "," then return nil, pos end
            pos = pos +1
        end
        return obj, pos
    elseif c == "[" then
        local arr = {}
        pos = pos +1
        local idx = 1
        while true do
            local v
            v, pos = decode_helper(str, pos)
            if v == nil then break end
            arr[idx] = v
            idx = idx + 1
            while str:sub(pos,pos):match("%s") do pos = pos+1 end
            if str:sub(pos,pos) == "]" then pos = pos+1; break end
            if str:sub(pos,pos) ~= "," then return nil, pos end
            pos = pos +1
        end
        return arr, pos
    elseif c == '"' then
        pos = pos +1
        local s = ""
        while true do
            local ch = str:sub(pos,pos)
            if ch == '"' then pos = pos+1; break end
            if ch == "\\" then
                pos = pos+1
                ch = str:sub(pos,pos)
                if ch == "n" then ch = "\n"
                elseif ch == "r" then ch = "\r"
                elseif ch == "t" then ch = "\t"
                elseif ch == "b" then ch = "\b"
                elseif ch == "f" then ch = "\f"
                end
            end
            s = s .. ch
            pos = pos + 1
        end
        return s, pos
    elseif str:sub(pos,pos+3) == "true" then
        return true, pos+4
    elseif str:sub(pos,pos+4) == "false" then
        return false, pos+5
    elseif str:sub(pos,pos+3) == "null" then
        return nil, pos+4
    elseif c:match("[%d%-]") then
        local num_end = pos
        while str:sub(num_end,num_end):match("[%d%.eE%+%-]") do num_end = num_end+1 end
        local numstr = str:sub(pos, num_end-1)
        local num = tonumber(numstr)
        return num, num_end
    end
    return nil, pos
end

function dkjson.decode(str)
    local val, pos = decode_helper(str,1)
    return val
end

return dkjson
