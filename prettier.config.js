/** @type {import("prettier").Config} */
export default {
  singleQuote: false,
  trailingComma: "all",
  plugins: ["prettier-plugin-astro"],
  overrides: [
    {
      files: "*.astro",
      options: {
        parser: "astro",
      },
    },
  ],
};
