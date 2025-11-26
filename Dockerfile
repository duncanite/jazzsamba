ARG           FROM_REGISTRY=docker.io/dubodubonduponey

ARG           FROM_IMAGE_RUNTIME=base:runtime-trixie-2025-11-01
ARG           FROM_IMAGE_TOOLS=tools:linux-trixie-2025-11-01

FROM          $FROM_REGISTRY/$FROM_IMAGE_TOOLS                                                                          AS builder-tools

#######################
# Running image
#######################
FROM          $FROM_REGISTRY/$FROM_IMAGE_RUNTIME

# hadolint ignore=DL3002
USER          root

# Unclear if we need: tracker libtracker-sparql-1.0-dev (<- provides spotlight search thing)
RUN           --mount=type=secret,uid=42,id=CA \
              --mount=type=secret,uid=42,id=CERTIFICATE \
              --mount=type=secret,uid=42,id=KEY \
              --mount=type=secret,uid=42,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              apt-get update -qq && \
              apt-get install -qq --no-install-recommends \
                samba=2:4.22.4+dfsg-1~deb13u1 \
                samba-vfs-modules=2:4.22.4+dfsg-1~deb13u1 \
                age=1.2.1-1+b5 && \
              apt-get -qq autoremove      && \
              apt-get -qq clean           && \
              rm -rf /var/lib/apt/lists/* && \
              rm -rf /tmp/*               && \
              rm -rf /var/tmp/*

# IMPORTANT: core dump location is NOT configurable at runtime
RUN           groupadd smb-share && \
              echo "kernel.core_pattern = /magnetar/state/samba/cores/core.%e.%p" >> /etc/sysctl.conf

# Garbage alert: no matter configuration, dcerpcd does not honor any log directive
RUN           ln -s "$XDG_RUNTIME_DIR"/log.samba-dcerpcd /var/log/samba/log.samba-dcerpcd

# Note: samba cannot work realistically without root.
# USER          dubo-dubon-duponey

COPY          --from=builder-tools /magnetar/bin/goello-server-ng /magnetar/bin/goello-server-ng

ENV           _SERVICE_NICK="JazzSamba"
ENV           _SERVICE_PORT=445

### mDNS broadcasting
# Whether to enable MDNS broadcasting or not
ENV           MOD_MDNS_ENABLED=true
# Name is used as a short description for the service
ENV           MOD_MDNS_NAME="$_SERVICE_NICK mDNS display name"
# The service will be annonced and reachable at $MOD_MDNS_HOST.local (set to empty string to disable mDNS announces entirely)
ENV           MOD_MDNS_HOST="$_SERVICE_NICK"
# Also announce the service as a workstation (for example for the benefit of coreDNS mDNS)
ENV           ADVANCED_MOD_MDNS_STATION=false

ENV           MODEL="MacPro6,1"
ENV           USERS=""
ENV           PASSWORDS=""

EXPOSE        $_SERVICE_PORT

# Necessary for users creation - this is problematic
VOLUME        /etc

# These are necessary at runtime
#VOLUME        "$XDG_DATA_HOME"
#VOLUME        "$XDG_RUNTIME_DIR"
#VOLUME        "$XDG_CACHE_HOME"
#VOLUME        "$XDG_STATE_HOME"

HEALTHCHECK   --interval=120s --timeout=30s --start-period=10s --retries=1 CMD smbstatus --configfile /magnetar/system/config/samba/main.conf >/dev/null 2>&1 || exit 1
