# 小米平板 6 Max 14（yudi）OrangeFox Recovery 设备树

小米平板 6 Max 14（代号 yudi）的 OrangeFox Recovery 设备树，基于 OrangeFox 的 fox_16.0 分支（Android 16）。

这棵树从零写成。分区布局和初始配置取自小米官方完整包，厂商服务和库取自 ROM，每个文件的来源和校验值见 [proprietary-files.txt](proprietary-files.txt)。

## 功能状态

| 功能 | 状态 | 说明 |
| --- | --- | --- |
| 启动、触摸、震动 | 已验证 | 两个 recovery 分区刷入同一镜像都能启动 |
| 电池、充电状态、CPU 温度 | 已验证 | |
| ADB、MTP | 已验证 | MTP 在 Windows 上双向复制过文件 |
| 中文主题和字体 | 已验证 | |
| 设置重启后保留 | 已验证 | 需要打 [补丁](patches/README.md) |
| 异常重启后写入不丢失 | 已验证 | 用 SysRq 强制重启测试 |
| 解密 data | 已验证 | 无锁屏、图案、4 位 PIN、文本密码和多用户都已验证 |
| 刷入 zip | 部分验证 | 只用测试 zip 验证过脚本会执行；刷入完整 ROM 未验证 |
| 备份和恢复 | 部分验证 | boot、data 恢复通过；super 备份和 digest 校验通过，super 恢复未验证。data 备份不含内部存储；TWRP 普通双清不会主动删除 user 0 凭据，想清锁屏用 Format Data；非 0 用户凭据随备份恢复 |
| ADB sideload | 部分验证 | 测试 zip 通过；退出后 ADB 恢复 |
| fastbootd | 部分验证 | `getvar`、`reboot` 正常；已通过 fastbootd 刷写 `recovery_a`，逻辑分区刷写未验证 |
| 读取和切换槽位 | 部分验证 | 切换生效；目标槽没有系统时会停在 fastboot，见[已知问题](docs/known-issues.md#另一槽没有系统时切槽会停在-fastboot) |
| USB Storage | 已关闭 | 设备只有一个 USB-C 口，无法同时接 OTG 和电脑；文件传输用 MTP |
| USB OTG | 已验证 | VIA 扩展坞/NTFS 挂载和读取通过；拔掉硬盘后 ADB/MTP 恢复；写入未单独验证 |
| 格式化 data / 双清 | 已验证 | 普通双清保留 `/data/media`，TWRP 也不主动删除 user 0 凭据文件；要清锁屏和内部存储用 Format Data。含 metadata 的整分区格式化后系统能重新加密并开机 |
| 分区修复和调整 | 未验证 | 属于破坏性操作 |
| 禁用 vbmeta AVB2.0 | 未验证 | 菜单存在，未实际执行 |

每个功能的工作方式见 [功能说明](docs/features.md)，测试方法和通过标准见 [验证清单](docs/verification.md)。

## 兼容性

- **机型**：小米平板 6 Max 14（yudi）。
- **系统**：在 OS3.0.306.4（Android 16）上验证。解密依赖系统版本和安全补丁级别，换用其他版本的 ROM 前，先按 [功能说明](docs/features.md#解密) 检查。
- **内核**：recovery 不带内核，使用 boot 分区的内核启动。目前在 5.10.272 的自编 GKI 内核上验证过；其他内核只要保持与原厂相同的模块接口（KMI），理论上都能启动。

## 刷入与回退

recovery 镜像不带内核，不能用 `fastboot boot` 临时启动，只能刷入 recovery 分区。

```sh
adb reboot bootloader
fastboot getvar current-slot                 # 先只刷当前槽位
fastboot flash recovery_a recovery.img       # 当前槽位是 b 时改为 recovery_b
fastboot reboot recovery
```

确认能正常启动后，再刷另一个槽位。

回退时刷回原厂 recovery。它在官方完整包的 payload 里，用 payload 解包工具可以取出 `recovery.img`。

## 文档

| 文档 | 内容 |
| --- | --- |
| [功能说明](docs/features.md) | 每个功能的工作方式和限制 |
| [已知问题](docs/known-issues.md) | 已知的问题和处理办法 |
| [构建](docs/building.md) | 拉取源码、打补丁、编译 |
| [验证清单](docs/verification.md) | 刷入后的测试方法和通过标准 |
| [更新日志](CHANGELOG.md) | 各版本的变化 |
| [补丁说明](patches/README.md) | 对 OrangeFox 源码的修改 |
| [参考资料](docs/references.md) | 源码、固件和对照用的设备树 |
| [开发记录](docs/notes/2026-11-05-recovery-build.md) | 调研和实验的过程 |

## 参考

本设备树基于 OrangeFox、TWRP 和 AOSP Android 16 的源码，并对照了 liuqin、mondrian 等设备树：

- [OrangeFox fox_16.0 manifest](https://gitlab.com/OrangeFox/Manifest/-/tree/fox_16.0)
- [OrangeFox recovery](https://gitlab.com/OrangeFox/bootable/recovery)
- [TWRP recovery](https://github.com/TeamWin/android_bootable_recovery)
- [AOSP Android 16 build](https://android.googlesource.com/platform/build/+/refs/tags/android-16.0.0_r1)
- [其他设备树（liuqin、mondrian 等）](docs/references.md#其他设备树)
- [完整参考资料](docs/references.md)

## 许可证

设备树配置、ramdisk 覆盖文件、主题覆盖文件和补丁采用 GNU GPL v3.0，见 [LICENSE](LICENSE)。OrangeFox 和 TWRP 本身同样是 GPL-3.0，本仓库不主张它们的版权。

`recovery/root` 下的小米二进制、库和固件版权归小米，不在 GPL 许可范围内。它们大部分取自小米官方完整包；boot HAL、VNDK v32 库、`libdrm.so` 和 `libu32.so` 对应的原始 libutils 取自一个第三方重打包的 306.3 包，没能与官方校验值核对，详见 [参考资料](docs/references.md#设备与固件)。这些文件只用于在对应设备上运行 recovery。

Sarasa Mono SC 字体采用 SIL Open Font License 1.1，见 [licenses/SarasaGothic-OFL.txt](licenses/SarasaGothic-OFL.txt)。
