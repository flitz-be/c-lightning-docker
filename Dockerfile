FROM elementsproject/lightningd:v0.12.1
RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr wget libsecp256k1-dev libuv1-dev

RUN mkdir -p /opt/lightningd/plugins/ && \
    cd /opt/lightningd/plugins && \
    wget https://github.com/nbd-wtf/trustedcoin/releases/download/v0.6.0/trustedcoin-v0.6.0-linux-amd64.tar.gz && \
    wget https://github.com/fiatjaf/sparko/releases/download/v2.8/sparko_linux_amd64 && \
    wget https://github.com/fiatjaf/poncho/releases/download/v0.2.1/poncho_x64 && \
    wget https://gist.githubusercontent.com/kiwiidb/ee126e23f74e146fa06cbc2ea6892a57/raw/964c39df9b2cc230957cc009731d912fdfd79ff1/hodl-invoice.py && \
    pip3 install pyln-client pyln-testing && \
    tar zxvf trustedcoin-v0.6.0-linux-amd64.tar.gz && \
    chmod +x trustedcoin && \
    chmod +x poncho_x64 && \
    chmod +x hodl-invoice.py && \
    chmod +x sparko_linux_amd64 