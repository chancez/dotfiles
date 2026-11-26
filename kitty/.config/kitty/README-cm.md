# cm integration

Replaces the zmx integration. Both are present during the trial; switching back means reverting this
branch.

## What runs what

- `launch_wrapper.py` puts every window kitty opens at the user's request in a cm session of its own
  (kitty 0.51's launch wrapper): a shell as `cm-attach <name>`, a command typed into its session's
  shell with `cm-attach --in-shell <name>`. It skips overlays, docks, kspaces' own windows and windows
  launched with `--var=no_cm=1`. The name is in the window's `cm_session` user var, which kitty saves
  in sessions, so a restored window reattaches to its session. A shell opened from a window showing a
  session on another cm host, attached as `HOST:REF`, gets a new session on that host, named
  `HOST:kitty.<this machine>.<n>`, in the source session's directory there.
- `kitty.conf` maps cmd+w and cmd+shift+w to kitty's own close, cmd+alt+w and cmd+alt+shift+w to
  `cm_close.py`, and registers `cm_reap.py` as a watcher.
- `cm_common.py` has what they share: session names, `cm` calls, and finding a window's session.
- `cm-attach` is a short wrapper around `cm attach`, so `cm` is looked up again each time.
- `cm_close.py` kills a tab's or window's sessions outright, asking first when one is running something.
- `cm_reap.py` reports a window closed on purpose, whichever way it was closed, to `cm close`, which keeps a
  session running a command and ends an idle one. It falls back to `cm kill --force` on a cm without close.
- `cm-reap` is a manual sweep for sessions no window is showing, dry-run by default.

## Installing cm

The scripts invoke `~/.local/bin/cm` by absolute path, because kitty inherits a minimal PATH when
started from the Dock and a kitten cannot rely on the shell's. Symlink or copy the binary there:

    ln -sf ~/projects/cm/bin/cm ~/.local/bin/cm

## What this needs from the shell

`zsh/kitty.zsh` loads kitty's shell integration by hand, and that is load-bearing rather than a
convenience. cm reads two things from what it emits:

- **OSC 7**, so `cm list` reports where a session actually is, and a new split opens there.
- **OSC 133**, so cm knows whether a command is running. That is what makes the close confirmation
  meaningful, since cm owns the pty and kitty can only ever see `cm attach` running.

Without it both degrade silently rather than failing: sessions report no directory and never report
themselves busy.

## What the zmx version needed and this does not

`zsh/zmx.zsh` is deleted. It maintained `CWD` and `PROG` labels from `preexec`/`precmd` hooks, because
zmx has no other way to know either. It also had to mangle values into `[a-zA-Z0-9-_.]`, which is why a
path lost its separators and a command arrived lossy. cm derives both from the shell's own output.

Two `lsof` calls are gone. zmx needed them because `zmx attach` can retarget an existing client, so a
window could show a session its argv never named, and killing by that name would destroy an unrelated
session. cm only ever exports `CM_SESSION` and never reads it, so the name a window was attached with is
authoritative.

`cm-reap` no longer searches multiple socket directories. zmx sessions could land in `/tmp/zmx-501` or a
per-user temp dir depending on whether `TMPDIR` was set, so orphans were invisible from the wrong shell.
cm resolves its runtime directory identically for every process, with `CM_RUNTIME_DIR` as the one
override.

`cm-attach` dropped two workarounds: `unset ZMX_SESSION` (cm never retargets) and a backgrounded
`SIGWINCH` to force a title repaint (cm re-emits OSC 2 in the screen it restores, and nudges the pty
itself on a same-size reattach).

`zmx-map` has no equivalent. It existed to show where launch argv and live session had diverged, which
cannot happen here.

## Known difference

Busy state is derived from a live output stream and deliberately not stored, so after a `cm server`
restart a session reports idle until its next command. The effect is a missing confirmation prompt for a
command that started before the restart. Storing it would be worse: a stale "busy" outlives its command
and makes the prompt fire forever.
