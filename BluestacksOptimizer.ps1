<#
.SYNOPSIS
    BlueStacks Optimizer - Remove apps desnecessários e otimiza o emulador para PCs fracos
.DESCRIPTION
    Este script automatiza todo o processo de otimização do BlueStacks:
    - Baixa e instala o ADB (Platform Tools)
    - Detecta automaticamente a porta ADB do BlueStacks
    - Remove apps inúteis (câmera, contatos, galeria, etc)
    - Aplica otimizações de desempenho (animações, sincronização, etc)
    - Limpa cache e reduz consumo de RAM
.NOTES
    Autor: Seu Nome
    Requer: PowerShell como Administrador
#>

#region [Configurações]
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$adbUrl = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
$adbFolder = "C:\ADB"
$adbZipPath = "$env:TEMP\platform-tools.zip"
$bluestacksConfigPath = "C:\ProgramData\BlueStacks_nxt\bluestacks.conf"
$bluestacksConfigPathOld = "C:\ProgramData\BlueStacks\bluestacks.conf"
#endregion

#region [Funções]
function Write-Log {
    param([string]$Message, [string]$Color = "White")
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $Color
}

function Show-Header {
    Clear-Host
    Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     🚀 BlueStacks Optimizer v1.0                              ║
║     Deixe seu emulador mais leve para PCs fracos             ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    Write-Host ""
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-BluestacksPort {
    Write-Log "🔍 Detectando porta ADB do BlueStacks..." -Color Yellow
    
    # Tenta encontrar a porta no arquivo de configuração
    $configPath = $null
    if (Test-Path $bluestacksConfigPath) {
        $configPath = $bluestacksConfigPath
    } elseif (Test-Path $bluestacksConfigPathOld) {
        $configPath = $bluestacksConfigPathOld
    }
    
    if ($configPath -and (Get-Content $configPath -ErrorAction SilentlyContinue | Select-String "adb_port")) {
        $portLine = Get-Content $configPath | Select-String 'adb_port' | Select-Object -First 1
        if ($portLine -match '(\d{4,5})') {
            $port = $matches[1]
            Write-Log "✅ Porta detectada automaticamente: $port" -Color Green
            return $port
        }
    }
    
    # Se não detectou, pergunta ao usuário
    Write-Log "⚠️ Não foi possível detectar automaticamente a porta ADB" -Color Yellow
    Write-Host ""
    Write-Host "📌 Como encontrar a porta ADB no BlueStacks:" -ForegroundColor Cyan
    Write-Host "   1. Abra o BlueStacks" -ForegroundColor White
    Write-Host "   2. Clique no ícone de engrenagem (Configurações)" -ForegroundColor White
    Write-Host "   3. Vá na aba 'Avançado'" -ForegroundColor White
    Write-Host "   4. Procure por 'Porta ADB' (geralmente 5555, 5556, 5585)" -ForegroundColor White
    Write-Host ""
    
    do {
        $port = Read-Host "Digite a porta ADB do BlueStacks"
        if ($port -match '^\d{4,5}$') {
            break
        }
        Write-Log "❌ Porta inválida! Digite um número entre 4 e 5 dígitos" -Color Red
    } while ($true)
    
    return $port
}

function Download-ADB {
    Write-Log "📥 Baixando ADB (Platform Tools)..." -Color Yellow
    
    # Criar pasta se não existir
    if (-not (Test-Path $adbFolder)) {
        New-Item -ItemType Directory -Path $adbFolder -Force | Out-Null
    }
    
    # Download do arquivo ZIP
    try {
        Invoke-WebRequest -Uri $adbUrl -OutFile $adbZipPath -UseBasicParsing -ErrorAction Stop
        Write-Log "✅ Download concluído" -Color Green
    } catch {
        Write-Log "❌ Falha no download: $_" -Color Red
        Write-Log "🌐 Baixe manualmente de: $adbUrl" -Color Yellow
        Read-Host "Pressione Enter após baixar o arquivo para C:\ADB"
        return
    }
    
    # Extrair arquivo
    Write-Log "📦 Extraindo arquivos..." -Color Yellow
    try {
        Expand-Archive -Path $adbZipPath -DestinationPath $adbFolder -Force
        Write-Log "✅ Extração concluída" -Color Green
    } catch {
        Write-Log "❌ Falha na extração: $_" -Color Red
        return
    }
    
    # Limpar ZIP temporário
    Remove-Item $adbZipPath -Force -ErrorAction SilentlyContinue
}

function Test-ADBConnection {
    param([string]$Port)
    
    $adbExe = Get-ChildItem -Path $adbFolder -Filter "adb.exe" -Recurse | Select-Object -First 1
    
    if (-not $adbExe) {
        Write-Log "❌ ADB não encontrado!" -Color Red
        return $false
    }
    
    Write-Log "🔄 Conectando ao BlueStacks na porta $Port..." -Color Yellow
    
    # Matar servidor ADB antigo
    & $adbExe.FullName kill-server 2>$null | Out-Null
    Start-Sleep -Seconds 1
    
    # Conectar
    $connectResult = & $adbExe.FullName connect "127.0.0.1:$Port" 2>&1
    
    if ($connectResult -match "connected") {
        Write-Log "✅ Conectado com sucesso!" -Color Green
        return $adbExe.FullName
    } else {
        Write-Log "❌ Falha na conexão! Verifique:" -Color Red
        Write-Log "   - BlueStacks está aberto?" -Color Yellow
        Write-Log "   - A porta $Port está correta?" -Color Yellow
        Write-Log "   - ADB está ativado nas configurações do BlueStacks?" -Color Yellow
        return $false
    }
}

function Remove-Bloatware {
    param([string]$AdbPath, [string]$Port)
    
    Write-Log "🗑️ Removendo apps desnecessários..." -Color Yellow
    
    $packagesToRemove = @(
        "com.android.contacts",
        "com.android.camera2", 
        "com.android.gallery3d",
        "com.android.providers.calendar",
        "com.android.wallpaper.livepicker",
        "com.android.wallpaperpicker",
        "com.android.printspooler",
        "com.android.companiondevicemanager",
        "com.android.backupconfirm",
        "com.google.android.backuptransport",
        "com.android.traceur",
        "com.android.statementservice",
        "com.android.chrome",
        "com.android.simappdialog",
        "com.google.android.partnersetup",
        "com.google.android.onetimeinitializer"
    )
    
    $removed = 0
    foreach ($pkg in $packagesToRemove) {
        $result = & $AdbPath -s "127.0.0.1:$Port" shell pm uninstall --user 0 $pkg 2>&1
        if ($result -match "Success") {
            Write-Log "   ✅ Removido: $pkg" -Color Green
            $removed++
        } elseif ($result -match "not installed") {
            Write-Log "   ⏭️  Não instalado: $pkg" -Color DarkGray
        } else {
            Write-Log "   ⚠️  Falha ao remover: $pkg" -Color Yellow
        }
    }
    
    Write-Log "✅ Total de $removed apps removidos com sucesso!" -Color Green
}

function Apply-Otimizations {
    param([string]$AdbPath, [string]$Port)
    
    Write-Log "⚙️ Aplicando otimizações de desempenho..." -Color Yellow
    
    $commands = @(
        # Desativar animações
        "settings put global transition_animation_scale 0",
        "settings put global window_animation_scale 0", 
        "settings put global animator_duration_scale 0",
        # Desativar sincronização automática
        "content insert --uri content://settings/global --bind name:s:auto_sync --bind value:i:0",
        # Limitar processos em segundo plano
        "settings put global background_process_limit 2",
        # Limpar cache
        "pm trim-caches 999G",
        # Limpar logs
        "logcat -c"
    )
    
    foreach ($cmd in $commands) {
        $result = & $AdbPath -s "127.0.0.1:$Port" shell $cmd 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "   ✅ $cmd" -Color Green
        } else {
            Write-Log "   ⚠️  $cmd (pode ser normal)" -Color DarkGray
        }
    }
    
    Write-Log "✅ Otimizações aplicadas!" -Color Green
}

function Show-RAMUsage {
    param([string]$AdbPath, [string]$Port)
    
    Write-Log "📊 Verificando uso de memória..." -Color Yellow
    
    $ramInfo = & $AdbPath -s "127.0.0.1:$Port" shell free -h 2>&1
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    📊 STATUS DA MEMÓRIA                       ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    $ramInfo | ForEach-Object {
        if ($_ -match "Mem:") {
            $parts = $_ -split '\s+'
            Write-Host "   💾 RAM Total:   $($parts[1])" -ForegroundColor White
            Write-Host "   📍 RAM em uso:   $($parts[2])" -ForegroundColor Yellow
            Write-Host "   ✅ RAM livre:    $($parts[3])" -ForegroundColor Green
        }
    }
    
    Write-Host ""
}

function Show-FinalInstructions {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                    ✅ OTIMIZAÇÃO CONCLUÍDA!                    ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎯 O que foi feito:" -ForegroundColor Cyan
    Write-Host "   ✓ Apps inúteis removidos (câmera, contatos, galeria, etc)" -ForegroundColor White
    Write-Host "   ✓ Animações do sistema desativadas" -ForegroundColor White
    Write-Host "   ✓ Sincronização automática desativada" -ForegroundColor White
    Write-Host "   ✓ Cache limpo" -ForegroundColor White
    Write-Host "   ✓ Processos em segundo plano limitados" -ForegroundColor White
    Write-Host ""
    Write-Host "📌 Recomendações finais (faça manualmente no BlueStacks):" -ForegroundColor Cyan
    Write-Host "   1. Configurações → Desempenho → Modo: Baixa memória" -ForegroundColor White
    Write-Host "   2. Configurações → Desempenho → RAM: 2048 MB (ou menos)" -ForegroundColor White
    Write-Host "   3. Configurações → Exibir → Resolução: 1280x720 ou menor" -ForegroundColor White
    Write-Host "   4. Configurações → Exibir → DPI: 160 ou 120" -ForegroundColor White
    Write-Host ""
    Write-Host "🔄 Reinicie o BlueStacks para aplicar todas as mudanças!" -ForegroundColor Yellow
    Write-Host ""
    Write-Log "Obrigado por usar o BlueStacks Optimizer!" -Color Green
    Write-Host ""
    Read-Host "Pressione Enter para sair"
}
#endregion

#region [Execução Principal]
Start-Transcript -Path "$env:TEMP\bluestacks_optimizer.log" -Append | Out-Null

try {
    # Verificar Administrador
    if (-not (Test-Administrator)) {
        Write-Log "❌ Este script precisa ser executado como Administrador!" -Color Red
        Write-Log "💡 Clique com botão direito no PowerShell e selecione 'Executar como administrador'" -Color Yellow
        Read-Host "Pressione Enter para sair"
        exit 1
    }
    
    Show-Header
    
    # Verificar se BlueStacks está aberto
    Write-Log "🔍 Verificando se BlueStacks está em execução..." -Color Yellow
    $bluestacksProcess = Get-Process -Name "HD-Player" -ErrorAction SilentlyContinue
    if (-not $bluestacksProcess) {
        Write-Log "⚠️ BlueStacks NÃO está aberto!" -Color Yellow
        Write-Log "📌 Por favor, abra o BlueStacks antes de continuar" -Color Red
        Read-Host "Pressione Enter após abrir o BlueStacks"
    } else {
        Write-Log "✅ BlueStacks está em execução" -Color Green
    }
    
    # Obter porta ADB
    $port = Get-BluestacksPort
    
    # Baixar ADB
    Download-ADB
    
    # Testar conexão e obter caminho do ADB
    $adbPath = Test-ADBConnection -Port $port
    if (-not $adbPath) {
        throw "Não foi possível conectar ao BlueStacks"
    }
    
    # Mostrar uso de RAM antes
    Show-RAMUsage -AdbPath $adbPath -Port $port
    
    # Remover bloatware
    Remove-Bloatware -AdbPath $adbPath -Port $port
    
    # Aplicar otimizações
    Apply-Otimizations -AdbPath $adbPath -Port $port
    
    # Mostrar uso de RAM depois
    Write-Log "" -Color White
    Write-Log "📊 Comparativo após otimizações:" -Color Cyan
    Show-RAMUsage -AdbPath $adbPath -Port $port
    
    # Instruções finais
    Show-FinalInstructions
    
} catch {
    Write-Log "❌ Erro durante a execução: $_" -Color Red
    Write-Log "📋 Verifique o log em: $env:TEMP\bluestacks_optimizer.log" -Color Yellow
    Read-Host "Pressione Enter para sair"
} finally {
    Stop-Transcript | Out-Null
}
#endregion
