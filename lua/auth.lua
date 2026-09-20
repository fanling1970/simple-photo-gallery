local ngx = require "ngx"
local dkjson = require "dkjson"

local config_path = "/usr/share/nginx/config/users.json"

local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

local function read_users()
    local f = io.open(config_path, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return dkjson.decode(data)
end

local function write_users(users)
    local f = io.open(config_path, "w")
    if not f then return false end
    f:write(dkjson.encode(users))
    f:close()
    return true
end

-- 读取用户库
local users = read_users()

-- 首次访问，没有用户文件，跳转到初始化页面
if not file_exists(config_path) then
    return ngx.redirect("/setup.html")
end

-- 登录接口 POST /api/auth
if ngx.var.uri == "/api/auth" and ngx.req.get_method() == "POST" then
    ngx.req.read_body()
    local args = ngx.req.get_post_args()
    local username = args.username or ""
    local pass = args.password or ""
    local user = users[username]

    local pass_hash = ngx.encode_base16(ngx.sha256_bin(pass)):lower()

    if user and user.pass == pass_hash then
        ngx.header["Set-Cookie"] = "token="..username.."; Path=/; HttpOnly"
        ngx.print(dkjson.encode({ok=true}))
    else
        ngx.print(dkjson.encode({ok=false, msg="账号或密码错误"}))
    end
    return ngx.exit(200)
end

-- 退出登录接口
if ngx.var.uri == "/api/logout" and ngx.req.get_method() == "GET" then
    ngx.header["Set-Cookie"] = "token=; Path=/; HttpOnly; Expires=Thu, 01 Jan 1970 00:00:00 GMT"
    return ngx.redirect("/login.html")
end

-- 校验cookie token
local token = ngx.var.http_cookie
local login_user = nil
if token then
    token = token:match("token=([^;]+)")
    if token and users[token] then
        login_user = token
    end
end

-- 静态页面路由控制
local uri = ngx.var.uri
-- 登录页、初始化页面放行
if uri == "/login.html" or uri == "/setup.html" then
    return
end

-- 未登录，跳转登录页
if not login_user then
    return ngx.redirect("/login.html")
end

-- 已登录，放行所有资源
return
