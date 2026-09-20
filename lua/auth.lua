local ngx = require "ngx"
local config_path = "/usr/share/nginx/config/users.json"

local function exists(p)
    local f = io.open(p, "r")
    if f then f:close() return true end
    return false
end

-- 未初始化 → 跳 setup
if not exists(config_path) then
    return ngx.redirect("/setup.html")
end

local token = (ngx.var.http_cookie or ""):match("token=([^;]+)")
if not token then
    return ngx.redirect("/login.html")
end

local f = io.open(config_path, "r")
if not f then return ngx.redirect("/login.html") end
local d = f:read("*a") f:close()
local users = require("dkjson").decode(d)
if not users or not users[token] then
    return ngx.redirect("/login.html")
end
