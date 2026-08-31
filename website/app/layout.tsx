import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import "./sections.css";
import "./responsive.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || "https://barkdesk.example.com";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: "BarkDesk - macOS Bark 客户端与 notify CLI",
  description: "从原生 macOS 界面或一条短命令发送 Bark 通知，并在本机查看完整发送历史。",
  icons: {
    icon: "/brand/barkdesk-icon.png",
    apple: "/brand/barkdesk-icon.png",
  },
  openGraph: {
    title: "BarkDesk",
    description: "原生 macOS Bark 客户端与简洁的 notify CLI。",
    type: "website",
    locale: "zh_CN",
    images: ["/visuals/barkdesk-product.webp"],
  },
  twitter: {
    card: "summary_large_image",
    title: "BarkDesk",
    description: "原生 macOS Bark 客户端与简洁的 notify CLI。",
    images: ["/visuals/barkdesk-product.webp"],
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="zh-CN">
      <body className={`${geistSans.variable} ${geistMono.variable}`}>{children}</body>
    </html>
  );
}
