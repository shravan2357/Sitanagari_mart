@echo off
echo ========================================================
echo        Launching Sitanagri Mart...
echo ========================================================

if not exist "out" (
    echo Build not found. Running build first...
    call build.bat
)

java -cp "out;lib/*" jmart.gui.SplashScreenFrame

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Application crashed. Check DB connection in config.properties
    pause
)
