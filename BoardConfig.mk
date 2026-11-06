#
# 小米平板 6 Max 14（yudi）板级配置
#
# 数值的来源：
#   OTA    官方完整包 yudi OS3.0.6.0.VMHCNXM 的 payload（分区大小、动态分区元数据）
#   REC    原厂 recovery.img 及其 ramdisk
#   VBOOT  原厂 vendor_boot.img（bootconfig、第一阶段 fstab、recovery 模块列表）
#   VENDOR 原厂 vendor 分区
#   DTBO   原厂 dtbo.img 中 yudi 的面板节点
#

DEVICE_PATH := device/xiaomi/yudi

# 架构：骁龙 8+ Gen 1（SM8475）
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a-dotprod
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic

# 平台：REC 的 ro.board.platform=taro
TARGET_BOARD_PLATFORM := taro
TARGET_BOOTLOADER_BOARD_NAME := taro
TARGET_NO_BOOTLOADER := true
QCOM_BOARD_PLATFORMS += taro

# 内核
# 原厂 recovery 不带内核（REC 头部 kernel_size = 0），引导程序用 boot 分区的内核启动它。
# Recovery 构建通过 PRODUCT_ENABLE_UFFD_GC := false 去掉了内核版本依赖。
# 构建系统仍要求 TARGET_PREBUILT_KERNEL 指向的文件存在；这里放 0 字节占位文件，
# 只用来满足检查，内核不会进镜像（BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE）。
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
TARGET_KERNEL_VERSION := 5.10
BOARD_KERNEL_PAGESIZE := 4096
TARGET_FORCE_PREBUILT_KERNEL := true
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true

# 镜像格式：REC 和 boot 都是 v4 头部；REC 的 ramdisk 是 LZ4 压缩
BOARD_BOOT_HEADER_VERSION := 4
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_RAMDISK_USE_LZ4 := true

# A/B
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    dtbo \
    odm \
    product \
    recovery \
    system \
    system_ext \
    vbmeta \
    vbmeta_system \
    vendor \
    vendor_boot \
    vendor_dlkm

# 分区大小：OTA
BOARD_BOOTIMAGE_PARTITION_SIZE := 201326592
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600
BOARD_DTBOIMG_PARTITION_SIZE := 25165824
BOARD_FLASH_BLOCK_SIZE := 262144

# 动态分区：OTA 的分区组 qti_dynamic_partitions，上限 10 GiB。
# super 本身的大小不在 OTA 里，这里取分区组上限加 4 MiB 元数据，只在构建时用于校验。
# 小米的 mi_ext 也在这个分区组里，但构建系统不认识它，所以没有列出；挂载由 fstab 负责。
BOARD_SUPER_PARTITION_SIZE := 10741612544
BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 10737418240
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    odm \
    product \
    system \
    system_ext \
    vendor \
    vendor_dlkm

# 文件系统：VBOOT 的 fstab，逻辑分区为 erofs，userdata 为 f2fs，metadata 为 ext4
BOARD_USES_METADATA_PARTITION := true
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
TARGET_COPY_OUT_ODM := odm
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_HAS_LARGE_FILESYSTEM := true

# 恢复模式的显示和输入
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_RECOVERY_QCOM_RTC_FIX := true

# AVB：解锁状态下 recovery 不必通过校验，这里用测试密钥签名
BOARD_AVB_ENABLE := true
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1

# 版本号和安全补丁级别必须和 ROM 当前运行的系统一致。
# 厂商的 libqtikeymint/libqtikeymaster4 会读 ro.build.version.release、
# ro.build.version.security_patch 和 ro.vendor.build.security_patch，用它们判断
# metadata key 是否需要升级（-62 KEY_REQUIRES_UPGRADE）。实测系统是
# release 16 / security_patch 2026-08-01 / vendor patch 2026-02-01，而 recovery
# 写成 2025-09-01 时 KeyMint 一直要求升级，升级又失败（-8）。
# 注意：不能把 PLATFORM_VERSION_LAST_STABLE 改成 12，CTS 校验会中止。
# boot 头部保持和原厂 boot 一致（12.0.0 / 2025-09），用 BOARD_MKBOOTIMG_ARGS
# 显式覆盖，mkbootimg 对重复参数取最后一个值。
PLATFORM_VERSION := 16
PLATFORM_SECURITY_PATCH := 2026-08-01
VENDOR_SECURITY_PATCH := 2026-02-01
BOOT_SECURITY_PATCH := 2026-08-01
BOARD_MKBOOTIMG_ARGS += --os_version 12.0.0 --os_patch_level 2025-09

# 解密：VBOOT 的 fstab 为 FBE v2（inlinecrypt_optimized + wrappedkey_v0）加 metadata 加密
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_USE_FSCRYPT_POLICY := 2
# 格式化 data 前用 dmctl 解除 metadata 加密映射，否则 make_f2fs 报
# “In use by the system!”（物理 userdata 仍被 dm-7 占用）。
OF_USE_DMCTL := 1
# 强制只用 keymaster_ver 属性（由 OF_DEFAULT_KEYMASTER_VERSION 启动时写入），
# 不从 vendor manifest 探测版本；三处设置的关系见 README“设计说明”。
TW_FORCE_KEYMASTER_VER := true

# TWRP：界面
# 面板原生是 2880x1800 横屏（DTBO），系统把它旋转 270 度作为自然方向
# （VENDOR 的 ro.surface_flinger.primary_display_orientation=ORIENTATION_270）。
# 橙狐只有竖屏界面，同样旋转 270 度。
# 四角实测：右上与左下分别只改变 rawX/rawY 且同向，驱动坐标系与竖屏画面一致，
# 不需要任何 SWAP/FLIP 参数。
TW_THEME := portrait_hdpi
TW_ROTATION := 270
# 主题按 1080x1920（16:9）设计，屏幕是 1800x2880（16:10）。
# 宽高统一按 1.5 倍缩放：scale_w=(1800-180)/1080=1.5，scale_h=2880/1920=1.5；
# 内容宽 1620px，TW_X_OFFSET=90 让左右各留 90px 黑边并居中。
TW_W_OFFSET := -180
TW_X_OFFSET := 90
TW_FRAMERATE := 60
TW_NO_SCREEN_BLANK := true
# 电池：recovery 里没有 health HAL 服务，直接读 /sys/class/power_supply/battery
OF_USE_LEGACY_BATTERY_SERVICES := 1
# CPU 温度：taro 的 CPU 传感器是 cpuss-2（thermal_zone27）；
# TWRP 默认读 thermal_zone0，这个平台上 zone0 是 pa，读不到值
TW_CUSTOM_CPU_TEMP_PATH := "/sys/class/thermal/thermal_zone27/temp"
# 震动：使用 ROM 自带的 AIDL vibrator HAL，实例名是 IVibrator/vibratorfeature
TW_SUPPORT_INPUT_AIDL_HAPTICS := true
TW_SUPPORT_INPUT_AIDL_HAPTICS_FQNAME := IVibrator/vibratorfeature

# TWRP：背光（REC 的 init 写的就是这个节点；DTBO 的背光范围 0–4095）
TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
TW_MAX_BRIGHTNESS := 4095
TW_DEFAULT_BRIGHTNESS := 1200

# TWRP：语言
TW_DEFAULT_LANGUAGE := zh_CN
TW_EXTRA_LANGUAGES := true

# TWRP：内核模块
# 显示、电池、振动、USB、加密相关的驱动在 VBOOT 的 modules.load.recovery 里，
# 第一阶段 init 会自动加载。触控驱动不在其中，需要 recovery 从 vendor_dlkm 加载：
# DTBO 里触控控制器为 novatek,NVT-ts-spi，对应 nt36532_touch.ko，另需 xiaomi_touch.ko。
TW_LOAD_VENDOR_MODULES := "xiaomi_touch.ko nt36532_touch.ko"
TW_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true

# TWRP：功能
TW_INCLUDE_FASTBOOTD := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LIBRESETPROP := true
TW_INCLUDE_LPTOOLS := true
TW_INCLUDE_LPDUMP := true
# recovery 主程序和 libtar 链接 libsysutils；打开 logcat/logd 会顺带把它打进 ramdisk。
# 保留 logcat 是为了 adb 抓 vendor 服务日志（约 2–3MB）；libsysutils 依赖很简单，
# 单独拆出来收益不大，所以维持现状。
TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true
TW_INCLUDE_NTFS_3G := true
TW_USE_TOOLBOX := true
TW_EXCLUDE_APEX := true
# 高通平台的虚拟触摸设备 hbtp_vm 存在时会抢占触摸输入，屏蔽它
TW_INPUT_BLACKLIST := "hbtp_vm"
