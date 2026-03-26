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

Drop a markdown file in `queue/`, and Blurt handles the rest: scheduling, publishing to multiple platforms in parallel, and keeping a full history of everything you've ever published.

## Why Blurt?

Buffer owns your content calendar. Hootsuite owns your analytics. Typefully owns your drafts. If any of them shut down, your publishing history disappears.

**Blurt gives it back.** Your posts are markdown files on your machine. Your publishing history is a folder. Every published post stores platform permalinks back to the original. That's your **system of record** — and you own it.

## How It Works

```
queue/my-post.md    →    worker polls every 60s    →    sent/my-post.md (with permalinks)
                                                   →    failed/my-post.md (with errors)
```

1. Write a markdown file with YAML frontmatter specifying target platforms
2. Drop it into `queue/`
3. The worker picks it up, publishes to each platform in parallel, and moves the file to `sent/` with permalinks (or `failed/` with error details in the frontmatter)

## Post Format

### Social post (flat file)

```markdown
---
platforms:
  - bluesky
  - mastodon
  - linkedin
scheduledAt: 2026-03-24T09:00:00Z  # optional, omit for immediate
---

Your post content here. Supports **markdown**.
```

### Blog post

Blog platforms (Medium, Dev.to, Substack) require a `title` field. You can target both social and blog platforms in the same post — social platforms ignore the title.

```markdown
---
platforms:
  - medium
  - devto
  - substack
title: "Why Posterous Was Ahead of Its Time"
---

Long-form **markdown** content here...
```

### Post with images (subdirectory)

Place the markdown file and images together in a subdirectory of `queue/`:

```
queue/
  my-post/
    post.md
    photo.jpg
    banner.png
```

```markdown
---
platforms:
  - bluesky
  - linkedin
images:
  - path: photo.jpg
    alt: "A sunset over the mountains"
  - path: banner.png
---

Post content here.
```

After publishing, the entire directory is moved to `sent/` (or `failed/`).

### Frontmatter fields

| Field | Required | Description |
|---|---|---|
| `platforms` | Yes | One or more of `bluesky`, `mastodon`, `linkedin`, `medium`, `devto`, `substack` |
| `title` | For blog platforms | Post title for Medium, Dev.to, and Substack |
| `scheduledAt` | No | ISO 8601 timestamp. Post waits in queue until this time |
| `images` | No | Array of `{path, alt}`. Max 4 images. Formats: jpg, png, gif, webp |

## Platforms

| Platform | Type | Format | Features |
| -------- | ---- | ------ | -------- |
| **Bluesky** | Social | Plaintext | Rich text facets (links, mentions, hashtags), link previews, image uploads |
| **Mastodon** | Social | Plaintext | Bare domain auto-linking, image attachments with alt text |
| **LinkedIn** | Social | Plaintext | Link previews with OG thumbnails, image attachments |
| **Medium** | Blog | HTML | Requires title |
| **Dev.to** | Blog | Raw markdown | Requires title |
| **Substack** | Blog | HTML via SMTP | Arrives as draft, requires title |

## Getting Started

### Prerequisites

- Ruby 3.4+
- libvips (for image processing)
- SQLite3

### Installation

```bash
git clone https://github.com/fberrez/blurt.sh.git
cd blurt.sh
bundle install
cp .env.example .env
bin/rails db:prepare
```

### Platform Credentials

Edit `.env` with your credentials. You only need to configure the platforms you want to use.

**Bluesky** — uses an [app password](https://bsky.app/settings/app-passwords):
```
BLUESKY_SERVICE=https://bsky.social
BLUESKY_IDENTIFIER=your.handle.bsky.social
BLUESKY_PASSWORD=your-app-password
```

**Mastodon** — generate an access token in Preferences > Development > New Application:
```
MASTODON_URL=https://mastodon.social
MASTODON_ACCESS_TOKEN=your-access-token
```

**LinkedIn** — requires an OAuth 2.0 token with `w_member_social` scope:
1. Create an app at [LinkedIn Developers](https://www.linkedin.com/developers/)
2. Enable **Share on LinkedIn** and **Sign In with LinkedIn using OpenID Connect** products
3. Add `http://localhost:3847/callback` as an authorized redirect URL in the Auth tab
4. Set `LINKEDIN_CLIENT_ID` and `LINKEDIN_CLIENT_SECRET` in `.env`
5. Run `rake blurt:linkedin_auth` to authenticate and get your token

```
LINKEDIN_CLIENT_ID=your-client-id
LINKEDIN_CLIENT_SECRET=your-client-secret
LINKEDIN_ACCESS_TOKEN=your-oauth-token
LINKEDIN_PERSON_ID=your-person-id
```

> LinkedIn tokens expire every 60 days. Run `rake blurt:linkedin_auth` to re-authenticate when you get a 401 error.

**Medium** — generate an [integration token](https://medium.com/me/settings/security):
```
MEDIUM_INTEGRATION_TOKEN=your-integration-token
```

**Dev.to** — generate an API key in [Settings > Extensions](https://dev.to/settings/extensions):
```
DEVTO_API_KEY=your-api-key
```

**Substack** — uses SMTP to email posts to your Substack import address. Posts arrive as drafts.
```
SUBSTACK_SMTP_HOST=smtp.gmail.com
SUBSTACK_SMTP_PORT=587
SUBSTACK_SMTP_USER=your-email@gmail.com
SUBSTACK_SMTP_PASSWORD=your-app-password
SUBSTACK_FROM_ADDRESS=your-email@gmail.com
SUBSTACK_TO_ADDRESS=your-substack-import@substack.com
```

### Running

```bash
# Development (with hot reload)
bin/dev

# Or start the server and worker separately
bin/rails server
bin/jobs
```

The worker polls `queue/` every 60 seconds. To publish immediately:

```bash
bin/rails runner "ScanQueueJob.perform_now"
```

## Architecture

```
queue/     →  QueueScanner finds pending posts
           →  PublishOrchestrator publishes to all platforms in parallel
           →  PostMover moves to sent/ (with permalinks) or failed/ (with errors)
```

- **Posts are POROs** — `Post` is a plain Ruby object that reads `.md` files. No ActiveRecord.
- **Filesystem is authoritative** — SQLite only stores `PublishLog` for fast queries. The files in `sent/` are the system of record.
- **File locking** — prevents double-processing via `.publishing` suffix rename.
- **Parallel publishing** — all platforms publish simultaneously via `Concurrent::Future`.
- **Link previews** — Bluesky and LinkedIn automatically fetch OG metadata and attach link cards with thumbnails.

## Tech Stack

| Layer | Tool |
| ----- | ---- |
| Framework | Ruby on Rails 8 |
| Background jobs | Solid Queue |
| Database | SQLite (metadata only) |
| Image processing | libvips via image_processing gem |
| HTTP client | Faraday + faraday-multipart |

## Roadmap

- [x] Rails 8 foundation — BlurtConfig, Post PORO, MarkdownProcessor, filesystem queue
- [x] Queue engine — QueueScanner, PostMover, ImageProcessor, PublishOrchestrator, file locking
- [x] Social publishers — Bluesky (AT Protocol, facets, link previews), Mastodon, LinkedIn (OG thumbnails)
- [ ] Blog publishers — Medium, Dev.to, Substack
- [ ] HTTP API — CRUD posts, history, platforms, health, export
- [ ] Docker deployment
- [ ] CLI tool
- [ ] MCP server for AI editors
- [ ] Web dashboard
- [ ] Hosted version at blurt.sh

## Design Decisions

- **Filesystem as state** — `queue/` is pending, `sent/` is done, `failed/` has errors. No database needed.
- **No UI required** — Drop a file, it gets published. CLI, API, and web UI are optional interfaces.
- **Sent files get enriched** — platform permalinks are written back into frontmatter. Your files are the system of record.
- **Failed posts preserve context** — error details and any successful URLs are written into the frontmatter so you can inspect and retry.
- **Plaintext for social, HTML for blogs** — Bluesky and LinkedIn get plaintext with platform-native formatting. Medium and Substack get HTML. Dev.to gets raw markdown.

## License

MIT
