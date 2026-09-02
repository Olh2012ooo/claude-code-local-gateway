# Claude Code Local Model Gateway

A lightweight local Anthropic-compatible gateway for routing Claude Code requests to multiple AI providers.

The gateway runs locally on:

```text
http://127.0.0.1:4000
```

It maps Claude Code model aliases to provider-specific model IDs.

## Supported Models

| Claude Code Alias          | Provider | Upstream Model      |
| -------------------------- | -------- | ------------------- |
| `claude-glm-5-3-flash`     | Z.AI     | `glm-5.3-flash`     |
| `claude-glm-4-7-flash`     | Z.AI     | `glm-4.7-flash`     |
| `claude-deepseek-v4-flash` | DeepSeek | `deepseek-v4-flash` |

The `claude-*` names are local gateway aliases. They are not Anthropic model IDs.

## Architecture

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

## Features

* Local-only gateway
* Anthropic-compatible `/v1/messages`
* Model discovery through `/v1/models`
* Three configurable model routes
* Streaming response support
* Automatic retries for temporary upstream failures
* Local API key storage through `.env`
* Automatic Windows startup
* Automatic Claude Code configuration
* Existing Claude Code settings are backed up before modification
* No API keys are stored in source files

## Requirements

* Windows 11
* Node.js 18 or newer
* npm
* Claude Code
* Z.AI API key
* DeepSeek API key

Git for Windows is recommended.

## Installation

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

The installer will:

1. Check the required files.
2. Ask for the Z.AI API key.
3. Ask for the DeepSeek API key.
4. Check Node.js and npm.
5. Install missing dependencies when possible.
6. Install Claude Code if required.
7. Copy the gateway files to the local system directory.
8. Create the local `.env` file.
9. Configure Claude Code.
10. Configure Windows Startup.
11. Start the gateway.
12. Verify all three configured models.

## Local Directory Structure

The installer creates:

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

## Model Switching

Inside Claude Code, run:

```text
/model
```

The configured model picker exposes:

```text
GLM-5.3-Flash
GLM-4.7-Flash
DeepSeek V4 Flash
```

The default model is:

```text
claude-glm-5-3-flash
```

## Routing

### GLM-5.3-Flash

```text
Claude Code
    |
    v
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

### GLM-4.7-Flash

```text
Claude Code
    |
    v
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

### DeepSeek V4 Flash

```text
Claude Code
    |
    v
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

## Security

The gateway listens only on:

```text
127.0.0.1:4000
```

It is designed for local use and should not be exposed directly to the public internet.

Provider API keys are stored locally in:

```text
%USERPROFILE%\Desktop\Claude Code\system\gateway\.env
```

The `.env` file is excluded from Git by `.gitignore`.

Never commit or publish:

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

## Testing

Check Node.js:

```powershell
node --version
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

Expected models:

```text
claude-glm-5-3-flash
claude-glm-4-7-flash
claude-deepseek-v4-flash
```

## Manual Gateway Start

For troubleshooting:

```powershell
node "$env:USERPROFILE\Desktop\Claude Code\system\gateway\router.mjs"
```

Expected output includes:

```text
Listening: http://127.0.0.1:4000
```

## Logs

The installer creates separate gateway logs:

```text
gateway.stdout.log
gateway.error.log
```

Located in:

```text
%USERPROFILE%\Desktop\Claude Code\system\gateway\
```

## Automatic Startup

The installer creates:

```text
%USERPROFILE%\Desktop\Claude Code\system\startup\start-hidden.vbs
```

and copies it to:

```text
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\
```

The gateway therefore starts automatically when the Windows user signs in.

## License

This project is licensed under the MIT License.

See:

```text
LICENSE
```

## Repository

```text
https://github.com/Olh2012ooo/claude-code-local-gateway
```
