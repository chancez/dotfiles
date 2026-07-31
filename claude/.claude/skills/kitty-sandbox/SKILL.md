---
name: kitty-sandbox
description: Launch and drive a throwaway kitty terminal instance to test terminal behavior end to end - prompts, window/tab titles, shell hooks, kitty.conf changes, kittens, keybindings, multiplexer sessions (zmx/tmux), escape sequences, and shell integration. Use this whenever verifying a change that only manifests in a real terminal, and especially before running any command that could attach to, retitle, resize, or kill a session in the user's live terminal. Triggers on "test this in kitty", "does my prompt/title work", "try this kitty config", "verify the shell hook fires", "check the tab title", "test the kitten", "reproduce it in a terminal", or any terminal/pty behavior that cannot be judged by reading code.
allowed-tools: Bash, Read, Write, Edit
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

Run it from anywhere. `${CLAUDE_SKILL_DIR}/scripts/kitty-sandbox.sh` resolves it
when the skill is active.

## The one rule that matters

**Never run terminal-mutating commands in the user's live terminal.** Your Bash
tool runs *inside* their session and inherits its environment. A command that
looks harmless can retarget, retitle, or kill the window they are working in.

The failure mode is not theoretical. `zmx attach NAME` from a shell that already
has `ZMX_SESSION` set does not create a new session, it *retargets the existing
client*, like `tmux switch-client`. Running it from a Bash tool call yanks the
user's window onto another session so they cannot type. If their setup also kills
a session when its window closes, closing that stuck window can destroy the
wrong session and lose real work.

So: anything that attaches, switches, resizes, retitles, or kills goes in a
sandbox. Read-only inspection of the user's terminal is fine.

## Workflow

```sh
S=${CLAUDE_SKILL_DIR}/scripts/kitty-sandbox.sh

$S new mytest                 # launch, waits until a window actually exists
$S ls mytest                  # window ids, pids, titles, cwd, running procs
$S run mytest 'echo hi'       # run a shell line (escape-safe)
$S screen mytest              # what is on screen right now
$S rm mytest                  # tear down
```

A new sandbox window appears on the user's display. Mention that you are opening
one so it is not a surprise, and always tear it down when finished.

`new` accepts:

- `--cmd "COMMAND"` — run something other than `/bin/sh` in the window
- `--conf FILE` — append extra kitty.conf lines (mappings, `shell_integration`, ...)
- `--zmx` — give the sandbox its own zmx socket dir (see below)

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
`get-text` over a screenshot. `screencapture` needs macOS screen-recording
permission, and granting it means restarting the terminal — real friction for the
user, in exchange for a less precise answer than the bytes. Reach for a
screenshot only when the question is genuinely visual (glyph rendering, colour
appearance, layout) or when you have a result you cannot otherwise trust, and say
why you needed it.

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
