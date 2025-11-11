# Lokalne wdrożenie regulatorów z ArgoCD

Kompletny przewodnik uruchomienia klastra Kubernetes z ArgoCD i wdrożenia regulatorów lokalnie.

## Wymagania wstępne

- ✅ Minikube zainstalowany
- ✅ Docker Desktop uruchomiony
- kubectl zainstalowany
- Git

## Krok 1: Uruchomienie klastra Minikube

```powershell
# Uruchom klaster z wystarczającymi zasobami
minikube start --cpus=4 --memory=8192 --driver=docker

# Sprawdź status
minikube status

# Włącz addony (opcjonalnie)
minikube addons enable metrics-server
minikube addons enable dashboard
```

## Krok 2: Instalacja ArgoCD

```powershell
# Utwórz namespace dla ArgoCD
kubectl create namespace argocd

# Zainstaluj ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Czekaj aż wszystkie pody będą gotowe (może potrwać 2-3 minuty)
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s

# Sprawdź status podów
kubectl get pods -n argocd
```

## Krok 3: Dostęp do ArgoCD UI

```powershell
# Metoda 1: Port-forward (zalecana dla lokalnego użytku)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# ArgoCD UI będzie dostępne na: https://localhost:8080
# (Zignoruj ostrzeżenie o certyfikacie SSL - to normalne dla lokalnej instalacji)
```

**Login do ArgoCD:**
- Username: `admin`
- Password: Pobierz komendą:

```powershell
# PowerShell
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

## Krok 4: Wdrożenie aplikacji regulatorów

### Opcja A: Przez ArgoCD CLI (zalecana)

```powershell
# Zainstaluj ArgoCD CLI (opcjonalnie)
# Windows: Pobierz z https://github.com/argoproj/argo-cd/releases

# Zaloguj się do ArgoCD
argocd login localhost:8080 --insecure

# Dodaj repo GitOps
argocd repo add https://github.com/JakubZasadni/cl-gitops-regulatory.git

# Utwórz aplikacje
argocd app create dwa-zbiorniki `
  --repo https://github.com/JakubZasadni/cl-gitops-regulatory.git `
  --path kustomize/apps/dwa-zbiorniki/base `
  --dest-server https://kubernetes.default.svc `
  --dest-namespace default `
  --sync-policy automated `
  --auto-prune `
  --self-heal

argocd app create wahadlo-odwrocone `
  --repo https://github.com/JakubZasadni/cl-gitops-regulatory.git `
  --path kustomize/apps/wahadlo-odwrocone/base `
  --dest-server https://kubernetes.default.svc `
  --dest-namespace default `
  --sync-policy automated `
  --auto-prune `
  --self-heal

argocd app create zbiornik-1rz `
  --repo https://github.com/JakubZasadni/cl-gitops-regulatory.git `
  --path kustomize/apps/zbiornik-1rz/base `
  --dest-server https://kubernetes.default.svc `
  --dest-namespace default `
  --sync-policy automated `
  --auto-prune `
  --self-heal

# Sprawdź status aplikacji
argocd app list
argocd app get dwa-zbiorniki
```

### Opcja B: Przez manifesty YAML (łatwiejsza)

Użyj gotowych manifestów z folderu `argocd/`:

```powershell
# Zastosuj wszystkie aplikacje ArgoCD
kubectl apply -f argocd/applications/

# Sprawdź status
kubectl get applications -n argocd
```

## Krok 5: Weryfikacja wdrożenia

```powershell
# Sprawdź wszystkie pody
kubectl get pods

# Sprawdź serwisy
kubectl get svc

# Sprawdź deployments
kubectl get deployments

# Logi z konkretnego regulatora
kubectl logs -l app=dwa-zbiorniki

# Szczegóły poda
kubectl describe pod <pod-name>
```

## Krok 6: Dostęp do aplikacji

```powershell
# Metoda 1: NodePort (domyślna w Minikube)
minikube service dwa-zbiorniki --url
minikube service wahadlo-odwrocone --url
minikube service zbiornik-1rz --url

# Metoda 2: Port-forward dla konkretnej aplikacji
kubectl port-forward svc/dwa-zbiorniki 8081:80
# Dostęp: http://localhost:8081
```

## Krok 7: Monitoring i debugging

### ArgoCD Dashboard
```powershell
# ArgoCD UI pokazuje:
# - Status synchronizacji aplikacji
# - Health deploymentów
# - Ostatnie zmiany w GitOps repo
# - Logi synchronizacji

# Dostęp: https://localhost:8080
```

### Kubernetes Dashboard (opcjonalnie)
```powershell
minikube dashboard
```

### Logi aplikacji
```powershell
# Logi z wszystkich podów aplikacji
kubectl logs -l app=dwa-zbiorniki --tail=100

# Logi z konkretnego poda
kubectl logs dwa-zbiorniki-<hash> -f

# Logi ArgoCD (jeśli są problemy z synchronizacją)
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

## Aktualizacja parametrów regulatora

### Automatyczna aktualizacja przez CI/CD:
1. Pipeline w `PID-CD` generuje nowe parametry
2. Automatycznie commituje do `cl-gitops-regulatory`
3. ArgoCD wykrywa zmiany i synchronizuje

### Ręczna aktualizacja:
```powershell
# Edytuj ConfigMap
kubectl edit configmap dwa-zbiorniki-config

# Lub zastosuj nowy plik
kubectl apply -f kustomize/apps/dwa-zbiorniki/base/configmap.yml

# Restartuj deployment aby załadować nowe parametry
kubectl rollout restart deployment/dwa-zbiorniki
```

## Synchronizacja z ArgoCD

ArgoCD automatycznie:
- Sprawdza repo co 3 minuty
- Synchronizuje zmiany
- Przywraca ręcznie zmienione zasoby (self-heal)

Ręczna synchronizacja:
```powershell
# Przez CLI
argocd app sync dwa-zbiorniki

# Przez UI
# Kliknij "Sync" w aplikacji
```

## Czyszczenie środowiska

```powershell
# Usuń aplikacje ArgoCD
kubectl delete -f argocd/applications/

# Lub przez CLI
argocd app delete dwa-zbiorniki --cascade
argocd app delete wahadlo-odwrocone --cascade
argocd app delete zbiornik-1rz --cascade

# Usuń ArgoCD
kubectl delete namespace argocd

# Zatrzymaj klaster Minikube
minikube stop

# Usuń klaster (opcjonalnie)
minikube delete
```

## Troubleshooting

### ArgoCD nie może zsynchronizować
```powershell
# Sprawdź czy repo jest dodane
argocd repo list

# Sprawdź logi aplikacji
argocd app get dwa-zbiorniki

# Sprawdź logi controllera
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Pody się nie uruchamiają
```powershell
# Sprawdź eventy
kubectl get events --sort-by='.lastTimestamp'

# Szczegóły poda
kubectl describe pod <pod-name>

# ImagePullBackOff? Sprawdź czy obrazy są dostępne
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].image}'
```

### Brak dostępu do serwisów
```powershell
# Sprawdź typy serwisów
kubectl get svc

# Minikube tunnel dla LoadBalancer (jeśli używasz)
minikube tunnel

# Sprawdź czy port-forward działa
netstat -an | findstr "8081"
```

## Przydatne komendy

```powershell
# Status całego środowiska
kubectl get all
kubectl get all -n argocd

# Zasoby Minikube
minikube ssh
docker ps

# Metryki
kubectl top nodes
kubectl top pods

# Eksport konfiguracji
kubectl get deployment dwa-zbiorniki -o yaml > backup.yaml
```

## Kolejne kroki

- 🔄 **Auto-sync**: ArgoCD automatycznie wdroży zmiany z repo
- 📊 **Monitoring**: Dodaj Prometheus/Grafana dla metryk
- 🔐 **Secrets**: Użyj Sealed Secrets dla wrażliwych danych
- 🌐 **Ingress**: Skonfiguruj Ingress dla zewnętrznego dostępu
- 🚀 **Multi-env**: Utwórz overlays dla dev/staging/prod

## Linki

- ArgoCD UI: https://localhost:8080
- ArgoCD Docs: https://argo-cd.readthedocs.io/
- Minikube Docs: https://minikube.sigs.k8s.io/docs/
- Repository GitOps: https://github.com/JakubZasadni/cl-gitops-regulatory
