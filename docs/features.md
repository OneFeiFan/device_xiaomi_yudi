# 功能说明

## 启动与 A/B 槽位

recovery 不带内核，由引导程序用 boot 分区的内核启动。设备有独立的 `recovery_a` 和 `recovery_b` 分区，两个槽位刷入同一镜像都能启动。

boot 控制使用原厂 vendor 的 HIDL 1.2 boot HAL，服务名是 `vendor.boot-hal-1-2`。读取当前槽位和切换槽位在“重启”菜单里完成。当前这台设备的 b 槽 super 是空的，切到 b 会落到 fastboot，见[已知问题](known-issues.md#另一槽没有系统时切槽会落到-fastboot)。

## 触摸

面板原生是 2880x1800 横屏。OrangeFox 旋转 270 度显示为 1800x2880 竖屏。触摸驱动的坐标系与竖屏画面一致，不需要 SWAP 或 FLIP 参数。

触控驱动是 `nt36532_touch.ko` 和 `xiaomi_touch.ko`。当前槽的 vendor_dlkm 有模块时由 TWRP 加载。vendor_dlkm 为空时，`/system/bin/beforemodules.sh` 从 ramdisk 的 `/lib/modules` 补载。

## 解密

userdata 使用 FBE v2（`inlinecrypt_optimized` 加 `wrappedkey_v0`）和 metadata 加密。解密依赖原厂的 qseecomd、Keymaster 4.1、KeyMint 和 Gatekeeper。服务启动顺序写在 `init.recovery.qcom.rc`。

recovery 的 `ro.build.version.release`、`ro.build.version.security_patch` 和 `ro.vendor.build.security_patch` 必须与当前系统一致：release 16、security patch 2026-08-01、vendor patch 2026-02-01。厂商库用这些值判断 metadata key 是否需要升级。更换 ROM 后如果不一致，解密会失败。

默认密码场景已经实机验证。自定义锁屏密码和多用户解密还没有验证。

## 电池、充电和温度

recovery 里没有 AIDL health 服务时，TWRP 直接读 `/sys/class/power_supply/battery`，状态栏显示电量和充电状态。设备树同时打包了原厂的 health HIDL 服务，fastbootd 启动时需要它。

CPU 温度读 `/sys/class/thermal/thermal_zone27/temp`（cpuss-2）。

## 震动

震动 HAL 是 ROM 自带的 AIDL 服务，实例为 `IVibrator/vibratorfeature`。服务常驻并注册成功。马达的实际触感还没有确认。

## ADB、MTP 和 USB Storage

ADB 在 recovery 启动后自动可用，不需要拔插 USB。

MTP 在开机时自动启用，把 `/data/media/0` 导出为 Internal Storage。Windows 与平板双向复制文件已经验证。进入 sideload 后 MTP 不会自动恢复，见[已知问题](known-issues.md#sideload-后-mtp-不会自动恢复)。

USB Storage 走 configfs 的 `mass_storage.0`。退出 USB Storage 后，主题覆盖会重新启动 MTP。电脑端的 USB Storage 读写还没有验证。

`vendorsetup.sh` 里的 `OF_ENABLE_USB_STORAGE=1` 在 `orangefox.mk` 里使用。这个值不等于 1 时会定义 `TW_NO_USB_STORAGE`。

## 卡刷、备份和恢复

“安装”页可以刷入 zip。已经用一个只写测试文件的 zip 验证过 update-binary 会执行。

备份和恢复支持 boot、dtbo、modem、persist、recovery、vendor_boot、data、super 等分区，目标可以是内部存储或 USB OTG。boot 分区做过端到端验证：备份 192MB，恢复后分区 sha256 与备份前一致。

## ADB sideload

在终端执行 `fox sideload start`，然后在电脑上运行 `adb sideload <zip>`。已经验证 zip 能收到并执行，sideload 退出后 adb 会自动恢复。

## fastbootd

fastbootd 启动时会先查 health 服务。设备树打包了原厂的 health HIDL 服务并在启动时拉起，USB 初始化能正常进行。设备在 fastbootd 模式下枚举为 `18d1:4ee0`。

Windows 需要为这个 USB 设备安装 Google USB 驱动（`android_winusb.inf`）。没有驱动时，设备管理器显示代码 28，`fastboot devices` 看不到设备。Linux 不需要额外驱动。

## 主题和中文字体

中文语言包 `zh_CN.xml` 会把终端和键盘字体替换成比例字体，导致等宽错乱。设备树在 `recovery/root/twres/` 下覆盖了语言包，把 `keylabel-longpress` 和 `fixed` 指向 Sarasa Mono SC。

字体使用 GBK 子集，约 2.2 万个字符，文件 12.8MB。超出 GBK 范围的生僻字在文件名里会显示成方块。

主题覆盖文件在构建时直接覆盖 `/twres`，不在开机时复制。启动页是“高级”tab。

## 设置持久化

设置保存在 `/sdcard/Fox/.foxs`，并在 `/persist/.foxs` 留一份备份。部分设置变量不在默认持久化表里，主题勾选写值需要 `persist=1`。补丁见 [patches/README.md](../patches/README.md)。

`/data` 的实际挂载参数来自 vendor 分区的 fstab（`additional.fstab`）。当前 `/proc/mounts` 里是 `checkpoint_merge` 和 `fsync_mode=nobarrier`，没有 `checkpoint=disable`。改主 `recovery.fstab` 不会改变 `nobarrier` 这类选项。

写入耐久性在正常重启和异常重启下都测过：写文件并 `sync` 后用 SysRq 强制重启，文件仍然存在。vendor fstab 的 `/data` 行带 `checkpoint=fs`，但 TWRP 实际挂载后没有禁用检查点。

## AVB2.0 菜单

设置、高级和安装页会出现“禁用 vbmeta AVB2.0”。它修改 `vbmeta_a/b` 和 `vbmeta_system_a/b` 的 flags，默认不自动执行。实际执行还没有验证。

## USB OTG

`twrp.flags` 里的 `/usb_otg` 负责 OTG。接真实设备的读写还没有验证。

## 分区管理

修复、调整大小、更改文件系统和格式化 data 还没有做破坏性测试。
