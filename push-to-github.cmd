@echo off
setlocal
cd /d "E:\WorkBuddy huancun\2026-11-21-13-05-48\securefree"

echo [1/5] git init
"D:\Git\cmd\git.exe" init
"D:\Git\cmd\git.exe" branch -M main

echo [2/5] staging files
"D:\Git\cmd\git.exe" add -A

echo [3/5] commit
"D:\Git\cmd\git.exe" -c user.name="scorpion19961007" -c user.email="scorpion19961007@users.noreply.github.com" commit -m "Initial commit: SecureFree - enable FLAG_SECURE screenshots on Android 17"

echo [4/5] remote
"D:\Git\cmd\git.exe" remote add origin https://github.com/scorpion19961007/SecureFree.git

echo [5/5] push
"D:\Git\cmd\git.exe" push -u origin main

echo.
echo Done. Check https://github.com/scorpion19961007/SecureFree
pause
