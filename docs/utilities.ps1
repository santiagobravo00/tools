<#
.SYNOPSIS
  Script de Instalación de Packs personalizado para entornos Enterprise.
  Se auto-eleva a Administrador y se ejecuta en una nueva ventana con un estilo llamativo,
  manteniendo la ventana abierta al finalizar el script.
#>

function Show-Menu {
    # ... (Esta función permanece sin cambios) ...
    param(
        [Parameter(Mandatory=$true)]
        [Hashtable]$Applications
    )

    Clear-Host
    Write-Host "--- 🛠️ Menú de Instalación de Aplicaciones ---" -ForegroundColor Cyan
    Write-Host "Selecciona los números de las aplicaciones a instalar (ej: 1, 3), o una opción predefinida."
    Write-Host "----------------------------------------------------"

    $i = 1
    foreach ($FriendlyName in $Applications.Values) {
        Write-Host "$($i). Instalar $($FriendlyName)" -ForegroundColor Green
        $i++
    }
    
    Write-Host "----------------------------------------------------"
    Write-Host "A. Instalar **Todas** las aplicaciones listadas." -ForegroundColor Yellow
    Write-Host "S. **Salir** del script." -ForegroundColor Red
    Write-Host "----------------------------------------------------"
    
    $Choice = Read-Host "Ingresa tu selección (ej: 1, 3, A):"
    return $Choice.Trim()
}

function Invoke-SilentInstall {
    # ... (Esta función permanece sin cambios) ...
    param(
        [Parameter(Mandatory=$true)]
        [string]$DownloadUrl,
        [Parameter(Mandatory=$true)]
        [string]$FriendlyName,
        [Parameter(Mandatory=$true)]
        [string]$InstallerFileName,
        [Parameter(Mandatory=$true)]
        [string]$InstallArguments
    )

    $DownloadPath = Join-Path -Path $env:TEMP -ChildPath $InstallerFileName
    $ExecutablePath = $DownloadPath
    
    Write-Host " "
    Write-Host "✨ Procesando: $($FriendlyName)..." -ForegroundColor Cyan
    
    # 1. Descargar el instalador
    Write-Host "   > Descargando..." -ForegroundColor Gray
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $DownloadPath -UseBasicParsing -Headers @{"User-Agent"="Custom Installer Script"} -ErrorAction Stop
    }
    catch {
        Write-Host "❌ Error al descargar $($FriendlyName): $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    # 2. Ejecutar la instalación silenciosa
    Write-Host "   > Ejecutando instalador silencioso..." -ForegroundColor Gray
    try {
        Start-Process -FilePath $ExecutablePath -ArgumentList $InstallArguments -Wait -NoNewWindow -ErrorAction Stop
        
        Write-Host "✅ $($FriendlyName) se instaló con ÉXITO." -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️ Fallo al ejecutar el instalador de $($FriendlyName). Revisa los permisos o la ruta." -ForegroundColor Yellow
    }
    
    # 3. Limpieza: Eliminar el instalador
    Write-Host "   > Limpiando..." -ForegroundColor Gray
    try {
        Remove-Item -Path $DownloadPath -Force -ErrorAction SilentlyContinue
    }
    catch {}
    Write-Host "---" -ForegroundColor DarkGray
}

function Start-InstallerPacks {
    # 1. Comprobación de Administrador y Auto-Elevación
    if (-not ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')) {
        Write-Host "⚠️ Ejecutando elevación de permisos (RunAs)..." -ForegroundColor Yellow
        $scriptPath = $MyInvocation.MyCommand.Path
        
        # 🟢 CORRECCIÓN APLICADA AQUÍ: Agregamos -NoExit
        $CommandArgs = "-NoExit -File `"$scriptPath`" -elevated"
        Start-Process -FilePath 'powershell.exe' -ArgumentList $CommandArgs -Verb RunAs
        exit
    }
    
    # 2. Banner de Bienvenida y Firma
    Clear-Host
    Write-Host "=========================================================" -ForegroundColor Cyan
    Write-Host "             ✨ PAQUETE DE INSTALACIÓN PERSONALIZADO ✨" -ForegroundColor Yellow
    Write-Host "=========================================================" -ForegroundColor Cyan
    Write-Host "   Cargado por: https://github.com/santiagobravo00" -ForegroundColor Green
    Write-Host "---------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " "

    # --- Definición de Aplicaciones ---
    $AppList = @{
        'https://dl.google.com/chrome/install/standalonesetup.exe' = @{
            Name='Google Chrome (Standard)'
            File='ChromeSetup.exe'
            Arguments='/silent /install' 
        }
        'https://referrals.brave.com/latest/BraveBrowserSetup-Standalone.exe' = @{
            Name='Brave Browser'
            File='BraveBrowserSetup.exe'
            Arguments='/silent /install' 
        }
    }

    # Lógica de menú y ejecución
    $FriendlyNames = @{}
    $AppList.GetEnumerator() | ForEach-Object { $FriendlyNames[$_.Key] = $_.Value.Name }
    $ApplicationUrls = $AppList.Keys | Sort-Object

    while ($true) {
        $Selection = Show-Menu -Applications $FriendlyNames

        if ($Selection -eq 'S' -or $Selection -eq 's') {
            Write-Host "👋 Saliendo del script. ¡Hasta pronto!" -ForegroundColor Red
            break
        }
        
        # ... (Lógica de selección de aplicaciones) ...
        $AppsToInstallUrls = @()
        if ($Selection -eq 'A' -or $Selection -eq 'a') {
            $AppsToInstallUrls = $ApplicationUrls
        } 
        elseif ($Selection -match '^\s*[\d,]+\s*$') {
            $Indices = $Selection -split ',' | ForEach-Object { [int]$_.Trim() }
            foreach ($Index in $Indices) {
                if ($Index -ge 1 -and $Index -le $ApplicationUrls.Count) {
                    $AppsToInstallUrls += $ApplicationUrls[$Index - 1]
                }
            }
        }
        
        if ($AppsToInstallUrls.Count -eq 0) {
            Write-Host "❌ Selección no válida. Por favor, intenta de nuevo." -ForegroundColor Red
            continue
        }

        Write-Host " "
        # Ejecutar la instalación
        foreach ($Url in $AppsToInstallUrls) {
            $AppInfo = $AppList[$Url]
            Invoke-SilentInstall -DownloadUrl $Url `
                                 -FriendlyName $AppInfo.Name `
                                 -InstallerFileName $AppInfo.File `
                                 -InstallArguments $AppInfo.Arguments
        }

        Write-Host " "
        Read-Host "Presiona **Enter** para volver al menú o **Ctrl+C** para salir."
    }
}

# Ejecuta la función principal
if ($MyInvocation.MyCommand.Path) {
    Start-InstallerPacks
} else {
    Write-Host " "
    Write-Host "⚠️ ADVERTENCIA: Ejecutar con 'irm | iex' no permite la auto-elevación. Debe ejecutar PowerShell COMO ADMINISTRADOR primero." -ForegroundColor Yellow
    Write-Host " "
    Start-InstallerPacks
}
