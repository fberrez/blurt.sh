---
title: "Hello, World"
description: "Welcome to Blurt — the simplest way to publish on the web."
pubDate: 2026-03-18
tags: ["intro", "blurt"]
author: "Blurt"
---

Welcome to **Blurt**, an open-source blog publishing engine. Write markdown, push to git, and your post is live.

## How it works

1. Write your post in markdown
2. Push to your repository
3. Your blog updates automatically

## Syntax highlighting

Blurt supports syntax highlighting out of the box:

```typescript
import { getCollection } from "astro:content";

const posts = await getCollection("posts");
console.log(`Found ${posts.length} posts`);
```

That's it. Happy writing!
