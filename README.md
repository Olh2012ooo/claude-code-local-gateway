Claude Code Local Model Gateway

A lightweight local Anthropic-compatible gateway for using multiple AI providers from Claude Code.

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

Claude Code sends Anthropic-compatible requests to the local gateway.

The gateway identifies the selected model and forwards the request directly to the correct provider.

## Switching Models

Inside Claude Code:

```text
/model
```

Available models:

```text
claude-glm-5-3-flash
claude-glm-4-7-flash
claude-deepseek-v4-flash
```

Models can be switched during an existing Claude Code session.

Routing

GLM-5.3-Flash

```text
claude-glm-5-3-flash
        ↓
Z.AI
        ↓
glm-5.3-flash
```

### GLM-4.7-Flash

```text
claude-glm-4-7-flash
        ↓
Z.AI
        ↓
glm-4.7-flash
```

DeepSeek V4 Flash

```text
claude-deepseek-v4-flash
        ↓
DeepSeek
        ↓
deepseek-v4-flash
```

Features

* Local-only gateway
* Anthropic-compatible `/v1/messages`
* `/v1/models` model discovery
* GLM-5.3-Flash via Z.AI
* GLM-4.7-Flash via Z.AI
* DeepSeek V4 Flash via DeepSeek
* Streaming response forwarding
* Automatic Windows startup
* No third-party gateway required
* API keys remain local

Requirements

* Windows 11
* Node.js 18+
* Claude Code
* Z.AI API key
* DeepSeek API key

Directory Structure

```text
Claude Code/
├── projekter/
│   ├── project-1/
│   ├── project-2/
│   └── ...
│
└── system/
    ├── gateway/
    │   ├── router.mjs
    │   ├── .env
    │   └── .env.example
    │
    ├── startup/
    │   └── start-hidden.vbs
    │
    ├── install.ps1
    ├── README.md
    ├── SETUP.md
    ├── LICENSE
    └── .gitignore
```

Security

API keys are stored locally in:

```text
system/gateway/.env
```

Never commit `.env` to GitHub.

The gateway listens only on:

```text
127.0.0.1:4000
```

It is intended for local use and should not be exposed to the public internet.

Automatic Startup

Windows starts:

```text
system/startup/start-hidden.vbs
```

at user login.

The startup script launches:

```text
system/gateway/router.mjs
```

hidden in the background.

Installation

For a complete installation and recreation guide, see:

```text
SETUP.md
```

For automatic installation on a new Windows machine:

```powershell
powershell -ExecutionPolicy Bypass -File ".\install.ps1"
```

The installer:

1. Checks the required files.
2. Requests the Z.AI API key.
3. Requests the DeepSeek API key.
4. Installs Claude Code if necessary.
5. Copies the system locally.
6. Creates the `.env` file.
7. Configures Claude Code.
8. Installs the Windows startup script.
9. Starts the gateway.
10. Verifies model discovery.

## Testing

Check whether the gateway is running:

```powershell
Get-NetTCPConnection -LocalPort 4000 -State Listen
```

Check available models:

```powershell
Invoke-RestMethod `
    -Uri "http://127.0.0.1:4000/v1/models" `
    -Headers @{ Authorization = "Bearer sk-local-claude-code" } |
    ConvertTo-Json -Depth 10
```

Expected:

```text
claude-glm-5-3-flash
claude-glm-4-7-flash
claude-deepseek-v4-flash
```

Design

The gateway intentionally stays small.

Claude Code handles:

* sessions
* context
* tools
* agents
* model selection
* conversation state

The gateway handles:

* model routing
* provider selection
* request forwarding
* response forwarding
* model discovery

The core flow is:

```text
Claude Code
    ↓
Local Gateway
    ↓
Identify Model
    ↓
Select Provider
    ↓
Forward Request
    ↓
Forward Response
```

License

MIT

