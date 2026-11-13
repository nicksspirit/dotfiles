import { describe, expect, it, vi } from "vitest";
import { FooterComponent, initTheme, type AgentSession, type ExtensionAPI, type ExtensionContext, type ReadonlyFooterDataProvider, type Theme } from "@earendil-works/pi-coding-agent";
import { stripTerminalSequences, visibleWidth, type Component } from "@earendil-works/pi-tui";
import install, { shortenCwd } from "../extension.js";

describe("shortenCwd", () => {
	it("keeps the leaf and immediate parent full, abbreviates the rest", () => {
		expect(shortenCwd("~/Developer/_SketchUp/sbd-legionrepo-wt/snowflake_cdp_dcm/projects/snowflake_cdp_dcm")).toBe(
			"~/D/_S/s/s/projects/snowflake_cdp_dcm",
		);
	});

	it("leaves short paths untouched", () => {
		expect(shortenCwd("~/projects/dotfiles")).toBe("~/projects/dotfiles");
		expect(shortenCwd("~")).toBe("~");
		expect(shortenCwd("/")).toBe("/");
	});

	it("handles absolute paths outside $HOME", () => {
		expect(shortenCwd("/var/www/some-very-long-service-name/backend/src")).toBe("/v/w/s/backend/src");
	});

	it("falls back to keeping 1 segment, then hard-truncates with an ellipsis, once over maxLen", () => {
		const deep = "~/Developer/_SketchUp/sbd-legionrepo-wt/snowflake_cdp_dcm/projects/snowflake_cdp_dcm";
		expect(shortenCwd(deep, 30)).toBe("~/D/_S/s/s/p/snowflake_cdp_dcm");
		expect(shortenCwd(deep, 20).startsWith("…")).toBe(true);
		expect(shortenCwd(deep, 20).endsWith("snowflake_cdp_dcm")).toBe(true);
	});

	it("abbreviates Unicode graphemes and caps paths by terminal cells", () => {
		expect(shortenCwd("~/工作/项目/应用/模块")).toBe("~/工/项/应用/模块");
		expect(shortenCwd("~/éclair/中文/leaf/parent")).toBe("~/é/中/leaf/parent");
		for (const width of [0, 1, 5, 10, 20]) {
			expect(visibleWidth(shortenCwd("~/工作/项目/" + "🧪".repeat(40), width))).toBeLessThanOrEqual(width);
		}
	});
});

const unstyle = (text: string) => stripTerminalSequences(text);
initTheme("dark");
const normalize = (text: string) => unstyle(text).trim().replace(/ +/g, " ");
const colors: Record<string, string> = { dim: "\x1b[90m", accent: "\x1b[36m", warning: "\x1b[33m", error: "\x1b[31m" };
const theme = { fg: (color: string, text: string) => `${colors[color] ?? "\x1b[37m"}${text}\x1b[0m` } as Theme;
function usage(input: number, output: number, cacheRead = 0, cost = 0, cacheWrite = 0) {
	return { input, output, cacheRead, cacheWrite, totalTokens: input + output + cacheRead + cacheWrite, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: cost } };
}

function harness(flag = "2", mode = "tui") {
	type Renderable = Component & { dispose?(): void; handleInput?(data: string): void };
	const state = {
		branch: "main", session: "first", leaf: "two", name: undefined as string | undefined,
		percent: 9 as number | null, auto: true, oauth: true, subscription: true,
		entries: [
			{ type: "message", message: { role: "assistant", usage: usage(24218, 5000, 0, 0.008) } },
			{ type: "message", message: { role: "assistant", usage: usage(3782, 200, 469000, 0.002) } },
		] as Record<string, any>[],
	};
	const statuses = new Map([
		["extmgr", "18 pkgs • ⏸ scheduled checks off"],
		["ponytail", "○ 🐴 ponytail: ⚡ FULL"],
	]);
	const handlers = new Map<string, (event: unknown, ctx: ExtensionContext) => void>();
	const commands = new Map<string, { handler(args: string, ctx: ExtensionContext): Promise<void> }>();
	const watchers = new Set<() => void>();
	const unsubscribe = vi.fn();
	const data = {
		getGitBranch: () => state.branch,
		getAvailableProviderCount: () => 3,
		getExtensionStatuses: () => statuses,
		onBranchChange: (fn: () => void) => { watchers.add(fn); return () => { watchers.delete(fn); unsubscribe(); }; },
	} satisfies ReadonlyFooterDataProvider;
	const tui = { requestRender: vi.fn(), terminal: { rows: 12 } };
	const widgets = new Map<string, Renderable>([["other-widget", { render: () => ["still here"], invalidate() {} }]]);
	let footer: Renderable | undefined;
	let overlay: Renderable | undefined;
	const done = vi.fn();
	const manager = {
		getSessionId: () => state.session, getLeafId: () => state.leaf,
		getCwd: () => "/var/www/dotfiles", getSessionName: () => state.name,
		getEntries: vi.fn(() => state.entries), getEntryCount: () => state.entries.length,
	};
	const ui = {
		notify: vi.fn(),
		setWidget: (key: string, factory: (() => Renderable) | undefined) => { if (factory) widgets.set(key, factory()); else widgets.delete(key); },
		setFooter: (factory: (tui: unknown, theme: Theme, data: ReadonlyFooterDataProvider) => Renderable) => { footer?.dispose?.(); footer = factory(tui, theme, data); },
		custom: async (factory: (tui: unknown, theme: Theme, keys: unknown, done: () => void) => Renderable) => { overlay = factory(tui, theme, {}, done); },
	};
	const ctx = {
		mode, hasUI: mode === "tui" || mode === "rpc", cwd: "/var/www/dotfiles", ui, sessionManager: manager,
		model: { id: "gpt-6-luna", provider: "openai", reasoning: true, contextWindow: 272000 },
		thinkingLevel: "medium",
		getContextUsage: () => ({ percent: state.percent, contextWindow: 272000, tokens: state.percent === null ? null : state.percent * 2720 }),
		modelRegistry: { isUsingOAuth: () => state.oauth, getProvider: () => ({ auth: { oauth: { isSubscription: state.subscription } } }) },
	} as unknown as ExtensionContext;
	const pi = {
		on: (event: string, handler: (event: unknown, ctx: ExtensionContext) => void) => handlers.set(event, handler),
		registerFlag: vi.fn(), getFlag: () => flag,
		registerCommand: (name: string, command: { handler(args: string, ctx: ExtensionContext): Promise<void> }) => commands.set(name, command),
		getSettings: () => ({ compaction: { enabled: state.auto } }), getThinkingLevel: () => "medium",
	} as unknown as ExtensionAPI;
	install(pi);
	const start = () => handlers.get("session_start")!({}, ctx);
	start();
	return {
		state, statuses, handlers, watchers, unsubscribe, tui, widgets, manager, ctx, ui, data, done,
		start,
		shelf: (width = 200) => [...widgets.entries()].find(([key]) => key !== "other-widget")?.[1].render(width) ?? [],
		footer: (width = 200) => footer?.render(width) ?? [],
		command: (args: string) => commands.get("statusline")!.handler(args, ctx),
		overlay: () => overlay!,
		dispose: () => footer?.dispose?.(),
	};
}

describe("Split ledger extension", () => {
	it("places location/model above the editor and native usage below, with complete keyed statuses", () => {
		const h = harness();
		expect(h.shelf().map(normalize)).toEqual(["/v/www/dotfiles (main) (openai) gpt-6-luna • medium"]);
		expect(h.footer().map(normalize)).toEqual([
			"↑28k ↓5.2k R469k CH99.2% $0.010 (sub) 9.0%/272k (auto)",
			"18 pkgs • ⏸ scheduled checks off │ ○ 🐴 ponytail: ⚡ FULL",
		]);
		expect(h.widgets.get("other-widget")!.render(100)).toEqual(["still here"]);
	});

	it.each([
		{ oauth: true, subscription: true, auto: true, percent: 9 },
		{ oauth: false, subscription: true, auto: false, percent: 75 },
		{ oauth: true, subscription: false, auto: true, percent: null },
		{ oauth: false, subscription: false, auto: false, percent: 95 },
	])("matches Pi's stock stats for auth/compaction state %j", (settings) => {
		const h = harness();
		Object.assign(h.state, settings);
		const native = new FooterComponent({
			sessionManager: h.manager, model: h.ctx.model,
			state: { model: h.ctx.model, thinkingLevel: h.ctx.thinkingLevel },
			modelRuntime: { isUsingSubscription: () => h.state.oauth && h.state.subscription },
			getContextUsage: h.ctx.getContextUsage,
		} as unknown as AgentSession, h.data);
		native.setAutoCompactEnabled(settings.auto);
		expect(normalize(h.footer()[0]) + " (openai) gpt-6-luna • medium").toBe(normalize(native.render(240)[1]));
	});

	it("counts supported usage entries once across compaction and only rescans when the session leaf changes", () => {
		const h = harness();
		h.shelf(); h.footer(); h.footer();
		expect(h.manager.getEntries).toHaveBeenCalledTimes(1);
		h.state.entries.push(
			{ type: "usage", usage: usage(1, 2, 0, 0.001) },
			{ type: "message", message: { role: "toolResult", usage: usage(3, 4, 0, 0.002) } },
			{ type: "branch_summary", usage: usage(5, 6, 0, 0.003) },
			{ type: "compaction", usage: usage(7, 8, 0, 0.004, 1000) },
		);
		h.state.leaf = "compacted";
		h.state.percent = null;
		const text = normalize(h.footer()[0]);
		expect(text).toContain("W1.0k CH99.2% $0.020 (sub) ?/272k (auto)");
		expect(h.manager.getEntries).toHaveBeenCalledTimes(2);
	});

	it("uses authoritative subscription metadata and handles fresh sessions and thinking off", () => {
		const h = harness();
		h.state.entries = []; h.state.leaf = "empty";
		h.state.oauth = false; h.state.subscription = false;
		h.ctx.thinkingLevel = "off";
		expect(normalize(h.footer()[0])).toBe("9.0%/272k (auto)");
		expect(normalize(h.shelf()[0])).toContain("gpt-6-luna • thinking off");
		h.ctx.model!.provider = "kimi-coding";
		expect(normalize(h.footer()[0])).toContain("$0.000 (sub)");
		h.ctx.model!.reasoning = false;
		expect(normalize(h.shelf()[0])).not.toContain("thinking off");
	});

	it("reads additions, replacements, empty values, and removals on every render without dangling separators", () => {
		const h = harness();
		h.statuses.set("new-extension", "new: working");
		expect(normalize(h.footer()[1])).toBe("18 pkgs • ⏸ scheduled checks off │ new: working │ ○ 🐴 ponytail: ⚡ FULL");
		h.statuses.set("new-extension", "new: done");
		expect(normalize(h.footer()[1])).not.toContain("working");
		h.statuses.delete("extmgr"); h.statuses.delete("new-extension");
		h.statuses.set("empty", "\x1b[32m  \n \t\x1b[0m");
		expect(normalize(h.footer()[1])).toBe("○ 🐴 ponytail: ⚡ FULL");
		h.statuses.clear();
		expect(h.footer()).toHaveLength(1);
	});

	it("wraps complete extension groups first, then long colored Unicode messages, preserving their content", () => {
		const h = harness();
		const rows = h.footer(40).slice(1).map(unstyle);
		expect(rows).toEqual(["18 pkgs • ⏸ scheduled checks off", "○ 🐴 ponytail: ⚡ FULL"]);
		h.statuses.clear();
		const text = "🧪漢é文".repeat(30);
		h.statuses.set("unicode", `\x1b[32m${text}\x1b[0m`);
		const wrapped = h.footer(40).slice(1);
		expect(wrapped.map(unstyle).join("")).toBe(text);
		expect(wrapped.every((line) => visibleWidth(line) <= 40 && line.includes("\x1b[32m"))).toBe(true);
		h.statuses.set("multiline", "alpha\n beta\t gamma");
		expect(h.footer(200).map(normalize).join(" ")).toContain("alpha beta gamma");
	});

	it.each([0, 1, 2, 10, 40, 72, 110, 160, 200])("obeys width %i at each supported core count and keeps details available", async (width) => {
		const h = harness();
		h.state.branch = "feature/very-long-branch-🧪漢".repeat(3);
		for (const count of [1, 2, 3]) {
			h.statuses.clear();
			await h.command(String(count));
			const all = [...h.shelf(width), ...h.footer(width)];
			expect(all.every((line) => visibleWidth(line) <= width)).toBe(true);
			expect(all).toHaveLength(width > 0 ? count : 0);
			h.statuses.set("wide", "🧪漢é".repeat(20));
			expect(h.footer(width).every((line) => visibleWidth(line) <= width)).toBe(true);
		}
	});

	it("preserves the core row budget, context priority, and model in narrow panes", async () => {
		const h = harness("1");
		expect(h.shelf(40)).toEqual([]);
		const narrow = normalize(h.footer(40)[0]);
		expect(narrow).toContain("gpt-6-luna");
		expect(narrow).toContain("9.0%/272k (auto)");
		await h.command("2");
		expect(h.shelf(40)).toHaveLength(1);
		expect(h.footer(40)[0]).toContain("9.0%/272k (auto)");
		await h.command("3");
		expect(h.shelf(40).length + h.footer(40).length).toBe(5);
	});

	it("refreshes branch/model/session state and disposes only its own widget and subscription", () => {
		const h = harness();
		h.state.branch = "next"; h.state.name = "named session";
		h.ctx.model!.id = "another-model";
		for (const notify of h.watchers) notify();
		expect(h.tui.requestRender).toHaveBeenCalledTimes(1);
		expect(normalize(h.shelf()[0])).toContain("(next) • named session (openai) another-model");
		h.state.session = "new"; h.state.entries = []; h.state.leaf = "new-leaf";
		h.start();
		expect(h.unsubscribe).toHaveBeenCalledTimes(1);
		expect(h.watchers.size).toBe(1);
		expect(normalize(h.footer()[0])).not.toContain("↑28k");
		h.dispose(); h.dispose();
		expect(h.unsubscribe).toHaveBeenCalledTimes(2);
		expect(h.widgets.size).toBe(1);
		expect(h.widgets.has("other-widget")).toBe(true);
	});

	it("opens a scrollable keyboard details view containing complete values", async () => {
		const h = harness();
		h.state.branch = "feature/" + "long".repeat(40);
		h.statuses.set("long", "contents ".repeat(60));
		await h.command("details");
		const overlay = h.overlay();
		const first = overlay.render(40).map(unstyle).join("\n");
		expect(first).toContain("Split ledger");
		expect(first).toContain("Directory:");
		overlay.handleInput!("\x1b[F");
		const last = overlay.render(40).map(unstyle).join("\n");
		expect(last).toContain("○ 🐴 ponytail: ⚡ FULL");
		expect(last).not.toBe(first);
		overlay.handleInput!("\x1b");
		expect(h.done).toHaveBeenCalledTimes(1);
	});

	it.each(["print", "rpc", "json"])("does not install terminal components in %s mode", (mode) => {
		const h = harness("2", mode);
		expect(h.shelf()).toEqual([]);
		expect(h.footer()).toEqual([]);
		expect(h.watchers.size).toBe(0);
	});

	it("falls back from an invalid row flag and rejects invalid commands without changing the layout", async () => {
		const h = harness("invalid");
		expect(h.ui.notify).toHaveBeenCalledWith("Invalid --statusline-lines; using 2", "warning");
		await h.command("4");
		expect(h.shelf()).toHaveLength(1);
		expect(h.ui.notify).toHaveBeenLastCalledWith("Use /statusline 1|2|3 or /statusline details", "info");
	});
});
