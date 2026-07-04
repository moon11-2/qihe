#!/usr/bin/env node

import { createServer } from "node:http";
import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";

const envPath = resolve(process.cwd(), ".env.local");
loadDotEnv(envPath);

const port = Number(process.env.DIFY_PROXY_PORT || 8787);
const apiKey = process.env.DIFY_API_KEY;
const apiBaseUrl = new URL(process.env.DIFY_API_BASE_URL || "https://api.dify.ai/v1");
const apiBasePath = normalizeApiBasePath(apiBaseUrl);
const proxyPrefix = "/api/dify";

if (!apiKey || apiKey.includes("replace-with") || apiKey.includes("your-dify")) {
  console.error("Missing DIFY_API_KEY. Create .env.local from .env.example and fill your Dify App API Key.");
  process.exit(1);
}

const server = createServer(async (request, response) => {
  setCorsHeaders(response);
  const startedAt = Date.now();

  if (request.method === "OPTIONS") {
    response.writeHead(204);
    response.end();
    logRequest(request, 204, startedAt);
    return;
  }

  const requestUrl = new URL(request.url || "/", `http://${request.headers.host || "127.0.0.1"}`);

  if (requestUrl.pathname === "/health") {
    response.writeHead(200, { "content-type": "application/json; charset=utf-8" });
    response.end(JSON.stringify({ ok: true, service: "hetongbang-dify-proxy" }));
    logRequest(request, 200, startedAt);
    return;
  }

  if (!requestUrl.pathname.startsWith(proxyPrefix)) {
    response.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    response.end("Not found");
    logRequest(request, 404, startedAt);
    return;
  }

  try {
    const body = await readRequestBody(request);
    const targetUrl = new URL(`${apiBasePath}${requestUrl.pathname.slice(proxyPrefix.length)}${requestUrl.search}`, apiBaseUrl);
    const headers = buildForwardHeaders(request);
    const forward = prepareForwardRequest(requestUrl.pathname, body, headers);

    const upstream = await fetch(targetUrl, {
      method: request.method,
      headers,
      body: request.method === "GET" || request.method === "HEAD" ? undefined : forward.body,
    });

    if (forward.aggregateSse && upstream.ok && isEventStream(upstream.headers)) {
      const aggregated = aggregateDifySse(await upstream.text());
      response.writeHead(200, { "content-type": "application/json; charset=utf-8" });
      response.end(JSON.stringify(aggregated));
    } else {
      const responseBody = Buffer.from(await upstream.arrayBuffer());
      const responseHeaders = filterResponseHeaders(upstream.headers);
      response.writeHead(upstream.status, responseHeaders);
      response.end(responseBody);
    }
    logRequest(request, upstream.status, startedAt);
  } catch (error) {
    response.writeHead(502, { "content-type": "application/json; charset=utf-8" });
    response.end(JSON.stringify({ error: "dify_proxy_error", message: error instanceof Error ? error.message : "Unknown proxy error" }));
    console.error(`[${new Date().toISOString()}] Dify proxy error: ${error instanceof Error ? error.message : "Unknown proxy error"}`);
    logRequest(request, 502, startedAt);
  }
});

server.listen(port, "0.0.0.0", () => {
  console.log(`Dify proxy listening on http://127.0.0.1:${port}${proxyPrefix}`);
  console.log(`Forwarding to ${apiBaseUrl.origin}${apiBasePath}`);
  if (!apiBasePath.endsWith("/v1")) {
    console.log("Dify proxy note: most Dify App API URLs end with /v1. Check DIFY_API_BASE_URL if upstream calls fail.");
  }
});

server.on("error", (error) => {
  console.error(`[${new Date().toISOString()}] Dify proxy server error: ${error instanceof Error ? error.message : "Unknown server error"}`);
});

function loadDotEnv(filePath) {
  if (!existsSync(filePath)) return;
  const content = readFileSync(filePath, "utf8");
  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const match = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!match) continue;
    const [, key, rawValue] = match;
    if (process.env[key]) continue;
    process.env[key] = unquote(rawValue.trim());
  }
}

function unquote(value) {
  if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
    return value.slice(1, -1);
  }
  return value;
}

function normalizeApiBasePath(url) {
  const path = url.pathname.replace(/\/$/, "");
  if (!path && url.hostname === "api.dify.ai") return "/v1";
  return path || "";
}

function setCorsHeaders(response) {
  response.setHeader("access-control-allow-origin", "*");
  response.setHeader("access-control-allow-methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS");
  response.setHeader("access-control-allow-headers", "content-type,authorization,x-requested-with");
}

function readRequestBody(request) {
  return new Promise((resolveBody, rejectBody) => {
    const chunks = [];
    request.on("data", (chunk) => chunks.push(chunk));
    request.on("end", () => resolveBody(Buffer.concat(chunks)));
    request.on("error", rejectBody);
  });
}

function buildForwardHeaders(request) {
  const headers = new Headers();
  const contentType = request.headers["content-type"];
  if (contentType) {
    headers.set("content-type", Array.isArray(contentType) ? contentType.join(", ") : contentType);
  }
  const accept = request.headers.accept;
  if (accept) {
    headers.set("accept", Array.isArray(accept) ? accept.join(", ") : accept);
  } else {
    headers.set("accept", "application/json, text/event-stream, */*");
  }
  headers.set("authorization", `Bearer ${apiKey}`);
  headers.set("user-agent", "qihe-dify-proxy/0.1");
  return headers;
}

function prepareForwardRequest(pathname, body, headers) {
  if (pathname !== `${proxyPrefix}/chat-messages` || body.length === 0) {
    return { body, aggregateSse: false };
  }

  try {
    const payload = JSON.parse(body.toString("utf8"));
    if (payload && payload.response_mode === "blocking") {
      payload.response_mode = "streaming";
      headers.set("content-type", "application/json");
      return {
        body: Buffer.from(JSON.stringify(payload), "utf8"),
        aggregateSse: true,
      };
    }
  } catch {
    return { body, aggregateSse: false };
  }

  return { body, aggregateSse: false };
}

function isEventStream(headers) {
  return (headers.get("content-type") || "").toLowerCase().includes("text/event-stream");
}

function aggregateDifySse(text) {
  let answer = "";
  let taskId = "";
  let messageId = "";
  let conversationId = "";
  let mode = "advanced-chat";
  let fallbackAnswer = "";

  for (const eventText of text.split(/\n\n+/)) {
    const dataLines = eventText
      .split(/\r?\n/)
      .filter((line) => line.startsWith("data:"))
      .map((line) => line.slice(5).trim())
      .filter(Boolean);
    if (!dataLines.length) continue;

    const dataText = dataLines.join("\n");
    if (dataText === "[DONE]") continue;

    let event;
    try {
      event = JSON.parse(dataText);
    } catch {
      continue;
    }

    if (event.event === "error") {
      throw new Error(event.message || event.code || "Dify streaming error");
    }

    if (typeof event.task_id === "string" && event.task_id) taskId = event.task_id;
    if (typeof event.conversation_id === "string" && event.conversation_id) conversationId = event.conversation_id;
    if (typeof event.message_id === "string" && event.message_id) messageId = event.message_id;
    if (typeof event.id === "string" && event.id) messageId = event.id;
    if (typeof event.mode === "string" && event.mode) mode = event.mode;

    if (event.event === "message_replace" && typeof event.answer === "string") {
      answer = event.answer;
    } else if (typeof event.answer === "string") {
      answer += event.answer;
    }

    const outputs = event && typeof event.data === "object" && event.data && typeof event.data.outputs === "object"
      ? event.data.outputs
      : null;
    if (outputs) {
      if (typeof outputs.answer === "string" && outputs.answer) {
        answer = outputs.answer;
      } else if (typeof outputs.text === "string" && outputs.text) {
        fallbackAnswer = outputs.text;
        if (!answer) answer = outputs.text;
      }
    }
  }

  return {
    event: "message",
    task_id: taskId,
    id: messageId,
    message_id: messageId,
    conversation_id: conversationId,
    mode,
    answer: answer || fallbackAnswer,
  };
}

function filterResponseHeaders(headers) {
  const output = {};
  for (const [key, value] of headers.entries()) {
    const lowerKey = key.toLowerCase();
    if (["content-encoding", "transfer-encoding", "connection", "keep-alive"].includes(lowerKey)) continue;
    output[key] = value;
  }
  setCorsHeaders({ setHeader: (key, value) => {
    output[key] = value;
  } });
  return output;
}

function logRequest(request, statusCode, startedAt) {
  const elapsed = Date.now() - startedAt;
  console.log(`[${new Date().toISOString()}] ${request.method} ${request.url} -> ${statusCode} ${elapsed}ms`);
}
