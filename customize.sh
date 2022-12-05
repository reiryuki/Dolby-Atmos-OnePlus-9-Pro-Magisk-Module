# space
if [ "$BOOTMODE" == true ]; then
  ui_print " "
fi

# magisk
if [ -d /sbin/.magisk ]; then
  MAGISKTMP=/sbin/.magisk
else
  MAGISKTMP=`realpath /dev/*/.magisk`
fi

# path
if [ "$BOOTMODE" == true ]; then
  MIRROR=$MAGISKTMP/mirror
else
  MIRROR=
fi
SYSTEM=`realpath $MIRROR/system`
PRODUCT=`realpath $MIRROR/product`
VENDOR=`realpath $MIRROR/vendor`
SYSTEM_EXT=`realpath $MIRROR/system_ext`
if [ -d $MIRROR/odm ]; then
  ODM=`realpath $MIRROR/odm`
else
  ODM=`realpath /odm`
fi
if [ -d $MIRROR/my_product ]; then
  MY_PRODUCT=`realpath $MIRROR/my_product`
else
  MY_PRODUCT=`realpath /my_product`
fi

# optionals
OPTIONALS=/sdcard/optionals.prop

# info
MODVER=`grep_prop version $MODPATH/module.prop`
MODVERCODE=`grep_prop versionCode $MODPATH/module.prop`
ui_print " ID=$MODID"
ui_print " Version=$MODVER"
ui_print " VersionCode=$MODVERCODE"
ui_print " MagiskVersion=$MAGISK_VER"
ui_print " MagiskVersionCode=$MAGISK_VER_CODE"
ui_print " "

# bit
if [ "`grep_prop dolby.32bit $OPTIONALS`" == 1 ]; then
  IS64BIT=false
fi
if [ "$IS64BIT" != true ]; then
  ui_print "- 32 bit"
  cp -rf $MODPATH/system_32/* $MODPATH/system
  rm -rf `find $MODPATH -type d -name *64`
  ui_print " "
else
  ui_print "- 64 bit"
  ui_print " "
fi
rm -rf $MODPATH/system_32

# sdk
NUM=28
if [ "$API" -lt $NUM ]; then
  ui_print "! Unsupported SDK $API. You have to upgrade your"
  ui_print "  Android version at least SDK API $NUM to use this module."
  abort
else
  ui_print "- SDK $API"
  ui_print " "
fi

# mount
if [ "$BOOTMODE" != true ]; then
  mount -o rw -t auto /dev/block/bootdevice/by-name/cust /vendor
  mount -o rw -t auto /dev/block/bootdevice/by-name/vendor /vendor
  mount -o rw -t auto /dev/block/bootdevice/by-name/persist /persist
  mount -o rw -t auto /dev/block/bootdevice/by-name/metadata /metadata
fi

# sepolicy.rule
FILE=$MODPATH/sepolicy.sh
DES=$MODPATH/sepolicy.rule
if [ -f $FILE ] && [ "`grep_prop sepolicy.sh $OPTIONALS`" != 1 ]; then
  mv -f $FILE $DES
  sed -i 's/magiskpolicy --live "//g' $DES
  sed -i 's/"//g' $DES
fi

# .aml.sh
mv -f $MODPATH/aml.sh $MODPATH/.aml.sh

# mod ui
if [ "`grep_prop mod.ui $OPTIONALS`" == 1 ]; then
  APP=DaxUI
  FILE=/sdcard/$APP.apk
  DIR=`find $MODPATH/system -type d -name $APP`
  ui_print "- Using modified UI apk..."
  if [ -f $FILE ]; then
    cp -f $FILE $DIR
    chmod 0644 $DIR/$APP.apk
    ui_print "  Applied"
  else
    ui_print "  ! There is no $FILE file."
    ui_print "    Please place the apk to your internal storage first"
    ui_print "    and reflash!"
  fi
  ui_print " "
fi

# cleaning
ui_print "- Cleaning..."
PKG="com.dolby.daxappui
     com.dolby.daxservice
     com.dolby.atmos"
if [ "$BOOTMODE" == true ]; then
  for PKGS in $PKG; do
    RES=`pm uninstall $PKGS`
  done
fi
rm -f /data/vendor/dolby/dap_sqlite3.db
rm -rf $MODPATH/unused
rm -rf /metadata/magisk/$MODID
rm -rf /mnt/vendor/persist/magisk/$MODID
rm -rf /persist/magisk/$MODID
rm -rf /data/unencrypted/magisk/$MODID
rm -rf /cache/magisk/$MODID
ui_print " "

# function
conflict() {
for NAMES in $NAME; do
  DIR=/data/adb/modules_update/$NAMES
  if [ -f $DIR/uninstall.sh ]; then
    sh $DIR/uninstall.sh
  fi
  rm -rf $DIR
  DIR=/data/adb/modules/$NAMES
  rm -f $DIR/update
  touch $DIR/remove
  FILE=/data/adb/modules/$NAMES/uninstall.sh
  if [ -f $FILE ]; then
    sh $FILE
    rm -f $FILE
  fi
  rm -rf /metadata/magisk/$NAMES
  rm -rf /mnt/vendor/persist/magisk/$NAMES
  rm -rf /persist/magisk/$NAMES
  rm -rf /data/unencrypted/magisk/$NAMES
  rm -rf /cache/magisk/$NAMES
done
}

# conflict
NAME="dolbyatmos
      DolbyAudio
      MotoDolby"
conflict
NAME=SoundEnhancement
FILE=/data/adb/modules/$NAME/module.prop
if grep -Eq 'Dolby Atmos Xperia' $FILE; then
  conflict
fi
NAME=MiSound
FILE=/data/adb/modules/$NAME/module.prop
if grep -Eq 'and Dolby Atmos' $FILE; then
  conflict
fi

# function
cleanup() {
if [ -f $DIR/uninstall.sh ]; then
  sh $DIR/uninstall.sh
fi
DIR=/data/adb/modules_update/$MODID
if [ -f $DIR/uninstall.sh ]; then
  sh $DIR/uninstall.sh
fi
}

# cleanup
DIR=/data/adb/modules/$MODID
FILE=$DIR/module.prop
if [ "`grep_prop data.cleanup $OPTIONALS`" == 1 ]; then
  sed -i 's/^data.cleanup=1/data.cleanup=0/' $OPTIONALS
  ui_print "- Cleaning-up $MODID data..."
  cleanup
  ui_print " "
elif [ -d $DIR ] && ! grep -Eq "$MODNAME" $FILE; then
  ui_print "- Different version detected"
  ui_print "  Cleaning-up $MODID data..."
  cleanup
  ui_print " "
fi

# function
permissive_2() {
sed -i '1i\
SELINUX=`getenforce`\
if [ "$SELINUX" == Enforcing ]; then\
  magiskpolicy --live "permissive *"\
fi\' $MODPATH/post-fs-data.sh
}
permissive() {
SELINUX=`getenforce`
if [ "$SELINUX" == Enforcing ]; then
  setenforce 0
  SELINUX=`getenforce`
  if [ "$SELINUX" == Enforcing ]; then
    ui_print "  Your device can't be turned to Permissive state."
    ui_print "  Using Magisk Permissive mode instead."
    permissive_2
  else
    setenforce 1
    sed -i '1i\
SELINUX=`getenforce`\
if [ "$SELINUX" == Enforcing ]; then\
  setenforce 0\
fi\' $MODPATH/post-fs-data.sh
  fi
fi
}
set_read_write() {
for NAMES in $NAME; do
  blockdev --setrw $DIR$NAMES
done
}
remount_rw() {
DIR=/dev/block/bootdevice/by-name
NAME="/vendor$SLOT /cust$SLOT /system$SLOT /system_ext$SLOT"
set_read_write
DIR=/dev/block/mapper
set_read_write
DIR=$MAGISKTMP/block
NAME="/vendor /system_root /system /system_ext"
set_read_write
mount -o rw,remount $MAGISKTMP/mirror/system
mount -o rw,remount $MAGISKTMP/mirror/system_root
mount -o rw,remount $MAGISKTMP/mirror/system_ext
mount -o rw,remount $MAGISKTMP/mirror/vendor
mount -o rw,remount /system
mount -o rw,remount /
mount -o rw,remount /system_root
mount -o rw,remount /system_ext
mount -o rw,remount /vendor
}
remount_ro() {
if [ "$BOOTMODE" == true ]; then
  mount -o ro,remount $MAGISKTMP/mirror/system
  mount -o ro,remount $MAGISKTMP/mirror/system_root
  mount -o ro,remount $MAGISKTMP/mirror/system_ext
  mount -o ro,remount $MAGISKTMP/mirror/vendor
  mount -o ro,remount /system
  mount -o ro,remount /
  mount -o ro,remount /system_root
  mount -o ro,remount /system_ext
  mount -o ro,remount /vendor
fi
}
backup() {
if [ ! -f $FILE.orig ] && [ ! -f $FILE.bak ]; then
  cp -f $FILE $FILE.orig
fi
}
patch_manifest() {
if [ -f $FILE ]; then
  backup
  if [ -f $FILE.orig ] || [ -f $FILE.bak ]; then
    ui_print "- Created"
    ui_print "$FILE.orig"
    ui_print " "
    ui_print "- Patching"
    ui_print "$FILE"
    ui_print "  directly..."
    sed -i '/<manifest/a\
    <hal format="hidl">\
        <name>vendor.dolby.hardware.dms</name>\
        <transport>hwbinder</transport>\
        <version>1.0</version>\
        <interface>\
            <name>IDms</name>\
            <instance>default</instance>\
        </interface>\
        <fqname>@1.0::IDms/default</fqname>\
    </hal>' $FILE
    ui_print " "
  else
    ui_print "- Failed to create"
    ui_print "$FILE.orig"
    ui_print " "
  fi
fi
}
patch_hwservice() {
if [ -f $FILE ]; then
  backup
  if [ -f $FILE.orig ] || [ -f $FILE.bak ]; then
    ui_print "- Created"
    ui_print "$FILE.orig"
    ui_print " "
    ui_print "- Patching"
    ui_print "$FILE"
    ui_print "  directly..."
    sed -i '1i\
vendor.dolby.hardware.dms::IDms u:object_r:hal_dms_hwservice:s0' $FILE
    ui_print " "
  else
    ui_print "- Failed to create"
    ui_print "$FILE.orig"
    ui_print " "
  fi
fi
}
restore() {
for FILES in $FILE; do
  if [ -f $FILES.orig ]; then
    mv -f $FILES.orig $FILES
  fi
  if [ -f $FILES.bak ]; then
    mv -f $FILES.bak $FILES
  fi
done
}
early_init_mount_dir() {
if echo $MAGISK_VER | grep -Eq delta\
&& [ "`grep_prop dolby.skip.early $OPTIONALS`" != 1 ]; then
  EIM=true
  ACTIVEEIMDIR=$MAGISKTMP/mirror/early-mount
  if [ -L $ACTIVEEIMDIR ]; then
    EIMDIR=$(readlink $ACTIVEEIMDIR)
    [ "${EIMDIR:0:1}" != "/" ] && EIMDIR="$MAGISKTMP/mirror/$EIMDIR"
  elif ! $ISENCRYPTED; then
    EIMDIR=/data/adb/early-mount.d
  elif [ -d /data/unencrypted ]\
  && ! grep ' /data ' /proc/mounts | grep -qE 'dm-|f2fs'; then
    EIMDIR=/data/unencrypted/early-mount.d
  elif grep ' /cache ' /proc/mounts | grep -q 'ext4'; then
    EIMDIR=/cache/early-mount.d
  elif grep ' /metadata ' /proc/mounts | grep -q 'ext4'; then
    EIMDIR=/metadata/early-mount.d
  elif grep ' /persist ' /proc/mounts | grep -q 'ext4'; then
    EIMDIR=/persist/early-mount.d
  elif grep ' /mnt/vendor/persist ' /proc/mounts | grep -q 'ext4'; then
    EIMDIR=/mnt/vendor/persist/early-mount.d
  else
    EIM=false
    ui_print "- Unable to find early init mount directory"
    ui_print " "
  fi
  if [ -d ${EIMDIR%/early-mount.d} ]; then
    mkdir -p $EIMDIR
    ui_print "- Your early init mount directory is"
    ui_print "  $EIMDIR"
    ui_print " "
    ui_print "  Any file stored to this directory will not be deleted even"
    ui_print "  you have uninstalled this module."
  else
    EIM=false
    ui_print "- Unable to find early init mount directory ${EIMDIR%/early-mount.d}"
  fi
  ui_print " "
else
  EIM=false
fi
}
find_file() {
for NAMES in $NAME; do
  FILE=`find $SYSTEM $VENDOR $SYSTEM_EXT -type f -name $NAMES`
  if [ ! "$FILE" ]; then
    if [ "`grep_prop install.hwlib $OPTIONALS`" == 1 ]; then
      sed -i 's/^install.hwlib=1/install.hwlib=0/' $OPTIONALS
      ui_print "- Installing $NAMES directly to /system and /vendor..."
      cp $MODPATH/system_support/lib/$NAMES $SYSTEM/lib
      cp $MODPATH/system_support/lib64/$NAMES $SYSTEM/lib64
      cp $MODPATH/system_support/vendor/lib/$NAMES $VENDOR/lib
      cp $MODPATH/system_support/vendor/lib64/$NAMES $VENDOR/lib64
      DES=$SYSTEM/lib/$NAMES
      DES2=$SYSTEM/lib64/$NAMES
      DES3=$VENDOR/lib/$NAMES
      DES4=$VENDOR/lib64/$NAMES
      if [ -f $MODPATH/system_support/lib/$NAMES ]\
      && [ ! -f $DES ]; then
        ui_print "  ! $DES"
        ui_print "    installation failed."
        ui_print "  Using $NAMES systemlessly."
        cp -f $MODPATH/system_support/lib/$NAMES $MODPATH/system/lib
      fi
      if [ -f $MODPATH/system_support/lib64/$NAMES ]\
      && [ ! -f $DES2 ]; then
        ui_print "  ! $DES2"
        ui_print "    installation failed."
        ui_print "  Using $NAMES systemlessly."
        cp -f $MODPATH/system_support/lib64/$NAMES $MODPATH/system/lib64
      fi
      if [ -f $MODPATH/system_support/vendor/lib/$NAMES ]\
      && [ ! -f $DES3 ]; then
        ui_print "  ! $DES3"
        ui_print "    installation failed."
        ui_print "  Using $NAMES systemlessly."
        cp -f $MODPATH/system_support/vendor/lib/$NAMES $MODPATH/system/vendor/lib
      fi
      if [ -f $MODPATH/system_support/vendor/lib64/$NAMES ]\
      && [ ! -f $DES4 ]; then
        ui_print "  ! $DES4"
        ui_print "    installation failed."
        ui_print "  Using $NAMES systemlessly."
        cp -f $MODPATH/system_support/vendor/lib64/$NAMES $MODPATH/system/vendor/lib64
      fi
    else
      ui_print "! $NAMES not found."
      ui_print "  Using $NAMES systemlessly."
      cp -f $MODPATH/system_support/lib/$NAMES $MODPATH/system/lib
      cp -f $MODPATH/system_support/lib64/$NAMES $MODPATH/system/lib64
      cp -f $MODPATH/system_support/vendor/lib/$NAMES $MODPATH/system/vendor/lib
      cp -f $MODPATH/system_support/vendor/lib64/$NAMES $MODPATH/system/vendor/lib64
      ui_print "  If this module still doesn't work, type:"
      ui_print "  install.hwlib=1"
      ui_print "  inside $OPTIONALS"
      ui_print "  and reinstall this module"
      ui_print "  to install $NAMES directly to this ROM."
      ui_print "  DwYOR!"
    fi
    ui_print " "
  fi
done
}
patch_manifest_eim() {
if [ $EIM == true ]; then
  SRC=$SYSTEM/etc/vintf/manifest.xml
  if [ -f $SRC ]; then
    DIR=$EIMDIR/system/etc/vintf
    DES=$DIR/manifest.xml
    mkdir -p $DIR
    if [ ! -f $DES ]; then
      cp -f $SRC $DIR
    fi
    if ! grep -A2 vendor.dolby.hardware.dms $DES | grep -Eq 1.0; then
      ui_print "- Patching"
      ui_print "$SRC"
      ui_print "  systemlessly using early init mount..."
      sed -i '/<manifest/a\
    <hal format="hidl">\
        <name>vendor.dolby.hardware.dms</name>\
        <transport>hwbinder</transport>\
        <version>1.0</version>\
        <interface>\
            <name>IDms</name>\
            <instance>default</instance>\
        </interface>\
        <fqname>@1.0::IDms/default</fqname>\
    </hal>' $DES
      ui_print " "
    fi
  else
    EIM=false
  fi
fi
}
patch_hwservice_eim() {
if [ $EIM == true ]; then
  SRC=$SYSTEM/etc/selinux/plat_hwservice_contexts
  if [ -f $SRC ]; then
    DIR=$EIMDIR/system/etc/selinux
    DES=$DIR/plat_hwservice_contexts
    mkdir -p $DIR
    if [ ! -f $DES ]; then
      cp -f $SRC $DIR
    fi
    if ! grep -Eq 'u:object_r:hal_dms_hwservice:s0|u:object_r:default_android_hwservice:s0' $DES; then
      ui_print "- Patching"
      ui_print "$SRC"
      ui_print "  systemlessly using early init mount..."
      sed -i '1i\
vendor.dolby.hardware.dms::IDms u:object_r:hal_dms_hwservice:s0' $DES
      ui_print " "
    fi
  else
    EIM=false
  fi
fi
}

# permissive
if [ "`grep_prop permissive.mode $OPTIONALS`" == 1 ]; then
  ui_print "- Using device Permissive mode."
  rm -f $MODPATH/sepolicy.rule
  permissive
  ui_print " "
elif [ "`grep_prop permissive.mode $OPTIONALS`" == 2 ]; then
  ui_print "- Using Magisk Permissive mode."
  rm -f $MODPATH/sepolicy.rule
  permissive_2
  ui_print " "
fi

# remount
remount_rw

# early init mount dir
early_init_mount_dir

# function
check_function() {
ui_print "- Checking"
ui_print "$NAME"
ui_print "  function at"
ui_print "$FILE"
ui_print "  Please wait..."
if ! grep -Eq $NAME $FILE; then
  ui_print "  ! Function not found."
  ui_print "    Unsupported ROM."
  remount_ro
  abort
fi
ui_print " "
}

# check
chcon -R u:object_r:system_lib_file:s0 $MODPATH/system_support/lib*
chcon -R u:object_r:same_process_hal_file:s0 $MODPATH/system_support/vendor/lib*
NAME="libhidltransport.so libhwbinder.so"
find_file
NAME=_ZN7android8hardware7details17gBnConstructorMapE
if [ "$IS64BIT" == true ]; then
  FILE=$SYSTEM/lib64/libhidlbase.so
  check_function
fi
FILE=$SYSTEM/lib/libhidlbase.so
check_function
rm -rf $MODPATH/system_support

# patch manifest.xml
FILE="$MAGISKTMP/mirror/*/etc/vintf/manifest.xml
      $MAGISKTMP/mirror/*/*/etc/vintf/manifest.xml
      /*/etc/vintf/manifest.xml /*/*/etc/vintf/manifest.xml
      $MAGISKTMP/mirror/*/etc/vintf/manifest/*.xml
      $MAGISKTMP/mirror/*/*/etc/vintf/manifest/*.xml
      /*/etc/vintf/manifest/*.xml /*/*/etc/vintf/manifest/*.xml"
if [ "`grep_prop dolby.skip.vendor $OPTIONALS`" != 1 ]\
&& ! grep -A2 vendor.dolby.hardware.dms $FILE | grep -Eq 1.0; then
  FILE=$VENDOR/etc/vintf/manifest.xml
  patch_manifest
fi
if [ "`grep_prop dolby.skip.system $OPTIONALS`" != 1 ]\
&& ! grep -A2 vendor.dolby.hardware.dms $FILE | grep -Eq 1.0; then
  FILE=$SYSTEM/etc/vintf/manifest.xml
  patch_manifest
fi
if [ "`grep_prop dolby.skip.system_ext $OPTIONALS`" != 1 ]\
&& ! grep -A2 vendor.dolby.hardware.dms $FILE | grep -Eq 1.0; then
  FILE=$SYSTEM_EXT/etc/vintf/manifest.xml
  patch_manifest
fi
if ! grep -A2 vendor.dolby.hardware.dms $FILE | grep -Eq 1.0; then
  patch_manifest_eim
  if [ $EIM == false ]; then
    ui_print "- Using systemless manifest.xml patch."
    ui_print "  On some ROMs, it causes bugs or even makes bootloop"
    ui_print "  because not allowed to restart hwservicemanager."
    ui_print "  You can fix this by using Magisk Delta Canary."
    ui_print " "
  fi
  FILE="$MAGISKTMP/mirror/*/etc/vintf/manifest.xml
        $MAGISKTMP/mirror/*/*/etc/vintf/manifest.xml
        /*/etc/vintf/manifest.xml /*/*/etc/vintf/manifest.xml"
  restore
fi

# patch hwservice contexts
FILE="$MAGISKTMP/mirror/*/etc/selinux/*_hwservice_contexts
      $MAGISKTMP/mirror/*/*/etc/selinux/*_hwservice_contexts
      /*/etc/selinux/*_hwservice_contexts
      /*/*/etc/selinux/*_hwservice_contexts"
if [ "`grep_prop dolby.skip.vendor $OPTIONALS`" != 1 ]\
&& ! grep -Eq 'u:object_r:hal_dms_hwservice:s0|u:object_r:default_android_hwservice:s0' $FILE; then
  FILE=$VENDOR/etc/selinux/vendor_hwservice_contexts
  patch_hwservice
fi
if [ "`grep_prop dolby.skip.system $OPTIONALS`" != 1 ]\
&& ! grep -Eq 'u:object_r:hal_dms_hwservice:s0|u:object_r:default_android_hwservice:s0' $FILE; then
  FILE=$SYSTEM/etc/selinux/plat_hwservice_contexts
  patch_hwservice
fi
if [ "`grep_prop dolby.skip.system_ext $OPTIONALS`" != 1 ]\
&& ! grep -Eq 'u:object_r:hal_dms_hwservice:s0|u:object_r:default_android_hwservice:s0' $FILE; then
  FILE=$SYSTEM_EXT/etc/selinux/system_ext_hwservice_contexts
  patch_hwservice
fi
if ! grep -Eq 'u:object_r:hal_dms_hwservice:s0|u:object_r:default_android_hwservice:s0' $FILE; then
  patch_hwservice_eim
  if [ $EIM == false ]; then
    ui_print "! Failed to set hal_dms_hwservice context."
    ui_print " "
  fi
  FILE="$MAGISKTMP/mirror/*/etc/selinux/*_hwservice_contexts
        $MAGISKTMP/mirror/*/*/etc/selinux/*_hwservice_contexts
        /*/etc/selinux/*_hwservice_contexts
        /*/*/etc/selinux/*_hwservice_contexts"
  restore
fi

# remount
remount_ro

# function
hide_oat() {
for APPS in $APP; do
  mkdir -p `find $MODPATH/system -type d -name $APPS`/oat
  touch `find $MODPATH/system -type d -name $APPS`/oat/.replace
done
}
replace_dir() {
if [ -d $DIR ]; then
  mkdir -p $MODDIR
  touch $MODDIR/.replace
fi
}
hide_app() {
DIR=$SYSTEM/app/$APPS
MODDIR=$MODPATH/system/app/$APPS
replace_dir
DIR=$SYSTEM/priv-app/$APPS
MODDIR=$MODPATH/system/priv-app/$APPS
replace_dir
DIR=$PRODUCT/app/$APPS
MODDIR=$MODPATH/system/product/app/$APPS
replace_dir
DIR=$PRODUCT/priv-app/$APPS
MODDIR=$MODPATH/system/product/priv-app/$APPS
replace_dir
DIR=$MY_PRODUCT/app/$APPS
MODDIR=$MODPATH/system/product/app/$APPS
replace_dir
DIR=$MY_PRODUCT/priv-app/$APPS
MODDIR=$MODPATH/system/product/priv-app/$APPS
replace_dir
DIR=$PRODUCT/preinstall/$APPS
MODDIR=$MODPATH/system/product/preinstall/$APPS
replace_dir
DIR=$SYSTEM_EXT/app/$APPS
MODDIR=$MODPATH/system/system_ext/app/$APPS
replace_dir
DIR=$SYSTEM_EXT/priv-app/$APPS
MODDIR=$MODPATH/system/system_ext/priv-app/$APPS
replace_dir
DIR=$VENDOR/app/$APPS
MODDIR=$MODPATH/system/vendor/app/$APPS
replace_dir
DIR=$VENDOR/euclid/product/app/$APPS
MODDIR=$MODPATH/system/vendor/euclid/product/app/$APPS
replace_dir
}
check_app() {
if [ "$BOOTMODE" == true ]\
&& [ "`grep_prop hide.parts $OPTIONALS`" == 1 ]; then
  for APPS in $APP; do
    FILE=`find $SYSTEM $PRODUCT $SYSTEM_EXT $VENDOR\
               $MY_PRODUCT -type f -name $APPS.apk`
    if [ "$FILE" ]; then
      ui_print "  Checking $APPS.apk"
      ui_print "  Please wait..."
      if grep -Eq $UUID $FILE; then
        ui_print "  Your $APPS.apk will be hidden"
        hide_app
      fi
    fi
  done
fi
}
detect_soundfx() {
if [ "$BOOTMODE" == true ]\
&& dumpsys media.audio_flinger | grep -Eq $UUID; then
  ui_print "- $NAME is detected."
  ui_print "  It may be conflicting with this module."
  ui_print "  You can type:"
  ui_print "  disable.dirac=1"
  ui_print "  inside $OPTIONALS"
  ui_print "  and reinstall this module if you want to disable it."
  ui_print " "
fi
}

# hide
APP="`ls $MODPATH/system/priv-app` `ls $MODPATH/system/app`"
hide_oat
APP="MusicFX MotoDolbyV3 MotoDolbyDax3 OPSoundTuner"
for APPS in $APP; do
  hide_app
done
if [ "`grep_prop disable.dirac $OPTIONALS`" != 0 ]\
&& [ "`grep_prop disable.misoundfx $OPTIONALS`" != 0 ]; then
  APP=MiSound
  for APPS in $APP; do
    hide_app
  done
fi
if [ "`grep_prop disable.dirac $OPTIONALS`" != 0 ]; then
  APP="Dirac DiracAudioControlService"
  for APPS in $APP; do
    hide_app
  done
fi

# dirac & misoundfx
FILE=$MODPATH/.aml.sh
APP="XiaomiParts ZenfoneParts ZenParts GalaxyParts
     KharaMeParts DeviceParts PocoParts"
NAME='dirac soundfx'
UUID=e069d9e0-8329-11df-9168-0002a5d5c51b
if [ "`grep_prop disable.dirac $OPTIONALS`" != 0 ]; then
  ui_print "- $NAME will be disabled"
  sed -i 's/#2//g' $FILE
  check_app
  ui_print " "
else
  detect_soundfx
fi
FILE=$MODPATH/.aml.sh
NAME=misoundfx
UUID=5b8e36a5-144a-4c38-b1d7-0002a5d5c51b
if [ "`grep_prop disable.misoundfx $OPTIONALS`" != 0 ]; then
  ui_print "- $NAME will be disabled"
  sed -i 's/#3//g' $FILE
  check_app
  ui_print " "
else
  if [ "$BOOTMODE" == true ]\
  && dumpsys media.audio_flinger | grep -Eq $UUID; then
    ui_print "- $NAME is detected."
    ui_print "  It may be conflicting with this module."
    ui_print "  You can type:"
    ui_print "  disable.misoundfx=1"
    ui_print "  inside $OPTIONALS"
    ui_print "  and reinstall this module if you want to disable it."
    ui_print " "
  fi
fi

# dirac_controller
FILE=$MODPATH/.aml.sh
NAME='dirac_controller soundfx'
UUID=b437f4de-da28-449b-9673-667f8b964304
if [ "`grep_prop disable.dirac $OPTIONALS`" != 0 ]; then
  ui_print "- $NAME will be disabled"
  ui_print " "
else
  detect_soundfx
fi

# dirac_music
FILE=$MODPATH/.aml.sh
NAME='dirac_music soundfx'
UUID=b437f4de-da28-449b-9673-667f8b9643fe
if [ "`grep_prop disable.dirac $OPTIONALS`" != 0 ]; then
  ui_print "- $NAME will be disabled"
  ui_print " "
else
  detect_soundfx
fi

# dirac_gef
FILE=$MODPATH/.aml.sh
NAME='dirac_gef soundfx'
UUID=3799D6D1-22C5-43C3-B3EC-D664CF8D2F0D
if [ "`grep_prop disable.dirac $OPTIONALS`" != 0 ]; then
  ui_print "- $NAME will be disabled"
  ui_print " "
else
  detect_soundfx
fi

# ui app
if [ "`grep_prop dolby.rc1 $OPTIONALS`" == 1 ]; then
  ui_print "- Using RC1 app..."
  APP="DaxUI daxService"
  ui_print " "
else
  APP=DolbyAtmos
fi
for APPS in $APP; do
  rm -rf `find $MODPATH/system -type d -name $APPS`
  hide_app
done

# stream mode
FILE=$MODPATH/.aml.sh
PROP=`grep_prop stream.mode $OPTIONALS`
if echo "$PROP" | grep -Eq m; then
  ui_print "- Activating music stream..."
  sed -i 's/#m//g' $FILE
  sed -i 's/musicstream=/musicstream=true/g' $MODPATH/acdb.conf
  ui_print " "
else
  APP=AudioFX
  for APPS in $APP; do
    hide_app
  done
fi
if echo "$PROP" | grep -Eq r; then
  ui_print "- Activating ring stream..."
  sed -i 's/#r//g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -Eq a; then
  ui_print "- Activating alarm stream..."
  sed -i 's/#a//g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -Eq s; then
  ui_print "- Activating system stream..."
  sed -i 's/#s//g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -Eq v; then
  ui_print "- Activating voice_call stream..."
  sed -i 's/#v//g' $FILE
  ui_print " "
fi
if echo "$PROP" | grep -Eq n; then
  ui_print "- Activating notification stream..."
  sed -i 's/#n//g' $FILE
  ui_print " "
fi

# settings
FILE=$MODPATH/system/vendor/etc/dolby/dap-default.xml
PROP=`grep_prop dolby.bass $OPTIONALS`
if [ "$PROP" == def ]; then
  ui_print "- Using default settings for bass enhancer"
elif [ "$PROP" == true ]; then
  ui_print "- Enable bass enhancer for all profiles"
  sed -i 's/bass-enhancer-enable value="false"/bass-enhancer-enable value="true"/g' $FILE
elif [ "$PROP" ] && [ "$PROP" != false ] && [ "$PROP" -gt 0 ]; then
  ui_print "- Enable bass enhancer for all profiles"
  sed -i 's/bass-enhancer-enable value="false"/bass-enhancer-enable value="true"/g' $FILE
  ui_print "- Changing bass enhancer boost values to $PROP for all profiles"
  ROW=`grep bass-enhancer-boost $FILE | sed 's/<bass-enhancer-boost value="0"\/>//p'`
  echo $ROW > $TMPDIR/test
  sed -i 's/<bass-enhancer-boost value="//g' $TMPDIR/test
  sed -i 's/"\/>//g' $TMPDIR/test
  ROW=`cat $TMPDIR/test`
  ui_print "  (Default values: $ROW)"
  for ROWS in $ROW; do
    sed -i "s/bass-enhancer-boost value=\"$ROWS\"/bass-enhancer-boost value=\"$PROP\"/g" $FILE
  done
else
  ui_print "- Disable bass enhancer for all profiles"
  sed -i 's/bass-enhancer-enable value="true"/bass-enhancer-enable value="false"/g' $FILE
fi
if [ "`grep_prop dolby.virtualizer $OPTIONALS`" == 1 ]; then
  ui_print "- Enable virtualizer for all profiles"
  sed -i 's/virtualizer-enable value="false"/virtualizer-enable value="true"/g' $FILE
elif [ "`grep_prop dolby.virtualizer $OPTIONALS`" == 0 ]; then
  ui_print "- Disable virtualizer for all profiles"
  sed -i 's/virtualizer-enable value="true"/virtualizer-enable value="false"/g' $FILE
fi
if [ "`grep_prop dolby.volumeleveler $OPTIONALS`" == def ]; then
  ui_print "- Using default volume leveler settings"
elif [ "`grep_prop dolby.volumeleveler $OPTIONALS`" == 1 ]; then
  ui_print "- Enable volume leveler for all profiles"
  sed -i 's/volume-leveler-enable value="false"/volume-leveler-enable value="true"/g' $FILE
else
  ui_print "- Disable volume leveler for all profiles"
  sed -i 's/volume-leveler-enable value="true"/volume-leveler-enable value="false"/g' $FILE
fi
if [ "`grep_prop dolby.deepbass $OPTIONALS`" != 0 ]; then
  ui_print "- Using deeper bass GEQ frequency"
  sed -i 's/frequency="47"/frequency="0"/g' $FILE
  sed -i 's/frequency="141"/frequency="47"/g' $FILE
  sed -i 's/frequency="234"/frequency="141"/g' $FILE
  sed -i 's/frequency="328"/frequency="234"/g' $FILE
  sed -i 's/frequency="469"/frequency="328"/g' $FILE
  sed -i 's/frequency="656"/frequency="469"/g' $FILE
  sed -i 's/frequency="844"/frequency="656"/g' $FILE
  sed -i 's/frequency="1031"/frequency="844"/g' $FILE
  sed -i 's/frequency="1313"/frequency="1031"/g' $FILE
  sed -i 's/frequency="1688"/frequency="1313"/g' $FILE
  sed -i 's/frequency="2250"/frequency="1688"/g' $FILE
  sed -i 's/frequency="3000"/frequency="2250"/g' $FILE
  sed -i 's/frequency="3750"/frequency="3000"/g' $FILE
  sed -i 's/frequency="4688"/frequency="3750"/g' $FILE
  sed -i 's/frequency="5813"/frequency="4688"/g' $FILE
  sed -i 's/frequency="7125"/frequency="5813"/g' $FILE
  sed -i 's/frequency="9000"/frequency="7125"/g' $FILE
  sed -i 's/frequency="11250"/frequency="9000"/g' $FILE
  sed -i 's/frequency="13875"/frequency="11250"/g' $FILE
  sed -i 's/frequency="19688"/frequency="13875"/g' $FILE
fi
ui_print " "

# audio rotation
FILE=$MODPATH/service.sh
if [ "`grep_prop audio.rotation $OPTIONALS`" == 1 ]; then
  ui_print "- Activating ro.audio.monitorRotation=true"
  sed -i '1i\
resetprop ro.audio.monitorRotation true' $FILE
  ui_print " "
fi

# raw
FILE=$MODPATH/.aml.sh
if [ "`grep_prop disable.raw $OPTIONALS`" == 0 ]; then
  ui_print "- Not disabling Ultra Low Latency playback (RAW)"
  ui_print " "
else
  sed -i 's/#u//g' $FILE
fi

# other
FILE=$MODPATH/service.sh
if [ "`grep_prop other.etc $OPTIONALS`" == 1 ]; then
  ui_print "- Activating other etc files bind mount..."
  sed -i 's/#p//g' $FILE
  ui_print " "
fi

# function
file_check_vendor() {
for NAMES in $NAME; do
  if [ "$IS64BIT" == true ]; then
    FILE=$VENDOR/lib64/$NAMES
    FILE2=$ODM/lib64/$NAMES
    if [ -f $FILE ] || [ -f $FILE2 ]; then
      ui_print "- Detected $NAMES 64"
      ui_print " "
      rm -f $MODPATH/system/vendor/lib64/$NAMES
    fi
  fi
  FILE=$VENDOR/lib/$NAMES
  FILE2=$ODM/lib/$NAMES
  if [ -f $FILE ] || [ -f $FILE2 ]; then
    ui_print "- Detected $NAMES"
    ui_print " "
    rm -f $MODPATH/system/vendor/lib/$NAMES
  fi
done
}

# check
NAME="libstagefrightdolby.so
      libstagefright_soft_ddpdec.so"
file_check_vendor

# permission
ui_print "- Setting permission..."
FILE=`find $MODPATH/system/vendor/bin\
           $MODPATH/system/vendor/odm/bin\
           $MODPATH/system/odm/bin -type f`
for FILES in $FILE; do
  chmod 0755 $FILES
done
chmod 0751 $MODPATH/system/vendor/bin
chmod 0751 $MODPATH/system/vendor/bin/hw
chmod 0755 $MODPATH/system/vendor/odm/bin
chmod 0755 $MODPATH/system/vendor/odm/bin/hw
chmod 0755 $MODPATH/system/odm/bin
chmod 0755 $MODPATH/system/odm/bin/hw
DIR=`find $MODPATH/system/vendor -type d`
for DIRS in $DIR; do
  chown 0.2000 $DIRS
done
FILE=`find $MODPATH/system/vendor/bin\
           $MODPATH/system/vendor/odm/bin -type f`
for FILES in $FILE; do
  chown 0.2000 $FILES
done
ui_print " "

# vendor_overlay
DIR=/product/vendor_overlay
if [ -d $DIR ]; then
  ui_print "- Fixing $DIR mount..."
  cp -rf $DIR/*/* $MODPATH/system/vendor
  ui_print " "
fi

# uninstaller
NAME=DolbyUninstaller.zip
cp -f $MODPATH/$NAME /sdcard
rm -f $MODPATH/$NAME
ui_print "- Flash /sdcard/$NAME"
ui_print "  via recovery if you got bootloop"
ui_print " "









