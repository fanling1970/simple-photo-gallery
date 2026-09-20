local ngx = require "ngx"
local json = require "dkjson"
local io = require "io"

local config_path = "/usr/share/nginx/config/users.json"

-- 读取用户配置文件
local function read_users()
    local f = io.open(config_path, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    local users = json.decode(data, 1, nil)
    return users
end

local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

-- 首次部署，users.json不存在，跳转到初始化账号页面
if not file_exists(config_path) then
    return ngx.redirect("/setup.html")
end

local users = read_users()
local token = ngx.var.http_cookie and ngx.var.http_cookie:match("token=([^;]+)")

-- 登录接口POST校验
if ngx.var.uri == "/api/auth" and ngx.req.get_method() == "POST" then
    ngx.req.read_body()
    local args = ngx.req.get_post_args()
    local username = args.username
    local pass = args.password
    local user = users[username]
    local pass_hash = ngx.encode_base16(ngx.sha256_bin(pass)):lower()
    if user and user.pass == pass_hash then
        ngx.header["Set-Cookie"] = "token="..username.."; Path=/; Max-Age=86400"
        ngx.print(json.encode({ok=true}))
    else
        ngx.print(json.encode({ok=false,msg="账号或密码错误"}))
    end
    return ngx.exit(200)
end

-- 访问静态资源校验token
if not token or not users[token] then
    return ngx.redirect("/login.html")
end
