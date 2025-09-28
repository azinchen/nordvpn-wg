# s6 overlay builder
FROM alpine:3.22.1 AS s6-builder

ENV PACKAGE="just-containers/s6-overlay"
ENV PACKAGEVERSION="3.2.1.0"

RUN echo "**** install security fix packages ****" && \
    echo "**** install mandatory packages ****" && \
    apk --no-cache --no-progress add \
        tar=1.35-r3 \
        xz=5.8.1-r0 \
        && \
    echo "**** create folders ****" && \
    mkdir -p /s6 && \
    echo "**** download ${PACKAGE} ****" && \
    s6_arch=$(case $(uname -m) in \
        i?86)           echo "i486"        ;; \
        x86_64)         echo "x86_64"      ;; \
        aarch64)        echo "aarch64"     ;; \
        armv6l)         echo "arm"         ;; \
        armv7l)         echo "armhf"       ;; \
        ppc64le)        echo "powerpc64le" ;; \
        riscv64)        echo "riscv64"     ;; \
        s390x)          echo "s390x"       ;; \
        *)              echo ""            ;; esac) && \
    echo "Package ${PACKAGE} platform ${PACKAGEPLATFORM} version ${PACKAGEVERSION}" && \
    wget -q "https://github.com/${PACKAGE}/releases/download/v${PACKAGEVERSION}/s6-overlay-noarch.tar.xz" -qO /tmp/s6-overlay-noarch.tar.xz && \
    wget -q "https://github.com/${PACKAGE}/releases/download/v${PACKAGEVERSION}/s6-overlay-${s6_arch}.tar.xz" -qO /tmp/s6-overlay-binaries.tar.xz && \
    tar -C /s6/ -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C /s6/ -Jxpf /tmp/s6-overlay-binaries.tar.xz

# rootfs builder
FROM alpine:3.22.1 AS rootfs-builder

RUN echo "**** install security fix packages ****" && \
    echo "**** end run statement ****"

COPY root/ /rootfs/
RUN chmod +x /rootfs/usr/local/bin/* && \
    chmod +x /rootfs/etc/s6-overlay/s6-rc.d/*/run && \
    chmod +x /rootfs/etc/s6-overlay/s6-rc.d/*/finish && \
    chmod 644 /rootfs/etc/nordvpn/*.json
COPY --from=s6-builder /s6/ /rootfs/

# Main image
FROM alpine:3.22.1

LABEL maintainer="Alexander Zinchenko <alexander@zinchenko.com>"

ARG IMAGE_VERSION=N/A
ARG BUILD_DATE=N/A

ENV IMAGE_VERSION=${IMAGE_VERSION} \
    BUILD_DATE=${BUILD_DATE} \
    NORDVPNAPI_IP=104.16.208.203;104.19.159.190 \
    DNS=103.86.96.100,103.86.99.100 \
    RANDOM_TOP=0 \
    CHECK_CONNECTION_ATTEMPTS=5 \
    CHECK_CONNECTION_ATTEMPT_INTERVAL=10 \
    PATH=/command:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=120000

RUN echo "**** install security fix packages ****" && \
    echo "**** install mandatory packages ****" && \
    apk --no-cache --no-progress add \
        curl=8.14.1-r1 \
        iptables=1.8.11-r1 \
        iptables-legacy=1.8.11-r1 \
        jq=1.8.0-r0 \
        shadow=4.17.3-r0 \
        shadow-login=4.17.3-r0 \
        wireguard-tools=1.0.20250521-r0 \
        bind-tools=9.20.13-r0 \
        && \
    echo "**** cleanup ****" && \
    rm -rf /tmp/* && \
    rm -rf /var/cache/apk/*

COPY --from=rootfs-builder /rootfs/ /

ENTRYPOINT ["/usr/local/bin/entrypoint"]
