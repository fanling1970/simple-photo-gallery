local ngx = require "ngx"
local json = require "dkjson"
local io = require "io"
local bcrypt = require "bcrypt"
local config_path = "/usr/share/nginx/config/users.json"

local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

if file_exists(config_path) then
    ngx.print(json.encode({ok=false,msg="管理员账号已创建，不可重复初始化"}))
    return ngx.exit(200)
end

if ngx.req.get_method() == "POST" then
    ngx.req.read_body()
    local args = ngx.req.get_post_args()
    local username = args.username
    local password = args.password
    if not username or #username <1 or not password or #password <4 then
        ngx.print(json.encode({ok=false,msg="用户名/密码长度不足"}))
        return ngx.exit(200)
    end
    -- lua-bcrypt生成哈希，不需要调用外部命令
    local hash = bcrypt.digest(password, 10)
    local users = {[username]={pass=hash}}
    local f = io.open(config_path,"w")
    f:write(json.encode(users))
    f:close()
    ngx.header["Set-Cookie"] = "token="..username.."; Path=/; Max-Age=86400"
    ngx.print(json.encode({ok=true}))
end
