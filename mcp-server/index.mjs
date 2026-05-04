#!/usr/bin/env node

/**
 * agent-watch MCP server
 *
 * Thin MCP-over-stdio wrapper around the agent-watch local HTTP API.
 * Expects `agent-watch serve --capture` running on 127.0.0.1:41733.
 *
 * Usage as an MCP connector (HandsFree / OpenCode config):
 *   { "type": "stdio", "command": "npx", "args": ["-y", "agent-watch-mcp"] }
 *
 * Or run directly:
 *   AGENT_WATCH_PORT=41733 node index.mjs
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const BASE = `http://127.0.0.1:${process.env.AGENT_WATCH_PORT || "41733"}`;

async function api(path, options = {}) {
  const url = `${BASE}${path}`;
  try {
    const response = await fetch(url, options);
    const text = await response.text();
    try {
      return JSON.parse(text);
    } catch {
      return { ok: false, error: text || `HTTP ${response.status}` };
    }
  } catch (error) {
    return { ok: false, error: `agent-watch unreachable at ${url}: ${error.message}` };
  }
}

const server = new McpServer({
  name: "agent-watch",
  version: "0.1.0",
});

// ── screen_capture ──
// Triggers a live capture of whatever is on screen right now.
server.tool(
  "screen_capture",
  "Capture text from the current screen using macOS accessibility or OCR. Returns the live text content of the frontmost app.",
  {},
  async () => {
    const result = await api("/capture", { method: "POST" });
    if (result.error) {
      return { content: [{ type: "text", text: `Error: ${result.error}${result.message ? ` — ${result.message}` : ""}` }], isError: true };
    }
    const parts = [];
    if (result.appName) parts.push(`App: ${result.appName}`);
    if (result.windowTitle) parts.push(`Window: ${result.windowTitle}`);
    if (result.source) parts.push(`Source: ${result.source}`);
    parts.push(`Outcome: ${result.outcome || "unknown"}`);
    if (result.text) parts.push(`\n${result.text}`);
    return { content: [{ type: "text", text: parts.join("\n") }] };
  }
);

// ── screen_latest ──
// Returns the most recent capture(s) without triggering a new one.
server.tool(
  "screen_latest",
  "Get the most recent screen capture records from the agent-watch database.",
  { limit: z.number().min(1).max(50).default(1).describe("Number of recent records to return") },
  async ({ limit }) => {
    const result = await api(`/latest?limit=${limit}`);
    if (result.error) {
      return { content: [{ type: "text", text: `Error: ${result.error}` }], isError: true };
    }
    if (!result.results?.length) {
      return { content: [{ type: "text", text: "No captures found." }] };
    }
    const text = result.results.map((r, i) => {
      const header = [`[${i + 1}] ${r.appName}${r.windowTitle ? ` — ${r.windowTitle}` : ""} (${r.source}, ${r.timestamp})`];
      if (r.text) header.push(r.text);
      return header.join("\n");
    }).join("\n\n---\n\n");
    return { content: [{ type: "text", text }] };
  }
);

// ── screen_search ──
// Full-text search over historical captures.
server.tool(
  "screen_search",
  "Search historical screen captures by keyword. Uses SQLite FTS5 full-text search over all past captures.",
  {
    query: z.string().describe("Search query (FTS5 syntax)"),
    limit: z.number().min(1).max(200).default(10).describe("Max results"),
    app: z.string().optional().describe("Filter by app name"),
  },
  async ({ query, limit, app }) => {
    let path = `/search?q=${encodeURIComponent(query)}&limit=${limit}`;
    if (app) path += `&app=${encodeURIComponent(app)}`;
    const result = await api(path);
    if (result.error) {
      return { content: [{ type: "text", text: `Error: ${result.error}` }], isError: true };
    }
    if (!result.results?.length) {
      return { content: [{ type: "text", text: `No results for "${query}".` }] };
    }
    const text = result.results.map((r, i) =>
      `[${i + 1}] ${r.appName}${r.windowTitle ? ` — ${r.windowTitle}` : ""} (${r.source}, ${r.timestamp})\n${r.snippet}`
    ).join("\n\n");
    return { content: [{ type: "text", text: `${result.count} results for "${query}":\n\n${text}` }] };
  }
);

// ── screen_status ──
// Returns agent-watch status: record count, permissions, last capture time.
server.tool(
  "screen_status",
  "Check agent-watch status: record count, permissions, database size, and last capture time.",
  {},
  async () => {
    const result = await api("/status");
    if (result.error) {
      return { content: [{ type: "text", text: `Error: ${result.error}` }], isError: true };
    }
    const lines = [
      `Records: ${result.recordCount ?? "?"}`,
      `Last capture: ${result.lastCaptureAt ?? "never"}`,
      `Database: ${result.databaseBytes ? Math.round(result.databaseBytes / 1024) + " KB" : "?"}`,
      `Accessibility: ${result.accessibilityGranted ? "granted" : "denied"}`,
      `Screen recording: ${result.screenRecordingGranted ? "granted" : "denied"}`,
    ];
    return { content: [{ type: "text", text: lines.join("\n") }] };
  }
);

// ── Start ──
const transport = new StdioServerTransport();
await server.connect(transport);
