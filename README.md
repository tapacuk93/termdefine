# TermDefine

A macOS menu-bar app that explains the word under your pointer when you **⌘-click** it in a
terminal — including inside TUIs like [Claude Code](https://claude.com/claude-code).

It shows two things at once: an instant offline definition, and — when an Anthropic API key is
available — a short explanation of what that word means *in the context currently on your
screen*, based on the visible terminal contents.

```
┌──────────────────────────────────────────┐
│ rsync                    COMMAND glossary│
│                                          │
│ Remote SYNC — efficiently sync           │
│ directories, copying only what changed.  │
│ -av is the common pair.                  │
│ ─────────────────────────────────────────│
│ IN THIS TERMINAL · CLAUDE                │
│ Here it is copying build output to the   │
│ staging host; --delete would remove      │
│ files there that no longer exist locally.│
└──────────────────────────────────────────┘
```

## The gesture

⌘-click a word. The app reads the word straight out of the terminal's accessibility text
(`AXRangeForPosition` → `AXStringForRange`) rather than selecting it, which matters more than
it sounds:

- **It works inside TUIs.** Programs like Claude Code, vim and htop turn on mouse reporting,
  so the terminal forwards clicks to the program instead of selecting text. Anything based on
  synthesizing a double-click finds nothing there.
- **It disturbs nothing.** Your existing selection is untouched, no clipboard round-trip, and
  the mouse pointer doesn't get hidden.

A synthetic-double-click fallback covers terminals that don't answer those queries.

**⌘+ / ⌘−** resize the popup while it's open, and the size is remembered. Those two keys are
swallowed while the panel is showing, so the terminal doesn't zoom its own font at the same
time; everywhere else they behave normally.

One caveat: Terminal.app opens paths and URLs on ⌘-click, and a global monitor can't suppress
that. ⌘-clicking a path may open it in Finder. Plain words are unaffected.

## What it explains

Two layers, shown together:

1. **Offline definition** — resolved instantly, in this order:
   - a built-in glossary of ~190 CLI commands, shell builtins and terminal abbreviations
     (`awk`, `stdout`, `SIGTERM`, `rc`, `inode`, …), written to be nicer than a man-page summary
   - `whatis` for anything with a man page (exact page-name matches only)
   - the macOS Dictionary, for ordinary English words
   - `which`, plus shape-based guesses for paths, flags and environment variables
2. **"In this terminal"** — an answer from Claude that reads the *visible terminal screen*
   and explains the word in that specific context: the command it belongs to, the error above
   it, the flag it modifies. If the screen shows an interactive **Claude Code** session, the
   app detects that and tells the model, so slash commands, permission modes and status-line
   elements are read in that light.

Other words on the clicked line appear as chips at the bottom of the panel — click one to
look it up without touching the terminal again.

## Build and run

```sh
./build.sh
open build/TermDefine.app
```

Requires the Xcode Command Line Tools (Swift 5.9+). Output: `build/TermDefine.app`,
bundle ID `com.oeaio.termdefine`.

## Permissions

macOS will ask for **Accessibility** access on first launch (System Settings → Privacy &
Security → Accessibility). It is needed to observe the click, read the selected text, and
read the terminal window's contents. The app polls until the permission is granted, so you
don't need to relaunch it.

The build is ad-hoc signed so the permission grant survives rebuilds.

## API key

The Claude layer looks for `ANTHROPIC_API_KEY` (or `ANTHROPIC_AUTH_TOKEN`) in:

1. the process environment
2. a key you pasted into the app, held in the Keychain
3. `~/.zshrc`, `~/.zshenv`, `~/.zprofile`, `~/.zlogin`, `~/.bash_profile`, `~/.bashrc`,
   `~/.profile` — the last `export ANTHROPIC_API_KEY=…` assignment wins

A GUI app doesn't inherit your shell environment, which is why the rc files are read directly.
Indirect assignments (`ANTHROPIC_API_KEY=$SOMETHING`, `$(op read …)`) are skipped.

If nothing is found on launch, the app offers a dialog to paste a key (once — after that use
**Set API key…** in the menu). A pasted key outranks the shell files, since pasting is a
deliberate act and a forgotten rc export shouldn't shadow it. It goes into the Keychain rather
than a preferences plist, which any process running as you could read. **Remove pasted key**
deletes it; **Reload API key** re-reads all sources after you edit a shell file.

Because the app is ad-hoc signed, its signature changes on every rebuild, so macOS may ask you
to allow Keychain access again after `./build.sh`. Allow it once per build.

Without a key everything still works — you just get the offline definition only.

Requests go to `POST /v1/messages` with `claude-opus-5`, thinking disabled at `low` effort and
`max_tokens: 600`, which is what keeps a popup answer under a couple of seconds.

## Menu options

| Item | Effect |
|---|---|
| Enabled | Master switch |
| Terminal apps only | Only react in Terminal, iTerm2, Warp, kitty, Alacritty, WezTerm, Ghostty, Hyper, … (on by default, so the gesture is inert in other apps) |
| Use ⌘C when needed | Allows the clipboard fallback when a terminal doesn't expose its selection over the Accessibility API. The previous clipboard contents are restored |
| Explain with Claude | Turns the contextual layer on or off |

## Dismissing the panel

Click anywhere, scroll, press a key, or wait 30 seconds. Esc closes it too.

## Layout

| File | Role |
|---|---|
| `Sources/ClickWatcher.swift` | Global mouse-down monitor; fires on ⌘-click, ignores ⌘-drags |
| `Sources/WordAtPoint.swift` | Reads the word under the pointer from the terminal's accessibility text |
| `Sources/SelectionReader.swift` | Fallback: synthetic double-click, selection via Accessibility or ⌘C with clipboard restore |
| `Sources/TerminalContext.swift` | Captures the visible screen; detects a Claude Code session |
| `Sources/Tokenizer.swift` | Strips prompt decoration and picks the interesting token from a line |
| `Sources/Glossary.swift` | The built-in command/abbreviation table |
| `Sources/Lookup.swift` | Offline resolution chain + short-lived helper processes |
| `Sources/ClaudeClient.swift` | Raw-HTTP Messages API client (Swift has no official SDK) |
| `Sources/DefinitionPanel.swift` | The floating non-activating panel, and its ⌘+/⌘− scaling |
| `Sources/ScaleHotkeys.swift` | Event tap that claims ⌘+/⌘− while the panel is open |
| `Sources/ApiKey.swift`, `Keychain.swift` | Key discovery and Keychain storage |
| `Sources/AppDelegate.swift` | Menu bar, permissions, orchestration |

## Troubleshooting

The menu's first line tells you whether the app is listening. If it says *"Waiting for
Accessibility permission…"*, re-add it in System Settings → Privacy & Security →
Accessibility — a stale entry can look enabled while being invalid, so remove it with **−**
and add it again.

For anything else, the app logs which path it took:

```sh
log show --last 5m --predicate 'subsystem == "com.oeaio.termdefine"' --style compact
```

Only the word looked up and the code path are recorded — never the terminal contents.

## Licence

MIT. See [LICENSE](LICENSE).
