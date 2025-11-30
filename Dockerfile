# 使用 musl libc 的 alpine 作为编译环境，以获得更好的静态编译效果
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
    && \
    OPENRESTY_VERSION=$(wget --timeout=10 -q -O - https://openresty.org/en/download.html \
    | grep -ioE 'openresty [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
    | head -n1 \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+') \
    && \
    OPENSSL_VERSION=$(wget -q -O - https://www.openssl.org/source/ | grep -oE 'openssl-[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -d'-' -f2) \
    && \
    ZLIB_VERSION=$(wget -q -O - https://zlib.net/ | grep -oE 'zlib-[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -d'-' -f2) \
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
    echo "PCRE_VERSION=${PCRE_VERSION}" && \
    \
    # fallback 以防 curl/grep 失败
    OPENRESTY_VERSION="${OPENRESTY_VERSION:-1.21.4.1}" && \
    OPENSSL_VERSION="${OPENSSL_VERSION:-3.3.0}" && \
    ZLIB_VERSION="${ZLIB_VERSION:-1.3.1}" && \
    PCRE_VERSION="${PCRE_VERSION:-8.45}" && \
    \
    echo "==> Using versions: openresty-${OPENRESTY_VERSION}, openssl-${OPENSSL_VERSION}, zlib-${ZLIB_VERSION}, pcre-${PCRE_VERSION}" && \
    \
    curl -fSL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz -o openresty.tar.gz && \
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
      --prefix=/opt/openresty \
      --user=nobody \
      --group=nobody \
      --with-cc-opt="-static -static-libgcc -O2" \
      --with-ld-opt="-static" \
      --with-openssl=../openssl-${OPENSSL_VERSION} \
      --with-zlib=../zlib-${ZLIB_VERSION} \
      --with-pcre=../pcre-${PCRE_VERSION} \
      --with-pcre-jit \
      \
      # 启用官方核心模块
      --with-luajit \
      --with-http_ssl_module \
      --with-http_v2_module \
      --with-http_realip_module \
      --with-http_gzip_static_module \
      --with-http_stub_status_module \
      --with-threads \
      \
      # 禁用一些非核心或动态模块
      --without-http_autoindex_module \
      --without-http_ssi_module \
      --without-http_userid_module \
      --without-http_auth_basic_module \
      --without-http_mirror_module \
      --without-http_split_clients_module \
      --without-http_memcached_module \
      --without-http_empty_gif_module \
      --without-http_browser_module \
      --without-mail_pop3_module \
      --without-mail_imap_module \
      --without-mail_smtp_module \
      --with-stream=no \
      --with-stream_ssl_module=no \
    && \
    make -j$(nproc) && \
    make install

# 中间层，用于创建用户和目录结构
FROM alpine:latest AS intermediate
RUN addgroup -g 101 -S nobody && \
    adduser -u 101 -S -G nobody -h /dev/null nobody && \
    mkdir -p /opt/openresty/nginx/logs && \
    chown -R nobody:nobody /opt/openresty/nginx/logs && \
    mkdir -p /etc/openresty && \
    # 创建一个默认的 nginx.conf 以防万一
    echo "worker_processes 1;\nevents { worker_connections 1024; }\nhttp { server { listen 80; location / { return 200 'Hello'; } } }" > /etc/openresty/nginx.conf

# 最终镜像
FROM scratch

# 从 intermediate 镜像复制用户和目录结构
COPY --from=intermediate /etc/passwd /etc/passwd
COPY --from=intermediate /etc/group /etc/group
COPY --from=intermediate /opt/openresty/nginx/logs /opt/openresty/nginx/logs
COPY --from=intermediate /etc/openresty /etc/openresty

# 从 builder 阶段复制编译好的二进制文件和模块
COPY --from=builder /opt/openresty/bin/openresty /opt/openresty/bin/openresty
COPY --from=builder /opt/openresty/nginx/sbin/nginx /opt/openresty/bin/nginx
COPY --from=builder /opt/openresty/lualib /opt/openresty/lualib
COPY --from=builder /opt/openresty/nginx/conf /etc/openresty

# 设置环境变量
ENV PATH="/opt/openresty/bin:/opt/openresty/nginx/sbin:$PATH"
ENV LUA_PATH="/opt/openresty/lualib/?.lua;;"
ENV LUA_CPATH="/opt/openresty/lualib/?.so;;"

# 暴露端口
EXPOSE 80

# 定义默认用户
USER nobody

# 启动命令
CMD ["/opt/openresty/bin/nginx", "-c", "/etc/openresty/nginx.conf", "-g", "daemon off;"]
