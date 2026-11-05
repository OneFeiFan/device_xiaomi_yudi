# 小米平板 6 Max 14（yudi）OrangeFox Recovery 设备树

小米平板 6 Max 14（代号 **yudi**，骁龙 8+ Gen 1）的 OrangeFox Recovery 设备树，基于橙狐 **fox_16.0**（Android 16，OrangeFox R12.0）。

| 项目 | 值 |
| --- | --- |
| 设备 | Xiaomi Pad 6 Max 14（yudi） |
| SoC | Snapdragon 8+ Gen 1（SM8475） |
| 屏幕 | 2880×1800，面板原生横屏，recovery 以 270° 旋转显示为 1800×2880 |
| 基线 | OrangeFox R12.0 / fox_16.0 |
| recovery 分区 | 100 MiB（镜像约 93 MiB，余量较小） |
| 当前状态 | 主要功能可用；未验证项和已知问题见下文 |

> **免责声明**：刷机有风险，可能丢数据甚至变砖。本设备树与小米、OrangeFox、TeamWin 无隶属关系，按现状提供，使用后果自负。刷机前请确认已备份，并阅读“刷入与回退”和“已知问题”。

这棵树从零写成：设置取自小米官方 OS3.0.6.0.VMHCNXM 完整包、TWRP/橙狐/AOSP 文档；boot 控制相关的专有文件取自 OS3.0.306.3.WMHCNXM 完整包；来源写在各文件的注释里，专有文件清单见 `proprietary-files.txt`。

## 功能状态

### ✅ 已在实机验证

| 功能 | 验证情况 |
| --- | --- |
| 启动与界面 | a 槽正常启动；b 槽刷同一镜像也能启动 |
| 触摸 | a/b 槽都正常；b 槽 vendor_dlkm 为空时由 `beforemodules.sh` 从 ramdisk 补载触摸模块 |
| 主题与字体 | 中文等宽终端、键盘 longpress 小符号、开机进“高级”tab，用户实机确认 |
| ADB | 首次进入 recovery 免拔插即可识别 |
| MTP | 开机自动启用，导出 `/data/media/0` 为 Internal Storage |
| USB Storage | 挂载菜单可用，电脑能读写 |
| 电池/充电 | 状态栏显示电量，充电状态正常 |
| CPU 温度 | 读取 `thermal_zone27`（cpuss-2），界面显示正常 |
| FBE 解密 | 默认密码场景下 metadata + userdata 均解密成功 |
| 安全服务 | qseecomd、Keymaster 4.1、Gatekeeper、KeyMint 均正常运行 |
| boot HAL | 原厂 HIDL 1.2 服务正常，`bootctl get-current-slot` 可读当前槽 |
| 逻辑分区 | system/vendor/product/system_ext 等可挂载 |
| 震动 HAL | `vibratorfeature-hal-service` 常驻，`IVibrator/vibratorfeature` 注册成功 |
| 设置持久化 | RPC 端到端验证：改值 → 重启 → 读回一致；界面点击走同一套 `SetValue`/`Flush` |
| AVB2.0 菜单 | 设置/高级/安装页出现“禁用 vbmeta AVB2.0” |
| 假 OTG 卷修复 | 不再把 UFS 的 sde/sdf 挂成 132 个 `/storage/usbotg-N` |
| 中文提示修复 | 下拉面板不再显示误译的“找不到 Media 储存”，显示“MTP 已启用” |

### ⚠️ 已实现但未实机验证

- 通过 recovery 刷入卡刷包（zip/ROM）
- 备份与恢复（boot/system/data 等）
- ADB sideload
- fastbootd（见“已知问题”，曾出现 USB 枚举消失，未复测）
- USB OTG 接真实设备读写
- 分区管理：修复、调整大小、更改文件系统
- 清除/格式化 data（未做破坏性测试）
- 实际执行“禁用 vbmeta AVB2.0”
- 自定义锁屏密码、多用户解密（只验证了默认密码）
- 震动的实际触感（只确认了 HAL 注册，未确认马达动作）
- 退出 USB Storage 后 MTP 自动恢复（已实现覆盖，未单独复测）
- 其他版本内核（当前运行 5.10.272 正常，更早/更晚版本未测）

### ❓ 存疑与已知问题

- **开机 1–3 秒卡顿**：UI 起来后短暂卡顿，根因未定位，暂未处理。
- **时区名无效**：`persist.sys.timezone=TAIST-8TAIDT`，ramdisk 没有 `/system/usr/share/zoneinfo`，每条命令会打 `__bionic_open_tzdata` 警告；时钟本身正确，不影响功能。
- **屏幕空闲会息屏**：TWRP 会把亮度降到 0，触碰会亮；不是故障。
- **b 槽 super 是空的**：UI 的槽位切换只认 A/B；当前 `*_b` 逻辑分区全部 0 扇区，切到 b 后系统会落到 fastboot。不要切 b；以后要切必须先用完整 OTA/线刷包填好 b 的 super，并保持 `recovery_b` 与 `recovery_a` 相同。
- **recovery 分区余量小**：100 MiB 分区，镜像约 93 MiB（含 25.6 MB Sarasa 字体），后续加功能要留意大小。
- **fastbootd 未复测**：早期执行 `adb reboot fastboot` 后 USB 枚举消失，之后再没验证；使用前先确认能回 fastboot。
- **Fox FIFO 的 `mtp enable` 会卡住界面**：dispatcher 写 `/system/bin/foxout` 时如果没有同时读取，会阻塞 GUI 动作线程；MTP 请走界面。
- **依赖 ROM 版本**：Keymaster/KeyMint 的版本和安全补丁必须与当前系统一致（见“设计说明”），换 ROM 后可能需要调整。
- **专有文件版权**：`recovery/root` 下的厂商二进制/固件来自小米官方包，版权归小米，不在本仓库的 GPL 许可范围内，详见“许可证与第三方”。

## 构建

需要约 150 GB 磁盘和 16 GB 以上内存。构建固定用 `-j12`；内存紧张时加 `GOGC=50 GOMAXPROCS=8`，否则 Soong 容易把机器换页拖死。

```sh
# 1. 同步橙狐源码
mkdir orangefox_16 && cd orangefox_16
repo init -u https://gitlab.com/OrangeFox/Manifest.git -b fox_16.0
repo sync -c --no-tags -j8

# 2. 放入设备树
git clone https://github.com/OneFeiFan/device_xiaomi_yudi device/xiaomi/yudi

# 3. 打 settings 补丁（必须，否则设置重启后会丢）
cd bootable/recovery
git apply ../../device/xiaomi/yudi/patches/0001-fox-settings-persistence.patch
cd ../..

# 4. 构建
export FOX_BUILD_DEVICE=yudi
source build/envsetup.sh
lunch twrp_yudi-bp2a-eng
GOGC=50 GOMAXPROCS=8 mka -j12 adbd recoveryimage
```

产物是 `out/target/product/yudi/OrangeFox-*.img` 和 `recovery.img`。

> 补丁是对 `bootable/recovery` 的两处修改：`tw_reboot()` 里 `syncfs()` 保证 f2fs 落盘，以及主题勾选写值 `persist=1`。每次 `repo sync` 覆盖 `bootable/recovery` 后都要重新打一次。

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
- 内存充足时增量构建可以用 `-j16`。

## 刷入与回退

yudi 有独立的 `recovery_a` 和 `recovery_b` 分区。原厂 recovery 不带内核，这个镜像也不带，所以不能用 `fastboot boot` 临时启动，只能刷入。

```sh
adb reboot bootloader
fastboot getvar current-slot                 # 先只刷当前槽位测试
fastboot flash recovery_a recovery.img       # 当前槽位是 b 时改为 recovery_b
fastboot reboot recovery
```

测试通过后再刷另一个槽位。回退时刷回原厂 recovery：它在官方完整包的 payload 里，可以用 payload 解包工具取出 `recovery.img`。

## 仓库结构

```text
AndroidProducts.mk       产品定义
BoardConfig.mk           recovery 板级配置（分区、触摸、内核参数、安全补丁）
device.mk                拷贝 ramdisk 覆盖文件
vendorsetup.sh           橙狐构建变量
twrp_yudi.mk             TWRP 产品配置
proprietary-files.txt    专有文件清单与来源
prebuilt/kernel          原厂 boot 里的内核，只用于满足构建系统，不打进镜像
patches/                 需要打到 OrangeFox bootable/recovery 的补丁
recovery/root/           ramdisk 覆盖：vendor 服务/库、固件、模块、主题覆盖
licenses/                第三方许可证
```

## 设计说明

**内核**：原厂 recovery 不带内核，由引导程序用 boot 分区的内核启动，这里保持一致。`prebuilt/kernel` 是原厂 boot 里的 5.10.236，只用来满足构建系统，不会打进镜像。实际运行时用的是 boot 分区的内核，包括自编内核；只要它和原厂内核的模块接口兼容就能工作（当前 5.10.272 实测可用）。

**boot 控制**：A/B 槽位直接用原厂 vendor 里的 HIDL 1.2 boot HAL（`android.hardware.boot@1.2-service`），不再编译 LineageOS 的 bootctrl 和 gpt-utils，也不需要内核头文件。服务名是 `vendor.boot-hal-1-2`，由 `init.recovery.qcom.rc` 在 `on fs` 里显式启动；实现库 `android.hardware.boot@1.0-impl-1.2-qti.so` 和依赖库都放在 ramdisk 的 `/vendor/lib64`。

**屏幕方向**：面板原生是 2880x1800 横屏。原厂系统把它旋转 270 度作为自然方向，橙狐也一样，界面是 1800x2880 的竖屏。四角实测驱动坐标系和竖屏画面一致，不需要任何 `RECOVERY_TOUCHSCREEN_*` 参数。触控驱动由 TWRP 在挂载 vendor_dlkm 之后从 ramdisk 的 `/vendor/lib/modules` 加载 `xiaomi_touch.ko` 和 `nt36532_touch.ko`。如果当前槽的 vendor_dlkm 为空（比如 b 槽），TWRP 会跳过这两个模块；设备树的 `recovery/root/system/bin/beforemodules.sh` 会在 TWRP 初始化 GUI/输入设备之前检查 vendor_dlkm 的块设备大小，为空时从 `/lib/modules` 补载，所以 a/b 槽都有触摸。触控固件放在 ramdisk 的 `/lib/firmware`。

**版本号和安全补丁**：厂商的 `libqtikeymint`/`libqtikeymaster4` 会读 `ro.build.version.release`、`ro.build.version.security_patch` 和 `ro.vendor.build.security_patch` 来判断 metadata key 是否需要升级。必须和当前系统一致：release 16、security_patch 2026-08-01、vendor patch 2026-02-01。boot 头部保持原厂值 12.0.0/2025-09，用 `BOARD_MKBOOTIMG_ARGS` 显式覆盖。不要把 `PLATFORM_VERSION_LAST_STABLE` 改成 12，CTS 校验会中止。

**ADSP 和电池**：ADSP 固件（`adsp.*`）放在 ramdisk 的 `/lib/firmware`，因为内核的 `firmware_class.path` 指向那里；震动效果文件（187 个 `*_RTP.bin` 等）放在 `/vendor/firmware`。不能把整个 modem 镜像 bind 到 `/vendor/firmware`，否则会盖住 vendor 分区的效果文件。ADSP 的 remoteproc 状态是 running，电池和充电正常。

**USB OTG**：`twrp.flags` 里的 `/usb_otg` 条目负责真正的 OTG。`recovery.fstab` 里原厂的 `/devices/... voldmanaged=usbotg:auto` 行会让 TWRP 把 `/dev/block/*` 展开成大量假卷，已注释掉。

**MTP 与 USB Storage**：recovery 的通用 init 只创建 `ffs.adb` 和 `ffs.fastboot`，没有 MTP。`init.recovery.qcom.rc` 在 `on boot` 里先创建 configfs 的 `ffs.mtp` 和 `mass_storage.0`，再 mount FunctionFS 到 `/dev/usb-ffs/mtp`，并在 `sys.usb.config=mtp,adb` / `mass_storage,adb` 时绑定 `f1`/`f2`。USB Storage 使用 `mass_storage.0` 的 configfs LUN 路径，不依赖 MTP。`tw_mtp_enabled` 的默认值是 1（`data.cpp`），开机时由 `twrp.cpp` 自动启动 MTP；设置只保存在 `/sdcard/Fox/.foxs`，不从镜像里写死。

**USB Storage 退出后 MTP 不恢复**是 TWRP 自身的问题：切换 USB 配置时 MTP 子进程会收到 FunctionFS 的 DISABLE（`errno 108`）退出，但父进程的 `mtppid` 没有清掉，`usb_storage_disable()` 再调用 `Enable_MTP()` 时直接返回“MTP already enabled”，于是按钮还亮着但 MTP 已经没了。设备树用主题覆盖修：`recovery/root/vendor/etc/mount-usb-mtp.xml` 在 USB 页的三个退出动作里，于 `unmount usb` 后加 `stopmtp`、等 500 ms、再 `startmtp`，由 `init.recovery.qcom.rc` 的 `on fs` 复制到 `/twres/pages/mount.xml`。代价是退出 USB Storage 一定会把 MTP 打开（即使进去前是关的）。**不要用 Fox FIFO 的 `mtp enable`（`/system/bin/foxin`）做测试**：dispatcher 会打开 `/system/bin/foxout` 写结果，如果不同时读取，写 FIFO 会阻塞 GUI 动作线程，屏幕看起来卡死；MTP 请走界面。

**主题字体与启动页**：橙狐主题在 ramdisk 的 `/twres`。中文语言包 `zh_CN.xml` 会把 `fixed`、`keylabel-longpress` 等几乎所有字体资源强制替换成 `wqy-microhei.ttf`（比例字体），主题里换字体不会生效。TWRP 的终端按固定格宽逐格绘制（格宽取 `measureEx("N")`），键盘 longpress 小符号按字宽右对齐，遇到比例字体就会出现字母挨太近/错位、小符号位置不齐。设备树自带一份改过的 `zh_CN.xml`（只把 `keylabel-longpress` 和 `fixed` 指向 `SarasaMonoSC-Regular.ttf`），并带上 Sarasa Mono SC Regular（中文等宽，25.6MB）；`init.recovery.qcom.rc` 在 `on fs` 把两者复制到 `/twres/languages/` 和 `/twres/fonts/`。代价是 ramdisk 增加约 25.6MB，镜像内容约 93MB（分区 100MB）。启动页由 `main.xml` 的 `tw_clear_destination` 决定：主题里的 `menu` 实际是文件管理的选项弹层，不是主菜单；本设备改为 `advanced`，开机进“高级”tab。中文语言包还把 `mtp_enabled` 误翻成“找不到 Media 存储。”，设备树里的 `zh_CN.xml` 已改成“MTP 已启用”。

**设置持久化**：橙狐把设置保存在 `/sdcard/Fox/.foxs`，并在 `/persist/.foxs` 留一份备份。本机 `/data` 是 f2fs，挂载参数含 `checkpoint=disable:0`，`sync(2)` 只做异步回写、不提交检查点；重启前刚写下的 `.foxs` 会在下一次启动时被文件系统回滚，表现为“设置重启后全部丢失”。源码补丁两处：`TWFunc::tw_reboot()` 在 `DataManager::Flush()` 之后对 `/data` 调用 `syncfs()`（f2fs 会执行 `f2fs_sync_fs(wait=1)` 并写 checkpoint），保证设置真正落盘；主题勾选写值改为 `persist=1`，因为部分设置变量（如 `fox_boot_*`）既不在 `vars.xml` 也不在默认持久化表里，原写法只写内存。补丁见 `patches/0001-fox-settings-persistence.patch`。设置页的勾选状态在进入页面时由 `SetPageFocus()` 从 `DataManager` 重新读取，不需要额外改列表刷新。

**AVB2.0**：`vendorsetup.sh` 打开 `OF_SUPPORT_VBMETA_AVB2_PATCHING=1`，设置/高级/安装页出现“禁用 vbmeta AVB2.0”。它修改 `vbmeta_a/b` 和 `vbmeta_system_a/b` 的 flags，可手动执行，或在刷 ROM 后按开关执行；默认不会自动改。`BOARD_AVB_ENABLE` 只是用测试密钥给 recovery 签名，不是绕过 AVB。`OF_PATCH_AVB20` 在 A/B 设备上被源码排除，不适用。

**解密**：userdata 使用 FBE v2（`inlinecrypt_optimized` 加 `wrappedkey_v0` 硬件包装密钥），并开启 metadata 加密。解密依赖 vendor 的安全服务：`qseecomd` 注册完监听器后，再启动 Keymaster 4.1、Gatekeeper 和 KeyMint。服务定义沿用原厂 vendor 的 rc 文件，启动顺序写在 `init.recovery.qcom.rc`。

**RPMB**：KeyMint 对带抗回滚属性的 key 需要访问 UFS RPMB（`/dev/0:0:0:49476`，well-known LUN 0xC144）。原厂 vendor 的 `/etc/ueventd.rc` 里有规则 `/dev/0:0:0:49476 0600 system system`，recovery 的 `/vendor/etc/ueventd.rc` 也加上这条（节点创建时生效）；`init.recovery.qcom.rc` 里再 `chown system system` + `chmod 0660` 兜底。这个节点默认是 `0600 root:root`，而 qseecomd 启动后会降到 system 用户；漏掉时会打印 `Unable to open ... error no: 13`，KeyMint 的 `begin` 返回 `-8 INCOMPATIBLE_BLOCK_MODE`，metadata 解密失败。

**VNDK**：qseecomd、Keymaster、KeyMint 等 HIDL 服务通过各自 rc 里的 `setenv LD_LIBRARY_PATH` 优先使用 `/vendor/lib64/vndk-v32` 下的 Android 12 VNDK 基础库（libcrypto、libbase、libcutils、libhidlbase 等）；AIDL 服务中的 misight 保持系统库；震动服务使用 vndk 目录里改名后的 `libu32.so`（v32 libutils），系统 `libbinder_ndk` 仍用系统 libutils，避免 `String16` 等符号冲突。

**震动**：ROM 自带的 AIDL vibrator HAL（实例 `IVibrator/vibratorfeature`）。根因是 `Vibrator` 构造函数里的 `android::Thread::run()`：Android 12 的 libutils 用 `incStrong`，Android 16 用 `incStrongRequireStrong`，后者要求对象已有强引用，厂商代码没有，于是 abort。修复方式是把 v32 libutils 的 SONAME 改成 `libu32.so`，并把厂商服务二进制的 NEEDED 从 `libutils.so` 改成 `libu32.so`；系统 `libbinder_ndk` 仍用系统 libutils，两份库共存。服务 rc 里给 `vibratorfeature-hal-service` 单独设置 `LD_LIBRARY_PATH` 指向 `/vendor/lib64/vndk-v32`。HAL 现在常驻并注册成功。

## 从官方固件取文件

主要来自 `yudi-ota_full-OS3.0.6.0.VMHCNXM-user-15.0-7b73783799.zip`；boot HAL 的 9 个文件来自 `yudi-ota_full-OS3.0.306.3.WMHCNXM-user-16.0-b255c0d484-2in1-Root.zip`：

- 306.3 包没有 payload，`super.zst` 解压得到 `super.img`，用 `lpunpack -p vendor_a -p system_ext_a super.img <目录>` 取出逻辑分区；
- erofs 分区可以用 `dump.erofs --path=<路径> --ls` 查看目录，用 `fsck.erofs --extract=<目录>` 整体解开；
- vendor 服务的依赖用 `readelf -d` 逐层查找；`qseecomd` 运行时用 dlopen 加载的监听器库，在二进制里搜索 `.so` 字符串找出；
- 震动效果文件来自 vendor 分区的 `/firmware`（187 个文件），ADSP 固件来自 modem 分区的 `/image/adsp.*`（26 个文件）。

## 许可证与第三方

- 本仓库的代码（设备树配置、ramdisk 覆盖、主题覆盖、补丁）采用 **GNU GPL v3.0**，见 `LICENSE`。OrangeFox/TWRP 本体同样是 GPL-3.0，本仓库不声称拥有它们的版权。
- `recovery/root/vendor/etc/SarasaMonoSC-Regular.ttf` 是 Sarasa Gothic（Sarasa Mono SC），版权归 Renzhi Li（Belleve Invis）等，采用 **SIL Open Font License 1.1**，许可证全文见 `licenses/SarasaGothic-OFL.txt`。
- `recovery/root` 下的小米厂商二进制、库和固件来自小米官方 ROM，版权归小米，**不在 GPL 许可范围内**。它们仅用于在对应设备上运行 recovery；如果你没有该设备/ROM 的使用权，请从本仓库删除这些文件，并按 `proprietary-files.txt` 从你自己的官方包中提取。
- `prebuilt/kernel` 是原厂 boot 镜像里的内核，版权归小米。

## 参考

- [TWRP](https://github.com/TeamWin/android_bootable_recovery)、[OrangeFox](https://gitlab.com/OrangeFox)：构建系统和变量文档
- 小米平板 6 Pro（liuqin）的 [TWRP 12.1 树](https://github.com/ymdzq/device_xiaomi_liuqin-TWRP) 和 [TWRP 16 树](https://github.com/lanweikayu/device_xiaomi_liuqin-TWRP-16)：同平台设备，用于对照核实，没有直接复制

## 维护者

- OneFeiFan（[github.com/OneFeiFan](https://github.com/OneFeiFan)）
- 欢迎提 issue/PR；提交前请说明设备/ROM 版本和复现步骤。
