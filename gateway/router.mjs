import http from "node:http";
import fs from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HOST = "127.0.0.1";
const PORT = 4000;

const BASE_DIR = dirname(fileURLToPath(import.meta.url));
const ENV_FILE = join(BASE_DIR, ".env");

const LOCAL_TOKEN = "sk-local-claude-code";

const MAX_RETRIES = 3;
const RETRYABLE_STATUS_CODES = new Set([
    429,
    500,
    502,
    503,
    529
]);

function loadEnv(file) {
    if (!fs.existsSync(file)) {
        throw new Error(`Missing .env file: ${file}`);
    }

    for (const line of fs.readFileSync(file, "utf8").split(/\r?\n/)) {
        const trimmed = line
            .replace(/^\uFEFF/, "")
            .trim();

        if (!trimmed || trimmed.startsWith("#")) {
            continue;
        }

        const separator = trimmed.indexOf("=");

        if (separator === -1) {
            continue;
        }

        const key = trimmed
            .slice(0, separator)
            .trim()
            .replace(/^\uFEFF/, "");

        const value = trimmed
            .slice(separator + 1)
            .trim()
            .replace(/^['"]|['"]$/g, "");

        process.env[key] = value;
    }
}

loadEnv(ENV_FILE);

const ZAI_API_KEY = process.env.ZAI_API_KEY;
const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;

if (!ZAI_API_KEY) {
    throw new Error("ZAI_API_KEY is missing from .env");
}

if (!DEEPSEEK_API_KEY) {
    throw new Error("DEEPSEEK_API_KEY is missing from .env");
}

const MODELS = {
    "claude-glm-5-3-flash": {
        provider: "Z.AI",
        upstreamModel: "glm-5.3-flash",
        url: "https://api.z.ai/api/anthropic/v1/messages",
        apiKey: ZAI_API_KEY
    },

    "claude-glm-4-7-flash": {
        provider: "Z.AI",
        upstreamModel: "glm-4.7-flash",
        url: "https://api.z.ai/api/anthropic/v1/messages",
        apiKey: ZAI_API_KEY
    },

    "claude-deepseek-v4-flash": {
        provider: "DeepSeek",
        upstreamModel: "deepseek-v4-flash",
        url: "https://api.deepseek.com/anthropic/v1/messages",
        apiKey: DEEPSEEK_API_KEY
    }
};

function sendJSON(res, status, data) {
    const body = JSON.stringify(data);

    res.writeHead(status, {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(body)
    });

    res.end(body);
}

function isAuthorized(req) {
    return (
        req.headers.authorization === `Bearer ${LOCAL_TOKEN}` ||
        req.headers["x-api-key"] === LOCAL_TOKEN
    );
}

async function readBody(req) {
    const chunks = [];

    for await (const chunk of req) {
        chunks.push(chunk);
    }

    return Buffer.concat(chunks).toString("utf8");
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

function getRetryDelay(response, attempt) {
    const retryAfter = response.headers.get("retry-after");

    if (retryAfter) {
        const seconds = Number(retryAfter);

        if (Number.isFinite(seconds)) {
            return Math.min(seconds * 1000, 30000);
        }
    }

    const delays = [2000, 5000, 10000];

    return delays[Math.min(attempt, delays.length - 1)];
}

async function fetchUpstream(url, headers, body) {
    let lastResponse = null;

    for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {

        const response = await fetch(url, {
            method: "POST",
            headers,
            body,
            signal: AbortSignal.timeout(15 * 60 * 1000)
        });

        lastResponse = response;

        if (!RETRYABLE_STATUS_CODES.has(response.status)) {
            return response;
        }

        if (attempt === MAX_RETRIES) {
            return response;
        }

        const delay = getRetryDelay(response, attempt);

        console.log(
            `[Gateway] Upstream returned HTTP ${response.status}. ` +
            `Retrying in ${delay}ms (attempt ${attempt + 1}/${MAX_RETRIES})`
        );

        await response.body?.cancel();

        await sleep(delay);
    }

    return lastResponse;
}

async function proxyResponse(upstream, res) {
    const responseHeaders = {};

    upstream.headers.forEach((value, key) => {
        const lower = key.toLowerCase();

        if (
            lower !== "content-length" &&
            lower !== "connection" &&
            lower !== "transfer-encoding" &&
            lower !== "content-encoding"
        ) {
            responseHeaders[key] = value;
        }
    });

    res.writeHead(upstream.status, responseHeaders);

    if (!upstream.body) {
        res.end();
        return;
    }

    const reader = upstream.body.getReader();

    try {
        while (true) {
            const { done, value } = await reader.read();

            if (done) {
                break;
            }

            res.write(Buffer.from(value));
        }
    } finally {
        reader.releaseLock();
    }

    res.end();
}

async function handleMessages(req, res) {

    if (!isAuthorized(req)) {
        sendJSON(res, 401, {
            error: {
                type: "authentication_error",
                message: "Invalid local gateway token"
            }
        });

        return;
    }

    const rawBody = await readBody(req);

    let body;

    try {
        body = JSON.parse(rawBody);
    } catch {
        sendJSON(res, 400, {
            error: {
                type: "invalid_request_error",
                message: "Invalid JSON body"
            }
        });

        return;
    }

    const requestedModel = body.model;
    const route = MODELS[requestedModel];

    if (!route) {
        sendJSON(res, 400, {
            error: {
                type: "invalid_request_error",
                message: `Unknown model: ${requestedModel}`,
                available_models: Object.keys(MODELS)
            }
        });

        return;
    }

    body.model = route.upstreamModel;

    const upstreamHeaders = {
        "content-type": "application/json",
        "x-api-key": route.apiKey,
        "anthropic-version":
            req.headers["anthropic-version"] || "2023-06-01"
    };

    if (req.headers["anthropic-beta"]) {
        upstreamHeaders["anthropic-beta"] = req.headers["anthropic-beta"];
    }

    if (req.headers["accept"]) {
        upstreamHeaders["accept"] = req.headers["accept"];
    }

    console.log(
        `[${new Date().toISOString()}] ` +
        `${requestedModel} -> ${route.provider} -> ${route.upstreamModel}`
    );

    let upstream;

    try {
        upstream = await fetchUpstream(
            route.url,
            upstreamHeaders,
            JSON.stringify(body)
        );
    } catch (error) {
        sendJSON(res, 502, {
            error: {
                type: "api_error",
                message: `Upstream request failed: ${error.message}`
            }
        });

        return;
    }

    await proxyResponse(upstream, res);
}

const server = http.createServer(async (req, res) => {

    try {

        const url = new URL(
            req.url,
            `http://${HOST}:${PORT}`
        );

        if (req.method === "GET" && url.pathname === "/") {

            sendJSON(res, 200, {
                status: "ok",
                name: "Claude Code Local Model Gateway",
                models: Object.keys(MODELS)
            });

            return;
        }

        if (req.method === "GET" && url.pathname === "/v1/models") {

            if (!isAuthorized(req)) {
                sendJSON(res, 401, {
                    error: {
                        type: "authentication_error",
                        message: "Invalid local gateway token"
                    }
                });

                return;
            }

            sendJSON(res, 200, {
                object: "list",

                data: Object.keys(MODELS).map(id => ({
                    id,
                    object: "model",
                    created: Math.floor(Date.now() / 1000),
                    owned_by: "local-gateway"
                }))
            });

            return;
        }

        if (
            req.method === "POST" &&
            url.pathname === "/v1/messages"
        ) {
            await handleMessages(req, res);
            return;
        }

        if (
            req.method === "POST" &&
            url.pathname === "/v1/messages/count_tokens"
        ) {
            sendJSON(res, 501, {
                error: {
                    type: "not_implemented_error",
                    message:
                        "Token counting is not implemented by the local gateway."
                }
            });

            return;
        }

        sendJSON(res, 404, {
            error: {
                type: "not_found_error",
                message:
                    `Route not found: ${req.method} ${url.pathname}`
            }
        });

    } catch (error) {

        console.error(error);

        if (!res.headersSent) {

            sendJSON(res, 500, {
                error: {
                    type: "api_error",
                    message: error.message
                }
            });

        } else {
            res.end();
        }
    }
});

server.on("error", error => {
    console.error("Gateway server error:", error);
    process.exit(1);
});

server.listen(PORT, HOST, () => {

    console.log("");
    console.log("==========================================");
    console.log("      CLAUDE CODE LOCAL MODEL GATEWAY");
    console.log("==========================================");
    console.log("");

    console.log(
        `Listening: http://${HOST}:${PORT}`
    );

    console.log("");

    console.log("Models:");

    console.log(
        "  claude-glm-5-3-flash       -> Z.AI"
    );

    console.log(
        "  claude-glm-4-7-flash       -> Z.AI"
    );

    console.log(
        "  claude-deepseek-v4-flash   -> DeepSeek"
    );

    console.log("");
});