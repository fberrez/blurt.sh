<p align="center">
  <h1 align="center">Blurt</h1>
  <p align="center">Own your social publishing. Write markdown, publish everywhere.</p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/status-in%20development-orange?style=flat-square" alt="In Development" />
  <a href="https://github.com/fberrez/blurt.sh/stargazers"><img src="https://img.shields.io/github/stars/fberrez/blurt.sh?style=flat-square" alt="Stars" /></a>
  <a href="https://github.com/fberrez/blurt.sh/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License" /></a>
</p>

---

## What is Blurt?

**Blurt** is an open-source social publishing queue. Write a markdown file, and Blurt publishes it to all your platforms at once. Your posts stay as files you own — not rows in someone else's database.

```
$ blurt post "hello world" --platforms bluesky,mastodon,linkedin
✓ Published to 3 platforms

$ ls sent/
hello-world.md   # your post, with platform permalinks
```

Drop a markdown file in `queue/`, and Blurt handles the rest: scheduling, publishing to multiple platforms in parallel, and keeping a full history of everything you've ever published.

## Why Blurt?

Buffer owns your content calendar. Hootsuite owns your analytics. Typefully owns your drafts. If any of them shut down, your publishing history disappears.

**Blurt gives it back.** Your posts are markdown files on your machine. Your publishing history is a folder. Every published post stores platform permalinks back to the original. That's your **system of record** — and you own it.

In the [SaaSpocalypse](https://techcrunch.com/2026/03/01/saas-in-saas-out-heres-whats-driving-the-saaspocalypse/) era, the tools that survive are the ones that own the data. Blurt makes sure **you** own it instead.

## How It Works

**Write once, publish everywhere.**

### The Queue

```
queue/my-post.md          →  worker picks it up every 60s
                          →  publishes to all platforms in parallel
                          →  moves to sent/ with permalinks
```

### Frontmatter

```markdown
---
platforms:
  - bluesky
  - mastodon
  - linkedin
scheduledAt: 2026-03-24T09:00:00Z
images:
  - path: photo.jpg
    alt: "Description"
---

Your post content here.
```

### Multiple Input Methods

| Method | How |
| ------ | --- |
| **Drop a file** | Put a `.md` file in `queue/`. That's it. |
| **CLI** | `blurt post "content" --platforms bluesky,mastodon` |
| **API** | `POST /posts` with markdown body |
| **MCP** | Publish from Claude Code, Cursor, or any AI editor |
| **Web UI** | Dashboard for composing, scheduling, and reviewing history |

## Platforms

| Platform | Type | Format |
| -------- | ---- | ------ |
| **Bluesky** | Social | Plaintext, rich text facets (links, mentions, hashtags) |
| **Mastodon** | Social | HTML, image attachments |
| **LinkedIn** | Social | Plaintext, image attachments |
| **Medium** | Blog | HTML |
| **Dev.to** | Blog | Raw markdown |
| **Substack** | Blog | HTML via SMTP (arrives as draft) |

## Features

- **Markdown-first** — Write in the format you already know
- **6 platforms** — Social (Bluesky, Mastodon, LinkedIn) + blog (Medium, Dev.to, Substack)
- **Filesystem as database** — Your posts are files. No database to manage, no data to migrate.
- **System of record** — Every published post stores platform permalinks. Full publishing history as files you own.
- **Scheduled posting** — Set `scheduledAt` in frontmatter. Post goes out at that time.
- **Image handling** — Auto-resizes per platform limits. Attach a photo, Blurt handles the rest.
- **Parallel publishing** — All platforms publish simultaneously. Failures are isolated per platform.
- **CLI + API + MCP** — Publish from terminal, code, or AI editors
- **Web dashboard** — Compose, schedule, review queue and history
- **Self-host or hosted** — Run it yourself for free, or use blurt.sh
- **Open source** — MIT licensed. No vendor lock-in. Your content is yours. Always.

## Blurt vs. Alternatives

|                        | Blurt   | Buffer  | Hootsuite | Typefully | Publer  |
| ---------------------- | ------- | ------- | --------- | --------- | ------- |
| Own your data (files)  | **Yes** | No      | No        | No        | No      |
| Open source            | **Yes** | No      | No        | No        | No      |
| Self-hostable          | **Yes** | No      | No        | No        | No      |
| Blog platforms         | **Yes** | No      | No        | No        | Partial |
| CLI / API / MCP        | **Yes** | Limited | API (paid)| No        | API (paid) |
| System of record       | **Yes** | No      | No        | No        | No      |
| Free tier              | **Yes** | Limited | No        | Limited   | Limited |

## Tech Stack

| Layer | Tool |
| ----- | ---- |
| Framework | Ruby on Rails 8 |
| Background jobs | Solid Queue |
| Database | SQLite |
| Frontend | Hotwire (Turbo + Stimulus) + Tailwind CSS |
| Image processing | libvips via image_processing gem |
| Deployment | Docker + Kamal |

## Roadmap

- [x] Rails 8 foundation — BlurtConfig, Post PORO, MarkdownProcessor, filesystem queue dirs
- [x] Queue engine — QueueScanner, PostMover, ImageProcessor, PublishOrchestrator, Solid Queue recurring jobs, file locking
- [ ] Platform publishers — Bluesky, Mastodon, LinkedIn, Medium, Dev.to, Substack
- [ ] HTTP API — CRUD posts, history, platforms, health, export
- [ ] CLI tool: `blurt post`, `blurt queue`, `blurt history`
- [ ] MCP server for AI editors
- [ ] Web dashboard
- [ ] Hosted version at blurt.sh
- [ ] Analytics and engagement tracking

## Getting Started

### Development

```bash
git clone https://github.com/fberrez/blurt.sh.git
cd blurt.sh
bundle install
cp .env.example .env  # configure your platform credentials
bin/rails db:prepare
bin/dev
```

### Self-Hosting (Docker)

```bash
docker run -v ./queue:/queue -v ./sent:/sent -v ./failed:/failed blurt/blurt
```

Configure platform credentials in `.env`. See `.env.example` for all available options.

## Contributing

Blurt is in early development. Star the repo to follow along, and watch for "good first issue" labels once we open up contributions.

## License

MIT
