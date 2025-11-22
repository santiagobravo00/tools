<#
.SYNOPSIS
  instalar aplicaciones (Google Chrome, Brave) en sistemas sin Winget.
  Utiliza Invoke-WebRequest para descargar instaladores y comandos de instalación silenciosa.

.DESCRIPTION
  Ofrece un menú para seleccionar qué aplicaciones instalar o para instalar todas.
  Gestiona la descarga, ejecución silenciosa del instalador y limpieza posterior.

.NOTES
  Debe ejecutarse como Administrador. Los IDs de las aplicaciones ahora son las URLs de descarga.
#>

function Show-Menu {
    param(
        [Parameter(Mandatory=$true)]
        [Hashtable]$Applications
    )

    Clear-Host
    Write-Host "--- 🛠️ Menú de Instalación de Aplicaciones (Modo Enterprise) ---" -ForegroundColor Cyan
    Write-Host "Selecciona las aplicaciones que deseas instalar (separadas por comas), o elige una opción predefinida."
    Write-Host "----------------------------------------------------"

    $i = 1
    # Mostramos los nombres amigables para el usuario
    foreach ($FriendlyName in $Applications.Values) {
        Write-Host "$($i). Instalar $($FriendlyName)"
        $i++
    }
    
    Write-Host "----------------------------------------------------"
    Write-Host "A. Instalar **Todas** las aplicaciones listadas." -ForegroundColor Green
    Write-Host "S. **Salir** del script." -ForegroundColor Red
    Write-Host "----------------------------------------------------"
    
    $Choice = Read-Host "Ingresa tu selección (ej: 1, 3, A):"
    return $Choice.Trim()
}

function Install-Application {
    param(
        [Parameter(Mandatory=$true)]
        [string]$DownloadUrl,
        [Parameter(Mandatory=$true)]
        [string]$FriendlyName,
        [Parameter(Mandatory=$true)]
        [string]$InstallerFileName,
        [Parameter(Mandatory=$true)]
        [string]$InstallCommand # El comando silencioso específico para el instalador
    )

    $DownloadPath = Join-Path -Path $env:TEMP -ChildPath $InstallerFileName
    
    Write-Host "👉 Iniciando instalación de $($FriendlyName)..." -ForegroundColor Yellow
    
    # 1. Descargar el instalador
    Write-Host "   Descargando $($FriendlyName) desde $($DownloadUrl)..."
    try {
        # Usamos iwr para la descarga. El Header es importante para algunos servidores.
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $DownloadPath -Headers @{"User-Agent"="PowerShell Script Downloader"}
    }
    catch {
        Write-Host "❌ Error al descargar $($FriendlyName): $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    # 2. Ejecutar la instalación silenciosa
    Write-Host "   Ejecutando instalación silenciosa..."
    try {
        # El comando 'Start-Process' permite ejecutar un proceso externo y esperar a que termine.
        Start-Process -FilePath $InstallCommand -ArgumentList $DownloadPath -Wait -NoNewWindow
        
        Write-Host "✅ $($FriendlyName) se instaló correctamente." -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️ Fallo al ejecutar el instalador de $($FriendlyName): $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
    
    # 3. Limpieza: Eliminar el instalador descargado
    Write-Host "   Limpiando instalador descargado: $($DownloadPath)..."
    try {
        Remove-Item -Path $DownloadPath -Force
        Write-Host "   Limpieza completa." -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️ No se pudo eliminar el archivo: $($DownloadPath)" -ForegroundColor DarkYellow
    }
    Write-Host "---"
}

# --- Definición de Aplicaciones ---
# Formato: 'URL_de_Descarga' = @{Name='Nombre Amigable'; File='Nombre de archivo'; Command='Comando de Ejecución'}
$AppList = @{
    # Google Chrome (Usamos el MSI Enterprise para instalación silenciosa limpia)
    'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi' = @{
        Name='Google Chrome (Enterprise)'
        File='GoogleChromeEnterprise.msi'
        Command='msiexec.exe /i' # Comando MSI para instalar
        Arguments='/qn /norestart' # Parámetros silenciosos (msiexec.exe /i <file.msi> /qn /norestart)
    }
    
    # Brave Browser (Descargamos el instalador que gestiona su propia instalación)
    'https://referrals.brave.com/latest/BraveBrowserSetup-Standalone.exe' = @{
        Name='Brave Browser'
        File='BraveBrowserSetup.exe'
        Command='&' # Comando para ejecutar el .exe directamente ( & <file.exe> /silent)
        Arguments='/silent /install' # Parámetros silenciosos para Brave
    }
    
    # Ejemplo de 7-Zip (EXE)
    #'https://www.7-zip.org/a/7z2301-x64.exe' = @{
    #    Name='7-Zip'
    #    File='7zSetup.exe'
    #    Command='&'
    #    Arguments='/S' # Parámetros silenciosos (el /S es común para EXE)
    #}
}

# --- Lógica Principal del Script ---

# Obtenemos las URLs de descarga que usaremos como identificadores únicos
$ApplicationIDs = $AppList.Keys | Sort-Object

while ($true) {
    # Creamos un Hashtable temporal solo con nombres amigables para el menú
    $FriendlyNames = @{}
    $AppList.GetEnumerator() | ForEach-Object { $FriendlyNames[$_.Key] = $_.Value.Name }

    $Selection = Show-Menu -Applications $FriendlyNames

    if ($Selection -eq 'S' -or $Selection -eq 's') {
        Write-Host "👋 Saliendo del script. ¡Hasta pronto!" -ForegroundColor Red
        break
    }
    
    # Procesar selección (A, o números)
    $AppsToInstallUrls = @()
    if ($Selection -eq 'A' -or $Selection -eq 'a') {
        $AppsToInstallUrls = $ApplicationIDs
        Write-Host "🚀 Opción seleccionada: Instalar todas las aplicaciones." -ForegroundColor Green
    } 
    elseif ($Selection -match '^\s*[\d,]+\s*$') {
        $Indices = $Selection -split ',' | ForEach-Object { [int]$_.Trim() }
        
        foreach ($Index in $Indices) {
            if ($Index -ge 1 -and $Index -le $ApplicationIDs.Count) {
                $AppsToInstallUrls += $ApplicationIDs[$Index - 1]
            }
        }
        
        if ($AppsToInstallUrls.Count -eq 0) {
            Write-Host "❌ Selección no válida. Por favor, intenta de nuevo." -ForegroundColor Red
            continue
        }
        
        $SelectedNames = $AppsToInstallUrls | ForEach-Object { $AppList[$_].Name }
        Write-Host "🚀 Opción seleccionada: $($SelectedNames -join ', ')" -ForegroundColor Green
    }
    else {
        Write-Host "❌ Opción no válida. Por favor, intenta de nuevo." -ForegroundColor Red
        continue
    }

    Write-Host ""
    # Ejecutar la instalación
    foreach ($Url in $AppsToInstallUrls) {
        $AppInfo = $AppList[$Url]
        $ArgumentString = "$($AppInfo.Command) `"$($DownloadPath)`" $($AppInfo.Arguments)"
        
        # Llamamos a la función con la información de descarga y el comando completo
        Install-Application -DownloadUrl $Url `
                            -FriendlyName $AppInfo.Name `
                            -InstallerFileName $AppInfo.File `
                            -InstallCommand "$($AppInfo.Command) $($AppInfo.Arguments)"
    }

    Write-Host ""
    Read-Host "Presiona **Enter** para volver al menú o **Ctrl+C** para salir."
}

# --- Fin del Script ---
