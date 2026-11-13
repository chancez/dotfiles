---
name: kitty-sandbox
description: >-
  Launch and drive a throwaway kitty terminal instance to test terminal behavior end to end:
  prompts, window and tab titles, shell hooks, kitty.conf changes, kittens, keybindings,
  multiplexer sessions, escape sequences, and shell integration. Use when a change only
  manifests in a real terminal, especially before a command could attach to, retitle, resize,
  or kill a session in the user's live terminal. Trigger on "test this in kitty", "does my
  prompt/title work", "try this kitty config", "verify the shell hook fires", "check the tab
  title", "test the kitten", "reproduce it in a terminal", or terminal and pty behavior that
  cannot be judged by reading code.
---

# Kitty sandbox

Terminal behavior is hard to verify by reading code. Titles, prompts, escape
sequences, and session state only become real when a terminal renders them. This
skill launches a disposable kitty instance you can drive programmatically, so you
can observe actual behavior without touching the terminal the user is sitting in.

The helper script does the boilerplate:

```
scripts/kitty-sandbox.sh
```

Run it from anywhere. Use the script bundled alongside this `SKILL.md`.

## The one rule that matters

**Never run terminal-mutating commands in the user's live terminal.** A shell
command can run *inside* their session and inherit its environment. A command that
looks harmless can retarget, retitle, or kill the window they are working in.

The failure mode is not theoretical. `zmx attach NAME` from a shell that already
has `ZMX_SESSION` set does not create a new session, it *retargets the existing
client*, like `tmux switch-client`. Running it from a shell tool call yanks the
user's window onto another session so they cannot type. If their setup also kills
a session when its window closes, closing that stuck window can destroy the
wrong session and lose real work.

So: anything that attaches, switches, resizes, retitles, or kills goes in a
sandbox. Read-only inspection of the user's terminal is fine.

## Workflow

```sh
S=/path/to/this-skill/scripts/kitty-sandbox.sh

$S new mytest                 # launch, waits until a window actually exists
$S ls mytest                  # window ids, pids, titles, cwd, running procs
$S run mytest 'echo hi'       # run a shell line (escape-safe)
$S screen mytest              # what is on screen right now
$S shot mytest                # png of kitty's rendering, stays hidden (see below)
$S rm mytest                  # tear down
```

`new` accepts:

- `--cmd "COMMAND"` — run something other than `/bin/sh` in the window
- `--conf FILE` — append extra kitty.conf lines (mappings, `shell_integration`, ...)
- `--zmx` — give the sandbox its own zmx socket dir (see below)
- `--cm` — give the sandbox its own cm runtime and state dirs (see below)
- `--visible` - start on screen with focus (rarely what you want, see below)

## Sandboxes start hidden

`new` passes `--start-as=hidden` and sets `macos_hide_from_tasks yes`, so the
sandbox never covers the user's work and adds no Dock icon or cmd-tab entry.
Everything works while hidden: `run`, `text`, `ls`, `screen`, `shot`, and any
`kitten @` command.

This is not a cosmetic nicety. A focused sandbox **steals the user's keystrokes**.
While testing this, a visible sandbox captured two characters the user was typing
into another app, and their shell then reported `command not found` for the
mangled line. A hidden sandbox in the same test received nothing. So a visible
sandbox both interrupts the user and silently corrupts your own test input, which
looks like a terminal bug rather than what it is.

Hidden alone did not keep focus away. glfw focuses every window it shows, and on
macOS focusing a window activates the whole app, so a hidden sandbox still took
the keyboard whenever an OS window was created inside it, whenever focus moved
between its OS windows, and when closing one focused the next. It can also be
the instance LaunchServices picks to reopen "kitty" (`open -a kitty`, a launcher
activating kitty by bundle id): it activates the app and opens a new window
running the login shell. One such window appeared in a sandbox during this
work, and a reopen event sent to a sandbox reproduced it. So `new` also writes
`$dir/nofocus.py` and loads it as a `watcher`. It runs inside the sandbox
process and:

- turns `activateIgnoringOtherApps:` into a no-op, so kitty itself can never
  activate the sandbox;
- stops `makeKeyAndOrderFront:` from putting a hidden window on screen;
- creates every new OS window hidden (`launch --type=os-window`, session
  `new_os_window`, `detach-tab`, `detach-window`, a reopen), whatever state was
  asked for;
- hides the app the moment something outside activates it anyway, which hands
  activation straight back to the previous app.

Measured by logging `lsappinfo front` every ~60ms: `new`, `shot`, `run`,
creating an OS window, `focus-window` across OS windows, closing one, a reopen
event, and `rm` never made the sandbox frontmost. Outside activation is the one
thing it cannot refuse, only undo: forcing the sandbox frontmost through System
Events showed it in one sample (under 150ms) before it handed focus back. Keys
typed in that moment can still land in it.

Consequences for tests: in a hidden sandbox no OS window is ever focused (`ls`
reports `is_focused` false everywhere) and OS window states like `maximized` or
`fullscreen` are not applied. Test those with `--visible`, which has no guard.

`--visible` exists for the case where a test genuinely depends on the window
being on screen and focused: real focus-follows behavior, `focus_follows_mouse`,
focus events, OS window states, the macOS titlebar. Prefer hidden and reach for it
only with a reason, since anything the user types goes into your window.

To hand a sandbox over for a human look, show it deliberately:

```sh
$S show mytest                # reveal and focus (takes focus on purpose)
$S hide mytest                # hide it and give focus back to the previous app
```

`show` switches the guard off and `hide` switches it back on, so between the two
the sandbox behaves like a normal kitty, new OS windows included. Say what you are
doing when you `show` one, since it interrupts them. `show` and `--visible` are
the only things that take focus on purpose.

## Sandboxes are silent

Hidden is not the same as unnoticeable. Not inheriting the real config also means
not inheriting its `enable_audio_bell no`, and kitty's default is `yes`, so a
sandbox used to beep out loud from a window with no icon and no visible presence.
Any BEL a test produces rings it: a shell error, readline completion, a truncated
OSC sequence. `new` now writes `enable_audio_bell no`, `window_alert_on_bell no`,
`bell_on_tab no`, and `command_on_bell none`.

Suppressing the tab marker matters for correctness too, not just quiet: a bell
would otherwise prefix the tab title and break a tab-title assertion.

If the bell itself is the subject of a test, put it back with `--conf`, which is
appended last and wins. Assert on it with `command_on_bell` writing a file rather
than on the tab title: `ls` reports title strings, not tab-bar rendering, so a
bell marker is invisible to it and a test that watches for one passes either way.

```sh
printf 'command_on_bell /usr/bin/touch /tmp/bell-fired\n' > /tmp/probe.conf
$S new bp --conf /tmp/probe.conf && $S run bp 'printf "\a"'
ls /tmp/bell-fired            # exists = the BEL reached kitty's bell handler
```

## Testing a source build of kitty

By default the sandbox runs the installed `/Applications/kitty.app`. When the
change under test is to kitty itself, that silently tests the *released* binary
instead of your build — a false pass that looks like a real one. Point the
sandbox at the build:

```sh
export KITTY_SANDBOX_KITTY=~/projects/kitty/kitty/launcher/kitty
export KITTY_SANDBOX_KITTEN=~/projects/kitty/kitty/launcher/kitten
```

Rebuild before launching, or you are testing the previous compile.

Confirm the right binary really is under test rather than assuming the env vars
took effect. Two cheap checks, either of which beats trusting the export:

```sh
ps -o command= -p $(pgrep -f "instance-group NAME" | head -1)   # shows the path
grep -i 'unknown config key' $dir/kitty.log
```

If your change adds a config option, put it in `--conf` and grep the log: the
installed kitty reports `Ignoring unknown config key: your_option` while a build
that has it stays silent. That turns "is this my binary?" into an observation.
Absence of the error is only meaningful for an option the released version does
not know about — for anything else, use `ps`.

## Programs the sandbox runs

A sandbox does not isolate *which programs* its windows run. kitty looks a bare
command name up itself, in `which()` (kitty/utils.py), before the child's
environment exists, in this order:

1. `exe_search_path` entries without a prefix;
2. kitty's own `PATH`, the one it was started with;
3. `~/.local/bin`, then `~/bin`;
4. `exe_search_path` entries with a `+` prefix.

`env PATH=...` in kitty.conf is not on that list: it only sets the child's
environment once the program has been found. So a fake `gr` or `claude` put
on `env PATH`, or on `exe_search_path +DIR`, loses to the real one in
`~/.local/bin`, and the sandbox runs the user's real program against your test
repo. This happened: a sandbox meant to run a fake `gr` ran the real one, which
wrote rows for the throwaway repo into the user's gr database.

Put fakes, and a build under test, in a directory listed first, without `+`,
and on `env PATH` too for anything the child itself runs by name:

```sh
printf 'exe_search_path %s\nenv PATH=%s:/usr/bin:/bin\n' "$FAKES" "$FAKES" > /tmp/fakes.conf
$S new mytest --conf /tmp/fakes.conf
```

Or launch by absolute path, which skips the lookup. Check before trusting a
result: `ls` shows each window's `cmdline`, and `foreground_processes` its
resolved executable.

## Driving the sandbox

**`run` for anything containing escapes.** `kitten @ send-text` mangles
backslash escapes in transit, so `printf "\033]2;title\007"` arrives corrupted
and your test silently measures nothing. `run` writes the line to a file and
sources it, so the shell interprets the escapes rather than kitty. This is the
single most common way terminal tests produce false negatives.

**`text` for literal keystrokes**, when you want exactly the bytes typed:

```sh
$S text mytest 'cd /tmp
'                             # trailing newline = pressing Enter
```

**Observing results.** `ls` gives structured state (titles, cwd, pids, foreground
processes) and is usually what you want for assertions. `screen` dumps visible
text; `screen --all` includes scrollback. To check for stray escape sequences
rendered as literal text, pipe through `od -c`, since they are invisible
otherwise.

Kitty's own screen buffer is authoritative for what was painted, so prefer
`get-text` over a screenshot: bytes you can assert on beat pixels you have to
eyeball. Reach for a screenshot when the question is genuinely visual (glyph
rendering, colour appearance, layout, anything outside a window's text grid) or
when you have a result you cannot otherwise trust.

```sh
$S shot mytest              # writes $dir/shot.png, prints the path
$S shot mytest /tmp/out.png
```

`shot` runs `kitten @ screenshot`: kitty renders the active OS window, tab bar
included, into an offscreen buffer with its own shaders and writes the png
itself. So it works while the sandbox stays hidden, never shows or focuses it,
exposes nothing else on the user's display, and needs no screen-recording
permission. The fonts, glyph widths, and colors are kitty's real rendering;
what is missing is what macOS adds when it composites a window: the titlebar,
the shadow, and transparency or blur over the desktop. For those, `show` it and
ask the user to look.

It used to show the window, capture it with `screencapture`, and hide it again,
because macOS does not composite a hidden window and a capture without the show
came back black. That show is what focused the sandbox, and it took two bursts of
the user's typing. Do not go back to it.

`shot` still warns when the png is entirely black, since that reads as a
rendering bug; compare with `screen` before believing either.
Prefer `screen`/`get-text` when you only need the text.

**`get-text` does not include the tab bar.** It reads the focused *window's*
screen; the tab bar is a separate Screen owned by the OS window, so no extent
reaches it — `screen` on a sandbox with a visible tab bar returns just the shell
prompt. `ls` reports tab title *strings*, not how they were rendered, which is
exactly the part in question for wrapping, truncation, and multi-line layout. So
neither command can see a tab bar bug, and both look like a clean pass.

To inspect tab bar rendering, drive it directly under the built binary instead:

```sh
./kitty/launcher/kitty +launch script.py
```

In that script patch `viewport_for_window`, `cell_size_for_window`,
`set_tab_bar_render_data` and `get_boss`, build a `TabBar`, call `layout()` and
`update(...)`, then read cells back with `str(screen.line(i))` for text or
`screen.line(i).as_ansi()` for colors and where a background span ends. Use
`kitty.config.load_config` to exercise real config-file parsing. This also covers
the horizontal tab bar and anything else drawn by kitty rather than by a program
inside a window.

Split the work by what each method can actually see: headless inspection for
layout and content, `shot` for how the bar looks once painted, and the sandbox for
live-window behavior (clicks, resizes, focus, tab creation).

Anything `kitten @` can do works against the sandbox socket:

```sh
K=/Applications/kitty.app/Contents/MacOS/kitten
SOCK=$($S sock mytest)
$K @ --to $SOCK launch --location=hsplit /bin/sh
$K @ --to $SOCK resize-os-window --width 900 --height 600
$K @ --to $SOCK get-text --extent all
```

## What you cannot test programmatically

Some things genuinely cannot be driven from a tool call, and handing one of those
back to the user is a good outcome rather than a failure. A sandbox you set up,
left in the right state, with a specific instruction and a specific thing to look
for, is a real contribution: you did the ten steps of setup so the user only has
to do the one step you cannot. That is far more useful than a hedged guess, and
more honest than a confident answer your harness could not actually support.

When you do this, make it cheap for them. Say what to press or click, what you
expect to happen, and what it would mean if something else happens instead. Where
possible give a second check that discriminates between explanations — if pressing
`i` should echo `105` and `j` should echo `106`, the number tracking the key rules
out coincidence in a way one observation cannot.

**Real keypresses.** `send-text` injects bytes straight into the pty, bypassing
kitty's keyboard-encoding layer. Bugs in that layer (kitty keyboard protocol,
modified keys, focus reporting) will not reproduce no matter what you send, so
asking the user to type is the only way to confirm them.

**Keybindings.** You can invoke what a mapping *calls*
(`kitten @ action ... kitten foo.py`) but not the keypress itself. Say which one
you verified, since "the kitten works" and "the mapping works" are different
claims.

**Programs that own the terminal.** While vim or a full-screen TUI is running,
shell hooks do not fire and titles come from the program. That is correct
behavior, not a bug — check whether it explains a result before calling it one.

## When "it doesn't reproduce" is your harness lying

The dangerous outcome is not failing to reproduce a bug, it is reporting that it
does not exist. Terminal features negotiate: a program asks the terminal what it
supports and only enables a mode if something answers. Wrap the program in
anything that does not answer and the feature never turns on, so the bug you were
chasing cannot appear.

Two traps that have produced exactly this false negative:

- Running the program under `script` — nothing replies to a query like `ESC[?u`
  behind its pty, so a program that would push a mode never pushes it.
- Driving input with `send-text` when the bug lives in key encoding.

Before concluding a bug is absent, confirm the precondition was actually met.
Query the terminal state directly and check it is what you assumed, or add a
control that is known to produce the symptom and verify your harness detects
*that*. If the control does not fire either, the harness is what is broken.

A useful control pattern: measure the state at three points — a clean baseline,
after the suspect action, and after a known-good action. If baseline and known-good
both come back clean and only the suspect action differs, the mechanism is real.
That structure also tells the user something they can act on, rather than a bare
yes or no.

## Isolating multiplexer state

For cm, use `--cm`. It sets `CM_RUNTIME_DIR`, `CM_STATE_DIR`, and `CM_CONFIG`, so sandbox sessions and
their database are separate from the user's, and the sandbox does not read their config file. All
three matter: setting only the runtime dir leaves the sandbox sharing the real database.

The helper defaults its root to `/tmp/kitty-sandbox`, not macOS `TMPDIR`, because cm's Unix socket path is
limited to 104 bytes. Keep an overridden `KITTY_SANDBOX_ROOT` short when using `--cm`.

`CM_CONFIG` points at a file inside the sandbox that does not exist, and that is deliberate. An
*empty* `CM_CONFIG` means **unset** to cm, so it falls through to `XDG_CONFIG_HOME` and then to the
real config file. This script did exactly that until it was caught: sandboxes looked isolated while
reading the developer's `detach_key = ctrl-o`, and nothing failed, because nothing asserted on it.

Verify rather than assume, since the failure is silent:

```sh
$S text NAME 'cm config | grep detach_key
'
# ctrl-\  = isolated (the default)
# ctrl-o  = reading the real config file
```

Three traps specific to cm, all of which produce a convincing false result rather than an error:

- `env -i` strips `CM_RUNTIME_DIR`, so a sandbox without `--cm` puts its sessions in the user's *real*
  runtime dir, alongside their live ones. This is the same hazard as the zmx case below.
- `CM_SESSION` is inherited by anything launched inside a sandbox window, so a bare `cm attach` there
  retargets the session that launched it rather than creating one. The symptom is `clients=2` and
  `state=running(cm)` on a session you expected to be fresh. Unset it in the wrapper script that
  `--cmd` runs.
- `$S rm` removes the sandbox directory, which for cm contains the database. Tearing down a sandbox
  while testing "do sessions survive kitty quitting?" therefore destroys the store and the sessions
  appear not to have survived. To test the quit path, kill only the kitty process
  (`pkill -f "instance-group NAME\$"`) and leave the directory alone.

Anything driving `cm` from outside the sandbox needs the same two variables, or it inspects a different
installation. A wrapper script that exports them and then execs `cm-attach` is the reliable way to
reattach from a second sandbox, since `--cmd` inherits the stripped environment.



For zmx, always use `--zmx`. It sets `ZMX_DIR`, which is priority 1 in zmx's
socket-dir resolution, so sandbox sessions live in their own directory and cannot
collide with the user's.

Do **not** rely on `env -i` alone for this. Dropping `TMPDIR` does relocate the
socket dir to `/tmp/zmx-501`, which *looks* isolated, but any of the user's
sessions started without `TMPDIR` also live there. I nearly killed real sessions
on that assumption. `ZMX_DIR` is explicit and does not depend on what the user's
environment happened to contain.

```sh
$S new zt --zmx --cmd "$HOME/.local/bin/zmx-attach zt.win"
ZMX_DIR=$(ls -d ${TMPDIR:-/tmp}/kitty-sandbox/zt/zmx)
ZMX_DIR=$ZMX_DIR zmx ls          # sees only sandbox sessions
```

Pass that same `ZMX_DIR` to every `zmx` call, or you are inspecting the user's
sessions instead. To test detach/reattach, `$S rm` then `$S new` with the same
name and command: the session outlives the kitty instance, which is the whole
point of a multiplexer.

## Before killing anything

If you must clean up a session outside a sandbox, verify it is really abandoned:
`clients=0` alone is not enough, because a detached session can still hold a live
shell with the user's work in it. Check the pid is actually dead (`ps -p PID`)
and look for child processes. When in doubt, leave it and say so.

`$S rm NAME` is safe because it matches on `--instance-group NAME`, which the
user's real kitty never carries. Never `pkill -f kitty` or similar broad
patterns.

That match is `$`-anchored, so `--instance-group` has to stay the **last**
argument in the kitty command line. If you add a flag after it, `rm` silently
matches nothing, reports success, and leaks a kitty process. Verify with
`pgrep -f "instance-group NAME\$"` after changing the launch line.

Use `rm NAME` rather than `rm-all` unless you are certain nothing else is running:
other agents may have sandboxes of their own, and `rm-all` will take theirs down
with yours.

## Interpreting an empty window list

If `ls` reports no windows, the usual cause is the window's command failing
instantly, not kitty failing to start. A login shell with a stripped `PATH` exits
immediately with "command not found". Read `kitty.log` in the sandbox dir before
concluding anything:

```sh
cat ${TMPDIR:-/tmp}/kitty-sandbox/mytest/kitty.log
```

This matters because an empty window list can also be the signature of a session
hijack. Confirm the mundane explanation first.

## Reporting results

Say what you observed and how, and distinguish it from what you inferred. "The
tab title showed `zmx-attach` after reattach, and `ls` confirms no title was
set" is useful. "Titles work now" is not, especially when the mechanism is a
sequence nobody can see. Quote the bytes when the answer depends on them.
