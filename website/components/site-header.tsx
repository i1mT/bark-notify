"use client";

import { GithubLogo, List, X } from "@phosphor-icons/react";
import Image from "next/image";
import { useState } from "react";

type SiteHeaderProps = {
  githubUrl: string;
  downloadUrl: string;
};

export function SiteHeader({ githubUrl, downloadUrl }: SiteHeaderProps) {
  const [open, setOpen] = useState(false);

  return (
    <header className="site-header">
      <div className="site-header-inner">
        <a className="brand-link" href="#top" aria-label="BarkDesk 首页">
          <Image src="/brand/barkdesk-icon.webp" width={36} height={36} alt="" fetchPriority="high" />
          <span>BarkDesk</span>
        </a>

        <nav className="desktop-nav" aria-label="主导航">
          <a href="#features">功能</a>
          <a href="#cli">CLI</a>
          <a href="#privacy">隐私</a>
          <a href={githubUrl} target="_blank" rel="noreferrer">
            <GithubLogo aria-hidden size={18} weight="bold" />
            查看 GitHub
          </a>
          <a className="nav-download" href={downloadUrl}>
            下载 DMG
          </a>
        </nav>

        <button
          className="mobile-menu-button"
          type="button"
          aria-expanded={open}
          aria-controls="mobile-navigation"
          aria-label={open ? "关闭导航" : "打开导航"}
          onClick={() => setOpen((value) => !value)}
        >
          {open ? <X aria-hidden size={22} /> : <List aria-hidden size={22} />}
        </button>
      </div>

      {open ? (
        <nav id="mobile-navigation" className="mobile-nav" aria-label="移动导航">
          <a href="#features" onClick={() => setOpen(false)}>功能</a>
          <a href="#cli" onClick={() => setOpen(false)}>CLI</a>
          <a href="#privacy" onClick={() => setOpen(false)}>隐私</a>
          <a href={githubUrl} target="_blank" rel="noreferrer">查看 GitHub</a>
          <a className="nav-download" href={downloadUrl}>下载 DMG</a>
        </nav>
      ) : null}
    </header>
  );
}
