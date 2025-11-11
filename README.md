# cl-gitops-regulatory

Repository GitOps do wdrażania regulatorów PID na Kubernetes z ArgoCD.

## Struktura projektu

```
cl-gitops-regulatory/
├── argocd/
│   └── applications/          # Manifesty ArgoCD Applications
│       ├── dwa-zbiorniki.yaml
│       ├── wahadlo-odwrocone.yaml
│       └── zbiornik-1rz.yaml
├── kustomize/
│   └── apps/
│       ├── dwa-zbiorniki/
│       │   └── base/
│       │       ├── configmap.yml      # Parametry regulatora
│       │       ├── deployment.yml     # Deployment aplikacji
│       │       ├── service.yml        # Serwis NodePort
│       │       └── kustomization.yml
│       ├── wahadlo-odwrocone/
│       └── zbiornik-1rz/
├── install-local.ps1          # Automatyczna instalacja lokalnie
├── cleanup-local.ps1          # Czyszczenie środowiska
└── LOCAL_DEPLOYMENT.md        # Pełna dokumentacja

```

## Szybki start - Lokalne wdrożenie

### Wymagania
- Minikube
- Docker Desktop
- kubectl

### Automatyczna instalacja

```powershell
# Sklonuj repo
git clone https://github.com/JakubZasadni/cl-gitops-regulatory.git
cd cl-gitops-regulatory

# Uruchom automatyczną instalację
./install-local.ps1
```

Skrypt automatycznie:
1. ✅ Uruchomi klaster Minikube
2. ✅ Zainstaluje ArgoCD
3. ✅ Wdroży wszystkie 3 aplikacje regulatorów
4. ✅ Wyświetli dane logowania

### Dostęp do ArgoCD UI

```powershell
# W nowym oknie PowerShell
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Otwórz przeglądarkę: https://localhost:8080
# Username: admin
# Password: (wyświetlone przez skrypt)
```

### Dostęp do aplikacji

```powershell
# Pobierz URL serwisów
minikube service dwa-zbiorniki --url
minikube service wahadlo-odwrocone --url
minikube service zbiornik-1rz --url
```

## Pełna dokumentacja

📖 **[LOCAL_DEPLOYMENT.md](LOCAL_DEPLOYMENT.md)** - Kompletny przewodnik:
- Instalacja krok po kroku
- Konfiguracja ArgoCD
- Monitoring i debugging
- Aktualizacja parametrów
- Troubleshooting

## Aplikacje

### 1. Dwa Zbiorniki
- **Model**: System dwóch zbiorników połączonych kaskadowo
- **Regulator**: PID/PI/PD/P (automatycznie dobrany przez CI/CD)
- **Path**: `kustomize/apps/dwa-zbiorniki/base`

### 2. Wahało Odwrócone
- **Model**: Wahało odwrócone (inverted pendulum)
- **Regulator**: PID/PI/PD/P (automatycznie dobrany przez CI/CD)
- **Path**: `kustomize/apps/wahadlo-odwrocone/base`

### 3. Zbiornik 1. rzędu
- **Model**: Prosty zbiornik pierwszego rzędu
- **Regulator**: PID/PI/PD/P (automatycznie dobrany przez CI/CD)
- **Path**: `kustomize/apps/zbiornik-1rz/base`

## Automatyczne wdrożenie przez CI/CD

Pipeline w repozytorium [PID-CD](https://github.com/JakubZasadni/PID-CD) automatycznie:

1. 🔧 **Stroi parametry** regulatorów (3 metody: Ziegler-Nichols, siatka, optymalizacja)
2. ✅ **Waliduje** na 3 modelach dynamicznych
3. 🏆 **Wybiera najlepszy** regulator wg metryk (IAE, ISE, Mp, ts)
4. 📦 **Commituje** parametry do `cl-gitops-regulatory`
5. 🚀 **ArgoCD wykrywa** zmiany i wdraża automatycznie

### Jak działa auto-deploy?

```
PID-CD Pipeline                  cl-gitops-regulatory           ArgoCD
    ├─ Tuning                           │                          │
    ├─ Validation                       │                          │
    ├─ Select Best                      │                          │
    └─ Git Push ──────────────────────> │                          │
                                        ├─ Commit detected         │
                                        └─ Webhook/Poll ─────────> │
                                                                   ├─ Sync
                                                                   └─ Deploy
```

## Struktura ConfigMap

Każda aplikacja ma ConfigMap z parametrami regulatora:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dwa-zbiorniki-config
data:
  regulator_type: "regulator_pid"
  method: "optymalizacja"
  Kp: "1.234"
  Ki: "0.567"
  Kd: "0.089"
  IAE: "12.34"
  ISE: "56.78"
  przeregulowanie: "5.2"
  czas_ustalania: "3.4"
```

## Weryfikacja wdrożenia

```powershell
# Status aplikacji w ArgoCD
kubectl get applications -n argocd

# Pody aplikacji
kubectl get pods

# Logi regulatora
kubectl logs -l app=dwa-zbiorniki -f

# Szczegóły deploymentu
kubectl describe deployment dwa-zbiorniki
```

## Czyszczenie środowiska

```powershell
# Usuń tylko aplikacje
./cleanup-local.ps1

# Usuń aplikacje + ArgoCD
./cleanup-local.ps1 -Full

# Usuń cały klaster
./cleanup-local.ps1 -DeleteCluster
```

## Troubleshooting

### ArgoCD nie synchronizuje aplikacji
- Sprawdź logi: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller`
- Wymuś sync: `argocd app sync dwa-zbiorniki`

### Pody się nie uruchamiają (ImagePullBackOff)
- Sprawdź czy obrazy są dostępne publicznie
- Sprawdź nazwę obrazu w `deployment.yml`

### Brak dostępu do serwisów
- Sprawdź typ serwisu: `kubectl get svc`
- Użyj `minikube service <nazwa> --url`

## Monitoring

```powershell
# Dashboard Kubernetes
minikube dashboard

# Metryki podów
kubectl top pods

# Eventy w klastrze
kubectl get events --sort-by='.lastTimestamp'
```

## Rozwój

### Dodanie nowego środowiska (dev/staging/prod)

```bash
# Utwórz overlay
mkdir -p kustomize/apps/dwa-zbiorniki/overlays/staging

# Dodaj kustomization.yaml z patches
# Utwórz nową ArgoCD Application wskazującą na overlay
```

### Aktualizacja parametrów

Parametry są automatycznie aktualizowane przez pipeline CI/CD, ale można też ręcznie:

```powershell
# Edytuj ConfigMap
kubectl edit configmap dwa-zbiorniki-config

# Restartuj deployment
kubectl rollout restart deployment/dwa-zbiorniki
```

## Linki

- 🔗 **Repository główne**: [PID-CD](https://github.com/JakubZasadni/PID-CD)
- 📊 **ArgoCD Docs**: https://argo-cd.readthedocs.io/
- ☸️ **Kubernetes Docs**: https://kubernetes.io/docs/
- 🚀 **Minikube**: https://minikube.sigs.k8s.io/

## Licencja

MIT