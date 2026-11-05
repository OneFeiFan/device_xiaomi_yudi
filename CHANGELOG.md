# 更新日志

## R12.0（2026-11-05，本地构建）

- 新增：小米平板 6 Max 14（yudi）的 OrangeFox R12.0 recovery 设备树。
- 新增：触摸、FBE 解密、Keymaster 4.1、KeyMint、Gatekeeper 和 boot HAL。
- 新增：AIDL 震动 HAL、MTP、ADB、ADB sideload、卡刷、备份恢复和 A/B 槽位。
- 新增：中文主题和字体，终端使用 Sarasa Mono SC 的 GBK 子集。
- 修正：主题勾选设置在重启后丢失。
- 修正：下拉面板里 MTP 提示的误译。
- 修正：VNDK v31 与 v32 的重复库。
- 修正：fastbootd 因缺少 health 服务不初始化 USB。设备端已能枚举为 18d1:4ee0，Windows 需要安装 fastboot 驱动。

验证：实机验证了启动、触摸、解密、MTP 双向传输、卡刷、备份恢复、ADB sideload、电池、ADSP 和 fastbootd。fastbootd 完成了 `getvar` 和 `reboot recovery` 验证；Windows 使用前需要安装 Google USB 驱动（`18D1:4EE0`）。
