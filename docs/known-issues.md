# 已知问题

尚未验证的功能见 [README 的功能状态表](../README.md#功能状态)，这里只列已经发现的问题。

## 另一槽没有系统时切槽会停在 fastboot

如果另一个槽位的 super 里没有系统，在“重启”菜单切到这个槽位后，设备会停在 fastboot。`recovery_b` 这类 recovery 分区本身不受影响。

处理办法：切换前，先用完整包或线刷包给目标槽位装好系统，并在它的 recovery 分区刷入同一个 OrangeFox 镜像。已经停在 fastboot 时，执行 `fastboot set_active a`（或原来的槽位）切回去。

## 换用其他版本的 ROM 后解密失败

KeyMint 要求 recovery 的安全补丁级别和 vendor 安全补丁与系统一致，版本属性也要检查。这些值目前写在 `BoardConfig.mk` 里。系统更新后，需要按 [功能说明](features.md#解密) 对照新系统的值，必要时重新构建。

## 普通双清不会清掉 user 0 锁屏

user 0 的 Gatekeeper/Keystore、`locksettings.db`、`spblob` 被 TWRP 的 `ExcludeAll()` 放进 wipe 排除表，普通双清不会主动删除这些文件。因此 TWRP 的普通双清**不能保证清除锁屏**，这和 Android 原厂“恢复出厂设置会清掉锁屏”的逻辑不同；想得到原厂那种效果，必须用 Format Data。

做过 Format Data 或换机后再恢复 data，user 0 的凭据和密钥已经没了，备份里也不包含，**才需要重设锁屏**；依赖 keystore 的应用可能需要重新登录。

非 0 用户（独立密码、clone profile）的凭据在正常解密路径下不会被排除：普通双清会删掉，恢复时写回备份里的版本；备份之后改过密码会与备份对不上，需要重设。

## sideload 后 MTP 不会自动恢复

进入 ADB sideload 再退出后，MTP 处于关闭状态，电脑上看不到 Internal Storage。这是因为 sideload 会切换 USB 配置，而 TWRP 退出时不会重新启用 MTP。

处理办法：执行 `fox mtp enable`，或者重新进入 recovery。

## 直接写 Fox FIFO 启用 MTP 会卡住界面

直接向 Fox 的 FIFO 写入 `mtp enable`，而没有同时读取 `foxout` 时，界面的动作线程会被阻塞，看起来像卡死。

处理办法：用 `fox mtp enable` 命令，或者在界面上操作。

## MTP 自启后 Windows 可能不立即显示

`tw_mtp_enabled` 默认为 1，启动日志里能看到 `[MTP] Starting MTP`，但 Windows 有时不会马上刷新出便携设备。这不影响手动使用：在“挂载”页关闭再打开 MTP，或者拔插一次 USB 线即可。

## 普通双清遇到无法删除的文件会中止

普通双清是逐个文件删除。recovery 会先清除 immutable/append 标志再重试；如果仍然无法删除（不是 `/data/user/0` 这类挂载点或预期的排除目录），会中止并报 `Unable to wipe /data`，此时 data 可能只清了一部分。

处理办法：改用 Format Data 整分区格式化。部分 root 模块会给 `/data/system/cloudFeature_*.xml` 加 immutable 标志，是常见原因之一。

## 开机后有 1 到 3 秒的卡顿

界面出现后会短暂卡顿，原因还没有找到。不影响使用。

## 每条命令都打印时区警告

在终端执行命令时，会打印 `__bionic_open_tzdata` 警告。OrangeFox 的时区列表里，UTC+8 只有一项 `TAIST-8;TAIDT`，它不是标准的时区名，而 recovery 里也没有时区数据库，所以 bionic 找不到对应数据。时间显示是正确的，可以忽略。

## 屏幕空闲后变黑

这是 TWRP 的自动息屏，触摸屏幕即可恢复。
