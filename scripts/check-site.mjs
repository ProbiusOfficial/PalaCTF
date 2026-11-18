import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs'
import { dirname, extname, isAbsolute, join, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')

const args = process.argv.slice(2)
const baseArg = args.indexOf('--base')
const siteArg = args.find((arg, index) => !arg.startsWith('--') && args[index - 1] !== '--base')
const siteRoot = resolve(repoRoot, siteArg ?? 'site')

const DEFAULT_BASE = '/PalaCTF/app/'
const appBase = (baseArg >= 0 ? args[baseArg + 1] : process.env.PAGES_APP_BASE ?? DEFAULT_BASE)
  .replace(/^\/+/, '/')
  .replace(/\/*$/, '/')

const failures = []

function fail(message) {
  failures.push(message)
  console.error(`FAIL ${message}`)
}

function read(path) {
  try {
    return readFileSync(path, 'utf8')
  } catch {
    return null
  }
}

function walk(dir) {
  const files = []
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name)
    if (entry.isDirectory()) files.push(...walk(path))
    else files.push(path)
  }
  return files
}

const introPath = join(siteRoot, 'index.html')
const appDir = join(siteRoot, 'app')
const appIndexPath = join(appDir, 'index.html')
const fallbackPath = join(siteRoot, '404.html')

for (const path of [introPath, appIndexPath, join(appDir, '404.html'), fallbackPath, join(siteRoot, 'LICENSE')]) {
  if (!existsSync(path)) fail(`缺少 ${relative(repoRoot, path)}`)
}

const intro = read(introPath)
if (intro !== null) {
  if (!/PalaCTF/.test(intro)) fail('站点介绍页未包含 PalaCTF 标识')
  if (!/\bhref=["']app\/["']/.test(intro)) fail('站点介绍页缺少 app/ 入口')
  if (!/\bhref=["']app\/licenses\/["']/.test(intro)) fail('站点介绍页缺少 app/licenses/ 许可证入口')
}

const appIndex = read(appIndexPath)
const fallback = read(fallbackPath)
if (appIndex !== null && fallback !== null && appIndex !== fallback) {
  fail('站点根 404.html 与 app/index.html 内容不一致，深层链接将无法回退到模拟平台')
}

function localReferences(html) {
  return [...html.matchAll(/\b(?:src|href)\s*=\s*["']([^"']+)["']/gi)]
    .map((match) => match[1].trim())
    .filter((url) => url.startsWith('/') && !url.startsWith('//'))
}

for (const [name, html] of [
  ['app/index.html', appIndex],
  ['404.html', fallback],
]) {
  if (html === null) continue
  const references = localReferences(html)
  if (references.length === 0) {
    fail(`${name} 没有资源引用`)
    continue
  }
  for (const url of references) {
    if (!url.startsWith(appBase)) {
      fail(`${name} 的资源 ${url} 未使用应用前缀 ${appBase}`)
      continue
    }
    const relativePath = decodeURIComponent(url.slice(appBase.length).split(/[?#]/, 1)[0])
    if (!relativePath.includes('.')) continue
    const target = resolve(appDir, relativePath)
    const rel = relative(appDir, target)
    if (rel.startsWith('..') || isAbsolute(rel)) {
      fail(`${name} 的资源 ${url} 越出 app 目录`)
      continue
    }
    if (!existsSync(target) || !statSync(target).isFile()) {
      fail(`${name} 的资源 ${url} 不存在`)
    }
  }
}

const appFiles = walk(appDir)
const licensesChunks = appFiles.filter((path) => /(^|\/)licenses-[^/]+\.js$/.test(path))
if (licensesChunks.length === 0) fail('模拟平台缺少第三方许可证数据块')

const entryChunks = appFiles.filter((path) => /(^|\/)index-.*\.js$/.test(path))
if (entryChunks.length === 0) {
  fail('模拟平台缺少入口脚本')
} else {
  const entry = read(entryChunks[0]) ?? ''
  if (!entry.includes('pala-pages-mock-state-v1')) fail('模拟平台入口缺少本地模拟状态')
  if (!entry.includes('pala-bundle:pages')) fail('模拟平台入口缺少 Pages 构建标记')
  if (entry.includes('pala-bundle:production')) fail('模拟平台包含生产构建标记')
}

const textExtensions = new Set(['.js', '.css', '.html', '.json', '.svg', '.txt', '.webmanifest'])
for (const path of appFiles) {
  if (!textExtensions.has(extname(path))) continue
  const content = readFileSync(path, 'utf8')
  if (content.includes('sourceMappingURL')) fail(`${relative(siteRoot, path)} 包含源码映射引用`)
  if (content.includes('/home/linuxcore')) fail(`${relative(siteRoot, path)} 包含本机路径`)
}

const forbiddenExtensions = new Set(['.map', '.ts', '.tsx'])
for (const path of walk(siteRoot)) {
  const name = relative(siteRoot, path)
  if (forbiddenExtensions.has(extname(name))) fail(`站点包含不应发布的文件 ${name}`)
  if (name.split(/[\\/]/).some((part) => part === '.git' || part === '.env' || part.startsWith('.env.'))) {
    fail(`站点包含不应发布的文件 ${name}`)
  }
}

if (failures.length > 0) {
  console.error(`check-site: ${failures.length} 项检查失败`)
  process.exit(1)
}

console.log(`check-site: 通过（应用前缀 ${appBase}，${appFiles.length} 个应用文件）`)
