import PostalMime from "postal-mime";
import { slugify } from "./slugify.js";
import type { PostData } from "./types.js";

function stripHtml(html: string): string {
  return (
    html
      // Line breaks
      .replace(/<br\s*\/?>/gi, "\n")
      // Paragraph ends
      .replace(/<\/p>/gi, "\n\n")
      // Links: <a href="url">text</a> → [text](url)
      .replace(/<a\s+[^>]*href="([^"]*)"[^>]*>(.*?)<\/a>/gi, "[$2]($1)")
      // Bold
      .replace(/<\/?(?:strong|b)>/gi, "**")
      // Italic
      .replace(/<\/?(?:em|i)>/gi, "*")
      // Strip remaining tags
      .replace(/<[^>]+>/g, "")
      // Decode common entities
      .replace(/&amp;/g, "&")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&nbsp;/g, " ")
      // Collapse excessive newlines
      .replace(/\n{3,}/g, "\n\n")
      .trim()
  );
}

function truncateAtWord(text: string, maxLen: number): string {
  if (text.length <= maxLen) return text;
  const truncated = text.slice(0, maxLen);
  const lastSpace = truncated.lastIndexOf(" ");
  return (lastSpace > 0 ? truncated.slice(0, lastSpace) : truncated) + "...";
}

function formatDate(dateStr: string | undefined): string {
  const date = dateStr ? new Date(dateStr) : new Date();
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function cleanSubject(subject: string): string {
  return subject.replace(/^(Re:|Fwd?:|FW:)\s*/gi, "").trim();
}

export async function parseEmail(raw: ReadableStream): Promise<PostData> {
  const parser = new PostalMime();
  const email = await parser.parse(raw);

  const title = cleanSubject(email.subject || "Untitled Post");
  const body = email.text || (email.html ? stripHtml(email.html) : "");
  const description = truncateAtWord(body.replace(/\n+/g, " ").trim(), 160);
  const pubDate = formatDate(email.date);

  const fromAddr = email.from?.address || "unknown";
  const author = email.from?.name || fromAddr;

  if (email.attachments?.length) {
    console.log(`Attachments found: ${email.attachments.length} (skipped)`);
  }

  return {
    title,
    description,
    pubDate,
    author,
    tags: ["email"],
    draft: true,
    body,
    slug: slugify(title),
  };
}

export function generateMarkdown(post: PostData): string {
  const frontmatter = [
    "---",
    `title: "${post.title.replace(/"/g, '\\"')}"`,
    `description: "${post.description.replace(/"/g, '\\"')}"`,
    `pubDate: ${post.pubDate}`,
    `tags: [${post.tags.map((t) => `"${t}"`).join(", ")}]`,
    `author: "${post.author.replace(/"/g, '\\"')}"`,
    `draft: ${post.draft}`,
    "---",
    "",
  ].join("\n");

  return frontmatter + post.body + "\n";
}
