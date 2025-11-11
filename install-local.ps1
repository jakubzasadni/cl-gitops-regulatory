# Skrypt automatycznej instalacji lokalnego środowiska z ArgoCD
# Uruchamia klaster Minikube, instaluje ArgoCD i wdraża aplikacje

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Instalacja srodowiska lokalnego" -ForegroundColor Cyan
Write-Host "  ArgoCD + Regulatory PID" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Krok 1: Sprawdz wymagania
Write-Host "[1/7] Sprawdzanie wymagan..." -ForegroundColor Yellow

$requirements = @("minikube", "kubectl", "docker")
$missingTools = @()

foreach ($tool in $requirements) {
    if (!(Get-Command $tool -ErrorAction SilentlyContinue)) {
        $missingTools += $tool
        Write-Host "[X] Brak: $tool" -ForegroundColor Red
    } else {
        Write-Host "[OK] Znaleziono: $tool" -ForegroundColor Green
    }
}

if ($missingTools.Count -gt 0) {
    Write-Host ""
    Write-Host "BLAD: Brakujace narzedzia: $($missingTools -join ', ')" -ForegroundColor Red
    Write-Host "Zainstaluj je przed uruchomieniem skryptu." -ForegroundColor Red
    exit 1
}

# Sprawdz czy Docker Desktop dziala
$dockerRunning = docker info 2>&1 | Select-String "Server Version"
if (!$dockerRunning) {
    Write-Host "[X] Docker Desktop nie jest uruchomiony!" -ForegroundColor Red
    Write-Host "Uruchom Docker Desktop i sprobuj ponownie." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Docker Desktop dziala" -ForegroundColor Green
Write-Host ""

# Krok 2: Uruchom Minikube
Write-Host "[2/7] Uruchamianie klastra Minikube..." -ForegroundColor Yellow

$minikubeStatus = minikube status 2>&1 | Select-String "host: Running"
if ($minikubeStatus) {
    Write-Host "[OK] Minikube juz dziala" -ForegroundColor Green
} else {
    Write-Host "Uruchamianie Minikube (moze potrvac 2-3 minuty)..." -ForegroundColor Cyan
    minikube start --cpus=2 --memory=6144 --driver=docker
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[X] Blad uruchamiania Minikube" -ForegroundColor Red
        Write-Host "Sprobuj zwiekszyc pamiec w Docker Desktop Settings > Resources" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "[OK] Minikube uruchomiony" -ForegroundColor Green
}
Write-Host ""

# Krok 3: Sprawdz polaczenie z klastrem
Write-Host "[3/7] Sprawdzanie polaczenia z klastrem..." -ForegroundColor Yellow
kubectl cluster-info | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[X] Brak polaczenia z klastrem" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Polaczono z klastrem Kubernetes" -ForegroundColor Green
Write-Host ""

# Krok 4: Instalacja ArgoCD
Write-Host "[4/7] Instalacja ArgoCD..." -ForegroundColor Yellow

$argoCDNamespace = kubectl get namespace argocd -o name 2>&1
if ($argoCDNamespace -match "argocd") {
    Write-Host "[OK] ArgoCD juz zainstalowany" -ForegroundColor Green
} else {
    Write-Host "Tworzenie namespace argocd..." -ForegroundColor Cyan
    kubectl create namespace argocd
    
    Write-Host "Instalowanie ArgoCD (moze potrvac 2-3 minuty)..." -ForegroundColor Cyan
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    Write-Host "Czekanie na gotowosc podow ArgoCD..." -ForegroundColor Cyan
    kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[X] Timeout podczas instalacji ArgoCD" -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] ArgoCD zainstalowany" -ForegroundColor Green
}
Write-Host ""

# Krok 5: Pobierz haslo ArgoCD
Write-Host "[5/7] Konfiguracja dostepu do ArgoCD..." -ForegroundColor Yellow

$argoPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>$null
if ($argoPassword) {
    $argoPasswordDecoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($argoPassword))
    Write-Host "[OK] Haslo ArgoCD pobrane" -ForegroundColor Green
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Dane logowania ArgoCD:" -ForegroundColor Cyan
    Write-Host "  URL: https://localhost:8080" -ForegroundColor White
    Write-Host "  Username: admin" -ForegroundColor White
    Write-Host "  Password: $argoPasswordDecoded" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Cyan
} else {
    Write-Host "[UWAGA] Nie mozna pobrac hasla ArgoCD" -ForegroundColor Yellow
}
Write-Host ""

# Krok 6: Wdrozenie aplikacji
Write-Host "[6/7] Wdrazanie aplikacji regulatorow..." -ForegroundColor Yellow

if (Test-Path "argocd/applications") {
    Write-Host "Stosowanie manifestow ArgoCD Applications..." -ForegroundColor Cyan
    kubectl apply -f argocd/applications/
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Aplikacje ArgoCD utworzone" -ForegroundColor Green
    } else {
        Write-Host "[X] Blad podczas tworzenia aplikacji" -ForegroundColor Red
    }
} else {
    Write-Host "[UWAGA] Folder argocd/applications nie istnieje" -ForegroundColor Yellow
    Write-Host "Pomijam automatyczne wdrozenie aplikacji." -ForegroundColor Yellow
}
Write-Host ""

# Krok 7: Status i podsumowanie
Write-Host "[7/7] Sprawdzanie statusu..." -ForegroundColor Yellow

Write-Host ""
Write-Host "Pody ArgoCD:" -ForegroundColor Cyan
kubectl get pods -n argocd

Write-Host ""
Write-Host "Aplikacje ArgoCD:" -ForegroundColor Cyan
kubectl get applications -n argocd 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Brak aplikacji (uzyj manifestow z argocd/applications/)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Deployments w namespace default:" -ForegroundColor Cyan
kubectl get deployments 2>$null

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Instalacja zakonczona!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Kolejne kroki:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Uruchom ArgoCD UI w nowym oknie PowerShell:" -ForegroundColor White
Write-Host "   kubectl port-forward svc/argocd-server -n argocd 8080:443" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Otworz przegladarke:" -ForegroundColor White
Write-Host "   https://localhost:8080" -ForegroundColor Gray
Write-Host "   (Zignoruj ostrzezenie o certyfikacie SSL)" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Zaloguj sie:" -ForegroundColor White
Write-Host "   Username: admin" -ForegroundColor Gray
Write-Host "   Password: $argoPasswordDecoded" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Sprawdz aplikacje w ArgoCD UI" -ForegroundColor White
Write-Host ""
Write-Host "5. Dostep do serwisow:" -ForegroundColor White
Write-Host "   minikube service dwa-zbiorniki --url" -ForegroundColor Gray
Write-Host "   minikube service wahadlo-odwrocone --url" -ForegroundColor Gray
Write-Host "   minikube service zbiornik-1rz --url" -ForegroundColor Gray
Write-Host ""
Write-Host "Dokumentacja: LOCAL_DEPLOYMENT.md" -ForegroundColor Cyan
Write-Host ""
