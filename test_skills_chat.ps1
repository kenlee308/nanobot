$ErrorActionPreference = "Stop"

# Auto-detect paths - users should adjust these if needed
$python = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $python)) { $python = "python" }

$configPath = Join-Path $HOME ".nanobot\config.json"
$config = Get-Content $configPath | ConvertFrom-Json
$workspace = $config.agents.defaults.workspace
if ($null -eq $workspace) { $workspace = "~/.nanobot/workspace" }
$workspace = [System.IO.Path]::GetFullPath([System.Environment]::ExpandEnvironmentVariables($workspace.Replace("~", $HOME)))

$cwd = $PSScriptRoot

Set-Location $cwd

Write-Host "--- Testing Skills ---" -ForegroundColor Cyan

# 1. Todo Skill
Write-Host "`n[1/4] Testing Todo Skill..."
Write-Host "Running: add buy milk to todo list"
& $python -m nanobot agent -m "add buy milk to todo list" --session test_skills --no-logs | Out-Null
if (Test-Path "$workspace\TODO.md") {
    $content = Get-Content "$workspace\TODO.md" -Raw
    if ($content -match "buy milk") {
        Write-Host "PASS: TODO.md created and contains task." -ForegroundColor Green
    }
    else {
        Write-Host "FAIL: TODO.md exists but missing task. Content: $content" -ForegroundColor Red
    }
}
else {
    Write-Host "FAIL: TODO.md not created." -ForegroundColor Red
}

# 2. Notes Skill
Write-Host "`n[2/4] Testing Notes Skill..."
Write-Host "Running: create a note called skill_test with content verification complete"
& $python -m nanobot agent -m "create a note called skill_test with content verification complete" --session test_skills --no-logs | Out-Null
if (Test-Path "$workspace\notes\skill_test.md") {
    $content = Get-Content "$workspace\notes\skill_test.md" -Raw
    if ($content -match "verification complete") {
        Write-Host "PASS: Note created." -ForegroundColor Green
    }
    else {
        Write-Host "FAIL: Note exists but content mismatch. Content: $content" -ForegroundColor Red
    }
}
else {
    Write-Host "FAIL: Note file not found at $workspace\notes\skill_test.md" -ForegroundColor Red
}

# 3. Calculator Skill
Write-Host "`n[3/4] Testing Calculator Skill..."
Write-Host "Running: calculate 50 * 3"
$output = (& $python -m nanobot agent -m "calculate 50 * 3" --session test_skills --no-logs 2>&1) | Out-String
if ($output -match "150") {
    Write-Host "PASS: Calculator returned 150." -ForegroundColor Green
}
else {
    Write-Host "FAIL: Calculator output mismatch. Start of output:" -ForegroundColor Red
    Write-Host ($output | Select-Object -First 5) -ForegroundColor Gray
}

# 4. Clipboard Skill
Write-Host "`n[4/4] Testing Clipboard Skill..."
Write-Host "Running: copy 'clipboard_verification_success' to clipboard"
& $python -m nanobot agent -m "copy 'clipboard_verification_success' to clipboard" --session test_skills --no-logs | Out-Null
Start-Sleep -Seconds 1
$clip = Get-Clipboard
if ($clip -match "clipboard_verification_success") {
    Write-Host "PASS: Clipboard set successfully." -ForegroundColor Green
}
else {
    Write-Host "FAIL: Clipboard content mismatch. Got: '$clip'" -ForegroundColor Red
}

Write-Host "`n--- Test Complete ---" -ForegroundColor Cyan
