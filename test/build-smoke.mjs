import { readFile, writeFile } from "node:fs/promises";

const stubs = await readFile("test/stubs.luau", "utf8");
const bundle = await readFile("dist/WrenchAi.luau", "utf8");
const checks = await readFile("test/checks.luau", "utf8");

const output = [
  stubs,
  "local __api = (function()",
  bundle,
  "end)()",
  checks,
  "",
].join("\n");

await writeFile("test/out.luau", output, "utf8");
console.log("wrote test/out.luau");
