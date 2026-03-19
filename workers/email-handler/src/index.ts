import { commitPost } from "./github.js";
import { generateMarkdown, parseEmail } from "./parse.js";
import type { Env } from "./types.js";

export default {
  async email(
    message: ForwardableEmailMessage,
    env: Env,
  ): Promise<void> {
    const sender = message.from;
    const allowed = env.ALLOWED_SENDERS.split(",").map((s) => s.trim().toLowerCase());

    if (!allowed.includes(sender.toLowerCase())) {
      console.log(`Rejected email from unauthorized sender: ${sender}`);
      return;
    }

    console.log(`Processing email from ${sender}: "${message.headers.get("subject")}"`);

    const post = await parseEmail(message.raw);
    const markdown = generateMarkdown(post);
    const result = await commitPost(post.slug, markdown, env);

    if (result.status === 201) {
      console.log(`Post committed: ${result.slug}.md`);
    } else {
      console.error(`Failed to commit post: HTTP ${result.status}`);
    }
  },
} satisfies ExportedHandler<Env>;
