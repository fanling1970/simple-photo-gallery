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

local function write_users(users)
    local f = io.open(config_path, "w")
    if not f then return false end
    f:write(dkjson.encode(users))
    f:close()
    return true
end

-- 用户文件已存在，禁止再次初始化
if file_exists(config_path) then
    ngx.print(dkjson.encode({ok=false, msg="用户已初始化，不可重复创建"}))
    return ngx.exit(200)
end

-- 处理POST初始化请求
if ngx.var.uri == "/api/init-user" and ngx.req.get_method() == "POST" then
    ngx.req.read_body()
    local args = ngx.req.get_post_args()
    local username = args.username or ""
    local pass = args.password or ""

    if #username <1 or #pass <4 then
        ngx.print(dkjson.encode({ok=false, msg="用户名不能为空，密码至少4位"}))
        return ngx.exit(200)
    end

    local pass_hash = ngx.encode_base16(ngx.sha256_bin(pass)):lower()
    local new_user = {
        [username] = {
            pass = pass_hash
        }
    }
    local ok = write_users(new_user)
    if ok then
        ngx.print(dkjson.encode({ok=true, msg="创建成功，请前往登录"}))
    else
        ngx.print(dkjson.encode({ok=false, msg="写入用户配置失败，检查目录权限"}))
    end
    return ngx.exit(200)
end

return
