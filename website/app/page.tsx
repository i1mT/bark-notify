import {
  ArrowDown,
  ArrowRight,
  BellRinging,
  CheckCircle,
  Cloud,
  DeviceMobile,
  GithubLogo,
  HardDrives,
  Key,
  Laptop,
  Package,
  SlidersHorizontal,
  TerminalWindow,
  Wrench,
} from "@phosphor-icons/react/dist/ssr";
import Image from "next/image";
import { CopyCommand } from "@/components/copy-command";
import { SiteHeader } from "@/components/site-header";
import { siteConfig } from "@/lib/site";

const installCommand = "npm install -g barkdesk-notify";
const configureCommand = "notify config set --server https://bark.example.com --device YOUR_DEVICE_KEY";

const scenarios = [
  { icon: HardDrives, title: "服务器任务结束", body: "让备份、同步和定时任务结束后主动通知手机。", code: "notify run -- ./backup.sh" },
  { icon: Package, title: "构建与发布", body: "保留原命令退出码，同时把成功或失败结果发送到 Bark。", code: "notify run -- pnpm build" },
  { icon: Wrench, title: "临时手动提醒", body: "在 Mac 上选择通知类型，发送图片、链接、Markdown 或重要警告。", code: "在 BarkDesk 中发送" },
  { icon: BellRinging, title: "远程工作提醒", body: "离开终端以后，也不会错过耗时命令的完成时间。", code: "notify -t \"训练完成\" \"模型可以检查了\"" },
];

export default function Home() {
  return (
    <>
      <a className="skip-link" href="#main-content">跳到主要内容</a>
      <SiteHeader githubUrl={siteConfig.githubUrl} downloadUrl={siteConfig.downloadUrl} />
      <main id="main-content">
        <section id="top" className="hero-section">
          <div className="hero-copy">
            <p className="eyebrow">BarkDesk · macOS App 与跨平台 CLI</p>
            <h1>Bark 通知，手动发送或交给命令行。</h1>
            <p className="hero-summary">
              在 Mac 上用 BarkDesk 查看历史、选择通知类型；在 Linux、macOS 和 Windows 上用短小的
              <code>notify</code> 命令接收任务结果。
            </p>
            <div className="hero-actions">
              <a className="primary-button" href={siteConfig.downloadUrl}>
                <ArrowDown aria-hidden size={19} weight="bold" />下载 BarkDesk
              </a>
              <a className="text-button" href="#setup">先看如何配置<ArrowRight aria-hidden size={17} /></a>
            </div>
          </div>

          <aside className="start-card" aria-label="BarkDesk 与 notify CLI 的区别">
            <p className="card-kicker">先选择使用位置</p>
            <div className="start-option">
              <span className="option-icon"><Laptop aria-hidden size={24} /></span>
              <div><strong>BarkDesk</strong><span>安装在 Mac，首次打开时完成配置</span></div>
              <span className="platform-label">macOS 14+</span>
            </div>
            <div className="start-option">
              <span className="option-icon"><TerminalWindow aria-hidden size={24} /></span>
              <div><strong>notify CLI</strong><span>通过 npm 独立安装，需要单独配置</span></div>
              <span className="platform-label">跨平台</span>
            </div>
            <p className="start-note">两者不会自动共享配置或历史，也都不需要新的中间服务。</p>
          </aside>
        </section>

        <section className="principle-strip" aria-label="产品特点">
          <span><CheckCircle aria-hidden size={19} weight="fill" />直接连接 Bark Server</span>
          <span><CheckCircle aria-hidden size={19} weight="fill" />本机保存发送历史</span>
          <span><CheckCircle aria-hidden size={19} weight="fill" />MIT 开源</span>
        </section>

        <section id="prerequisites" className="section-shell prerequisites-section">
          <div className="section-heading narrow">
            <p className="eyebrow">开始前准备</p>
            <h2>先让 iPhone 准备好接收通知。</h2>
            <p>BarkDesk 和 notify 负责发送，iPhone 上的 Bark App 负责接收。按照下面三步准备一次即可。</p>
          </div>

          <div className="prerequisite-flow">
            <article className="prerequisite-card">
              <div className="prerequisite-heading">
                <span className="prerequisite-number">01</span>
                <DeviceMobile aria-hidden size={27} />
              </div>
              <h3>安装 Bark iOS App</h3>
              <p>从 App Store 安装 Bark，第一次打开时允许通知权限。BarkDesk 不能替代这个 iOS App。</p>
              <a className="inline-link" href={siteConfig.barkAppUrl} target="_blank" rel="noreferrer">
                前往 App Store<ArrowRight aria-hidden size={16} />
              </a>
            </article>

            <article className="prerequisite-card server-card">
              <div className="prerequisite-heading">
                <span className="prerequisite-number">02</span>
                <Cloud aria-hidden size={27} />
              </div>
              <h3>选择 Bark Server</h3>
              <div className="server-choice">
                <strong>最快开始</strong>
                <p>直接使用 Bark 默认的官方服务 <code>https://api.day.app</code>，不需要部署。</p>
              </div>
              <div className="server-choice recommended">
                <div><strong>个人部署推荐</strong><span>Cloudflare</span></div>
                <p>使用 Bark 官方部署文档列出的 bark-worker，个人低频使用推荐 D1 版本。</p>
                <div className="choice-links">
                  <a href={siteConfig.barkWorkerDeployUrl} target="_blank" rel="noreferrer">一键部署</a>
                  <a href={siteConfig.barkWorkerUrl} target="_blank" rel="noreferrer">查看说明</a>
                </div>
              </div>
              <p className="prerequisite-note">高频推送或已有主机，可以按照 Bark 官方文档部署 bark-server。</p>
              <a className="inline-link" href={siteConfig.barkDeployUrl} target="_blank" rel="noreferrer">
                查看全部部署方式<ArrowRight aria-hidden size={16} />
              </a>
            </article>

            <article className="prerequisite-card">
              <div className="prerequisite-heading">
                <span className="prerequisite-number">03</span>
                <SlidersHorizontal aria-hidden size={27} />
              </div>
              <h3>设置 Bark App</h3>
              <p>使用自建 Server 时，先在 Bark 中添加 Server 地址并完成注册。发送 App 内的测试通知，确认接收成功。</p>
              <p>复制测试推送地址：域名部分是 Server 地址，域名后的第一段是 Device Key。</p>
              <a className="inline-link" href={siteConfig.barkDocsUrl} target="_blank" rel="noreferrer">
                查看 Bark 使用文档<ArrowRight aria-hidden size={16} />
              </a>
            </article>
          </div>
          <p className="security-note"><Key aria-hidden size={17} />Device Key 相当于推送密码，请勿提交到仓库或粘贴到公开页面。</p>
        </section>

        <section id="setup" className="section-shell setup-section">
          <div className="section-heading">
            <p className="eyebrow">开始使用</p>
            <h2>Desk 和 CLI，需要分别配置一次。</h2>
            <p>完成上面的准备后，把 Bark Server 地址和 Device Key 分别填入需要使用的工具。</p>
          </div>

          <div className="setup-layout">
            <article id="desk" className="setup-panel desk-panel">
              <div className="panel-heading">
                <span className="panel-icon"><Laptop aria-hidden size={25} /></span>
                <div><p>macOS</p><h3>配置 BarkDesk</h3></div>
              </div>
              <ol className="steps-list">
                <li><span>1</span><div><strong>下载并打开 App</strong><p>打开 DMG，将 BarkDesk 拖入“应用程序”文件夹。</p></div></li>
                <li><span>2</span><div><strong>跟随首次启动引导</strong><p>填写 Bark Server 地址与 Device Key；需要 Basic Auth 时再填写账号密码。</p></div></li>
                <li><span>3</span><div><strong>检查连接并发送测试通知</strong><p>通过检查后进入发送页面，配置会保存在这台 Mac，其中敏感信息存入 Keychain。</p></div></li>
              </ol>
              <a className="primary-button compact" href={siteConfig.downloadUrl}><ArrowDown aria-hidden size={18} />下载最新 DMG</a>
            </article>

            <article id="cli" className="setup-panel cli-panel">
              <div className="panel-heading">
                <span className="panel-icon"><TerminalWindow aria-hidden size={25} /></span>
                <div><p>Linux · macOS · Windows</p><h3>配置 notify CLI</h3></div>
              </div>
              <div className="command-step"><span>1</span><div><strong>安装</strong><CommandBlock command={installCommand} /></div></div>
              <div className="command-step"><span>2</span><div><strong>保存配置</strong><CommandBlock command={configureCommand} /></div></div>
              <div className="command-step"><span>3</span><div><strong>检查并发送</strong><CommandBlock command={'notify config test\nnotify "配置完成"'} /></div></div>
              <p className="panel-note"><Key aria-hidden size={17} />服务器、容器和 CI 建议使用 <code>BARK_SERVER</code> 与 <code>BARK_DEVICE_KEY</code> 环境变量。</p>
            </article>
          </div>
        </section>

        <section id="scenarios" className="section-shell scenarios-section">
          <div className="section-heading narrow">
            <p className="eyebrow">适合这些时刻</p>
            <h2>不必守在终端前。</h2>
            <p>把通知放在真正需要知道结果的地方，不改变原来的工作方式。</p>
          </div>
          <div className="scenario-list">
            {scenarios.map(({ icon: Icon, title, body, code }, index) => (
              <article className="scenario-row" key={title}>
                <span className="scenario-number">0{index + 1}</span>
                <Icon aria-hidden size={26} />
                <div><h3>{title}</h3><p>{body}</p></div>
                <code>{code}</code>
              </article>
            ))}
          </div>
        </section>

        <section id="features" className="section-shell details-section">
          <div className="details-copy">
            <p className="eyebrow">覆盖日常需要</p>
            <h2>一个负责可视化，一个适合自动化。</h2>
            <p>BarkDesk 支持普通、图片、链接、重要警告、快捷复制和 Markdown 通知，并可查看、搜索与重新发送本机历史。</p>
            <p>notify CLI 支持 stdin、环境变量、secret file、命令退出码透传与独立历史，适合无桌面的服务器。</p>
          </div>
          <div className="type-cloud" aria-label="支持的 Bark 通知能力">
            <span>普通通知</span><span>图片</span><span>链接</span><span>Markdown</span>
            <span>重要警告</span><span>快捷复制</span><span>分组</span><span>提示音</span>
          </div>
        </section>

        <section id="download" className="section-shell download-section">
          <div className="download-panel">
            <Image src="/brand/barkdesk-icon.webp" width={68} height={68} alt="BarkDesk 红色铃铛图标" />
            <div><h2>选择适合你的入口。</h2><p>Mac 下载签名并经过 Apple 公证的 DMG；服务器通过 npm 安装 CLI。</p></div>
            <div className="download-actions">
              <a className="primary-button" href={siteConfig.downloadUrl}>下载 DMG</a>
              <a className="secondary-button" href={siteConfig.npmUrl} target="_blank" rel="noreferrer">查看 npm</a>
            </div>
          </div>
        </section>
      </main>

      <footer className="site-footer">
        <div><Image src="/brand/barkdesk-icon.webp" width={30} height={30} alt="" /><span>BarkDesk</span></div>
        <p>MIT License。第三方开源客户端，与 Bark 官方项目无隶属关系。</p>
        <a href={siteConfig.githubUrl} target="_blank" rel="noreferrer"><GithubLogo aria-hidden size={18} />GitHub</a>
      </footer>
    </>
  );
}

function CommandBlock({ command }: { command: string }) {
  return (
    <div className="mini-command">
      <pre><code>{command}</code></pre>
      <CopyCommand command={command} compact />
    </div>
  );
}
