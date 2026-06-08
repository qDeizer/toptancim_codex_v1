@echo off
START "Toptancim PostgreSQL (CODEX)" postgres.bat
TIMEOUT /T 4 /NOBREAK >NUL
START "Toptancim Backend (CODEX)" backend.bat
START "Toptancim Frontend (CODEX)" frontend.bat
