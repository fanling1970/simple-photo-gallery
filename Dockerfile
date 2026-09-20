FROM openresty/openresty:alpine
# 安装依赖：imagemagick生成缩略图、bcrypt密码哈希
RUN apk add --no-cache imagemagick bcrypt
WORKDIR /usr/share/nginx/html

# 拷贝前端静态资源
COPY index.html ./
COPY login.html ./
COPY setup.html ./
COPY css ./css
COPY js ./js

# 拷贝lua脚本
COPY lua /usr/share/nginx/lua
# 拷贝nginx主配置
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

# 配置目录，持久化挂载users.json
RUN mkdir -p /usr/share/nginx/config
VOLUME ["/usr/share/nginx/config", "/usr/share/nginx/html/photos"]

EXPOSE 80
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
