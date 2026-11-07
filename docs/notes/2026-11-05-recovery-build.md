# 2026-11-05 recovery 构建记录

记录从 2026-11-05 开始，2026-11-06 补入了数据耐久性、震动确认、仓库体积清理和 Gatekeeper 密码修复。

这份记录保留调研过程、实验结论和当时的判断，供后续维护参考。功能说明和已知问题分别写在 `docs/features.md` 和 `docs/known-issues.md`。

## 设备树来源

设备树从零编写。分区大小、动态分区布局和初始设置取自官方 OS3.0.6.0.VMHCNXM 完整包。boot HAL、libdrm、VNDK v32 库和 `libu32.so` 的原始 libutils 取自第三方重打包的 OS3.0.306.3.WMHCNXM-2in1-Root.zip。没有找到官方 306.3 包，无法与官方校验值核对。

编写时对照了小米平板 6 Pro（liuqin）的两棵 TWRP 树和 LineageOS 的 sm8450-common、sm8550-common、mondrian 设备树，没有直接复制。完整列表见 `docs/references.md`。

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

反查厂商库发现 `libqtikeymint` 和 `libqtikeymaster4` 读取的是 `ro.build.version.release`、`ro.build.version.security_patch` 和 `ro.vendor.build.security_patch`，不是 boot 头部。系统侧的值是 release 16、security patch 2026-08-01、vendor patch 2026-02-01。改 BoardConfig 后解密通过。后来实测 recovery 的 `ro.build.version.release` 是 12、`release_or_codename` 是 16，当前组合仍可解密，见下文。

boot 头部仍然用 `BOARD_MKBOOTIMG_ARGS` 写成 12.0.0 / 2025-09，与原厂 boot 一致。`BOOT_SECURITY_PATCH` 会被这组参数覆盖。

## 设置持久化

最初的判断是 f2fs 的 `checkpoint=disable` 导致写入被回滚，于是在 `tw_reboot()` 里加了 `syncfs()`。P0 实验撤掉 syncfs 后，设置和 marker 文件仍能跨重启保留，说明 syncfs 不是必需的。

真正关键的是 `gui/listbox.cpp` 的 `persist=1`。部分主题勾选变量不在 `vars.xml` 或默认持久化表里，原来的写法只写内存。

主 `recovery.fstab` 的 `/data` 行去掉了 `checkpoint=fs` 和 `fsync_mode=nobarrier`，但 TWRP 会解析 vendor 分区的 fstab 作为 `additional.fstab`，它的 /data 行覆盖主 fstab。vendor fstab 的 /data 行以 `checkpoint=fs` 和 `fsync_mode=nobarrier` 结尾；当前 `/proc/mounts` 里是 `checkpoint_merge` 和 `fsync_mode=nobarrier`，没有 `checkpoint=disable`。

正常重启会卸载 `/data`，f2fs 在卸载时补写检查点。为了覆盖异常重启，用 SysRq 强制重启做了测试：`echo test > /sdcard/durability-test && sync`，然后 `echo b > /proc/sysrq-trigger`；重新进入 recovery 后文件仍然存在。如果以后 `/proc/mounts` 出现 `checkpoint=disable`，需要再处理。

## VNDK 和震动

qseecomd、Keymaster、KeyMint 等 HIDL 服务最初把 `/vendor/lib64/vndk-v32` 放在库搜索路径最前面，整套使用 Android 12 VNDK。2026-11-07 做了精简：只保留系统里没有的 9 个库（KeyMint 3 个、HIDL memory 2 个、libdmabufheap、libhidlmemory、libion、libxml2），移到 `/vendor/lib64`；9 个和系统重复的核心库删除，服务 rc 里的 `setenv LD_LIBRARY_PATH` 也去掉，默认搜索路径就能找到。需要实机回归解密、槽位、fastbootd 和震动。

震动 HAL 最初用 Android 12 的小米厂商二进制。它在 Android 16 的 libutils 下会因为 `incStrongRequireStrong` 崩溃；当时的修复方式是把 v32 libutils 的 SONAME 改成 `libu32.so`，把厂商服务的 NEEDED 改成 `libu32.so`，两份 libutils 共存。

2026-11-07 已改为从源码构建高通开源的 AIDL vibrator HAL，通过 `qcom-hv-haptics` 的 FF 输入设备驱动马达。小米服务、misight、`libu32.so`、`libtinyalsa.so` 和 49 个 `*_RTP.bin` 效果文件都已删除，这处厂商二进制修改也一并去掉。

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

## Gatekeeper、密码类型和 RPMB（2026-11-06）

用户设置图案锁屏后，recovery 能识别出 `password type: pattern`，但 Gatekeeper 拒绝验证。logcat 里依次出现 `SPU is not available`、`IsSbKmAvailable failed`、`GatekeeperHalDevice: verify_legacy`、`ret: -45`，TWRP 日志停在 `GateKeeper response error` 和 `failed to unwrapSyntheticPasswordBlob`。

没有锁屏密码时不会触发这个问题：TWRP 直接使用 `default-password`，跳过 Gatekeeper。设置图案、PIN 或文本密码后，才需要 Gatekeeper 验证。高通这个 HAL 在没有 SPU 的 recovery 里会先尝试 SPU，失败后走 `verify_legacy` 并返回 `-45`。

在 recovery 里执行 `setprop vendor.gatekeeper.disable_spu true` 并重启 `gatekeeper-1-0` 后，图案解密通过。随后把这一行写进 `init.recovery.qcom.rc` 的 `on fs` 段，做成永久修复。最终镜像里 `getprop vendor.gatekeeper.disable_spu` 为 `true`。

用户随后把锁屏改成 4 位数字密码。recovery 日志显示 `password type: PIN`，`GateKeeper status ok`，`User 0 Decrypted Successfully!`。纯数字密码在 Android 里就是 PIN，和文本密码、图案走同一条 synthetic password + Gatekeeper 路径。之后用户又实测了文本密码，也能正常解密。

多用户也测了：在系统里临时创建用户 10，启动后回 recovery，用用户 0 的文本密码解密，日志显示 `User 0 Decrypted Successfully` 后自动继续 `User 10 Decrypted Successfully`，两个 `twrp.user.*.decrypt` 都是 1。测完已在系统里删除用户 10。对应源码是 `Decrypt_Device()` 在用户 0 解密成功后遍历其他未解密用户（`partitionmanager.cpp:2385-2401`）。

data 备份也做了：`fox backup data --name data-test --storage internal`，10007MB 数据、8 个分片、总计约 10070MB，45 秒完成；`data.f2fs.win000.sha2` 与实际 `sha256sum` 一致。

super 备份同样做了：`fox backup super --name super-test --storage internal`，11264MB，26 秒完成，生成 `super.emmc.win` 和 `.sha2`；`sha256sum super.emmc.win` 与 `.sha2` 一致。data 和 super 都只验证了备份与 digest，没有做恢复。

用 `twrp decrypt` 命令行测了一次，从执行到 `Data successfully decrypted` 约 2.8 秒。当前 PIN 凭据的 scrypt 参数是 N=2048、r=8、p=2；scrypt 和 Gatekeeper 验证是正常开销。默认密码跳过这两步，所以几乎是立即解密。

另外发现 recovery 的 `ro.build.version.release` 实际是 12，`release_or_codename` 是 16；系统侧两个值都是 16。当前这组值可以正常解密，文档已按实际 `getprop` 结果改写，不再声称 `release` 必须等于系统。

RPMB 节点 `/dev/0:0:0:49476` 原来在 `ueventd.rc` 设为 `0600 system system`，init 里又 `chown/chmod 0660`。ueventd 在 early-init 冷启动时就加载 `/vendor/etc/ueventd.rc`，早于 `on fs`，所以把规则改成 `0660 system system`，删掉 init 里的 `wait/chown/chmod` 三行。实机验证节点权限是 `crw-rw---- system system`。

之后用 fastbootd 把同一个 recovery 镜像刷入 `recovery_a`，重启回 recovery 正常，说明 fastbootd 的刷写路径可用。

USB Storage 在没有外接存储时点击启用会提示“无法定位存储设备”。源码里 `usb_storage_enable()` 先 `Toggle_MTP(false)`，再 `Find_Next_Storage("", true)`；后者会跳过带 `Has_Data_Media` 的 `/data`，只找可移动存储。失败后错误处理又调用 `Enable_MTP()`，所以电脑会断联一次再以 MTP 重连。UPSTREAM 的 `usb_storage_disable()` 里本来就有 `Enable_MTP()`，但因为 MTP 子进程的 `mtppid` 没清掉，实际会返回“MTP already enabled”，所以之前退出 USB Storage 后 MTP 不恢复；设备树的 `twres/pages/mount.xml` 覆盖用 `stopmtp` + 500ms + `startmtp` 修过这个问题。

这台设备只有一个 USB-C 口，无法同时接 OTG 存储和电脑，且 TWRP 不导出内部 `/data/media`，所以 USB Storage 实际不可用。最终把 `OF_ENABLE_USB_STORAGE` 设为 0，并从设备树删除 `twres/pages/mount.xml` 覆盖；关闭后 UI 不再显示 USB Storage，源码里的 MTP 重开逻辑也不会被调用。

## 测试结论

卡刷、备份恢复、ADB sideload 和 MTP 双向传输都在实机上验证通过。备份恢复用 boot 分区做了 sha256 对比。sideload 退出后 adb 能自动恢复，但 MTP 需要手动打开。

后续的 data 恢复、普通双清/含 metadata 的整分区格式化、USB OTG 和 USB 清理见 [2026-11-07 的笔记](2026-11-07-usb-otg-and-wipe.md)。

Fox RPC 的截图只能截到起始页，终端和其他页面的显示只能靠肉眼在设备上确认。
