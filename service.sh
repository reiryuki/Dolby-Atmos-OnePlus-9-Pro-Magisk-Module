MODPATH=${0%/*}

# log
LOGFILE=$MODPATH/debug.log
exec 2>$LOGFILE
set -x

# var
API=`getprop ro.build.version.sdk`

# property
resetprop -n ro.audio.ignore_effects false
resetprop -n ro.build.version.oplusrom V13.1.0
resetprop -n ro.vendor.dolby.dax.version DAX3_3.6.0.12_r1
resetprop -n ro.vendor.dolby.model PAFM00
resetprop -n ro.vendor.dolby.device OP46C3
resetprop -n ro.vendor.dolby.manufacturer OPLUS
resetprop -n ro.vendor.dolby.brand OPLUS
resetprop -n ro.oplus.audio.effect.type dolby
resetprop -n vendor.audio.dolby.ds2.enabled false
resetprop -n vendor.audio.dolby.ds2.hardbypass false
resetprop -n ro.oplus.audio.dolby.equalizer_support true
resetprop -n ro.oplus.audio.dolby.movieToMusic_support true
resetprop -n ro.oplus.audio.dolby.mod_uuid false
#resetprop -p --delete persist.vendor.dolby.loglevel
#resetprop -n persist.vendor.dolby.loglevel 0
#resetprop -n vendor.audio.gef.debug.flags false
#resetprop -n vendor.audio.gef.enable.traces false
#resetprop -n vendor.dolby.dap.param.tee false
#resetprop -n vendor.dolby.mi.metadata.log false
#resetprop -n vendor.dolby.debug.dap_pcm_dump false

# restart
if [ "$API" -ge 24 ]; then
  SERVER=audioserver
else
  SERVER=mediaserver
fi
PID=`pidof $SERVER`
if [ "$PID" ]; then
  killall $SERVER android.hardware.audio@4.0-service-mediatek
fi

# stop
NAMES="dms-hal-2-0 dms-v36-hal-2-0"
for NAME in $NAMES; do
  if [ "`getprop init.svc.$NAME`" == running ]\
  || [ "`getprop init.svc.$NAME`" == restarting ]; then
    stop $NAME
  fi
done

# mount
DIR=/odm/bin/hw
FILES=$DIR/vendor.dolby_v3_6.hardware.dms360@2.0-service
if [ "`realpath $DIR`" == $DIR ]; then
  for FILE in $FILES; do
    if [ -f $FILE ]; then
      if [ -L $MODPATH/system/vendor ]\
      && [ -d $MODPATH/vendor ]; then
        mount -o bind $MODPATH/vendor$FILE $FILE
      else
        mount -o bind $MODPATH/system/vendor$FILE $FILE
      fi
    fi
  done
fi

# run
SERVICES=`realpath /vendor`/bin/hw/vendor.dolby_v3_6.hardware.dms360@2.0-service
for SERVICE in $SERVICES; do
  killall $SERVICE
  $SERVICE &
  PID=`pidof $SERVICE`
done

# restart
killall vendor.qti.hardware.vibrator.service\
 vendor.qti.hardware.vibrator.service.oneplus9\
 android.hardware.camera.provider@2.4-service_64\
 vendor.mediatek.hardware.mtkpower@1.0-service\
 android.hardware.usb@1.0-service\
 android.hardware.usb@1.0-service.basic\
 android.hardware.light-service.mt6768\
 android.hardware.lights-service.xiaomi_mithorium\
 vendor.samsung.hardware.light-service\
 android.hardware.sensors@1.0-service\
 android.hardware.sensors@2.0-service\
 android.hardware.sensors@2.0-service-mediatek\
 android.hardware.sensors@2.0-service.multihal\
 android.hardware.health-service.qti
#skillall vendor.qti.hardware.display.allocator-service

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

# grant
PKG=com.oplus.audio.effectcenterui
if appops get $PKG > /dev/null 2>&1; then
  appops set $PKG WRITE_SETTINGS allow
  appops set $PKG SYSTEM_ALERT_WINDOW allow
  if [ "$API" -ge 31 ]; then
    pm grant $PKG android.permission.BLUETOOTH_CONNECT
  fi
  if [ "$API" -ge 30 ]; then
    appops set $PKG AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore
  fi
  if [ "$API" -ge 33 ]; then
    appops set $PKG ACCESS_RESTRICTED_SETTINGS allow
  fi
  PKGOPS=`appops get $PKG`
  UID=`dumpsys package $PKG 2>/dev/null | grep -m 1 userId= | sed 's|    userId=||g'`
  if [ "$UID" ] && [ "$UID" -gt 9999 ]; then
    UIDOPS=`appops get --uid "$UID"`
  fi
fi

# grant
PKG=com.oplus.audio.effectcenter
appops set $PKG WRITE_SETTINGS allow
if [ "$API" -ge 31 ]; then
  pm grant $PKG android.permission.BLUETOOTH_CONNECT
fi
if [ "$API" -ge 30 ]; then
  appops set $PKG AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore
fi
PKGOPS=`appops get $PKG`
UID=`dumpsys package $PKG 2>/dev/null | grep -m 1 userId= | sed 's|    userId=||g'`
if [ "$UID" ] && [ "$UID" -gt 9999 ]; then
  UIDOPS=`appops get --uid "$UID"`
fi

# function
stop_log() {
SIZE=`du $LOGFILE | sed "s|$LOGFILE||g"`
if [ "$LOG" != stopped ] && [ "$SIZE" -gt 50 ]; then
  exec 2>/dev/null
  set +x
  LOG=stopped
fi
}
check_audioserver() {
if [ "$NEXTPID" ]; then
  PID=$NEXTPID
else
  PID=`pidof $SERVER`
fi
sleep 15
stop_log
NEXTPID=`pidof $SERVER`
if [ "`getprop init.svc.$SERVER`" != stopped ]; then
  [ "$PID" != "$NEXTPID" ] && killall $PROC
else
  start $SERVER
fi
check_audioserver
}

# check
for SERVICE in $SERVICES; do
  if ! pidof $SERVICE; then
    $SERVICE &
    PID=`pidof $SERVICE`
  fi
done
PROC="com.oplus.audio.effectcenter com.oplus.audio.effectcenterui"
killall $PROC
check_audioserver








