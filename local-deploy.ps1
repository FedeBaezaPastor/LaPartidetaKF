$ErrorActionPreference = "Stop"

Write-Host "🚀 Preparando cambios para deploy..."

git status

if (-not (git diff --quiet) -and -not (git diff --cached --quiet)) {
    git add .
    git commit -m "Deploy: fix admin login and production update"
    git push origin main
    Write-Host "✅ Cambios subidos a GitHub."
} else {
    Write-Host "No hay cambios pendientes para subir."
}