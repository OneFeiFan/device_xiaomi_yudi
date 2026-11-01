#
# 设备需要安装的软件包和属性
#

LOCAL_PATH := device/xiaomi/yudi

# 首发 API 级别：vendor/build.prop 的 ro.board.first_api_level=31
PRODUCT_SHIPPING_API_LEVEL := 31

# 动态分区：原厂 recovery 的 ro.boot.dynamic_partitions=true
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# A/B 槽位控制：高通平台用分区表属性位记录槽位状态，必须用高通的实现，
# AOSP 默认实现不适用。需要 hardware/qcom-caf/bootctrl（见 README 的本地 manifest）。
# bootctrl 模块在 hardware/qcom-caf/bootctrl 的 Soong 命名空间里
PRODUCT_SOONG_NAMESPACES += hardware/qcom-caf/bootctrl

PRODUCT_PACKAGES += \
    android.hardware.boot-service.qti.recovery

# fastbootd
PRODUCT_PACKAGES += \
    android.hardware.fastboot@1.1-impl-mock \
    fastbootd

# 解密使用 Keymaster 4.1：vendor 的 manifest_cape.xml 声明了 keymaster@4.1
PRODUCT_PROPERTY_OVERRIDES += \
    keymaster_ver=4.1
