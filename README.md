# 个人服务器相册 (Simple Photo Gallery)

基于 Nginx 静态前端的轻量级个人相册，代码托管 GitHub，Docker 镜像自动构建，图片通过数据卷挂载存储。

## 架构说明

```
GitHub 仓库（源代码）
    │
    ├── GitHub Actions 自动构建
    │       └── 推送镜像到 GHCR (ghcr.io)
    │
服务器（Docker 运行）
    ├── 拉取 GHCR 镜像
    ├── 容器内：Nginx 服务 + 前端代码
    └── 数据卷挂载：宿主机 /opt/photo-images → 容器 /usr/share/nginx/html/img
```

**核心原则：镜像只包含程序代码，图片通过 volume 外部挂载，新增图片无需重建镜像。**

## 项目结构

```
simple-photo-gallery/
├── .github/workflows/
│   └── build-docker.yml    # GitHub Actions 自动构建 Docker 镜像
├── css/
│   └── style.css            # 相册样式
├── js/
│   └── gallery.js           # 相册交互逻辑
├── img/                     # 图片目录（git 忽略，运行时挂载）
├── .gitignore
├── Dockerfile               # Docker 镜像构建文件
├── docker-compose.yml       # 服务器部署配置
├── nginx.conf               # Nginx 配置
├── index.html               # 相册主页
└── README.md
```

## 快速开始

### 1. 推送到 GitHub

```bash
git init
git add .
git commit -m "init: basic photo gallery"
git remote add origin https://github.com/你的用户名/simple-photo-gallery.git
git branch -M main
git push -u origin main
```

推送后 GitHub Actions 会自动构建镜像并推送到 GHCR。

### 2. 设置 GHCR 镜像为公开

仓库页面 → Packages → 选择镜像 → Package settings → 拉到最下方 → Change visibility → Public

### 3. 服务器部署

```bash
# 创建图片目录
mkdir -p /opt/photo-images

# 上传图片到 /opt/photo-images

# 下载 docker-compose.yml 并修改镜像地址中的用户名
# 然后启动
docker compose up -d
```

访问 `http://服务器IP:8080` 即可查看相册。

## 本地开发测试

```bash
# 构建镜像
docker build -t simple-photo-gallery .

# 运行（挂载本地图片目录）
docker run -d -p 8080:80 \
  -v $(pwd)/img:/usr/share/nginx/html/img \
  simple-photo-gallery
```

访问 `http://localhost:8080`

## 后续迭代路线

- [ ] 自动扫描图片目录（无需手动维护图片列表）
- [ ] 图片分类 / 文件夹相册
- [ ] 缩略图自动生成
- [ ] 网页上传图片功能
- [ ] 分页 / 搜索 / EXIF 信息展示
- [ ] 账号密码登录

## 注意事项

- 图片不要提交到 Git 仓库，`img/` 目录已在 `.gitignore` 中排除
- 大量图片建议使用对象存储或 CDN
- 生产环境建议配置 HTTPS（可使用 Nginx 反向代理 + Let's Encrypt）
