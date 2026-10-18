# Release Win64 build. The tag vX.Y.Z[.N] becomes the exe file version.
# GHBDTN_UPDATE is defined only here, so build.bat stays off the network.
# -ExeOutput writes the exe somewhere else when bin\Ghbdtn.exe is in use.
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Tag,
  [string]$ExeOutput
)

$ErrorActionPreference = 'Stop'

if ($Tag -notmatch '^v(\d+)\.(\d+)\.(\d+)(?:\.(\d+))?$') {
  Write-Error 'Tag must be vX.Y.Z or vX.Y.Z.N'
  exit 1
}

$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$patch = [int]$Matches[3]
$build = 0
if ($Matches[4]) { $build = [int]$Matches[4] }
foreach ($part in @($major, $minor, $patch, $build)) {
  if ($part -gt 65535) {
    Write-Error 'A version part must be between 0 and 65535'
    exit 1
  }
}

$version = "$major.$minor.$patch.$build"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$props = Join-Path $root 'release.props'
$proj = Join-Path $root 'Ghbdtn.dproj'
$rsvars = Join-Path ${env:ProgramFiles(x86)} 'Embarcadero\Studio\37.0\bin\rsvars.bat'
$keys = "CompanyName=;FileDescription=Ghbdtn;FileVersion=$version;InternalName=Ghbdtn;LegalCopyright=;LegalTrademarks=;OriginalFilename=Ghbdtn.exe;ProductName=Ghbdtn;ProductVersion=$version;Comments="

$xml = @"
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <DCC_Define>RELEASE;GHBDTN_UPDATE</DCC_Define>
    <VerInfo_MajorVer>$major</VerInfo_MajorVer>
    <VerInfo_MinorVer>$minor</VerInfo_MinorVer>
    <VerInfo_Release>$patch</VerInfo_Release>
    <VerInfo_Build>$build</VerInfo_Build>
    <VerInfo_Keys>$keys</VerInfo_Keys>
  </PropertyGroup>
</Project>
"@

try {
  Set-Content -LiteralPath $props -Value $xml -Encoding ASCII
  $cmd = 'call "' + $rsvars + '" && msbuild "' + $proj + '" /nologo /v:m /t:Build /p:Config=Release /p:Platform=Win64 /p:ForceRebuild=true /p:GhbdtnReleaseProps="' + $props + '"'
  if ($ExeOutput) {
    $cmd = $cmd + ' /p:DCC_ExeOutput="' + $ExeOutput + '"'
  }
  & cmd.exe /d /c $cmd
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  $out = Join-Path $root 'bin\Ghbdtn.exe'
  if ($ExeOutput) { $out = Join-Path $ExeOutput 'Ghbdtn.exe' }
  if (-not [IO.Path]::IsPathRooted($out)) { $out = Join-Path $root $out }
  Write-Host "Release $version : $out"
}
finally {
  if (Test-Path -LiteralPath $props) {
    Remove-Item -LiteralPath $props
  }
}
