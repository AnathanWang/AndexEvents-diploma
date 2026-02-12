@echo off
setlocal
set BASE_DIR=%~dp0
set WRAPPER_DIR=%BASE_DIR%\.mvn\wrapper
set PROPS_FILE=%WRAPPER_DIR%\maven-wrapper.properties
set JAR_FILE=%WRAPPER_DIR%\maven-wrapper.jar

if not exist "%PROPS_FILE%" (
  echo Missing %PROPS_FILE%
  exit /b 1
)

if not exist "%JAR_FILE%" (
  for /f "usebackq tokens=1,* delims==" %%A in ("%PROPS_FILE%") do (
    if "%%A"=="wrapperUrl" set WRAPPER_URL=%%B
  )
  if "%WRAPPER_URL%"=="" (
    echo wrapperUrl not set in %PROPS_FILE%
    exit /b 1
  )
  echo Downloading Maven Wrapper JAR...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "(New-Object Net.WebClient).DownloadFile('%WRAPPER_URL%','%JAR_FILE%')" || exit /b 1
)

if defined JAVA_HOME (
  set JAVA_CMD=%JAVA_HOME%\bin\java
) else (
  set JAVA_CMD=java
)

"%JAVA_CMD%" -classpath "%JAR_FILE%" -Dmaven.multiModuleProjectDirectory="%BASE_DIR%" org.apache.maven.wrapper.MavenWrapperMain %*
