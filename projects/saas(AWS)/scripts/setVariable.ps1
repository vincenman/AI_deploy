Get-Content "$PSScriptRoot\..\.env" | ForEach-Object {
    if ($_ -match '^(.+?)=(.+)$') {
        [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
    }
}

#check : Get-ChildItem Env:
