# 已知问题

## sideload 后 MTP 不会自动恢复

进入 ADB sideload 再退出后，MTP 是关闭状态，电脑看不到 Internal Storage。

sideload 会切换 USB 配置。退出时 TWRP 不会重新启动 MTP。

手动执行 `fox mtp enable`，或者重新进入 recovery，可以恢复 MTP。

## 另一槽没有系统时切槽会落到 fastboot

当前这台设备的 b 槽 super 是空的。在槽位菜单切到 b 后，系统会落到 fastboot。

原因是 b 槽的 system、vendor 等逻辑分区没有内容。`recovery_b` 本身正常。

不要在这台设备上切 b。要切必须先用完整 OTA 或线刷包填好另一槽的 super，并保持 `recovery_b` 与 `recovery_a` 相同。

## 时区名不是标准 IANA 名

执行命令时会打印 `__bionic_open_tzdata` 警告。

`persist.sys.timezone=TAIST-8TAIDT` 来自主题的时区列表。recovery 的 ramdisk 没有 `/system/usr/share/zoneinfo`，bionic 找不到对应的时区数据。

时钟本身正确，不影响功能，不需要处理。

## 屏幕空闲后息屏

TWRP 会把亮度降到 0，触碰后恢复。

这不是故障。测试时先点亮屏幕。

## 开机后 1–3 秒卡顿

UI 起来后有短暂卡顿，原因还没有定位。

暂时没有处理办法。

## 依赖 ROM 版本

Keymaster、KeyMint 和 health 的行为依赖系统版本和安全补丁。

更换 ROM 后，`ro.build.version.release`、`ro.build.version.security_patch` 和 `ro.vendor.build.security_patch` 可能需要调整，否则解密会失败。详见[功能说明](features.md#解密)。

## Fox FIFO 的 mtp enable 会卡住界面

用原始 FIFO 写 `mtp enable` 时，如果没有同时读取 `foxout`，GUI 动作线程会被阻塞，屏幕看起来卡死。

使用 `fox mtp enable`，或者走界面。

## 尚未验证的功能

- 震动马达的实际触感
- USB Storage 在电脑端的读写
- USB OTG 接真实设备
- 分区修复、调整大小、更改文件系统
- 格式化 data
- 实际执行“禁用 vbmeta AVB2.0”
- 自定义锁屏密码和多用户解密
- 其他版本的启动内核
