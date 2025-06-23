# ---------- Stage 1: Build OpenResty ----------
FROM alpine:3.20 as builder

ARG RESTY_VERSION=1.27.1.2
ARG RESTY_OPENSSL_VERSION=1.1.1w
ARG RESTY_PCRE_VERSION=8.45
ARG RESTY_J=2

WORKDIR /tmp

RUN apk add --no-cache build-base curl perl tar \
    libtool automake autoconf pkgconf \
    pcre-dev zlib-dev linux-headers

# 下载源码包
RUN curl -sSL https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz | tar xz && \
    curl -sSL https://www.openssl.org/source/old/1.1.1/openssl-${RESTY_OPENSSL_VERSION}.tar.gz | tar xz && \
    curl -sSL https://downloads.sourceforge.net/project/pcre/pcre/${RESTY_PCRE_VERSION}/pcre-${RESTY_PCRE_VERSION}.tar.gz | tar xz

# 编译
WORKDIR /tmp/openresty-${RESTY_VERSION}

RUN ./configure \
    --prefix=/usr/local/openresty \
    --with-pcre=/tmp/pcre-${RESTY_PCRE_VERSION} \
    --with-openssl=/tmp/openssl-${RESTY_OPENSSL_VERSION} \
    --with-luajit \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_realip_module \
    --with-threads \
    --with-stream \
    --with-stream_ssl_module \
    --with-pcre-jit \
    --with-cc-opt="-Os -fomit-frame-pointer" \
    --with-ld-opt="-Wl,--as-needed" \
    --without-http_browser_module

RUN make -j${RESTY_J} && make install

# ---------- Stage 2: Final image (scratch base + alpine rootfs) ----------
FROM scratch

ADD https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-minirootfs-3.20.6-x86_64.tar.gz /

LABEL maintainer="你 <your@email.com>" \
      resty_version="${RESTY_VERSION}" \
      resty_openssl_version="${RESTY_OPENSSL_VERSION}" \
      resty_pcre_version="${RESTY_PCRE_VERSION}"

ENV PATH=/usr/local/openresty/nginx/sbin:/usr/local/openresty/luajit/bin:/usr/local/openresty/bin:$PATH

COPY --from=builder /usr/local/openresty /usr/local/openresty

# 可选：添加自定义配置
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY nginx.vh.default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
STOPSIGNAL SIGQUIT
