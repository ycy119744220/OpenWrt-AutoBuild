# OpenWrt x86_64 自动编译仓库（OpenWrt-AutoBuild）

自动跟踪 [openwrt/openwrt](https://github.com/openwrt/openwrt) 的最新**正式版** tag，编译 x86_64 软路由精简固件，并发布到本仓库的 Releases。

默认简体中文界面 + Argon 主题，集成本仓库预置的 OpenClash（含 Meta 内核与四个数据库）。

## 发布产物

每次编译**只发布 2 个文件**（其余产物一律不进 Release）：

| 文件 | 说明 |
| --- | --- |
| `openwrt-<ver>-x86-64-generic-ext4-combined-efi.img.gz` | 普通版，出厂默认配置 |
| `openwrt-<ver>-x86-64-generic-ext4-combined-efi-preconfigured.img.gz` | 预配置版，额外带初始网络/租约/转发/UPnP |

**两个镜像都默认简体中文 + Argon 主题**，区别只在初始网络配置。

`rootfs.tar.gz`、`kernel.bin`、`.config` 只留在 Actions artifact 里；SHA256 校验值打印在 `Checksums` 步骤日志中，不生成 `sha256sums.txt` 附件。同一 tag 重跑会先删掉旧 Release 再重建，不会残留历史附件。

## 四个工作流

| 工作流 | 触发 | 行为 |
| --- | --- | --- |
| `check-upstream.yml` | 每天 UTC 20:00、推送到 main、手动 | 取上游最新 `vX.Y.Z`（排除 rc/beta/alpha），与本仓库已有 Release 比对，**有新版本才编译** |
| `build.yml` | 被上游检测调用、手动（可指定 tag） | 编译 + 双镜像 + 发布 Release |
| `preflight.yml` | 改到配置/脚本/包时、手动 | **不编译**，只跑「拉源 → 配置 → 裁剪 → defconfig → 校验 → 预置包下载自检」，8-12 分钟，用来在花 3 小时编译前先验证配置链 |
| `keepalive.yml` | 每月 1 号、手动 | 只提交一个带时间戳的 `.keepalive`，不编译不发布 |

想立刻编译一次：Actions → `check-upstream` → Run workflow。
想只编译某个历史版本：Actions → `build` → Run workflow → 填 `v25.12.6`。
改完配置想先验证：Actions → `preflight` → Run workflow。

### 调试开关

仓库变量 `AUTO_BUILD_ENABLED` 设为 `false` 时，`check-upstream` 只检测不编译（改配置期间避免误触发 3 小时任务）。删掉该变量或设为 `true` 即恢复自动编译。

## 刷写

1. 解压 `.img.gz` 得到 `.img`
2. 用 Etcher / Rufus / `dd` 写入 U 盘或 SSD
3. **UEFI** 引导启动（本仓库不编译 BIOS/Legacy 镜像）
4. 网线接 LAN 口，浏览器打开 `http://192.168.1.1`
5. 首次登录**必须**设置 root 密码（镜像里 root 无密码）

串口控制台为 `ttyS0`，115200 8N1。x86 下 `eth0` 为 WAN，其余为 LAN（口序以实际网卡排序为准，开机后可在「网络 → 接口」里核对）。

## 预配置版包含什么

仅 `-preconfigured` 镜像包含，写入 `/etc/uci-defaults/90-preconfigured`，首次启动执行一次：

- LAN `192.168.1.1/24`，DHCP 池 `192.168.1.100-199`，租期 12h
- WAN 为 PPPoE 模板（账号密码留空，登录后填）
- 4 条静态租约：`Yang-PC .88`、`IQOO-12 .89`、`AX6000 .2`、`AX6000-2 .3`（均在 `192.168.88.0/24`）
- 5 条端口转发（全部 TCP → `192.168.88.254`）：8890 / 8888 / 6690 / 443 / 9999
- UPnP 开启：IGD + NAT-PMP + PCP + IGDv1 兼容，下行 1024、上行 512 kB/s
- 时区 `Asia/Shanghai`，NTP 指向国内源

> **注意**：静态租约与端口转发写的是 `192.168.88.x`，只有 LAN 处于 `192.168.88.0/24` 时才生效。若 LAN 是 `192.168.1.1/24`，这两组配置会被 dnsmasq/防火墙忽略（不报错，也不生效）。把 LAN 改成 `192.168.88.1/24` 后立即生效，无需改其它配置。

## 自定义

改 `config/x86_64.config` 增删包即可，CI 会追加 `config/ci-extra.config`（OpenClash 依赖）。

- 加包：`CONFIG_PACKAGE_<name>=y`
- 减包：`CONFIG_PACKAGE_<name>=n`
- 注意 `.config` 里**不能写行尾注释**，`prepare_config.sh` 会自动剥离，但仍建议写成整行注释
- 改完务必让 `scripts/verify_config.sh` 里的清单跟着调整，否则构建会失败（这是有意的）

其他可改点：

| 文件 | 作用 |
| --- | --- |
| `scripts/trim_x86.py` | 剔除 `target/linux/x86/image/64.mk` 里不需要的网卡/显卡驱动，`KEEP` 集合里是要保留的 |
| `scripts/feeds.sh` | 第三方 feed 与 OpenClash 版本解析 |
| `files/common/` | 两个镜像都注入的 uci-defaults（主题、语言） |
| `files/preconfigured/` | 只注入预配置镜像的 uci-defaults |

## 构建期自检

编译不是"跑完就算成功"，以下检查任一失败都会让 job 失败、不发 Release：

1. `verify_config.sh`：`kmod-igc`/Argon/argon-config/OpenClash/两个本地包/`dnsmasq-full`/中文语言开关必须 `=y`；`luci-app-fstab`/`block-mount`/多余网卡驱动不得 `=y`（符号若不存在也算通过，因为 kconfig 对未被引用的符号不写任何行）
2. `verify_firmware.sh`：rootfs 里必须真的有 Argon 主题文件、中文语言包、`clash_meta` 内核、四个数据库，且首启脚本带执行位；普通版不得含预配置脚本
3. `make_preconfigured.sh`：注入后必须能在镜像里找到 `90-preconfigured` 且权限为 755，输出 gzip 需通过完整性校验

## 为什么这么设计

- **一次编译出两个镜像**：预配置版不重新编译，而是 `losetup` 挂载已构建的 ext4 镜像，把 overlay 写进去再压回。省掉一遍 3 小时编译。
- **四个数据库打进固件**：`package/openclash-geo-db` 在编译期下载并安装到 `/etc/openclash/`，刷完机不用等 OpenClash 联网下载（它的 `install.sh` 本来就只在运行时下载）。
- **Meta 内核来自 mihomo 官方 release**：`MetaCubeX/mihomo` 的 `mihomo-linux-amd64-v1-<tag>.gz`，编译期解压后落地 `/etc/openclash/core/clash_meta`，并在构建机上跑一次 `-v` 确认是可执行文件。OpenClash 自己的仓库里并没有预编译内核，其 `install.sh` 是运行期才下载的，所以必须自己预置。
- **Argon 的两个包走 `package/` 而不是 feed**：`luci-theme-argon`、`luci-app-argon-config` 都是「仓库根目录就是包本身」的结构，写成 `src-git` 时 25.12 的 feed 索引生成会报 `target pattern contains no '%'`，随后 `Ignoring feed 'argon' - index missing`，包直接进不了包树。改为 clone 到 `package/` 后完全绕开索引。
- **挂载点菜单天然不存在**：25.12 已把 `block-mount` 并入 `fstools`，LuCI 侧也不再提供 `luci-app-fstab`，所以「删除挂载点」无需额外操作；`.config` 里保留 `=n` 只是防上游回退。
- **action 全部 pin 到 node24 版本**：`checkout@v5`、`cache@v5`、`upload-artifact@v6`、`action-gh-release@v3`，不会有 Node.js 20 弃用告警；runner 显式写 `ubuntu-24.04`，不跟随 `ubuntu-latest` 迁移到 Ubuntu 26。
- **脚本一律用 glob 找产物**：不硬编码 `x86-64-generic-*` 文件名，避免上游改了设备命名后到最后一刻才失败。

## 关闭自动编译

删掉 `.github/workflows/check-upstream.yml` 的 `schedule` 段，或直接 Actions → `check-upstream` → `...` → Disable workflow。
