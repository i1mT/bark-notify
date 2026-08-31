const defaultGitHubUrl = "https://github.com";

const githubUrl =
  process.env.NEXT_PUBLIC_GITHUB_URL?.replace(/\/$/, "") || defaultGitHubUrl;

export const siteConfig = {
  name: "BarkDesk",
  description: "原生 macOS Bark 客户端与简洁的 notify CLI。",
  githubUrl,
  downloadUrl:
    process.env.NEXT_PUBLIC_DOWNLOAD_URL ||
    (githubUrl === defaultGitHubUrl ? githubUrl : `${githubUrl}/releases/latest`),
};
