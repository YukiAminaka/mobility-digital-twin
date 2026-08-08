FROM ubuntu:22.04

ARG TARGETARCH
ARG TARGETVARIANT

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && SORATUN_VERSION="1.2.8" \
    && SORATUN_TARGETARCH="${TARGETARCH:-$(dpkg --print-architecture)}" \
    && case "${SORATUN_TARGETARCH}/${TARGETVARIANT}" in \
        amd64/) SORATUN_ARCH="amd64"; SORATUN_SHA256="f058249775775d1f556e59c893e021fdf6ccd3c6e23a5f5b4d381c749ebd59f0" ;; \
        arm64/) SORATUN_ARCH="arm64"; SORATUN_SHA256="63d925ecf5b8e1b02190e6ab068cd28f9915ebcd56a0208ceacc5382ef707fb5" ;; \
        arm/v7) SORATUN_ARCH="armv7"; SORATUN_SHA256="27e5f214cff77408f9cf9419742002d019f6bcd366244ed71a2f4672ad87fab7" ;; \
        arm/v6) SORATUN_ARCH="armv6"; SORATUN_SHA256="9cc1b0bf553bb7522fb49decde736e051f8f47d6e09cb476c8410dff0d8cab07" ;; \
        arm/v5) SORATUN_ARCH="armv5"; SORATUN_SHA256="50ac49206b5c2118abc6cf9ec8e90075680aba9e9358c3ae9c59dcaec008787d" ;; \
        armhf/) SORATUN_ARCH="armv7"; SORATUN_SHA256="27e5f214cff77408f9cf9419742002d019f6bcd366244ed71a2f4672ad87fab7" ;; \
        *) echo "Unsupported platform: ${SORATUN_TARGETARCH}/${TARGETVARIANT}" >&2; exit 1 ;; \
    esac \
    && SORATUN_ARCHIVE="soratun_${SORATUN_VERSION}_linux_${SORATUN_ARCH}.tar.gz" \
    && curl -fsSL --retry 3 \
        "https://github.com/soracom/soratun/releases/download/v${SORATUN_VERSION}/${SORATUN_ARCHIVE}" \
        -o "/tmp/${SORATUN_ARCHIVE}" \
    && echo "${SORATUN_SHA256}  /tmp/${SORATUN_ARCHIVE}" | sha256sum -c - \
    && mkdir -p /tmp/soratun \
    && tar -xzf "/tmp/${SORATUN_ARCHIVE}" -C /tmp/soratun --strip-components=1 \
    && install -m 0755 /tmp/soratun/soratun /usr/local/bin/soratun \
    && soratun version \
    && rm -rf /tmp/soratun "/tmp/${SORATUN_ARCHIVE}" /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/soratun-entrypoint
RUN chmod 0755 /usr/local/bin/soratun-entrypoint

ENTRYPOINT ["/usr/local/bin/soratun-entrypoint"]
CMD ["version"]
