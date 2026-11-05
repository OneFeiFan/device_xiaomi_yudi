# 功能说明

本文说明每个功能的工作方式和限制。各功能验证到了什么程度，以 [README 的功能状态表](../README.md#功能状态) 为准。

## 启动与 A/B 槽位

recovery 镜像不带内核，由引导程序用 boot 分区的内核启动，和原厂 recovery 相同。设备有独立的 `recovery_a` 和 `recovery_b` 分区，两个槽位可以刷入同一个镜像。

槽位由原厂 vendor 的 HIDL 1.2 boot HAL 管理（服务名 `vendor.boot-hal-1-2`）。在“重启”菜单里可以查看和切换槽位。切换之前，要确认目标槽位装有系统，否则会停在 fastboot，见 [已知问题](known-issues.md#另一槽没有系统时切槽会停在-fastboot)。

## 触摸

面板原生是 2880×1800 的横屏。OrangeFox 只有竖屏界面，所以旋转 270 度显示为 1800×2880，和系统的自然方向一致。触摸芯片报告的坐标本来就是竖屏方向，不需要设置任何交换或翻转参数。

触摸驱动是 `nt36532_touch.ko` 和 `xiaomi_touch.ko`，它们不在 vendor_boot 的 recovery 模块列表里，需要 recovery 自己加载：
- 当前槽位的 vendor_dlkm 里有这两个模块时，由 TWRP 从 vendor_dlkm 加载；
- vendor_dlkm 为空时，`/system/bin/beforemodules.sh` 从 ramdisk 的 `/lib/modules` 加载。

触摸固件放在 ramdisk 的 `/lib/firmware`。

## 解密

userdata 使用 FBE v2（`inlinecrypt_optimized` 加 `wrappedkey_v0` 硬件包装密钥），并开启了 metadata 加密。解密依赖原厂的 qseecomd、Keymaster 4.1、KeyMint 和 Gatekeeper，启动顺序写在 `init.recovery.qcom.rc`：先设置 RPMB 节点权限，再启动 qseecomd，等它注册完监听器后，再启动其他服务。

厂商的 KeyMint 库会读取下面三个属性，判断密钥是否需要升级。recovery 里的值必须与当前系统完全一致：

| 属性 | 当前值 |
| --- | --- |
| `ro.build.version.release` | 16 |
| `ro.build.version.security_patch` | 2026-08-01 |
| `ro.vendor.build.security_patch` | 2026-02-01 |

这三个值写在 `BoardConfig.mk` 里，对应 OS3.0.306.3。换用其他版本的 ROM 时，从新系统的 `/system/build.prop` 和 `/vendor/build.prop` 读出对应的值，改好后重新构建。实测 recovery 的值高于系统时，KeyMint 返回 `-62`（`KEY_REQUIRES_UPGRADE`），解密失败；值必须与系统一致，不要凭经验调高或调低。

## 电池、充电和温度

TWRP 直接读取 `/sys/class/power_supply/battery`，状态栏显示电量和充电状态。电池驱动的数据来自 ADSP，所以开机时先从 modem 分区链接 ADSP 固件，再启动 ADSP。

ramdisk 里还有原厂的 health HIDL 服务。它不是给电量显示用的，而是 fastbootd 启动时需要，见下文。

CPU 温度读取 `/sys/class/thermal/thermal_zone27/temp`（cpuss-2）。

## 震动

使用 ROM 自带的小米震动 HAL，实例是 `IVibrator/vibratorfeature`。

这个 HAL 是 Android 12 的二进制，在 Android 16 的 libutils 下创建线程时会因引用计数检查而崩溃。为此，ramdisk 里放了一份改名为 `libu32.so` 的 Android 12 版 libutils，并把震动服务的依赖从 `libutils.so` 改成了它。两处修改都记录在专有文件清单的"已修改文件"一节。

## ADB、MTP 和 USB Storage

ADB 和 MTP 在 recovery 启动后自动可用。MTP 把 `/data/media/0` 导出为 Internal Storage。

USB Storage 通过 configfs 的 `mass_storage.0` 实现，在“挂载”页启用。退出 USB Storage 后，MTP 会自动重新启用。

`vendorsetup.sh` 里的 `OF_ENABLE_USB_STORAGE=1` 由 OrangeFox 的 `orangefox.mk` 读取，不为 1 时会关闭 USB Storage 功能。

## 刷入 zip、备份和恢复

“安装”页可以刷入 zip。备份和恢复支持 boot、dtbo、modem、persist、recovery、vendor_boot、data、super 等分区，目标可以是内部存储或 USB OTG。

data 使用文件级加密，备份能否正确恢复，取决于设备上是否仍是同一套加密密钥。格式化 data 或换机后，旧的 data 备份通常无法正确恢复。

## ADB sideload

在 OrangeFox 的菜单里进入 ADB sideload，或者在终端执行 `fox sideload start`，然后在电脑上运行 `adb sideload <zip>`。退出后 ADB 会自动恢复，MTP 不会，见 [已知问题](known-issues.md#sideload-后-mtp-不会自动恢复)。

## fastbootd

fastbootd 启动时会先查找 health 服务，找不到就一直重试，走不到 USB 初始化。ramdisk 里的原厂 health HIDL 服务就是为此准备的。进入 fastbootd 后，设备在电脑上显示为 `18d1:4ee0`。

Windows 需要为这个设备安装 Google USB 驱动（`android_winusb.inf`），否则设备管理器显示代码 28，`fastboot devices` 看不到设备。Linux 不需要额外驱动。

## 主题和中文字体

OrangeFox 的中文语言包会把终端和键盘字体换成比例字体，导致等宽错乱。设备树在 `recovery/root/twres/` 下覆盖了语言包，把终端字体和键盘长按标签的字体指向 Sarasa Mono SC。

字体使用 GBK 子集，约 2.2 万个字符，12.8 MB。超出 GBK 的生僻字会显示成方块。

主题覆盖文件在构建时直接写入 `/twres`。启动后默认显示“高级”页。

## 设置持久化

设置保存在 `/sdcard/Fox/.foxs`，并在 `/persist/.foxs` 留一份备份。部分设置项不在 OrangeFox 的默认持久化列表里，需要 [补丁](../patches/README.md) 才能在重启后保留。

`/data` 的挂载参数实际来自 vendor 分区的 fstab：TWRP 把它作为 `additional.fstab` 读入，覆盖主 `recovery.fstab` 的 `/data` 行。目前挂载后带 `checkpoint_merge` 和 `fsync_mode=nobarrier`，没有 `checkpoint=disable`。如果某次挂载后出现 `checkpoint=disable`（系统刚装完更新、尚未确认启动成功时可能如此），写入要等卸载时才落盘，异常重启会丢失。

## 禁用 vbmeta AVB2.0

`vendorsetup.sh` 打开了 `OF_SUPPORT_VBMETA_AVB2_PATCHING`，设置、高级和安装页会出现“禁用 vbmeta AVB2.0”。它修改 `vbmeta_a/b` 和 `vbmeta_system_a/b` 的标志位，默认不会自动执行。

## USB OTG

`twrp.flags` 里的 `/usb_otg` 指向 `/dev/block/sdg1`：UFS 占用了 sda 到 sdf，OTG 设备通常是下一个。如果实际节点不同，以 `/tmp/recovery.log` 为准修改。
