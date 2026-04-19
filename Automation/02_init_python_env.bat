@echo off
:: --- Posicionarse en la raíz del proyecto (un nivel arriba de automation/) ---
cd /d "%~dp0.."
set "PROJECT_ROOT=%CD%"

echo.
echo [1/5] Raiz del proyecto detectada: %PROJECT_ROOT%
echo.

:: ============================================================
:: PASO 1 — Verificar que Python esté disponible
:: ============================================================
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python no encontrado en el PATH.
    echo         Instala Python desde https://www.python.org y
    echo         asegurate de marcar "Add Python to PATH".
    pause
    exit /b 1
)
echo [OK] Python encontrado.

:: ============================================================
:: PASO 2 — Crear el entorno virtual (si no existe ya)
:: ============================================================
if not exist "%PROJECT_ROOT%\.venv\Scripts\activate.bat" (
    echo.
    echo [2/5] Creando entorno virtual en .venv ...
    python -m venv "%PROJECT_ROOT%\.venv"
    if errorlevel 1 (
        echo [ERROR] No se pudo crear el entorno virtual.
        pause
        exit /b 1
    )
    echo [OK] Entorno virtual creado.
) else (
    echo [2/5] El entorno virtual ya existe, se omite la creacion.
)

:: ============================================================
:: PASO 3 — Activar entorno e instalar librerías
:: ============================================================
echo.
echo [3/5] Activando entorno virtual e instalando dependencias...
call "%PROJECT_ROOT%\.venv\Scripts\activate.bat"

python -m pip install --upgrade pip --quiet
pip install -r "%PROJECT_ROOT%\requirements.txt"
if errorlevel 1 (
    echo [ERROR] Fallo durante la instalacion de dependencias.
    pause
    exit /b 1
)
echo [OK] Dependencias instaladas correctamente.

:: ============================================================
:: PASO 4 — Registrar el kernel de Jupyter con nombre del proyecto
:: ============================================================
echo.
echo [4/5] Registrando kernel de Jupyter...
python -m ipykernel install --user --name="proyectoBDM" --display-name="Python (proyectoBDM)"
if errorlevel 1 (
    echo [ERROR] No se pudo registrar el kernel de Jupyter.
    pause
    exit /b 1
)
echo [OK] Kernel registrado como "Python (proyectoBDM)".

:: ============================================================
:: PASO 5 — Verificar extensión Jupyter en VSCode y abrir notebook
:: ============================================================
echo.
echo [5/5] Verificando extension Jupyter en VSCode...

:: Ruta del notebook relativa a la raíz (portable entre equipos)
set "NOTEBOOK_PATH=%PROJECT_ROOT%\notebook\proyectoBDM.ipynb"

:: Verificar si la extensión Jupyter está instalada
code --list-extensions 2>nul | findstr /i "ms-toolsai.jupyter" >nul
if errorlevel 1 (
    echo [AVISO] La extension Jupyter de VSCode no esta instalada.
    echo         Instalandola automaticamente...
    code --install-extension ms-toolsai.jupyter
    echo [OK] Extension instalada. Abriendo notebook...
) else (
    echo [OK] Extension Jupyter ya esta instalada.
)

:: Abrir VSCode en la raíz del proyecto y el notebook en nueva pestaña
code --reuse-window "%NOTEBOOK_PATH%"

echo.
echo ============================================================
echo  Entorno listo.
echo  Kernel   : Python (proyectoBDM)
echo  Notebook : notebook\proyectoBDM.ipynb
echo  Raiz     : %PROJECT_ROOT%
echo ============================================================
echo.
pause