# 功能说明

本文说明每个功能的工作方式和限制。各功能验证到了什么程度，以 [README 的功能状态表](../README.md#功能状态) 为准；测试方法见[验证清单](verification.md)。

## 启动与 A/B 槽位

recovery 镜像不带内核，由引导程序用 boot 分区的内核启动，和原厂 recovery 相同。设备有独立的 `recovery_a` 和 `recovery_b` 分区，两个槽位可以刷入同一个镜像。

槽位由原厂 vendor 的 HIDL 1.2 boot HAL 管理（服务名 `vendor.boot-hal-1-2`）。在“重启”菜单里可以查看和切换槽位。切换前要确认目标槽位装有系统，否则会停在 fastboot，见[已知问题](known-issues.md#另一槽没有系统时切槽会停在-fastboot)。

## 触摸

面板原生是 2880×1800 的横屏。OrangeFox 只有竖屏界面，所以旋转 270 度显示为 1800×2880，和系统的自然方向一致。触摸芯片报告的坐标本来就是竖屏方向，不需要设置交换或翻转参数。

触摸驱动是 `nt36532_touch.ko` 和 `xiaomi_touch.ko`，它们不在 vendor_boot 的 recovery 模块列表里，需要 recovery 自己加载：当前槽位的 vendor_dlkm 里有这两个模块时，由 TWRP 从 vendor_dlkm 加载；vendor_dlkm 为空时，由 `/system/bin/beforemodules.sh` 从 ramdisk 的 `/lib/modules` 加载。触摸固件放在 ramdisk 的 `/lib/firmware`。

## 解密

userdata 使用 FBE v2（`inlinecrypt_optimized` 加 `wrappedkey_v0` 硬件包装密钥），并开启了 metadata 加密。解密依赖原厂的 qseecomd、Keymaster 4.1、KeyMint 和 Gatekeeper：`init.recovery.qcom.rc` 先启动 qseecomd，等它注册完监听器后再启动其他服务。KeyMint 的抗回滚状态存放在 UFS 的 RPMB 里，RPMB 节点的权限由 `vendor/etc/ueventd.rc` 设为 `0660 system system`。

recovery 里没有 SPU。高通 Gatekeeper 默认先尝试 SPU，会使 `verify_legacy` 返回 `-45`，所以 `init.recovery.qcom.rc` 在启动时设置 `vendor.gatekeeper.disable_spu true`，让它直接走 TEE。不要删除这一行。

### 凭据和用户

图案、PIN 和文本密码都要先用 scrypt 派生，再交给 Gatekeeper 验证，然后解开 synthetic password，整个过程约 2 到 3 秒，期间界面看起来像卡住，这是正常的。纯数字密码在系统里就是 PIN，日志显示为 `password type: PIN`。没有锁屏密码时直接使用默认密码，跳过这两步，几乎立即解密。

recovery 按用户分别解密：

- **user 0 和同密码的用户**：user 0 解密成功后，没有独立密码或与 user 0 密码相同的用户会自动解密。
- **独立密码的用户**：需要输入该用户自己的密码。
- **统一锁屏的 profile**（clone profile、managed profile，例如 XSpace、平行空间）：它们没有自己的锁屏凭据。父用户解密成功后，recovery 用 keystore2 解出 `gatekeeper.profile.key`，得到该 profile 的随机密码，再按普通流程解密。这部分由源码补丁 0006 实现。

### 版本和安全补丁

厂商的 KeyMint 库会读取下面几个属性，判断密钥是否需要升级：

| 属性 | recovery 的值 | 系统的值 |
| --- | --- | --- |
| `ro.build.version.release` | 12 | 16 |
| `ro.build.version.release_or_codename` | 16 | 16 |
| `ro.build.version.security_patch` | 2026-08-01 | 2026-08-01 |
| `ro.vendor.build.security_patch` | 2026-02-01 | 2026-02-01 |

recovery 的 `release` 是 Android 16 的兼容值 12，实测这组值可以解密。换用其他版本的 ROM 时，先让两个安全补丁级别与新系统一致；解密仍失败时，再检查 `release` 和 `release_or_codename`。不要把安全补丁级别调得比系统高：实测这会让 KeyMint 返回 `-62`（`KEY_REQUIRES_UPGRADE`），解密失败。这些值写在 `BoardConfig.mk` 里，修改后需要重新构建。

## 电池、充电和温度

TWRP 直接读取 `/sys/class/power_supply/battery`，状态栏显示电量和充电状态。电池驱动的数据来自 ADSP，所以开机时先从 modem 分区链接 ADSP 固件，再启动 ADSP。

CPU 温度读取 `/sys/class/thermal/thermal_zone27/temp`（cpuss-2）。

## 震动

使用高通开源的 AIDL vibrator HAL（`vendor/qcom/opensource/vibrator`，模块 `vendor.qti.hardware.vibrator.service`）。马达在 recovery 里表现为名为 `qcom-hv-haptics` 的 FF 输入设备（event 编号不固定），HAL 通过 `EV_FF` 驱动它，不依赖小米的效果文件和 misight 服务。recovery 只调用标准的 `on()`/`off()`，实例名使用默认的 `IVibrator/default`。

## USB：ADB、MTP 和 OTG

ADB 和 MTP 都走 configfs。ADB 在 recovery 启动后自动可用；MTP 默认开启，把 `/data/media/0` 导出为 Internal Storage。

USB Storage 已关闭（`vendorsetup.sh` 的 `OF_ENABLE_USB_STORAGE=0`）。这台设备只有一个 USB-C 口，不能同时接 OTG 存储和电脑，而 TWRP 的 USB Storage 只导出可移动存储，不导出内部存储，所以它在这台设备上用不上。文件传输使用 MTP。

OTG 存储挂载在 `/usb_otg`，设备节点是 `/dev/block/sdg1`，备用 `/dev/block/sdg`：UFS 占用了 sda 到 sdf，OTG 设备通常是下一个。NTFS 分区由 `mount.ntfs`（ntfs-3g）挂载。如果扩展坞枚举成其他节点名，自动挂载不会触发，需要同时修改 `twrp.flags` 和 `partitionmanager.cpp` 里的检查路径。

插入 OTG 后 USB 要切到 host 模式，拔出后再切回 device 模式。`init.recovery.qcom.rc` 用 `sys.usb.mode_ready` 避免 MTP 的开关打断 host 模式；拔掉 OTG 后再插电脑线，ADB 会自动回来。OTG 拔出后，`Update_Size()` 不会再尝试挂载已经不存在的设备节点（补丁 0007），恢复 data 后的分区详情刷新不会报无法挂载 `/usb_otg`。

## 数据：清除、备份和恢复

### 普通双清

普通双清（Data 加 Cache/Dalvik）逐个删除 `/data` 下的文件，保留 `/data/media`，**不会删除照片、下载等内部存储文件**。

有些文件带 immutable 或 append 标志，普通删除会失败。常见的是部分 root 模块锁住的 `/data/system/cloudFeature_*.xml`。源码补丁 0002 会先清掉这些标志再删除；仍然删不掉时，双清会中止并报 `Unable to wipe /data`，此时 `/data` 可能只清了一部分，应改用 Format Data。恢复 data 前，recovery 也会先走同一个清除流程。

### Format Data 和 metadata

Format Data，或者在高级清除里勾选 metadata，会格式化整个 userdata 分区（`make_f2fs /dev/block/sda35`），`/data/media` 也会被清空。

metadata 分区存着 data 的加密密钥。只擦 metadata 而不格式化 data，会留下一个没有密钥的 userdata：重启后显示 `Magic Mismatch`，系统无法开机。所以源码补丁 0002 让擦 metadata 时先格式化 data。

格式化前，recovery 会先停掉 MTP（源码补丁 0004）：MTP 一直打开着 `/data/media`，不停掉的话 userdata 的映射处于占用状态，`make_f2fs` 会失败。格式化完成后，MTP 恢复原来的状态。格式化之后需要进一次系统，由系统重新建立加密。

### 备份的范围

- **内部存储**：data 备份不包含 `/data/media`。照片、下载等内容需要另外备份 Internal Storage，并把备份文件复制到电脑或 OTG 硬盘上，因为 Format Data 会清空内部存储。
- **应用数据**：OrangeFox 的 `OF_WORKAROUND_BACKUP_BUG` 把 `/data/data` 排除在备份之外，但在 recovery 里，应用数据也能通过挂载点 `/data/user/0/<包名>/` 访问，备份会经由这条路径收进去，所以应用数据仍在备份里。确认方法见[验证清单](verification.md#data-的备份)。
- **锁屏凭据**：user 0 的 Gatekeeper、Keystore、`locksettings.db` 和 `spblob` 被 TWRP 的 `ExcludeAll()` 排除，既不进入备份，清除时也会保留。

### 恢复后锁屏凭据的状态

因为上面的排除规则，锁屏凭据在不同情况下的结果不同：

| 情况 | 结果 |
| --- | --- |
| 普通双清后恢复 | user 0 的凭据文件没有被删除，仍是当前的状态 |
| 备份和恢复之间做过 Format Data，或者换了设备 | user 0 的凭据和密钥已经不在了，备份里也没有，需要在系统里重新设置锁屏；依赖 keystore 的应用可能需要重新登录 |
| 非 0 用户（独立密码的用户、clone profile） | 普通双清会删掉它们的凭据，恢复时写回备份里的版本；如果备份之后改过密码，恢复后会对不上，需要重新设置 |

另外，普通双清不会删除 user 0 的凭据文件，所以它不能当作“清除锁屏”的手段，这和原厂的恢复出厂设置不同。要清掉锁屏，用 Format Data。

### /data 的挂载参数

recovery 通过 `BoardConfig.mk` 的 `TW_SKIP_ADDITIONAL_FSTAB := true` 只使用设备树自己的 `recovery.fstab`，不读 vendor 的 additional fstab。`/data` 挂载后带 `checkpoint_merge`，没有 `checkpoint=disable`；写入不会因为 vendor fstab 的 `checkpoint=fs` 被回滚。`fsync_mode` 由内核和 vold 在挂载时决定（实测出现过 `posix` 和 `nobarrier` 两种），不是设备树固定配置。SysRq 硬重启后写入的文件仍然存在，已实测。`/vendor/firmware_mnt` 仍由 init 的 `charger_fstab.qti` 挂载，ADSP 不受影响。

## 刷入 zip 和 ADB sideload

“安装”页可以刷入 zip。ADB sideload 在 OrangeFox 的菜单里进入，或者在终端执行 `fox sideload start`，然后在电脑上运行 `adb sideload <zip>`。等待期间界面显示“正在启动侧载”，这是在等电脑开始发送，不是卡住。退出 sideload 后 ADB 会自动恢复，MTP 不会，见[已知问题](known-issues.md#sideload-后-mtp-不会自动恢复)。

## fastbootd

fastbootd 启动时会先查找 health 服务，找不到就一直重试，走不到 USB 初始化，所以 ramdisk 里带了原厂的 health HIDL 服务。进入 fastbootd 后，设备在电脑上显示为 `18d1:4ee0`。

Windows 需要为这个设备安装 Google USB 驱动（`android_winusb.inf`），否则设备管理器显示代码 28，`fastboot devices` 看不到设备。Linux 不需要额外驱动。

## 主题和中文字体

OrangeFox 的中文语言包会把终端和键盘字体换成比例字体，导致等宽错乱。设备树在 `recovery/root/twres/` 下覆盖了语言包，把终端字体和键盘长按标签的字体指向 Sarasa Mono SC。字体是 GBK 子集，约 2.2 万个字符，12.8 MB，超出 GBK 的生僻字会显示成方块。

主题覆盖文件在构建时直接写入 `/twres`。启动后默认显示文件列表。双清或格式化之后会重新加载当前语言（源码补丁 0005），按钮不会停留在英文。

## 设置持久化

设置保存在 `/sdcard/Fox/.foxs`，并在 `/persist/.foxs` 留一份备份。设备树的 `twres/pages/main.xml` 把所有勾选变量声明为 `persist="1"`，不在 OrangeFox 默认持久化列表里的设置也能在重启后保留，不需要源码补丁。

## 禁用 vbmeta AVB2.0

`vendorsetup.sh` 打开了 `OF_SUPPORT_VBMETA_AVB2_PATCHING`，设置、高级和安装页会出现“禁用 vbmeta AVB2.0”。它修改 `vbmeta_a/b` 和 `vbmeta_system_a/b` 的标志位，默认不会自动执行。
