# Verifica a release mais nova no GitHub, atualiza o jogo se precisar e abre.
# Os saves (progress.txt, best.txt, settings.txt...) ficam na pasta e nao sao apagados.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$repo    = 'Brunobetiatto/backrooms'
$base    = $PSScriptRoot
$gameDir = Join-Path $base 'jogo'
$verFile = Join-Path $gameDir 'versao.txt'

$local = if (Test-Path $verFile) { (Get-Content $verFile -Raw).Trim() } else { '' }

try {
    $rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'backrooms-launcher' } -TimeoutSec 10
    $asset = $rel.assets | Where-Object { $_.name -eq 'backrooms-windows.zip' } | Select-Object -First 1
    if ($asset -and $rel.tag_name -ne $local) {
        Write-Host "Atualizando para $($rel.tag_name)... (pode demorar um pouco)"
        $tmp = Join-Path $env:TEMP 'backrooms-update'
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force $tmp | Out-Null
        $zip = Join-Path $tmp 'jogo.zip'
        Invoke-WebRequest $asset.browser_download_url -OutFile $zip
        Expand-Archive $zip -DestinationPath (Join-Path $tmp 'x')
        # remove arquivos antigos do jogo, mas preserva os saves (*.txt)
        if (Test-Path $gameDir) {
            Get-ChildItem $gameDir | Where-Object { $_.Extension -ne '.txt' } | Remove-Item -Recurse -Force
        } else {
            New-Item -ItemType Directory -Force $gameDir | Out-Null
        }
        Copy-Item (Join-Path $tmp 'x\*') $gameDir -Recurse -Force
        Set-Content $verFile $rel.tag_name
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
        Write-Host 'Atualizado!'
    }
} catch {
    Write-Host "Nao deu pra verificar atualizacao ($($_.Exception.Message)). Abrindo a versao instalada."
}

$exe = Join-Path $gameDir 'backrooms.exe'
if (Test-Path $exe) {
    Start-Process $exe -WorkingDirectory $gameDir
} else {
    Write-Host 'Jogo nao instalado e sem internet para baixar.'
    Read-Host 'Enter para sair'
}
