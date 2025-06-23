FROM alpine:3.20 as builder

RUN apk add --no-cache curl build-base perl tar pkgconf pcre-dev zlib-dev linux-headers

WORKDIR /tmp

# 动态抓取最新OpenResty版本号并设置环境变量，接着下载源码、编译
RUN export RESTY_VERSION=$(curl -s https://openresty.org/en/download.html \
    | grep -oP 'openresty-\K[0-9.]+' | head -n1) && \
    echo "Latest OpenResty version: $RESTY_VERSION" && \
    curl -sSL https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz | tar xz && \
    cd openresty-${RESTY_VERSION} && \
    ./configure --prefix=/usr/local/openresty \
        --with-pcre-jit \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --with-http_realip_module \
        --with-threads \
        --with-stream \
        --with-stream_ssl_module \
        --with-cc-opt="-Os -fomit-frame-pointer" \
        --with-ld-opt="-Wl,--as-needed" \
        --without-http_browser_module && \
    make -j$(nproc) && make install

# 生产镜像，复制OpenResty
FROM alpine:3.18

RUN apk add --no-cache libgcc libstdc++ libcrypto3 libssl3 pcre zlib

ENV PATH="/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin:$PATH"

COPY --from=builder /usr/local/openresty /usr/local/openresty

EXPOSE 80

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
