# Skrypt uruchamiający ArgoCD UI
# Pokazuje dane logowania i uruchamia port-forward

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ArgoCD UI" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Sprawdź czy klaster działa
kubectl cluster-info | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[X] Brak połączenia z klastrem Kubernetes" -ForegroundColor Red
    Write-Host "Uruchom klaster: minikube start" -ForegroundColor Yellow
    exit 1
}

# Sprawdź czy ArgoCD jest zainstalowany
$argoCDNamespace = kubectl get namespace argocd -o name 2>&1
if ($argoCDNamespace -notmatch "argocd") {
    Write-Host "[X] ArgoCD nie jest zainstalowany" -ForegroundColor Red
    Write-Host "Uruchom: ./install-local.ps1" -ForegroundColor Yellow
    exit 1
}

# Pobierz hasło
Write-Host "Pobieranie danych logowania..." -ForegroundColor Cyan
$argoPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>$null
if ($argoPassword) {
    $argoPasswordDecoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($argoPassword))
} else {
    Write-Host "[UWAGA] Nie można pobrać hasła ArgoCD" -ForegroundColor Yellow
    $argoPasswordDecoded = "Nie znaleziono hasła"
}

# Wyświetl dane logowania
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Dane logowania ArgoCD:" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  URL:      https://localhost:8080" -ForegroundColor White
Write-Host "  Username: admin" -ForegroundColor White
Write-Host "  Password: $argoPasswordDecoded" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "UWAGA: Zignoruj ostrzeżenie o certyfikacie SSL" -ForegroundColor Yellow
Write-Host "       (to normalne dla lokalnej instalacji)" -ForegroundColor Yellow
Write-Host ""

# Uruchom port-forward
Write-Host "Uruchamianie port-forward..." -ForegroundColor Cyan
Write-Host "Naciśnij Ctrl+C aby zatrzymać" -ForegroundColor Gray
Write-Host ""

# Otwórz przeglądarkę (opcjonalnie)
Start-Sleep -Seconds 2
Start-Process "https://localhost:8080"

# Port-forward (blokujące)
kubectl port-forward svc/argocd-server -n argocd 8080:443
