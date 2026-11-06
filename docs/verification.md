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
- 多用户（同密码用户会自动解密，独立密码用户需要输入自己的密码）；
- 统一锁屏的 clone/managed profile（例如 XSpace、平行空间）。

以上情况都已实测通过。统一锁屏 profile 的通过标准是：父用户解密成功后，日志里能看到该 profile 用户也被解密；父用户没有解密时不会尝试。

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

不适用：已在设备树关闭。设备只有一个 USB-C 口，无法同时接 OTG 存储和电脑；文件传输用 MTP。

### USB OTG

准备一个 USB-C 扩展坞或 OTG 盘，分区可以是 FAT32、exFAT 或 NTFS。

1. 拔掉电脑线，插上扩展坞/OTG 盘；
2. 在“挂载”页打开 USB 外置存储，或在终端执行 `ls /usb_otg`；
3. 读取一个文件，有条件的话再写入一个测试文件；
4. 拔掉扩展坞，把电脑线插回平板。

通过标准：`/usb_otg` 能挂载并读到文件，NTFS 分区由 `mount.ntfs` 正常处理；拔掉扩展坞后 `adb devices` 和 MTP 能恢复，不需要重启恢复。

如果实际设备节点不是 `sdg`/`sdg1`，看 `/tmp/recovery.log` 确认节点名，并同时修改 `twrp.flags` 和 `Check_UsbOtg_Status()` 的检查路径。

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

界面上的“正在启动侧载”是在等电脑执行 `adb sideload`，不是卡死；电脑开始发送后页面会继续显示进度。退出 sideload 后 MTP 不会自动恢复，见[已知问题](known-issues.md#sideload-后-mtp-不会自动恢复)。

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

应用数据不在 `/data/data`（橙狐的 `OF_WORKAROUND_BACKUP_BUG` 会排除它），而是在 `/data/user/0/<包名>/` 路径下。用下面的命令确认备份里确实有应用数据，而不是只看 `/data/data`：

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

这是破坏性测试。先备份 data，再在 `/data` 根目录新建一个测试文件（不要放 `/sdcard`，因为 `/data/media` 不会被清除），然后恢复刚才的备份。data 备份不包含 `/data/media`，要保留照片/下载需要另外备份 Internal Storage。

为了确认应用数据确实在备份里，再在一个已安装应用的数据目录放一个标记文件，例如 `/data/user/0/<包名>/fox-restore-marker.txt`，用上面的 `tar -tf` 命令确认它出现在备份分卷里；然后做一次普通双清（`fox wipe cache data`）再恢复，检查这个标记文件是否回来。

通过标准：恢复后 `/data/...` 测试文件消失（如果它不在备份里），应用数据标记文件恢复；重启进入系统后应用数据可以正常读取。

凭据是否保留取决于恢复前做过什么：

- 只做普通双清再恢复：user 0 的锁屏凭据不会被清除，**不需要重设**；
- 备份和恢复之间做过 Format Data 或换机：user 0 的凭据和密钥已经没了，备份里也不包含，需要重设锁屏；依赖 keystore 的应用可能需要重新登录；
- 非 0 用户（独立密码、clone profile）：普通双清会删掉它们的凭据，恢复时写回备份里的版本；如果备份之后改过密码，恢复后会对不上，需要重设。

### 双清和 Format Data

这是破坏性测试，先在电脑或 OTG 上保留需要的备份。

普通双清：

```sh
adb shell "mkdir -p /data/media/0; echo keep > /data/media/0/wipe-keep-test.txt; echo delete > /data/wipe-delete-test.txt"
adb shell "fox wipe cache data"
adb shell "ls -l /data/media/0/wipe-keep-test.txt /data/wipe-delete-test.txt"
```

通过标准：`/data/media/0/wipe-keep-test.txt` 还在，`/data/wipe-delete-test.txt` 不存在；重启能进入系统。

如果普通双清报 `Unable to wipe /data` 或在某个文件处停止，说明该文件在清除 immutable/append 后仍删不掉，`/data` 可能只清了一部分。这种情况改用 Format Data，不要继续重复普通双清。

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

### 刷入完整 ROM 和切换槽位

在 recovery 里刷入官方完整包。A/B 设备会把系统装到另一个槽位，并把那个槽位的 recovery 换成原厂 recovery，所以刷完后要在另一个槽位的 recovery 分区重新刷入 OrangeFox。

通过标准：刷入过程没有报错；切换到另一个槽位后能进入系统，也能进入 OrangeFox。
