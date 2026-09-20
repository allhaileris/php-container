ARG PHP_VER=8.2

FROM alpine:latest AS php-compiler
WORKDIR /build
ARG PHP_VER
RUN apk add --no-cache curl git ca-certificates bash
#RUN curl -sSL https://dl.static-php.dev/v3/spc-bin/nightly/spc-linux-x86_64 -o spc && chmod +x spc
RUN curl -sSL https://dl.static-php.dev/v3/spc-bin/nightly/spc-linux-aarch64 -o spc && chmod +x spc
RUN ./spc doctor --auto-fix
RUN ./spc download --with-php=$PHP_VER -e "sockets,opcache,curl,openssl,mbstring,dom"
RUN ./spc build "sockets,opcache,curl,openssl,mbstring,dom,filter,session,tokenizer,ctype" --build-cli

FROM alpine:latest AS ospreparation
RUN echo "appuser:x:10001:10001:appuser:/:/sbin/nologin" > /etc/passwd && \
    echo "appuser:x:10001:" > /etc/group
RUN apk add --no-cache ca-certificates

FROM golang:1.27-alpine AS rr-compiler
WORKDIR /src
RUN apk add --no-cache git upx
RUN git clone --depth 1 https://github.com/roadrunner-server/roadrunner .
ARG TARGETOS
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -ldflags="-s -w -extldflags '-static'" -o rr cmd/rr/main.go
RUN upx --best --lzma rr

FROM scratch
COPY --from=ospreparation /etc/passwd /etc/passwd
COPY --from=ospreparation /etc/group /etc/group
COPY --from=ospreparation --chown=appuser:appuser /tmp /tmp
COPY --from=ospreparation /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=php-compiler /build/buildroot/bin/php /usr/local/bin/php
COPY --from=rr-compiler /src/rr /usr/local/bin/rr
WORKDIR /app
COPY --chown=appuser:appuser . /app
USER appuser
EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/rr", "serve", "-c", "/app/.rr.yaml"]
