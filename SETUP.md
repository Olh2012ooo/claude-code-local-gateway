````text
===== SETUP.md =====

Claude Code Local Model Gateway — Setup Guide

This guide explains how to install, test, troubleshoot, and recreate the Claude Code Local Model Gateway on another Windows machine.

Overview

The gateway allows Claude Code to use multiple external AI models through one local Anthropic-compatible endpoint.

Claude Code communicates with:

```text
http://127.0.0.1:4000
````

The local Node.js gateway reads the selected model and routes the request to the correct provider.

Supported Models

| Claude Code Alias          | Provider | Upstream Model      |
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

Repository Structure

```text
claude-code-local-gateway/
|
+-- gateway/
|   +-- router.mjs
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
+-- .gitattributes
```

The repository does not contain the real `.env` file.

Installed Windows Structure

The installer creates:

```text
%USERPROFILE%\Desktop\Claude Code\
|
+-- projekter/
|
+-- system/
    |
    +-- gateway/
    |   +-- router.mjs
    |   +-- .env
    |   +-- .env.example
    |   +-- gateway.stdout.log
    |   +-- gateway.error.log
    |
    +-- startup/
    |   +-- start-hidden.vbs
    |
    +-- install.ps1
    +-- README.md
    +-- SETUP.md
    +-- LICENSE
    +-- .gitignore
    +-- .gitattributes
```

Requirements

* Windows 11
* Node.js 18 or newer
* npm
* Claude Code
* Z.AI API key
* DeepSeek API key

Git for Windows is recommended.

Installation from GitHub

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

Installation from USB

Copy the complete repository folder to the new machine.

Open PowerShell inside the repository folder and run:

```powershell
powershell -ExecutionPolicy Bypass -File ".\install.ps1"
```

The installer copies only the required system files to:

```text
%USERPROFILE%\Desktop\Claude Code\system
```

The source location does not need to remain on the computer.

API Keys

During installation, the installer asks for:

```text
Z.AI API key
DeepSeek API key
```

The keys are stored locally in:

```text
%USERPROFILE%\Desktop\Claude Code\system\gateway\.env
```

Example:

```text
ZAI_API_KEY=your_key_here
DEEPSEEK_API_KEY=your_key_here
```

The real `.env` file must never be committed to Git.

Claude Code Configuration

The installer configures:

```text
%USERPROFILE%\.claude\settings.json
```

The gateway environment is:

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

The installer also sets:

```text
claude-glm-5-3-flash
```

as the default model.

The model picker is configured to show only:

```text
GLM-5.3-Flash
GLM-4.7-Flash
DeepSeek V4 Flash
```

Existing `settings.json` content is preserved and backed up before modification.

Automatic Startup

The installer creates:

```text
%USERPROFILE%\Desktop\Claude Code\system\startup\start-hidden.vbs
```

It then copies that script to:

```text
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\
```

At Windows login:

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

Model Routing

GLM-5.3-Flash

```text
claude-glm-5-3-flash
        |
        v
Z.AI
        |
        v
glm-5.3-flash
```

Endpoint:

```text
https://api.z.ai/api/anthropic/v1/messages
```

GLM-4.7-Flash

```text
claude-glm-4-7-flash
        |
        v
Z.AI
        |
        v
glm-4.7-flash
```

Endpoint:

```text
https://api.z.ai/api/anthropic/v1/messages
```

DeepSeek V4 Flash

```text
claude-deepseek-v4-flash
        |
        v
DeepSeek
        |
        v
deepseek-v4-flash
```

Endpoint:

```text
https://api.deepseek.com/anthropic/v1/messages
```

Verification

Check Node.js:

```powershell
node --version
```

Check npm:

```powershell
npm --version
```

Check Claude Code:

```powershell
claude --version
```

Check the gateway:

```powershell
Get-NetTCPConnection -LocalPort 4000 -State Listen
```

Check model discovery:

```powershell
Invoke-RestMethod `
    -Uri "http://127.0.0.1:4000/v1/models" `
    -Headers @{ Authorization = "Bearer sk-local-claude-code" } |
    ConvertTo-Json -Depth 10
```

Expected model IDs:

```text
claude-glm-5-3-flash
claude-glm-4-7-flash
claude-deepseek-v4-flash
```

Manual Gateway Start

Run:

```powershell
node "$env:USERPROFILE\Desktop\Claude Code\system\gateway\router.mjs"
```

Expected output:

```text
==========================================
      CLAUDE CODE LOCAL MODEL GATEWAY
==========================================

Listening: http://127.0.0.1:4000
```

Manual Startup Test

Run:

```powershell
cscript.exe "$env:USERPROFILE\Desktop\Claude Code\system\startup\start-hidden.vbs"
```

The script starts Node.js without opening a visible console window.

Logs

The gateway uses:

```text
gateway.stdout.log
gateway.error.log
```

Located at:

```text
%USERPROFILE%\Desktop\Claude Code\system\gateway\
```

Check them with:

```powershell
Get-Content "$env:USERPROFILE\Desktop\Claude Code\system\gateway\gateway.stdout.log"
```

and:

```powershell
Get-Content "$env:USERPROFILE\Desktop\Claude Code\system\gateway\gateway.error.log"
```

Troubleshooting

Port 4000 is already in use

Find the process:

```powershell
Get-NetTCPConnection -LocalPort 4000 -State Listen |
    Select-Object LocalAddress, LocalPort, OwningProcess
```

Inspect it:

```powershell
Get-Process -Id <PID>
```

Do not stop an unrelated process just because it uses port 4000.

Router does not start

Run:

```powershell
node "$env:USERPROFILE\Desktop\Claude Code\system\gateway\router.mjs"
```

Check `.env`:

```powershell
Test-Path "$env:USERPROFILE\Desktop\Claude Code\system\gateway\.env"
```

Expected:

```text
True
```

Models do not appear in `/model`

Check the gateway:

```powershell
Invoke-RestMethod `
    -Uri "http://127.0.0.1:4000/v1/models" `
    -Headers @{ Authorization = "Bearer sk-local-claude-code" } |
    ConvertTo-Json -Depth 10
```

Then inspect Claude Code settings:

```powershell
Get-Content "$env:USERPROFILE\.claude\settings.json" -Raw |
    ConvertFrom-Json |
    ConvertTo-Json -Depth 20
```

The model picker should contain:

```text
claude-glm-5-3-flash
claude-glm-4-7-flash
claude-deepseek-v4-flash
```

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

Never paste the actual values into support requests.

Upstream temporary errors

The gateway retries temporary upstream errors including:

```text
429
500
502
503
529
```

If an upstream provider is temporarily overloaded, the gateway may retry the request automatically.

Security

The gateway binds to:

```text
127.0.0.1:4000
```

It is intended for local use.

Do not expose port 4000 directly to the public internet.

Never publish:

```text
gateway/.env
```

Repository

```text
https://github.com/Olh2012ooo/claude-code-local-gateway
```

Recreation Process

```text
1. Install or verify Node.js
2. Install or verify Claude Code
3. Clone or copy the repository
4. Run install.ps1
5. Enter the Z.AI API key
6. Enter the DeepSeek API key
7. Installer creates the local .env
8. Installer configures Claude Code
9. Installer configures Windows Startup
10. Installer starts the gateway
11. Installer verifies /v1/models
12. Start Claude Code
13. Use /model
```

===== startup/start-hidden.vbs =====

Set WShell = CreateObject("WScript.Shell")

Desktop = WShell.SpecialFolders("Desktop")
Router = Desktop & "\Claude Code\system\gateway\router.mjs"

WShell.Run "node.exe """ & Router & """", 0, False

===== .gitignore =====

Secrets

.env
.env.*
!.env.example

Local configuration

.claude/

Logs

*.log

Node

node_modules/

Windows

Thumbs.db
Desktop.ini

Editors

.vscode/
.idea/

===== .gitattributes =====

*.ps1 text eol=crlf
*.vbs text eol=crlf
*.mjs text eol=lf
*.md text eol=lf
*.json text eol=lf
*.example text eol=lf
LICENSE text eol=lf

```
```
