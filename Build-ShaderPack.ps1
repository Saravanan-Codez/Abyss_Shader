# Build-ShaderPack.ps1
# Automates versioning, ZIP creation, and deployment for the Abyss Shader Pack

# Parse arguments for deployment (must be the first non-comment statement in PowerShell)
param (
    [switch]$Deploy = $false # If -Deploy is passed, it copies directly to Minecraft
)

$ProjectName = "Abyss_Shader"
$VersionFile = "version.txt"
$BuildDir = "builds"
$MinecraftShaderDir = "$env:APPDATA\.minecraft\shaderpacks"

# 1. Initialize or increment version
if (Test-Path $VersionFile) {
    $CurrentVersion = Get-Content $VersionFile
    $NewVersion = [math]::Round([double]$CurrentVersion + 0.1, 1)
} else {
    $NewVersion = 0.1
}

$VersionString = "v$NewVersion"
$ZipName = "${ProjectName}_${VersionString}.zip"

Write-Host "--- Starting Build for $ProjectName $VersionString ---" -ForegroundColor Cyan

# 2. Ensure build directory exists
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

# 3. Create ZIP file
$SourceFiles = Get-ChildItem -Path "shaders"

if ($SourceFiles) {
    $TargetPath = Join-Path $BuildDir $ZipName
    
    if (Test-Path $TargetPath) { Remove-Item $TargetPath }
    
    Write-Host "Compressing shader files to $TargetPath..." -ForegroundColor Yellow
    
    # Create a temporary folder to structure the ZIP correctly
    $TempDir = "temp_build"
    if (Test-Path $TempDir) { Remove-Item -Recurse -Force $TempDir }
    New-Item -ItemType Directory -Path $TempDir | Out-Null
    
    # Copy both the shaders folder and pack.mcmeta to the root of the ZIP
    Copy-Item -Path "shaders" -Destination $TempDir -Recurse
    if (Test-Path "pack.mcmeta") {
        Copy-Item -Path "pack.mcmeta" -Destination $TempDir
    }
    
    Compress-Archive -Path "$TempDir\*" -DestinationPath $TargetPath
    
    # Clean up temp folder
    Remove-Item -Recurse -Force $TempDir
    
    # 4. Save the new version
    $NewVersion | Out-File $VersionFile -NoNewline
    
    Write-Host "Build Complete! File saved: $TargetPath" -ForegroundColor Green

    # 5. Optional Auto-Deploy Workflow
    if ($Deploy) {
        if (Test-Path $MinecraftShaderDir) {
            Write-Host "Deploying to Minecraft ($MinecraftShaderDir)..." -ForegroundColor Yellow
            
            # Remove old versions of this shaderpack
            $OldVersions = Get-ChildItem -Path $MinecraftShaderDir -Filter "${ProjectName}_*.zip"
            if ($OldVersions) {
                Write-Host "Removing old deployed versions..." -ForegroundColor DarkYellow
                $OldVersions | Remove-Item -Force
            }

            $DeployTarget = Join-Path $MinecraftShaderDir $ZipName
            Copy-Item -Path $TargetPath -Destination $DeployTarget -Force
            Write-Host "Deployed successfully! You can now select it in-game." -ForegroundColor Green
        } else {
            Write-Host "Minecraft shaderpacks folder not found at $MinecraftShaderDir." -ForegroundColor Red
        }
    } else {
        Write-Host "Tip: Run '.\Build-ShaderPack.ps1 -Deploy' to automatically copy to Minecraft!" -ForegroundColor Gray
    }

} else {
    Write-Error "Error: 'shaders' folder not found in the current directory."
}
