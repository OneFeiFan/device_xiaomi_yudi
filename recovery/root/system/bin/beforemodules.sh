#!/system/bin/sh
# 当前槽的 vendor_dlkm 没有可用模块时，才从 ramdisk 补载触摸模块；
# vendor_dlkm 完整时交给 TWRP 自己加载，避免模块版本和当前内核/ROM 不匹配。

# 已经加载过就不重复
grep -q '^xiaomi_touch ' /proc/modules 2>/dev/null && exit 0

dev="$(readlink -f /dev/block/by-name/vendor_dlkm 2>/dev/null)"
size="$(blockdev --getsize64 "$dev" 2>/dev/null || echo 0)"

# yudi 正常的 vendor_dlkm 约 27 MiB，空槽是 0；1 MiB 作为阈值
if [ -n "$dev" ] && [ "$size" -ge 1048576 ]; then
    exit 0
fi

/system/bin/insmod /lib/modules/xiaomi_touch.ko
/system/bin/insmod /lib/modules/nt36532_touch.ko
