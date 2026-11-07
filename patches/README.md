# 补丁

这些补丁把 OrangeFox 的 `bootable/recovery` 和 `system/vold` 改成本设备树需要的状态。补丁按当前 OrangeFox `fox_16.0` 分支生成，`repo sync` 覆盖源码后需要重新应用。

## 应用顺序

先按编号应用 0001、0002、0004、0005、0007 到 `bootable/recovery`，再应用 0006 到 `system/vold`。0003 已删除：实测移除后拔掉 OTG 再插电脑线，ADB 会自动恢复。

```sh
cd bootable/recovery
for p in ../../device/xiaomi/yudi/patches/0001-*.patch \
         ../../device/xiaomi/yudi/patches/0002-*.patch \
         ../../device/xiaomi/yudi/patches/0004-*.patch \
         ../../device/xiaomi/yudi/patches/0005-*.patch \
         ../../device/xiaomi/yudi/patches/0007-*.patch; do
    git apply "$p"
done

cd ../../system/vold
git apply ../../device/xiaomi/yudi/patches/0006-*.patch
```

补丁都用 `git apply` 应用，不依赖提交历史。应用前先确认工作区干净；如果上游已经合入其中某个修改，跳过对应补丁。

## 0001-fox-settings-persistence.patch

作用：主题页的勾选写值加上 `persist=1`，让不在 `vars.xml` 和默认持久化表里的变量也能写入 `/sdcard/Fox/.foxs`。没有这个补丁时，`fox_boot_*` 等设置重启后会丢失。

修改文件：`bootable/recovery/gui/listbox.cpp`。

## 0002-fix-data-wipe-immutable-metadata.patch

作用：

- 清理 `/data` 下文件的 immutable、append 等删除阻塞属性，避免 wipe/restore 时报 `extractTarFork() 255`；
- 在擦 `/metadata` 前先真正格式化 `/data`，避免留下没有 metadata 密钥的密文 userdata（表现为 `Magic Mismatch`、系统无法开机）；
- 如果 `Wipe_Encryption()` 已经顺带擦掉同一个 metadata 分区，外层 wipe 不再重复格式化。

`extractTarFork() 255` 的常见来源是部分 root 模块给 `/data/system/cloudFeature_*.xml` 加了 immutable 标志。补丁会先清标志再重试；如果仍然无法删除，普通双清会中止而不是悄悄跳过，此时 data 可能只清了一部分，应该改用 Format Data。

修改文件：`bootable/recovery/partition.cpp`。

## 0004-wipe-stop-mtp-before-format.patch

作用：`Wipe_Encryption()` 在 `dmctl delete userdata` 和 `make_f2fs` 前先停 MTP，结束后恢复。MTP 会一直打开 `/data/media`，不停掉时 dm-userdata 处于 busy，`make_f2fs` 报 `In use by the system!` 并返回 255。

修改文件：`bootable/recovery/partition.cpp`。

## 0005-gui-listbox-language.patch

作用：

- wipe/format 结束后重新加载当前语言并重绘；
- `LoadLanguage()` 在文件名为空时回落到默认语言。

启动页改回文件列表后，“高级”页不再在语言资源加载前被聚焦，原来的列表项重新翻译逻辑（`gui/listbox.cpp`）已经不需要，实测中文正常。

修改文件：`bootable/recovery/gui/action.cpp`、`gui/pages.cpp`。

## 0006-vold-clone-profile-decrypt.patch

作用：支持统一锁屏的 clone/managed profile（例如 XSpace、平行空间）。这类用户没有自己的锁屏凭据，只有 `gatekeeper.profile.key`；父用户认证通过后，用 keystore2 解出 profile key 派生的随机密码，再走普通 synthetic password 解密流程。

修改文件：`system/vold/Decrypt.cpp`。普通用户、独立密码用户和默认密码用户的处理不受影响。

## 0007-skip-absent-removable-partitions.patch

作用：可移动分区（例如 OTG 的 `/usb_otg`）拔出后，`Find_Actual_Block_Device()` 会保留上一次的 `Actual_Block_Device`，`Update_Size()` 仍去挂载已经不存在的设备节点，日志和界面会报挂载失败。补丁在分区不存在时跳过挂载并把大小清零，恢复 data 完成后的分区详情刷新不会再报这个错。

修改文件：`bootable/recovery/partition.cpp`。

## 设备树主题覆盖

刷机确认页的选项列表高度、AVB2 项顺序和“安装Ramdisk”按钮由设备树的 `recovery/root/twres/pages/install.xml` 覆盖，不修改 `bootable/recovery`。分区列表里的“安装恢复 Ramdisk”项仍由 OrangeFox 动态生成，保留不隐藏。

`/data` 的 `checkpoint=fs` 问题由设备树的 `BoardConfig.mk` 里 `TW_SKIP_ADDITIONAL_FSTAB := true` 解决。

## 上游状态

这些修改目前都还没有提交到 OrangeFox 上游。上游合入后可以删除对应补丁；删除前先确认上游实现与设备树行为一致。
