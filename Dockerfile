ARG OPENRESTY_VERSION=1.27.1.2
ARG OPENSSL_VERSION=3.1.3
ARG PCRE_VERSION=8.45

FROM alpine:3.20 AS builder

RUN apk add --no-cache build-base curl perl tar libtool automake autoconf pkgconf pcre-dev zlib-dev linux-headers

WORKDIR /tmp

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
    --with-http_stub_status_module \
    --with-http_realip_module \
    --with-threads \
    --with-stream \
    --with-stream_ssl_module \
    --with-pcre-jit \
    --with-cc-opt="-Os -fomit-frame-pointer" \
    --with-ld-opt="-Wl,--as-needed" \
    --without-http_browser_module

RUN make -j${BUILD_JOBS} && make install

FROM alpine:3.18

RUN apk add --no-cache libgcc libstdc++ libcrypto3 libssl3 pcre zlib

ENV PATH="/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin:$PATH"

COPY --from=builder /usr/local/openresty /usr/local/openresty

EXPOSE 80

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
