# 补丁

这些补丁把 OrangeFox 的 `bootable/recovery` 和 `system/vold` 改成本设备树需要的状态。补丁按当前 OrangeFox `fox_16.0` 分支生成，`repo sync` 覆盖源码后需要重新应用。

## 应用顺序

先按编号应用 0001–0005 到 `bootable/recovery`，再应用 0006 到 `system/vold`：

```sh
cd bootable/recovery
for p in ../../device/xiaomi/yudi/patches/000[1-5]-*.patch; do
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

修改文件：`bootable/recovery/partition.cpp`。

## 0003-usb-otg-host-mode.patch

作用：`Check_UsbOtg_Status()` 在挂载 OTG 前置位 `sys.usb.otg_active`，卸载时清零；设备树的 init 规则据此避免在 MTP 开关时把已切到 host 的 USB 模式重写成 peripheral，并在 OTG 退出后立即恢复 device/ADB。

修改文件：`bootable/recovery/partitionmanager.cpp`。设备树侧对应的 `init.recovery.qcom.rc` 修改已经在设备树仓库里。

## 0004-wipe-stop-mtp-before-format.patch

作用：`Wipe_Encryption()` 在 `dmctl delete userdata` 和 `make_f2fs` 前先停 MTP，结束后恢复。MTP 会一直打开 `/data/media`，不停掉时 dm-userdata 处于 busy，`make_f2fs` 报 `In use by the system!` 并返回 255。

修改文件：`bootable/recovery/partition.cpp`。

## 0005-gui-listbox-language.patch

作用：

- 列表项保存原始（未翻译）名称，每次页面获得焦点都重新 `gui_parse_text()`，避免页面在语言资源加载前被聚焦后一直显示英文；
- wipe/format 结束后重新加载当前语言并重绘；
- `LoadLanguage()` 在文件名为空时回落到默认语言。

修改文件：`bootable/recovery/gui/listbox.cpp`、`gui/action.cpp`、`gui/pages.cpp`。

## 0006-vold-clone-profile-decrypt.patch

作用：支持统一锁屏的 clone/managed profile（例如 XSpace、平行空间）。这类用户没有自己的锁屏凭据，只有 `gatekeeper.profile.key`；父用户认证通过后，用 keystore2 解出 profile key 派生的随机密码，再走普通 synthetic password 解密流程。

修改文件：`system/vold/Decrypt.cpp`。普通用户、独立密码用户和默认密码用户的处理不受影响。

## 上游状态

这些修改目前都还没有提交到 OrangeFox 上游。上游合入后可以删除对应补丁；删除前先确认上游实现与设备树行为一致。
