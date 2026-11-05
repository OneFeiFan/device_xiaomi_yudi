# 参考资料

这份设备树在编写和验证时参考了下面的资料。具体结论写在功能说明、已知问题和开发记录里。

## 源码仓库

- 设备树：<https://github.com/OneFeiFan/device_xiaomi_yudi>
- OrangeFox manifest（fox_16.0）：<https://gitlab.com/OrangeFox/Manifest/-/tree/fox_16.0>
- OrangeFox recovery：<https://gitlab.com/OrangeFox/bootable/recovery>
- TWRP recovery：<https://github.com/TeamWin/android_bootable_recovery>
- TWRP 最小 manifest：<https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp>
- AOSP build（android-16.0.0_r1）：<https://android.googlesource.com/platform/build/+/refs/tags/android-16.0.0_r1>
- AOSP system/core（init、fastboot 等）：<https://android.googlesource.com/platform/system/core/+/refs/tags/android-16.0.0_r1>
- AOSP hwservicemanager：<https://android.googlesource.com/platform/system/hwservicemanager/+/refs/tags/android-16.0.0_r1>
- AOSP libhidl：<https://android.googlesource.com/platform/system/libhidl/+/refs/tags/android-16.0.0_r1>
- AOSP health 接口：<https://android.googlesource.com/platform/hardware/interfaces/+/refs/tags/android-16.0.0_r1/health>

## 其他设备树

同平台和其他高通设备树只用于对照，没有直接复制：

- 小米平板 6 Pro（liuqin）的 TWRP 12.1 树：<https://github.com/ymdzq/device_xiaomi_liuqin-TWRP>
- 小米平板 6 Pro（liuqin）的 TWRP 16 树：<https://github.com/lanweikayu/device_xiaomi_liuqin-TWRP-16>
- LineageOS sm8450-common：<https://github.com/LineageOS/android_device_xiaomi_sm8450-common>
- LineageOS sm8550-common：<https://github.com/LineageOS/android_device_xiaomi_sm8550-common>
- LineageOS mondrian：<https://github.com/LineageOS/android_device_xiaomi_mondrian>
- OrangeFox mondrian 设备树：<https://github.com/ymdzq/OFRP-device_xiaomi_mondrian>

liuqin 的两棵树是同一平台的 TWRP/OrangeFox 配置，用来核对模块加载、服务启动和密钥相关设置。LineageOS 的三棵树用来核对高通设备树里 bootctrl 的 Soong namespace 写法。mondrian 的 OrangeFox 更新记录把 `keymaster_ver` 默认值设为 4.1，是本设备树 Keymaster 4.1 配置的参考。

LineageOS 没有公开的 liuqin 设备树（`LineageOS/android_device_xiaomi_liuqin` 返回 404），liuqin 的参考以上面两棵 TWRP 树为准。

## 设备与固件

- 小米官方完整包 `yudi-ota_full-OS3.0.6.0.VMHCNXM-user-15.0-7b73783799.zip`：分区布局、动态分区、初始配置。
- 第三方重打包的 `yudi-ota_full-OS3.0.306.3.WMHCNXM-user-16.0-b255c0d484-2in1-Root.zip`：boot HAL、`libdrm.so`、vndk-v32 库、`libu32.so` 对应的原始 libutils。这个包不是官方包，校验值无法与官方 306.3 核对。
- 原厂 `recovery.img`：`charger_fstab.qti`、ramdisk 布局、ADSP 固件文件名。

## OrangeFox 和 TWRP 代码

- OrangeFox `bootable/recovery`：`gui/listbox.cpp`、`fox_fifo`、`etc/init.rc`、`fastboot`、`partitionmanager.cpp`。
- OrangeFox `vendor/twrp`：板级配置、主题资源和打包脚本。
- TWRP 的设备树约定、模块加载、FunctionFS 和 `additional.fstab` 处理。
- LineageOS `android_hardware_qcom_bootctrl`：<https://github.com/LineageOS/android_hardware_qcom_bootctrl>。最初尝试使用它的 boot 控制 HAL，因需要内核 UAPI 头而放弃，最终改用原厂 vendor 的 HIDL 1.2 boot HAL。

## AOSP Android 16 代码

- `build/make/core/Makefile`、`product_config.mk`、`sysprop.mk`：UFFD GC 和 OTA 内核 VINTF 检查对内核版本、内核配置的依赖。
- `build/make/tools/extract_kernel.py`：从内核提取版本和配置。
- `system/core/init`：`wait_for_prop`、USB configfs 触发规则。
- `system/hwservicemanager` 和 `system/libhidl`：HIDL 服务注册、接口链查询。
- `system/core/fastboot/device`：fastbootd 的 health 查询和 USB 初始化。
- `hardware/interfaces/health/2.1`：health 服务实现和 2.0 兼容查询。

## 审计与写作规范

- 用户提供的 15 点设备树审计，以及后续的功能测试审计、内核声明审计、数据耐久性审计。
- 用户提供的文档写作规范：<https://github.com/OneFeiFan/gki-kernel-5.10-xiaomi-pad6max/blob/pad6max/docs/writing-guide.md>。

## 工具

- fonttools：<https://github.com/fonttools/fonttools>，用来生成 Sarasa Mono SC 的 GBK 子集。
- Sarasa Gothic 字体发布页：<https://github.com/be5invis/Sarasa-Gothic>，字体来源。
- Google USB Driver：<https://developer.android.com/studio/run/win-usb>，Windows 上绑定 fastbootd 的 `18D1:4EE0` 设备。
