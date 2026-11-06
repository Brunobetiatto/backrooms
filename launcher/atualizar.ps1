# Launcher do Backrooms: ve se tem commit novo na main, compila no proprio PC
# (com o Processing, baixado uma vez so) e abre o jogo.
# Tudo fica na pasta do NerdolasBackrooms.exe: o jogo em jogo\ e o Processing em .ferramentas\ (oculta).
# A compilacao usa uma pasta temporaria que e apagada no fim. Os saves (*.txt) nunca sao apagados.
param(
    [string]$Base,        # pasta do NerdolasBackrooms.exe (o exe passa sozinho)
    [switch]$SemAbrir     # so atualiza/compila, sem abrir o jogo (para testes)
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo    = 'Brunobetiatto/backrooms'
$branch  = 'main'
if (-not $Base) { $Base = Split-Path $PSScriptRoot -Parent }   # rodando direto da pasta launcher
$tools   = Join-Path $Base '.ferramentas'
$gameDir = Join-Path $Base 'jogo'
$work    = Join-Path $env:TEMP 'NerdolasBackrooms_compilando'
$verFile = Join-Path $gameDir 'versao.txt'
$logFile = Join-Path $tools 'ultimo_build.log'
$procUrl  = 'https://github.com/processing/processing4/releases/download/processing-1293-4.3/processing-4.3-windows-x64.zip'
$minimUrl = 'http://code.compartmental.net/minim/distro/minim_for_processing.zip'
$procJava = Join-Path $tools 'processing-4.3\processing-java.exe'
$minimLib = Join-Path $tools 'minim\library'

function Extrair($zip, $dest) {
    New-Item -ItemType Directory -Force $dest | Out-Null
    # tar do proprio Windows (rapido); se faltar ou falhar, usa o Expand-Archive
    $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
    $ok = $false
    if (Test-Path $tar) {
        $t = Start-Process $tar -ArgumentList '-xf', "`"$zip`"", '-C', "`"$dest`"" -Wait -PassThru -NoNewWindow
        $ok = $t.ExitCode -eq 0
    }
    if (-not $ok) { Expand-Archive $zip -DestinationPath $dest -Force }
}

function Baixar($url, $arq) {
    Invoke-WebRequest $url -OutFile $arq -UseBasicParsing -Headers @{ 'User-Agent' = 'backrooms-launcher' }
}

New-Item -ItemType Directory -Force $tools, $gameDir | Out-Null
(Get-Item $tools -Force).Attributes = 'Directory, Hidden'
$procJre = Join-Path $tools 'processing-4.3\java'

# jogo\java e um atalho (junction) para o Java do Processing: um Java so no disco, em vez de dois.
# Uma junction e apagada sozinha ([IO.Directory]::Delete sem recursao): o Remove-Item -Recurse do
# PowerShell 5 entraria nela e apagaria o Java do Processing junto.
function RemoverJava($dir) {
    $j = Join-Path $dir 'java'
    if (-not (Test-Path $j)) { return }
    if ((Get-Item $j -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { [IO.Directory]::Delete($j) }
    else { Remove-Item -Recurse -Force $j }
}
function LigarJava($dir) {
    RemoverJava $dir
    $p = Start-Process cmd -ArgumentList "/c mklink /J `"$(Join-Path $dir 'java')`" `"$procJre`" >nul" -Wait -PassThru -NoNewWindow
    if ($p.ExitCode -ne 0) { throw 'nao foi possivel ligar o Java do jogo' }
}
$exe = Join-Path $gameDir 'NerdolasBackrooms.exe'
$local = if (Test-Path $verFile) { (Get-Content $verFile -Raw).Trim() } else { '' }

try {
    # ultimo commit da main, lido pelo protocolo do git (nao usa a API do GitHub, que tem limite e as vezes da 504)
    $refs = (Invoke-WebRequest "https://github.com/$repo.git/info/refs?service=git-upload-pack" -UseBasicParsing `
             -TimeoutSec 20 -Headers @{ 'User-Agent' = 'git/2.0' }).Content
    if ($refs -is [byte[]]) { $refs = [Text.Encoding]::ASCII.GetString($refs) }
    if ($refs -notmatch "([0-9a-f]{40}) refs/heads/$branch") { throw "branch $branch nao encontrada no GitHub" }
    $sha = $Matches[1]

    if ($sha -ne $local -or -not (Test-Path $exe)) {
        Write-Host "Versao nova encontrada ($($sha.Substring(0,7))). Preparando..."

        if (-not (Test-Path $procJava)) {
            Write-Host 'Baixando o Processing (so na primeira vez, ~225 MB)...'
            $z = Join-Path $tools 'processing.zip'
            Baixar $procUrl $z; Extrair $z $tools; Remove-Item $z
            # o editor e as ferramentas dele nao sao usados para compilar (~75 MB)
            Remove-Item -Recurse -Force (Join-Path $tools 'processing-4.3	ools'), (Join-Path $tools 'processing-4.3\processing.exe') -ErrorAction SilentlyContinue
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

        # troca os arquivos do jogo, preservando os saves (*.txt); o Java do export (~250 MB) nao e copiado
        RemoverJava $gameDir
        Get-ChildItem $gameDir | Where-Object { $_.Extension -ne '.txt' } | Remove-Item -Recurse -Force
        Get-ChildItem $novo.DirectoryName | Where-Object { $_.Name -ne 'java' } | Copy-Item -Destination $gameDir -Recurse -Force
        LigarJava $gameDir
        # o Processing da ao exe o nome do sketch; renomeia para o nome do jogo
        Rename-Item (Join-Path $gameDir 'backrooms.exe') 'NerdolasBackrooms.exe'
        Set-Content $verFile $sha
        Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
        Write-Host 'Jogo atualizado!'
    }
} catch {
    Write-Host "Nao foi possivel atualizar: $($_.Exception.Message)"
    if (Test-Path $exe) { Write-Host 'Abrindo a versao instalada.'; Start-Sleep 3 }
}

if ($SemAbrir) {
    Write-Host "Teste: jogo pronto em $exe = $(Test-Path $exe)"
} elseif (Test-Path $exe) {
    Start-Process $exe -WorkingDirectory $gameDir
} else {
    Write-Host 'O jogo ainda nao esta instalado (precisa de internet na primeira vez).'
    Read-Host 'Enter para sair'
}
