$flutter = "D:\Arikx\tools\flutter_3.41.6\bin\flutter.bat"

if (-not (Test-Path $flutter)) {
    Write-Error "Flutter SDK not found at $flutter"
    exit 1
}

& $flutter @args
exit $LASTEXITCODE
