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

local function is_video(n)
    return n:match("%.[mM][pP]4$") or n:match("%.[wW][eE][bB][mM]$")
        or n:match("%.[mM][oO][vV]$") or n:match("%.[mM][kK][vV]$")
end

-- 读取文件的拍摄日期 YYYY/MM/DD（优先EXIF，其次mtime）
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

-- 递归列出所有媒体文件（返回相对路径，排除thumb目录）
local function list_media()
    local cmd = 'find "' .. photo_dir .. '" -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mov" -o -iname "*.mkv" \\) ! -path "*/thumb/*" 2>/dev/null'
    local p = io.popen(cmd)
    local out = p:read("*a") p:close()
    local prefix = photo_dir .. "/"
    local files = {}
    for line in out:gmatch("[^\n]+") do
        local rel = line:sub(#prefix + 1)
        files[#files + 1] = rel
    end
    table.sort(files, function(a, b) return a > b end)  -- 路径即日期，倒序=新片在前
    return files
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

-- 列表（倒序）
if uri == "/api/list" then
    return reply(list_media())
end

-- 时间线（按 YYYY-MM 分组，直接从相对路径解析）
if uri == "/api/timeline" then
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
    return reply(groups)
end

-- 上传：按拍摄日期自动建年月日目录
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

    -- 先写临时文件用于识别EXIF
    local tmp = photo_dir .. "/__tmp_" .. tostring(os.time()) .. "_" .. name
    local tf = io.open(tmp, "wb")
    if not tf then return reply({ok=false, msg="无法写入图片目录"}) end
    tf:write(data) tf:close()

    -- 按拍摄日期建目录
    local datadir = get_date_dir(tmp)
    local fulldir = photo_dir .. "/" .. datadir
    os.execute("mkdir -p '" .. fulldir .. "/thumb'")

    -- 保留原文件名；同名则加序号
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

    -- 生成缩略图（视频暂不生成）
    if not is_video(name) then
        local thumbname = dest:match("([^/]+)$")
        os.execute(string.format('magick "%s" -resize 400x400 -quality 80 "%s/thumb/%s"', dest, fulldir, thumbname))
    end

    return reply({ok=true, name=final})

