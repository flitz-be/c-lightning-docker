FROM elementsproject/lightningd:v0.12.0
RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr wget libsecp256k1-dev libuv0.10-dev

RUN mkdir -p /opt/lightningd/plugins/ && \
    cd /opt/lightningd/plugins && \
    wget https://github.com/fiatjaf/trustedcoin/releases/download/v0.4.0/trustedcoin_linux_amd64 && \
    wget https://github.com/fiatjaf/sparko/releases/download/v2.8/sparko_linux_amd64 && \
    wget https://github.com/fiatjaf/poncho/releases/download/v0.2.1/poncho_x64 && \
    chmod +x trustedcoin_linux_amd64 && \
    chmod +x poncho_x64 && \
    chmod +x sparko_linux_amd64 