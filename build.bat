@echo off
setlocal
call "%ProgramFiles(x86)%\Embarcadero\Studio\37.0\bin\rsvars.bat"
if errorlevel 1 exit /b 1

set "PROJ=%~dp0Ghbdtn.dproj"
set "CFG=%~1"
if "%CFG%"=="" set "CFG=Debug"
set "PLAT=Win64"
if not "%~2"=="" if /I not "%~2"=="Win64" (
  echo Ghbdtn supports Win64 only.
  exit /b 1
)

msbuild "%PROJ%" /nologo /v:m /t:Build /p:Config=%CFG% /p:Platform=%PLAT%
if errorlevel 1 exit /b 1

echo.
echo %PLAT% %CFG%: %~dp0bin\Ghbdtn.exe
endlocal
