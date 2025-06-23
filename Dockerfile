# ===============================
# 第一阶段：构建 OpenResty 静态版本
# ===============================
FROM alpine:3.18 AS builder

ARG OPENRESTY_VERSION=1.21.4.3
ARG LUAJIT_LIB=/usr/local/lib
ARG LUAJIT_INC=/usr/local/include/luajit-2.1

RUN apk add --no-cache \
    build-base \
    pcre-dev \
    openssl-dev \
    zlib-dev \
    curl \
    git \
    tar \
    libmaxminddb-dev \
    linux-headers

WORKDIR /tmp

# 下载并解压 OpenResty 源码
RUN curl -fSL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz | tar xz

WORKDIR /tmp/openresty-${OPENRESTY_VERSION}

# 配置 + 静态编译
RUN ./configure \
    --prefix=/opt/openresty \
    --with-luajit \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_stub_status_module \
    --with-threads \
    --with-file-aio \
    --with-cc-opt="-static" \
    --with-ld-opt="-static" \
    --without-http_auth_basic_module \
    --without-http_browser_module \
    --without-http_geo_module \
    --without-http_limit_conn_module \
    --without-http_limit_req_module \
    --without-http_memcached_module \
    --without-http_proxy_module \
    --without-http_userid_module \
    --without-lua_resty_dns \
    --without-lua_resty_memcached \
    --without-lua_resty_redis

RUN make -j$(nproc) && make install

# ===============================
# 第二阶段：scratch 极小镜像
# ===============================
FROM scratch

# 复制构建结果
COPY --from=builder /opt/openresty /opt/openresty

# 添加你自己的 nginx.conf
COPY nginx.conf /opt/openresty/nginx/conf/nginx.conf

# 设置 PATH
ENV PATH=/opt/openresty/nginx/sbin:/opt/openresty/luajit/bin:$PATH

# 使用 static 编译的 nginx 作为入口
ENTRYPOINT ["/opt/openresty/nginx/sbin/nginx"]

# 保持前台运行
CMD ["-g", "daemon off;"]
