# 第三方组件与许可证

本文件适用于本仓库 GitHub Pages 站点发布的纯前端模拟平台。模拟平台由已构建的静态资源组成，完整许可证正文随产物分发，可在 [`/app/licenses/`](https://probiusofficial.github.io/PalaCTF/app/licenses/) 查看。

PalaCTF 本身的专有许可见 [LICENSE](LICENSE)。以下第三方组件依其各自许可证授权。

## 前端运行时依赖

版本来自构建时 `web/package-lock.json` 的解析结果。

| 包 | 版本 | 许可证 | 用途 |
|---|---|---|---|
| `react` | 19.3.1 | MIT | UI 运行时 |
| `react-dom` | 19.3.1 | MIT | DOM 渲染 |
| `react-router-dom` | 7.18.5 | MIT | 路由 |
| `@tanstack/react-query` | 5.105.0 | MIT | 数据请求与缓存 |
| `@radix-ui/react-avatar` | 1.3.1 | MIT | 无样式交互组件 |
| `@radix-ui/react-dialog` | 1.3.1 | MIT | 无样式交互组件 |
| `@radix-ui/react-dropdown-menu` | 2.2.1 | MIT | 无样式交互组件 |
| `@radix-ui/react-progress` | 1.2.1 | MIT | 无样式交互组件 |
| `@radix-ui/react-separator` | 1.2.0 | MIT | 无样式交互组件 |
| `@radix-ui/react-slot` | 1.5.0 | MIT | 无样式交互组件 |
| `@radix-ui/react-switch` | 1.4.1 | MIT | 无样式交互组件 |
| `@radix-ui/react-tabs` | 1.2.1 | MIT | 无样式交互组件 |
| `@radix-ui/react-tooltip` | 1.4.1 | MIT | 无样式交互组件 |
| `sonner` | 2.0.8 | MIT | Toast |
| `lucide-react` | 0.545.0 | ISC | 图标 |
| `class-variance-authority` | 0.7.1 | Apache-2.0 | 变体样式工具 |
| `clsx` | 2.1.1 | MIT | className 合并 |
| `tailwind-merge` | 3.7.0 | MIT | Tailwind 类冲突合并 |
| `@xterm/xterm` | 6.0.0 | MIT | 网页终端仿真 |
| `@xterm/addon-fit` | 0.11.0 | MIT | 终端尺寸自适应 |
| `dompurify` | 3.4.17 | MPL-2.0 或 Apache-2.0 | 富文本清洗 |
| `highlight.js` | 11.12.0 | BSD-3-Clause | 代码块语法高亮 |
| `katex` | 0.19.1 | MIT | 数学公式渲染 |
| `marked` | 18.1.2 | MIT | Markdown 解析 |
| `docx-preview` | 0.4.1 | Apache-2.0 | DOCX 在线预览 |
| `jszip` | 3.10.2 | MIT 或 GPL-3.0-or-later | 文档预览解压，作为 `docx-preview` 的依赖打包 |

## 字体

| 字体 | 上游项目 | 版权声明 | 许可证 |
|---|---|---|---|
| Geist | The Geist Project Authors（`vercel/geist-font`） | Copyright 2024 The Geist Project Authors | SIL Open Font License 1.1 |
| Geist Mono | The Geist Project Authors（`vercel/geist-font`） | Copyright 2024 The Geist Project Authors | SIL Open Font License 1.1 |
| Instrument Serif | The Instrument Serif Project Authors（`Instrument/instrument-serif`） | Copyright 2022 The Instrument Serif Project Authors | SIL Open Font License 1.1 |

字体经 Fontsource 打包进模拟平台。OFL 正文与版权声明随许可证页面分发；不得单独售卖字体，不得对字体文件本身施加额外限制。

## JSZip

模拟平台选择 MIT 许可证使用 JSZip：

```text
Copyright (c) 2009-2016 Stuart Knightley, David Duponchel, Franz Buchinger, António Afonso

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

## 组件骨架来源

界面组件的部分写法以 [shadcn/ui](https://ui.shadcn.com)（MIT）为起点，经改写后与平台样式、状态和无障碍行为对齐；项目骨架沿用 Vite `react-ts` 模板的公开结构。业务逻辑、页面文案与样式由 hello-ctf.com 编写。

## 说明

本文件是便于阅读的摘要。许可证全文、版权行与各组件许可文件名称以模拟平台的 `/app/licenses/` 页面为准；如摘要与随组件分发的许可证正文不一致，以许可证正文为准。
