# ==============================================================================
# Stage 1: Builder
# 在此阶段，我们编译一个完全静态的 OpenResty 二进制文件。
# ==============================================================================
FROM alpine:latest AS builder

# 使用 ARG 定义版本号，使构建过程确定且易于更新
ARG OPENRESTY_VERSION=1.21.4.2
ARG OPENSSL_VERSION=1.1.1w
ARG PCRE_VERSION=8.45
ARG ZLIB_VERSION=1.3.1

WORKDIR /build

# 安装构建所需的最少依赖
RUN apk add --no-cache --virtual .build-deps \
    build-base \
    curl \
    perl \
    linux-headers

# 下载并解压所有源码
# 将所有下载和解压操作合并到一层以减小镜像大小
RUN set -eux; \
    curl -fSL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz -o openresty.tar.gz && \
    curl -fSL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz -o openssl.tar.gz && \
    curl -fSL https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz -o zlib.tar.gz && \
    curl -fSL https://sourceforge.net/projects/pcre/files/pcre/${PCRE_VERSION}/pcre-${PCRE_VERSION}.tar.gz/download -o pcre.tar.gz && \
    tar xzf openresty.tar.gz && \
    tar xzf openssl.tar.gz && \
    tar xzf zlib.tar.gz && \
    tar xzf pcre.tar.gz

# 编译 OpenResty
RUN cd openresty-${OPENRESTY_VERSION} && \
    ./configure \
      --prefix=/usr/local/openresty \
      --user=appuser \
      --group=appuser \
      \
      # 核心编译选项：静态链接所有库
      --with-cc-opt="-static -static-libgcc -O2" \
      --with-ld-opt="-static" \
      \
      # 指向我们下载的依赖源码
      --with-openssl=../openssl-${OPENSSL_VERSION} \
      --with-zlib=../zlib-${ZLIB_VERSION} \
      --with-pcre=../pcre-${PCRE_VERSION} \
      --with-pcre-jit \
      \
      # 启用核心模块
      --with-luajit \
      --with-http_ssl_module \
      --with-http_v2_module \
      --with-http_realip_module \
      --with-http_gzip_static_module \
      --with-http_stub_status_module \
      --with-threads \
      \
      # 禁用不需要的模块以减小体积
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
    #   --without-stream_module \
    && \
    make -j$(nproc) && \
    make install

# ==============================================================================
# Stage 2: Runtime Setup
# 为 scratch 镜像准备用户、组和目录结构。
# ==============================================================================
FROM alpine:latest AS runtime-setup

RUN addgroup -S -g 1001 appuser && \
    adduser -S -u 1001 -G appuser appuser

# 创建 OpenResty 运行时需要的目录，并设置正确的所有权
RUN mkdir -p /usr/local/openresty/nginx/logs /usr/local/openresty/nginx/temp && \
    chown -R appuser:appuser /usr/local/openresty

# ==============================================================================
# Stage 3: Final Image
# 构建最终的、最小化的镜像。
# ==============================================================================
FROM scratch

# 从 runtime-setup 阶段复制用户和组信息
COPY --from=runtime-setup /etc/passwd /etc/passwd
COPY --from=runtime-setup /etc/group /etc/group

# 从 builder 阶段复制编译好的 OpenResty 文件
COPY --from=builder /usr/local/openresty/bin/openresty /usr/local/openresty/bin/openresty
COPY --from=builder /usr/local/openresty/nginx/sbin/nginx /usr/local/openresty/nginx/sbin/nginx
COPY --from=builder /usr/local/openresty/lualib /usr/local/openresty/lualib
COPY --from=builder /usr/local/openresty/luajit /usr/local/openresty/luajit
COPY --from=builder /usr/local/openresty/nginx/conf /usr/local/openresty/nginx/conf

# 从 runtime-setup 阶段复制目录结构和权限
COPY --from=runtime-setup --chown=appuser:appuser /usr/local/openresty/nginx/logs /usr/local/openresty/nginx/logs
COPY --from=runtime-setup --chown=appuser:appuser /usr/local/openresty/nginx/temp /usr/local/openresty/nginx/temp

# 设置环境变量
ENV PATH="/usr/local/openresty/bin:/usr/local/openresty/nginx/sbin:$PATH"

# 暴露端口
EXPOSE 80

# 切换到非 root 用户
USER appuser

# 设置工作目录
WORKDIR /usr/local/openresty

# 启动命令
CMD ["/usr/local/openresty/nginx/sbin/nginx", "-c", "/usr/local/openresty/nginx/conf/nginx.conf", "-g", "daemon off;"]
