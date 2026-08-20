@echo off
echo ========================================================
echo        Building Sitanagri Mart Project...
echo ========================================================

if not exist "out" mkdir out
if not exist "Barcode" mkdir Barcode

javac -cp "lib/*;src" -d out src/jmart/pojo/*.java src/jmart/dbutil/*.java src/jmart/dao/*.java src/jmart/gui/*.java

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Copying assets...
    xcopy /Y /Q "src\jmart\gui\*.jpg" "out\jmart\gui\" 2>nul
    xcopy /Y /Q "src\jmart\gui\*.png" "out\jmart\gui\" 2>nul
    echo.
    echo ========================================================
    echo SUCCESS: Sitanagri Mart compiled successfully!
    echo Run 'run.bat' to launch the application.
    echo ========================================================
) else (
    echo.
    echo ========================================================
    echo ERROR: Build failed. Please check compiler output.
    echo ========================================================
)
pause
