# 2026-11-05 recovery 构建记录

这份记录保留调研过程、实验结论和当时的判断，供后续维护参考。功能说明和已知问题分别写在 `docs/features.md` 和 `docs/known-issues.md`。

## 设备树来源

设备树从零编写。分区大小、动态分区布局和初始设置取自官方 OS3.0.6.0.VMHCNXM 完整包。boot HAL、libdrm、VNDK v32 库和 `libu32.so` 的原始 libutils 取自第三方重打包的 OS3.0.306.3.WMHCNXM-2in1-Root.zip。没有找到官方 306.3 包，无法与官方校验值核对。

## boot 控制

第一版尝试编译 LineageOS 的 bootctrl 和 gpt-utils，需要内核 UAPI 头。设备由 boot 分区的内核启动，树里没有内核源码，方案被撤销。

最终使用原厂 vendor 里的 HIDL 1.2 boot HAL。服务名是 `vendor.boot-hal-1-2`，实现库和依赖放在 ramdisk 的 `/vendor/lib64`。原厂 rc 缺 `seclabel u:r:recovery:s0`，直接照抄会导致所有 vendor 服务启动失败，后来统一补上 `disabled` 和 seclabel。

## 内核声明

目标是不在仓库里放 45MB 的原厂内核。原厂 recovery 头部 `kernel_size` 本来就是 0，引导程序用 boot 分区的内核。

第一次尝试 `TARGET_NO_KERNEL := true` 并删除 `prebuilt/kernel`。构建能跑完，但 OrangeFox 打包脚本拿到的 `INSTALLED_RECOVERYIMAGE_TARGET` 是空的，不生成 `recovery.img`。

Android 16 的 recovery 构建会通过 UFFD GC 的 sysprop 依赖去内核里取版本号。在 `device.mk` 设 `PRODUCT_ENABLE_UFFD_GC := false` 后，这个依赖消失。

但 0 字节的 `prebuilt/kernel` 仍然在 `check_vintf_all` 的内核配置提取处失败。这个设备树只构建 recovery、不生成 OTA，于是在 `device.mk` 再设 `PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false`，跳过这项 OTA 检查。

最终方案：`prebuilt/kernel` 是 0 字节占位文件，保留 `TARGET_PREBUILT_KERNEL` 和 `TARGET_FORCE_PREBUILT_KERNEL` 让 recovery 镜像目标正常定义，`BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE` 保证空内核不进镜像。构建产物头部仍是 v4、`kernel_size=0`。和上一版相比 ramdisk 只有构建时间和 fox_id 变化，刷入后启动、health、ADSP、触摸和解密正常。

## 解密和版本号

最初 recovery 头部写成 Android 16.0.0 / 2099-12，高于 ROM 的 12.0.0 / 2025-09，KeyMint 返回 `-62 KEY_REQUIRES_UPGRADE`。把头部改成与 boot 一致后仍失败。

反查厂商库发现 `libqtikeymint` 和 `libqtikeymaster4` 读取的是 `ro.build.version.release`、`ro.build.version.security_patch` 和 `ro.vendor.build.security_patch`，不是 boot 头部。系统实际值是 release 16、security patch 2026-08-01、vendor patch 2026-02-01。改 BoardConfig 后解密通过。

boot 头部仍然用 `BOARD_MKBOOTIMG_ARGS` 写成 12.0.0 / 2025-09，与原厂 boot 一致。`BOOT_SECURITY_PATCH` 会被这组参数覆盖。

## 设置持久化

最初的判断是 f2fs 的 `checkpoint=disable` 导致写入被回滚，于是在 `tw_reboot()` 里加了 `syncfs()`。P0 实验撤掉 syncfs 后，设置和 marker 文件仍能跨重启保留，说明 syncfs 不是必需的。

真正关键的是 `gui/listbox.cpp` 的 `persist=1`。部分主题勾选变量不在 `vars.xml` 或默认持久化表里，原来的写法只写内存。

主 `recovery.fstab` 的 `/data` 行去掉了 `checkpoint=fs` 和 `fsync_mode=nobarrier`，但 TWRP 会解析 vendor 分区的 fstab 作为 `additional.fstab`，它的 /data 行覆盖主 fstab。vendor fstab 的 /data 行以 `checkpoint=fs` 和 `fsync_mode=nobarrier` 结尾；当前 `/proc/mounts` 里是 `checkpoint_merge` 和 `fsync_mode=nobarrier`，没有 `checkpoint=disable`。

正常重启会卸载 `/data`，f2fs 在卸载时补写检查点。为了覆盖异常重启，用 SysRq 强制重启做了测试：`echo test > /sdcard/durability-test && sync`，然后 `echo b > /proc/sysrq-trigger`；重新进入 recovery 后文件仍然存在。如果以后 `/proc/mounts` 出现 `checkpoint=disable`，需要再处理。

## VNDK 和震动

qseecomd、Keymaster、KeyMint 等 HIDL 服务使用 `/vendor/lib64/vndk-v32` 下的 Android 12 VNDK 库。系统里同时存在 v31 和 v32，两套重复。确认所有服务都能在 v32 找到依赖后，删除了 9 个 v31 库。

震动 HAL 是 Android 12 厂商二进制。它在 Android 16 的 libutils 下会因为 `incStrongRequireStrong` 崩溃。修复方式是把 v32 libutils 的 SONAME 改成 `libu32.so`，把厂商服务的 NEEDED 改成 `libu32.so`，两份 libutils 共存。

## 主题和字体

中文语言包 `zh_CN.xml` 会把 `fixed` 和 `keylabel-longpress` 指向比例字体，终端等宽和键盘小符号都会错乱。设备树自带改过的语言包，指向 Sarasa Mono SC。

字体原来 25.6MB。用 fonttools 做 GBK 子集后是 12.8MB，覆盖约 2.2 万字符。用户实机确认中文、生僻字和全角标点显示正常。

主题覆盖文件从 `vendor/etc` 移到 `recovery/root/twres/` 对应路径。构建时设备树文件会覆盖主题，省掉开机复制。曾担心主题复制规则会反向覆盖，构建后比对暂存目录，8 个文件全部与设备树一致。

## ADSP

ADSP 固件原本 26 个文件放在 ramdisk 的 `/lib/firmware`。后来改成开机把 modem 分区的 `/image/adsp.*` 符号链接到 `/lib/firmware`，省约 24MB。

最初把 27 条 `symlink` 写死在 init 里。为了避免 modem 固件分段数变化后失配，改成一个 oneshot 服务运行 `/system/bin/link-adsp.sh`，脚本遍历 `/vendor/firmware_mnt/image/adsp.*` 并设置 `sys.adsp.links.ready`。init 用 `wait_for_prop` 等脚本完成后再写 `boot_adsp`。

## fastbootd

早期执行 `adb reboot fastboot` 后 USB 枚举消失。当时以为是 configfs 的 `f1` 还指向 adb，于是加了一条 fastboot 触发规则。实测这条规则触发得太早，fastbootd 还没建好 configfs，`UDC` 和 `f1` 都不存在，命令全部失败。

日志显示 fastbootd 启动后一直等待 `android.hardware.health@2.0::IHealth/default`，每秒重试，根本没有走到 USB 初始化。原厂 vendor 里有 `android.hardware.health@2.1-service`，把它和依赖库、VINTF 片段打进 ramdisk 并在 `on fs` 启动。那条提前触发的 fastboot 规则已删除。

修复后 fastbootd 会打开 `/dev/usb-ffs/fastboot/ep0` 并初始化 FunctionFS，设备在主机上枚举为 `18d1:4ee0`。Windows 上安装 Google USB 驱动（`android_winusb.inf`）后，`fastboot devices`、`getvar current-slot`、`getvar product` 和 `reboot recovery` 都正常。没有驱动时设备管理器显示代码 28。

## 测试结论

卡刷、备份恢复、ADB sideload 和 MTP 双向传输都在实机上验证通过。备份恢复用 boot 分区做了 sha256 对比。sideload 退出后 adb 能自动恢复，但 MTP 需要手动打开。

Fox RPC 的截图只能截到起始页，终端和其他页面的显示只能靠肉眼在设备上确认。
