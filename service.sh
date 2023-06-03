MODPATH=${0%/*}
API=`getprop ro.build.version.sdk`

# debug
exec 2>$MODPATH/debug.log
set -x

# property
resetprop ro.feature.dolby_enable true
resetprop vendor.audio.dolby.ds2.enabled false
resetprop vendor.audio.dolby.ds2.hardbypass false

# restart
if [ "$API" -ge 24 ]; then
  SVR=audioserver
else
  SVR=mediaserver
fi
PID=`pidof $SVR`
if [ "$PID" ]; then
  killall $SVR
fi

# stop
NAMES="dms-hal-1-0 dms-hal-2-0"
for NAME in $NAMES; do
  if [ "`getprop init.svc.$NAME`" == running ]\
  || [ "`getprop init.svc.$NAME`" == restarting ]; then
    stop $NAME
  fi
done

# run
SVCS=`realpath /vendor`/bin/hw/vendor.dolby.hardware.dms@1.0-service
for SVC in $SVCS; do
  killall $SVC
  $SVC &
  PID=`pidof $SVC`
done

# restart
killall vendor.qti.hardware.vibrator.service
killall vendor.qti.hardware.vibrator.service.oneplus9
killall android.hardware.camera.provider@2.4-service_64
killall vendor.mediatek.hardware.mtkpower@1.0-service
killall android.hardware.usb@1.0-service
killall android.hardware.usb@1.0-service.basic
killall android.hardware.light-service.mt6768
killall android.hardware.lights-service.xiaomi_mithorium
killall vendor.samsung.hardware.light-service
killall android.hardware.sensors@1.0-service
killall android.hardware.sensors@2.0-service-mediatek
killall android.hardware.sensors@2.0-service.multihal

# wait
sleep 20

# aml fix
AML=/data/adb/modules/aml
if [ -L $AML/system/vendor ]\
&& [ -d $AML/vendor ]; then
  DIR=$AML/vendor/odm/etc
else
  DIR=$AML/system/vendor/odm/etc
fi
if [ -d $DIR ] && [ ! -f $AML/disable ]; then
  chcon -R u:object_r:vendor_configs_file:s0 $DIR
fi
AUD=`grep AUD= $MODPATH/copy.sh | sed -e 's|AUD=||g' -e 's|"||g'`
if [ -L $AML/system/vendor ]\
&& [ -d $AML/vendor ]; then
  DIR=$AML/vendor
else
  DIR=$AML/system/vendor
fi
FILES=`find $DIR -type f -name $AUD`
if [ -d $AML ] && [ ! -f $AML/disable ]\
&& find $DIR -type f -name $AUD; then
  if ! grep '/odm' $AML/post-fs-data.sh && [ -d /odm ]\
  && [ "`realpath /odm/etc`" == /odm/etc ]; then
    for FILE in $FILES; do
      DES=/odm`echo $FILE | sed "s|$DIR||g"`
      if [ -f $DES ]; then
        umount $DES
        mount -o bind $FILE $DES
      fi
    done
  fi
  if ! grep '/my_product' $AML/post-fs-data.sh\
  && [ -d /my_product ]; then
    for FILE in $FILES; do
      DES=/my_product`echo $FILE | sed "s|$DIR||g"`
      if [ -f $DES ]; then
        umount $DES
        mount -o bind $FILE $DES
      fi
    done
  fi
fi

# wait
until [ "`getprop sys.boot_completed`" == "1" ]; do
  sleep 10
done

# allow
PKG=com.dolby.daxappui
if pm list packages | grep $PKG ; then
  if [ "$API" -ge 30 ]; then
    appops set $PKG AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore
  fi
  PKGOPS=`appops get $PKG`
  UID=`dumpsys package $PKG 2>/dev/null | grep -m 1 userId= | sed 's/    userId=//g'`
  if [ "$UID" -gt 9999 ]; then
    UIDOPS=`appops get --uid "$UID"`
  fi
fi

# allow
PKG=com.dolby.daxservice
if pm list packages | grep $PKG ; then
  if [ "$API" -ge 30 ]; then
    appops set $PKG AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore
  fi
  PKGOPS=`appops get $PKG`
  UID=`dumpsys package $PKG 2>/dev/null | grep -m 1 userId= | sed 's/    userId=//g'`
  if [ "$UID" -gt 9999 ]; then
    UIDOPS=`appops get --uid "$UID"`
  fi
fi

# allow
PKG=com.dolby.atmos
if pm list packages | grep $PKG ; then
  if [ "$API" -ge 30 ]; then
    appops set $PKG AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore
  fi
  PKGOPS=`appops get $PKG`
  UID=`dumpsys package $PKG 2>/dev/null | grep -m 1 userId= | sed 's/    userId=//g'`
  if [ "$UID" -gt 9999 ]; then
    UIDOPS=`appops get --uid "$UID"`
  fi
fi

# function
stop_log() {
FILE=$MODPATH/debug.log
SIZE=`du $FILE | sed "s|$FILE||g"`
if [ "$LOG" != stopped ] && [ "$SIZE" -gt 50 ]; then
  exec 2>/dev/null
  LOG=stopped
fi
}
check_audioserver() {
if [ "$NEXTPID" ]; then
  PID=$NEXTPID
else
  PID=`pidof $SVR`
fi
sleep 15
stop_log
NEXTPID=`pidof $SVR`
if [ "`getprop init.svc.$SVR`" != stopped ]; then
  until [ "$PID" != "$NEXTPID" ]; do
    check_audioserver
  done
  killall $PROC
  check_audioserver
else
  start $SVR
  check_audioserver
fi
}

# check
for SVC in $SVCS; do
  if ! pidof $SVC; then
    $SVC &
    PID=`pidof $SVC`
  fi
done
PROC="com.dolby.daxservice com.dolby.daxappui com.dolby.atmos"
killall $PROC
check_audioserver













