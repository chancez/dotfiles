// Wires agora into omp the way claude/.claude/settings.json wires it into Claude Code: inject on prompts and
// tool results, guard on edits, doorbell when the agent settles, leave when the session ends. agora reads
// Claude Code hook events on stdin, so each handler hands it one.
import { type ChildProcess, spawn, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";

type Result = { code: number | null; stdout: string; stderr: string };

// Same shape as agora's own session names (claude-<8 hex of sha256(id)>), so the roster says which harness.
function memberFor(sessionId: string): string {
	return `omp-${createHash("sha256").update(sessionId).digest("hex").slice(0, 8)}`;
}

function additionalContext(stdout: string): string | undefined {
	try {
		return JSON.parse(stdout).hookSpecificOutput?.additionalContext || undefined;
	} catch {
		return undefined;
	}
}

export default function agora(pi: ExtensionAPI) {
	let member: string | undefined;
	let sessionId = "";
	let cwd = "";
	let started = false;
	let doorbell: ChildProcess | undefined;

	const env = () => ({ ...process.env, AGORA_MEMBER: member });
	const event = (ctx: ExtensionContext, fields: Record<string, unknown>) =>
		JSON.stringify({ session_id: sessionId, cwd: ctx.cwd, ...fields });

	const run = (ctx: ExtensionContext, args: string[], input: string, timeoutMs = 5_000) =>
		new Promise<Result>(resolve => {
			const child = spawn("agora", args, { cwd: ctx.cwd, env: env(), timeout: timeoutMs });
			let stdout = "";
			let stderr = "";
			child.stdout.on("data", d => (stdout += d));
			child.stderr.on("data", d => (stderr += d));
			child.on("error", () => resolve({ code: null, stdout, stderr }));
			child.on("close", code => resolve({ code, stdout, stderr }));
			// agora can exit without reading its event, and an unhandled EPIPE takes omp down.
			child.stdin.on("error", () => {});
			child.stdin.end(input);
		});

	const stopDoorbell = () => {
		doorbell?.kill();
		doorbell = undefined;
	};

	// Ends the member and gives back its claims, like the SessionEnd hook. session_shutdown handlers get 2 seconds.
	const leave = () => {
		stopDoorbell();
		if (!member) return;
		spawnSync("agora", ["leave", "--force"], {
			cwd,
			env: env(),
			input: JSON.stringify({ session_id: sessionId, cwd, hook_event_name: "SessionEnd" }),
			stdio: ["pipe", "ignore", "ignore"],
			timeout: 1_500,
		});
		member = undefined;
	};

	// Exported so the agent's own `agora` commands in the bash tool resolve to the member the hooks brief.
	const bind = (_event: unknown, ctx: ExtensionContext) => {
		if (ctx.agent.kind !== "main") return;
		const id = ctx.sessionManager.getSessionId();
		if (!id || id === sessionId) return;
		leave();
		sessionId = id;
		cwd = ctx.cwd;
		member = memberFor(id);
		process.env.AGORA_MEMBER = member;
		started = false;
	};

	pi.on("session_start", bind);
	pi.on("session_switch", bind);
	pi.on("session_branch", bind);

	pi.on("session_shutdown", (_event, ctx) => {
		if (ctx.agent.kind === "main") leave();
	});

	// SessionStart has no prompt to ride on, so the first prompt of a session carries it.
	pi.on("before_agent_start", async (e, ctx) => {
		if (e.reason !== "prompt" || ctx.agent.kind !== "main" || !member) return;
		stopDoorbell();
		const hook = started ? "UserPromptSubmit" : "SessionStart";
		started = true;
		const r = await run(ctx, ["inject"], event(ctx, { hook_event_name: hook, prompt: e.prompt }));
		const content = additionalContext(r.stdout);
		if (content) return { message: { customType: "agora", content, display: false } };
	});

	pi.on("tool_result", async (e, ctx) => {
		if (ctx.agent.kind !== "main" || !member) return;
		const r = await run(
			ctx,
			["inject", "--limit", "3"],
			event(ctx, { hook_event_name: "PostToolUse", tool_name: e.toolName }),
		);
		const content = additionalContext(r.stdout);
		if (content) return { additionalContext: content };
	});

	// Hashline edits can name several files, which omp lists in `paths`.
	pi.on("tool_call", async (e, ctx) => {
		if ((e.toolName !== "edit" && e.toolName !== "write") || ctx.agent.kind !== "main" || !member) return;
		const input = e.input as { path?: unknown; paths?: unknown };
		const paths = Array.isArray(input.paths) ? input.paths : [input.path];
		const contexts: string[] = [];
		for (const path of paths) {
			if (typeof path !== "string" || !path) continue;
			const r = await run(
				ctx,
				["guard"],
				event(ctx, { hook_event_name: "PreToolUse", tool_name: "Edit", tool_input: { file_path: path } }),
			);
			const content = additionalContext(r.stdout);
			if (content) contexts.push(content);
		}
		if (contexts.length) return { additionalContext: contexts.join("\n\n") };
	});

	// Claude Code's asyncRewake: wait past the end of the turn, and start one when something addressed to this
	// member arrives. Exit 2 means ring, and stderr is the message.
	pi.on("agent_end", (e, ctx) => {
		if (e.willContinue || ctx.agent.kind !== "main" || !member) return;
		stopDoorbell();
		const child = spawn("agora", ["doorbell", "--wait", "30m"], {
			cwd: ctx.cwd,
			env: env(),
			stdio: ["pipe", "ignore", "pipe"],
		});
		doorbell = child;
		let stderr = "";
		child.stderr?.on("data", d => (stderr += d));
		child.on("error", () => {});
		child.stdin?.on("error", () => {});
		child.on("close", code => {
			if (doorbell !== child) return;
			doorbell = undefined;
			if (code !== 2 || !stderr.trim()) return;
			pi.sendMessage(
				{ customType: "agora", content: stderr.trim(), display: true },
				{ triggerTurn: true, deliverAs: "followUp" },
			);
		});
		child.stdin?.end(event(ctx, { hook_event_name: "Stop", stop_hook_active: false }));
		child.unref();
	});
}
