# ---------- 构建阶段 ----------
FROM alpine:3.18 AS builder

ARG OPENRESTY_VERSION=1.21.4.3
ARG OPENSSL_VERSION=3.3.1

RUN apk add --no-cache \
    build-base perl curl git tar \
    pcre-dev zlib-dev linux-headers

# 下载并解压 OpenResty 源码
WORKDIR /tmp
RUN curl -fSL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz | tar xz

# 下载并解压 OpenSSL 最新源码
RUN curl -fSL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz | tar xz

# 编译 OpenResty（静态链接 OpenSSL）
WORKDIR /tmp/openresty-${OPENRESTY_VERSION}
RUN ./configure \
    --prefix=/opt/openresty \
    --with-cc-opt="-static" \
    --with-ld-opt="-static" \
    --with-openssl=/tmp/openssl-${OPENSSL_VERSION} \
    --with-luajit \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_stub_status_module \
    --with-threads \
    --with-file-aio \
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

# ---------- 运行阶段 ----------
FROM scratch AS final

# 拷贝编译产物
COPY --from=builder /opt/openresty /opt/openresty

# 可选：COPY 自定义 nginx.conf（必须存在）
COPY nginx.conf /opt/openresty/nginx/conf/nginx.conf

ENV PATH=/opt/openresty/nginx/sbin:$PATH

EXPOSE 80
CMD ["/opt/openresty/nginx/sbin/nginx", "-g", "daemon off;"]
