$envFile = Join-Path $PSScriptRoot ".env"

if (Test-Path $envFile) {
    Write-Host "Loading environment variables from .env file..."

    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()

        if ($line -and -not $line.StartsWith("#")) {

            $parts = $line -split '=', 2

            if ($parts.Count -eq 2) {

                $key = $parts[0].Trim()
                $value = $parts[1].Trim()

                [Environment]::SetEnvironmentVariable($key, $value, "Process")

                Write-Host "  Loaded $key"
            }
        }
    }

    Write-Host ""
}
else {
    Write-Host "Warning: .env file not found at $envFile"
    Write-Host ""
}