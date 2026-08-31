# Claude Code Local Model Gateway

A lightweight local Anthropic-compatible gateway for using multiple AI providers from Claude Code.

## Overview

This setup allows Claude Code to use multiple external models through one local gateway.

Claude Code sends requests to:

```text
http://127.0.0.1:4000
```

The local Node.js gateway identifies the requested model and forwards the request directly to the correct provider.

## Supported Models

| Claude Code model          | Provider | Upstream model      |
| -------------------------- | -------- | ------------------- |
| `claude-glm-5-3-flash`     | Z.AI     | `glm-5.3-flash`     |
| `claude-deepseek-v4-flash` | DeepSeek | `deepseek-v4-flash` |

## Architecture

```text
Claude Code
     |
     v
127.0.0.1:4000
     |
     +-------------------------+
     |                         |
     v                         v
   Z.AI                    DeepSeek
     |                         |
     v                         v
GLM-5.3-Flash             DeepSeek V4 Flash
```

### GLM routing

```text
claude-glm-5-3-flash
        ->
https://api.z.ai/api/anthropic/v1/messages
        ->
glm-5.3-flash
```

### DeepSeek routing

```text
claude-deepseek-v4-flash
        ->
https://api.deepseek.com/anthropic/v1/messages
        ->
deepseek-v4-flash
```

## Directory Structure

```text
Claude Code/
|
+-- projekter/
|   +-- project-1/
|   +-- project-2/
|   +-- ...
|
+-- system/
    |
    +-- gateway/
    |   +-- router.mjs
    |   +-- .env
    |   +-- .env.example
    |
    +-- startup/
    |   +-- start-hidden.vbs
    |
    +-- README.md
    +-- SETUP.md
    +-- LICENSE
    +-- .gitignore
```

## File Descriptions

### `system/gateway/router.mjs`

The main local gateway.

Responsibilities:

* listens on `127.0.0.1:4000`
* exposes `/v1/models`
* accepts Anthropic-compatible `/v1/messages` requests
* reads the requested model
* routes GLM requests to Z.AI
* routes DeepSeek requests to DeepSeek
* forwards streamed responses back to Claude Code
* removes upstream `content-encoding` headers to avoid double decompression

The router is intentionally local and is not designed to be exposed to the public internet.

### `system/gateway/.env`

Contains the private API keys.

Format:

```text
ZAI_API_KEY=YOUR_ZAI_API_KEY
DEEPSEEK_API_KEY=YOUR_DEEPSEEK_API_KEY
```

Never commit this file to GitHub.

### `system/gateway/.env.example`

Safe example configuration without real API keys.

Copy it to `.env` and insert your own keys.

### `system/startup/start-hidden.vbs`

Starts the Node.js gateway silently at Windows login.

It dynamically resolves the current user's Desktop path and therefore does not contain a hardcoded Windows username.

### `system/README.md`

Short project overview.

### `system/SETUP.md`

This document. Contains the complete recreation instructions.

### `system/.gitignore`

Prevents secrets and local machine files from being committed.

### `system/LICENSE`

MIT license.

## Claude Code Configuration

Claude Code settings are stored at:

```text
%USERPROFILE%\.claude\settings.json
```

The important settings are:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:4000",
    "ANTHROPIC_AUTH_TOKEN": "sk-local-claude-code",
    "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY": "1",
    "CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT": "1"
  }
}
```

These settings make Claude Code use the local gateway automatically.

## Switching Models

Inside an active Claude Code session:

```text
/model
```

Available models:

```text
claude-glm-5-3-flash
claude-deepseek-v4-flash
```

The model can be changed without ending the current session.

## Automatic Startup

The gateway is started automatically using the Windows per-user Startup folder:

```text
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\
```

The startup file is:

```text
start-hidden.vbs
```

It launches:

```text
%USERPROFILE%\Desktop\Claude Code\system\gateway\router.mjs
```

The gateway runs hidden in the background.

## Startup Flow

At Windows login:

```text
Windows
    ->
Startup folder
    ->
start-hidden.vbs
    ->
Node.js
    ->
router.mjs
    ->
127.0.0.1:4000
```

When Claude Code starts:

```text
Claude Code
    ->
127.0.0.1:4000
    ->
local router
    ->
Z.AI or DeepSeek
```

## Requirements

* Windows 11
* Node.js 18+
* Claude Code
* Z.AI API key
* DeepSeek API key

## Installation on Another Windows Machine

### 1. Install Node.js

Install Node.js.

Verify:

```powershell
node --version
```

### 2. Install Claude Code

```powershell
npm install -g @anthropic-ai/claude-code
```

Verify:

```powershell
claude --version
```

### 3. Create the directory structure

Create:

```text
%USERPROFILE%\Desktop\Claude Code\
%USERPROFILE%\Desktop\Claude Code\projekter\
%USERPROFILE%\Desktop\Claude Code\system\
%USERPROFILE%\Desktop\Claude Code\system\gateway\
%USERPROFILE%\Desktop\Claude Code\system\startup\
```

### 4. Copy the system files

Copy the contents of the `system` directory into:

```text
%USERPROFILE%\Desktop\Claude Code\system\
```

The important files are:

```text
system\gateway\router.mjs
system\gateway\.env.example
system\startup\start-hidden.vbs
system\README.md
system\SETUP.md
system\LICENSE
system\.gitignore
```

### 5. Create `.env`

Copy:

```text
system\gateway\.env.example
```

to:

```text
system\gateway\.env
```

Edit `.env`:

```text
ZAI_API_KEY=YOUR_ZAI_API_KEY
DEEPSEEK_API_KEY=YOUR_DEEPSEEK_API_KEY
```

Never publish `.env`.

### 6. Configure Claude Code

Create:

```text
%USERPROFILE%\.claude\settings.json
```

Add the gateway configuration:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:4000",
    "ANTHROPIC_AUTH_TOKEN": "sk-local-claude-code",
    "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY": "1",
    "CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT": "1"
  }
}
```

If `settings.json` already contains other Claude Code settings, merge the `env` section instead of deleting unrelated settings.

### 7. Configure Windows Startup

Copy:

```text
system\startup\start-hidden.vbs
```

to:

```text
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\
```

The script starts the gateway automatically when the user logs into Windows.

### 8. Start the gateway manually for testing

Run:

```powershell
node "$env:USERPROFILE\Desktop\Claude Code\system\gateway\router.mjs"
```

Expected:

```text
Listening: http://127.0.0.1:4000
```

### 9. Verify model discovery

Open another PowerShell window and run:

```powershell
Invoke-RestMethod `
    -Uri "http://127.0.0.1:4000/v1/models" `
    -Headers @{ Authorization = "Bearer sk-local-claude-code" } |
    ConvertTo-Json -Depth 10
```

Expected models:

```text
claude-glm-5-3-flash
claude-deepseek-v4-flash
```

### 10. Start Claude Code

Open a project:

```powershell
cd "$env:USERPROFILE\Desktop\Claude Code\projekter\<PROJECT>"
```

Start Claude Code:

```powershell
claude
```

Use:

```text
/model
```

to select the desired model.

## Testing the Gateway

### Check port 4000

```powershell
Get-NetTCPConnection -LocalPort 4000 -State Listen
```

A Node.js process should be listening.

### Check available models

```powershell
Invoke-RestMethod `
    -Uri "http://127.0.0.1:4000/v1/models" `
    -Headers @{ Authorization = "Bearer sk-local-claude-code" } |
    ConvertTo-Json -Depth 10
```

### Test GLM

The gateway should route:

```text
claude-glm-5-3-flash
```

to:

```text
glm-5.3-flash
```

through Z.AI.

### Test DeepSeek

The gateway should route:

```text
claude-deepseek-v4-flash
```

to:

```text
deepseek-v4-flash
```

through DeepSeek.

## Troubleshooting

### Port 4000 is already in use

Find the process:

```powershell
Get-NetTCPConnection -LocalPort 4000 -State Listen |
    Select-Object LocalAddress, LocalPort, OwningProcess
```

Inspect it:

```powershell
Get-Process -Id <PID>
```

### Router does not start

Run it directly:

```powershell
node "$env:USERPROFILE\Desktop\Claude Code\system\gateway\router.mjs"
```

Check whether `.env` exists:

```powershell
Test-Path "$env:USERPROFILE\Desktop\Claude Code\system\gateway\.env"
```

Expected:

```text
True
```

### Models do not appear in `/model`

Verify model discovery:

```powershell
Invoke-RestMethod `
    -Uri "http://127.0.0.1:4000/v1/models" `
    -Headers @{ Authorization = "Bearer sk-local-claude-code" } |
    ConvertTo-Json -Depth 10
```

Then verify Claude Code settings:

```powershell
Get-Content "$env:USERPROFILE\.claude\settings.json" -Raw |
    ConvertFrom-Json
```

### GLM does not work

Check:

* Z.AI API key
* `ZAI_API_KEY` in `.env`
* upstream model `glm-5.3-flash`
* Z.AI Anthropic endpoint

```text
https://api.z.ai/api/anthropic/v1/messages
```

### DeepSeek does not work

Check:

* DeepSeek API key
* `DEEPSEEK_API_KEY` in `.env`
* upstream model `deepseek-v4-flash`
* DeepSeek Anthropic endpoint

```text
https://api.deepseek.com/anthropic/v1/messages
```

## Security

Never publish:

```text
system/gateway/.env
```

Do not place API keys inside:

* `README.md`
* `SETUP.md`
* source code
* screenshots
* Git commits
* public issue reports

The gateway listens only on:

```text
127.0.0.1:4000
```

Do not expose this port to the public internet without implementing proper authentication and security controls.

## Recreation Checklist

On a new Windows machine:

```text
1. Install Node.js
2. Install Claude Code
3. Create Claude Code directory
4. Copy system directory
5. Create .env
6. Add Z.AI API key
7. Add DeepSeek API key
8. Configure Claude Code settings.json
9. Copy start-hidden.vbs to Windows Startup
10. Start Windows or run startup script manually
11. Verify port 4000
12. Verify /v1/models
13. Start Claude Code
14. Use /model
```

## Design Principle

The gateway intentionally stays small.

Claude Code remains responsible for:

* sessions
* context
* tools
* agents
* model selection
* conversation state

The local gateway is responsible for:

* provider routing
* request forwarding
* response forwarding
* model discovery

The core request flow is:

```text
receive request
    ->
read model
    ->
select provider
    ->
forward request
    ->
forward response
```

## Current Reference Environment

The original setup was tested with:

```text
Windows 11
Node.js 26.7.0
Claude Code 2.1.251
Z.AI GLM-5.3-Flash
DeepSeek V4 Flash
```

The gateway itself only requires a compatible Node.js version and the provider API keys.
