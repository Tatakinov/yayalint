@echo off
chcp 65001
cd /d "%~dp0"
yayalint.exe %*
pause
