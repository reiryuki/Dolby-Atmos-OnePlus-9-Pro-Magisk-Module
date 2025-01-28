# Dolby Atmos OnePlus 9 Pro Magisk Module

## DISCLAIMER
- OnePlus & Dolby apps and blobs are owned by OnePlus™ & Dolby™.
- The MIT license specified here is for the Magisk Module only, not for OnePlus & Dolby apps and blobs.

## Descriptions
- Equalizer sound effect ported from OnePlus 9 Pro (OnePlus9Pro) and integrated as a Magisk Module for all supported and rooted devices with Magisk
- Global type sound effect
- Conflicted with `vendor.dolby.hardware.dms@2.0-service` & `vendor.dolby_sp.hardware.dmssp@2.0-service`

## Sources
- https://dumps.tadiphone.dev/dumps/oneplus/oneplus9pro qssi-user-13-TP1A.220905.001-1698121073735-release-keys--IN
- libsqlite.so: https://dumps.tadiphone.dev/dumps/zte/p855a01 msmnile-user-11-RKQ1.201221.002-20211215.223102-release-keys
- libhidlbase.so: CrDroid ROM Android 13
- libmagiskpolicy.so: Kitsune Mask R6687BB53

## Screenshots
- https://t.me/androidryukimods/1612

## Requirements
- arm64-v8a architecture
- Android 11 (SDK 30) and up
- Magisk or KernelSU installed (Recommended to use Magisk Delta/Kitsune Mask for systemless early init mount manifest.xml if your ROM is Read-Only https://t.me/ryukinotes/49)
- OPlus Core Magisk Module installed in non-OPlus ROM https://github.com/reiryuki/OPlus-Core-Magisk-Module

## WARNING!!!
- Possibility of bootloop or even softbrick or a service failure on Read-Only ROM if you don't use Magisk Delta/Kitsune Mask.

## Installation Guide & Download Link
- Recommended to use Magisk Delta/Kitsune Mask https://t.me/ryukinotes/49
- Install OPlus Core Magisk Module first if you are in non-OPlus ROM: https://github.com/reiryuki/OPlus-Core-Magisk-Module
- Install this module https://www.pling.com/p/2110036/ via Magisk app or KernelSU app or Recovery if Magisk installed
- Install AML Magisk Module https://t.me/ryukinotes/34 only if using any other else audio mod module
- If you are using KernelSU, you need to disable Unmount Modules by Default in KernelSU app settings
- Reboot
- If you are using KernelSU, you need to allow superuser list manually all package name listed in package.txt (and your home launcher app also) (enable show system apps) and reboot afterwards
- If you are using SUList, you need to allow list manually your home launcher app (enable show system apps) and reboot afterwards
- If you have an issue with your in-built Spatial Audio, then install AOSP Sound Effects Remover also: https://github.com/reiryuki/AOSP-soundfx-Remover-Magisk-Module
- If you have sensors issue (fingerprint, proximity, gyroscope, etc), then READ Optionals bellow!

## Optionals
- https://t.me/ryukinotes/8
- Global: https://t.me/ryukinotes/35
- Stream: https://t.me/ryukinotes/52

## Troubleshootings
- https://t.me/ryukinotes/10
- https://t.me/ryukinotes/11
- Global: https://t.me/ryukinotes/34

## Support & Bug Report
- https://t.me/ryukinotes/54
- If you don't do above, issues will be closed immediately

## Credits and Contributors
- @HuskyDG
- https://t.me/viperatmos
- https://t.me/androidryukimodsdiscussions
- @HELLBOY017
- You can contribute ideas about this Magisk Module here: https://t.me/androidappsportdevelopment

## Sponsors
- https://t.me/ryukinotes/25


