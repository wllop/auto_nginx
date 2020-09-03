#!/bin/sh
### BEGIN INIT INFO
# Provides:          asi_si_webjack
# Required-Start:    $network $remote_fs $local_fs
# Required-Stop:     $network $remote_fs $local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start Chroot Environment
### END INIT INFO

# Author: Walter Llop Masia @wllop>
## Para instalar, ubicar el script en /etc/init.d, dar permisos de ejecución chmod a+x autochroot.sh y ejecutar update-rc.d autochroot defaults y LISTO!!

PATH=/sbin:/usr/sbin:/bin:/usr/bin
case "$1" in
start)
    for user in $(find /var/www/ -maxdepth 1 -name "webjack*" -type d)
    do
    mount --bind /dev/urandom  $user/chroot/dev/urandom 2>/dev/null
    mount -o "ro,bind" /etc/ssl/certs  $user/chroot/etc/ssl/certs 2>/dev/null
    mount --bind /etc/resolv.conf $user/chroot/etc/resolv.conf 2>/dev/null
    mount --bind /lib/x86_64-linux-gnu/libnss_dns.so.2 $user/chroot/lib/x86_64-linux-gnu/libnss_dns.so.2 2>/dev/null
    mount --bind /etc/hosts $user/chroot/etc/hosts 2>/dev/null
    mount --bind /etc/localtime $user/chroot/etc/localtime 2>/dev/null
    mount -o "ro,bind" /usr/share/zoneinfo $user/chroot/usr/share/zoneinfo 2>/dev/null
    mount -o "ro,bind" /usr/share/ca-certificates $user/chroot/usr/share/ca-certificates 2>/dev/null
    mount --bind /lib64/ld-linux-x86-64.so.2 $user/chroot/lib64/ld-linux-x86-64.so.2 2>/dev/null
    mount --bind /lib/x86_64-linux-gnu/libc.so.6 $user/chroot/lib/x86_64-linux-gnu/libc.so.6  2>/dev/null
   done
;;
esac