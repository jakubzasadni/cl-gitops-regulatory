# Skrypt czyszczenia lokalnego środowiska
# Usuwa aplikacje ArgoCD, opcjonalnie ArgoCD i klaster Minikube

param(
    [switch]$Full,  # Usuń również ArgoCD
    [switch]$DeleteCluster  # Usuń cały klaster Minikube
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Czyszczenie środowiska lokalnego" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Sprawdź połączenie z klastrem
kubectl cluster-info | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[X] Brak połączenia z klastrem" -ForegroundColor Red
    Write-Host "Czy Minikube jest uruchomiony? (minikube status)" -ForegroundColor Yellow
    exit 1
}

# Usuń aplikacje ArgoCD
Write-Host "[1/3] Usuwanie aplikacji regulatorów..." -ForegroundColor Yellow

$apps = @("dwa-zbiorniki", "wahadlo-odwrocone", "zbiornik-1rz")
foreach ($app in $apps) {
    $exists = kubectl get application $app -n argocd 2>&1
    if ($exists -notmatch "NotFound") {
        Write-Host "Usuwanie aplikacji: $app" -ForegroundColor Cyan
        kubectl delete application $app -n argocd
    } else {
        Write-Host "[SKIP] Aplikacja $app nie istnieje" -ForegroundColor Gray
    }
}

# Usuń deployments i serwisy z namespace default
Write-Host ""
Write-Host "Usuwanie deploymentów i serwisów..." -ForegroundColor Cyan
foreach ($app in $apps) {
    kubectl delete deployment $app --ignore-not-found=true
    kubectl delete service $app --ignore-not-found=true
    kubectl delete configmap "$app-config" --ignore-not-found=true
}

Write-Host "[OK] Aplikacje usunięte" -ForegroundColor Green
Write-Host ""

# Usuń ArgoCD (opcjonalnie)
if ($Full) {
    Write-Host "[2/3] Usuwanie ArgoCD..." -ForegroundColor Yellow
    
    $argoCDNamespace = kubectl get namespace argocd -o name 2>&1
    if ($argoCDNamespace -match "argocd") {
        Write-Host "Usuwanie namespace argocd (może potrwać chwilę)..." -ForegroundColor Cyan
        kubectl delete namespace argocd
        
        # Czekaj na usunięcie namespace
        $timeout = 60
        $elapsed = 0
        while ((kubectl get namespace argocd 2>&1) -notmatch "NotFound" -and $elapsed -lt $timeout) {
            Write-Host "." -NoNewline
            Start-Sleep -Seconds 2
            $elapsed += 2
        }
        Write-Host ""
        Write-Host "[OK] ArgoCD usunięty" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] ArgoCD nie był zainstalowany" -ForegroundColor Gray
    }
} else {
    Write-Host "[2/3] Zachowuję ArgoCD (użyj -Full aby usunąć)" -ForegroundColor Yellow
}
Write-Host ""

# Usuń klaster Minikube (opcjonalnie)
if ($DeleteCluster) {
    Write-Host "[3/3] Usuwanie klastra Minikube..." -ForegroundColor Yellow
    
    $confirmation = Read-Host "Czy na pewno chcesz usunąć cały klaster Minikube? (tak/nie)"
    if ($confirmation -eq "tak") {
        Write-Host "Zatrzymywanie Minikube..." -ForegroundColor Cyan
        minikube stop
        
        Write-Host "Usuwanie klastra..." -ForegroundColor Cyan
        minikube delete
        
        Write-Host "[OK] Klaster Minikube usunięty" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] Anulowano usuwanie klastra" -ForegroundColor Gray
    }
} else {
    Write-Host "[3/3] Zachowuję klaster Minikube (użyj -DeleteCluster aby usunąć)" -ForegroundColor Yellow
}
Write-Host ""

# Podsumowanie
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Czyszczenie zakończone!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

if (!$Full -and !$DeleteCluster) {
    Write-Host "Status środowiska:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Klaster Minikube:" -ForegroundColor White
    minikube status
    Write-Host ""
    Write-Host "Pody w namespace argocd:" -ForegroundColor White
    kubectl get pods -n argocd 2>$null
    Write-Host ""
    Write-Host "Aplikacje ArgoCD:" -ForegroundColor White
    kubectl get applications -n argocd 2>$null
    Write-Host ""
}

Write-Host "Dostępne opcje czyszczenia:" -ForegroundColor Cyan
Write-Host "  ./cleanup-local.ps1              - Usuń tylko aplikacje" -ForegroundColor Gray
Write-Host "  ./cleanup-local.ps1 -Full        - Usuń aplikacje + ArgoCD" -ForegroundColor Gray
Write-Host "  ./cleanup-local.ps1 -DeleteCluster - Usuń cały klaster Minikube" -ForegroundColor Gray
Write-Host ""
