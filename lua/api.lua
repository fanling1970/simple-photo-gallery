local ngx = require "ngx"
local dkjson = require "dkjson"
local sha2 = require "sha2"

local config_path = "/usr/share/nginx/config/users.json"

local function exists(p)
    local f = io.open(p, "r")
    if f then f:close() return true end
    return false
end

local function read_users()
    local f = io.open(config_path, "r")
    if not f then return {} end
    local d = f:read("*a") f:close()
    local u = dkjson.decode(d)
    if type(u) ~= "table" then return {} end
    return u
end

local function write_users(u)
    local f = io.open(config_path, "w")
    if not f then return false end
    f:write(dkjson.encode(u)) f:close()
    return true
end

local function sha(s) return sha2.hex(s) end


ngx.req.read_body()
local args = ngx.req.get_post_args()
local uri = ngx.var.uri

if ngx.req.get_method() ~= "POST" then
    ngx.print(dkjson.encode({ok=false, msg="仅支持POST"})) return ngx.exit(200)
end

-- 首次初始化管理员（仅当 users.json 不存在）
if uri == "/api/setup" then
    if exists(config_path) then
        ngx.print(dkjson.encode({ok=false, msg="管理员已创建，不可重复初始化"}))
        return ngx.exit(200)
    end
    local username = (args.username or ""):gsub("%s","")
    local pass = args.password or ""
    if #username < 1 then
        ngx.print(dkjson.encode({ok=false, msg="用户名不能为空"})) return ngx.exit(200)
    end
    if #pass < 4 then
        ngx.print(dkjson.encode({ok=false, msg="密码至少4位"})) return ngx.exit(200)
    end
    if not write_users({[username]={pass=sha(pass)}}) then
        ngx.print(dkjson.encode({ok=false, msg="写入失败，请检查 config 目录权限"}))
        return ngx.exit(200)
    end
    ngx.header["Set-Cookie"] = "token="..username.."; Path=/; HttpOnly"
    ngx.print(dkjson.encode({ok=true}))
    return ngx.exit(200)
end

-- 登录
if uri == "/api/auth" then
    local username = (args.username or ""):gsub("%s","")
    local pass = args.password or ""
    local u = read_users()[username]
    if u and u.pass == sha(pass) then
        ngx.header["Set-Cookie"] = "token="..username.."; Path=/; HttpOnly"
        ngx.print(dkjson.encode({ok=true}))
    else
        ngx.print(dkjson.encode({ok=false, msg="用户名或密码错误"}))
    end
    return ngx.exit(200)
end

ngx.print(dkjson.encode({ok=false, msg="未知接口"}))
return ngx.exit(200)
