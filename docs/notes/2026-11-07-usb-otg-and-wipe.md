# 2026-11-07：USB OTG、USB 清理和双清回归

这次改动集中在 USB host/device 切换、USB Storage 死代码清理，以及 data/metadata 擦除路径。设备上的最终测试镜像是 `recovery-mtp-format-fix.img`（SHA256 `a3e3dc240e486f1de4688604cbd80a767b1b88cf5ee3e1c00d73d422e2cd5ff2`）。

## USB OTG 无法挂载

现象：插上 USB-C 扩展坞（VIA hub + RTL8153 网卡 + RTL9210B NTFS 硬盘）后，内核能短暂枚举出 `sdg`/`sdg1`，但 `mount.ntfs` 报 13/11，随后 USB 角色被切回 device。旧的 12.1 recovery 用同一个扩展坞能正常识别。

根因：新设备树的 `init.recovery.qcom.rc` 在每次 `sys.usb.state=adb` 时都无条件写 `mode peripheral`。OTG 自动挂载会调用 `Toggle_MTP(false)`，把 `sys.usb.config` 从 `mtp,adb` 改成 `adb`，触发这条规则，把已经切到 host 的 USB 又踢回 device。`dmesg` 里能看到 UCSI 的 `ucsi_handle_connector_change → usb_role_switch_set_role` 调用。

修复：

- 设备树 `376a639`：用 `sys.usb.mode_ready` 只在第一次 device 状态写 peripheral；后续 MTP 切换不再改 mode。
- 设备树 `e5b4e3a` + recovery `7ccfcff`：增加 `sys.usb.otg_active`，OTG 挂载时置 1、卸载时置 0；init 在 0 时立即恢复 peripheral，拔掉硬盘后 ADB/MTP 不用等 UCSI 自己恢复。

验证：扩展坞能挂载并读取文件；拔掉硬盘后 dmesg 快速出现 `HOST → DEVICE`，`otg_active=0`、`mode=peripheral`，ADB 立即恢复。

## USB 清理

`OF_ENABLE_USB_STORAGE=0` 后，设备树里与 USB Storage 相关的路径都不可达，已删除：

- `init.recovery.qcom.rc` 的 `mass_storage.0` function 和 `mass_storage,adb` 规则；
- 设备树新增空的 `init.recovery.usb.rc`，覆盖通用 recovery 的 legacy `/sys/class/android_usb` 规则；本机是 configfs 模式，这些节点不存在；
- 仅用于 USB Storage 的 `twres/pages/mount.xml`。

设备树提交 `d887707`、`8eb93da`。

## Format Data / metadata 双清失败

第一次执行 `fox wipe cache metadata data` 失败：

```
dmctl delete userdata: Device or resource busy
make_f2fs ...: In use by the system! (255)
```

原因：MTP 正在导出 `/data/media`，一直占着 dm-userdata；`Wipe_Encryption()` 在 `dmctl`/`make_f2fs` 前没有停 MTP。metadata 保护因此中止，但 data 和 metadata 都没有损坏，重启后仍能解密。

修复（recovery `0e806b9`）：`Wipe_Encryption()` 开头 `Toggle_MTP(false)`，退出时按原状态恢复。

重跑结果：

- `Disabling MTP` → `running dmctl before formatting` → `format successful`；
- metadata 只格式化一次，日志 `metadata was already formatted while clearing the data key; skipping the second wipe`；
- `Wiped /metadata`、`Wiped /data`；
- 重启能正常进入设置向导；系统重新建立 metadata key 和 dm-7，recovery 再次启动 `Data successfully decrypted`。

普通双清 `fox wipe cache data`（不含 metadata）也验证通过：`/data/media/0/wipe-keep-test.txt` 保留，`/data/wipe-delete-test.txt` 删除；dm-7 和加密状态不变，重启能进入向导。

## 其他回归

- fastbootd：`is-userspace=yes`、`product=yudi`、`current-slot=a`，`fastboot reboot recovery` 正常。
- ADB sideload：CLI 和手动 UI 两条路径都通过；页面停在“正在启动侧载”是在等电脑 `adb sideload`，不是卡死；退出后 ADB 恢复，MTP 不自动恢复。
- MTP：Windows 双向复制通过；自启日志有 `[MTP] Starting MTP`，Windows 可能不立即刷新。

## 相关提交

- device/xiaomi/yudi：`376a639`、`e5b4e3a`、`d887707`、`8eb93da`
- bootable/recovery：`e825a72`、`7ccfcff`、`0e806b9`、`5a32417`
- system/vold：`45f2030`

对应的 OrangeFox 补丁导出在 `patches/`，应用顺序见 [patches/README.md](../../patches/README.md)。
