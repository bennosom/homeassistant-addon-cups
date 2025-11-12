ARG BUILD_FROM
FROM ${BUILD_FROM}

ENV LANG=C.UTF-8 \
    CUPS_USER=cupsadmin

RUN apk add --no-cache \
        cups \
        cups-client \
        cups-filters \
        jq \
        shadow \
    && rm -rf /var/cache/apk/*

COPY rootfs /

RUN chmod a+x \
        /etc/cont-init.d/cups.sh \
        /etc/services.d/cups/run

EXPOSE 631

