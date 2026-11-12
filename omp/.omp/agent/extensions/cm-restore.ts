// Declares `omp --resume <session file>` to cm, so a cm session restored after a reboot resumes this
// conversation instead of opening a fresh shell. Mirrors the claude SessionStart hook in
// claude/.claude/settings.json.
import { spawnSync } from "node:child_process";
import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";

// A background omp (`omp &`, a script) must not claim the cm session's restore command.
function inForeground(): boolean {
	const ps = spawnSync("ps", ["-o", "pgid=,tpgid=", "-p", String(process.pid)], { encoding: "utf8" });
	const [pgid, tpgid] = (ps.stdout ?? "").trim().split(/\s+/);
	return pgid !== undefined && pgid === tpgid;
}

export default function cmRestore(pi: ExtensionAPI) {
	if (!process.env.CM_SESSION) return;
	let declared: string | undefined;

	// /new, /resume and a fork each move to another session file, so declare again on every one.
	const declare = (_event: unknown, ctx: ExtensionContext) => {
		if (ctx.mode !== "tui" || ctx.agent.kind !== "main") return;
		const path = ctx.sessionManager.getSessionFile();
		if (!path || path === declared || !inForeground()) return;
		const r = spawnSync("cm", ["restore-with", "--", "omp", "--resume", path], { stdio: "ignore", timeout: 10_000 });
		if (r.status === 0) declared = path;
	};

	pi.on("session_start", declare);
	pi.on("session_switch", declare);
	pi.on("session_branch", declare);
}
