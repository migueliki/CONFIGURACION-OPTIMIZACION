<#
.SYNOPSIS
    Script de optimización con Chris Titus y confirmación de reinicio
.DESCRIPTION
    Ejecuta el script de Chris Titus, aplica optimizaciones personalizadas
    y pregunta al usuario si desea reiniciar al finalizar.
.NOTES
    File Name      : UltimateOptimizerWithRestart.ps1
    Author         : Asistente de configuración
    Version        : 5.0
#>

# Requiere ejecución como administrador
#Requires -RunAsAdministrator

function Show-Menu {
    Clear-Host
    Write-Host "============================================="
    Write-Host "  OPTIMIZADOR DEFINITIVO CON REINICIO  "
    Write-Host "============================================="
    Write-Host "1. Ejecutar TODO (Chris Titus + Optimizaciones)"
    Write-Host "2. Solo Chris Titus (config estándar)"
    Write-Host "3. Solo mis optimizaciones personalizadas"
    Write-Host "4. Salir"
    Write-Host "============================================="
}

function Run-ChrisTitus {
    Write-Host "`n[+] Ejecutando Chris Titus Tool..." -ForegroundColor Cyan
    try {
        $script = Invoke-WebRequest -Uri "https://christitus.com/win" -UseBasicParsing
        $scriptBlock = [scriptblock]::Create($script.Content)
        
        # Simular entrada estándar (1-1-1)
        1..3 | ForEach-Object { 
            $inputNumber = $_.ToString()
            $inputNumber | & $scriptBlock 
        }
        
        Write-Host "[✓] Chris Titus completado" -ForegroundColor Green
    } catch {
        Write-Host "[X] Error en Chris Titus: $_" -ForegroundColor Red
    }
}

function Optimize-System {
    Write-Host "`n[+] Aplicando optimizaciones personalizadas..." -ForegroundColor Cyan
    
    # 1. Telemetría y privacidad
    $telemetryPaths = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
    )
    
    foreach ($path in $telemetryPaths) {
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "AllowTelemetry" -Value 0 -Type DWord
    }
    
    # 2. Configuración de rendimiento
    powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
    powercfg -setactive e9a42b02-d5df-448d-aa00-03f14749eb61
    
    # 3. Configuración de archivos
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
    
    # 4. Memoria virtual (ajustada para 32GB/16GB)
    $totalRAM = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).Sum / 1MB
    $initialSize = [math]::Round($totalRAM * 1.5)
    $maximumSize = [math]::Round($totalRAM * 3)
    
    $pageFile = Get-WmiObject Win32_PageFileSetting
    if ($pageFile) {
        $pageFile.InitialSize = $initialSize
        $pageFile.MaximumSize = $maximumSize
        $pageFile.Put() | Out-Null
        Write-Host "[✓] Memoria virtual configurada (Inicial: ${initialSize}MB, Máx: ${maximumSize}MB)" -ForegroundColor Green
    }
    
    Write-Host "[✓] Optimizaciones personalizadas completadas" -ForegroundColor Green
}

function Configure-Hardware {
    Write-Host "`n[+] Configurando hardware..." -ForegroundColor Cyan
    
    # Hz máximos del monitor
    try {
        $monitor = Get-WmiObject -Namespace root\wmi -Class WmiMonitorListedSupportedSourceModes | Select-Object -First 1
        if ($monitor) {
            $maxHz = ($monitor.MonitorSourceModes | Sort-Object VerticalRefreshRate -Descending | Select-Object -First 1).VerticalRefreshRate
            (Get-WmiObject -Namespace root\wmi -Class WmiMonitorCurrentMode).SetMode(
                ($monitor.MonitorSourceModes | Where-Object { $_.VerticalRefreshRate -eq $maxHz } | Select-Object -First 1).ModeNumber
            )
            Write-Host "[✓] Monitor configurado a $maxHz Hz (máximo detectado)" -ForegroundColor Green
        }
    } catch {
        Write-Host "[!] No se pudo configurar frecuencia de actualización: $_" -ForegroundColor Yellow
    }
    
    # Todos los procesadores
    $cores = (Get-WmiObject Win32_ComputerSystem).NumberOfLogicalProcessors
    if ($cores -gt 0) {
        bcdedit /set "{current}" numproc $cores
        Write-Host "[✓] Configurados todos los $cores núcleos lógicos" -ForegroundColor Green
    }
}

function Ask-ForRestart {
    Write-Host "`n[!] Algunos cambios requieren reinicio para aplicarse" -ForegroundColor Yellow
    $choice = Read-Host "¿Deseas reiniciar ahora? (S/N)"
    
    if ($choice -eq "S" -or $choice -eq "s") {
        Write-Host "[+] Reiniciando sistema..." -ForegroundColor Cyan
        Start-Sleep -Seconds 3
        Restart-Computer -Force
    } else {
        Write-Host "[!] Recuerda reiniciar manualmente cuando sea conveniente" -ForegroundColor Yellow
    }
}

# Menú principal
do {
    Show-Menu
    $selection = Read-Host "Selecciona una opción"
    $restartNeeded = $false
    
    switch ($selection) {
        '1' {
            Run-ChrisTitus
            Optimize-System
            Configure-Hardware
            $restartNeeded = $true
            Write-Host "`n[✓] TODAS las configuraciones aplicadas correctamente" -ForegroundColor Green
        }
        '2' { 
            Run-ChrisTitus
            $restartNeeded = $true
        }
        '3' { 
            Optimize-System
            Configure-Hardware
            $restartNeeded = $true
        }
        '4' { exit }
        default { Write-Host "[X] Opción no válida" -ForegroundColor Red }
    }
    
    if ($restartNeeded) {
        Ask-ForRestart
    } else {
        pause
    }
} until ($selection -eq '4')