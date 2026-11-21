# Writes an MSBuild props file that sets the exe file version from the latest
# release tag, so a local build reports the version it was built on.
# Prints the props path; prints nothing when there is no usable tag.
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$OutFile
)

$tag = & git -C $PSScriptRoot describe --tags --abbrev=0 2>$null
if ($LASTEXITCODE -ne 0 -or $tag -notmatch '^v(\d+)\.(\d+)\.(\d+)(?:\.(\d+))?$') {
  exit 0
}

$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$patch = [int]$Matches[3]
$build = 0
if ($Matches[4]) { $build = [int]$Matches[4] }
$version = "$major.$minor.$patch.$build"
$keys = "CompanyName=;FileDescription=Ghbdtn;FileVersion=$version;InternalName=Ghbdtn;LegalCopyright=;LegalTrademarks=;OriginalFilename=Ghbdtn.exe;ProductName=Ghbdtn;ProductVersion=$version;Comments="

$xml = @"
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <VerInfo_MajorVer>$major</VerInfo_MajorVer>
    <VerInfo_MinorVer>$minor</VerInfo_MinorVer>
    <VerInfo_Release>$patch</VerInfo_Release>
    <VerInfo_Build>$build</VerInfo_Build>
    <VerInfo_Keys>$keys</VerInfo_Keys>
  </PropertyGroup>
</Project>
"@
Set-Content -LiteralPath $OutFile -Value $xml -Encoding ASCII
Write-Output $OutFile
