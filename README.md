# What

A docker image for [Samba](https://www.samba.org/) geared towards TimeMachine backups.

## Image features

 * multi-architecture:
   * [x] linux/amd64
   * [x] linux/arm64
 * hardened:
    * [x] image runs read-only
    * [ ] image runs with ~~no capabilities~~ the following capabilities:
        * NET_BIND_SERVICE
        * CHOWN
        * FOWNER
        * SETUID
        * SETGID
        * DAC_OVERRIDE
    * [ ] ~~process runs as a non-root user, disabled login, no shell~~
        * the entrypoint script runs as root
 * lightweight
    * [x] based on our slim [Debian Trixie](https://github.com/dubo-dubon-duponey/docker-debian)
    * [x] simple entrypoint script
    * [ ] multi-stage build with ~~zero packages~~ `samba`, `samba-vfs-modules`, `smbclient` installed in the runtime image
 * observable
    * [x] healthcheck
    * [x] log to stdout
    * [ ] ~~prometheus endpoint~~

## Run


```bash
docker run -d --rm \
        --name samba \
        --env MOD_MDNS_NAME=samba \
        --env MOD_MDNS_HOST=TimeSamba \
        --read-only \
        --net host \
        --user root \
        --cap-drop ALL \
        --cap-add DAC_OVERRIDE \
        --cap-add FOWNER \
        --cap-add NET_BIND_SERVICE \
        --cap-add CHOWN \
        --cap-add SETUID \
        --cap-add SETGID \
        --volume [host_path]:/magnetar \
        --volume [host_path]:/tmp \
        --volume age_encrypted_users:/secrets/secrets.age \
        --volume age_key:/secrets/key \
        docker.io/dubodubonduponey/samba
```

## Notes

### Networking

You need to run this in `host` or `mac(or ip)vlan` networking (because of mDNS).

### Configuration

The following extra environment variables lets you further configure the image behavior:

* MOD_MDNS_HOST controls the host part under which the service is being announced (eg: $MOD_MDNS_HOST.local)
  * If set empty, will disable mDNS announcements altogether
* MOD_MDNS_NAME controls the fancy name
* MODEL allows controlling the icon for TimeMachine

The image runs read-only, but the following volumes are necessary (rw):
* /etc this is necessary to allow for on-the-fly user creation
* /magnetar/user/data/home where users homes are located
* /magnetar/user/data/share where the common share is located
* /magnetar/user/data/timemachine where the timemachine backups are located
* /magnetar/cache
* /magnetar/state
* /magnetar/runtime
* /magnetar/system/config/samba/main.conf where your samba config should live (see example for inspiration)

Finally note that you must pass an age encrypted file for `users:password`,
along with a decryption key.
If you want these to disappear immediately after consumption, you may of course
use and mount fifos (and feed the data through whatever appropriate mean).

### Advanced configuration

Any additional arguments when running the image will get fed to the `samba` binary.

## Debugging TimeMachine

From a mac:

```
log show --predicate 'subsystem == "com.apple.TimeMachine"' --info | grep 'upd: (' | cut -c 1-19,140-999
```

## Moar?

See [DEVELOP.md](DEVELOP.md)
