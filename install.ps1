#requires -Version 5.1

$ErrorActionPreference = "Stop"

# ============================================================
# Claude Code Local Model Gateway
# Portable Windows Installer
# ============================================================

$SourceRoot = $PSScriptRoot

$LocalRoot = Join-Path $env:USERPROFILE "Desktop\Claude Code"
$LocalSystem = Join-Path $LocalRoot "system"
$LocalGateway = Join-Path $LocalSystem "gateway"
$LocalStartup = Join-Path $LocalSystem "startup"

$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$ClaudeSettings = Join-Path $ClaudeDir "settings.json"

$WindowsStartup = Join-Path `
    $env:APPDATA `
    "Microsoft\Windows\Start Menu\Programs\Startup"

$StartupFile = Join-Path `
    $WindowsStartup `
    "claude-code-local-gateway.vbs"

$LocalEnv = Join-Path $LocalGateway ".env"

$GatewayStdoutLog = Join-Path $LocalGateway "gateway.stdout.log"
$GatewayStderrLog = Join-Path $LocalGateway "gateway.error.log"

$GatewayPort = 4000
$LocalToken = "sk-local-claude-code"

function Write-Header {
    param([string]$Text)

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " $Text" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Refresh-EnvironmentPath {
    $MachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")

    $env:Path = "$MachinePath;$UserPath"
}

function Test-CommandExists {
    param([string]$Command)

    return $null -ne (
        Get-Command $Command -ErrorAction SilentlyContinue
    )
}

function Get-SecureValue {
    param([string]$Prompt)

    $secure = Read-Host $Prompt -AsSecureString

    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)

    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Content
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        $utf8NoBom
    )
}

function Wait-ForPort {
    param(
        [int]$Port,
        [int]$TimeoutSeconds = 10
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $deadline) {

        $connection = Get-NetTCPConnection `
            -LocalPort $Port `
            -State Listen `
            -ErrorAction SilentlyContinue

        if ($connection) {
            return $true
        }

        Start-Sleep -Milliseconds 500
    }

    return $false
}

function Get-PortProcesses {
    param([int]$Port)

    return Get-NetTCPConnection `
        -LocalPort $Port `
        -State Listen `
        -ErrorAction SilentlyContinue
}

function Stop-ExistingGateway {
    param([string]$ExpectedRouterPath)

    $connections = @(Get-PortProcesses -Port $GatewayPort)

    if (-not $connections) {
        return
    }

    foreach ($connection in $connections) {

        $processId = $connection.OwningProcess

        if ($processId -eq 0) {
            throw "Port $GatewayPort is occupied by a system process."
        }

        $processInfo = Get-CimInstance `
            Win32_Process `
            -Filter "ProcessId = $processId" `
            -ErrorAction SilentlyContinue

        $commandLine = ""

        if ($processInfo) {
            $commandLine = [string]$processInfo.CommandLine
        }

        $normalizedCommandLine = $commandLine.ToLowerInvariant()
        $normalizedExpectedPath = $ExpectedRouterPath.ToLowerInvariant()

        if (
            $normalizedCommandLine.Contains("router.mjs") -and
            $normalizedCommandLine.Contains($normalizedExpectedPath)
        ) {

            Write-Host "Stopping existing local gateway process (PID $processId)..."

            Stop-Process `
                -Id $processId `
                -Force `
                -ErrorAction Stop

        }
        else {

            throw (
                "Port $GatewayPort is already in use by another process " +
                "(PID $processId). The installer will not stop it automatically."
            )
        }
    }

    Start-Sleep -Seconds 1
}

function Backup-File {
    param([string]$Path)

    if (-not (Test-Path $Path -PathType Leaf)) {
        return
    }

    $BackupPath = "$Path.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    Copy-Item `
        $Path `
        $BackupPath `
        -Force

    Write-Host "Backup created:"
    Write-Host "  $BackupPath" -ForegroundColor Yellow
}

function Assert-File {
    param([string]$Path)

    if (-not (Test-Path $Path -PathType Leaf)) {
        throw "Required file is missing: $Path"
    }
}

# ============================================================
# Start
# ============================================================

Write-Header "CLAUDE CODE LOCAL MODEL GATEWAY INSTALLER"

Write-Host "Source:"
Write-Host "  $SourceRoot"

Write-Host ""
Write-Host "Installation:"
Write-Host "  $LocalSystem"

# ============================================================
# 1. Validate installer files
# ============================================================

Write-Header "1/8 - CHECKING INSTALLATION FILES"

$RequiredFiles = @(
    "gateway\router.mjs",
    "gateway\.env.example",
    "startup\start-hidden.vbs",
    "install.ps1"
)

foreach ($RelativePath in $RequiredFiles) {

    $FullPath = Join-Path $SourceRoot $RelativePath

    Assert-File $FullPath

    Write-Host "OK  $RelativePath" -ForegroundColor Green
}

# ============================================================
# 2. API keys
# ============================================================

Write-Header "2/8 - API KEYS"

Write-Host "The API keys will be stored only in:"
Write-Host "  $LocalEnv"

Write-Host ""
Write-Host "Input is hidden while you type."
Write-Host ""

$ZaiKey = Get-SecureValue "Z.AI API key"
$DeepSeekKey = Get-SecureValue "DeepSeek API key"

if ([string]::IsNullOrWhiteSpace($ZaiKey)) {
    throw "Z.AI API key cannot be empty."
}

if ([string]::IsNullOrWhiteSpace($DeepSeekKey)) {
    throw "DeepSeek API key cannot be empty."
}

# ============================================================
# 3. Dependencies
# ============================================================

Write-Header "3/8 - CHECKING DEPENDENCIES"

Refresh-EnvironmentPath

# -------------------------
# Node.js
# -------------------------

if (-not (Test-CommandExists "node")) {

    Write-Host "Node.js was not found."

    if (Test-CommandExists "winget") {

        Write-Host "Installing Node.js LTS with winget..."

        winget install `
            --id OpenJS.NodeJS.LTS `
            --exact `
            --accept-package-agreements `
            --accept-source-agreements

        Refresh-EnvironmentPath
    }
    else {

        throw (
            "Node.js is missing and winget is unavailable. " +
            "Install Node.js 18+ and run the installer again."
        )
    }
}

if (-not (Test-CommandExists "node")) {

    throw (
        "Node.js is still unavailable. " +
        "Open a new PowerShell window and run the installer again."
    )
}

Write-Host "Node.js:"
node --version

if (-not (Test-CommandExists "npm")) {
    throw "npm was not found."
}

Write-Host "npm:"
npm --version

# -------------------------
# Git
# -------------------------

if (-not (Test-CommandExists "git")) {

    Write-Host ""
    Write-Host "Git was not found."

    if (Test-CommandExists "winget") {

        Write-Host "Installing Git for Windows..."

        winget install `
            --id Git.Git `
            --exact `
            --accept-package-agreements `
            --accept-source-agreements

        Refresh-EnvironmentPath
    }
}

if (Test-CommandExists "git") {

    Write-Host "Git:"
    git --version

}
else {

    Write-Host `
        "WARNING: Git was not found. Git is recommended for Claude Code." `
        -ForegroundColor Yellow
}

# ============================================================
# 4. Claude Code
# ============================================================

Write-Header "4/8 - CHECKING CLAUDE CODE"

Refresh-EnvironmentPath

if (Test-CommandExists "claude") {

    Write-Host "Claude Code is already installed:" -ForegroundColor Green
    claude --version

}
else {

    Write-Host "Claude Code was not found."
    Write-Host "Installing Claude Code..."

    npm config set `
        allow-scripts=@anthropic-ai/claude-code `
        --location=user

    npm install -g @anthropic-ai/claude-code

    Refresh-EnvironmentPath

    if (-not (Test-CommandExists "claude")) {

        throw (
            "Claude Code was installed but the 'claude' command " +
            "is unavailable. Open a new PowerShell window and " +
            "run the installer again."
        )
    }

    Write-Host ""
    Write-Host "Claude Code:"
    claude --version
}

# ============================================================
# 5. Install system files
# ============================================================

Write-Header "5/8 - INSTALLING SYSTEM FILES"

New-Item `
    -ItemType Directory `
    -Path $LocalSystem `
    -Force |
    Out-Null

New-Item `
    -ItemType Directory `
    -Path $LocalGateway `
    -Force |
    Out-Null

New-Item `
    -ItemType Directory `
    -Path $LocalStartup `
    -Force |
    Out-Null

# Copy gateway files explicitly.
Copy-Item `
    (Join-Path $SourceRoot "gateway\router.mjs") `
    (Join-Path $LocalGateway "router.mjs") `
    -Force

Copy-Item `
    (Join-Path $SourceRoot "gateway\.env.example") `
    (Join-Path $LocalGateway ".env.example") `
    -Force

# Copy startup script.
Copy-Item `
    (Join-Path $SourceRoot "startup\start-hidden.vbs") `
    (Join-Path $LocalStartup "start-hidden.vbs") `
    -Force

# Copy documentation and repository files.
foreach ($File in @(
    "README.md",
    "SETUP.md",
    "LICENSE",
    ".gitignore",
    ".gitattributes"
)) {

    $SourceFile = Join-Path $SourceRoot $File
    $DestinationFile = Join-Path $LocalSystem $File

    if (Test-Path $SourceFile -PathType Leaf) {

        Copy-Item `
            $SourceFile `
            $DestinationFile `
            -Force
    }
}

# Keep a local copy of the installer.
Copy-Item `
    (Join-Path $SourceRoot "install.ps1") `
    (Join-Path $LocalSystem "install.ps1") `
    -Force

# Remove accidental nested gateway directory from older releases.
$NestedGateway = Join-Path $LocalGateway "gateway"

if (Test-Path $NestedGateway) {

    Write-Host "Removing obsolete nested gateway directory..."

    Remove-Item `
        $NestedGateway `
        -Recurse `
        -Force
}

# Verify critical files.
$CriticalFiles = @(
    (Join-Path $LocalGateway "router.mjs"),
    (Join-Path $LocalGateway ".env.example"),
    (Join-Path $LocalStartup "start-hidden.vbs")
)

foreach ($CriticalFile in $CriticalFiles) {
    Assert-File $CriticalFile
}

Write-Host "System files installed successfully." -ForegroundColor Green

# ============================================================
# 6. Create .env
# ============================================================

Write-Header "6/8 - CREATING LOCAL API CONFIGURATION"

Backup-File $LocalEnv

$EnvContent = @"
ZAI_API_KEY=$ZaiKey
DEEPSEEK_API_KEY=$DeepSeekKey
"@

Write-Utf8NoBom `
    -Path $LocalEnv `
    -Content $EnvContent

Write-Host ".env created successfully." -ForegroundColor Green

# Clear plaintext variables as soon as possible.
$ZaiKey = $null
$DeepSeekKey = $null

# ============================================================
# 7. Configure Claude Code and Windows Startup
# ============================================================

Write-Header "7/8 - CONFIGURING CLAUDE CODE"

New-Item `
    -ItemType Directory `
    -Path $ClaudeDir `
    -Force |
    Out-Null

# -------------------------
# settings.json
# -------------------------

if (Test-Path $ClaudeSettings -PathType Leaf) {

    Backup-File $ClaudeSettings

    try {

        $Settings = Get-Content `
            $ClaudeSettings `
            -Raw |
            ConvertFrom-Json

    }
    catch {

        throw (
            "Existing settings.json is invalid JSON. " +
            "A backup was created before the installer stopped."
        )
    }

}
else {

    $Settings = [PSCustomObject]@{}
}

# Ensure env object exists.
if (-not ($Settings.PSObject.Properties.Name -contains "env")) {

    $Settings |
        Add-Member `
            -MemberType NoteProperty `
            -Name env `
            -Value ([PSCustomObject]@{})
}

$Settings.env |
    Add-Member `
        -MemberType NoteProperty `
        -Name ANTHROPIC_BASE_URL `
        -Value "http://127.0.0.1:4000" `
        -Force

$Settings.env |
    Add-Member `
        -MemberType NoteProperty `
        -Name ANTHROPIC_AUTH_TOKEN `
        -Value $LocalToken `
        -Force

$Settings.env |
    Add-Member `
        -MemberType NoteProperty `
        -Name CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY `
        -Value "1" `
        -Force

$Settings.env |
    Add-Member `
        -MemberType NoteProperty `
        -Name CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT `
        -Value "1" `
        -Force

# Default model.
$Settings |
    Add-Member `
        -MemberType NoteProperty `
        -Name model `
        -Value "claude-glm-5-3-flash" `
        -Force

# Only expose gateway models in the model picker.
$ModelPicker = [PSCustomObject]@{
    replaceBuiltInOptions = $true

    options = @(
        [PSCustomObject]@{
            model = "claude-glm-5-3-flash"
            label = "GLM-5.3-Flash"
            description = "Z.AI"
        }

        [PSCustomObject]@{
            model = "claude-glm-4-7-flash"
            label = "GLM-4.7-Flash"
            description = "Z.AI"
        }

        [PSCustomObject]@{
            model = "claude-deepseek-v4-flash"
            label = "DeepSeek V4 Flash"
            description = "DeepSeek"
        }
    )
}

$Settings |
    Add-Member `
        -MemberType NoteProperty `
        -Name modelPicker `
        -Value $ModelPicker `
        -Force

Write-Utf8NoBom `
    -Path $ClaudeSettings `
    -Content (
        $Settings |
            ConvertTo-Json -Depth 20
    )

Write-Host "Claude Code settings configured." -ForegroundColor Green

# -------------------------
# Windows Startup
# -------------------------

$LocalStartupScript = Join-Path `
    $LocalStartup `
    "start-hidden.vbs"

if (Test-Path $LocalStartupScript -PathType Leaf) {

    New-Item `
        -ItemType Directory `
        -Path $WindowsStartup `
        -Force |
        Out-Null

    Copy-Item `
        $LocalStartupScript `
        $StartupFile `
        -Force

}
else {

    throw "Startup script was not installed correctly."
}

Write-Host "Windows Startup configured." -ForegroundColor Green

# ============================================================
# 8. Start and verify gateway
# ============================================================

Write-Header "8/8 - STARTING AND VERIFYING GATEWAY"

$RouterPath = Join-Path $LocalGateway "router.mjs"

Stop-ExistingGateway $RouterPath

foreach ($LogFile in @(
    $GatewayStdoutLog,
    $GatewayStderrLog
)) {

    if (Test-Path $LogFile) {
        Remove-Item $LogFile -Force -ErrorAction SilentlyContinue
    }
}

Start-Process `
    -FilePath "node.exe" `
    -ArgumentList "`"$RouterPath`"" `
    -WindowStyle Hidden `
    -RedirectStandardOutput $GatewayStdoutLog `
    -RedirectStandardError $GatewayStderrLog `
    -WorkingDirectory $LocalGateway

if (-not (Wait-ForPort -Port $GatewayPort -TimeoutSeconds 10)) {

    Write-Host ""
    Write-Host "Gateway failed to start." -ForegroundColor Red

    if (Test-Path $GatewayStdoutLog) {

        Write-Host ""
        Write-Host "Gateway output:"
        Get-Content $GatewayStdoutLog -ErrorAction SilentlyContinue
    }

    if (Test-Path $GatewayStderrLog) {

        Write-Host ""
        Write-Host "Gateway errors:"
        Get-Content $GatewayStderrLog -ErrorAction SilentlyContinue
    }

    throw "Gateway startup verification failed."
}

Write-Host `
    "Gateway is listening on 127.0.0.1:4000." `
    -ForegroundColor Green

# Test model discovery.
try {

    $Models = Invoke-RestMethod `
        -Uri "http://127.0.0.1:4000/v1/models" `
        -Headers @{
            Authorization = "Bearer $LocalToken"
        }

}
catch {

    throw (
        "Gateway started, but /v1/models could not be reached: " +
        $_.Exception.Message
    )
}

$ExpectedModels = @(
    "claude-glm-5-3-flash",
    "claude-glm-4-7-flash",
    "claude-deepseek-v4-flash"
)

$ReturnedModels = @(
    $Models.data |
        ForEach-Object { $_.id }
)

foreach ($ExpectedModel in $ExpectedModels) {

    if ($ReturnedModels -contains $ExpectedModel) {

        Write-Host `
            "OK  $ExpectedModel" `
            -ForegroundColor Green

    }
    else {

        throw (
            "Expected model was not returned by gateway: " +
            $ExpectedModel
        )
    }
}

# ============================================================
# Finished
# ============================================================

Write-Header "INSTALLATION COMPLETE"

Write-Host "Installed system:"
Write-Host "  $LocalSystem"

Write-Host ""
Write-Host "Claude Code settings:"
Write-Host "  $ClaudeSettings"

Write-Host ""
Write-Host "Windows Startup:"
Write-Host "  $StartupFile"

Write-Host ""
Write-Host "Gateway logs:"
Write-Host "  $GatewayStdoutLog"
Write-Host "  $GatewayStderrLog"

Write-Host ""
Write-Host "Available models:"
Write-Host "  GLM-5.3-Flash"
Write-Host "  GLM-4.7-Flash"
Write-Host "  DeepSeek V4 Flash"

Write-Host ""
Write-Host "Start Claude Code with:"
Write-Host "  claude"

Write-Host ""
Write-Host "Switch models with:"
Write-Host "  /model"

Write-Host ""
Write-Host "The gateway runs locally on:"
Write-Host "  http://127.0.0.1:4000"

Write-Host ""
Write-Host "Installation completed successfully." -ForegroundColor Green
Write-Host ""