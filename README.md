# 小米平板 6 Max 14（yudi）的橙狐设备树

小米平板 6 Max 14（yudi，骁龙 8+ Gen 1）的 OrangeFox Recovery 设备树，基于橙狐 fox_16.0（Android 16）。

这棵树从零写成：设置取自小米官方 OS3.0.6.0.VMHCNXM 完整包、TWRP/橙狐/AOSP 文档，boot 控制相关的专有文件取自 OS3.0.306.3.WMHCNXM 完整包，来源写在各文件的注释里。专有文件清单见 `proprietary-files.txt`。

**状态：部分验证。**已确认：OrangeFox UI、触摸、MTP、USB Storage、AVB2.0 菜单、USB（免拔插）、电池、CPU 温度、data 解密（metadata + userdata）、震动、system/vendor 等逻辑分区挂载、boot HAL、keymaster、gatekeeper、keymint、qseecomd、logd。原厂 `voldmanaged` 行造成的 132 个假 OTG 存储卷也已修掉，不会再误把 UFS 的 sde/sdf 分区（包括 `vm-bootsys_b`）挂成 `/storage/usbotg-N`。

**data 解密已修复**：根因是恢复环境里 UFS RPMB 设备节点 `/dev/0:0:0:49476` 默认是 `0600 root:root`，而 qseecomd 实际以 system 运行，打不开 RPMB；KeyMint 对带抗回滚属性的 key 返回 `-8`。`init.recovery.qcom.rc` 在启动 qseecomd 前提前 `chown system system` 并 `chmod 0660`，metadata 和 userdata 解密均通过。

**震动已修复**：厂商 AIDL HAL 在 `Vibrator` 构造函数里对没有强引用的 `Thread` 对象调用 `android::Thread::run()`。Android 12 的 libutils 里 `Thread::run` 用 `incStrong`（容错），Android 16 改成 `incStrongRequireStrong`（直接 abort）。给这个 HAL 单独提供改名后的 v32 libutils（`libu32.so`），系统 `libbinder_ndk` 继续用系统 libutils，两份库以不同 SONAME 共存。

## 构建

需要约 150 GB 磁盘和 16 GB 以上内存。构建固定用 `-j12`；内存紧张时加 `GOGC=50 GOMAXPROCS=8`，否则 soong 容易把机器换页拖死。

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
GOGC=50 GOMAXPROCS=8 mka -j12 adbd recoveryimage
```

产物是 `out/target/product/yudi/OrangeFox-*.img` 和 `recovery.img`。

**注意**：`recovery/root` 的 staging 有时会残留旧的 `libminuitwrp.so`，改了触摸代码却看不到效果时，先删掉 `out/target/product/yudi/recovery/root` 和 `ramdisk-recovery.img` 再编。

### 增量构建

完整构建一次后，只改 C/C++ 或 `recovery/root/` 里已有的文件，可以跳过 Soong/Kati，直接调用 ninja：

```sh
source build/envsetup.sh
lunch twrp_yudi-bp2a-eng
prebuilts/build-tools/linux-x86/bin/ninja -f out/combined-twrp_yudi.ninja -j12 adbd recoveryimage
```

- 改 `BoardConfig.mk`、`device.mk`、`Android.bp`、`vendorsetup.sh`，或新增模块/新增会被 glob 的源文件时，必须回到 `mka` 重新生成 ninja。
- 改 ramdisk/主题文件后如果 ninja 认为无事可做，先删 `out/target/product/yudi/recovery.img`；必要时再删 `out/target/product/yudi/recovery/root` 和 `ramdisk-recovery.img`。
- 直接 ninja 前先 `source build/envsetup.sh` 和 `lunch`，否则 OrangeFox 的打包文件名可能缺设备名。
- `m --skip-soong-tests recoveryimage` 可以省掉 Soong 自检。

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
| MTP | 挂载菜单启用 MTP 后，电脑出现便携设备，可读写 `/sdcard`（`tw_mtp_enabled` 默认 1，开机会自动启动） |
| USB Storage | 挂载菜单出现 USB Storage，电脑能读写 |
| AVB2.0 | 设置/高级页出现“禁用 vbmeta AVB2.0”，默认自动处理关闭 |
| 分区挂载 | 挂载菜单里能勾选 system、vendor 等逻辑分区 |
| 槽位 | 只做只读核对：`bootctl get-current-slot` 与 `fastboot getvar current-slot` 一致（当前为 0/a）。b 槽是空的，不要切；原因见“已知问题” |
| fastbootd | 在 recovery 里执行 `adb reboot fastboot`，电脑上 `fastboot getvar is-userspace` 返回 yes |
| 解密 | 进入 recovery 后能看到 `/sdcard` 里的文件（已验证，metadata + userdata 都通过） |
| 电池/温度 | 状态栏显示电量，CPU 温度来自 `thermal_zone27`（cpuss-2） |
| 震动 | 点击按钮有震感；`vibratorfeature-hal-service` 常驻，实例 `IVibrator/vibratorfeature` 已注册（libu32 修复） |
| 刷入卡刷包、备份和恢复 | 各做一次 |

出问题时，取 `/tmp/recovery.log`、`logcat -d` 和 `dmesg`。

## 设计说明

**内核**：原厂 recovery 不带内核，由引导程序用 boot 分区的内核启动，这里保持一致。`prebuilt/kernel` 是原厂 boot 里的 5.10.236，只用来满足构建系统，不会打进镜像。实际运行时用的是 boot 分区的内核，包括自编内核；只要它和原厂内核的模块接口兼容就能工作。

**boot 控制**：A/B 槽位直接用原厂 vendor 里的 HIDL 1.2 boot HAL（`android.hardware.boot@1.2-service`），不再编译 LineageOS 的 bootctrl 和 gpt-utils，也不需要内核头文件。服务名是 `vendor.boot-hal-1-2`，由 `init.recovery.qcom.rc` 在 `on fs` 里显式启动；实现库 `android.hardware.boot@1.0-impl-1.2-qti.so` 和依赖库都放在 ramdisk 的 `/vendor/lib64`。

**屏幕方向**：面板原生是 2880x1800 横屏。原厂系统把它旋转 270 度作为自然方向，橙狐也一样，界面是 1800x2880 的竖屏。四角实测驱动坐标系和竖屏画面一致，不需要任何 `RECOVERY_TOUCHSCREEN_*` 参数。触控驱动由 TWRP 在挂载 vendor_dlkm 之后从 ramdisk 的 `/vendor/lib/modules` 加载 `xiaomi_touch.ko` 和 `nt36532_touch.ko`。如果当前槽的 vendor_dlkm 为空（比如 b 槽），TWRP 会跳过这两个模块；设备树的 `recovery/root/system/bin/beforemodules.sh` 会在 TWRP 初始化 GUI/输入设备之前检查 vendor_dlkm 的块设备大小，为空时从 `/lib/modules` 补载，所以 a/b 槽都有触摸。触控固件放在 ramdisk 的 `/lib/firmware`。

**版本号和安全补丁**：厂商的 `libqtikeymint`/`libqtikeymaster4` 会读 `ro.build.version.release`、`ro.build.version.security_patch` 和 `ro.vendor.build.security_patch` 来判断 metadata key 是否需要升级。必须和当前系统一致：release 16、security_patch 2026-08-01、vendor patch 2026-02-01。boot 头部保持原厂值 12.0.0/2025-09，用 `BOARD_MKBOOTIMG_ARGS` 显式覆盖。不要把 `PLATFORM_VERSION_LAST_STABLE` 改成 12，CTS 校验会中止。

**ADSP 和电池**：ADSP 固件（`adsp.*`）放在 ramdisk 的 `/lib/firmware`，因为内核的 `firmware_class.path` 指向那里；震动效果文件（187 个 `*_RTP.bin` 等）放在 `/vendor/firmware`。不能把整个 modem 镜像 bind 到 `/vendor/firmware`，否则会盖住 vendor 分区的效果文件。ADSP 的 remoteproc 状态是 running，电池和充电正常。

**USB OTG**：`twrp.flags` 里的 `/usb_otg` 条目负责真正的 OTG。`recovery.fstab` 里原厂的 `/devices/... voldmanaged=usbotg:auto` 行会让 TWRP 把 `/dev/block/*` 展开成大量假卷，已注释掉。

**MTP 与 USB Storage**：recovery 的通用 init 只创建 `ffs.adb` 和 `ffs.fastboot`，没有 MTP。`init.recovery.qcom.rc` 在 `on boot` 里先创建 configfs 的 `ffs.mtp` 和 `mass_storage.0`，再 mount FunctionFS 到 `/dev/usb-ffs/mtp`，并在 `sys.usb.config=mtp,adb` / `mass_storage,adb` 时绑定 `f1`/`f2`。USB Storage 使用 `mass_storage.0` 的 configfs LUN 路径，不依赖 MTP。`tw_mtp_enabled` 的默认值是 1（`data.cpp`），开机时由 `twrp.cpp` 自动启动 MTP；设置只保存在 `/sdcard/Fox/.foxs`，不从镜像里写死。

**USB Storage 退出后 MTP 不恢复**是 TWRP 自身的问题：切换 USB 配置时 MTP 子进程会收到 FunctionFS 的 DISABLE（`errno 108`）退出，但父进程的 `mtppid` 没有清掉，`usb_storage_disable()` 再调用 `Enable_MTP()` 时直接返回“MTP already enabled”，于是按钮还亮着但 MTP 已经没了。设备树用主题覆盖修：`recovery/root/vendor/etc/mount-usb-mtp.xml` 在 USB 页的三个退出动作里，于 `unmount usb` 后加 `stopmtp`、等 500 ms、再 `startmtp`，由 `init.recovery.qcom.rc` 的 `on fs` 复制到 `/twres/pages/mount.xml`。代价是退出 USB Storage 一定会把 MTP 打开（即使进去前是关的）。**不要用 Fox FIFO 的 `mtp enable`（`/system/bin/foxin`）做测试**：dispatcher 会打开 `/system/bin/foxout` 写结果，如果不同时读取，写 FIFO 会阻塞 GUI 动作线程，屏幕看起来卡死；MTP 请走界面。

**主题字体与启动页**：橙狐主题在 ramdisk 的 `/twres`。中文语言包 `zh_CN.xml` 会把 `fixed`、`keylabel-longpress` 等几乎所有字体资源强制替换成 `wqy-microhei.ttf`（比例字体），主题里换字体不会生效。TWRP 的终端按固定格宽逐格绘制（格宽取 `measureEx("N")`），键盘 longpress 小符号按字宽右对齐，遇到比例字体就会出现字母挨太近/错位、小符号位置不齐。设备树自带一份改过的 `zh_CN.xml`（只把第 27 行 `keylabel-longpress` 和第 38 行 `fixed` 指向 `SarasaMonoSC-Regular.ttf`），并带上 Sarasa Mono SC Regular（中文等宽，25.6MB）；`init.recovery.qcom.rc` 在 `on fs` 把两者复制到 `/twres/languages/` 和 `/twres/fonts/`。代价是 ramdisk 增加约 25.6MB，镜像内容约 93MB（分区 100MB）。启动页由 `main.xml` 的 `tw_clear_destination` 决定：主题里的 `menu` 实际是文件管理的选项弹层，不是主菜单；本设备改为 `advanced`，开机进“高级”tab。

**AVB2.0**：`vendorsetup.sh` 打开 `OF_SUPPORT_VBMETA_AVB2_PATCHING=1`，设置/高级/安装页出现“禁用 vbmeta AVB2.0”。它修改 `vbmeta_a/b` 和 `vbmeta_system_a/b` 的 flags，可手动执行，或在刷 ROM 后按开关执行；默认不会自动改。`BOARD_AVB_ENABLE` 只是用测试密钥给 recovery 签名，不是绕过 AVB。`OF_PATCH_AVB20` 在 A/B 设备上被源码排除，不适用。

**解密**：userdata 使用 FBE v2（`inlinecrypt_optimized` 加 `wrappedkey_v0` 硬件包装密钥），并开启 metadata 加密。解密依赖 vendor 的安全服务：`qseecomd` 注册完监听器后，再启动 Keymaster 4.1、Gatekeeper 和 KeyMint。服务定义沿用原厂 vendor 的 rc 文件，启动顺序写在 `init.recovery.qcom.rc`。

**RPMB**：KeyMint 对带抗回滚属性的 key 需要访问 UFS RPMB（`/dev/0:0:0:49476`，well-known LUN 0xC144）。原厂 vendor 的 `/etc/ueventd.rc` 里有规则 `/dev/0:0:0:49476 0600 system system`，recovery 的 `/vendor/etc/ueventd.rc` 也加上这条（节点创建时生效）；`init.recovery.qcom.rc` 里再 `chown system system` + `chmod 0660` 兜底。这个节点默认是 `0600 root:root`，而 qseecomd 启动后会降到 system 用户；漏掉时会打印 `Unable to open ... error no: 13`，KeyMint 的 `begin` 返回 `-8 INCOMPATIBLE_BLOCK_MODE`，metadata 解密失败。

**VNDK**：qseecomd、Keymaster、KeyMint 等 HIDL 服务通过各自 rc 里的 `setenv LD_LIBRARY_PATH` 优先使用 `/vendor/lib64/vndk-v32` 下的 Android 12 VNDK 基础库（libcrypto、libbase、libcutils、libhidlbase 等）；AIDL 服务中的 misight 保持系统库；震动服务使用 vndk 目录里改名后的 `libu32.so`（v32 libutils），系统 `libbinder_ndk` 仍用系统 libutils，避免 `String16` 等符号冲突。

**震动**：ROM 自带的 AIDL vibrator HAL（实例 `IVibrator/vibratorfeature`）。根因是 `Vibrator` 构造函数里的 `android::Thread::run()`：Android 12 的 libutils 用 `incStrong`，Android 16 用 `incStrongRequireStrong`，后者要求对象已有强引用，厂商代码没有，于是 abort。修复方式是把 v32 libutils 的 SONAME 改成 `libu32.so`，并把厂商服务二进制的 NEEDED 从 `libutils.so` 改成 `libu32.so`；系统 `libbinder_ndk` 仍用系统 libutils，两份库共存。服务 rc 里给 `vibratorfeature-hal-service` 单独设置 `LD_LIBRARY_PATH` 指向 `/vendor/lib64/vndk-v32`。HAL 现在常驻并注册成功。

## 已知问题

- ~~data 解密~~：已修复，见“设计说明”的 RPMB 一段。根因不是版本属性或 GCM 参数，而是 UFS RPMB 节点权限；修复后在 `recovery.log` 里可以看到 `Successfully decrypted metadata encrypted data partition` 和 `Data successfully decrypted`。
- ~~震动 HAL abort~~：已修复，见“设计说明”的震动一段（libu32）。
- **时区名无效**：`persist.sys.timezone=TAIST-8TAIDT`，ramdisk 没有 `/system/usr/share/zoneinfo`，每条命令会打 `__bionic_open_tzdata` 警告；时钟偏移本身正确，不影响功能。
- **屏幕空闲会息屏**：TWRP 会把亮度降到 0，触碰会亮；不是故障。
- **槽位切换 UI 只认 A/B，当前 b 槽是空的**：UI（Reboot 页）只显示当前槽和“切换到另一个槽”，点击后走 vendor boot HAL 的 `SetActiveBootSlot(0/1)`，不会写 super 元数据，也不会提供第三个槽。super 的 `metadata_slot_count` 和 QTI boot HAL 都报 3，但 `get-suffix 2` 直接报错；这个“3”是元数据副本/QTI HAL 的计数，和 recovery UI 无关。实测当前设备 super 里的 `*_b` 逻辑分区（system/vendor/product/system_ext/odm/vendor_dlkm/mi_ext）全部是 0 扇区；`recovery_b` 已在 2026-11-04 刷成与 `recovery_a` 相同的这份 recovery。切到 b 后系统分区消失、落到 fastboot，根因是 b 槽没有系统，不是 UI 误选第三个槽。不要切 b；以后要切必须先用完整 OTA/线刷包填好 b 的 super，并保持 `recovery_b` 与 `recovery_a` 相同，再用 fastboot `--set-active=b` 并确认。
- ~~**b 槽 recovery 没有触摸**~~：已修复。`beforemodules.sh` 在当前槽的 vendor_dlkm 为空时从 ramdisk 补载 `xiaomi_touch.ko`/`nt36532_touch.ko`，vendor_dlkm 完整时交给 TWRP 自己加载；b 槽触摸正常。2026-11-04 实测：recovery_b 与 recovery_a 相同、boot_a/boot_b 相同，b 槽能正常启动这份 rec 并完成切回 a。

## 从官方固件取文件

主要来自 `yudi-ota_full-OS3.0.6.0.VMHCNXM-user-15.0-7b73783799.zip`；boot HAL 的 9 个文件来自 `yudi-ota_full-OS3.0.306.3.WMHCNXM-user-16.0-b255c0d484-2in1-Root.zip`：

- 306.3 包没有 payload，`super.zst` 解压得到 `super.img`，用 `lpunpack -p vendor_a -p system_ext_a super.img <目录>` 取出逻辑分区；
- erofs 分区可以用 `dump.erofs --path=<路径> --ls` 查看目录，用 `fsck.erofs --extract=<目录>` 整体解开；
- vendor 服务的依赖用 `readelf -d` 逐层查找；`qseecomd` 运行时用 dlopen 加载的监听器库，在二进制里搜索 `.so` 字符串找出；
- 震动效果文件来自 vendor 分区的 `/firmware`（187 个文件），ADSP 固件来自 modem 分区的 `/image/adsp.*`（26 个文件）。

## 参考

- [TWRP](https://github.com/TeamWin/android_bootable_recovery)、[OrangeFox](https://gitlab.com/OrangeFox)：构建系统和变量文档
- 小米平板 6 Pro（liuqin）的 [TWRP 12.1 树](https://github.com/ymdzq/device_xiaomi_liuqin-TWRP) 和 [TWRP 16 树](https://github.com/lanweikayu/device_xiaomi_liuqin-TWRP-16)：同平台设备，用于对照核实，没有直接复制
