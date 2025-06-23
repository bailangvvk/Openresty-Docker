# ---------- Stage 1: Build OpenResty ----------
FROM alpine:3.20 AS builder

ARG OPENRESTY_VERSION
ARG OPENSSL_VERSION=3.1.3
ARG PCRE_VERSION=8.45
ARG MAKE_JOBS=2

RUN apk add --no-cache \
    build-base curl perl tar \
    libtool automake autoconf pkgconf \
    pcre-dev zlib-dev linux-headers

WORKDIR /tmp

# 下载源码包并解压
RUN curl -sSL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz | tar xz && \
    curl -sSL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz | tar xz && \
    curl -sSL https://downloads.sourceforge.net/project/pcre/pcre/${PCRE_VERSION}/pcre-${PCRE_VERSION}.tar.gz | tar xz

WORKDIR /tmp/openresty-${OPENRESTY_VERSION}

RUN ./configure \
    --prefix=/usr/local/openresty \
    --with-pcre=/tmp/pcre-${PCRE_VERSION} \
    --with-openssl=/tmp/openssl-${OPENSSL_VERSION} \
    --with-luajit \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_stub_status_module \
    --with-http_realip_module \
    --with-http_geoip_module \
    --with-http_gzip_static_module \
    --with-http_auth_request_module \
    --with-http_secure_link_module \
    --with-http_degradation_module \
    --with-http_slice_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    # --with-http_proxy_module \
    --with-http_random_index_module \
    --with-http_addition_module \
    --with-http_xslt_module \
    --with-http_image_filter_module \
    --with-http_perl_module \
    --with-threads \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_realip_module \
    --with-stream_geoip_module \
    --with-stream_ssl_preread_module \
    --with-pcre-jit \
    --with-cc-opt="-Os -fomit-frame-pointer" \
    --with-ld-opt="-Wl,--as-needed"

RUN make -j${MAKE_JOBS} && make install

# ---------- Stage 2: Runtime image ----------
FROM alpine:3.18

RUN apk add --no-cache libgcc libstdc++ libcrypto3 libssl3 pcre zlib geoip libxslt gd perl

ENV PATH="/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin:$PATH"

COPY --from=builder /usr/local/openresty /usr/local/openresty

EXPOSE 80 443

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
