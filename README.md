<p align="center">
  <h1 align="center">Blurt</h1>
  <p align="center">The simplest way to publish on the web: push markdown, send an email, or just write. Your blog is live.</p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/status-coming%20soon-blueviolet?style=flat-square" alt="Coming Soon" />
  <a href="https://github.com/fberrez/blurt.sh/stargazers"><img src="https://img.shields.io/github/stars/fberrez/blurt.sh?style=flat-square" alt="Stars" /></a>
  <a href="https://github.com/fberrez/blurt.sh/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License" /></a>
</p>

---

## What is Blurt?

**Blurt** is an open-source publishing engine that turns a `git push` or an email into a live blog post. No CMS. No dashboard. No configuration. Just write and publish.

```
$ git push origin main   # Your markdown is now a blog post
$ echo "Hello" | mail post@blurt.sh   # ...or just send an email
```

For developers and technical writers who want a personal blog but hate setting up and maintaining one — Blurt handles the entire pipeline from content to deployed site.

## Why Blurt?

In early 2026, while browsing [1,736 dead YC startups](https://startups.rip), I found **Posterous** (YC S08). At its peak, Posterous had 15 million monthly visitors. The premise was simple: email something, and it becomes a blog post. It died in 2013 — not from lack of demand, but from strategic drift after a Twitter acquisition.

The core idea was right. It was just too early.

In 2026, the developer ecosystem has everything Posterous needed but didn't have: static site generators, edge deployment, markdown as a first-class format, and GitHub as the universal dev workspace. Blurt picks up where Posterous left off — rebuilt from scratch for developers, open-source, and designed to run at near-zero cost.

## How It Works

**Two publishing channels. Same result.**

### Email → Blog Post

Send an email to your Blurt address. The subject becomes the title. The body becomes the content. Attachments become images. Your post is live in under 60 seconds.

### Git Push → Blog Post

Add a `.md` file to your `/posts` directory. Push to main. Blurt renders it, generates OG images, builds your RSS feed, and deploys to the edge. Done.

## Features

- **Markdown-first** — Write in the format you already know
- **Zero config** — No databases to set up, no dashboards to learn
- **Git-native** — Your blog lives in your repo. Version-controlled by default.
- **Email publishing** — Send an email, get a blog post. Like Posterous, but better.
- **Edge deployment** — Static output deployed to Cloudflare's edge network. Sub-second loads.
- **Auto-generated OG images** — Every post gets a social card, automatically
- **RSS built-in** — Feed generated on every build
- **Dark mode** — Responsive, clean default theme with dark mode support
- **Self-host or hosted** — Run it yourself for free, or use `yourname.blurt.sh`
- **Open source** — MIT licensed. No vendor lock-in. Your content is yours.

## Tech Stack

| Layer            | Tool                     | Why                                      |
| ---------------- | ------------------------ | ---------------------------------------- |
| Blog engine      | Astro                    | Static output, great DX, markdown-native |
| Email processing | Cloudflare Email Workers | Reliable inbound email parsing           |
| Hosting          | Cloudflare Pages         | Free tier, edge deployment, fast         |
| Storage          | Cloudflare R2            | S3-compatible, no egress fees            |
| Database         | Turso                    | SQLite at the edge, free tier            |
| Auth             | Clerk                    | Simple auth with GitHub OAuth            |
| Payments         | Stripe                   | Standard, reliable                       |
| Analytics        | Plausible (self-hosted)  | Privacy-friendly, no cookies             |
| OG images        | Satori                   | Auto-generated social cards              |
| CI/CD            | GitHub Actions           | Free for public repos                    |

## Blurt vs. Alternatives

|                     | Blurt   | Ghost   | Hugo/Jekyll      | Substack | Hashnode | Dev.to | Medium     |
| ------------------- | ------- | ------- | ---------------- | -------- | -------- | ------ | ---------- |
| Git push to publish | **Yes** | No      | Yes (with setup) | No       | No       | No     | No         |
| Email to publish    | **Yes** | No      | No               | No       | No       | No     | No         |
| Zero config         | **Yes** | No      | No               | Yes      | Yes      | Yes    | Yes        |
| Open source         | **Yes** | Yes     | Yes              | No       | No       | No     | No         |
| Free self-hosting   | **Yes** | Yes     | Yes              | No       | No       | No     | No         |
| Custom domain       | **Yes** | Yes     | Yes              | No       | Yes      | No     | Yes (paid) |
| Syntax highlighting | **Yes** | Plugin  | Yes              | No       | Yes      | Yes    | No         |
| No vendor lock-in   | **Yes** | Partial | Yes              | No       | No       | No     | No         |

## Roadmap

- [x] Project vision and README
- [x] Project skeleton and CI setup
- [x] Email-to-post parsing spike
- [ ] Core MVP: email channel + git channel
- [ ] Hosted version with `username.blurt.sh`
- [ ] Pro tier with custom domains, analytics, and newsletters
- [ ] CLI tool: `npx blurt push`
- [ ] Themes, scheduled posts, import tools

## Contributing

Blurt is in early development. Star the repo to follow along, and watch for "good first issue" labels once we open up contributions.

## License

MIT
