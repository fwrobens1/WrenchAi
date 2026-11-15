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
  "local __api2 = (function()",
  bundle,
  "end)()",
  `if __api.ui.destroyed ~= true then error("FAIL: previous UI was not destroyed on reload", 0) end
if G.WrenchAi ~= __api2 then error("FAIL: second run did not export a new api", 0) end
print("reload ok: 2 checks")`,
  "",
].join("\n");

await writeFile("test/out.luau", output, "utf8");
console.log("wrote test/out.luau");
