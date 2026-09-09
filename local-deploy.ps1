param(
    [string]$CommitMessage = "Deploy: production update $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
    [string]$VpsHost = "169.58.89.28",
    [string]$VpsUser = "root",
    [string]$VpsPath = "/var/www/miapp",
    [switch]$SkipChecks,
    [switch]$SkipVps
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [Console]::OutputEncoding

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "El comando '$Command $($Arguments -join ' ')' ha fallado con codigo $LASTEXITCODE."
    }
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n>> $Message" -ForegroundColor Cyan
}

Set-Location -LiteralPath $PSScriptRoot

try {
    Write-Host "Publicacion de OMIKI Golf" -ForegroundColor Green

    $branch = (& git branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "No se ha podido leer la rama actual de Git."
    }
    if ($branch -ne "main") {
        throw "La publicacion solo se permite desde main. Rama actual: $branch"
    }

    if (-not $SkipChecks) {
        Write-Step "Comprobando TypeScript"
        Invoke-Checked -Command "npm.cmd" -Arguments @("run", "typecheck")

        Write-Step "Generando build de produccion"
        Invoke-Checked -Command "npm.cmd" -Arguments @("run", "build")

        Write-Step "Comprobando formato del diff"
        Invoke-Checked -Command "git" -Arguments @("diff", "--check")
    }

    Write-Step "Sincronizando main con GitHub"
    Invoke-Checked -Command "git" -Arguments @("pull", "--rebase", "--autostash", "origin", "main")

    Write-Step "Preparando cambios (theme-kit queda excluido)"
    Invoke-Checked -Command "git" -Arguments @("add", "-A", "--", ".")

    & git diff --cached --quiet
    $stagedStatus = $LASTEXITCODE
    if ($stagedStatus -eq 1) {
        Invoke-Checked -Command "git" -Arguments @("commit", "-m", $CommitMessage)
    } elseif ($stagedStatus -eq 0) {
        Write-Host "No hay cambios nuevos que confirmar." -ForegroundColor Yellow
    } else {
        throw "No se ha podido comprobar el contenido preparado para el commit."
    }

    Write-Step "Subiendo main a GitHub"
    Invoke-Checked -Command "git" -Arguments @("push", "origin", "main")
    Write-Host "OK: GitHub actualizado." -ForegroundColor Green

    if ($SkipVps) {
        Write-Host "Despliegue del VPS omitido mediante -SkipVps." -ForegroundColor Yellow
        exit 0
    }

    if ($VpsHost -notmatch '^[a-zA-Z0-9.-]+$' -or $VpsUser -notmatch '^[a-zA-Z0-9_-]+$') {
        throw "El usuario o el host del VPS contienen caracteres no validos."
    }
    if ($VpsPath -notmatch '^/[a-zA-Z0-9._/-]+$') {
        throw "La ruta del VPS no es valida: $VpsPath"
    }

    $sshTarget = "${VpsUser}@${VpsHost}"
    $sshOptions = @(
        "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=10",
        "-o", "StrictHostKeyChecking=accept-new"
    )

    Write-Step "Comprobando acceso SSH al VPS"
    & ssh @sshOptions $sshTarget "true"
    if ($LASTEXITCODE -ne 0) {
        throw "No existe acceso SSH mediante clave para $sshTarget. Configura la clave una sola vez y vuelve a ejecutar el script."
    }

    Write-Step "Desplegando en el VPS"
    $remoteCommand = "cd $VpsPath && ./deploy.sh && docker ps --filter name=lapartideta-app --format '{{.Names}} {{.Status}} {{.Image}}' && docker logs --tail 30 lapartideta-app"
    Invoke-Checked -Command "ssh" -Arguments ($sshOptions + @($sshTarget, $remoteCommand))

    Write-Step "Comprobando https://golf.arinsaldev.com/"
    $healthUrl = "https://golf.arinsaldev.com/?deploy_check=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
    $response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 30
    if ($response.StatusCode -ne 200) {
        throw "La web ha respondido con HTTP $($response.StatusCode)."
    }

    Write-Host "`nOK: Publicacion completada. GitHub y golf.arinsaldev.com estan actualizados." -ForegroundColor Green
} catch {
    Write-Host "`nERROR: Publicacion detenida: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "No se ha continuado despues del paso que fallo." -ForegroundColor Yellow
    exit 1
}
