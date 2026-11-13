import { CustomEditor, type ExtensionAPI, type ExtensionContext, type ReadonlyFooterDataProvider, type Theme } from "@earendil-works/pi-coding-agent";
import { Key, matchesKey, sliceByColumn, stripTerminalSequences, Text, truncateToWidth, visibleWidth, wrapTextWithAnsi } from "@earendil-works/pi-tui";

const MAX_LEN = 80;
const graphemes = new Intl.Segmenter(undefined, { granularity: "grapheme" });
const clean = (text: string) => text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim();
const plain = (text: string) => clean(stripTerminalSequences(text));

function formatTokens(count: number): string {
	if (count < 1000) return String(count);
	if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1000000) return `${Math.round(count / 1000)}k`;
	if (count < 10000000) return `${(count / 1000000).toFixed(1)}M`;
	return `${Math.round(count / 1000000)}M`;
}

function abbreviateSegment(segment: string): string {
	const chars = Array.from(graphemes.segment(segment), ({ segment }) => segment);
	if (/^[\p{L}\p{N}]/u.test(chars[0])) return chars[0];
	return chars[0] + (chars.slice(1).find((char) => /^[\p{L}\p{N}]/u.test(char)) ?? "");
}

function shorten(pwd: string, keepLast: number): string {
	const home = pwd === "~" || pwd.startsWith("~/");
	const segments = pwd.split("/").filter(Boolean).slice(home ? 1 : 0);
	if (segments.length <= keepLast) return pwd;
	const prefix = home ? "~/" : pwd.startsWith("/") ? "/" : "";
	return prefix + [...segments.slice(0, -keepLast).map(abbreviateSegment), ...segments.slice(-keepLast)].join("/");
}

export function shortenCwd(pwd: string, maxLen = MAX_LEN): string {
	if (maxLen <= 0) return "";
	let out = shorten(pwd, 2);
	if (visibleWidth(out) <= maxLen) return out;
	out = shorten(pwd, 1);
	if (visibleWidth(out) <= maxLen) return out;
	return "…" + sliceByColumn(out, Math.max(0, visibleWidth(out) - maxLen + 1), maxLen - 1, true);
}

function homePath(cwd: string): string {
	const home = process.env.HOME || process.env.USERPROFILE;
	if (cwd === home) return "~";
	return home && cwd.startsWith(`${home}/`) ? `~${cwd.slice(home.length)}` : cwd;
}

// Keep complete native fields when possible; an ellipsis points to /statusline details.
function fitFields(fields: string[], width: number): string {
	if (width <= 0) return "";
	if (visibleWidth(fields.join(" ")) <= width) return fields.join(" ");
	const kept: string[] = [];
	for (const field of fields) {
		if (visibleWidth([...kept, field, "…"].join(" ")) > width) break;
		kept.push(field);
	}
	return [...kept, "…"].join(" ");
}

function align(left: string, right: string, width: number): string {
	if (width <= 0) return "";
	const r = truncateToWidth(right, width, "…");
	const l = truncateToWidth(left, Math.max(0, width - visibleWidth(r) - (left && r ? 2 : 0)), "…");
	return l + " ".repeat(Math.max(0, width - visibleWidth(l) - visibleWidth(r))) + r;
}

function extensionRows(data: ReadonlyFooterDataProvider, theme: Theme, width: number): string[] {
	if (width <= 0) return [];
	const rows: string[] = [];
	let row = "";
	const separator = theme.fg("dim", "  │  ");
	for (const [, value] of [...data.getExtensionStatuses()].sort(([a], [b]) => a.localeCompare(b))) {
		const text = clean(value);
		if (!plain(text)) continue;
		if (row && visibleWidth(row + separator + text) <= width) {
			row += separator + text;
			continue;
		}
		if (row) rows.push(row);
		const wrapped = wrapTextWithAnsi(text, width).map((line) => truncateToWidth(line, width, "…"));
		rows.push(...wrapped.slice(0, -1));
		row = wrapped.at(-1) ?? "";
	}
	if (row) rows.push(row);
	return rows;
}

export default function piMinimalStatuslineExtension(pi: ExtensionAPI) {
	let lines: 1 | 2 | 3 = 2;
	let configured = false;
	let active: { ctx: ExtensionContext; data: ReadonlyFooterDataProvider; theme: Theme; render(): void; dispose(): void } | undefined;
	let totalsCache: {
		manager: ExtensionContext["sessionManager"]; session: string; leaf: string | null;
		input: number; output: number; cacheRead: number; cacheWrite: number; cost: number; hit?: number;
	} | undefined;

	function snapshot(ctx: ExtensionContext, data: ReadonlyFooterDataProvider, theme: Theme) {
		const manager = ctx.sessionManager;
		const session = manager.getSessionId();
		const leaf = manager.getLeafId();
		// Appends move the leaf; rendering both widget and footer must not rescan the session.
		if (!totalsCache || totalsCache.manager !== manager || totalsCache.session !== session || totalsCache.leaf !== leaf) {
			const totals = { manager, session, leaf, input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, hit: undefined as number | undefined };
			for (const entry of manager.getEntries()) {
				let usage;
				if (entry.type === "usage") usage = entry.usage;
				else if (entry.type === "message" && entry.message.role === "assistant") {
					usage = entry.message.usage;
					const prompt = usage.input + usage.cacheRead + usage.cacheWrite;
					totals.hit = prompt > 0 ? usage.cacheRead / prompt * 100 : undefined;
				} else if (entry.type === "message" && entry.message.role === "toolResult") usage = entry.message.usage;
				else if (entry.type === "branch_summary" || entry.type === "compaction") usage = entry.usage;
				if (!usage) continue;
				totals.input += usage.input;
				totals.output += usage.output;
				totals.cacheRead += usage.cacheRead;
				totals.cacheWrite += usage.cacheWrite;
				totals.cost += usage.cost.total;
			}
			totalsCache = totals;
		}
		const totals = totalsCache;
		const counters: string[] = [];
		if (totals.input) counters.push(`↑${formatTokens(totals.input)}`);
		if (totals.output) counters.push(`↓${formatTokens(totals.output)}`);
		if (totals.cacheRead) counters.push(`R${formatTokens(totals.cacheRead)}`);
		if (totals.cacheWrite) counters.push(`W${formatTokens(totals.cacheWrite)}`);
		if ((totals.cacheRead || totals.cacheWrite) && totals.hit !== undefined) counters.push(`CH${totals.hit.toFixed(1)}%`);

		const model = ctx.model;
		const subscription = model && (model.provider === "kimi-coding" || (
			ctx.modelRegistry.isUsingOAuth(model) && ctx.modelRegistry.getProvider(model.provider)?.auth.oauth?.isSubscription === true
		));
		const cost = totals.cost || subscription ? `$${totals.cost.toFixed(3)}${subscription ? " (sub)" : ""}` : "";
		const context = ctx.getContextUsage();
		const percent = context?.percent != null ? `${context.percent.toFixed(1)}%` : "?";
		const auto = pi.getSettings().compaction?.enabled !== false ? " (auto)" : "";
		const contextText = `${percent}/${formatTokens(context?.contextWindow ?? model?.contextWindow ?? 0)}${auto}`;
		const color = context?.percent != null && context.percent > 90 ? "error" : context?.percent != null && context.percent > 70 ? "warning" : "accent";
		const effort = ctx.thinkingLevel ?? pi.getThinkingLevel();
		const modelText = (model?.id ?? "no-model") + (model?.reasoning ? ` • ${effort === "off" ? "thinking off" : effort}` : "");
		const providerModel = model && data.getAvailableProviderCount() > 1 ? `(${model.provider}) ${modelText}` : modelText;
		const cwd = plain(homePath(manager.getCwd()));
		const branch = data.getGitBranch();
		const name = manager.getSessionName();
		const suffix = (branch ? ` (${plain(branch)})` : "") + (name ? ` • ${plain(name)}` : "");
		return { counters, cost, context: theme.fg(color, contextText), model: modelText, providerModel, cwd, suffix };
	}

	function layout(ctx: ExtensionContext, data: ReadonlyFooterDataProvider, theme: Theme, width: number) {
		if (width <= 0) return { shelf: [] as string[], footer: [] as string[] };
		const s = snapshot(ctx, data, theme);
		const dim = (text: string) => theme.fg("dim", text);
		const fullLocation = shortenCwd(s.cwd) + s.suffix;
		const identity = visibleWidth(fullLocation) + 2 + visibleWidth(s.providerModel) <= width ? s.providerModel : s.model;
		const model = theme.fg("accent", identity);
		let trailing = [s.cost ? dim(s.cost) : "", s.context].filter(Boolean).join(" ");
		if (visibleWidth(trailing) > width) trailing = s.context;
		const budget = Math.max(0, width - visibleWidth(trailing) - 2);
		const usage = align(dim(fitFields(s.counters, budget)), trailing, width);
		let shelf: string[];
		let footer: string[];
		if (lines === 1) {
			let right = `${model}  ${s.context}`;
			if (visibleWidth(right) > width) right = align(theme.fg("accent", s.model), s.context, width);
			const fields = [...s.counters, ...(s.cost ? [s.cost] : [])];
			if (visibleWidth([fullLocation, ...fields].join(" ")) + 2 + visibleWidth(right) <= width) fields.unshift(fullLocation);
			shelf = [];
			footer = [align(dim(fitFields(fields, Math.max(0, width - visibleWidth(right) - 2))), right, width)];
		} else if (lines === 3) {
			shelf = [truncateToWidth(dim(fullLocation), width, "…")];
			footer = [truncateToWidth(model, width, "…"), usage];
		} else {
			const locationWidth = Math.max(0, width - visibleWidth(model) - 2);
			const location = shortenCwd(s.cwd, Math.max(0, Math.min(MAX_LEN, locationWidth - visibleWidth(s.suffix)))) + s.suffix;
			shelf = [align(dim(location), model, width)];
			footer = [usage];
		}
		return { shelf, footer: [...footer, ...extensionRows(data, theme, width)] };
	}

	pi.registerFlag("statusline-lines", { type: "string", default: "2", description: "Split ledger core rows: 1, 2, or 3; extension rows are additional" });
	pi.registerCommand("statusline", {
		description: "Split ledger: /statusline 1|2|3 or /statusline details",
		handler: async (args, ctx) => {
			const arg = args.trim();
			if (arg === "1" || arg === "2" || arg === "3") {
				lines = Number(arg) as 1 | 2 | 3;
				active?.render();
				return;
			}
			if (arg !== "details" || !active) {
				ctx.ui.notify("Use /statusline 1|2|3 or /statusline details", "info");
				return;
			}
			const s = snapshot(ctx, active.data, active.theme);
			const statuses = [...active.data.getExtensionStatuses()].sort(([a], [b]) => a.localeCompare(b)).map(([key, value]) => `${plain(key)}: ${clean(value)}`);
			const text = new Text([
				`Directory: ${s.cwd}${s.suffix}`, `Model: ${s.providerModel}`,
				`Usage: ${[...s.counters, s.cost, s.context].filter(Boolean).join(" ")}`,
				`Core rows: ${lines} (extension rows additional)`, "", ...statuses,
			].join("\n"), 0, 0);
			await ctx.ui.custom<void>((tui, theme, _keys, done) => {
				let offset = 0;
				let height = 1;
				let length = 0;
				return {
					invalidate: () => text.invalidate(),
					render(width) {
						if (width <= 0) return [];
						const body = text.render(width);
						length = body.length;
						height = Math.max(1, tui.terminal.rows - 4);
						offset = Math.min(offset, Math.max(0, length - height));
						return [align(theme.fg("accent", "Split ledger · full status"), "", width), ...body.slice(offset, offset + height), align(theme.fg("dim", "↑/↓ PgUp/PgDn scroll · Esc close"), "", width)];
					},
					handleInput(input) {
						if (matchesKey(input, Key.escape) || matchesKey(input, Key.enter)) { done(); return; }
						if (matchesKey(input, Key.up)) offset--;
						if (matchesKey(input, Key.down)) offset++;
						if (matchesKey(input, Key.pageUp)) offset -= height;
						if (matchesKey(input, Key.pageDown)) offset += height;
						if (matchesKey(input, Key.home)) offset = 0;
						if (matchesKey(input, Key.end)) offset = length;
						offset = Math.max(0, Math.min(offset, Math.max(0, length - height)));
						tui.requestRender();
					},
				};
			}, { overlay: true, overlayOptions: { width: "100%", maxHeight: "100%" } });
		},
	});

	pi.on("session_start", (_event, ctx) => {
		active?.dispose();
		active = undefined;
		totalsCache = undefined;
		if (!ctx.hasUI || ctx.mode !== "tui") return;
		if (!configured) {
			const flag = pi.getFlag("statusline-lines");
			if (flag === "1" || flag === "2" || flag === "3") lines = Number(flag) as 1 | 2 | 3;
			else ctx.ui.notify("Invalid --statusline-lines; using 2", "warning");
			configured = true;
		}
		ctx.ui.setFooter((tui, theme, data) => {
			let disposed = false;
			const unsubscribe = data.onBranchChange(() => tui.requestRender());
			const previousEditor = ctx.ui.getEditorComponent();
			// Ordinary widgets follow publication order, so keep the shelf inside the editor.
			const shelfEditor: NonNullable<typeof previousEditor> = (editorTui, editorTheme, keybindings) => {
				const editor = previousEditor?.(editorTui, editorTheme, keybindings)
					?? new CustomEditor(editorTui, editorTheme, keybindings, { embedWorkingStatus: true });
				const render = editor.render.bind(editor);
				editor.render = (width) => [...(disposed ? [] : layout(ctx, data, theme, width).shelf), ...render(width)];
				return editor;
			};
			const owner = {
				ctx, data, theme,
				render: () => tui.requestRender(),
				dispose() {
					if (disposed) return;
					disposed = true;
					unsubscribe();
					if (ctx.ui.getEditorComponent() === shelfEditor) ctx.ui.setEditorComponent(previousEditor);
					if (active === owner) active = undefined;
				},
			};
			active = owner;
			ctx.ui.setEditorComponent(shelfEditor);
			return { render: (width) => layout(ctx, data, theme, width).footer, invalidate() {}, dispose: owner.dispose };
		});
	});
	pi.on("session_shutdown", () => active?.dispose());
}
