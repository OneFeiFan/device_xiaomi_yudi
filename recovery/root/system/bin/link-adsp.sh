#!/system/bin/sh
# 把 modem 分区里的 ADSP 固件链接到内核固件搜索路径。
# 段数变化时不需要改 init，链接完设置 sys.adsp.links.ready。

for f in /vendor/firmware_mnt/image/adsp.*; do
    [ -e "$f" ] || continue
    name="${f##*/}"
    ln -sf "$f" "/lib/firmware/$name"
done

setprop sys.adsp.links.ready 1
