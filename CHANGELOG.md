# 更新日志

## R12.0（2026-11-07，本地构建）

第一个版本。

- 设备树：从零编写，分区布局和初始配置取自官方 OS3.0.6.0 完整包。
- 解密：FBE v2 和 metadata 加密，使用原厂的 qseecomd、Keymaster 4.1、KeyMint 和 Gatekeeper。
- 槽位：使用原厂的 HIDL 1.2 boot HAL，不再编译高通 bootctrl。
- fastbootd：加入原厂 health 服务后，USB 能正常初始化。
- 震动：使用 ROM 自带的小米震动 HAL，配合改名的 Android 12 libutils。
- 界面：中文主题，终端和键盘使用 Sarasa Mono SC 的 GBK 子集。
- 修正：主题勾选的设置重启后丢失。
- 修正：下拉面板里 MTP 提示的误译。
- 修正：recovery 里没有 SPU 时 Gatekeeper 拒绝图案、PIN 和文本密码（`verify_legacy` 返回 `-45`）。启动时设置 `vendor.gatekeeper.disable_spu=true`，图案和 4 位 PIN 解密通过。
- 修正：RPMB 节点权限重复设置，统一由 `vendor/etc/ueventd.rc` 设为 `0660 system system`。
- 关闭：USB Storage。设备只有一个 USB-C 口，无法同时接 OTG 存储和电脑，文件传输使用 MTP。
- 清理：删除 configfs 的 `mass_storage` function 和 legacy `android_usb` init 规则；ADB/MTP 继续走 configfs。
- 修正：擦 metadata 前先真正格式化 data，避免留下没有 metadata 密钥的密文 userdata；普通双清仍然跳过 `/data/media`。
- 修正：格式化 data 前先停 MTP，避免 `dmctl delete userdata` 报 busy、`make_f2fs` 返回 255。
- 修正：OTG 挂载时关闭 MTP 不再把 USB 从 host 踢回 device；拔出 OTG 后立即恢复 device 和 ADB。
- 修正：双清/格式化后“高级”页的列表项保持中文，不再需要重启 recovery。
- 新增：支持统一锁屏的 clone profile（例如 XSpace/平行空间）自动解密；父用户认证后通过 profile key 派生该用户的随机密码。
- 精简：去掉 45 MB 的预编译内核，`prebuilt/kernel` 改为 0 字节占位文件；ADSP 固件改为从 modem 分区链接，字体改为子集，recovery 根目录从约 93 MB 降到约 49 MB。

验证：启动、触摸、震动、电池、ADB、MTP、中文显示、设置保存和异常重启后的写入都已在实机上验证。解密验证了无锁屏、图案、4 位 PIN、文本密码、多用户和统一锁屏 profile。刷入 zip 和 sideload 只用测试 zip 验证；备份恢复验证了 boot 和 data 的备份/恢复，super 验证了备份与 digest 校验；双清验证了保留 `/data/media` 的普通路径和含 metadata 的整分区格式化，格式化后系统能重新加密并正常开机；USB OTG 验证了扩展坞/NTFS 的挂载和读取，拔出后 ADB/MTP 恢复；fastbootd 验证了 `getvar`、`reboot` 和刷写 `recovery_a`。USB Storage 已在设备树关闭。完整状态见 [README](README.md#功能状态)。
