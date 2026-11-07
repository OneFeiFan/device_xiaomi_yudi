#!/system/bin/sh
# 触控模块统一从 ramdisk 加载，不依赖当前槽 vendor_dlkm 是否完整。
# ramdisk 里的模块和当前 ROM 的 vendor_dlkm 一致（见 BoardConfig.mk）。

# 已经加载过就不重复
grep -q '^xiaomi_touch ' /proc/modules 2>/dev/null && exit 0

/system/bin/insmod /lib/modules/xiaomi_touch.ko
/system/bin/insmod /lib/modules/nt36532_touch.ko
