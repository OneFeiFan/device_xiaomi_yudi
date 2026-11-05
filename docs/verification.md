# 验证清单

刷入新构建的镜像后，按下面的顺序检查。每一项都写明通过标准；某一次的测试结果不记在这里，而是更新到 [README 的功能状态表](../README.md#功能状态)。

前三部分不改动任何数据，每次构建后都应该跑一遍。第四部分会改写分区，需要事先准备。

## 一、基本功能

### 确认运行的是新镜像

```sh
adb shell "getprop ro.boot.slot_suffix; getprop ro.build.date"
```

通过标准：构建时间是这次构建的时间。如果不是，说明启动的槽位里还是旧镜像，把两个槽位都刷一遍。

### 服务

```sh
adb shell "for s in recovery vendor.boot-hal-1-2 vendor.qseecomd vendor.keymaster-4-1 vendor.keymint-qti gatekeeper-1-0 health-hal-2-1 vibratorfeature-hal-service vendor.mi_misight; do echo \$s=\$(getprop init.svc.\$s); done"
```

通过标准：每一项都是 `running`。

### ADSP、电池和固件

```sh
adb shell "cat /sys/class/remoteproc/remoteproc0/state"
adb shell "cat /sys/class/power_supply/battery/capacity /sys/class/power_supply/battery/status"
adb shell "dmesg | grep -c 'Direct firmware load failed'"
```

通过标准：remoteproc 是 `running`；能读到电量和充电状态；固件加载失败次数为 0。

### 触摸、温度和震动

在界面上依次点击四个角和中间，在设置页切换几个开关。

通过标准：落点与手指位置一致；状态栏有 CPU 温度；切换开关时马达有震动。

### 主题和中文字体

打开终端，执行 `ls /sdcard` 等会输出中文文件名的命令。

通过标准：终端字体等宽；常用汉字和 GBK 范围内的生僻字不显示成方块。截图工具只能截到起始页，这一项要在设备上直接看。

## 二、解密和数据

### 解密

```sh
adb shell "getprop vendor.gatekeeper.disable_spu"
adb shell "ls -l /dev/0:0:0:49476"
adb shell "grep -E 'password type|GateKeeper|Decrypted Successfully|Data successfully decrypted' /tmp/recovery.log | tail -8"
adb shell "ls /sdcard"
```

通过标准：`vendor.gatekeeper.disable_spu` 是 `true`；RPMB 节点是 `crw-rw---- system system`；日志里有 `password type: PIN`、`pattern` 或 `password`、`GateKeeper status ok`、`User 0 Decrypted Successfully!`；`/sdcard` 下的文件名正常，不是乱码。

要分别测这几种情况：
- 系统没有设置锁屏密码（默认密码）；
- 图案；
- 4 位数字 PIN；
- 文本密码；
- 多用户。

输入图案、PIN 或文本密码后需要约 2–3 秒完成 scrypt 和 Gatekeeper 验证，这段时间界面看起来像卡住，是正常开销。默认密码不经过这两步，几乎立即解密。

### 设置保存

在设置页勾选几项，重启 recovery，再进设置页查看。也可以用命令：

```sh
adb shell "fox internal set tw_hidden_files 1"
adb reboot recovery
adb shell "fox internal get tw_hidden_files"
```

通过标准：重启后勾选还在，读回的值是 1。

### 异常重启后的写入

```sh
adb shell "echo durability-test > /sdcard/durability-test; sync"
adb shell "echo b > /proc/sysrq-trigger"
# 重新进入 recovery 后
adb shell "cat /sdcard/durability-test; grep ' /data ' /proc/mounts"
```

通过标准：文件还在；`/data` 的挂载参数里没有 `checkpoint=disable`。

## 三、传输

### MTP

在 Windows 的“此电脑”里打开设备，向 Internal Storage 复制一个中文文件名的文件，再从设备复制回电脑。

通过标准：两个方向都能复制，文件名和内容都正确。

### USB Storage

在“挂载”页启用 USB Storage，在电脑上读写这个磁盘，然后退出。

通过标准：电脑能读写；退出后 MTP 的 Internal Storage 重新出现。

### 刷入 zip 和 ADB sideload

准备一个测试 zip，它的 `update-binary` 只向 `/sdcard/Fox/zip-test.txt` 写一行文字。

```sh
adb push fox-zip-test.zip /sdcard/
adb shell "rm -f /sdcard/Fox/zip-test.txt"
adb shell "fox flash /sdcard/fox-zip-test.zip --no-verify"
adb shell "cat /sdcard/Fox/zip-test.txt"

adb shell "rm -f /sdcard/Fox/zip-test.txt; fox sideload start"
adb sideload fox-zip-test.zip
adb shell "cat /sdcard/Fox/zip-test.txt"
```

通过标准：两种方式下测试文件都被写出；sideload 退出后 `adb devices` 能重新看到设备。

### fastbootd

```sh
adb reboot fastboot
fastboot devices
fastboot getvar current-slot
fastboot getvar product
fastboot reboot recovery
```

通过标准：能看到设备；`current-slot` 是当前槽位；`product` 是 `yudi`；最后能回到 recovery。

## 四、需要事先准备的测试

这些测试会改写分区。开始前先备份重要数据，并准备好原厂 recovery 和线刷包。

### boot 分区的备份和恢复

```sh
adb shell 'sha256sum /dev/block/bootdevice/by-name/boot$(getprop ro.boot.slot_suffix)'
adb shell "fox backup boot --name boot-test --storage internal"
adb shell "fox restore boot --name boot-test"
adb shell 'sha256sum /dev/block/bootdevice/by-name/boot$(getprop ro.boot.slot_suffix)'
```

通过标准：两次 sha256 一致。

### data 的备份和恢复

先备份 data，再在内部存储新建一个测试文件，然后恢复刚才的备份。

通过标准：恢复后测试文件消失，其余文件完好；重启进入系统后，应用和数据正常。

### 通过 fastbootd 刷写分区

用当前槽位正在使用的同一个 recovery 镜像，通过 fastbootd 重新刷一次：

```sh
fastboot flash recovery_a recovery.img       # 换成当前槽位
fastboot reboot recovery
```

通过标准：刷写成功，并能重新进入 recovery。

### 刷入完整 ROM 和切换槽位

在 recovery 里刷入官方完整包。A/B 设备会把系统装到另一个槽位，并把那个槽位的 recovery 换成原厂 recovery，所以刷完后要在另一个槽位的 recovery 分区重新刷入 OrangeFox。

通过标准：刷入过程没有报错；切换到另一个槽位后能进入系统，也能进入 OrangeFox。
