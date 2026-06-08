@echo off
TITLE Toptancim Frontend (CODEX)

SET "RUNTIME=%USERPROFILE%\tools\codex-runtime"
SET "FLUTTER_BIN=%RUNTIME%\flutter\bin"
SET "GIT_BIN=%RUNTIME%\PortableGit\cmd"
SET "PATH=%GIT_BIN%;%FLUTTER_BIN%;%PATH%"

ECHO ========================================
ECHO      TOPTANCIM FRONTEND (CODEX)
ECHO ========================================
ECHO.
ECHO Frontend statik web server olarak baslatiliyor.
ECHO Port: 8089
ECHO.

cd /d "%~dp0frontend"

IF NOT EXIST "%FLUTTER_BIN%\flutter.bat" (
  ECHO [HATA] Flutter portable runtime bulunamadi: %FLUTTER_BIN%
  ECHO Once projeyi Codex ile kurulumdan gecirin.
  PAUSE
  EXIT /B 1
)

ECHO [INFO] Flutter web hedefi hazirlaniyor...
CALL flutter config --enable-web --no-enable-windows-desktop --no-enable-linux-desktop --no-enable-macos-desktop
IF ERRORLEVEL 1 GOTO :error

ECHO [INFO] Flutter paketleri kontrol ediliyor...
CALL flutter pub get
IF ERRORLEVEL 1 GOTO :error

IF NOT EXIST "build\web\main.dart.js" (
  ECHO [INFO] Web build bulunamadi, release build aliniyor...
  CALL flutter build web --release --no-web-resources-cdn
  IF ERRORLEVEL 1 GOTO :error
) ELSE (
  ECHO [INFO] Mevcut web build kullanilacak: build\web
)

IF NOT EXIST "node_modules\.bin\serve.cmd" (
  ECHO [INFO] Frontend npm paketleri kuruluyor...
  CALL npm install
  IF ERRORLEVEL 1 GOTO :error
)

ECHO [INFO] http://localhost:8089 yayina aciliyor...
CALL node_modules\.bin\serve.cmd -s build/web -l 8089
GOTO :end

:error
ECHO.
ECHO [HATA] Frontend baslatilirken hata olustu.
PAUSE
EXIT /B 1

:end
PAUSE
