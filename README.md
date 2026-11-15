# WrenchAi

In-executor Roblox chat agent: <https://github.com/fwrobens1/WrenchAi>

An in-game Roblox chat agent that runs entirely inside the executor. It replaces the
`roblox-executor-mcp` bridge: the script calls the OpenAI-compatible model directly,
executes tools in the same client, and renders its own CoreGui chat window. No Node
process, no MCP client, no external bridge.

Combined capabilities:

- **Inspector / debugger** (from `roblox-executor-mcp`): game info, instance search,
  bounded trees, properties, console logs, script listing, decompiled source, grep.
- **Code execution**: `run_luau` in the executor with identity 8, print capture and
  returned values. Gated by an approval card; the "Always" button disables future prompts.
- **GUI automation**: fire `GuiButton` signals or drive `VirtualInputManager`, and set or
  type into `TextBox` instances.
- **Remote spy**: Cobalt only. `spy_*` tools download and load
  [CobaltSpy](https://github.com/Wortexios/CobaltSpy) from its upstream URL, then read and
  control `Cobalt.shared.Logs`.
- **Dex**: `open_dex` downloads the
  [Dex Recontinued](https://github.com/Tesker-103/DexRecontinued) release and launches it
  for manual inspection.

## Layout

```
wrench-ai/
  build.mjs            custom bundler: src/**/*.luau -> dist/WrenchAi.luau
  loader.luau          one-line executor loader (URL, local file, or raw source)
  src/
    main.luau          wiring, first-run behavior, getgenv().WrenchAi export
    compat.luau        executor feature detection and HTTP/decompile wrappers
    config.luau        defaults + WrenchAi/config.json persistence
    serialize.luau     safe Instance/Vector/CFrame/table -> JSON conversion
    llm/client.luau    chat.completions client, retries, SSE last-frame fallback
    agent/prompt.luau  system prompt (place, player, executor, rules)
    agent/loop.luau    tool-calling loop, JSON protocol fallback, context trimming
    tools/             inspect, scripts, run, gui, spy(+manager), dex
    ui/                theme + CoreGui chat window
  test/
    stubs.luau         mocked Roblox/executor globals
    checks.luau        headless wiring + tool + loop assertions
    build-smoke.mjs    concatenates stubs + bundle + checks into out.luau
```

## Build

```sh
cd wrench-ai
npm run build
```

This writes `dist/WrenchAi.luau` (single file). The bundler rewrites relative
`require` calls into an internal module registry; source files stay separate.

## Test

The smoke suite runs the real bundle against mocked Roblox globals (no Studio needed). It
covers first-run settings, tool registration, native tool calls, the JSON protocol fallback,
inspector/GUI/spy tools, `run_luau` approval, config updates, and UI state transitions. It
also evaluates the bundle twice in one session and asserts the first UI is destroyed and a
fresh API is exported, so re-execution cannot stack windows.

```sh
# put the Luau CLI on PATH first (luau-windows.zip from luau-lang/luau releases)
npm test
```

A local copy of the CLI lives at `../tools/luau.exe` in this workspace; add it to PATH or
run `../tools/luau.exe test/out.luau` after `node test/build-smoke.mjs`.

The mock cannot prove visual layout, real keyboard behavior, Cobalt's hooks, or actual
decompiler output. Those still need a client test.

## Install (executor)

One line, always pulls the latest bundle from this repo:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/fwrobens1/WrenchAi/main/loader.luau"))()
```

The loader downloads `dist/WrenchAi.luau` with a cache-buster so a fresh push shows up
immediately. Override the source when needed:

```lua
-- pin or self-host the bundle
getgenv().WrenchAiURL = "https://example.test/dist/WrenchAi.luau"

-- bundle already copied to the executor workspace
-- (place dist/WrenchAi.luau at WrenchAi/WrenchAi.luau)

-- inline source
getgenv().WrenchAiSource = "<bundle contents>"
```

Re-running the loader destroys the previous window, cancels any running turn, and sweeps
`gethui` / `PlayerGui` / `CoreGui` for a leftover `WrenchAi` ScreenGui, so executing the
script twice never stacks two windows.

## UI

A single dark-charcoal panel designed to sit on top of any game without looking like a
default Roblox GUI.

- **Auto-scale.** The panel is authored at 420 wide and wrapped in a `UIScale` sized from the
  viewport width, so type stays readable on phones; the height shrinks to the available
  screen instead of scaling a 700px design down to tiny text. It recomputes on viewport
  changes, so phones, tablets, and desktop windows all get a correctly sized window.
- **Draggable.** Grab the header anywhere that is not a button; the drag delta is divided by
  the current scale, and the window is clamped inside the screen edges.
- **Mobile.** Comfortable hit targets, a keyboard-lift animation when the composer is
  focused, a 58px floating circular button to reopen the panel after closing, and a
  minimized pill (logo + live status) docked bottom-right.
- **Animations.** Scale/fade open, slide-in settings panel, pulsing status dot while a turn
  runs, expanding tool cards, animated switches and focus strokes, smooth scroll-to-bottom.
- **Minimize / close.** The header `–` button collapses to the pill; `×` unloads the window
  and leaves the floating button.
- **Chat.** Right-aligned user bubbles, plain assistant text with inline code blocks,
  compact tool chips (`name · status · duration`) that expand to arguments and output,
  error cards, and an approval card for `run_luau`.
- **Settings overlay.** Connection, model, sampling, limits, Cobalt/Dex URLs, system prompt,
  and the **Always allow run_luau** switch, saved to `WrenchAi/config.json`.

On Delta for iOS the window opens bottom-right. Tap the floating button to reopen, the pill
to restore a minimized panel, and drag it up while typing if the keyboard still covers the
composer.

## Updating the repo

```sh
npm run build          # rewrites dist/WrenchAi.luau
npm test               # mocked smoke suite
git add -A && git commit -m "..." && git push
```

`dist/WrenchAi.luau` is committed on purpose: the loader pulls it straight from `main`.

## Settings

Open **CFG** in the header. Fields are persisted to `WrenchAi/config.json` when the executor
has `writefile`; otherwise they last for the session.

| Field | Default | Notes |
| --- | --- | --- |
| Base URL | `https://api.reflection.ai/openai/v1` | Any OpenAI-compatible `/chat/completions` root |
| Model | `Beam-1.0-501B-A23B` | Sent as `model` |
| API key | empty | `Authorization: Bearer ...`; can be injected at runtime via `getgenv().WrenchAiApiKey` |
| Temperature | `0.7` | |
| Max agent steps | `12` | 1–30 tool/answer iterations per message |
| Cobalt URL | upstream `Cobalt` raw URL | Downloaded on first `spy_*` use |
| Dex URL | Dex release URL | Downloaded on first `open_dex` |
| Extra system prompt | empty | Appended to the built-in rules |
| Always allow `run_luau` | off | Same switch as the **Always** approval button |

The API key is never written into the bundle or sent anywhere except the configured base
URL. Prefer a key you can rotate; config JSON is plain text in the executor workspace.

If a key is already in the executor environment, injection overrides the saved one without
touching the config file:

```lua
getgenv().WrenchAiApiKey = "<key>"
loadstring(game:HttpGet("https://raw.githubusercontent.com/fwrobens1/WrenchAi/main/loader.luau"))()
```

### About the API key and the GitHub environment

The default backend is Reflection (`api.reflection.ai`), model `Beam-1.0-501B-A23B`. The
repo's `verify-api-key` workflow reads `secrets.REFLECTION_API_KEY` (or the existing
`WRENCHAI_API_KEY` secret if you just replace its value) from the `WRENCHAI_API_KEY`
environment and runs a 5-token completion against `/chat/completions`, so a bad key or
retired model fails CI instead of failing in-game.

GitHub **environment secrets are write-only** and are decrypted only inside an Actions
runner. An executor script running on a phone has no GitHub token and cannot read them, so
WrenchAi does not try. Because this repository is public, embedding the key in
`dist/WrenchAi.luau` would publish it to everyone.

What the environment secret is good for:

- CI that verifies the key and model still work, without writing the key to the bundle.
- A future proxy on your own host (the EC2 box behind Tailscale, for example): the proxy
  holds the key and forwards `/v1/chat/completions`, and the in-game config only knows the
  proxy URL. That is the only design that keeps a real key out of every client.

Until a proxy exists, set the key once in the on-device settings panel or inject it with
`getgenv().WrenchAiApiKey` at load time. A saved `config.json` that still pointed at the
retired refuseless endpoint is migrated to Reflection automatically on the next load.

## Tools

| Tool | What it does |
| --- | --- |
| `get_game_info` | Place/job/player/platform/executor and detected capabilities |
| `search_instances` | `QueryDescendants` with a bounded manual fallback |
| `get_descendants_tree` | Depth/children/class-filtered hierarchy, 300-node budget |
| `get_properties` | Serializable properties, attributes, tags |
| `get_console_logs` | Recent `LogService` history, newest first |
| `list_scripts` | Indexed loaded scripts with `debugId` (includes `getnilinstances` when available) |
| `read_script` | Decompile by path or `debugId`, 8s timeout, cached |
| `grep_scripts` | Literal/regex search with line numbers under a time budget |
| `run_luau` | Execute Luau; **approval required** unless always-allow is on |
| `click_button` | `firesignal` on button signals, else virtual mouse click |
| `type_text` | Set `TextBox.Text` or simulate input, optional Enter release |
| `spy_open` / `spy_status` / `spy_calls` / `spy_clear` / `spy_set` | Cobalt lifecycle, reading calls, clearing, block/ignore |
| `open_dex` | Launch Dex Recontinued |

The model uses native OpenAI tool calling. If the endpoint rejects `tools`, the loop
switches to a `{"tool":"name","args":{...}}` JSON protocol automatically and tells you in
the chat.

## Approval model

Everything except `run_luau` is unrestricted, matching the requested "full access" mode.
`run_luau` shows a card with the exact source, the model's description, and three buttons:

- **Run** — this call only.
- **Always** — this call plus every later call; persists `autoApproveScripts = true`.
- **Deny** — returns an error to the model instead of executing.

Press **STOP** at any time; a pending approval is denied automatically and the current
request is cancelled.

## Limitations

- **Client only.** `run_luau` runs on the local client. Server-side effects depend on what
  the client can legitimately do.
- **Decompiler required** for `read_script`/`grep_scripts`. Executors without `decompile`
  return an explanation instead of source.
- **No screenshots.** A screenshot tool cannot be implemented from inside the same
  Roblox process; use the inspector tools or Dex.
- **No token streaming.** Responses are non-streaming; the status line and tool cards show
  progress. SSE bodies are parsed only as a compatibility fallback.
- **iOS input.** The chat box is a multi-line `TextBox`. The window lifts itself when
  focused on touch devices, but exact keyboard height varies by device and executor.
- **Cobalt/Dex are remote code.** They are downloaded from the configured URLs and run with
  executor privileges. Pin a commit URL if you need reproducibility.

## Authorization

These tools can read scripts, fire UI signals, block remotes, and execute arbitrary Luau.
Only use WrenchAi on places you own or have explicit permission to test. The built-in
system prompt restates this, but it is not a security boundary: the executor is.
