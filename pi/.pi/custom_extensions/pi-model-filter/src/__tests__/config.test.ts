import { describe, it, expect, vi } from "vitest";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { findProjectConfig, isBlocked, loadLayeredConfig, validateConfig, type FilterConfig, type Logger } from "../extension";

function makeLogger(): Logger & { messages: string[] } {
  const messages: string[] = [];
  return {
    messages,
    warn: (msg) => messages.push(msg),
  };
}

describe("loadLayeredConfig", () => {
  it("finds project config from a nested working directory", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-model-filter-"));
    const projectDir = join(dir, "project");
    const nestedDir = join(projectDir, "src");
    const configPath = join(projectDir, ".pi", "model-filter.json");
    mkdirSync(join(projectDir, ".pi"), { recursive: true });
    mkdirSync(nestedDir, { recursive: true });
    writeFileSync(configPath, "{}");
    try {
      expect(findProjectConfig(nestedDir)).toBe(configPath);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("uses project rules before global rules and inherits global defaultAction", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-model-filter-"));
    const globalPath = join(dir, "global.json");
    const projectPath = join(dir, "project.json");
    const log = makeLogger();
    writeFileSync(globalPath, JSON.stringify({ rules: [{ provider: "openai", action: "block", match: { patterns: ["*"] } }], defaultAction: "block" }));
    writeFileSync(projectPath, JSON.stringify({ rules: [{ provider: "openai", action: "allow", match: { ids: ["gpt-6"] } }] }));

    try {
      const config = loadLayeredConfig(globalPath, projectPath, log);
      expect(isBlocked(config, { provider: "openai", id: "gpt-6" })).toBe(false);
      expect(isBlocked(config, { provider: "openai", id: "gpt-5" })).toBe(true);
      expect(config.defaultAction).toBe("block");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});

describe("validateConfig", () => {
  it("accepts valid minimal config", () => {
    const log = makeLogger();
    const result = validateConfig({ rules: [], defaultAction: "allow" }, log);
    expect(result).toEqual({ rules: [], defaultAction: "allow" });
    expect(log.messages).toHaveLength(0);
  });

  it("defaults rules to [] and defaultAction to allow", () => {
    const log = makeLogger();
    const result = validateConfig({}, log);
    expect(result).toEqual({ rules: [], defaultAction: "allow" });
  });

  it("rejects non-object config", () => {
    const log = makeLogger();
    expect(validateConfig("not an object", log)).toBeUndefined();
    expect(validateConfig(null, log)).toBeUndefined();
    expect(validateConfig(42, log)).toBeUndefined();
  });

  it("rejects invalid defaultAction", () => {
    const log = makeLogger();
    expect(
      validateConfig({ defaultAction: "deny" }, log),
    ).toBeUndefined();
  });

  it("validates a complete rule", () => {
    const log = makeLogger();
    const result = validateConfig(
      {
        rules: [
          {
            provider: "github-copilot",
            action: "block",
            match: { ids: ["gpt-5.4"] },
          },
        ],
        defaultAction: "allow",
      },
      log,
    );
    expect(result?.rules).toHaveLength(1);
    expect(result?.rules[0].provider).toBe("github-copilot");
    expect(result?.rules[0].action).toBe("block");
    expect(result?.rules[0].match.ids).toEqual(["gpt-5.4"]);
  });

  it("validates rule with all match fields", () => {
    const log = makeLogger();
    const result = validateConfig(
      {
        rules: [
          {
            provider: "*",
            action: "allow",
            match: {
              ids: ["gpt-5.4"],
              patterns: ["gpt-*"],
              reasoning: true,
              contextWindow: { min: 100000, max: 300000 },
            },
          },
        ],
      },
      log,
    );
    expect(result?.rules).toHaveLength(1);
    expect(result?.rules[0].match.ids).toEqual(["gpt-5.4"]);
    expect(result?.rules[0].match.patterns).toEqual(["gpt-*"]);
    expect(result?.rules[0].match.reasoning).toBe(true);
    expect(result?.rules[0].match.contextWindow).toEqual({
      min: 100000,
      max: 300000,
    });
  });

  it("rejects rule with empty provider", () => {
    const log = makeLogger();
    const result = validateConfig(
      {
        rules: [
          { provider: "", action: "block", match: { ids: ["x"] } },
        ],
      },
      log,
    );
    expect(result?.rules).toHaveLength(0);
  });

  it("rejects rule with invalid action", () => {
    const log = makeLogger();
    const result = validateConfig(
      {
        rules: [
          { provider: "*", action: "deny", match: { ids: ["x"] } },
        ],
      },
      log,
    );
    expect(result?.rules).toHaveLength(0);
  });

  it("rejects rule with empty match", () => {
    const log = makeLogger();
    const result = validateConfig(
      {
        rules: [{ provider: "*", action: "block", match: {} }],
      },
      log,
    );
    expect(result?.rules).toHaveLength(0);
  });

  it("rejects non-string ids and patterns without coercing them", () => {
    const log = makeLogger();
    const result = validateConfig({
      rules: [{ provider: "*", action: "block", match: { ids: ["ok", 42] } }],
    }, log);
    expect(result?.rules).toHaveLength(0);
    expect(log.messages).toContain("match.ids must be a non-empty array");

    const patterns = validateConfig({
      rules: [{ provider: "*", action: "block", match: { patterns: [true] } }],
    }, log);
    expect(patterns?.rules).toHaveLength(0);
  });

  it("rejects match.ids as empty array", () => {
    const log = makeLogger();
    const result = validateConfig(
      {
        rules: [{ provider: "*", action: "block", match: { ids: [] } }],
      },
      log,
    );
    expect(result?.rules).toHaveLength(0);
  });

  it("rejects contextWindow with no min or max", () => {
    const log = makeLogger();
    const result = validateConfig(
      {
        rules: [
          {
            provider: "*",
            action: "block",
            match: { contextWindow: {} },
          },
        ],
      },
      log,
    );
    expect(result?.rules).toHaveLength(0);
  });

  it("rejects contextWindow with negative min", () => {
    const log = makeLogger();
    const result = validateConfig(
      {
        rules: [
          {
            provider: "*",
            action: "block",
            match: { contextWindow: { min: -1 } },
          },
        ],
      },
      log,
    );
    expect(result?.rules).toHaveLength(0);
  });

  it("rejects contextWindow with NaN", () => {
    const log = makeLogger();
    const result = validateConfig(
      {
        rules: [
          {
            provider: "*",
            action: "block",
            match: { contextWindow: { min: Number.NaN } },
          },
        ],
      },
      log,
    );
    expect(result?.rules).toHaveLength(0);
  });

  it("rejects contextWindow with Infinity", () => {
    const log = makeLogger();
    const result = validateConfig(
      {
        rules: [
          {
            provider: "*",
            action: "block",
            match: { contextWindow: { min: Number.POSITIVE_INFINITY } },
          },
        ],
      },
      log,
    );
    expect(result?.rules).toHaveLength(0);
  });

  it("rejects contextWindow where min > max", () => {
    const log = makeLogger();
    const result = validateConfig(
      {
        rules: [
          {
            provider: "*",
            action: "block",
            match: { contextWindow: { min: 300000, max: 100000 } },
          },
        ],
      },
      log,
    );
    expect(result?.rules).toHaveLength(0);
  });

  it("accepts contextWindow with only min", () => {
    const log = makeLogger();
    const result = validateConfig(
      {
        rules: [
          {
            provider: "*",
            action: "block",
            match: { contextWindow: { min: 100000 } },
          },
        ],
      },
      log,
    );
    expect(result?.rules).toHaveLength(1);
    expect(result?.rules[0].match.contextWindow).toEqual({ min: 100000 });
  });

  it("accepts contextWindow with only max", () => {
    const log = makeLogger();
    const result = validateConfig(
      {
        rules: [
          {
            provider: "*",
            action: "block",
            match: { contextWindow: { max: 150000 } },
          },
        ],
      },
      log,
    );
    expect(result?.rules).toHaveLength(1);
    expect(result?.rules[0].match.contextWindow).toEqual({ max: 150000 });
  });

  it("skips invalid rules but keeps valid ones", () => {
    const log = makeLogger();
    const result = validateConfig(
      {
        rules: [
          { provider: "*", action: "block", match: { ids: ["valid"] } },
          { provider: "", action: "block", match: { ids: ["x"] } },
          { provider: "*", action: "allow", match: { patterns: ["*"] } },
        ],
      },
      log,
    );
    expect(result?.rules).toHaveLength(2);
    expect(result?.rules[0].match.ids).toEqual(["valid"]);
    expect(result?.rules[1].match.patterns).toEqual(["*"]);
  });
});
