# This dockerfile is meant to compile a c-lightning x64 image
# It is using multi stage build:
# * downloader: Download bitcoin and qemu binaries needed for c-lightning
# * builder: Compile c-lightning dependencies, then c-lightning itself with static linking
# * final: Copy the binaries required at runtime
# Then install the needed plugins
# From the root of the repository, run "docker build -t yourimage:yourtag ."
FROM debian:buster-slim as downloader

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr wget

WORKDIR /opt

RUN wget -qO /opt/tini "https://github.com/krallin/tini/releases/download/v0.18.0/tini" \
    && echo "12d20136605531b09a2c2dac02ccee85e1b874eb322ef6baf7561cd93f93c855 /opt/tini" | sha256sum -c - \
    && chmod +x /opt/tini

ARG BITCOIN_VERSION=22.0
ENV BITCOIN_TARBALL bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz
ENV BITCOIN_URL https://bitcoincore.org/bin/bitcoin-core-$BITCOIN_VERSION/$BITCOIN_TARBALL
ENV BITCOIN_ASC_URL https://bitcoincore.org/bin/bitcoin-core-$BITCOIN_VERSION/SHA256SUMS

RUN mkdir /opt/bitcoin && cd /opt/bitcoin \
    && wget -qO $BITCOIN_TARBALL "$BITCOIN_URL" \
    && wget -qO bitcoin "$BITCOIN_ASC_URL" \
    && grep $BITCOIN_TARBALL bitcoin | tee SHA256SUMS \
    && sha256sum -c SHA256SUMS \
    && BD=bitcoin-$BITCOIN_VERSION/bin \
    && tar -xzvf $BITCOIN_TARBALL $BD/bitcoin-cli --strip-components=1 \
    && rm $BITCOIN_TARBALL

FROM debian:buster-slim as builder

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates autoconf automake build-essential git libtool python3 python3-pip python3-setuptools python3-mako wget gnupg dirmngr git gettext libpq-dev postgresql

RUN wget -q https://zlib.net/zlib-1.2.12.tar.gz \
&& tar xvf zlib-1.2.12.tar.gz \
&& cd zlib-1.2.12 \
&& ./configure \
&& make \
&& make install && cd .. && rm zlib-1.2.12.tar.gz && rm -rf zlib-1.2.12

RUN apt-get install -y --no-install-recommends unzip tclsh \
&& wget -q https://www.sqlite.org/2019/sqlite-src-3290000.zip \
&& unzip sqlite-src-3290000.zip \
&& cd sqlite-src-3290000 \
&& ./configure --enable-static --disable-readline --disable-threadsafe --disable-load-extension \
&& make \
&& make install && cd .. && rm sqlite-src-3290000.zip && rm -rf sqlite-src-3290000

RUN wget -q https://gmplib.org/download/gmp/gmp-6.1.2.tar.xz \
&& tar xvf gmp-6.1.2.tar.xz \
&& cd gmp-6.1.2 \
&& ./configure --disable-assembly \
&& make \
&& make install && cd .. && rm gmp-6.1.2.tar.xz && rm -rf gmp-6.1.2

ENV LIGHTNINGD_VERSION=v0.11.0.1
ENV LIGHTNING_URL https://github.com/ElementsProject/lightning

WORKDIR /opt/lightningd
RUN git clone --branch $LIGHTNINGD_VERSION $LIGHTNING_URL /tmp/lightning
RUN git clone --recursive /tmp/lightning . && \
    git checkout $(git --work-tree=/tmp/lightning --git-dir=/tmp/lightning/.git rev-parse HEAD)

# Get Rust, we need moar languages
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

ARG DEVELOPER=0
ENV PYTHON_VERSION=3
RUN apt-get install -y --no-install-recommends python3-dev python3-venv
RUN curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/install-poetry.py | python3 - \
    && pip3 install -U pip \
    && pip3 install -U wheel \
    && /root/.local/bin/poetry config virtualenvs.create false \
    && /root/.local/bin/poetry install
RUN ./configure --prefix=/tmp/lightning_install --enable-static && make -j3 DEVELOPER=${DEVELOPER} && make install

FROM debian:buster-slim as final

COPY --from=downloader /opt/tini /usr/bin/tini
RUN apt-get update && apt-get install -y --no-install-recommends socat inotify-tools python3 python3-pip libpq-dev postgresql \
    && rm -rf /var/lib/apt/lists/*

ENV LIGHTNINGD_DATA=/root/.lightning
ENV LIGHTNINGD_RPC_PORT=9835
ENV LIGHTNINGD_PORT=9735
ENV LIGHTNINGD_NETWORK=bitcoin

RUN mkdir $LIGHTNINGD_DATA && \
    touch $LIGHTNINGD_DATA/config
VOLUME [ "/root/.lightning" ]
COPY --from=builder /tmp/lightning_install/ /usr/local/
COPY --from=downloader /opt/bitcoin/bin /usr/bin
COPY --from=builder /tmp/lightning/tools/docker-entrypoint.sh entrypoint.sh

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr wget

RUN mkdir -p /opt/lightningd/plugins/ && \
    cd /opt/lightningd/plugins && \
    wget https://github.com/fiatjaf/trustedcoin/releases/download/v0.4.0/trustedcoin_linux_amd64 && \
    wget https://github.com/fiatjaf/sparko/releases/download/v2.8/sparko_linux_amd64 && \
    wget https://github.com/fiatjaf/lightningd-webhook/releases/download/v3.3/webhook_linux_amd64 && \
    wget https://github.com/flitz-be/lightningd-redis-publisher/releases/download/v0.2/lightningd-redis-publisher && \
    chmod +x trustedcoin_linux_amd64 && \
    chmod +x lightningd-redis-publisher && \
    chmod +x webhook_linux_amd64 && \
    chmod +x sparko_linux_amd64 
EXPOSE 9735 9835
ENTRYPOINT  [ "/usr/bin/tini", "-g", "--", "./entrypoint.sh" ]