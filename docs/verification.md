# 验证清单

刷入后按下面的顺序检查。每一项都给出通过标准，不记录某一次的具体结果。

## 启动和服务

```sh
adb wait-for-device
adb shell "getprop init.svc.recovery"
adb shell "getprop init.svc.vendor.boot-hal-1-2; getprop init.svc.vendor.qseecomd; getprop init.svc.vendor.keymaster-4-1; getprop init.svc.vendor.keymint-qti; getprop init.svc.gatekeeper-1-0; getprop init.svc.vibratorfeature-hal-service; getprop init.svc.vendor.mi_misight"
```

通过标准：`recovery` 是 running，后面每个服务都是 running。

## ADSP、电池和解密

```sh
adb shell "cat /sys/class/remoteproc/remoteproc0/state"
adb shell "cat /sys/class/power_supply/battery/capacity; cat /sys/class/power_supply/battery/status"
adb shell "ls /sdcard/Fox/.foxs"
adb shell "dmesg | grep -c 'Direct firmware load failed'"
```

通过标准：remoteproc 是 running，电池容量和状态能读到，`.foxs` 存在，固件加载失败次数是 0。

## 震动

在设置页切换一个开关，或者在“高级”页点一个按钮。

通过标准：马达有实际震动。

## 触摸和温度

在界面上点击四个角和中间，确认落点与手指一致。状态栏的 CPU 温度应有读数。

## 主题和中文字体

打开终端，输入几个中文文件名或执行会输出中文的命令。字体应等宽，常见汉字和 GBK 范围内的生僻字不应显示成方块。

Fox RPC 的截图只能截到起始页，终端和其他页面的显示要用肉眼在设备上确认。

## MTP

在 Windows 的“此电脑”里打开设备，向 Internal Storage 复制一个文件，再从设备复制回电脑。

通过标准：两个方向都能复制，文件内容一致。中文文件名和内容不能乱码。

## USB Storage

在“挂载”页启用 USB Storage，电脑上应出现一个可读写的磁盘。退出后 MTP 应重新出现。

通过标准：电脑能读写这个磁盘，退出后 Internal Storage 仍可访问。

## 卡刷 zip

用一个只写测试文件的 zip 验证。zip 的 `update-binary` 写入 `/sdcard/Fox/zip-test.txt`。

```sh
adb push fox-zip-test.zip /sdcard/
adb shell "rm -f /sdcard/Fox/zip-test.txt"
adb shell "fox flash /sdcard/fox-zip-test.zip --no-verify"
adb shell "cat /sdcard/Fox/zip-test.txt"
```

通过标准：命令返回成功，测试文件存在且内容正确。

## 备份和恢复

```sh
adb shell "sha256sum /dev/block/bootdevice/by-name/boot"
adb shell "fox backup boot --name boot-test --storage internal"
adb shell "fox restore boot --name boot-test"
adb shell "sha256sum /dev/block/bootdevice/by-name/boot"
```

通过标准：备份目录里有 `boot.emmc.win` 和 digest，恢复后 boot 分区的 sha256 与恢复前一致。

## ADB sideload

```sh
adb shell "fox sideload start"
adb sideload fox-zip-test.zip
```

通过标准：传输到 100%，zip 里的脚本执行，退出后 `adb devices` 能重新看到 recovery。

## fastbootd

```sh
adb reboot fastboot
fastboot devices
fastboot getvar current-slot
fastboot getvar product
fastboot reboot recovery
```

通过标准：`fastboot devices` 能看到设备，`current-slot` 返回当前槽位，`product` 返回 `yudi`，`fastboot reboot recovery` 能回到 recovery。设备在 fastbootd 模式下枚举为 `18d1:4ee0`。

Windows 需要先为这个 USB 设备安装 Google USB 驱动（`android_winusb.inf`）。设备管理器显示代码 28 表示缺驱动。Linux 不需要额外驱动。

## 设置持久化

在设置页勾选几项，重启 recovery，再进入设置页确认勾选还在。

也可以用 `fox internal get tw_hidden_files` 和 `fox internal set tw_hidden_files 1` 做端到端检查。重启后读回的值应与写入一致。

通过标准：重启前后的值一致，`/sdcard/Fox/.foxs` 的修改时间会更新。

## 异常重启后的写入

```sh
adb shell "echo durability-test > /sdcard/durability-test; sync"
adb shell "echo b > /proc/sysrq-trigger"
# 重启后重新进入 recovery
adb shell "cat /sdcard/durability-test"
```

通过标准：文件仍然存在。`/proc/mounts` 的 `/data` 行不应出现 `checkpoint=disable`。

## 槽位

```sh
adb shell "fox status"
```

确认 Boot slot 是当前实际槽位。不要在没有系统的槽位之间切换，见[已知问题](known-issues.md#另一槽没有系统时切槽会落到-fastboot)。
