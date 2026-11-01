#
# 小米平板 6 Max 14（yudi）
# 构建：lunch twrp_yudi-bp2a-eng && mka adbd recoveryimage
#

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/twrp_yudi.mk

COMMON_LUNCH_CHOICES := \
    twrp_yudi-bp2a-eng
