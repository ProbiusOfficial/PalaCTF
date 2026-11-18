# PalaCTF

PalaCTF 是面向私有化训练的综合 CTF 平台，将赛事、练习、课程与知识库放在同一套系统中。支持经典解题、AWD、AWDP 与综合渗透训练，并通过单机 Docker 管理靶机生命周期。

## 平台能力

- **赛事与解题**：报名、队伍、题目、动态 Flag、排行榜、公告与赛后复盘。
- **攻防训练**：AWD 轮次、服务可用性检查、AWDP 补丁验证与结算。
- **日常教学**：题单、课程、附件、知识库和学习进度。
- **私有化部署**：Linux、Docker Engine 和 PostgreSQL；应用以单个可执行文件提供 API 与网页。

## 获取与使用

Linux amd64 安装包已发布在本仓库的 [v0.1.0 Release](https://github.com/ProbiusOfficial/PalaCTF/releases/tag/v0.1.0)。安装前请阅读发布说明、校验文件及包内的许可证和安装文档；请勿使用其他来源的二进制文件冒充正式版本。

### 一键安装

Linux amd64 主机已准备 Docker Engine、Compose v2、buildx、PostgreSQL 镜像及 systemd 时，可用 `wget` 从 GitHub 下载固定版本的安装入口和发布公钥，核对脚本 SHA-256 与公钥指纹后安装：

```sh
bash -c 'set -euo pipefail; d=$(mktemp -d); trap '\''rm -rf -- "$d"'\'' EXIT; wget -q --https-only --timeout=15 --tries=3 -O "$d/install.sh" https://raw.githubusercontent.com/ProbiusOfficial/PalaCTF/ac63587ae1fcebc4203984666774234ee414295f/install.sh; wget -q --https-only --timeout=15 --tries=3 -O "$d/release.pub" https://github.com/ProbiusOfficial/PalaCTF/releases/download/v0.1.0/pala-release.pub; printf "%s  %s\n" baf99785c4eca09aa05f06de95b2c247b4fdd1cf421bce9456cc4db8b2026509 "$d/install.sh" | sha256sum -c -; test "$(openssl pkey -pubin -in "$d/release.pub" -outform DER | sha256sum | cut -d" " -f1)" = 3fa38a5fc0bf650327a774c9612e0bca49180764da484a3902535187649f40e7; sudo bash "$d/install.sh" --version 0.1.0 --pubkey "$d/release.pub" --pubkey-sha256 3fa38a5fc0bf650327a774c9612e0bca49180764da484a3902535187649f40e7 -- --yes'
```

安装命令固定了脚本提交、脚本摘要与签名公钥指纹；首次使用前仍应通过独立渠道核对这两个摘要。想先验证下载而不安装，可按下文下载脚本后使用 `--download-only`。安装器不会在缺少 Docker 时自动安装 Docker；Ubuntu 24.04 amd64 可在命令末尾的 `--yes` 后添加 `--install-docker`。当前没有自动更新或默认的在线更新检查。

先从 [Releases](https://github.com/ProbiusOfficial/PalaCTF/releases) 确认已有正式发布，再取得该发布使用的公钥文件与其 SHA-256 指纹。公钥的便利副本是本仓库的 [release.pub](release.pub)，发布页也给出同一份公钥。指纹针对公钥的 DER 编码计算；请通过项目维护者的独立渠道核对指纹，不能仅凭同一下载页面提供的公钥和指纹建立信任。

当前发布公钥指纹：

```
3fa38a5fc0bf650327a774c9612e0bca49180764da484a3902535187649f40e7
```

将公钥保存为本机的 `./palactf-release.pub`，并在普通用户终端核验：

```sh
openssl pkey -pubin -in ./palactf-release.pub -outform DER | sha256sum
```

若取得的是 X.509 证书，先执行 `openssl x509 -in ./palactf-release.crt -pubkey -noout > ./palactf-release.pub`，再运行上面的指纹命令。将结果与独立渠道公布的指纹逐字比较。指纹由你确认后，再下载本仓库的安装入口到本地文件并检查内容：

```sh
curl --fail --location --proto '=https' --proto-redir '=https' \
  --output ./palactf-install.sh \
  https://raw.githubusercontent.com/ProbiusOfficial/PalaCTF/main/install.sh
less ./palactf-install.sh
```

确认脚本内容及公钥可信后，使用普通用户已核验的文件调用 `sudo`。下面命令固定安装 `0.1.0`；省略 `--version` 时使用最新正式发布版本。脚本会验证下载校验值、签名 manifest 和包内安装脚本，然后运行安装器。下载失败或签名不符时会报错并停止。

```sh
sudo bash ./palactf-install.sh \
  --version 0.1.0 \
  --pubkey ./palactf-release.pub \
  --pubkey-sha256 3fa38a5fc0bf650327a774c9612e0bca49180764da484a3902535187649f40e7 \
  -- --yes
```

`sudo` 运行的是已保存并检查的本地脚本；公钥路径须允许 root 读取。若主机缺少 Docker，在支持的 Ubuntu 24.04 amd64 主机上可显式追加 `--install-docker` 到 `--` 之后，安装器才会使用签名包内经校验的 `docker-prereq.sh` 从 Docker 官方软件源安装依赖。其他主机请自行准备 Docker Engine、Compose v2、buildx 及 Docker 守护进程访问权限。可先将 `--yes` 换成 `--dry-run` 查看安装计划。

### 更新检查

`v0.1.0` 发布包不含内建的 `check-update` 命令；新版本发布后可用 `palactf check-update --pubkey /path/to/release.pub` 显式检查 GitHub 最新正式版。命令会验证签名清单、发布版本与对应安装包附件，发现更新时退出码为 `10`；已是最新或更高版本时为 `0`，检查失败为 `1`。只检查，不下载、不安装，也不在后台自动联网。当前 `v0.1.0` 的已签名清单发布在 [更新元数据](https://probiusofficial.github.io/PalaCTF/updates/linux-amd64/manifest.json)，并非新二进制版本。

[项目页面](https://probiusofficial.github.io/PalaCTF/) · [模拟平台](https://probiusofficial.github.io/PalaCTF/app/) · [发布记录](https://github.com/ProbiusOfficial/PalaCTF/releases)

## 在线模拟

项目页面提供纯前端模拟平台，入口为 [/app/](https://probiusofficial.github.io/PalaCTF/app/)。模拟平台不请求后端 API 或 WebSocket，赛事、题目、队伍、课程与排行榜数据全部在浏览器内构造并保存在本地存储；演示身份为虚构账号，无需注册。

模拟数据不代表真实赛事、成绩或部署状态，也不会读取任何生产环境数据。清除站点存储后，模拟状态恢复初始值。模拟平台包含的第三方组件许可见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)，完整正文可在模拟平台的 [许可证页面](https://probiusofficial.github.io/PalaCTF/app/licenses/) 查看。

## 许可

PalaCTF 为探姬（ProbiusOfficial）的专有软件。公开介绍和发布文件不意味着开源，也不授予使用、修改或再分发许可。第三方组件依其各自许可证授权；正式安装包随附相应声明及许可证正文。详见 [LICENSE](LICENSE)。

作者：探姬（ProbiusOfficial） · [GitHub](https://github.com/ProbiusOfficial) · 联系 tjsec@qq.com

© 2026 探姬（ProbiusOfficial）
