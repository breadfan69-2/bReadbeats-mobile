@echo off
setlocal

set "ROOT_DIR=%~dp0"
set "PROTO_DIR=%ROOT_DIR%proto\focstim"
set "OUT_DIR=%ROOT_DIR%lib\generated\protobuf"
set "LOCAL_PROTOC=%ROOT_DIR%.tools\protoc\bin\protoc.exe"
set "PROTOC_BIN=protoc"
set "PUB_BIN=%LOCALAPPDATA%\Pub\Cache\bin"
set "DART_PROTOC_PLUGIN=%PUB_BIN%\protoc-gen-dart.bat"

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

if exist "%LOCAL_PROTOC%" (
  set "PROTOC_BIN=%LOCAL_PROTOC%"
) else (
  where protoc >nul 2>nul
  if errorlevel 1 (
    echo [ERROR] protoc was not found in PATH and no local copy exists.
    echo Expected local path: %LOCAL_PROTOC%
    exit /b 1
  )
)

dart pub global activate protoc_plugin
if errorlevel 1 (
  echo [ERROR] Failed to activate protoc_plugin.
  exit /b 1
)

if exist "%PUB_BIN%" set "PATH=%PUB_BIN%;%PATH%"

if not exist "%DART_PROTOC_PLUGIN%" (
  echo [ERROR] protoc-gen-dart plugin was not found at: %DART_PROTOC_PLUGIN%
  exit /b 1
)

"%PROTOC_BIN%" ^
  --plugin=protoc-gen-dart="%DART_PROTOC_PLUGIN%" ^
  --dart_out="%OUT_DIR%" ^
  -I="%PROTO_DIR%" ^
  "%PROTO_DIR%\constants.proto" ^
  "%PROTO_DIR%\messages.proto" ^
  "%PROTO_DIR%\notifications.proto" ^
  "%PROTO_DIR%\focstim_rpc.proto"

if errorlevel 1 (
  echo [ERROR] Protobuf generation failed.
  exit /b 1
)

echo [OK] Generated Dart protobuf files in %OUT_DIR%
