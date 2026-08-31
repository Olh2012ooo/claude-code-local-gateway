#requires -Version 5.1

$ErrorActionPreference = "Stop"

# ============================================================
# Claude Code Local Model Gateway Installer
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

$StartupFile = Join-Path $WindowsStartup "claude-code-gateway.vbs"

$LocalEnv = Join-Path $LocalGateway ".env"

function Write-Header {
    param([string]$Text)

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " $Text" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-CommandExists {
    param([string]$Command)

    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-SecureInput {
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

Write-Header "CLAUDE CODE LOCAL MODEL GATEWAY INSTALLER"

Write-Host "Source:"
Write-Host "  $SourceRoot"

Write-Host ""
Write-Host "Installation:"
Write-Host "  $LocalSystem"

# ============================================================
# 1. Kontroller source
# ============================================================

Write-Header "1/8 - KONTROLLERER INSTALLASJONSFILER"

$RequiredFiles = @(
    "gateway\router.mjs",
    "gateway\.env.example"
)

foreach ($File in $RequiredFiles) {
    $FullPath = Join-Path $SourceRoot $File

    if (-not (Test-Path $FullPath)) {
        throw "Mangler nødvendig fil: $FullPath"
    }

    Write-Host "OK  $File" -ForegroundColor Green
}

# ============================================================
# 2. API keys
# ============================================================

Write-Header "2/8 - API KEYS"

Write-Host "API-nøklene lagres lokalt i:"
Write-Host "  $LocalEnv"
Write-Host ""
Write-Host "Inputfeltet skjuler nøklene mens du skriver."
Write-Host ""

$ZaiKey = Get-SecureInput "Z.AI API key"
$DeepSeekKey = Get-SecureInput "DeepSeek API key"

if ([string]::IsNullOrWhiteSpace($ZaiKey)) {
    throw "Z.AI API key kan ikke være tom."
}

if ([string]::IsNullOrWhiteSpace($DeepSeekKey)) {
    throw "DeepSeek API key kan ikke være tom."
}

# ============================================================
# 3. Node.js
# ============================================================

Write-Header "3/8 - NODE.JS"

if (Test-CommandExists "node") {
    Write-Host "Node.js er allerede installert:" -ForegroundColor Green
    node --version
}
else {
    Write-Host "Node.js ble ikke funnet."

    if (Test-CommandExists "winget") {
        Write-Host "Installerer Node.js LTS med winget..."

        winget install `
            --id OpenJS.NodeJS.LTS `
            --exact `
            --accept-package-agreements `
            --accept-source-agreements
    }
    else {
        throw "Node.js mangler og winget finnes ikke. Installer Node.js manuelt og kjør install.ps1 på nytt."
    }

    Write-Host ""
    Write-Host "Lukk PowerShell og åpne et nytt PowerShell-vindu etter Node-installasjonen."
    Write-Host "Kjør deretter install.ps1 på nytt."
    exit 0
}

if (-not (Test-CommandExists "npm")) {
    throw "npm ble ikke funnet. Kontroller Node.js-installasjonen."
}

Write-Host "npm:"
npm --version

# ============================================================
# 4. Claude Code
# ============================================================

Write-Header "4/8 - CLAUDE CODE"

if (Test-CommandExists "claude") {
    Write-Host "Claude Code er allerede installert:" -ForegroundColor Green
    claude --version
}
else {
    Write-Host "Claude Code ble ikke funnet."
    Write-Host "Installerer..."

    npm config set allow-scripts=@anthropic-ai/claude-code --location=user

    npm install -g @anthropic-ai/claude-code

    Write-Host ""

    if (-not (Test-CommandExists "claude")) {
        throw "Claude Code ble installert, men kommandoen 'claude' ble ikke funnet. Åpne et nytt PowerShell-vindu og kjør install.ps1 på nytt."
    }

    claude --version
}

# ============================================================
# 5. Kopier systemet lokalt
# ============================================================

Write-Header "5/8 - INSTALLERER SYSTEMET"

New-Item -ItemType Directory -Path $LocalSystem -Force | Out-Null
New-Item -ItemType Directory -Path $LocalGateway -Force | Out-Null
New-Item -ItemType Directory -Path $LocalStartup -Force | Out-Null

# Kopier alle systemfiler unntatt .env
Get-ChildItem -Path $SourceRoot -Force |
    Where-Object {
        $_.Name -notin @(".env", ".git", "install.ps1")
    } |
    ForEach-Object {
        Copy-Item `
            -Path $_.FullName `
            -Destination (Join-Path $LocalSystem $_.Name) `
            -Recurse `
            -Force
    }

# Kopier installereren separat
Copy-Item `
    -Path (Join-Path $SourceRoot "install.ps1") `
    -Destination (Join-Path $LocalSystem "install.ps1") `
    -Force

Write-Host "Systemet er kopiert til:"
Write-Host "  $LocalSystem" -ForegroundColor Green

# ============================================================
# 6. Opprett .env
# ============================================================

Write-Header "6/8 - OPPRETTER API-KONFIGURASJON"

if (Test-Path $LocalEnv) {
    $BackupEnv = "$LocalEnv.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    Copy-Item $LocalEnv $BackupEnv -Force

    Write-Host "Eksisterende .env ble sikkerhetskopiert:"
    Write-Host "  $BackupEnv" -ForegroundColor Yellow
}

@"
ZAI_API_KEY=$ZaiKey
DEEPSEEK_API_KEY=$DeepSeekKey
"@ | Set-Content `
    -Path $LocalEnv `
    -Encoding UTF8

Write-Host ".env opprettet." -ForegroundColor Green

# ============================================================
# 7. Claude Code settings
# ============================================================

Write-Header "7/8 - KONFIGURERER CLAUDE CODE"

New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null

if (Test-Path $ClaudeSettings) {

    $SettingsBackup = "$ClaudeSettings.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    Copy-Item `
        $ClaudeSettings `
        $SettingsBackup `
        -Force

    Write-Host "Eksisterende settings er sikkerhetskopiert:"
    Write-Host "  $SettingsBackup" -ForegroundColor Yellow

    try {
        $Settings = Get-Content `
            $ClaudeSettings `
            -Raw |
            ConvertFrom-Json
    }
    catch {
        throw "Eksisterende Claude Code settings.json er ugyldig JSON. Backup finnes på $SettingsBackup"
    }
}
else {
    $Settings = [PSCustomObject]@{}
}

if (-not ($Settings.PSObject.Properties.Name -contains "env")) {
    $Settings | Add-Member `
        -MemberType NoteProperty `
        -Name env `
        -Value ([PSCustomObject]@{})
}

$Settings.env | Add-Member `
    -MemberType NoteProperty `
    -Name ANTHROPIC_BASE_URL `
    -Value "http://127.0.0.1:4000" `
    -Force

$Settings.env | Add-Member `
    -MemberType NoteProperty `
    -Name ANTHROPIC_AUTH_TOKEN `
    -Value "sk-local-claude-code" `
    -Force

$Settings.env | Add-Member `
    -MemberType NoteProperty `
    -Name CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY `
    -Value "1" `
    -Force

$Settings.env | Add-Member `
    -MemberType NoteProperty `
    -Name CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT `
    -Value "1" `
    -Force

$Settings |
    ConvertTo-Json -Depth 20 |
    Set-Content `
        -Path $ClaudeSettings `
        -Encoding UTF8

Write-Host "Claude Code er konfigurert." -ForegroundColor Green

# ============================================================
# Startup VBS
# ============================================================

$InstalledRouter = Join-Path $LocalGateway "router.mjs"

@"
Set WShell = CreateObject("WScript.Shell")

Router = "$InstalledRouter"

WShell.Run "node.exe """ & Router & """", 0, False
"@ | Set-Content `
    -Path (Join-Path $LocalStartup "start-hidden.vbs") `
    -Encoding ASCII

Copy-Item `
    -Path (Join-Path $LocalStartup "start-hidden.vbs") `
    -Destination $StartupFile `
    -Force

# ============================================================
# 8. Start gateway
# ============================================================

Write-Header "8/8 - STARTER GATEWAY"

# Stopp eventuell gammel gateway på port 4000
$Existing = Get-NetTCPConnection `
    -LocalPort 4000 `
    -State Listen `
    -ErrorAction SilentlyContinue

if ($Existing) {
    foreach ($Connection in $Existing) {
        try {
            Stop-Process `
                -Id $Connection.OwningProcess `
                -Force `
                -ErrorAction SilentlyContinue
        }
        catch {
        }
    }

    Start-Sleep -Seconds 1
}

# Start router skjult
cscript.exe `
    (Join-Path $LocalStartup "start-hidden.vbs") |
    Out-Null

Start-Sleep -Seconds 2

# ============================================================
# Verifisering
# ============================================================

Write-Header "INSTALLASJON FERDIG"

Write-Host "Gateway-status:"
$Connection = Get-NetTCPConnection `
    -LocalPort 4000 `
    -State Listen `
    -ErrorAction SilentlyContinue

if ($Connection) {
    Write-Host "OK - Gateway kjører på 127.0.0.1:4000" -ForegroundColor Green
}
else {
    Write-Host "FEIL - Gateway kjører ikke." -ForegroundColor Red
    Write-Host ""
    Write-Host "Start den manuelt med:"
    Write-Host "node `"$LocalGateway\router.mjs`""
    exit 1
}

Write-Host ""
Write-Host "Tester modell-discovery..."

try {
    $Models = Invoke-RestMethod `
        -Uri "http://127.0.0.1:4000/v1/models" `
        -Headers @{
            Authorization = "Bearer sk-local-claude-code"
        }

    foreach ($Model in $Models.data) {
        Write-Host "OK - $($Model.id)" -ForegroundColor Green
    }
}
catch {
    Write-Host "FEIL - Kunne ikke hente modeller." -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host " INSTALLASJONEN ER FERDIG" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Installerte filer:"
Write-Host "  $LocalSystem"

Write-Host ""
Write-Host "Claude Code settings:"
Write-Host "  $ClaudeSettings"

Write-Host ""
Write-Host "Windows Startup:"
Write-Host "  $StartupFile"

Write-Host ""
Write-Host "Start Claude Code med:"
Write-Host "  claude" -ForegroundColor Cyan

Write-Host ""
Write-Host "Bytt modell med:"
Write-Host "  /model" -ForegroundColor Cyan

Write-Host ""
Write-Host "Modeller:"
Write-Host "  claude-glm-5-3-flash"
Write-Host "  claude-deepseek-v4-flash"

Write-Host ""
Write-Host "API-nøklene dine ble ikke skrevet til terminalen eller README/SETUP."
Write-Host ""