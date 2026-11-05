# 小米平板 6 Max 14（yudi）OrangeFox Recovery 设备树

这是为小米平板 6 Max 14（代号 yudi）构建 OrangeFox R12.0 recovery 的设备树，基于 OrangeFox 的 fox_16.0 分支（Android 16）。

## 功能

设备可以启动 OrangeFox。触摸、解密、MTP、ADB、卡刷、备份恢复、ADB sideload 和中文主题字体可用。A/B 槽位控制，以及原厂的 Keymaster、KeyMint、Gatekeeper 服务工作正常。

每个功能的行为、默认值和限制见 [docs/features.md](docs/features.md)。已知问题和尚未验证的功能见 [docs/known-issues.md](docs/known-issues.md)。

## 兼容性

- 机型：小米平板 6 Max 14（yudi）
- 系统：OS3.0.306.x（Android 16）
- 槽位：A/B，`recovery_a` 和 `recovery_b` 都可以刷入
- 启动内核：boot 分区的内核，目前验证到 5.10.272

Keymaster 和 KeyMint 的版本、安全补丁必须与当前系统一致。更换 ROM 后可能需要调整，见 [功能说明](docs/features.md#解密)。

## 刷入与回退

yudi 的 recovery 不带内核，不能用 `fastboot boot` 临时启动，必须刷入 recovery 分区。

```sh
adb reboot bootloader
fastboot getvar current-slot
fastboot flash recovery_a recovery.img
fastboot reboot recovery
```

当前槽位是 b 时，把 `recovery_a` 换成 `recovery_b`。建议先只刷当前槽位，确认能启动后再刷另一个槽位。

回退时刷回原厂 recovery。原厂 recovery 在官方完整包的 payload 里，可以用 payload 解包工具取出 `recovery.img`。

## 文档

- [功能说明](docs/features.md)
- [已知问题](docs/known-issues.md)
- [构建](docs/building.md)
- [验证清单](docs/verification.md)
- [更新日志](CHANGELOG.md)
- [补丁说明](patches/README.md)
- [参考资料](docs/references.md)
- [开发记录](docs/notes/2026-11-05-recovery-build.md)

## 许可证

设备树配置、ramdisk 覆盖、主题覆盖和补丁采用 GNU GPL v3.0，见 [LICENSE](LICENSE)。OrangeFox 和 TWRP 本体同样是 GPL-3.0，本仓库不声称拥有它们的版权。

`recovery/root` 下的小米二进制、库和固件来自小米官方 ROM，版权归小米，不在 GPL 许可范围内。它们只用于在对应设备上运行 recovery。没有该设备或 ROM 使用权的人应删除这些文件，并按 [proprietary-files.txt](proprietary-files.txt) 从自己的官方包提取。

Sarasa Mono SC 字体采用 SIL Open Font License 1.1，见 [licenses/SarasaGothic-OFL.txt](licenses/SarasaGothic-OFL.txt)。
