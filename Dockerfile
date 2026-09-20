# 基础镜像：轻量级 Nginx
FROM nginx:alpine

# 维护者信息
LABEL maintainer="fanling1970"
LABEL description="个人服务器相册 - 静态前端 + Nginx"

# 删除默认配置
RUN rm /etc/nginx/conf.d/default.conf

# 复制自定义 Nginx 配置
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 复制相册前端代码到容器
COPY index.html /usr/share/nginx/html/
COPY css/ /usr/share/nginx/html/css/
COPY js/ /usr/share/nginx/html/js/

# 创建图片目录（运行时通过 volume 挂载覆盖）
RUN mkdir -p /usr/share/nginx/html/img

# 暴露端口
EXPOSE 80

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

# 启动 Nginx
CMD ["nginx", "-g", "daemon off;"]
