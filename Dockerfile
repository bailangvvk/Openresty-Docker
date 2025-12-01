# FROM alpine:3.20 AS builder
FROM alpine:latest AS builder

WORKDIR /build

# 安装构建依赖
RUN  set -eux && apk add --no-cache --virtual .build-deps \
    build-base \
    curl \
    pcre-dev \
    zlib-dev \
    linux-headers \
    perl \
    sed \
    grep \
    tar \
    bash \
    jq \
    git \
    autoconf \
    automake \
    libtool \
    make \
    gcc \
    g++ \
    tree \
    && \
    # OPENRESTY_VERSION=$(wget --timeout 10 -q -O - https://openresty.org/en/download.html | grep -oE 'openresty-[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -d'-' -f2) \
    OPENRESTY_VERSION=$(wget --timeout=10 -q -O - https://openresty.org/en/download.html \
    | grep -ioE 'openresty [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
    | head -n1 \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+') \
    && \
    OPENSSL_VERSION=$(wget -q -O - https://www.openssl.org/source/ | grep -oE 'openssl-[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -d'-' -f2) \
    && \
    ZLIB_VERSION=$(wget -q -O - https://zlib.net/ | grep -oE 'zlib-[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -d'-' -f2) \
    && \
    ZSTD_VERSION=$(curl -Ls https://github.com/facebook/zstd/releases/latest | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -c2-) \
    && \
    CORERULESET_VERSION=$(curl -s https://api.github.com/repos/coreruleset/coreruleset/releases/latest | grep -oE '"tag_name": "[^"]+' | cut -d'"' -f4 | sed 's/v//') \
    && \
    PCRE_VERSION=$(curl -sL https://sourceforge.net/projects/pcre/files/pcre/ \
    | grep -oE 'pcre/[0-9]+\.[0-9]+/' \
    | grep -oE '[0-9]+\.[0-9]+' \
    | sort -Vr \
    | head -n1) \
    && \
    echo "=============版本号=============" && \
    echo "OPENRESTY_VERSION=${OPENRESTY_VERSION}" && \
    echo "OPENSSL_VERSION=${OPENSSL_VERSION}" && \
    echo "ZLIB_VERSION=${ZLIB_VERSION}" && \
    echo "ZSTD_VERSION=${ZSTD_VERSION}" && \
    echo "CORERULESET_VERSION=${CORERULESET_VERSION}" && \
    echo "PCRE_VERSION=${CORERULESET_VERSION}" && \
    \
    # fallback 以防 curl/grep 失败
    OPENRESTY_VERSION="${OPENRESTY_VERSION:-1.21.4.1}" && \
    OPENSSL_VERSION="${OPENSSL_VERSION:-3.3.0}" && \
    ZLIB_VERSION="${ZLIB_VERSION:-1.3.1}" && \
    ZSTD_VERSION="${ZSTD_VERSION:-1.5.7}" && \
    CORERULESET_VERSION="${CORERULESET_VERSION:-4.15.0}" && \
    PCRE_VERSION="${PCRE_VERSION:-8.45}" && \
    \
    echo "==> Using versions: openresty-${OPENRESTY_VERSION}, openssl-${OPENSSL_VERSION}, zlib-${ZLIB_VERSION}, ZSTD_VERSION-${ZSTD_VERSION}, CORERULESET_VERSION-${CORERULESET_VERSION}, CORERULESET_VERSION-${CORERULESET_VERSION}" && \
    \
    curl -fSL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz -o openresty.tar.gz && \
    # curl -fSL https://github.com/openresty/openresty/releases/download/v${OPENRESTY_VERSION}/openresty-${OPENRESTY_VERSION}.tar.gz  && \
    tar xzf openresty.tar.gz && \
    \
    curl -fSL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz -o openssl.tar.gz && \
    tar xzf openssl.tar.gz && \
    \
    curl -fSL https://fossies.org/linux/misc/zlib-${ZLIB_VERSION}.tar.gz -o zlib.tar.gz && \
    tar xzf zlib.tar.gz && \
    \
    curl -fSL https://sourceforge.net/projects/pcre/files/pcre/${PCRE_VERSION}/pcre-${PCRE_VERSION}.tar.gz/download -o pcre.tar.gz && \
    tar xzf pcre.tar.gz && \
    \
    cd openresty-${OPENRESTY_VERSION} && \
    ./configure \
    --prefix=/usr/local \
    --modules-path=/usr/local/nginx/modules \
    --sbin-path=/usr/local/nginx/sbin/nginx \
    --conf-path=/usr/local/nginx/conf/nginx.conf \
    --error-log-path=/data/logs/error.log \
    --http-log-path=/data/logs/access.log \
    --with-cc-opt="-O3 -DNGX_LUA_ABORT_AT_PANIC" \
    --with-ld-opt="-Wl,--export-dynamic" \
    --with-openssl=../openssl-${OPENSSL_VERSION} \
    --with-zlib=../zlib-${ZLIB_VERSION} \
    --with-pcre=../pcre-${PCRE_VERSION} \
    --with-pcre-jit \
    --with-stream \
    --user=nobody \
    --group=nobody \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-http_v2_module \
    --without-mail_pop3_module \
    --without-mail_imap_module \
    --without-mail_smtp_module \
    --with-http_stub_status_module  \
    --with-http_realip_module \
    --with-http_gzip_static_module \
    --with-http_sub_module \
    --with-http_gunzip_module \
    --with-threads \
    --with-compat \
    --with-stream=dynamic \
    --with-http_ssl_module \
    && \
    make -j$(nproc) && \
    make install \
    && \
    strip /usr/local/nginx/sbin/nginx && \
    strip /usr/local/luajit/bin/luajit || true && \
    strip /usr/local/luajit/lib/libluajit-5.1.so.2 || true && \
            find /usr/local/nginx/modules -name '*.so' -exec strip {} \; || true && \
            find /usr/local/lualib -name '*.so' -exec strip {} \; || true && \
            apk del .build-deps

FROM alpine:latest

RUN apk add --no-cache libgcc

# 复制之前编译好的 openresty, luajit 等文件
COPY --from=builder /usr/local/nginx /usr/local/nginx
COPY --from=builder /usr/local/luajit /usr/local/luajit
COPY --from=builder /usr/local/lualib /usr/local/lualib
COPY --from=builder /usr/local/bin/openresty /usr/local/bin/
COPY --from=builder /usr/local/luajit/bin/luajit /usr/local/bin/

# 软连接库路径等操作
RUN mkdir -p /usr/local/lib \
    && ln -sf /usr/local/luajit/lib/libluajit-5.1.so.2 /usr/local/lib/ \
    && ln -sf /usr/local/luajit/lib/libluajit-5.1.so.2.1.ROLLING /usr/local/lib/

ENV PATH="/usr/local/nginx/sbin:/usr/local/bin:$PATH"
ENV LUA_PATH="/usr/local/lualib/?.lua;;"
ENV LUA_CPATH="/usr/local/lualib/?.so;;"
ENV LD_LIBRARY_PATH="/usr/local/luajit/lib:$LD_LIBRARY_PATH"

WORKDIR /usr/local/nginx

RUN mkdir -p /data/logs && chown -R nobody:nobody /data/logs /usr/local/nginx

USER nobody

CMD ["nginx", "-g", "daemon off;"]
