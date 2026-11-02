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
# 原厂 recovery 不带内核（REC 头部 kernel_size = 0），引导程序用 boot 分区的内核启动它，
# 这里保持一致。预编译内核是原厂 boot 里的 5.10.236，只用来满足构建系统，不会打进镜像。
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
TARGET_KERNEL_VERSION := 5.10
BOARD_KERNEL_IMAGE_NAME := Image
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

# 版本号和安全补丁级别
# Keymaster 只允许不低于创建密钥时的系统版本和补丁级别使用密钥，
# 所以 recovery 头部写一个足够大的值，避免解密时因版本过低被拒绝。
PLATFORM_VERSION := 16
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
PLATFORM_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)

# 解密：VBOOT 的 fstab 为 FBE v2（inlinecrypt_optimized + wrappedkey_v0）加 metadata 加密
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_USE_FSCRYPT_POLICY := 2
TW_FORCE_KEYMASTER_VER := true

# TWRP：界面
# 面板原生是 2880x1800 横屏（DTBO），系统把它旋转 270 度作为自然方向
# （VENDOR 的 ro.surface_flinger.primary_display_orientation=ORIENTATION_270）。
# 橙狐只有竖屏界面，同样旋转 270 度。
# 触摸驱动（NVTCapacitiveTouchScreen）上报的坐标已经是竖屏方向
# （x 横向、y 纵向），实测不需要 SWAP_XY/FLIP_X；加了反而整体转 90 度。
TW_THEME := portrait_hdpi
TW_ROTATION := 270
TW_FRAMERATE := 60
TW_NO_SCREEN_BLANK := true
# 电池：recovery 里没有 health HAL 服务，直接读 /sys/class/power_supply/battery
OF_USE_LEGACY_BATTERY_SERVICES := 1

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
# recovery 主程序和 libtar 链接 libsysutils；打开 logcat/logd 才会把它打进 ramdisk
TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true
TW_INCLUDE_NTFS_3G := true
TW_USE_TOOLBOX := true
TW_EXCLUDE_APEX := true
# 高通平台的虚拟触摸设备 hbtp_vm 存在时会抢占触摸输入，屏蔽它
TW_INPUT_BLACKLIST := "hbtp_vm"
