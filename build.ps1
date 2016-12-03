Write-Host "Preparing to run build script..."

$PSScriptRoot = split-path -parent $MyInvocation.MyCommand.Definition;

$TOOLS_DIR = Join-Path $PSScriptRoot "tools"
$NUGET_EXE = Join-Path $TOOLS_DIR "nuget.exe"
$NUGET_URL = "http://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
$CAKE_VERSION = "0.17.0"
#$CAKE_EXE = Join-Path $TOOLS_DIR "Cake.$($CAKE_VERSION)/Cake.exe"
$CAKE_EXE = Join-Path $TOOLS_DIR "Cake.CoreCLR.$CAKE_VERSION/Cake.dll"
$env:PATH = "$TOOLS_DIR;$env:PATH"

# Make sure tools folder exists
if ((Test-Path $PSScriptRoot) -and !(Test-Path $TOOLS_DIR)) {
    Write-Verbose -Message "Creating tools directory..."
    New-Item -Path $TOOLS_DIR -Type directory | out-null
}

###########################################################################
# INSTALL .NET CORE CLI
###########################################################################

Function Install-Dotnet()
{
    # Prepare the dotnet CLI folder
    $env:DOTNET_INSTALL_DIR="$(Convert-Path "$PSScriptRoot")\.dotnet\win7-x64"
    if (!(Test-Path $env:DOTNET_INSTALL_DIR))
    {
      mkdir $env:DOTNET_INSTALL_DIR | Out-Null
    }

	# Download the dotnet CLI install script
    if (!(Test-Path .\dotnet\install.ps1))
    {
      Write-Output "Downloading Dotnet CLI installer..."
      Invoke-WebRequest "https://raw.githubusercontent.com/dotnet/cli/rel/1.0.0-preview2/scripts/obtain/dotnet-install.ps1" -OutFile ".\.dotnet\dotnet-install.ps1"
    }

    # Run the dotnet CLI install
    Write-Output "Installing Dotnet CLI ..."
    & .\.dotnet\dotnet-install.ps1 -Channel "preview" -Version "1.0.0-preview2-003131" -InstallDir "$env:DOTNET_INSTALL_DIR"

    # Add the dotnet folder path to the process. This gets skipped
    # by Install-DotNetCli if it's already installed.
    Remove-PathVariable $env:DOTNET_INSTALL_DIR
    $env:PATH = "$env:DOTNET_INSTALL_DIR;$env:PATH"
}

Function Remove-PathVariable([string]$VariableToRemove)
{
  $path = [Environment]::GetEnvironmentVariable("PATH", "User")
  $newItems = $path.Split(';') | Where-Object { $_.ToString() -inotlike $VariableToRemove }
  [Environment]::SetEnvironmentVariable("PATH", [System.String]::Join(';', $newItems), "User")
  $path = [Environment]::GetEnvironmentVariable("PATH", "Process")
  $newItems = $path.Split(';') | Where-Object { $_.ToString() -inotlike $VariableToRemove }
  [Environment]::SetEnvironmentVariable("PATH", [System.String]::Join(';', $newItems), "Process")
}

Install-Dotnet

###########################################################################
# INSTALL CAKE
###########################################################################

Add-Type -AssemblyName System.IO.Compression.FileSystem
Function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

# Make sure Cake has been installed.
if (!(Test-Path $CAKE_EXE)) {
    Write-Host "Installing Cake..."
    (New-Object System.Net.WebClient).DownloadFile("https://www.nuget.org/api/v2/package/Cake.CoreCLR/$CAKE_VERSION", "$TOOLS_DIR\Cake.CoreCLR.zip")
    Unzip "$TOOLS_DIR\Cake.CoreCLR.zip" "$TOOLS_DIR/Cake.CoreCLR.$CAKE_VERSION"
    Remove-Item "$TOOLS_DIR\Cake.CoreCLR.zip"
}

###########################################################################
# RUN BUILD SCRIPT
###########################################################################

Write-Host "Running build script..."
& dotnet "$CAKE_EXE" $args
exit $LASTEXITCODE
