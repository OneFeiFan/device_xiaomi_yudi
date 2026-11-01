#
# 橙狐的构建变量
# 变量的含义见橙狐官方文档：gitlab.com/OrangeFox/vendor/recovery 的 orangefox_build_vars.txt（fox_16.0-R12 分支）
#

FDEVICE="yudi"

fox_get_target_device() {
	local chkdev=$(echo "$BASH_SOURCE" | grep -w "$FDEVICE")
	if [ -n "$chkdev" ]; then
		FOX_BUILD_DEVICE="$FDEVICE"
	else
		chkdev=$(set | grep BASH_ARGV | grep -w "$FDEVICE")
		[ -n "$chkdev" ] && FOX_BUILD_DEVICE="$FDEVICE"
	fi
}

if [ -z "$1" -a -z "$FOX_BUILD_DEVICE" ]; then
	fox_get_target_device
fi

if [ "$1" = "$FDEVICE" -o "$FOX_BUILD_DEVICE" = "$FDEVICE" ]; then
	export ALLOW_MISSING_DEPENDENCIES=true
	export LC_ALL="C"

	# 分区布局：原生虚拟 A/B，并且有独立的 recovery 分区（OTA 里有 recovery 分区）
	export FOX_VIRTUAL_AB_DEVICE=1
	export FOX_AB_DEVICE=1
	export OF_AB_DEVICE_WITH_RECOVERY_PARTITION=1

	# 预编译内核只用于构建，不放进镜像
	export OF_FORCE_PREBUILT_KERNEL=1

	# ramdisk 用 LZ4，与原厂 recovery 一致（BoardConfig 已设 BOARD_RAMDISK_USE_LZ4）
	export OF_USE_LZ4_COMPRESSION=1

	# 屏幕：旋转后的界面是 1800x2880（16:10）。按橙狐的公式，宽度折算到 1080 后高度为 1080*2880/1800 = 1728
	export OF_SCREEN_H=1728

	# 语言和时区：中国
	export TW_DEFAULT_LANGUAGE="zh_CN"
	export OF_DEFAULT_TIMEZONE="CST-8"

	# 动态分区工具
	export OF_ENABLE_LPTOOLS=1

	# 快速备份默认勾选的分区
	export OF_QUICK_BACKUP_LIST="/boot;/vendor_boot;/dtbo;/data;"

	export OF_MAINTAINER="OneFeiFan"
fi
