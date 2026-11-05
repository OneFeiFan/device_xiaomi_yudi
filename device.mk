#
# 设备需要安装的软件包和属性
#

LOCAL_PATH := device/xiaomi/yudi

# 首发 API 级别：vendor/build.prop 的 ro.board.first_api_level=31
PRODUCT_SHIPPING_API_LEVEL := 31

# 动态分区：原厂 recovery 的 ro.boot.dynamic_partitions=true
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# fastbootd
PRODUCT_PACKAGES += \
    android.hardware.fastboot@1.1-impl-mock \
    fastbootd

# 解密使用 Keymaster 4.1：vendor 的 manifest_cape.xml 声明了 keymaster@4.1。
# 这里的属性只是构建期默认，启动时 twrp.cpp 会用 OF_DEFAULT_KEYMASTER_VERSION
# 覆盖它；保留同值作兜底，三处设置的关系见 README“设计说明”。
PRODUCT_PROPERTY_OVERRIDES += \
    keymaster_ver=4.1
