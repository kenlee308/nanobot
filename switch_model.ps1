# Enhanced Model Switcher - Queries available models from APIs
# For Gemini: Lists all available models from the API
# For Ollama: Lists locally installed models

Write-Host "=== NANOBOT MODEL SWITCHER ===" -ForegroundColor Cyan
Write-Host ""

$configPath = Join-Path $HOME ".nanobot\config.json"
$config = Get-Content $configPath | ConvertFrom-Json

Write-Host "Current Model: " -NoNewline -ForegroundColor Yellow
Write-Host $config.agents.defaults.model -ForegroundColor White
Write-Host ""

Write-Host "Select action:" -ForegroundColor Yellow
Write-Host "  1. Ollama (Local)" -ForegroundColor Gray
Write-Host "  2. Gemini API (Cloud)" -ForegroundColor Gray
Write-Host "  3. Toggle Draft Mode (Intercept every request)" -ForegroundColor Gray
Write-Host "  4. Run Detailed System Diagnostics" -ForegroundColor Gray
Write-Host "  5. Toggle RAG & Tools (Currently: $(if ($config.agents.defaults.disableTools) { 'DISABLED' } else { 'ENABLED' }))" -ForegroundColor Gray
Write-Host "  6. Toggle Hide JSON Mode (Currently: $(if ($config.agents.defaults.useNativeTools -eq $false) { 'ON' } else { 'OFF' }))" -ForegroundColor Gray
Write-Host "     (Turn ON for small models to fix '{}' response crash)" -ForegroundColor DarkGray
Write-Host "  7. Toggle Prompt Profile (Currently: $(if ($config.agents.defaults.promptProfile -eq 'Minimal') { 'MINIMAL' } else { 'FULL' }))" -ForegroundColor Gray
Write-Host "     (Use MINIMAL for very small context models)" -ForegroundColor DarkGray
Write-Host "  8. Clear All Chat Histories (PERMANENT)" -ForegroundColor Red
Write-Host "  9. Adjust Model Accuracy / Temperature (Currently: $(
    if ($config.agents.defaults.temperature -le 0.1) { 'PRECISE' }
    elseif ($config.agents.defaults.temperature -ge 1.0) { 'CREATIVE' }
    else { 'BALANCED' }
))" -ForegroundColor Gray
Write-Host "  10. Manage Skills (Enable/Disable)" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Enter choice (1-10)"

if ($choice -eq "1") {
    # Ollama - List local models
    Write-Host ""
    Write-Host "Fetching available Ollama models..." -ForegroundColor Cyan

    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -ErrorAction Stop
        $models = $response.models | Sort-Object name

        if ($models.Count -eq 0) {
            Write-Host "No Ollama models found. Pull a model first." -ForegroundColor Red
            exit
        }

        Write-Host ""
        Write-Host "Available Ollama Models:" -ForegroundColor Green
        for ($i = 0; $i -lt $models.Count; $i++) {
            $size = [math]::Round($models[$i].size / 1GB, 2)
            $n = $i + 1
            $mname = $models[$i].name
            Write-Host "  $n. $mname (${size}GB)" -ForegroundColor Gray
        }

        Write-Host ""
        $modelChoice = Read-Host "Select model number"
        $selectedModel = $models[[int]$modelChoice - 1].name

        # Query model info for context length
        Write-Host "Detecting context limit for $selectedModel..." -ForegroundColor Cyan
        $showResponse = Invoke-RestMethod -Uri "http://localhost:11434/api/show" -Method Post -Body (@{name = $selectedModel } | ConvertTo-Json)
        $limit = $showResponse.model_info."$($showResponse.details.family).context_length"
        if (-not $limit) { $limit = 8192 }

        Write-Host ""
        Write-Host "Context Length (maxTokens) - Max detected: $limit" -ForegroundColor Yellow
        Write-Host "  1. Default (8192)" -ForegroundColor Gray
        if ($limit -ge 16384) { Write-Host "  2. 16k" -ForegroundColor Gray }
        if ($limit -ge 32768) { Write-Host "  3. 32k" -ForegroundColor Gray }
        if ($limit -ge 65536) { Write-Host "  4. 64k" -ForegroundColor Gray }
        if ($limit -ge 128000) { Write-Host "  5. 128k" -ForegroundColor Gray }
        Write-Host "  6. Custom (Max: $limit)" -ForegroundColor Gray
        $ctxChoice = Read-Host "Select context length"
        
        $maxTokens = 8192
        if ($ctxChoice -eq "2" -and $limit -ge 16384) { $maxTokens = 16384 }
        elseif ($ctxChoice -eq "3" -and $limit -ge 32768) { $maxTokens = 32768 }
        elseif ($ctxChoice -eq "4" -and $limit -ge 65536) { $maxTokens = 65536 }
        elseif ($ctxChoice -eq "5" -and $limit -ge 128000) { $maxTokens = 128000 }
        elseif ($ctxChoice -eq "6") { 
            $maxTokens = [int](Read-Host "Enter custom context length")
            if ($maxTokens -gt $limit) {
                Write-Host "Warning: $maxTokens exceeds model limit of $limit. Setting to $limit." -ForegroundColor Yellow
                $maxTokens = $limit
            }
        }

        $config.agents.defaults.model = "ollama/$selectedModel"
        $config.agents.defaults.maxTokens = $maxTokens
        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath

        Write-Host ""
        Write-Host "Switched to: ollama/$selectedModel (Context: $maxTokens)" -ForegroundColor Green
    }
    catch {
        Write-Host "Error connecting to Ollama. Is it running?" -ForegroundColor Red
    }
}
elseif ($choice -eq "2") {
    # Gemini - Query available models from API
    Write-Host ""
    Write-Host "Enter your Gemini API key (or press Enter to keep existing):" -ForegroundColor Yellow
    $apiKey = Read-Host

    if ($apiKey) {
        $config.providers.gemini.apiKey = $apiKey
    }
    else {
        $apiKey = $config.providers.gemini.apiKey
    }

    if (-not $apiKey) {
        Write-Host "No API key provided. Cannot proceed." -ForegroundColor Red
        exit
    }

    Write-Host ""
    Write-Host "Fetching available Gemini models..." -ForegroundColor Cyan

    try {
        $url = "https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey"
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop

        # Filter for models that support generateContent
        $models = $response.models | Where-Object {
            $_.supportedGenerationMethods -contains "generateContent"
        } | Sort-Object name

        if ($models.Count -eq 0) {
            Write-Host "No Gemini models available. Check your API key." -ForegroundColor Red
            exit
        }

        Write-Host ""
        Write-Host "Available Gemini Models:" -ForegroundColor Green
        for ($i = 0; $i -lt $models.Count; $i++) {
            $mname = $models[$i].name -replace "^models/", ""
            $n = $i + (1)
            $limit = $models[$i].inputTokenLimit
            Write-Host "  $n. $mname (Max Token: $limit)" -ForegroundColor Gray
        }

        Write-Host ""
        $modelChoice = Read-Host "Select model number"
        $modelObj = $models[[int]$modelChoice - 1]
        $selectedModel = $modelObj.name -replace "^models/", ""
        $limit = $modelObj.inputTokenLimit

        Write-Host ""
        Write-Host "Context Length (maxTokens) - Max available: $limit" -ForegroundColor Yellow
        Write-Host "  1. Default (8192)" -ForegroundColor Gray
        if ($limit -ge 16384) { Write-Host "  2. 16k" -ForegroundColor Gray }
        if ($limit -ge 32768) { Write-Host "  3. 32k" -ForegroundColor Gray }
        if ($limit -ge 128000) { Write-Host "  4. 128k" -ForegroundColor Gray }
        if ($limit -ge 1000000) { Write-Host "  5. 1M" -ForegroundColor Gray }
        Write-Host "  6. Custom (Max: $limit)" -ForegroundColor Gray
        $ctxChoice = Read-Host "Select context length"
        
        $maxTokens = 8192
        if ($ctxChoice -eq "2" -and $limit -ge 16384) { $maxTokens = 16384 }
        elseif ($ctxChoice -eq "3" -and $limit -ge 32768) { $maxTokens = 32768 }
        elseif ($ctxChoice -eq "4" -and $limit -ge 128000) { $maxTokens = 128000 }
        elseif ($ctxChoice -eq "5" -and $limit -ge 1000000) { $maxTokens = 1000000 }
        elseif ($ctxChoice -eq "6") { 
            $maxTokens = [int](Read-Host "Enter custom context length")
            if ($maxTokens -gt $limit) {
                Write-Host "Warning: $maxTokens exceeds model limit of $limit. Setting to $limit." -ForegroundColor Yellow
                $maxTokens = $limit
            }
        }

        $config.agents.defaults.model = "gemini/$selectedModel"
        $config.agents.defaults.maxTokens = $maxTokens
        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath

        Write-Host ""
        Write-Host "Switched to: gemini/$selectedModel (Context: $maxTokens)" -ForegroundColor Green
    }
    catch {
        Write-Host "Error fetching Gemini models: $_" -ForegroundColor Red
    }
}
elseif ($choice -eq "3") {
    # Toggle Draft Mode
    # Handle missing property gracefully in PowerShell
    $current = $config.agents.defaults.draftMode
    if ($null -eq $current) { $current = $false }
    
    $newVal = -not $current
    
    if (-not $config.agents.defaults.PSObject.Properties['draftMode']) {
        $config.agents.defaults | Add-Member -MemberType NoteProperty -Name "draftMode" -Value $newVal
    }
    else {
        $config.agents.defaults.draftMode = $newVal
    }
    
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath
    
    $status = if ($config.agents.defaults.draftMode) { "ENABLED" } else { "DISABLED" }
    Write-Host ""
    Write-Host "Draft Mode is now: $status" -ForegroundColor Yellow
    Write-Host ""
    
    if ($status -eq "ENABLED") {
        Write-Host "In Draft Mode, Nanobot will save every prompt to 'draft_payload.json'" -ForegroundColor Gray
        Write-Host "for you to edit before sending it to the AI." -ForegroundColor Gray
    }
    
    exit
}
elseif ($choice -eq "4") {
    # Diagnostics
    Write-Host ""
    Write-Host "Running Detailed System Diagnostics..." -ForegroundColor Yellow
    
    $pythonCmd = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
    if (-not (Test-Path $pythonCmd)) { $pythonCmd = "python" }
    
    & $pythonCmd system_diagnostic.py
    
    Write-Host ""
    Write-Host "Diagnostics complete." -ForegroundColor Cyan
    Read-Host "Press Enter to return to menu"
    exit
}
elseif ($choice -eq "5") {
    # Toggle Tools
    $current = $config.agents.defaults.disableTools
    if ($null -eq $current) { $current = $false }
    
    $newVal = -not $current
    
    if (-not $config.agents.defaults.PSObject.Properties['disableTools']) {
        $config.agents.defaults | Add-Member -MemberType NoteProperty -Name "disableTools" -Value $newVal
    }
    else {
        $config.agents.defaults.disableTools = $newVal
    }
    
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath
    
    $status = if ($config.agents.defaults.disableTools) { "ON (Tools Disabled)" } else { "OFF (Tools Enabled)" }
    Write-Host ""
    Write-Host "Text-Only Mode is now: $status" -ForegroundColor Yellow
    Write-Host ""
    exit
}
elseif ($choice -eq "6") {
    # Toggle Native Tool Use
    $current = $config.agents.defaults.useNativeTools
    if ($null -eq $current) { $current = $true }
    
    $newVal = -not $current
    
    if (-not $config.agents.defaults.PSObject.Properties['useNativeTools']) {
        $config.agents.defaults | Add-Member -MemberType NoteProperty -Name "useNativeTools" -Value $newVal
    }
    else {
        $config.agents.defaults.useNativeTools = $newVal
    }
    
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath
    
    $status = if ($config.agents.defaults.useNativeTools -eq $false) { "ON" } else { "OFF" }
    Write-Host ""
    Write-Host "Hide JSON Mode is now: $status" -ForegroundColor Yellow
    Write-Host ""
    
    if ($status -eq "ON") {
        Write-Host "Tools will no longer be sent to the AI's native API." -ForegroundColor Gray
        Write-Host "Use [CALL: tool_name(args)] format in your prompt if the AI forgets how to call them." -ForegroundColor Gray
    }
    exit
}
elseif ($choice -eq "7") {
    # Toggle Profile
    $current = $config.agents.defaults.promptProfile
    if ($null -eq $current) { $current = "Full" }
    
    $workspace = $config.agents.defaults.workspace
    if ($null -eq $workspace) { $workspace = "~/.nanobot/workspace" }
    $wsPath = [System.IO.Path]::GetFullPath([System.Environment]::ExpandEnvironmentVariables($workspace.Replace("~", $HOME)))
    
    $files = @("AGENTS.md", "SOUL.md", "USER.md")
    
    if ($current -eq "Full") {
        $newVal = "Minimal"
        # Switch TO Minimal
        foreach ($f in $files) {
            $fullPath = Join-Path $wsPath $f
            $backPath = Join-Path $wsPath "$f.full"
            $miniPath = Join-Path $wsPath "minimal-$f"
            
            if (Test-Path $fullPath) {
                # Save current as full if not already saved
                Move-Item $fullPath $backPath -Force
            }
            if (Test-Path $miniPath) {
                Copy-Item $miniPath $fullPath -Force
            }
        }
    }
    else {
        $newVal = "Full"
        # Switch TO Full
        foreach ($f in $files) {
            $fullPath = Join-Path $wsPath $f
            $backPath = Join-Path $wsPath "$f.full"
            
            if (Test-Path $backPath) {
                Move-Item $backPath $fullPath -Force
            }
        }
    }
    
    if (-not $config.agents.defaults.PSObject.Properties['promptProfile']) {
        $config.agents.defaults | Add-Member -MemberType NoteProperty -Name "promptProfile" -Value $newVal
    }
    else {
        $config.agents.defaults.promptProfile = $newVal
    }
    
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath
    
    Write-Host ""
    Write-Host "Prompt Profile is now: $($newVal.ToUpper())" -ForegroundColor Yellow
    Write-Host "Bootstrap files in $wsPath have been updated." -ForegroundColor Gray
    exit
}
elseif ($choice -eq "8") {
    # Clear All Chat Histories
    Write-Host ""
    Write-Host "⚠️ WARNING: This will permanently delete ALL chat histories." -ForegroundColor Red
    $confirm = Read-Host "Are you sure? (y/N)"
    
    if ($confirm.Trim().ToLower() -eq "y") {
        $sessionDir = Join-Path $HOME ".nanobot\sessions"
        if (Test-Path $sessionDir) {
            Write-Host "Clearing all sessions in $sessionDir..." -ForegroundColor Cyan
            Remove-Item (Join-Path $sessionDir "*.jsonl") -Force -ErrorAction SilentlyContinue
            Write-Host "History cleared." -ForegroundColor Green
        }
        else {
            Write-Host "Session directory not found." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Operation cancelled." -ForegroundColor Gray
    }
    Write-Host ""
    exit
}
elseif ($choice -eq "9") {
    # Adjust Model Accuracy (Temperature)
    $current = $config.agents.defaults.temperature
    if ($null -eq $current) { $current = 0.7 }
    
    # Toggle logic: 0.1 -> 0.7 -> 1.2 -> 0.1
    $newVal = 0.7
    $label = "BALANCED"
    
    if ($current -ge 1.0) { 
        $newVal = 0.1
        $label = "PRECISE"
    }
    elseif ($current -le 0.1) {
        $newVal = 0.7
        $label = "BALANCED"
    }
    else {
        $newVal = 1.2
        $label = "CREATIVE"
    }

    if (-not $config.agents.defaults.PSObject.Properties['temperature']) {
        $config.agents.defaults | Add-Member -MemberType NoteProperty -Name "temperature" -Value $newVal
    }
    else {
        $config.agents.defaults.temperature = $newVal
    }
    
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath
    
    Write-Host ""
    Write-Host "Model Accuracy set to: $label (Temperature: $newVal)" -ForegroundColor Yellow
    Write-Host ""
    exit
}
elseif ($choice -eq "10") {
    # Manage Skills
    Write-Host ""
    Write-Host "Fetching available skills..." -ForegroundColor Cyan

    $pythonCmd = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
    if (-not (Test-Path $pythonCmd)) { $pythonCmd = "python" }
    
    # Get all available skills via Python
    $workspace = $config.agents.defaults.workspace
    if ($null -eq $workspace) { $workspace = "~/.nanobot/workspace" }
    $wsPath = [System.IO.Path]::GetFullPath([System.Environment]::ExpandEnvironmentVariables($workspace.Replace("~", $HOME)))
    
    $script = "from nanobot.agent.skills import SkillsLoader; from pathlib import Path; loader = SkillsLoader(Path(r'$wsPath')); print(','.join(sorted([s['name'] for s in loader.list_skills()])))"
    $availableSkillsStr = & $pythonCmd -c $script
    $availableSkills = $availableSkillsStr -split ","

    $disabled = $config.agents.defaults.disabledSkills
    if ($null -eq $disabled) { $disabled = @() }

    Write-Host ""
    Write-Host "Available Skills:" -ForegroundColor Green
    foreach ($skill in $availableSkills) {
        if ($skill) {
            $status = "ENABLED"
            $color = "Green"
            if ($disabled -contains $skill) {
                $status = "DISABLED"
                $color = "DarkGray"
            }
            Write-Host "  $skill - $status" -ForegroundColor $color
        }
    }

    Write-Host ""
    Write-Host "Enter skill name to toggle (or 'all-enable' / 'all-disable'):" -ForegroundColor Yellow
    $toToggle = Read-Host

    if ($toToggle -eq "all-enable") {
        $config.agents.defaults.disabledSkills = @()
        Write-Host "All skills enabled." -ForegroundColor Green
    }
    elseif ($toToggle -eq "all-disable") {
        $config.agents.defaults.disabledSkills = $availableSkills
        Write-Host "All skills disabled." -ForegroundColor Yellow
    }
    elseif ($availableSkills -contains $toToggle) {
        if ($disabled -contains $toToggle) {
            # Enable it
            $config.agents.defaults.disabledSkills = $disabled | Where-Object { $_ -ne $toToggle }
            Write-Host "$toToggle enabled." -ForegroundColor Green
        }
        else {
            # Disable it
            $config.agents.defaults.disabledSkills += $toToggle
            Write-Host "$toToggle disabled." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Skill '$toToggle' not found." -ForegroundColor Red
        exit
    }

    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath
    exit
}
else {
    Write-Host "Invalid choice" -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "Configuration updated!" -ForegroundColor Green
$testRun = Read-Host "Would you like to run a quick test? (y/n)"
if ($testRun -eq "y") {
    Write-Host ""
    Write-Host "Running test: 'hello'..." -ForegroundColor Cyan
    $testCmd = "& '" + (Join-Path $PSScriptRoot ".venv\Scripts\python.exe") + "' -m nanobot agent -m 'hello'"
    Invoke-Expression $testCmd
}

Write-Host ""
Write-Host "Done! You can use nanobot_chat.bat to start chatting." -ForegroundColor Gray
Write-Host ""
