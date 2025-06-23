ARG OPENRESTY_VERSION=1.27.1.2
ARG OPENSSL_VERSION=3.3.1
ARG ZLIB_VERSION=1.3.1

FROM alpine:3.18 AS builder

RUN apk add --no-cache \
    build-base perl curl git tar \
    pcre-dev linux-headers zlib-dev openssl-dev

WORKDIR /tmp

# 下载源码包
RUN curl -fSL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz | tar xz && \
    curl -fSL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz | tar xz && \
    curl -fSL https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz | tar xz

WORKDIR /tmp/openresty-${OPENRESTY_VERSION}

# 编译（去掉 -static，动态编译）
RUN ./configure \
    --prefix=/opt/openresty \
    --with-openssl=/tmp/openssl-${OPENSSL_VERSION} \
    --with-zlib=/tmp/zlib-${ZLIB_VERSION} \
    --with-luajit \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_stub_status_module \
    --with-threads \
    --with-file-aio \
    --without-http_browser_module \
    --without-http_memcached_module \
    --without-http_geo_module \
    --without-http_proxy_module \
    --without-http_auth_basic_module \
    --without-http_userid_module \
    --without-lua_resty_memcached \
    --without-lua_resty_redis \
    --without-lua_resty_dns

RUN make -j$(nproc) && make install

# ------------- 运行镜像 -------------
FROM alpine:3.18

RUN apk add --no-cache bash gettext

ENV PATH="/opt/openresty/nginx/sbin:$PATH"
ENV NGINX_PORT=8080

# 复制编译好的 OpenResty
COPY --from=builder /opt/openresty /opt/openresty

# 复制并赋权启动脚本
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 复制 nginx 配置模板
COPY nginx.template.conf /nginx.template.conf

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
