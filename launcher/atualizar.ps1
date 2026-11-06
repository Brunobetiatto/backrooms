# Launcher do Backrooms: ve se tem commit novo na main, compila no proprio PC
# (com o Processing, baixado uma vez so) e abre o jogo.
# Tudo fica em %LOCALAPPDATA%\BackroomsLuca. Os saves (*.txt) nunca sao apagados.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo    = 'Brunobetiatto/backrooms'
$branch  = 'main'
$root    = Join-Path $env:LOCALAPPDATA 'BackroomsLuca'
$tools   = Join-Path $root 'ferramentas'
$gameDir = Join-Path $root 'jogo'
$work    = Join-Path $root 'compilando'
$verFile = Join-Path $gameDir 'versao.txt'
$logFile = Join-Path $root 'ultimo_build.log'
$procUrl  = 'https://github.com/processing/processing4/releases/download/processing-1293-4.3/processing-4.3-windows-x64.zip'
$minimUrl = 'http://code.compartmental.net/minim/distro/minim_for_processing.zip'
$procJava = Join-Path $tools 'processing-4.3\processing-java.exe'
$minimLib = Join-Path $tools 'minim\library'

function Extrair($zip, $dest) {
    New-Item -ItemType Directory -Force $dest | Out-Null
    & tar.exe -xf $zip -C $dest 2>$null
    if ($LASTEXITCODE -ne 0) { Expand-Archive $zip -DestinationPath $dest -Force }
}

function Baixar($url, $arq) {
    Invoke-WebRequest $url -OutFile $arq -UseBasicParsing -Headers @{ 'User-Agent' = 'backrooms-launcher' }
}

New-Item -ItemType Directory -Force $root, $tools, $gameDir | Out-Null
$exe = Join-Path $gameDir 'backrooms.exe'
$local = if (Test-Path $verFile) { (Get-Content $verFile -Raw).Trim() } else { '' }

try {
    $sha = (Invoke-RestMethod "https://api.github.com/repos/$repo/commits/$branch" -TimeoutSec 15 `
            -Headers @{ 'User-Agent' = 'backrooms-launcher'; 'Accept' = 'application/vnd.github.sha' }).Trim()

    if ($sha -ne $local -or -not (Test-Path $exe)) {
        Write-Host "Versao nova encontrada ($($sha.Substring(0,7))). Preparando..."

        if (-not (Test-Path $procJava)) {
            Write-Host 'Baixando o Processing (so na primeira vez, ~225 MB)...'
            $z = Join-Path $tools 'processing.zip'
            Baixar $procUrl $z; Extrair $z $tools; Remove-Item $z
        }
        if (-not (Test-Path $minimLib)) {
            Write-Host 'Baixando a biblioteca de audio Minim...'
            $z = Join-Path $tools 'minim.zip'
            Baixar $minimUrl $z; Extrair $z $tools; Remove-Item $z
        }

        Write-Host 'Baixando o codigo do jogo...'
        Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force $work | Out-Null
        $z = Join-Path $work 'codigo.zip'
        Baixar "https://codeload.github.com/$repo/zip/$sha" $z
        Extrair $z (Join-Path $work 'x')
        # o Processing exige que a pasta tenha o mesmo nome do .pde principal
        $srcDir = Get-ChildItem (Join-Path $work 'x') -Directory | Select-Object -First 1
        $sketch = Join-Path $work 'backrooms'
        Move-Item $srcDir.FullName $sketch
        Remove-Item -Recurse -Force (Join-Path $sketch '.github'), (Join-Path $sketch 'launcher') -ErrorAction SilentlyContinue
        # jars na pasta code/ entram no classpath e no export
        New-Item -ItemType Directory -Force (Join-Path $sketch 'code') | Out-Null
        Copy-Item (Join-Path $minimLib '*.jar') (Join-Path $sketch 'code')

        Write-Host 'Compilando (leva ~1 minuto)...'
        $out = Join-Path $work 'out'
        # Start-Process: avisos do Processing na saida de erro nao derrubam o script
        $p = Start-Process $procJava -Wait -PassThru -NoNewWindow `
             -ArgumentList "`"--sketch=$sketch`"", "`"--output=$out`"", '--variant=windows-amd64', '--export' `
             -RedirectStandardOutput $logFile -RedirectStandardError "$logFile.err"
        $novo = Get-ChildItem $out -Recurse -Filter 'backrooms.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $novo) { throw "a compilacao falhou (codigo $($p.ExitCode)), veja $logFile e $logFile.err" }

        # troca os arquivos do jogo, preservando os saves (*.txt)
        Get-ChildItem $gameDir | Where-Object { $_.Extension -ne '.txt' } | Remove-Item -Recurse -Force
        Copy-Item (Join-Path $novo.DirectoryName '*') $gameDir -Recurse -Force
        Set-Content $verFile $sha
        Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
        Write-Host 'Jogo atualizado!'
    }
} catch {
    Write-Host "Nao foi possivel atualizar: $($_.Exception.Message)"
    if (Test-Path $exe) { Write-Host 'Abrindo a versao instalada.'; Start-Sleep 3 }
}

if (Test-Path $exe) {
    Start-Process $exe -WorkingDirectory $gameDir
} else {
    Write-Host 'O jogo ainda nao esta instalado (precisa de internet na primeira vez).'
    Read-Host 'Enter para sair'
}
