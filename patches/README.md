# 补丁

## 0001-fox-settings-persistence.patch

作用：主题页的勾选写值加上 `persist=1`，让不在 `vars.xml` 和默认持久化表里的变量也能写入 `/sdcard/Fox/.foxs`。没有这个补丁时，`fox_boot_*` 等设置重启后会丢失。

修改文件：`bootable/recovery/gui/listbox.cpp`。

应用方法：

```sh
cd bootable/recovery
git apply ../../device/xiaomi/yudi/patches/0001-fox-settings-persistence.patch
```

每次 `repo sync` 覆盖 `bootable/recovery` 后都要重新应用。

上游状态：这是 OrangeFox 自身的缺陷，补丁还没有提交到上游。上游合入后可以删除这个补丁。
