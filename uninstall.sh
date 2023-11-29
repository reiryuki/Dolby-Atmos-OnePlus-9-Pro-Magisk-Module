mount -o rw,remount /data
[ ! "$MODPATH" ] && MODPATH=${0%/*}
[ ! "$MODID" ] && MODID=`basename "$MODPATH"`
UID=`id -u`

# log
exec 2>/data/media/"$UID"/$MODID\_uninstall.log
set -x

# run
. $MODPATH/function.sh

# boot mode
[ -z $BOOTMODE ] && ps | grep zygote | grep -qv grep && BOOTMODE=true
[ -z $BOOTMODE ] && ps -A 2>/dev/null | grep zygote | grep -qv grep && BOOTMODE=true
[ -z $BOOTMODE ] && BOOTMODE=false

# sar
if [ -z $SYSTEM_ROOT ]\
&& [ -z $SYSTEM_AS_ROOT ]; then
  if [ -f /system/init -o -L /system/init ]; then
    SYSTEM_AS_ROOT=true
  else
    if grep ' / ' /proc/mounts | grep -qv 'rootfs' || grep -q ' /system_root ' /proc/mounts; then
      SYSTEM_AS_ROOT=true
    else
      SYSTEM_AS_ROOT=false
    fi
  fi
fi

# function
grep_cmdline() {
  local REGEX="s/^$1=//p"
  { echo $(cat /proc/cmdline)$(sed -e 's/[^"]//g' -e 's/""//g' /proc/cmdline) | xargs -n 1; \
    sed -e 's/ = /=/g' -e 's/, /,/g' -e 's/"//g' /proc/bootconfig; \
  } 2>/dev/null | sed -n "$REGEX"
}

# slot
SLOT=`grep_cmdline androidboot.slot_suffix`
if [ -z $SLOT ]; then
  SLOT=`grep_cmdline androidboot.slot`
  [ -z $SLOT ] || SLOT=_${SLOT}
fi
[ "$SLOT" = "normal" ] && unset SLOT

# recovery
mount_partitions_in_recovery

# cleaning
remove_cache
PKGS=`cat $MODPATH/package.txt`
for PKG in $PKGS; do
  rm -rf /data/user*/"$UID"/$PKG
done
remove_sepolicy_rule
rm -f /data/vendor/dolby/dax_sqlite3.db
if [ "$BOOTMODE" != true ]; then
  rm -f `find /metadata/early-mount.d /persist/early-mount.d\
   /mnt/vendor/persist/early-mount.d /cache/early-mount.d\
   /data/unencrypted/early-mount.d /data/adb/early-mount.d\
   /cust/early-mount.d -type f -name manifest.xml`
fi

# magisk
magisk_setup

# remount
remount_rw

# restore
FILES="$MAGISKTMP/mirror/*/etc/vintf/manifest.xml
       $MAGISKTMP/mirror/*/*/etc/vintf/manifest.xml
       /*/etc/vintf/manifest.xml /*/*/etc/vintf/manifest.xml
       $MAGISKTMP/mirror/*/etc/selinux/*_hwservice_contexts
       $MAGISKTMP/mirror/*/*/etc/selinux/*_hwservice_contexts
       /*/etc/selinux/*_hwservice_contexts /*/*/etc/selinux/*_hwservice_contexts
       $MAGISKTMP/mirror/*/etc/selinux/*_file_contexts
       $MAGISKTMP/mirror/*/*/etc/selinux/*_file_contexts
       /*/etc/selinux/*_file_contexts /*/*/etc/selinux/*_file_contexts"
restore

# remount
remount_ro

# unmount
if [ "$BOOTMODE" == true ] && [ ! "$MAGISKPATH" ]; then
  unmount_mirror
fi


















