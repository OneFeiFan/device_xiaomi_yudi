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

	# keymaster：强制 4.1，并与 TW_FORCE_KEYMASTER_VER 配套
	export OF_DEFAULT_KEYMASTER_VERSION="4.1"

	# 预编译内核只用于构建，不放进镜像
	export OF_FORCE_PREBUILT_KERNEL=1

	# ramdisk 用 LZ4，与原厂 recovery 一致（BoardConfig 已设 BOARD_RAMDISK_USE_LZ4）
	export OF_USE_LZ4_COMPRESSION=1

	# 屏幕：橙狐 portrait_hdpi 主题按 1080x1920 设计。OF_SCREEN_H 是主题缩放用的
	# 基准高度，不是设备的实际像素高度；旧设备树没有设置（默认 1920）。
	# 设成 1728 会把 1920 高的布局放大到约 3200px，比 2880px 的屏幕还高，
	# 底部内容会被推出屏幕。
	export OF_SCREEN_H=1920

	# 语言和时区：中国
	export TW_DEFAULT_LANGUAGE="zh_CN"
	export OF_DEFAULT_TIMEZONE="CST-8"

	# 动态分区工具
	export OF_ENABLE_LPTOOLS=1

	# AVB2.0：在设置/高级/安装页提供“禁用 vbmeta AVB2.0”。
	# 只增加开关；默认不会在启动时自动改 vbmeta，刷 ROM 后的自动处理也默认关闭。
	export OF_SUPPORT_VBMETA_AVB2_PATCHING=1

	# Mount 菜单显示 USB Storage（大容量存储），不依赖 MTP。
	export OF_ENABLE_USB_STORAGE=1

	# 快速备份默认勾选的分区
	export OF_QUICK_BACKUP_LIST="/boot;/vendor_boot;/dtbo;/data;"

	export OF_MAINTAINER="OneFeiFan"
fi
