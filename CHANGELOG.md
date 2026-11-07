# 更新日志

## R12.0（2026-11-07，本地构建）

第一个版本。设备树从零编写，分区布局和初始配置取自官方 OS3.0.6.0 完整包。

新增：

- 解密：支持 FBE v2 和 metadata 加密，使用原厂的 qseecomd、Keymaster 4.1、KeyMint 和 Gatekeeper；支持无锁屏、图案、PIN、文本密码、多用户和统一锁屏的 clone profile（例如 XSpace、平行空间）。
- 槽位：使用原厂的 HIDL 1.2 boot HAL。
- 震动：使用高通开源的 AIDL vibrator HAL，通过 `qcom-hv-haptics` 的 FF 输入设备驱动马达。
- 界面：中文主题，终端和键盘使用 Sarasa Mono SC 字体。
- USB OTG：支持扩展坞和 NTFS 硬盘，拔出后 ADB 和 MTP 立即恢复。

修正：

- Gatekeeper 在 recovery 里拒绝图案、PIN 和文本密码。
- fastbootd 卡在 USB 初始化之前。
- 主题里勾选的设置重启后丢失。
- 双清或格式化后，“高级”页的按钮变回英文。
- 下拉面板里 MTP 提示的误译。
- 恢复 data 时遇到带 immutable 标志的文件报 `extractTarFork() 255`。
- 只擦 metadata 会留下无法解密的 userdata，系统无法开机。
- 格式化 data 时因 MTP 占用而失败。
- 挂载 OTG 时 USB 被切回 device 模式，导致挂载失败。
- 拔掉 OTG 后恢复 data，分区详情刷新会尝试挂载已移除的 U 盘并报错。

调整：

- 关闭 USB Storage：设备只有一个 USB-C 口，用不上；删除了相关的 configfs 规则和旧版 USB 规则。
- RPMB 节点权限统一由 `ueventd.rc` 设置。
- VNDK：只保留系统缺少的 9 个库并放到 `/vendor/lib64`，删除 9 个和系统重复的核心库以及各服务的单独库路径。
- 精简 ramdisk：去掉 45 MB 的预编译内核（`prebuilt/kernel` 改为 0 字节占位文件）；ADSP 固件改为从 modem 分区链接；字体改为 GBK 子集。recovery 根目录从约 93 MB 降到约 49 MB。

验证范围见 [README 的功能状态表](README.md#功能状态)。
