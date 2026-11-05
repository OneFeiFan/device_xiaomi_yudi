# 构建

## 环境

- Linux 或 WSL2，约 150GB 磁盘
- 16GB 以上内存
- repo、git、ccache
- Android 16 源码，OrangeFox 的 `fox_16.0` 分支

## 拉取源码

```sh
mkdir orangefox_16
cd orangefox_16
repo init -u https://gitlab.com/OrangeFox/Manifest.git -b fox_16.0
repo sync -c --no-tags -j8
```

## 放入设备树

```sh
git clone https://github.com/OneFeiFan/device_xiaomi_yudi device/xiaomi/yudi
```

`recovery/root` 不需要在 `device.mk` 里拷贝。构建系统会把它铺进 recovery 的 ramdisk。

## 打补丁

`bootable/recovery/gui/listbox.cpp` 需要加一条 `persist=1`，否则部分主题勾选项只写内存。补丁在 `patches/0001-fox-settings-persistence.patch`。

```sh
cd bootable/recovery
git apply ../../device/xiaomi/yudi/patches/0001-fox-settings-persistence.patch
cd ../..
```

每次 `repo sync` 覆盖 `bootable/recovery` 后都要重新打一次。

## 编译

```sh
export FOX_BUILD_DEVICE=yudi
source build/envsetup.sh
lunch twrp_yudi-bp2a-eng
GOGC=50 GOMAXPROCS=8 mka -j14 adbd recoveryimage
```

内存紧张时降低并发数。产物在 `out/target/product/yudi/`：

- `recovery.img`
- `OrangeFox-*.img`
- `OrangeFox-*.zip`

`prebuilt/kernel` 是 0 字节占位文件，不要删除。构建系统需要 `TARGET_PREBUILT_KERNEL` 来定义 recovery 镜像目标；真正让构建不需要内核内容的是 `device.mk` 里的 `PRODUCT_ENABLE_UFFD_GC := false` 和 `PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false`。如果把内核文件删掉，构建可能显示成功，但不会产出 `recovery.img`。

## 增量构建

完整构建过一次后，只改 C/C++ 时可以跳过 Soong 和 Kati，直接调 ninja：

```sh
source build/envsetup.sh
lunch twrp_yudi-bp2a-eng
prebuilts/build-tools/linux-x86/bin/ninja -f out/combined-twrp_yudi.ninja -j14 adbd recoveryimage
```

只改 `recovery/root` 里已有的文件时，ninja 不一定知道暂存目录要重新拷贝。可靠的做法是先把文件同步到 `out/target/product/yudi/recovery/root/` 的对应路径，再执行上面的 ninja；或者直接走 `mka`，它会先跑 Soong/Kati，慢一些但不会漏文件。

改 `BoardConfig.mk`、`device.mk`、`Android.bp`、`vendorsetup.sh`，或者新增、删除会被 glob 的源文件时，必须回到 `mka` 重新生成 ninja。

直接调 ninja 前先 `source build/envsetup.sh` 和 `lunch`，否则 OrangeFox 的打包文件名可能缺设备名。`m --skip-soong-tests recoveryimage` 可以省掉 Soong 自检。

## ramdisk 暂存

`out/target/product/yudi/recovery/root` 偶尔会残留旧的 `libminuitwrp.so`。改了触摸相关代码却看不到效果时，先删掉这个目录和 `ramdisk-recovery.img` 再编。

改了 ramdisk 或主题文件后如果 ninja 认为无事可做，先删 `out/target/product/yudi/recovery.img`。必要时再删 `out/target/product/yudi/recovery/root`。
