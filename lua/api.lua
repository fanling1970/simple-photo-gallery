local ngx = require "ngx"
local dkjson = require "dkjson"
local sha2 = require "sha2"

local config_path = "/usr/share/nginx/config/users.json"
local photo_dir = "/usr/share/nginx/html/photos/images"

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

local function is_logged_in()
    if not exists(config_path) then return false end
    local token = (ngx.var.http_cookie or ""):match("token=([^;]+)")
    if not token then return false end
    return read_users()[token] ~= nil
end

local function reply(obj)
    ngx.print(dkjson.encode(obj))
    return ngx.exit(200)
end

local uri = ngx.var.uri
local method = ngx.req.get_method()

-- 首次初始化管理员
if uri == "/api/setup" and method == "POST" then
    if exists(config_path) then return reply({ok=false, msg="管理员已创建，不可重复初始化"}) end
    ngx.req.read_body()
    local args = ngx.req.get_post_args()
    local username = (args.username or ""):gsub("%s","")
    local pass = args.password or ""
    if #username < 1 then return reply({ok=false, msg="用户名不能为空"}) end
    if #pass < 4 then return reply({ok=false, msg="密码至少4位"}) end
    if not write_users({[username]={pass=sha(pass)}}) then
        return reply({ok=false, msg="写入失败，请检查 config 目录权限"})
    end
    ngx.header["Set-Cookie"] = "token="..username.."; Path=/; HttpOnly"
    return reply({ok=true})
end

-- 登录
if uri == "/api/auth" and method == "POST" then
    ngx.req.read_body()
    local args = ngx.req.get_post_args()
    local username = (args.username or ""):gsub("%s","")
    local pass = args.password or ""
    local u = read_users()[username]
    if u and u.pass == sha(pass) then
        ngx.header["Set-Cookie"] = "token="..username.."; Path=/; HttpOnly"
        return reply({ok=true})
    end
    return reply({ok=false, msg="用户名或密码错误"})
end

-- 图片列表（扫描 photos 目录）
if uri == "/api/list" then
    local p = io.popen("ls -1 " .. photo_dir .. " 2>/dev/null")
    local out = p:read("*a") p:close()
    local files = {}
    for line in out:gmatch("[^\n]+") do
        if line:match("%.[jJ][pP][eE]?[gG]$") or line:match("%.[pP][nN][gG]$")
           or line:match("%.[gG][iI][fF]$") or line:match("%.[wW][eE][bB][pP]$") then
            files[#files+1] = line
        end
    end
    return reply(files)
end

-- 图片上传（二进制直传）
if uri == "/api/upload" and method == "POST" then
    if not is_logged_in() then return reply({ok=false, msg="未登录"}) end
    ngx.req.read_body()
    local data = ngx.req.get_body_data()
    if not data or #data == 0 then return reply({ok=false, msg="未收到文件内容"}) end
    local name = (ngx.var.arg_name or ""):gsub("[^%w%.%-_]", "")
    if name == "" then return reply({ok=false, msg="文件名不合法"}) end
    os.execute("mkdir -p " .. photo_dir .. "/thumb")
    local final = tostring(os.time()) .. "_" .. name
    local f = io.open(photo_dir .. "/" .. final, "wb")
    if not f then return reply({ok=false, msg="无法写入图片目录"}) end
    f:write(data) f:close()
    -- 生成缩略图
    os.execute(string.format('magick "%s/%s" -resize 400x400 -quality 80 "%s/thumb/%s"', photo_dir, final, photo_dir, final))
    return reply({ok=true, name=final})
end

return reply({ok=false, msg="未知接口"})
