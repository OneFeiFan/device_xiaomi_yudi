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

userdata 使用 FBE v2（`inlinecrypt_optimized` 加 `wrappedkey_v0` 硬件包装密钥），并开启了 metadata 加密。解密依赖原厂的 qseecomd、Keymaster 4.1、KeyMint 和 Gatekeeper，启动顺序写在 `init.recovery.qcom.rc`：启动 qseecomd，等它注册完监听器后，再启动其他服务。RPMB 节点权限由 `vendor/etc/ueventd.rc` 在启动早期设为 `0660 system system`，init 里不再重复设置。

Android 的锁屏凭据分图案、PIN 和文本密码三类；纯数字的密码在系统里就是 PIN，recovery 日志会显示 `password type: PIN`。三类都走 synthetic password + Gatekeeper 验证，图案、4 位 PIN、文本密码和多用户都已实测。

### 用户和凭据

recovery 按用户解密，不是只处理 user 0：

- **普通用户/默认密码**：user 0 使用输入的密码或默认密码解密；其他没有独立密码、或与 user 0 使用同一密码的用户，会在 user 0 成功后自动尝试解密。
- **独立密码用户**：不会用 user 0 的密码自动解开；需要提供该用户自己的密码。
- **统一锁屏的 profile**（clone profile、managed profile，例如 XSpace、平行空间）：没有自己的锁屏凭据，只有 `gatekeeper.profile.key`。父用户认证通过后，recovery 用 keystore2 解出 profile key 派生的随机密码，再按普通 synthetic password 流程解密该用户；父用户没有解密时不会尝试。

凭据的处理要分情况：

- **user 0** 的 Gatekeeper/Keystore、`locksettings.db`、`spblob` 始终被 `ExcludeAll()` 排除。TWRP 的普通双清**不会主动删除这些凭据文件**，所以不能保证旧锁屏被清除；这和 Android 原厂“恢复出厂设置会清掉锁屏”的逻辑不同。想得到原厂那种效果，必须用 Format Data。只有 Format Data 或换机后恢复，才需要重设 user 0 锁屏。
- **非 0 用户**（独立密码用户、clone profile）的凭据在正常解密路径下不会被排除。普通双清会删掉它们，恢复时如果有备份就写回备份里的版本；备份之后改过密码会导致恢复后的凭据对不上，需要重设。
- 依赖 keystore 的应用在凭据丢失后可能需要重新登录。

这些行为来自 TWRP 的 `ExcludeAll()` 设计，不是恢复失败。

recovery 没有 SPU，高通 Gatekeeper 默认会先尝试 SPU，`verify_legacy` 返回 `-45`，图案、PIN 和文本密码都会验证失败。没有锁屏密码时不受影响，因为默认密码不经过 Gatekeeper。`init.recovery.qcom.rc` 在启动时设置 `vendor.gatekeeper.disable_spu true`，让 Gatekeeper 走普通 TEE；不要删除这一行。

输入图案、PIN 或文本密码后，recovery 先用 scrypt 派生 password token，再通过 Gatekeeper 验证，最后解开 synthetic password。当前 PIN 的 scrypt 参数是 N=2048、r=8、p=2，整个过程约 2–3 秒；没有锁屏密码时 TWRP 直接使用 `default-password`，跳过 scrypt 和 Gatekeeper，所以几乎是立即解密。这个等待是正常开销，不是卡死。

厂商的 KeyMint 库会读取版本和安全补丁属性，判断密钥是否需要升级。当前 recovery 的实际值是：

| 属性 | recovery 实际值 |
| --- | --- |
| `ro.build.version.release` | 12 |
| `ro.build.version.release_or_codename` | 16 |
| `ro.build.version.security_patch` | 2026-08-01 |
| `ro.vendor.build.security_patch` | 2026-02-01 |

系统侧 `ro.build.version.release` 是 16，`release_or_codename` 也是 16；其他两项相同。当前 recovery 的 `release` 是 12（Android 16 的兼容值），实测这组值可以解密。换用其他版本的 ROM 时，先对齐 security patch 和 vendor patch；如果解密失败，再检查 `release` 和 `release_or_codename`。实测 recovery 的安全补丁高于系统时，KeyMint 返回 `-62`（`KEY_REQUIRES_UPGRADE`），解密失败，所以不要凭经验调高。

## 电池、充电和温度

TWRP 直接读取 `/sys/class/power_supply/battery`，状态栏显示电量和充电状态。电池驱动的数据来自 ADSP，所以开机时先从 modem 分区链接 ADSP 固件，再启动 ADSP。

ramdisk 里还有原厂的 health HIDL 服务。它不是给电量显示用的，而是 fastbootd 启动时需要，见下文。

CPU 温度读取 `/sys/class/thermal/thermal_zone27/temp`（cpuss-2）。

## 震动

使用 ROM 自带的小米震动 HAL，实例是 `IVibrator/vibratorfeature`。

这个 HAL 是 Android 12 的二进制，在 Android 16 的 libutils 下创建线程时会因引用计数检查而崩溃。为此，ramdisk 里放了一份改名为 `libu32.so` 的 Android 12 版 libutils，并把震动服务的依赖从 `libutils.so` 改成了它。两处修改都记录在专有文件清单的"已修改文件"一节。

## ADB、MTP 和 USB Storage

ADB 和 MTP 都走 configfs。ADB 在 recovery 启动后自动可用；MTP 由 `tw_mtp_enabled` 控制，默认设置为开启，把 `/data/media/0` 导出为 Internal Storage。如果 Windows 没有立即出现设备，可以在“挂载”页手动开关一次 MTP，不需要重启 recovery。

USB Storage 已在设备树里关闭（`vendorsetup.sh` 的 `OF_ENABLE_USB_STORAGE=0`）。这台设备只有一个 USB-C 口，无法同时接 OTG 存储和电脑；TWRP 的 USB Storage 又只导出可移动存储，不导出内部 `/data/media`，实际不可用。文件传输使用 MTP。

格式化 data 或擦 metadata 前，recovery 会先停 MTP。MTP 会一直打开 `/data/media`，不停掉时 dm-userdata 处于 busy，`dmctl delete userdata` 和 `make_f2fs` 会失败；格式化结束后会按原来的状态恢复 MTP。

## 刷入 zip、备份和恢复

“安装”页可以刷入 zip。备份和恢复支持 boot、dtbo、modem、persist、recovery、vendor_boot、data、super 等分区，目标可以是内部存储或 USB OTG。

data 备份排除 `/data/media`（内部存储/照片/下载）。要备份这些内容，需要单独选择 Internal Storage，并把备份文件另外保存到电脑或 OTG 硬盘，因为 Format Data 会清空内部存储。

data 备份是解密后的文件。恢复后普通文件和应用数据可以读回；凭据是否保留见前面的“用户和凭据”。

OrangeFox 的 `OF_WORKAROUND_BACKUP_BUG` 会排除 `/data/data`，但应用数据在 recovery 里的路径是 `/data/user/0/<包名>/`，备份会从这条路径遍历，所以应用数据并没有丢。检查备份时不要只看 `/data/data`，可以用下面的命令确认：

```sh
for f in /sdcard/Fox/BACKUPS/<serialno>/<备份名>/data.f2fs.win[0-9]*; do
    tar -tf "$f"
done | grep '^/data/user/0/' | head
```

之前 restore 报 `extractTarFork() 255`，常见原因是部分 root 模块给 `/data/system/cloudFeature_*.xml` 之类的文件加了 immutable/append 标志，恢复时无法覆盖。补丁 0002 会先清掉这些标志再删除/覆盖；如果仍失败，改用 Format Data。

## 双清和 Format Data

普通双清（Data + Cache/Dalvik）使用 `Wipe_Data_Without_Wiping_Media`，会递归删除 `/data` 下除 `/data/media` 之外的内容，**不会删除照片、下载等内部存储文件**。

普通双清是逐个文件删除。补丁 0002 会先清掉 immutable/append 标志再重试；如果仍然无法 `unlink()`/`rmdir()`（不是 `/data/user/0` 这类挂载点，也不是预期的排除目录），recovery 会**中止并报错**，此时 `/data` 可能只清了一部分。遇到这种情况不要继续普通双清，改用 Format Data 整分区格式化。

Format Data，或者在高级清除里同时勾选 metadata，会走整分区格式化（`make_f2fs /dev/block/sda35`），`/data/media` 也会被清空。metadata 是 data 的加密密钥：只擦 metadata 而不格式化 data 会留下没有密钥的密文 userdata，重启后表现为 `Magic Mismatch`、系统无法开机；recovery 已改为在擦 metadata 前先格式化 data，并在格式化前停 MTP。格式化完成后需要重启系统，让系统重新建立加密。

## ADB sideload

在 OrangeFox 的菜单里进入 ADB sideload，或者在终端执行 `fox sideload start`，然后在电脑上运行 `adb sideload <zip>`。退出后 ADB 会自动恢复，MTP 不会，见 [已知问题](known-issues.md#sideload-后-mtp-不会自动恢复)。

## fastbootd

fastbootd 启动时会先查找 health 服务，找不到就一直重试，走不到 USB 初始化。ramdisk 里的原厂 health HIDL 服务就是为此准备的。进入 fastbootd 后，设备在电脑上显示为 `18d1:4ee0`。

Windows 需要为这个设备安装 Google USB 驱动（`android_winusb.inf`），否则设备管理器显示代码 28，`fastboot devices` 看不到设备。Linux 不需要额外驱动。

## 主题和中文字体

OrangeFox 的中文语言包会把终端和键盘字体换成比例字体，导致等宽错乱。设备树在 `recovery/root/twres/` 下覆盖了语言包，把终端字体和键盘长按标签的字体指向 Sarasa Mono SC。

字体使用 GBK 子集，约 2.2 万个字符，12.8 MB。超出 GBK 的生僻字会显示成方块。

主题覆盖文件在构建时直接写入 `/twres`。启动后默认显示“高级”页。

列表项在每次页面获得焦点时重新解析翻译，所以双清/格式化后“高级”页的按钮不会停留在英文，不需要重启 recovery。

## 设置持久化

设置保存在 `/sdcard/Fox/.foxs`，并在 `/persist/.foxs` 留一份备份。部分设置项不在 OrangeFox 的默认持久化列表里，需要 [补丁](../patches/README.md) 才能在重启后保留。

`/data` 的挂载参数实际来自 vendor 分区的 fstab：TWRP 把它作为 `additional.fstab` 读入，覆盖主 `recovery.fstab` 的 `/data` 行。目前挂载后带 `checkpoint_merge` 和 `fsync_mode=nobarrier`，没有 `checkpoint=disable`。如果某次挂载后出现 `checkpoint=disable`（系统刚装完更新、尚未确认启动成功时可能如此），写入要等卸载时才落盘，异常重启会丢失。

## 禁用 vbmeta AVB2.0

`vendorsetup.sh` 打开了 `OF_SUPPORT_VBMETA_AVB2_PATCHING`，设置、高级和安装页会出现“禁用 vbmeta AVB2.0”。它修改 `vbmeta_a/b` 和 `vbmeta_system_a/b` 的标志位，默认不会自动执行。

## USB OTG

`twrp.flags` 里的 `/usb_otg` 指向 `/dev/block/sdg1`，备用节点是 `/dev/block/sdg`：UFS 占用了 sda 到 sdf，OTG 设备通常是下一个。如果实际节点不同，以 `/tmp/recovery.log` 为准修改。NTFS 分区通过系统自带的 `mount.ntfs`（ntfs-3g）挂载。

OTG host 模式由两条 init 标记保护：

- `sys.usb.mode_ready`：只在第一次进入 device 状态时写一次 `mode peripheral`，后续 MTP 配置变化不再改 mode；
- `sys.usb.otg_active`：`Check_UsbOtg_Status()` 在挂载 OTG 时置 1，卸载时置 0。OTG 活动期间关闭 MTP 不会把 host 踢回 device；卸载后 init 立即写回 peripheral，ADB 和 MTP 不用等 UCSI 自己恢复。

`Check_UsbOtg_Status()` 默认只检查 `sdg1`/`sdg` 这两个节点。如果扩展坞枚举成其他名字，自动挂载不会触发，需要同时修改 `twrp.flags` 和 `partitionmanager.cpp` 里的检查路径。
