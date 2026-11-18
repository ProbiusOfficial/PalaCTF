# PalaCTF

PalaCTF 是面向私有化训练的综合 CTF 平台，将赛事、练习、课程与知识库放在同一套系统中。支持经典解题、AWD、AWDP 与综合渗透训练，并通过单机 Docker 管理靶机生命周期。

## 平台能力

- **赛事与解题**：报名、队伍、题目、动态 Flag、排行榜、公告与赛后复盘。
- **攻防训练**：AWD 轮次、服务可用性检查、AWDP 补丁验证与结算。
- **日常教学**：题单、课程、附件、知识库和学习进度。
- **私有化部署**：Linux、Docker Engine 和 PostgreSQL；应用以单个可执行文件提供 API 与网页。

## 获取与使用

正式发布的 Linux 安装包将列在本仓库的 [Releases](https://github.com/ProbiusOfficial/PalaCTF/releases)。安装前请阅读对应发布说明、校验文件及包内的许可证和安装文档。未出现正式发布包时，请勿使用其他来源的二进制文件冒充正式版本。

[项目页面](https://probiusofficial.github.io/PalaCTF/) · [模拟平台](https://probiusofficial.github.io/PalaCTF/app/) · [发布记录](https://github.com/ProbiusOfficial/PalaCTF/releases)

## 在线模拟

项目页面提供纯前端模拟平台，入口为 [/app/](https://probiusofficial.github.io/PalaCTF/app/)。模拟平台不请求后端 API 或 WebSocket，赛事、题目、队伍、课程与排行榜数据全部在浏览器内构造并保存在本地存储；演示身份为虚构账号，无需注册。

模拟数据不代表真实赛事、成绩或部署状态，也不会读取任何生产环境数据。清除站点存储后，模拟状态恢复初始值。模拟平台包含的第三方组件许可见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)，完整正文可在模拟平台的 [许可证页面](https://probiusofficial.github.io/PalaCTF/app/licenses/) 查看。

## 许可

PalaCTF 为 hello-ctf.com 的专有软件。公开介绍和发布文件不意味着开源，也不授予使用、修改或再分发许可。第三方组件依其各自许可证授权；正式安装包随附相应声明及许可证正文。详见 [LICENSE](LICENSE)。

© 2026 hello-ctf.com
