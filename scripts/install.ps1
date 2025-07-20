# Installation script for Razon Email Client
#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

# Load existing environment variables if available
$razonEnvFile = "$env:USERPROFILE\.razon_env.ps1"
if (Test-Path $razonEnvFile) {
    . $razonEnvFile
}

# Determine system architecture
$arch = if ([System.Environment]::Is64BitOperatingSystem) {
    if ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -eq [System.Runtime.InteropServices.Architecture]::Arm64) {
        "arm64"
    } else {
        "amd64"
    }
} else {
    Write-Error "32-bit systems are not supported"
    exit 1
}

# Define installation paths
$installDir = "$env:USERPROFILE\.razon"
$exePath = "$installDir\razon.exe"
$binUrl = "https://github.com/cli-packages/razon-mailer/releases/latest/download/razon-windows-$arch.exe"

Write-Host "Installing Razon Email Client..." -ForegroundColor Cyan
Write-Host "Architecture: $arch"

# Remove existing installation if present
if (Test-Path $installDir) {
    Write-Host "Removing existing installation..." -ForegroundColor Yellow
    Remove-Item -Path $installDir -Recurse -Force
}

# Create installation directory
Write-Host "Creating installation directory..."
New-Item -ItemType Directory -Path $installDir -Force | Out-Null

try {
    # Download the binary
    Write-Host "Downloading binary for $arch architecture..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $binUrl -OutFile $exePath -UseBasicParsing

    # Download Puppeteer Chromium for Windows
    Write-Host "Checking Chromium browser for email automation..." -ForegroundColor Cyan
    
    # Create chromium subdirectory
    $chromiumDir = "$installDir\chromium"
    New-Item -ItemType Directory -Path $chromiumDir -Force | Out-Null
    
    # Function to get latest Chromium version
    function Get-LatestChromiumVersion {
        $apiUrl = "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions.json"
        
        try {
            $response = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
            return $response.channels.Stable.version
        }
        catch {
            Write-Warning "Failed to fetch latest Chromium version, using fallback"
            return "121.0.6167.85"
        }
    }
    
    # Function to get current installed Chromium version
    function Get-InstalledChromiumVersion {
        if ($env:JM_BROWSER_PATH -and (Test-Path $env:JM_BROWSER_PATH)) {
            try {
                $versionOutput = & $env:JM_BROWSER_PATH --version 2>$null
                if ($versionOutput -match '(\d+\.\d+\.\d+\.\d+)') {
                    return $matches[1]
                }
            }
            catch {
                # Ignore errors when getting version
            }
        }
        return $null
    }
    
    # Check if we need to download Chromium
    $latestVersion = Get-LatestChromiumVersion
    $installedVersion = Get-InstalledChromiumVersion
    $skipChromiumDownload = $false
    
    if ($env:JM_BROWSER_PATH -and (Test-Path $env:JM_BROWSER_PATH) -and $installedVersion) {
        Write-Host "Found existing Chromium installation: $env:JM_BROWSER_PATH"
        Write-Host "Installed version: $installedVersion"
        Write-Host "Latest version: $latestVersion"
        
        if ($installedVersion -eq $latestVersion) {
            Write-Host "Chromium is already up-to-date! Skipping download." -ForegroundColor Green
            $skipChromiumDownload = $true
        } else {
            Write-Host "Chromium version mismatch. Updating to latest version..." -ForegroundColor Yellow
            $skipChromiumDownload = $false
        }
    } else {
        Write-Host "No existing Chromium found. Downloading latest version..." -ForegroundColor Cyan
        $skipChromiumDownload = $false
    }
    
    # Function to download and extract Chromium
    function Download-Chromium {
        param($Architecture, $Version)
        
        Write-Host "Using Chromium version: $Version" -ForegroundColor Yellow
        
        $chromiumUrl = switch ($Architecture) {
            "amd64" { "https://storage.googleapis.com/chrome-for-testing-public/$Version/win64/chrome-win64.zip" }
            "arm64" { "https://storage.googleapis.com/chrome-for-testing-public/$Version/win64/chrome-win64.zip" } # Fallback to x64
            default { 
                Write-Warning "No Chromium download available for architecture: $Architecture"
                return $false
            }
        }
        
        $chromiumZip = "$chromiumDir\chromium.zip"
        
        try {
            # Download Chromium
            Write-Host "Downloading Chromium from: $chromiumUrl"
            Invoke-WebRequest -Uri $chromiumUrl -OutFile $chromiumZip -UseBasicParsing
            
            # Extract Chromium
            Write-Host "Extracting Chromium..."
            Expand-Archive -Path $chromiumZip -DestinationPath $chromiumDir -Force
            Remove-Item $chromiumZip
            
            # Find Chrome executable and create a shortcut/symlink
            $chromeExe = Get-ChildItem -Path $chromiumDir -Name "chrome.exe" -Recurse | Select-Object -First 1
            if ($chromeExe) {
                $chromeFullPath = Join-Path $chromiumDir $chromeExe
                $chromeSymlink = "$chromiumDir\chrome.exe"
                
                # Create a copy/symlink to chrome.exe in the root chromium directory
                if (Test-Path $chromeFullPath) {
                    Copy-Item $chromeFullPath $chromeSymlink -Force
                    Write-Host "Chromium downloaded successfully!" -ForegroundColor Green
                    return $chromeSymlink
                }
            }
            
            Write-Warning "Chrome executable not found after extraction"
            return $false
        }
        catch {
            Write-Warning "Failed to download Chromium: $_"
            return $false
        }
    }
    
    # Download Chromium for the current architecture only if needed
    $chromiumPath = $null
    if (-not $skipChromiumDownload) {
        $chromiumPath = Download-Chromium -Architecture $arch -Version $latestVersion
    }
    
    # Set environment variable for Chromium path
    $finalChromiumPath = "$chromiumDir\chrome.exe"
    if (Test-Path $finalChromiumPath) {
        $razonEnvFile = "$env:USERPROFILE\.razon_env.ps1"
        "`$env:JM_BROWSER_PATH = `"$finalChromiumPath`"" | Out-File -FilePath $razonEnvFile -Encoding UTF8
        Write-Host "Chromium path configured: $finalChromiumPath" -ForegroundColor Green
        Write-Host "Note: Source $razonEnvFile in your PowerShell profile for persistent browser path" -ForegroundColor Yellow
        
        # Set for current session
        $env:JM_BROWSER_PATH = $finalChromiumPath
    } elseif ($env:JM_BROWSER_PATH -and (Test-Path $env:JM_BROWSER_PATH)) {
        Write-Host "Using existing Chromium installation: $env:JM_BROWSER_PATH" -ForegroundColor Green
    }

    # Add to User PATH if not already present
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$installDir*") {
        Write-Host "Adding to User PATH..." -ForegroundColor Yellow
        $newPath = if ($userPath) { "$userPath;$installDir" } else { $installDir }
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        $env:Path = "$env:Path;$installDir"
    }

    # Test the installation
    $env:Path = "$env:Path;$installDir"
    if (Get-Command razon -ErrorAction SilentlyContinue) {
        Write-Host "`nInstallation successful!" -ForegroundColor Green
        Write-Host "You can now use 'razon' from any terminal" -ForegroundColor Green
        Write-Host "Example: razon send" -ForegroundColor Yellow
        Write-Host "Example: razon init" -ForegroundColor Yellow
    } else {
        Write-Host "`nBinary installed to: $exePath" -ForegroundColor Yellow
        Write-Host "Please restart your terminal to use razon" -ForegroundColor Yellow
    }
} catch {
    Write-Error "Installation failed: $_"
    if (Test-Path $installDir) {
        Remove-Item -Path $installDir -Recurse -Force
    }
    exit 1
}