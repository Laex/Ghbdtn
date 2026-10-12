@echo off
setlocal
call "%ProgramFiles(x86)%\Embarcadero\Studio\37.0\bin\rsvars.bat"
if errorlevel 1 exit /b 1

set "PROJ=%~dp0Ghbdtn.Tests.dproj"
set "CFG=%~1"
if "%CFG%"=="" set "CFG=Debug"
set "PLAT=Win64"
if not "%~2"=="" if /I not "%~2"=="Win64" (
  echo Ghbdtn tests support Win64 only.
  exit /b 1
)

msbuild "%PROJ%" /nologo /v:m /t:Build /p:Config=%CFG% /p:Platform=%PLAT%
if errorlevel 1 exit /b 1

"%~dp0..\bin\tests\Ghbdtn.Tests.exe"
exit /b %errorlevel%
