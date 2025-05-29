FROM openresty/openresty:alpine-fat

# 安装必要工具
RUN apk add --no-cache \
    git \
    doxygen \
    graphviz \
    lua \
    lua-socket \
    bash \
    curl \
    unzip 

RUN mkdir -p /opt/workspace && chmod 777 /opt/workspace   
RUN mkdir -p /opt/output && chmod 777 /opt/output

# 复制脚本和配置
COPY lua_scripts /opt/lua_scripts
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY mime.types /usr/local/openresty/nginx/conf/mime.types
# 设置工作目录
WORKDIR /opt

# 启动命令
CMD ["openresty", "-g", "daemon off;"]