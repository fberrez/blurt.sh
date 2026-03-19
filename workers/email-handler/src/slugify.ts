export function slugify(subject: string): string {
  return (
    subject
      // Strip email prefixes
      .replace(/^(Re:|Fwd?:|FW:)\s*/gi, "")
      .trim()
      .toLowerCase()
      // Replace non-alphanumeric with hyphens
      .replace(/[^a-z0-9]+/g, "-")
      // Collapse consecutive hyphens
      .replace(/-+/g, "-")
      // Trim leading/trailing hyphens
      .replace(/^-|-$/g, "")
      // Truncate to 60 chars without breaking mid-hyphen
      .slice(0, 60)
      .replace(/-$/, "")
  );
}
