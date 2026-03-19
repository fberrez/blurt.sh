import type { Env } from "./types.js";

interface CommitResult {
  status: number;
  slug: string;
}

export async function commitPost(
  slug: string,
  content: string,
  env: Env,
): Promise<CommitResult> {
  const encoded = btoa(unescape(encodeURIComponent(content)));

  const result = await tryCommit(slug, encoded, env);

  // On 409 conflict, retry with timestamp suffix
  if (result.status === 409) {
    const deduped = `${slug}-${Date.now()}`;
    console.log(`Slug conflict for "${slug}", retrying as "${deduped}"`);
    return tryCommit(deduped, encoded, env);
  }

  return result;
}

async function tryCommit(
  slug: string,
  encodedContent: string,
  env: Env,
): Promise<CommitResult> {
  const path = `${env.POST_PATH}/${slug}.md`;
  const url = `https://api.github.com/repos/${env.REPO_OWNER}/${env.REPO_NAME}/contents/${path}`;

  const response = await fetch(url, {
    method: "PUT",
    headers: {
      Authorization: `Bearer ${env.GITHUB_TOKEN}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "Content-Type": "application/json",
      "User-Agent": "blurt-email-handler",
    },
    body: JSON.stringify({
      message: `post: ${slug} (via email)`,
      content: encodedContent,
    }),
  });

  if (!response.ok && response.status !== 409) {
    const body = await response.text();
    console.error(`GitHub API error: ${response.status} — ${body}`);
  }

  return { status: response.status, slug };
}
