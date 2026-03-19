export interface Env {
  GITHUB_TOKEN: string;
  ALLOWED_SENDERS: string;
  REPO_OWNER: string;
  REPO_NAME: string;
  POST_PATH: string;
}

export interface PostData {
  title: string;
  description: string;
  pubDate: string;
  author: string;
  tags: string[];
  draft: boolean;
  body: string;
  slug: string;
}
