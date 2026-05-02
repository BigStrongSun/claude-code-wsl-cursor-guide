param(
    [ValidateSet("status", "enable", "disable")]
    [string]$Mode = "status",

    [string]$CursorSettingsPath = (Join-Path $env:APPDATA "Cursor\User\settings.json"),

    [string]$ClaudeConfigDir = (Join-Path $env:USERPROFILE ".claude"),

    [switch]$NoBackup
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Web.Extensions
$script:JsonSerializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer

function New-EmptyJsonObject {
    return [System.Collections.Generic.Dictionary[string, object]]::new()
}

function Read-JsonObject {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return New-EmptyJsonObject
    }

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return New-EmptyJsonObject
    }

    try {
        $parsed = $script:JsonSerializer.DeserializeObject($raw)
    }
    catch {
        throw "Failed to parse JSON file '$Path'. Remove comments or trailing commas first. $($_.Exception.Message)"
    }

    if ($parsed -isnot [System.Collections.IDictionary]) {
        throw "JSON file '$Path' must contain an object at the top level."
    }

    return $parsed
}

function Save-JsonObject {
    param(
        [string]$Path,
        [object]$Object
    )

    $directory = Split-Path -Parent $Path
    if ($directory) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }

    if ((Test-Path -LiteralPath $Path) -and -not $NoBackup) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        Copy-Item -LiteralPath $Path -Destination "$Path.bak-$timestamp" -Force
    }

    $json = $script:JsonSerializer.Serialize($Object)
    Set-Content -LiteralPath $Path -Value $json -Encoding UTF8
}

function Set-JsonProperty {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Value
    )

    if ($Object.ContainsKey($Name)) {
        $Object[$Name] = $Value
    }
    else {
        $Object.Add($Name, $Value)
    }
}

function Remove-JsonProperty {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -ne $Object -and $Object.ContainsKey($Name)) {
        $Object.Remove($Name) | Out-Null
    }
}

function Get-JsonPropertyValue {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -ne $Object -and $Object.ContainsKey($Name)) {
        return $Object[$Name]
    }

    return $null
}

function Ensure-JsonObjectProperty {
    param(
        [object]$Object,
        [string]$Name
    )

    $value = Get-JsonPropertyValue -Object $Object -Name $Name
    if ($null -eq $value -or $value -isnot [System.Collections.IDictionary]) {
        $value = New-EmptyJsonObject
        Set-JsonProperty -Object $Object -Name $Name -Value $value
    }

    return $value
}

function Test-ObjectHasNoProperties {
    param([object]$Object)
    return ($null -eq $Object -or $Object.Count -eq 0)
}

$claudeSettingsPath = Join-Path $ClaudeConfigDir "settings.json"

$cursorSettings = Read-JsonObject -Path $CursorSettingsPath
$claudeSettings = Read-JsonObject -Path $claudeSettingsPath

$cursorAllow = Get-JsonPropertyValue -Object $cursorSettings -Name "claudeCode.allowDangerouslySkipPermissions"
$cursorInitialMode = Get-JsonPropertyValue -Object $cursorSettings -Name "claudeCode.initialPermissionMode"
$claudePermissions = Get-JsonPropertyValue -Object $claudeSettings -Name "permissions"
$claudeDefaultMode = if ($null -ne $claudePermissions) {
    Get-JsonPropertyValue -Object $claudePermissions -Name "defaultMode"
} else {
    $null
}

if ($Mode -eq "status") {
    [pscustomobject]@{
        CursorSettingsPath = $CursorSettingsPath
        CursorAllowDangerouslySkipPermissions = $cursorAllow
        CursorInitialPermissionMode = $cursorInitialMode
        ClaudeSettingsPath = $claudeSettingsPath
        ClaudePermissionsDefaultMode = $claudeDefaultMode
    } | Format-List
    return
}

if ($Mode -eq "enable") {
    Set-JsonProperty -Object $cursorSettings -Name "claudeCode.allowDangerouslySkipPermissions" -Value $true
    Set-JsonProperty -Object $cursorSettings -Name "claudeCode.initialPermissionMode" -Value "bypassPermissions"

    $permissions = Ensure-JsonObjectProperty -Object $claudeSettings -Name "permissions"
    Set-JsonProperty -Object $permissions -Name "defaultMode" -Value "bypassPermissions"
}

if ($Mode -eq "disable") {
    Set-JsonProperty -Object $cursorSettings -Name "claudeCode.allowDangerouslySkipPermissions" -Value $false
    if ($cursorInitialMode -eq "bypassPermissions") {
        Remove-JsonProperty -Object $cursorSettings -Name "claudeCode.initialPermissionMode"
    }

    if ($null -ne $claudePermissions -and $claudeDefaultMode -eq "bypassPermissions") {
        Remove-JsonProperty -Object $claudePermissions -Name "defaultMode"
        if (Test-ObjectHasNoProperties -Object $claudePermissions) {
            Remove-JsonProperty -Object $claudeSettings -Name "permissions"
        }
    }
}

Save-JsonObject -Path $CursorSettingsPath -Object $cursorSettings
Save-JsonObject -Path $claudeSettingsPath -Object $claudeSettings

Write-Host "Claude Code bypass permissions mode: $Mode"
Write-Host "Updated Cursor settings: $CursorSettingsPath"
Write-Host "Updated Claude settings: $claudeSettingsPath"
