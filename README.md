# 小米平板 6 Max 14（yudi）的橙狐设备树

小米平板 6 Max 14（yudi，骁龙 8+ Gen 1）的 OrangeFox Recovery 设备树，基于橙狐 fox_16.0（Android 16）。

这棵树从零写成：设置取自小米官方 OS3.0.6.0.VMHCNXM 完整包、TWRP/橙狐/AOSP 文档，boot 控制相关的专有文件取自 OS3.0.306.3.WMHCNXM 完整包，来源写在各文件的注释里。专有文件清单见 `proprietary-files.txt`。

**状态：部分验证。**已在设备上确认：OrangeFox UI 启动、boot HAL、keymaster、gatekeeper、keymint、qseecomd、logd 正常运行，电池和触控驱动已加载。解密和槽位切换仍需按下面的清单继续验证。

## 构建

需要约 150 GB 磁盘和 16 GB 以上内存。

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
mka adbd recoveryimage
```

产物是 `out/target/product/yudi/OrangeFox-*.img` 和 `recovery.img`。

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
| 触控 | 点击位置准确；如果左右或上下反了，见下文"触控方向" |
| ADB | 电脑上 `adb shell` 能连上 |
| 分区挂载 | 挂载菜单里能勾选 system、vendor 等逻辑分区 |
| 槽位 | `bootctl get-current-slot` 与 `fastboot getvar current-slot` 一致（当前为 0/a）。注意：QTI 的 boot HAL 报 `get-number-slots=3`，但设备实际只有 a/b 两个槽，测试时只切 0/1，切完重启到 bootloader 再确认 |
| fastbootd | 在 recovery 里执行 `adb reboot fastboot`，电脑上 `fastboot getvar is-userspace` 返回 yes |
| 解密 | 进入 recovery 后输入锁屏密码，能看到 `/sdcard` 里的文件 |
| 电池 | 状态栏显示电量 |
| 刷入卡刷包、备份和恢复 | 各做一次 |

出问题时，取 `/tmp/recovery.log` 和 `dmesg`，问题多半能从里面看出。

## 设计说明

**内核**：原厂 recovery 不带内核，由引导程序用 boot 分区的内核启动，这里保持一致。`prebuilt/kernel` 是原厂 boot 里的 5.10.236，只用来满足构建系统，不会打进镜像。实际运行时用的是 boot 分区里的内核，包括自编内核；只要它和原厂内核的模块接口兼容就能工作。

**boot 控制**：A/B 槽位直接用原厂 vendor 里的 HIDL 1.2 boot HAL（`android.hardware.boot@1.2-service`），不再编译 LineageOS 的 bootctrl 和 gpt-utils，也不需要内核头文件。服务名是 `vendor.boot-hal-1-2`，由 `init.recovery.qcom.rc` 在 `on fs` 里显式启动；实现库 `android.hardware.boot@1.0-impl-1.2-qti.so` 和依赖库都放在 ramdisk 的 `/vendor/lib64`。

**屏幕方向**：面板原生是 2880x1800 横屏。原厂系统把它旋转 270 度作为自然方向，橙狐也一样，界面是 1800x2880 的竖屏。触摸坐标按 270 度换算：交换 x 和 y，再翻转 x。

**驱动**：显示、电池、振动、USB 和加密相关的驱动都在 vendor_boot 的 recovery 模块列表里，第一阶段 init 会自动加载。触控驱动不在其中，由 TWRP 从 vendor_dlkm 加载 `xiaomi_touch.ko` 和 `nt36532_touch.ko`。触控固件放在 ramdisk 的 `/lib/firmware`，因为 `/vendor/firmware` 之后会被 ADSP 固件绑定挂载覆盖。

**ADSP 和电池**：照搬原厂 recovery 的做法，先加载 6 个音频和 ADSP 模块，挂载 modem 分区里的 ADSP 固件，再启动 ADSP。电池驱动要等 ADSP 起来才有数据。

**解密**：userdata 使用 FBE v2（`inlinecrypt_optimized` 加 `wrappedkey_v0` 硬件包装密钥），并开启 metadata 加密。解密依赖 vendor 的安全服务：`qseecomd` 注册完监听器后，再启动 Keymaster 4.1、Gatekeeper 和 KeyMint。服务定义沿用原厂 vendor 的 rc 文件，启动顺序写在 `init.recovery.qcom.rc`。KeyMint 依赖 Android 12 时代的 VNDK 接口库，取自系统的 VNDK v31。

**版本号**：Keymaster 和 KeyMint 只允许不低于密钥创建时的系统版本和补丁级别使用密钥，所以 recovery 头部写入 `2099-12-31` 的补丁级别。

## 触控方向

触摸驱动报告的是面板原生方向的坐标。按目前的设置，点击位置应该准确。如果实测左右反了，把 `BoardConfig.mk` 里的 `RECOVERY_TOUCHSCREEN_FLIP_X` 换成 `RECOVERY_TOUCHSCREEN_FLIP_Y`；如果横竖错了，去掉 `RECOVERY_TOUCHSCREEN_SWAP_XY`。

## 从官方固件取文件

主要来自 `yudi-ota_full-OS3.0.6.0.VMHCNXM-user-15.0-7b73783799.zip`；boot HAL 的 9 个文件来自 `yudi-ota_full-OS3.0.306.3.WMHCNXM-user-16.0-b255c0d484-2in1-Root.zip`：

- 306.3 包没有 payload，`super.zst` 解压得到 `super.img`，用 `lpunpack -p vendor_a -p system_ext_a super.img <目录>` 取出逻辑分区；
- erofs 分区可以用 `dump.erofs --path=<路径> --ls` 查看目录，用 `fsck.erofs --extract=<目录>` 整体解开；
- vendor 服务的依赖用 `readelf -d` 逐层查找；`qseecomd` 运行时用 dlopen 加载的监听器库，在二进制里搜索 `.so` 字符串找出。

## 已知风险

- **解密待验证**：这是最可能出问题的一项。现在的系统是移植的 HyperOS 3（Android 16），密钥由 KeyMint 创建。目前 UI、keymaster/keymint 服务都正常，但无密码自动尝试时 KeyMint 返回 `-62 INVALID_KEY_BLOB`；需要在界面输入锁屏密码后复测，并取 `/tmp/recovery.log` 和 logcat 分析。
- **构建后检查依赖**：第一次构建完成后，在 `out/target/product/yudi/recovery/root` 下用 ldcheck 检查 `vendor/bin` 里的每个服务，确认没有缺失的库。
- **USB 存储的设备节点**：`twrp.flags` 里 OTG 设备写的是 `/dev/block/sdg1`，UFS 占用了 sda 到 sdf。如果实际不是 sdg，按 `/tmp/recovery.log` 修改。

## 参考

- [TWRP](https://github.com/TeamWin/android_bootable_recovery)、[OrangeFox](https://gitlab.com/OrangeFox)：构建系统和变量文档
- 小米平板 6 Pro（liuqin）的 [TWRP 12.1 树](https://github.com/ymdzq/device_xiaomi_liuqin-TWRP) 和 [TWRP 16 树](https://github.com/lanweikayu/device_xiaomi_liuqin-TWRP-16)：同平台设备，用于对照核实，没有直接复制
