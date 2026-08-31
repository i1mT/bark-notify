import {
  ArrowDown,
  ArrowRight,
  BellRinging,
  GithubLogo,
  Key,
  ShieldCheck,
  TerminalWindow,
} from "@phosphor-icons/react/dist/ssr";
import Image from "next/image";
import { CopyCommand } from "@/components/copy-command";
import { HeroEntrance, Reveal } from "@/components/content-shell";
import { SiteHeader } from "@/components/site-header";
import { siteConfig } from "@/lib/site";

const command = 'notify -t "部署完成" "生产环境已经更新"';

export default function Home() {
  return (
    <>
      <SiteHeader githubUrl={siteConfig.githubUrl} downloadUrl={siteConfig.downloadUrl} />
      <main>
        <section id="top" className="hero-section">
          <div className="hero-grid">
            <HeroEntrance className="hero-copy">
              <p className="hero-eyebrow">macOS App + 跨平台 CLI</p>
              <h1>把 Bark 通知，放进 Mac、服务器和终端。</h1>
              <p className="hero-summary">原生 macOS 客户端，加上可以通过 npm 安装的 notify 命令。</p>
              <div className="hero-actions">
                <a className="primary-button" href={siteConfig.downloadUrl}>
                  <ArrowDown aria-hidden size={20} weight="bold" />
                  下载 macOS App
                </a>
                <a className="secondary-button" href={siteConfig.githubUrl} target="_blank" rel="noreferrer">
                  <GithubLogo aria-hidden size={20} weight="bold" />
                  查看 GitHub
                </a>
              </div>
            </HeroEntrance>

            <HeroEntrance className="hero-visual">
              <div className="screenshot-shell">
                <Image
                  src="/screenshots/barkdesk-history.webp"
                  width={1920}
                  height={1342}
                  alt="BarkDesk 中文通知历史界面"
                  fetchPriority="high"
                  loading="eager"
                />
              </div>
            </HeroEntrance>
          </div>
        </section>

        <section className="fact-strip" aria-label="项目特点">
          <div><BellRinging aria-hidden size={24} /><span>SwiftUI 原生界面</span></div>
          <div><TerminalWindow aria-hidden size={24} /><span>Linux、macOS、Windows</span></div>
          <div><Key aria-hidden size={24} /><span>App Keychain / Server Secret</span></div>
        </section>

        <section id="features" className="section-shell">
          <Reveal className="section-heading">
            <h2>发送、追踪、重新发送。</h2>
            <p>App 与 CLI 各自管理本机配置和历史，但都直接连接你的 Bark Server。</p>
          </Reveal>

          <div className="feature-grid">
            <Reveal className="feature-cell product-cell">
              <Image
                src="/visuals/barkdesk-product.webp"
                width={1600}
                height={1067}
                alt="红色 BarkDesk 图标的产品展示图"
              />
              <div className="cell-copy">
                <h3>为 macOS 设计</h3>
                <p>中文界面、系统材质、菜单栏入口，以及符合使用顺序的首次配置。</p>
              </div>
            </Reveal>

            <Reveal className="feature-cell command-cell">
              <TerminalWindow aria-hidden size={34} weight="duotone" />
              <h3>命令足够短</h3>
              <pre><code>npm i -g barkdesk-notify</code></pre>
              <pre><code>notify &quot;构建完成&quot;</code></pre>
              <p>也可以用 notify run 包裹任何命令，并保留原命令退出码。</p>
            </Reveal>

            <Reveal className="feature-cell history-cell">
              <div className="history-image-wrap">
                <Image
                  src="/screenshots/barkdesk-history.webp"
                  width={1920}
                  height={1342}
                  alt="BarkDesk 发送历史与通知详情"
                />
              </div>
              <div className="cell-copy">
                <h3>成功与失败都可追踪</h3>
                <p>搜索、复制、删除和重新发送，历史只保存在这台 Mac。</p>
              </div>
            </Reveal>

            <Reveal className="feature-cell types-cell">
              <BellRinging aria-hidden size={38} weight="duotone" />
              <h3>覆盖 Bark 通知类型</h3>
              <div className="type-list" aria-label="支持的通知类型">
                <span>普通通知</span><span>图片通知</span><span>链接通知</span>
                <span>重要警告</span><span>快捷复制</span><span>Markdown</span>
              </div>
            </Reveal>
          </div>
        </section>

        <section id="cli" className="cli-section">
          <Reveal className="cli-copy">
            <h2>终端结束时，让手机知道。</h2>
            <p>在 Ubuntu 服务器、macOS 或 Windows 中使用，用于构建、部署和备份任务。</p>
            <div className="cli-notes">
              <span>stdin 输入</span>
              <span>npm 独立安装</span>
              <span>完整 Bark 参数</span>
              <span>原样返回退出码</span>
            </div>
          </Reveal>

          <Reveal className="command-stage">
            <div className="command-line">
              <span aria-hidden>$</span>
              <code>{command}</code>
            </div>
            <CopyCommand command={command} />
            <div className="command-examples">
              <code>notify run pnpm build</code>
              <code>echo &quot;完成&quot; | notify -t &quot;备份&quot;</code>
            </div>
          </Reveal>
        </section>

        <section id="privacy" className="privacy-section">
          <Reveal className="privacy-copy">
            <ShieldCheck aria-hidden size={42} weight="duotone" />
            <h2>不增加新的中间服务。</h2>
            <p>App 使用 macOS Keychain；CLI 支持环境变量、secret file 和权限受限的配置文件。两者都不会增加中间转发服务。</p>
          </Reveal>

          <Reveal className="delivery-flow">
            <div><strong>BarkDesk / notify</strong><span>Mac / Linux / Windows</span></div>
            <ArrowRight aria-hidden size={24} />
            <div><strong>Bark Server</strong><span>你的地址</span></div>
            <ArrowRight aria-hidden size={24} />
            <div><strong>APNs / iPhone</strong><span>Bark 通知</span></div>
          </Reveal>
        </section>

        <section id="download" className="download-section">
          <Reveal className="download-panel">
            <div>
              <h2>macOS 下载 App，服务器安装 npm CLI。</h2>
              <p>App 需要 macOS 14 或更高版本；CLI 需要 Node.js 20.9 或更高版本。</p>
            </div>
            <div className="download-actions">
              <a className="primary-button" href={siteConfig.downloadUrl}>
                <ArrowDown aria-hidden size={20} weight="bold" />
                下载 DMG
              </a>
              <a className="secondary-button" href={siteConfig.npmUrl} target="_blank" rel="noreferrer">
                <TerminalWindow aria-hidden size={20} weight="bold" />
                查看 npm
              </a>
            </div>
          </Reveal>
        </section>
      </main>

      <footer className="site-footer">
        <div>
          <Image src="/brand/barkdesk-icon.webp" width={32} height={32} alt="" />
          <span>BarkDesk</span>
        </div>
        <p>MIT License。BarkDesk 是第三方开源客户端，与 Bark 官方项目无隶属关系。</p>
        <a href={siteConfig.githubUrl} target="_blank" rel="noreferrer">查看 GitHub</a>
      </footer>
    </>
  );
}
