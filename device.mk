#
# 设备需要安装的软件包和属性
#

LOCAL_PATH := device/xiaomi/yudi

# 首发 API 级别：vendor/build.prop 的 ro.board.first_api_level=31
PRODUCT_SHIPPING_API_LEVEL := 31

# recovery 不运行 ART。明确关闭 UFFD GC，避免构建系统为了 sysprop 去内核里提取版本号。
# Android 14 起 sysprop.mk 默认依赖内核版本，这会让不带内核的 recovery 构建失败。
PRODUCT_ENABLE_UFFD_GC := false

# 本设备树只构建 recovery，不生成 OTA。关闭 OTA 的内核 VINTF 要求，
# 构建系统就不会从内核提取配置和版本；recovery 不需要这项检查。
PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false

# 动态分区：原厂 recovery 的 ro.boot.dynamic_partitions=true
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# fastbootd
PRODUCT_PACKAGES += \
    android.hardware.fastboot@1.1-impl-mock \
    fastbootd

# 震动 HAL 从源码构建，替代 ROM 自带的小米 AIDL 服务。
$(call inherit-product-if-exists, vendor/qcom/opensource/vibrator/vibrator-vendor-product.mk)
