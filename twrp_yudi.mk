#
# 产品定义
#

# recovery 只需要 64 位
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)

# 虚拟 A/B：官方 OTA 的动态分区元数据 snapshot_enabled = true
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota.mk)

# TWRP 和橙狐的通用配置
$(call inherit-product, vendor/twrp/config/common.mk)

# 设备配置
$(call inherit-product, device/xiaomi/yudi/device.mk)

# 机型信息：原厂 recovery 的 ro.product.vendor.*
PRODUCT_DEVICE := yudi
PRODUCT_NAME := twrp_yudi
PRODUCT_BRAND := Xiaomi
PRODUCT_MODEL := 2307BRPDCC
PRODUCT_MANUFACTURER := Xiaomi
