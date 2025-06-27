FROM alpine:3.20 AS builder

WORKDIR /build

# 安装构建依赖
RUN  set -x && apk add --no-cache \
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
  echo "=============版本号=============" && \
  echo "OPENRESTY_VERSION=${OPENRESTY_VERSION}" && \
  echo "OPENSSL_VERSION=${OPENSSL_VERSION}" && \
  echo "ZLIB_VERSION=${ZLIB_VERSION}" && \
  echo "ZSTD_VERSION=${ZSTD_VERSION}" && \
  echo "CORERULESET_VERSION=${CORERULESET_VERSION}" && \
  \
  # fallback 以防 curl/grep 失败
  OPENRESTY_VERSION="${OPENRESTY_VERSION:-1.21.4.1}" && \
  OPENSSL_VERSION="${OPENSSL_VERSION:-3.3.0}" && \
  ZLIB_VERSION="${ZLIB_VERSION:-1.3.1}" && \
  ZSTD_VERSION="${ZSTD_VERSION:-1.5.7}" && \
  CORERULESET_VERSION="${CORERULESET_VERSION:-4.15.0}" && \
  \
  echo "==> Using versions: openresty-${OPENRESTY_VERSION}, openssl-${OPENSSL_VERSION}, zlib-${ZLIB_VERSION}" && \
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
  # tree && \
  # \

  # cd openresty-${OPENRESTY_VERSION} && \
  # ./configure \
  #   --prefix=/etc/openresty \
  #   --user=root \
  #   --group=root \
  #   --with-cc-opt="-static -static-libgcc" \
  #   --with-ld-opt="-static" \
  #   --with-openssl=../openssl-${OPENSSL_VERSION} \
  #   --with-zlib=../zlib-${ZLIB_VERSION} \
  #   --with-pcre \
  #   --with-pcre-jit \
  #   --with-http_ssl_module \
  #   --with-http_v2_module \
  #   --with-http_gzip_static_module \
  #   --with-http_stub_status_module \
  #   --without-http_rewrite_module \
  #   --without-http_auth_basic_module \
  #   --with-threads && \
  # make -j$(nproc) && \
  # make install \

  cd openresty-${OPENRESTY_VERSION} && \
  ./configure \
  --prefix=/usr/local/openresty \
  --with-openssl=../openssl-${OPENSSL_VERSION} \
  --with-zlib=../zlib-${ZLIB_VERSION} \
  # --with-cc-opt="-O2" \
  # --with-ld-opt="-Wl,--export-dynamic" && \
  --with-cc-opt="-static -static-libgcc" \
  --with-ld-opt="-static" \
  make -j$(nproc) && \
  make install \

  && \
  strip /usr/local/openresty/sbin/nginx


# 最小运行时镜像
FROM busybox:1.35-uclibc

# 拷贝构建产物
COPY --from=builder /usr/local/openresty /usr/local/openresty

# 暴露端口
EXPOSE 80 443

WORKDIR /usr/local/openresty

# 启动 openresty
CMD ["./nginx/sbin/nginx", "-g", "daemon off;"]
