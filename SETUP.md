Claude Code Local Model Gateway — Setup Guide

This document explains how to install and recreate the Claude Code Local Model Gateway on another Windows machine.

Overview

The gateway allows Claude Code to use multiple external AI models through one local Anthropic-compatible endpoint.

Claude Code communicates with:

```text
http://127.0.0.1:4000
```

The local Node.js gateway routes requests according to the selected model.

Supported Models

| Claude Code model          | Provider | Upstream model      |
| -------------------------- | -------- | ------------------- |
| `claude-glm-5-3-flash`     | Z.AI     | `glm-5.3-flash`     |
| `claude-glm-4-7-flash`     | Z.AI     | `glm-4.7-flash`     |
| `claude-deepseek-v4-flash` | DeepSeek | `deepseek-v4-flash` |

Architecture

```text
Claude Code
     |
     v
127.0.0.1:4000
     |
     +-------------------------+
     |            |            |
     v            v            v
   Z.AI         Z.AI       DeepSeek
     |            |            |
     v            v            v
GLM-5.3-Flash  GLM-4.7-Flash  DeepSeek V4 Flash
```

Directory Structure

The recommended local structure is:

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
    +-- install.ps1
    +-- README.md
    +-- SETUP.md
    +-- LICENSE
    +-- .gitignore
```

File Responsibilities

`gateway/router.mjs`

The main local gateway.

It:

* listens on `127.0.0.1:4000`
* exposes `/v1/models`
* accepts Anthropic-compatible `/v1/messages` requests
* reads the requested model
* routes GLM-5.3-Flash to Z.AI
* routes GLM-4.7-Flash to Z.AI
* routes DeepSeek V4 Flash to DeepSeek
* forwards responses back to Claude Code
* supports streamed responses

The router is intended to run locally and should not be exposed directly to the public internet.

`gateway/.env`

Contains the private provider API keys.

Example:

```text
ZAI_API_KEY=YOUR_ZAI_API_KEY
DEEPSEEK_API_KEY=YOUR_DEEPSEEK_API_KEY
```

Never commit this file to GitHub.

`gateway/.env.example`

Safe example of the required environment variables.

It contains no real credentials.

`startup/start-hidden.vbs`

Windows startup launcher.

It starts the Node.js gateway automatically and hides the process window.

The script resolves the current user's Desktop directory dynamically and does not depend on a specific Windows username.

`install.ps1`

Automatic Windows installer.

It:

1. verifies required files
2. asks for the Z.AI API key
3. asks for the DeepSeek API key
4. checks for Node.js
5. installs Claude Code if required
6. copies the system to the local `Claude Code\system` directory
7. creates `.env`
8. configures Claude Code
9. configures Windows Startup
10. starts the gateway
11. verifies `/v1/models`

`README.md`

Short project overview and architecture.

`SETUP.md`

Complete setup and recreation instructions.

`.gitignore`

Prevents secrets and machine-specific files from being committed.

`LICENSE`

MIT license for the project.

Requirements

* Windows 11
* Node.js 18 or newer
* npm
* Claude Code
* Z.AI API key
* DeepSeek API key

Installation on a New Windows Machine

The recommended method is to copy or clone the `system` directory and run `install.ps1`.

Method 1 — GitHub

Clone the repository:

```powershell
git clone https://github.com/Olh2012ooo/claude-code-local-gateway.git
```

Enter the repository:

```powershell
cd claude-code-local-gateway
```

Run the installer:

```powershell
powershell -ExecutionPolicy Bypass -File ".\install.ps1"
```

Method 2 — USB Drive

Copy the `system` directory from the USB drive to the new machine.

Open PowerShell inside the copied `system` directory and run:

```powershell
powershell -ExecutionPolicy Bypass -File ".\install.ps1"
```

The installer copies the required files from the USB/repository location to:

```text
%USERPROFILE%\Desktop\Claude Code\system
```

The USB drive can then be removed.

API Key Setup

During installation, the installer asks for:

```text
Z.AI API key
DeepSeek API key
```

The values are stored locally in:

```text
%USERPROFILE%\Desktop\Claude Code\system\gateway\.env
```

The API keys are not written to:

* `README.md`
* `SETUP.md`
* source code
* `.env.example`

Claude Code Configuration

Claude Code uses:

```text
%USERPROFILE%\.claude\settings.json
```

The important gateway settings are:

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

The installer preserves existing settings by backing up the existing `settings.json` before modifying it.

Automatic Startup

The installer places:

```text
start-hidden.vbs
```

in the Windows per-user Startup folder:

```text
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\
```

At login:

```text
Windows
    |
    v
Startup folder
    |
    v
start-hidden.vbs
    |
    v
Node.js
    |
    v
router.mjs
    |
    v
127.0.0.1:4000
```

The gateway therefore starts automatically in the background.

Model Routing

GLM-5.3-Flash

Claude Code:

```text
claude-glm-5-3-flash
```

routes to:

```text
Z.AI
glm-5.3-flash
```

Endpoint:

```text
https://api.z.ai/api/anthropic/v1/messages
```

GLM-4.7-Flash

Claude Code:

```text
claude-glm-4-7-flash
```

routes to:

```text
Z.AI
glm-4.7-flash
```

Endpoint:

```text
https://api.z.ai/api/anthropic/v1/messages
```

DeepSeek V4 Flash

Claude Code:

```text
claude-deepseek-v4-flash
```

routes to:

```text
DeepSeek
deepseek-v4-flash
```

Endpoint:

```text
https://api.deepseek.com/anthropic/v1/messages
```

Switching Models

Inside Claude Code:

```text
/model
```

Choose one of:

```text
claude-glm-5-3-flash
claude-glm-4-7-flash
claude-deepseek-v4-flash
```

The model can be changed during an existing Claude Code session.

Verify Installation

Check Node.js

```powershell
node --version
```

Check Claude Code

```powershell
claude --version
```

Check gateway port

```powershell
Get-NetTCPConnection -LocalPort 4000 -State Listen
```

A Node.js process should be listening on port `4000`.

Check model discovery

```powershell
Invoke-RestMethod `
    -Uri "http://127.0.0.1:4000/v1/models" `
    -Headers @{ Authorization = "Bearer sk-local-claude-code" } |
    ConvertTo-Json -Depth 10
```

Expected models:

```text
claude-glm-5-3-flash
claude-glm-4-7-flash
claude-deepseek-v4-flash
```

Start the Gateway Manually

For troubleshooting:

```powershell
node "$env:USERPROFILE\Desktop\Claude Code\system\gateway\router.mjs"
```

Expected:

```text
Listening: http://127.0.0.1:4000
```

Start the Startup Script Manually

```powershell
cscript.exe "$env:USERPROFILE\Desktop\Claude Code\system\startup\start-hidden.vbs"
```

Troubleshooting

Port 4000 is already in use

Find the process:

```powershell
Get-NetTCPConnection -LocalPort 4000 -State Listen |
    Select-Object LocalAddress, LocalPort, OwningProcess
```

Inspect the process:

```powershell
Get-Process -Id <PID>
```

If the process is the gateway, it is already running and no additional copy should be started.

Router does not start

Run it directly:

```powershell
node "$env:USERPROFILE\Desktop\Claude Code\system\gateway\router.mjs"
```

Check that `.env` exists:

```powershell
Test-Path "$env:USERPROFILE\Desktop\Claude Code\system\gateway\.env"
```

Expected:

```text
True
```

Models do not appear in `/model`

Check:

```powershell
Invoke-RestMethod `
    -Uri "http://127.0.0.1:4000/v1/models" `
    -Headers @{ Authorization = "Bearer sk-local-claude-code" } |
    ConvertTo-Json -Depth 10
```

Then check:

```powershell
Get-Content "$env:USERPROFILE\.claude\settings.json" -Raw |
    ConvertFrom-Json
```

GLM-4.7-Flash returns 529

A `529` response with an upstream overload message can come directly from Z.AI when the service is overloaded.

This is different from a gateway configuration error.

The router should be left unchanged unless the upstream API behavior changes.

API key errors

Check:

```text
%USERPROFILE%\Desktop\Claude Code\system\gateway\.env
```

Expected variables:

```text
ZAI_API_KEY=...
DEEPSEEK_API_KEY=...
```

Never paste the actual keys into support requests.

Security

Never publish:

```text
gateway/.env
```

Do not put API keys into:

* source code
* README.md
* SETUP.md
* Git commits
* screenshots
* public issue reports

The gateway binds to:

```text
127.0.0.1:4000
```

and is intended for local use.

Do not expose port `4000` to the public internet.

GitHub

The public source repository is:

```text
https://github.com/Olh2012ooo/claude-code-local-gateway
```

The public repository contains:

```text
router.mjs
install.ps1
README.md
SETUP.md
.env.example
start-hidden.vbs
LICENSE
.gitignore
```

The real `.env` file is intentionally excluded.

Recreating the System

The complete recreation process is:

```text
1. Install Node.js
2. Install Claude Code
3. Clone/download the repository
4. Run install.ps1
5. Enter Z.AI API key
6. Enter DeepSeek API key
7. Installer creates local .env
8. Installer configures Claude Code
9. Installer configures Windows Startup
10. Gateway starts
11. Verify /v1/models
12. Start Claude Code
13. Use /model
```

Design Principle

The gateway intentionally performs a small number of tasks.

Claude Code remains responsible for:

* sessions
* context
* tools
* agents
* model selection
* conversation state

The local gateway is responsible for:

* provider routing
* model mapping
* request forwarding
* response forwarding
* model discovery

Core flow:

```text
Claude Code
    |
    v
Local Gateway
    |
    v
Read model
    |
    v
Select provider
    |
    v
Forward request
    |
    v
Forward response
```

Current Tested Environment

The original setup was tested with:

```text
Windows 11
Node.js 26.7.0
Claude Code 2.1.251

Z.AI
- GLM-5.3-Flash
- GLM-4.7-Flash

DeepSeek
- DeepSeek V4 Flash
```

The gateway itself is designed to use the versions and model IDs configured in `router.mjs`.
