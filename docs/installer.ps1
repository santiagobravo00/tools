<#
.SYNOPSIS
  Script de Instalación de Packs personalizado para entornos Enterprise.
  DEBE EJECUTARSE COMO ADMINISTRADOR.
.DESCRIPTION
  Instala Google Chrome (Estándar Standalone) y Brave Browser de forma silenciosa.
#>

# 1. Asegura la codificación UTF-8 para evitar errores de tildes
$OutputEncoding = [System.Text.Encoding]::UTF8

function Show-Menu {
    param(
        [Parameter(Mandatory=$true)]
        [Hashtable]$Applications
    )

    Clear-Host
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║       🛠️ MENÚ DE INSTALACIÓN RÁPIDA DE APLICACIONES      ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host "Selecciona los números de las aplicaciones a instalar (ej: 1, 3), o una opción predefinida."
    Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray

    $i = 1
    foreach ($FriendlyName in $Applications.Values) {
        Write-Host "[$($i)] Instalar $($FriendlyName)" -ForegroundColor Green
        $i++
    }
    
    Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[A] Instalar **Todas** las aplicaciones listadas." -ForegroundColor Yellow
    Write-Host "[S] **Salir** del script." -ForegroundColor Red
    Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
    
    $Choice = Read-Host "► Ingresa tu selección (ej: 1, 3, A)"
    return $Choice.Trim()
}

function Invoke-SilentInstall {
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
    Write-Host "🚀 Procesando: $($FriendlyName)..." -ForegroundColor Cyan
    
    # 1. Descargar el instalador
    Write-Host "   -> Descargando desde la fuente..." -ForegroundColor Gray
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $DownloadPath -UseBasicParsing -Headers @{"User-Agent"="Custom Installer Script"} -ErrorAction Stop
    }
    catch {
        Write-Host "❌ Error al descargar $($FriendlyName): $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    # 2. Ejecutar la instalación silenciosa
    Write-Host "   -> Ejecutando instalador silencioso..." -ForegroundColor Gray
    try {
        Start-Process -FilePath $ExecutablePath -ArgumentList $InstallArguments -Wait -NoNewWindow -ErrorAction Stop
        
        Write-Host "✅ $($FriendlyName) se instaló con ÉXITO." -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️ Fallo al ejecutar el instalador de $($FriendlyName). Verifica los argumentos o el estado de la instalación." -ForegroundColor Yellow
    }
    
    # 3. Limpieza: Eliminar el instalador
    Write-Host "   -> Limpiando archivos temporales..." -ForegroundColor Gray
    try {
        Remove-Item -Path $DownloadPath -Force -ErrorAction SilentlyContinue
    }
    catch {}
    Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
}

# --- FUNCIÓN PRINCIPAL DE EJECUCIÓN ---
function Start-InstallerPacks {
    
    # 1. Comprobación de Administrador
    if (-not ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')) {
        Clear-Host
        Write-Host "=========================================================" -ForegroundColor Red
        Write-Host "             🚨 ACCESO DENEGADO 🚨" -ForegroundColor White -BackgroundColor Red
        Write-Host "=========================================================" -ForegroundColor Red
        Write-Host "Este script DEBE ejecutarse como Administrador." -ForegroundColor Yellow
        Write-Host "Por favor, inicia PowerShell (o el símbolo del sistema) con permisos elevados." -ForegroundColor Cyan
        Write-Host "Pulsa Enter para salir."
        Read-Host
        exit
    }
    
    # 2. Banner de Bienvenida y Firma (Ajustado para mejor apariencia)
    Clear-Host
    Write-Host "#########################################################" -ForegroundColor Cyan
    Write-Host "  ✨ PAQUETE DE INSTALACIÓN AUTOMÁTICA (ENTERPRISE PACK) ✨" -ForegroundColor Yellow
    Write-Host "#########################################################" -ForegroundColor Cyan
    Write-Host "  👤 Autor: https://github.com/santiagobravo00/" -ForegroundColor Green
    Write-Host "---------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " "

    # --- Definición de Aplicaciones ---
    $AppList = @{
        'https://dl.google.com/chrome/install/standalonesetup.exe' = @{
            Name='Google Chrome (Estándar)'
            File='ChromeSetup.exe'
            Arguments='/silent /install' 
        }
        'https://referrals.brave.com/latest/BraveBrowserSetup-Standalone.exe' = @{
            Name='Brave Browser'
            File='BraveBrowserSetup.exe'
            Arguments='/silent /install' 
        }
    }

    $FriendlyNames = @{}
    $AppList.GetEnumerator() | ForEach-Object { $FriendlyNames[$_.Key] = $_.Value.Name }
    $ApplicationUrls = $AppList.Keys | Sort-Object

    while ($true) {
        $Selection = Show-Menu -Applications $FriendlyNames

        if ($Selection -eq 'S' -or $Selection -eq 's') {
            Write-Host "👋 Saliendo del menú. ¡Hasta pronto!" -ForegroundColor Red
            break
        }
        
        # Lógica de selección de aplicaciones
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
Start-InstallerPacks
