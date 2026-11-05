# 参考资料

这份设备树在编写和验证时参考了下面的资料。具体结论写在功能说明、已知问题和开发记录里。

## 设备与固件

- 小米官方完整包 `yudi-ota_full-OS3.0.6.0.VMHCNXM-user-15.0-7b73783799.zip`：分区布局、动态分区、初始配置。
- 第三方重打包的 `yudi-ota_full-OS3.0.306.3.WMHCNXM-user-16.0-b255c0d484-2in1-Root.zip`：boot HAL、`libdrm.so`、vndk-v32 库、`libu32.so` 对应的原始 libutils。这个包不是官方包，校验值无法与官方 306.3 核对。
- 原厂 `recovery.img`：`charger_fstab.qti`、ramdisk 布局、ADSP 固件文件名。

## OrangeFox 和 TWRP

- OrangeFox `fox_16.0` 源码：`bootable/recovery/gui/listbox.cpp`、`fox_fifo`、`etc/init.rc`、`fastboot`、`vendor/twrp`。
- TWRP 的设备树约定、主题资源、模块加载和 FunctionFS 处理。

## AOSP Android 16

- `build/make/core/Makefile`、`product_config.mk`、`sysprop.mk`：UFFD GC 和 OTA 内核 VINTF 检查对内核版本、内核配置的依赖。
- `build/make/tools/extract_kernel.py`：从内核提取版本和配置。
- `system/core/init`：`wait_for_prop`、USB configfs 触发规则。
- `system/hwservicemanager` 和 `system/libhidl`：HIDL 服务注册、接口链查询。
- `system/core/fastboot/device`：fastbootd 的 health 查询和 USB 初始化。
- `hardware/interfaces/health/2.1`：health 服务实现和 2.0 兼容查询。

## 审计与写作规范

- 用户提供的 15 点设备树审计，以及后续的功能测试审计、内核声明审计。
- 用户提供的文档写作规范：<https://github.com/OneFeiFan/gki-kernel-5.10-xiaomi-pad6max/blob/pad6max/docs/writing-guide.md>。

## 工具

- fonttools：生成 Sarasa Mono SC 的 GBK 子集。
- Google USB Driver r13：Windows 上绑定 fastbootd 的 `18D1:4EE0` 设备。
