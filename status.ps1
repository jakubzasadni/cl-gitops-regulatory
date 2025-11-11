# Skrypt sprawdzający status całego środowiska
# Wyświetla informacje o klastrze, ArgoCD i aplikacjach

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Status środowiska lokalnego" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Minikube
Write-Host "[1] Status Minikube:" -ForegroundColor Yellow
Write-Host "-------------------" -ForegroundColor Gray
minikube status
Write-Host ""

# Klaster Kubernetes
Write-Host "[2] Klaster Kubernetes:" -ForegroundColor Yellow
Write-Host "----------------------" -ForegroundColor Gray
kubectl cluster-info 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[X] Brak połączenia z klastrem" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Nodes
Write-Host "[3] Nodes:" -ForegroundColor Yellow
Write-Host "----------" -ForegroundColor Gray
kubectl get nodes
Write-Host ""

# ArgoCD
Write-Host "[4] ArgoCD:" -ForegroundColor Yellow
Write-Host "-----------" -ForegroundColor Gray
$argoCDNamespace = kubectl get namespace argocd -o name 2>&1
if ($argoCDNamespace -match "argocd") {
    Write-Host "[OK] ArgoCD zainstalowany" -ForegroundColor Green
    Write-Host ""
    Write-Host "Pody ArgoCD:" -ForegroundColor Cyan
    kubectl get pods -n argocd
    Write-Host ""
    
    # Hasło ArgoCD
    $argoPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>$null
    if ($argoPassword) {
        $argoPasswordDecoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($argoPassword))
        Write-Host "Dane logowania ArgoCD:" -ForegroundColor Cyan
        Write-Host "  URL: https://localhost:8080 (uruchom: ./start-argocd-ui.ps1)" -ForegroundColor Gray
        Write-Host "  Username: admin" -ForegroundColor Gray
        Write-Host "  Password: $argoPasswordDecoded" -ForegroundColor Gray
    }
} else {
    Write-Host "[X] ArgoCD nie zainstalowany" -ForegroundColor Red
    Write-Host "Uruchom: ./install-local.ps1" -ForegroundColor Yellow
}
Write-Host ""

# Aplikacje ArgoCD
Write-Host "[5] Aplikacje ArgoCD:" -ForegroundColor Yellow
Write-Host "--------------------" -ForegroundColor Gray
kubectl get applications -n argocd 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Brak aplikacji ArgoCD" -ForegroundColor Gray
    Write-Host "Zastosuj: kubectl apply -f argocd/applications/" -ForegroundColor Yellow
}
Write-Host ""

# Deployments
Write-Host "[6] Deployments (namespace: default):" -ForegroundColor Yellow
Write-Host "-------------------------------------" -ForegroundColor Gray
kubectl get deployments 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Brak deploymentów" -ForegroundColor Gray
}
Write-Host ""

# Pody aplikacji
Write-Host "[7] Pody aplikacji:" -ForegroundColor Yellow
Write-Host "------------------" -ForegroundColor Gray
kubectl get pods -l 'app in (dwa-zbiorniki,wahadlo-odwrocone,zbiornik-1rz)' 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Brak podów aplikacji" -ForegroundColor Gray
}
Write-Host ""

# Serwisy
Write-Host "[8] Serwisy:" -ForegroundColor Yellow
Write-Host "------------" -ForegroundColor Gray
kubectl get svc -l 'app in (dwa-zbiorniki,wahadlo-odwrocone,zbiornik-1rz)' 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Brak serwisów" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "Dostęp do serwisów:" -ForegroundColor Cyan
    Write-Host "  minikube service dwa-zbiorniki --url" -ForegroundColor Gray
    Write-Host "  minikube service wahadlo-odwrocone --url" -ForegroundColor Gray
    Write-Host "  minikube service zbiornik-1rz --url" -ForegroundColor Gray
}
Write-Host ""

# ConfigMaps
Write-Host "[9] ConfigMaps:" -ForegroundColor Yellow
Write-Host "---------------" -ForegroundColor Gray
kubectl get configmap -l 'app in (dwa-zbiorniki,wahadlo-odwrocone,zbiornik-1rz)' 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Brak ConfigMaps" -ForegroundColor Gray
}
Write-Host ""

# Zasoby
Write-Host "[10] Zasoby klastra:" -ForegroundColor Yellow
Write-Host "-------------------" -ForegroundColor Gray
kubectl top nodes 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    kubectl top pods 2>$null
} else {
    Write-Host "Metrics server nie jest włączony" -ForegroundColor Gray
    Write-Host "Włącz: minikube addons enable metrics-server" -ForegroundColor Yellow
}
Write-Host ""

# Podsumowanie
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Szybkie komendy:" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Uruchom ArgoCD UI:" -ForegroundColor White
Write-Host "  ./start-argocd-ui.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "Logi aplikacji:" -ForegroundColor White
Write-Host "  kubectl logs -l app=dwa-zbiorniki -f" -ForegroundColor Gray
Write-Host ""
Write-Host "Dostęp do serwisu:" -ForegroundColor White
Write-Host "  minikube service dwa-zbiorniki --url" -ForegroundColor Gray
Write-Host ""
Write-Host "Dashboard Kubernetes:" -ForegroundColor White
Write-Host "  minikube dashboard" -ForegroundColor Gray
Write-Host ""
Write-Host "Czyszczenie:" -ForegroundColor White
Write-Host "  ./cleanup-local.ps1" -ForegroundColor Gray
Write-Host ""
