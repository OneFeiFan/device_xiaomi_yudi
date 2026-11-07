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
adb shell "for s in recovery vendor.boot-hal-1-2 vendor.qseecomd vendor.keymaster-4-1 vendor.keymint-qti gatekeeper-1-0 health-hal-2-1 vendor.qti.vibrator; do echo \$s=\$(getprop init.svc.\$s); done"
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

要分别测这几种情况：没有锁屏密码、图案、PIN、文本密码、多用户，以及统一锁屏的 profile（例如 XSpace、平行空间）。多用户时，同密码的用户应自动解密，独立密码的用户要输入自己的密码；统一锁屏的 profile 应在父用户解密后自动解密。

输入密码后要等 2 到 3 秒，原因见[功能说明](features.md#凭据和用户)。

### 设置保存

在设置页勾选几项，重启 recovery，再进设置页查看。也可以用命令：

```sh
adb shell "fox internal set tw_hidden_files 1"
adb reboot recovery
adb shell "fox internal get tw_hidden_files"
```

通过标准：重启后勾选还在，读回的值是 1。

### 全新设置下的默认值

先备份 `/sdcard/Fox/.foxs` 和 `/persist/.foxs`，把它们删除后重启 recovery，查看设置页的勾选状态，最后把备份放回。

通过标准：各复选框的默认勾选状态与未修改的 OrangeFox 一致。主题里声明的持久化变量不应改变这些默认值。

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

### USB OTG

准备一个 USB-C 扩展坞或 OTG 盘，分区可以是 FAT32、exFAT 或 NTFS。

1. 拔掉电脑线，插上扩展坞/OTG 盘；
2. 在“挂载”页打开 USB 外置存储，或在终端执行 `ls /usb_otg`；
3. 读取一个文件，有条件的话再写入一个测试文件；
4. 拔掉扩展坞，把电脑线插回平板。

通过标准：`/usb_otg` 能挂载并读到文件，NTFS 分区由 `mount.ntfs` 正常处理；拔掉扩展坞后 `adb devices` 和 MTP 能恢复，不需要重启恢复。

如果没有自动挂载，看 `/tmp/recovery.log` 确认实际的设备节点名，处理办法见[功能说明](features.md#usbadbmtp-和-otg)。

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

退出 sideload 后 MTP 不会自动恢复，见[已知问题](known-issues.md#sideload-后-mtp-不会自动恢复)。

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

### data 的备份

```sh
adb shell "fox backup data --name data-test --storage internal"
```

通过标准：备份目录里有 `data.f2fs.win000` 等分片、`.sha2` 和 `data.info`；任选一个分片，`sha256sum` 与 `.sha2` 内容一致。

再确认备份里有应用数据。应用数据经由 `/data/user/0/<包名>/` 进入备份（原因见[功能说明](features.md#备份的范围)），所以要查这条路径，不要只看 `/data/data`：

```sh
for f in /sdcard/Fox/BACKUPS/<serialno>/<备份名>/data.f2fs.win[0-9]*; do
    tar -tf "$f"
done | grep '^/data/user/0/' | head
```

### super 的备份

```sh
adb shell "fox backup super --name super-test --storage internal"
```

通过标准：备份目录里有 `super.emmc.win` 和 `.sha2`；`sha256sum super.emmc.win` 与 `.sha2` 内容一致。

### data 的恢复

这是破坏性测试。先备份 data，再在 `/data` 根目录新建一个测试文件（不要放在 `/sdcard`，因为 `/data/media` 不会被清除），然后恢复刚才的备份。

为了确认应用数据确实在备份里，再在一个已安装应用的数据目录放一个标记文件，例如 `/data/user/0/<包名>/fox-restore-marker.txt`，用上面的 `tar -tf` 命令确认它出现在备份分卷里；然后做一次普通双清（`fox wipe cache data`）再恢复，检查这个标记文件是否回来。

通过标准：恢复后 `/data/...` 测试文件消失（如果它不在备份里），应用数据标记文件恢复；重启进入系统后应用数据可以正常读取。

恢复后锁屏凭据的状态取决于恢复前做过什么，对照[功能说明](features.md#恢复后锁屏凭据的状态)检查。

### 双清和 Format Data

这是破坏性测试，先在电脑或 OTG 上保留需要的备份。

普通双清：

```sh
adb shell "mkdir -p /data/media/0; echo keep > /data/media/0/wipe-keep-test.txt; echo delete > /data/wipe-delete-test.txt"
adb shell "fox wipe cache data"
adb shell "ls -l /data/media/0/wipe-keep-test.txt /data/wipe-delete-test.txt"
```

通过标准：`/data/media/0/wipe-keep-test.txt` 还在，`/data/wipe-delete-test.txt` 不存在；重启能进入系统。

如果普通双清中止并报 `Unable to wipe /data`，处理办法见[已知问题](known-issues.md#普通双清遇到删不掉的文件会中止)。

含 metadata 的整分区清除：

```sh
adb shell "fox wipe cache metadata data"
```

通过标准：日志里有 `format successful` 和（整分区已格式化时）`metadata was already formatted while clearing the data key`；没有 `In use by the system`；`Wiped /metadata`、`Wiped /data`；重启能进入系统，再次进入 recovery 能正常解密。这个路径会清空 `/data/media`。

### 通过 fastbootd 刷写分区

用当前槽位正在使用的同一个 recovery 镜像，通过 fastbootd 重新刷一次：

```sh
fastboot flash recovery_a recovery.img       # 换成当前槽位
fastboot reboot recovery
```

通过标准：刷写成功，并能重新进入 recovery。

### 刷入官方完整包和切换槽位

在 recovery 里刷入小米官方完整包（`payload.bin` 格式）。第三方通用包由包内脚本直接写分区，不经过 update_engine，不能代替这项测试。

官方包会把系统装到另一个槽位，并把那个槽位的 recovery 换成原厂 recovery。刷完后、重启前，把 OrangeFox 镜像刷进另一个槽位的 recovery 分区；也可以事后用 fastboot 刷入。

通过标准：刷入过程没有报错；重启后从另一个槽位进入系统；在这个槽位上也能进入 OrangeFox。
