FROM erlang:21-alpine AS build-env

WORKDIR /vernemq-build

ARG VERNEMQ_GIT_REF=1.9.2
ARG TARGET=rel
ARG VERNEMQ_REPO=https://github.com/vernemq/vernemq.git

# Defaults
ENV DOCKER_VERNEMQ_KUBERNETES_LABEL_SELECTOR="app=vernemq" \
    DOCKER_VERNEMQ_LOG__CONSOLE=console

RUN apk --no-cache --update --available upgrade && \
    apk add --no-cache git autoconf build-base bsd-compat-headers cmake openssl-dev bash && \
    git clone -b $VERNEMQ_GIT_REF $VERNEMQ_REPO .

COPY bin/build.sh build.sh

RUN ./build.sh $TARGET

#ARG BUILD_FROM=hassioaddons/base:5.0.1
#FROM $BUILD_FROM

FROM hassioaddons/base:5.0.1

ENV LANG en_US.utf8
ENV TZ America/New_York

RUN apk --no-cache --update --available upgrade && \
    apk add --no-cache ncurses-libs openssl libstdc++ jq curl bash && \
    addgroup --gid 10000 vernemq && \
    adduser --uid 10000 -H -D -G vernemq -h /vernemq vernemq && \
    install -d -o vernemq -g vernemq /vernemq

# Defaults
ENV DOCKER_VERNEMQ_KUBERNETES_LABEL_SELECTOR="app=vernemq" \
    DOCKER_VERNEMQ_LOG__CONSOLE=console \
    PATH="/vernemq/bin:$PATH"

WORKDIR /vernemq

COPY --chown=10000:10000 bin/vernemq.sh /usr/sbin/start_vernemq
COPY --chown=10000:10000 files/vm.args /vernemq/etc/vm.args
COPY --chown=10000:10000 --from=build-env /vernemq-build/release /vernemq

RUN ln -s /vernemq/etc /etc/vernemq && \
    ln -s /vernemq/data /var/lib/vernemq && \
    ln -s /vernemq/log /var/log/vernemq

# Ports
# 1883  MQTT
# 8883  MQTT/SSL
# 8080  MQTT WebSockets
# 44053 VerneMQ Message Distribution
# 4369  EPMD - Erlang Port Mapper Daemon
# 8888  Prometheus Metrics
# 9100 9101 9102 9103 9104 9105 9106 9107 9108 9109  Specific Distributed Erlang Port Range

EXPOSE 1883 8883 8080 44053 4369 8888 \
       9100 9101 9102 9103 9104 9105 9106 9107 9108 9109

#VOLUME ["/vernemq/log", "/vernemq/data", "/vernemq/etc"]

HEALTHCHECK CMD vernemq ping | grep -q pong

#USER vernemq
#CMD ["start_vernemq"]

# Build arugments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_REF
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="VerneMQ" \
    io.hass.description="An MQTT server" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="Alex Savin <alex@smarthouse.site>" \
    org.label-schema.description="An MQTT server" \
    org.label-schema.build-date=${BUILD_DATE} \
    org.label-schema.name="VerneMQ" \
    org.label-schema.schema-version="1.0" \
    org.label-schema.url="https://github.com/alex-savin/hassio-addons/tree/master/vernemq" \
    org.label-schema.usage="https://github.com/alex-savin/hassio-addons/vernemq/tree/master/README.md" \
    org.label-schema.vcs-ref=${BUILD_REF} \
    org.label-schema.vcs-url="https://github.com/alex-savin/hassio-addons/tree/master/vernemq" \
    org.label-schema.vendor="SmartHouse's Hass.io Add-ons"
