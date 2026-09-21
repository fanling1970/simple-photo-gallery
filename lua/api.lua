local ngx = require "ngx"
local dkjson = require "dkjson"
local sha2 = require "sha2"

local config_path = "/usr/share/nginx/config/users.json"
local photo_dir = "/usr/share/nginx/html/photos/images"
local list_cache = "/usr/share/nginx/config/list_cache.json"
local timeline_cache = "/usr/share/nginx/config/timeline_cache.json"

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
    ngx.header["Cache-Control"] = "no-store, no-cache, must-revalidate"
    ngx.print(dkjson.encode(obj))
    return ngx.exit(200)
end

local function is_video(n)
    return n:match("%.[mM][pP]4$") or n:match("%.[wW][eE][bB][mM]$")
        or n:match("%.[mM][oO][vV]$") or n:match("%.[mM][kK][vV]$")
end

local function get_date_dir(path)
    local y, m, d
    local h = io.popen('identify -format "%[EXIF:DateTimeOriginal]" "' .. path .. '" 2>/dev/null')
    local exif = h:read("*a") h:close()
    if exif and exif ~= "" then
        y, m, d = exif:match("(%d%d%d%d):(%d%d):(%d%d)")
    end
    if not y then
        local h2 = io.popen('stat -c "%y" "' .. path .. '" 2>/dev/null')
        local mt = h2:read("*a") h2:close()
        y, m, d = mt:match("(%d%d%d%d)-(%d%d)-(%d%d)")
    end
    if not y then
        local t = os.date("*t")
        y, m, d = tostring(t.year), string.format("%02d", t.month), string.format("%02d", t.day)
    end
    return y .. "/" .. m .. "/" .. d
end

local function list_media()
    local cf = io.open(list_cache, "r")
    if cf then
        local data = cf:read("*a") cf:close()
        local files = dkjson.decode(data)
        if type(files) == "table" then return files end
    end
    local cmd = 'find "' .. photo_dir .. '" -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mov" -o -iname "*.mkv" \\) ! -path "*/thumb/*" 2>/dev/null'
    local p = io.popen(cmd)
    local out = p:read("*a") p:close()
    local prefix = photo_dir .. "/"
    local files = {}
    for line in out:gmatch("[^\n]+") do
        files[#files + 1] = line:sub(#prefix + 1)
    end
    table.sort(files, function(a, b) return a > b end)
    local wf = io.open(list_cache, "w")
    if wf then wf:write(dkjson.encode(files)) wf:close() end
    return files
end

local function invalidate_cache()
    os.execute("rm -f '" .. list_cache .. "' '" .. timeline_cache .. "'")
end

local uri = ngx.var.uri
local method = ngx.req.get_method()

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

if uri == "/api/list" then
    return reply(list_media())
end

if uri == "/api/timeline" then
    local cf = io.open(timeline_cache, "r")
    if cf then
        local data = cf:read("*a") cf:close()
        ngx.header["Cache-Control"] = "no-store"
        ngx.print(data)
        return ngx.exit(200)
    end
    local files = list_media()
    local groups = {}
    for _, rel in ipairs(files) do
        local y, m = rel:match("^(%d%d%d%d)/(%d%d)/")
        if y and m then
            local ym = y .. "-" .. m
            groups[ym] = groups[ym] or {}
            table.insert(groups[ym], rel)
        end
    end
    local wf = io.open(timeline_cache, "w")
    if wf then wf:write(dkjson.encode(groups)) wf:close() end
    return reply(groups)
end

if uri == "/api/upload" and method == "POST" then
    if not is_logged_in() then return reply({ok=false, msg="未登录"}) end
    ngx.req.read_body()
    local data = ngx.req.get_body_data()
    if not data then
        local tmpfile = ngx.req.get_body_file()
        if tmpfile then
            local tf = io.open(tmpfile, "r")
            if tf then data = tf:read("*a") tf:close() end
        end
    end
    if not data or #data == 0 then return reply({ok=false, msg="未收到文件内容"}) end
    local name = (ngx.var.arg_name or ""):gsub("[^%w%.%-_]", "")
    if name == "" then return reply({ok=false, msg="文件名不合法"}) end

    local tmp = photo_dir .. "/__tmp_" .. tostring(os.time()) .. "_" .. name
    local tf = io.open(tmp, "wb")
    if not tf then return reply({ok=false, msg="无法写入图片目录"}) end
    tf:write(data) tf:close()

    local datadir = get_date_dir(tmp)
    local fulldir = photo_dir .. "/" .. datadir
    os.execute("mkdir -p '" .. fulldir .. "/thumb'")

    local dest = fulldir .. "/" .. name
    local n = 1
    while exists(dest) do
        local base, ext = name:match("^(.-)(%.[^%.]+)$")
        if base then
            dest = fulldir .. "/" .. base .. "_" .. n .. ext
        else
            dest = fulldir .. "/" .. name .. "_" .. n
        end
        n = n + 1
    end

    os.execute('mv "' .. tmp .. '" "' .. dest .. '"')
    local final = dest:sub(#photo_dir + 2)

    if not is_video(name) then
        local thumbname = dest:match("([^/]+)$")
        os.execute(string.format('magick "%s" -resize 400x400 -quality 80 "%s/thumb/%s"', dest, fulldir, thumbname))
    end

    invalidate_cache()
    return reply({ok=true, name=final})
end

return reply({ok=false, msg="未知接口"})
