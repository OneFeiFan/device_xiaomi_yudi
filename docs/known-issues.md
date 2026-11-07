# 已知问题

这里只列已经发现的问题和处理办法。尚未验证的功能见 [README 的功能状态表](../README.md#功能状态)。

## 另一槽没有系统时切槽会停在 fastboot

如果另一个槽位的 super 里没有系统，在“重启”菜单切到这个槽位后，设备会停在 fastboot。recovery 分区本身不受影响。

处理办法：切换前，先用完整包或线刷包给目标槽位装好系统，并在它的 recovery 分区刷入同一个 OrangeFox 镜像。已经停在 fastboot 时，执行 `fastboot set_active a`（或原来的槽位）切回去。

## 换用其他版本的 ROM 后解密失败

KeyMint 要求 recovery 的版本和安全补丁属性与系统匹配，而这些值写在 `BoardConfig.mk` 里。系统更新后，按[功能说明](features.md#版本和安全补丁)对照新系统的值，必要时重新构建。

## 普通双清不能清除锁屏

普通双清会保留 user 0 的锁屏凭据文件，所以不能像原厂的恢复出厂设置那样清掉锁屏。要清掉锁屏，用 Format Data。恢复 data 之后各种情况下凭据的状态，见[功能说明](features.md#恢复后锁屏凭据的状态)。

## 普通双清遇到删不掉的文件会中止

清掉 immutable 和 append 标志后仍删不掉的文件，会让双清中止并报 `Unable to wipe /data`，此时 `/data` 可能只清了一部分。

处理办法：改用 Format Data，不要重复执行普通双清。原因见[功能说明](features.md#普通双清)。

## MTP 启动后 Windows 可能不立即显示

MTP 默认开启，日志里也能看到 `[MTP] Starting MTP`，但 Windows 有时不会马上刷新出这台设备。

处理办法：在“挂载”页关闭再打开 MTP，或者拔插一次 USB 线。

## sideload 后 MTP 不会自动恢复

进入 ADB sideload 再退出后，MTP 处于关闭状态，电脑上看不到 Internal Storage。sideload 会切换 USB 配置，而 TWRP 退出时不会重新启用 MTP。

处理办法：执行 `fox mtp enable`，或者重新进入 recovery。

## 双清或 Format Data 后其他用户的解密失效

双清或 Format Data 之后，除机主 user 0 以外的用户，包括系统分身、独立密码的用户和 XSpace 等 clone profile，在 recovery 里无法再解密。

双清后再进入系统时，系统会删除这些用户的加密密钥，而 TWRP 的 data 备份不包含密钥。所以实测中，即使恢复双清前的 data 备份，recovery 也认不出这些用户，系统里同样无法访问它们的数据，只能把这些用户删除。原因的细节见[功能说明](features.md#恢复后锁屏凭据的状态)。

处理办法：双清或 Format Data 之前，先在系统里把其他用户和分身空间里需要的文件拷出来，不要指望用 data 备份恢复这些用户。

## qseecomd 启动时报 libsecureui.so 找不到

recovery 启动时 logcat 里有一条：

```
QSEECOMD: : Init dlopen(libsecureui.so, RLTD_NOW) is failed.... dlopen failed: library "libsecureui.so" not found
```

当前 ROM 的 vendor、system、system_ext、product、odm 分区里都没有这个库。qseecomd 把它当可选功能，加载失败后继续运行；解密、Keymaster、Gatekeeper 和 fastbootd 都不受影响。不要为了消掉这条日志塞入空库或修改厂商二进制。

## 直接写 Fox FIFO 启用 MTP 会卡住界面

直接向 Fox 的 FIFO 写入 `mtp enable`，又没有同时读取 `foxout` 时，界面的动作线程会被阻塞，看起来像卡死。

处理办法：用 `fox mtp enable` 命令，或者在界面上操作。

## 开机后有 1 到 3 秒的卡顿

界面出现后会短暂卡顿，原因还没有找到。不影响使用。

## 每条命令都打印时区警告

在终端执行命令时会打印 `__bionic_open_tzdata` 警告。OrangeFox 的时区列表里，UTC+8 只有 `TAIST-8;TAIDT` 一项，它不是标准的时区名，recovery 里也没有时区数据库，所以 bionic 找不到对应数据。时间显示是正确的，可以忽略。

## 屏幕空闲后变黑

这是 TWRP 的自动息屏，触摸屏幕即可恢复。
