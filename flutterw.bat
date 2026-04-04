@echo off
set "FLUTTER_SDK=D:\Arikx\tools\flutter_3.41.6\bin\flutter.bat"

if not exist "%FLUTTER_SDK%" (
  echo Flutter SDK not found at %FLUTTER_SDK%
  exit /b 1
)

call "%FLUTTER_SDK%" %*
