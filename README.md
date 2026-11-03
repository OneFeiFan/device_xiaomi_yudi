# 小米平板 6 Max 14（yudi）的橙狐设备树

小米平板 6 Max 14（yudi，骁龙 8+ Gen 1）的 OrangeFox Recovery 设备树，基于橙狐 fox_16.0（Android 16）。

这棵树从零写成：设置取自小米官方 OS3.0.6.0.VMHCNXM 完整包、TWRP/橙狐/AOSP 文档，boot 控制相关的专有文件取自 OS3.0.306.3.WMHCNXM 完整包，来源写在各文件的注释里。专有文件清单见 `proprietary-files.txt`。

**状态：部分验证。**已确认：OrangeFox UI、触摸、USB（免拔插）、电池、CPU 温度、data 解密（metadata + userdata）、震动、system/vendor 等逻辑分区挂载、boot HAL、keymaster、gatekeeper、keymint、qseecomd、logd。原厂 `voldmanaged` 行造成的 132 个假 OTG 存储卷也已修掉，不会再误把 UFS 的 sde/sdf 分区（包括 `vm-bootsys_b`）挂成 `/storage/usbotg-N`。

**data 解密已修复**：根因是恢复环境里 UFS RPMB 设备节点 `/dev/0:0:0:49476` 默认是 `0600 root:root`，而 qseecomd 实际以 system 运行，打不开 RPMB；KeyMint 对带抗回滚属性的 key 返回 `-8`。`init.recovery.qcom.rc` 在启动 qseecomd 前提前 `chown system system` 并 `chmod 0660`，metadata 和 userdata 解密均通过。

**震动已修复**：厂商 AIDL HAL 在 `Vibrator` 构造函数里对没有强引用的 `Thread` 对象调用 `android::Thread::run()`。Android 12 的 libutils 里 `Thread::run` 用 `incStrong`（容错），Android 16 改成 `incStrongRequireStrong`（直接 abort）。给这个 HAL 单独提供改名后的 v32 libutils（`libu32.so`），系统 `libbinder_ndk` 继续用系统 libutils，两份库以不同 SONAME 共存。

## 构建

需要约 150 GB 磁盘和 16 GB 以上内存。内存紧张时用 `GOGC=50 GOMAXPROCS=8 JOBS=8`，否则 soong 容易把机器换页拖死。

```sh
# 1. 同步橙狐源码
mkdir orangefox_16 && cd orangefox_16
repo init -u https://gitlab.com/OrangeFox/Manifest.git -b fox_16.0
repo sync -c --no-tags -j8

# 2. 放入设备树
git clone <本仓库> device/xiaomi/yudi

# 3. 构建
export FOX_BUILD_DEVICE=yudi
source build/envsetup.sh
lunch twrp_yudi-bp2a-eng
mka -j8 adbd recoveryimage
```

产物是 `out/target/product/yudi/OrangeFox-*.img` 和 `recovery.img`。

**注意**：`recovery/root` 的 staging 有时会残留旧的 `libminuitwrp.so`，改了触摸代码却看不到效果时，先删掉 `out/target/product/yudi/recovery/root` 和 `ramdisk-recovery.img` 再编。

## 刷入与回退

yudi 有独立的 `recovery_a` 和 `recovery_b` 分区。原厂 recovery 不带内核，这个镜像也不带，所以不能用 `fastboot boot` 临时启动，只能刷入。

```sh
adb reboot bootloader
fastboot getvar current-slot                 # 先只刷当前槽位测试
fastboot flash recovery_a recovery.img       # 当前槽位是 b 时改为 recovery_b
fastboot reboot recovery
```

测试通过后再刷另一个槽位。回退时刷回原厂 recovery：它在官方完整包的 payload 里，可以用 payload 解包工具取出 `recovery.img`。

## 测试清单

| 项目 | 怎么确认 |
| --- | --- |
| 能进入界面 | 屏幕显示橙狐，不反复重启 |
| 触控 | 点击位置准确（面板原生横屏，界面旋转 270°，不需要 SWAP/FLIP） |
| ADB | 电脑上 `adb shell` 能连上，第一次 attach 不需要拔插 |
| 分区挂载 | 挂载菜单里能勾选 system、vendor 等逻辑分区 |
| 槽位 | `bootctl get-current-slot` 与 `fastboot getvar current-slot` 一致（当前为 0/a）。注意 QTI boot HAL 报 `get-number-slots=3`，实际只有 a/b，只切 0/1，切完重启到 bootloader 确认 |
| fastbootd | 在 recovery 里执行 `adb reboot fastboot`，电脑上 `fastboot getvar is-userspace` 返回 yes |
| 解密 | 进入 recovery 后能看到 `/sdcard` 里的文件（已验证，metadata + userdata 都通过） |
| 电池/温度 | 状态栏显示电量，CPU 温度来自 `thermal_zone27`（cpuss-2） |
| 震动 | 点击按钮有震感；`vibratorfeature-hal-service` 常驻，实例 `IVibrator/vibratorfeature` 已注册（libu32 修复） |
| 刷入卡刷包、备份和恢复 | 各做一次 |

出问题时，取 `/tmp/recovery.log`、`logcat -d` 和 `dmesg`。

## 设计说明

**内核**：原厂 recovery 不带内核，由引导程序用 boot 分区的内核启动，这里保持一致。`prebuilt/kernel` 是原厂 boot 里的 5.10.236，只用来满足构建系统，不会打进镜像。实际运行时用的是 boot 分区的内核，包括自编内核；只要它和原厂内核的模块接口兼容就能工作。

**boot 控制**：A/B 槽位直接用原厂 vendor 里的 HIDL 1.2 boot HAL（`android.hardware.boot@1.2-service`），不再编译 LineageOS 的 bootctrl 和 gpt-utils，也不需要内核头文件。服务名是 `vendor.boot-hal-1-2`，由 `init.recovery.qcom.rc` 在 `on fs` 里显式启动；实现库 `android.hardware.boot@1.0-impl-1.2-qti.so` 和依赖库都放在 ramdisk 的 `/vendor/lib64`。

**屏幕方向**：面板原生是 2880x1800 横屏。原厂系统把它旋转 270 度作为自然方向，橙狐也一样，界面是 1800x2880 的竖屏。四角实测驱动坐标系和竖屏画面一致，不需要任何 `RECOVERY_TOUCHSCREEN_*` 参数。触控驱动由 TWRP 从 vendor_dlkm 加载 `xiaomi_touch.ko` 和 `nt36532_touch.ko`；这两个模块同时放进了 ramdisk 的 `/vendor/lib/modules` 和 `/lib/modules`，vendor_dlkm 缺失时仍可触摸。触控固件放在 ramdisk 的 `/lib/firmware`。

**版本号和安全补丁**：厂商的 `libqtikeymint`/`libqtikeymaster4` 会读 `ro.build.version.release`、`ro.build.version.security_patch` 和 `ro.vendor.build.security_patch` 来判断 metadata key 是否需要升级。必须和当前系统一致：release 16、security_patch 2026-08-01、vendor patch 2026-02-01。boot 头部保持原厂值 12.0.0/2025-09，用 `BOARD_MKBOOTIMG_ARGS` 显式覆盖。不要把 `PLATFORM_VERSION_LAST_STABLE` 改成 12，CTS 校验会中止。

**ADSP 和电池**：ADSP 固件（`adsp.*`）放在 ramdisk 的 `/lib/firmware`，因为内核的 `firmware_class.path` 指向那里；震动效果文件（187 个 `*_RTP.bin` 等）放在 `/vendor/firmware`。不能把整个 modem 镜像 bind 到 `/vendor/firmware`，否则会盖住 vendor 分区的效果文件。ADSP 的 remoteproc 状态是 running，电池和充电正常。

**USB OTG**：`twrp.flags` 里的 `/usb_otg` 条目负责真正的 OTG。`recovery.fstab` 里原厂的 `/devices/... voldmanaged=usbotg:auto` 行会让 TWRP 把 `/dev/block/*` 展开成大量假卷，已注释掉。

**解密**：userdata 使用 FBE v2（`inlinecrypt_optimized` 加 `wrappedkey_v0` 硬件包装密钥），并开启 metadata 加密。解密依赖 vendor 的安全服务：`qseecomd` 注册完监听器后，再启动 Keymaster 4.1、Gatekeeper 和 KeyMint。服务定义沿用原厂 vendor 的 rc 文件，启动顺序写在 `init.recovery.qcom.rc`。

**RPMB**：KeyMint 对带抗回滚属性的 key 需要访问 UFS RPMB（`/dev/0:0:0:49476`，well-known LUN 0xC144）。原厂 vendor 的 `/etc/ueventd.rc` 里有规则 `/dev/0:0:0:49476 0600 system system`，recovery 的 `/vendor/etc/ueventd.rc` 也加上这条（节点创建时生效）；`init.recovery.qcom.rc` 里再 `chown system system` + `chmod 0660` 兜底。这个节点默认是 `0600 root:root`，而 qseecomd 启动后会降到 system 用户；漏掉时会打印 `Unable to open ... error no: 13`，KeyMint 的 `begin` 返回 `-8 INCOMPATIBLE_BLOCK_MODE`，metadata 解密失败。

**VNDK**：qseecomd、Keymaster、KeyMint 等 HIDL 服务通过各自 rc 里的 `setenv LD_LIBRARY_PATH` 优先使用 `/vendor/lib64/vndk-v32` 下的 Android 12 VNDK 基础库（libcrypto、libbase、libcutils、libhidlbase 等）；AIDL 服务中的 misight 保持系统库；震动服务使用 vndk 目录里改名后的 `libu32.so`（v32 libutils），系统 `libbinder_ndk` 仍用系统 libutils，避免 `String16` 等符号冲突。

**震动**：ROM 自带的 AIDL vibrator HAL（实例 `IVibrator/vibratorfeature`）。根因是 `Vibrator` 构造函数里的 `android::Thread::run()`：Android 12 的 libutils 用 `incStrong`，Android 16 用 `incStrongRequireStrong`，后者要求对象已有强引用，厂商代码没有，于是 abort。修复方式是把 v32 libutils 的 SONAME 改成 `libu32.so`，并把厂商服务二进制的 NEEDED 从 `libutils.so` 改成 `libu32.so`；系统 `libbinder_ndk` 仍用系统 libutils，两份库共存。服务 rc 里给 `vibratorfeature-hal-service` 单独设置 `LD_LIBRARY_PATH` 指向 `/vendor/lib64/vndk-v32`。HAL 现在常驻并注册成功。

## 已知问题

- ~~data 解密~~：已修复，见“设计说明”的 RPMB 一段。根因不是版本属性或 GCM 参数，而是 UFS RPMB 节点权限；修复后在 `recovery.log` 里可以看到 `Successfully decrypted metadata encrypted data partition` 和 `Data successfully decrypted`。
- ~~震动 HAL abort~~：已修复，见“设计说明”的震动一段（libu32）。
- **时区名无效**：`persist.sys.timezone=TAIST-8TAIDT`，ramdisk 没有 `/system/usr/share/zoneinfo`，每条命令会打 `__bionic_open_tzdata` 警告；时钟偏移本身正确，不影响功能。
- **屏幕空闲会息屏**：TWRP 会把亮度降到 0，触碰会亮；不是故障。
- **b 槽没有系统**：只切到有系统的槽位；recovery 已把触摸模块打进 ramdisk，但空槽仍然没有 system/vendor，无法开机。QTI boot HAL 报 3 个槽位，实际只有 0/a、1/b，不要切到 2。

## 从官方固件取文件

主要来自 `yudi-ota_full-OS3.0.6.0.VMHCNXM-user-15.0-7b73783799.zip`；boot HAL 的 9 个文件来自 `yudi-ota_full-OS3.0.306.3.WMHCNXM-user-16.0-b255c0d484-2in1-Root.zip`：

- 306.3 包没有 payload，`super.zst` 解压得到 `super.img`，用 `lpunpack -p vendor_a -p system_ext_a super.img <目录>` 取出逻辑分区；
- erofs 分区可以用 `dump.erofs --path=<路径> --ls` 查看目录，用 `fsck.erofs --extract=<目录>` 整体解开；
- vendor 服务的依赖用 `readelf -d` 逐层查找；`qseecomd` 运行时用 dlopen 加载的监听器库，在二进制里搜索 `.so` 字符串找出；
- 震动效果文件来自 vendor 分区的 `/firmware`（187 个文件），ADSP 固件来自 modem 分区的 `/image/adsp.*`（26 个文件）。

## 参考

- [TWRP](https://github.com/TeamWin/android_bootable_recovery)、[OrangeFox](https://gitlab.com/OrangeFox)：构建系统和变量文档
- 小米平板 6 Pro（liuqin）的 [TWRP 12.1 树](https://github.com/ymdzq/device_xiaomi_liuqin-TWRP) 和 [TWRP 16 树](https://github.com/lanweikayu/device_xiaomi_liuqin-TWRP-16)：同平台设备，用于对照核实，没有直接复制
