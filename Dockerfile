FROM debian:jessie

# Install basic required packages.
RUN set -x \
 && apt-get update \
 && echo "deb http://www.deb-multimedia.org jessie main non-free" >> /etc/apt/sources.list \
 && echo "deb-src http://www.deb-multimedia.org jessie main non-free" >> /etc/apt/sources.list \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes --no-install-recommends \
        deb-multimedia-keyring \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        ca-certificates \
        curl \
        ffmpeg \
        git \
        libargtable2-dev \
        libavcodec-dev \
        libavformat-dev \
        libavutil-dev \
        libtool \
        make \
        mkvtoolnix \
        xmlstarlet \
 && cd /tmp \
 && git clone https://github.com/erikkaashoek/Comskip.git \
 && cd Comskip \
 && ./autogen.sh && ./configure && make && make install \
 && cd / \
 && rm -rf /tmp/* \
 && apt-get remove -y \
        autoconf \
        automake \
        libargtable2-dev \
        libavformat-dev \
        libavutil-dev \
        libavcodec-dev \
        libtool \
        make \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN set -x \
    # Create plex user
 && useradd --system --uid 797 -M --shell /usr/sbin/nologin plex \
    # Download and install Plex (non plexpass) after displaying downloaded URL in the log.
    # This gets the latest non-plexpass version
    # Note: We created a dummy /bin/start to avoid install to fail due to upstart not being installed.
    # We won't use upstart anyway.
 && curl -I 'https://downloads.plex.tv/plex-media-server/1.2.0.3114-de38375/plexmediaserver_1.2.0.3114-de38375_amd64.deb' \
 && curl -L 'https://downloads.plex.tv/plex-media-server/1.2.0.3114-de38375/plexmediaserver_1.2.0.3114-de38375_amd64.deb' -o plexmediaserver.deb \
 && touch /bin/start \
 && chmod +x /bin/start \
 && dpkg -i plexmediaserver.deb \
 && rm -f plexmediaserver.deb \
 && rm -f /bin/start \
    # Install dumb-init
    # https://github.com/Yelp/dumb-init
 && DUMP_INIT_URI=$(curl -L https://github.com/Yelp/dumb-init/releases/latest | grep -Po '(?<=href=")[^"]+_amd64(?=")') \
 && curl -Lo /usr/local/bin/dumb-init "https://github.com/$DUMP_INIT_URI" \
 && chmod +x /usr/local/bin/dumb-init \
    # Create writable config directory in case the volume isn't mounted
 && mkdir /config \
 && chown plex:plex /config

# PLEX_MEDIA_SERVER_MAX_PLUGIN_PROCS: The number of plugins that can run at the same time.
# $PLEX_MEDIA_SERVER_MAX_STACK_SIZE: Used for "ulimit -s $PLEX_MEDIA_SERVER_MAX_STACK_SIZE".
# PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR: defines the location of the configuration directory,
#   default is "${HOME}/Library/Application Support".
ENV PLEX_MEDIA_SERVER_MAX_PLUGIN_PROCS=6 \
    PLEX_MEDIA_SERVER_MAX_STACK_SIZE=3000 \
    PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR=/config \
    PLEX_MEDIA_SERVER_HOME=/usr/lib/plexmediaserver \
    LD_LIBRARY_PATH=/usr/lib/plexmediaserver \
    TMPDIR=/tmp

COPY root /

VOLUME ["/config", "/media"]

EXPOSE 32400

USER plex

WORKDIR /usr/lib/plexmediaserver
ENTRYPOINT ["/usr/local/bin/dumb-init", "/plex-entrypoint.sh"]
CMD ["/usr/lib/plexmediaserver/Plex Media Server"]
