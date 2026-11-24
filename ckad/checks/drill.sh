#!/usr/bin/env bash
# CKAD drill checks. Usage: bash ckad/checks/drill.sh <number>
# Each drill works in its own namespace ckad-<n>. A drill passes when every task passes.
source "$(dirname "$0")/../../checks/lib.sh"
n=${1:?drill number}
ns="ckad-$n"
jpn() { jp "$@" -n "$ns"; }

case "$n" in
1)
  header "Drill 1 · CronJob" "Ejercicio 1 · CronJob"
  task "CronJob backup runs every 5 minutes" "El CronJob backup se ejecuta cada 5 minutos" \
       "kubectl create cronjob backup --image=busybox:1.36 --schedule='*/5 * * * *' -n $ns -- date" "kubectl create cronjob backup --image=busybox:1.36 --schedule='*/5 * * * *' -n $ns -- date" \
       test "$(jpn cronjob backup -o jsonpath='{.spec.schedule}')" = '*/5 * * * *'
  task "It never runs two jobs at once" "Nunca ejecuta dos jobs a la vez" \
       "spec.concurrencyPolicy: Forbid" "spec.concurrencyPolicy: Forbid" \
       test "$(jpn cronjob backup -o jsonpath='{.spec.concurrencyPolicy}')" = Forbid
  task "It keeps 2 successful and 1 failed job" "Guarda 2 jobs correctos y 1 fallido" \
       "successfulJobsHistoryLimit: 2, failedJobsHistoryLimit: 1" "successfulJobsHistoryLimit: 2, failedJobsHistoryLimit: 1" \
       test "$(jpn cronjob backup -o jsonpath='{.spec.successfulJobsHistoryLimit}/{.spec.failedJobsHistoryLimit}')" = 2/1
  task "A job is killed after 60 seconds" "Un job se corta a los 60 segundos" \
       "spec.jobTemplate.spec.activeDeadlineSeconds: 60" "spec.jobTemplate.spec.activeDeadlineSeconds: 60" \
       test "$(jpn cronjob backup -o jsonpath='{.spec.jobTemplate.spec.activeDeadlineSeconds}')" = 60 ;;
2)
  header "Drill 2 · Init container and native sidecar" "Ejercicio 2 · Init container y sidecar nativo"
  task "Pod web has an init container that writes index.html" "El Pod web tiene un init container que escribe index.html" \
       "initContainers: one container that writes into a shared emptyDir" "initContainers: un contenedor que escribe en un emptyDir compartido" \
       test -n "$(jpn pod web -o jsonpath='{.spec.initContainers[?(@.name=="init")].name}')"
  task "Its log shipper is a native sidecar (init container with restartPolicy Always)" "Su log shipper es un sidecar nativo (init container con restartPolicy Always)" \
       "Add an initContainers entry named logs with restartPolicy: Always" "Añade en initContainers uno llamado logs con restartPolicy: Always" \
       test "$(jpn pod web -o jsonpath='{.spec.initContainers[?(@.name=="logs")].restartPolicy}')" = Always
  task "Pod web is Running with all containers ready" "El Pod web está Running con todos los contenedores listos" \
       "kubectl describe pod web -n $ns and read the events" "kubectl describe pod web -n $ns y lee los eventos" \
       test "$(jpn pod web -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = True ;;
3)
  header "Drill 3 · SecurityContext" "Ejercicio 3 · SecurityContext"
  task "Pod api runs as user 1000 and never as root" "El Pod api corre como usuario 1000 y nunca como root" \
       "spec.securityContext: runAsUser: 1000, runAsNonRoot: true" "spec.securityContext: runAsUser: 1000, runAsNonRoot: true" \
       test "$(jpn pod api -o jsonpath='{.spec.securityContext.runAsUser}/{.spec.securityContext.runAsNonRoot}')" = 1000/true
  task "Its container has a read-only root filesystem" "Su contenedor tiene el sistema de ficheros raíz de solo lectura" \
       "containers[0].securityContext.readOnlyRootFilesystem: true" "containers[0].securityContext.readOnlyRootFilesystem: true" \
       test "$(jpn pod api -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}')" = true
  task "It drops ALL capabilities and cannot escalate" "Quita TODAS las capabilities y no puede escalar privilegios" \
       "capabilities.drop: [ALL], allowPrivilegeEscalation: false" "capabilities.drop: [ALL], allowPrivilegeEscalation: false" \
       test "$(jpn pod api -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop[0]}/{.spec.containers[0].securityContext.allowPrivilegeEscalation}')" = ALL/false
  task "Pod api is Running" "El Pod api está Running" \
       "A read-only image may need an emptyDir on /tmp" "Una imagen de solo lectura puede necesitar un emptyDir en /tmp" \
       test "$(jpn pod api -o jsonpath='{.status.phase}')" = Running ;;
4)
  header "Drill 4 · ResourceQuota and LimitRange" "Ejercicio 4 · ResourceQuota y LimitRange"
  task "ResourceQuota team caps the namespace at 2 CPU, 2Gi and 10 pods" "La ResourceQuota team limita el namespace a 2 CPU, 2Gi y 10 pods" \
       "kubectl create quota team --hard=limits.cpu=2,limits.memory=2Gi,pods=10 -n $ns" "kubectl create quota team --hard=limits.cpu=2,limits.memory=2Gi,pods=10 -n $ns" \
       test "$(jpn resourcequota team -o jsonpath='{.spec.hard.limits\.cpu}/{.spec.hard.limits\.memory}/{.spec.hard.pods}')" = 2/2Gi/10
  task "LimitRange defaults gives every container 250m / 256Mi limits" "La LimitRange defaults da a cada contenedor límites de 250m / 256Mi" \
       "kind: LimitRange, type: Container, default: {cpu: 250m, memory: 256Mi}" "kind: LimitRange, type: Container, default: {cpu: 250m, memory: 256Mi}" \
       test "$(jpn limitrange defaults -o jsonpath='{.spec.limits[0].default.cpu}/{.spec.limits[0].default.memory}')" = 250m/256Mi
  task "Deployment worker (3 replicas, no resources in its spec) has 3 pods running" "El Deployment worker (3 réplicas, sin resources en su spec) tiene 3 pods en marcha" \
       "Without the LimitRange the quota rejects pods that set no limits" "Sin la LimitRange, la quota rechaza pods sin límites" \
       deploy_ready "$ns" worker ;;
5)
  header "Drill 5 · Ingress" "Ejercicio 5 · Ingress"
  task "Ingress shop sends shop.ckad.local/ to Service web:80" "El Ingress shop manda shop.ckad.local/ al Service web:80" \
       "kubectl create ingress shop --class=nginx --rule='shop.ckad.local/*=web:80' -n $ns" "kubectl create ingress shop --class=nginx --rule='shop.ckad.local/*=web:80' -n $ns" \
       test "$(jpn ingress shop -o jsonpath='{.spec.rules[0].host}/{.spec.rules[0].http.paths[0].backend.service.name}:{.spec.rules[0].http.paths[0].backend.service.port.number}')" = shop.ckad.local/web:80
  task "It uses ingressClassName nginx" "Usa ingressClassName nginx" \
       "spec.ingressClassName: nginx" "spec.ingressClassName: nginx" \
       test "$(jpn ingress shop -o jsonpath='{.spec.ingressClassName}')" = nginx
  task "/api goes to Service api:8080 with pathType Prefix" "/api va al Service api:8080 con pathType Prefix" \
       "Add a second path to the same rule" "Añade una segunda ruta a la misma regla" \
       test "$(jpn ingress shop -o jsonpath='{.spec.rules[0].http.paths[?(@.path=="/api")].backend.service.name}{.spec.rules[0].http.paths[?(@.path=="/api")].pathType}')" = apiPrefix
  task "Service web exists and has endpoints" "El Service web existe y tiene endpoints" \
       "kubectl create deploy web --image=nginx:1.27 -n $ns && kubectl expose deploy web --port=80 -n $ns" "kubectl create deploy web --image=nginx:1.27 -n $ns && kubectl expose deploy web --port=80 -n $ns" \
       endpoints_ready "$ns" web ;;
6)
  header "Drill 6 · Kustomize" "Ejercicio 6 · Kustomize"
  task "The prod overlay runs 3 replicas of Deployment web" "El overlay prod ejecuta 3 réplicas del Deployment web" \
       "kubectl apply -k ckad/kustomize/overlays/prod after setting replicas in the overlay" "kubectl apply -k ckad/kustomize/overlays/prod tras poner las réplicas en el overlay" \
       test "$(jpn deploy prod-web -o jsonpath='{.spec.replicas}')" = 3
  task "Every resource carries the label env=prod" "Todos los recursos llevan la etiqueta env=prod" \
       "labels: (or commonLabels:) in the overlay kustomization.yaml" "labels: (o commonLabels:) en el kustomization.yaml del overlay" \
       test "$(jpn deploy prod-web -o jsonpath='{.metadata.labels.env}')$(jpn configmap -l env=prod -o name | wc -l | tr -d ' ')" = prod1
  task "The image is nginx:1.27-alpine" "La imagen es nginx:1.27-alpine" \
       "images: - name: nginx, newTag: 1.27-alpine" "images: - name: nginx, newTag: 1.27-alpine" \
       test "$(jpn deploy prod-web -o jsonpath='{.spec.template.spec.containers[0].image}')" = nginx:1.27-alpine ;;
7)
  header "Drill 7 · Helm" "Ejercicio 7 · Helm"
  task "Release web (chart podinfo/podinfo) is deployed in $ns" "La release web (chart podinfo/podinfo) está desplegada en $ns" \
       "helm repo add podinfo https://stefanprodan.github.io/podinfo && helm install web podinfo/podinfo -n $ns" "helm repo add podinfo https://stefanprodan.github.io/podinfo && helm install web podinfo/podinfo -n $ns" \
       bash -c "helm --kube-context $CTX status web -n $ns -o json | grep -q '\"status\":\"deployed\"'"
  task "It runs 2 replicas, set through values" "Corre 2 réplicas, fijadas por values" \
       "helm upgrade web podinfo/podinfo -n $ns --reuse-values --set replicaCount=2" "helm upgrade web podinfo/podinfo -n $ns --reuse-values --set replicaCount=2" \
       deploy_ready "$ns" web-podinfo
  task "Release web is at revision 2 or later" "La release web va por la revisión 2 o posterior" \
       "An upgrade creates a new revision; helm history web -n $ns" "Un upgrade crea una revisión nueva; helm history web -n $ns" \
       bash -c "helm --kube-context $CTX history web -n $ns -o json | grep -q '\"revision\":2'" ;;
8)
  header "Drill 8 · Canary" "Ejercicio 8 · Canary"
  task "Service shop selects app=shop only (both versions)" "El Service shop selecciona solo app=shop (las dos versiones)" \
       "Selector app=shop, without version" "Selector app=shop, sin version" \
       test "$(jpn svc shop -o jsonpath='{.spec.selector}')" = '{"app":"shop"}'
  task "shop-v1 runs 4 replicas and shop-v2 runs 1 (20 % canary)" "shop-v1 corre 4 réplicas y shop-v2 corre 1 (canary del 20 %)" \
       "kubectl scale deploy shop-v1 --replicas=4; shop-v2 --replicas=1" "kubectl scale deploy shop-v1 --replicas=4; shop-v2 --replicas=1" \
       test "$(jpn deploy shop-v1 -o jsonpath='{.status.availableReplicas}')/$(jpn deploy shop-v2 -o jsonpath='{.status.availableReplicas}')" = 4/1
  task "The Service has 5 endpoints" "El Service tiene 5 endpoints" \
       "Both Deployments need the label app=shop on the pod template" "Los dos Deployments necesitan app=shop en la plantilla del pod" \
       test "$(jp endpointslices -n "$ns" -l kubernetes.io/service-name=shop -o jsonpath='{range .items[*].endpoints[*]}x{end}' | wc -c | tr -d ' ')" = 5 ;;
9)
  header "Drill 9 · ServiceAccount and RBAC" "Ejercicio 9 · ServiceAccount y RBAC"
  task "ServiceAccount reader exists" "Existe el ServiceAccount reader" \
       "kubectl create sa reader -n $ns" "kubectl create sa reader -n $ns" \
       exists sa reader -n "$ns"
  task "reader can list pods in $ns" "reader puede listar pods en $ns" \
       "kubectl create role pod-reader --verb=get,list,watch --resource=pods; then a rolebinding" "kubectl create role pod-reader --verb=get,list,watch --resource=pods; luego un rolebinding" \
       test "$(k auth can-i list pods -n "$ns" --as=system:serviceaccount:$ns:reader)" = yes
  task "reader cannot delete pods" "reader no puede borrar pods" \
       "Only get, list, watch" "Solo get, list, watch" \
       test "$(k auth can-i delete pods -n "$ns" --as=system:serviceaccount:$ns:reader)" = no
  task "Pod probe runs with ServiceAccount reader and no auto-mounted token" "El Pod probe usa el ServiceAccount reader sin token montado automáticamente" \
       "spec.serviceAccountName: reader, automountServiceAccountToken: false" "spec.serviceAccountName: reader, automountServiceAccountToken: false" \
       test "$(jpn pod probe -o jsonpath='{.spec.serviceAccountName}/{.spec.automountServiceAccountToken}')" = reader/false ;;
10)
  header "Drill 10 · Fix a broken app" "Ejercicio 10 · Arreglar una app rota"
  task "Deployment broken has all replicas available" "El Deployment broken tiene todas sus réplicas disponibles" \
       "Start with kubectl get, describe, logs --previous and events" "Empieza por kubectl get, describe, logs --previous y los eventos" \
       deploy_ready "$ns" broken
  task "It has a readiness probe on /healthz port 8080" "Tiene una readiness probe en /healthz puerto 8080" \
       "readinessProbe.httpGet: {path: /healthz, port: 8080}" "readinessProbe.httpGet: {path: /healthz, port: 8080}" \
       test "$(jpn deploy broken -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}:{.spec.template.spec.containers[0].readinessProbe.httpGet.port}')" = /healthz:8080 ;;
11)
  header "Drill 11 · CRD and custom resource" "Ejercicio 11 · CRD y recurso propio"
  task "CRD backups.ckad.lab is established" "La CRD backups.ckad.lab está establecida" \
       "kubectl apply -f ckad/crd/backup-crd.yaml after fixing it" "kubectl apply -f ckad/crd/backup-crd.yaml tras arreglarla" \
       test "$(jp crd backups.ckad.lab -o jsonpath='{.status.conditions[?(@.type=="Established")].status}')" = True
  task "Backup nightly exists in $ns with schedule '0 2 * * *'" "El Backup nightly existe en $ns con schedule '0 2 * * *'" \
       "kind: Backup, apiVersion: ckad.lab/v1" "kind: Backup, apiVersion: ckad.lab/v1" \
       test "$(jpn backup nightly -o jsonpath='{.spec.schedule}')" = '0 2 * * *' ;;
12)
  header "Drill 12 · Build and run your own image" "Ejercicio 12 · Construir y ejecutar tu imagen"
  task "Pod hello runs image ckad/hello:v1 with imagePullPolicy Never" "El Pod hello usa la imagen ckad/hello:v1 con imagePullPolicy Never" \
       "docker build -t ckad/hello:v1 ckad/image && kind load docker-image ckad/hello:v1 --name lab" "docker build -t ckad/hello:v1 ckad/image && kind load docker-image ckad/hello:v1 --name lab" \
       test "$(jpn pod hello -o jsonpath='{.spec.containers[0].image}/{.spec.containers[0].imagePullPolicy}/{.status.phase}')" = ckad/hello:v1/Never/Running
  task "ConfigMap greeting is mounted as env var GREETING" "La ConfigMap greeting está montada como variable GREETING" \
       "env: - name: GREETING, valueFrom.configMapKeyRef" "env: - name: GREETING, valueFrom.configMapKeyRef" \
       test "$(jpn pod hello -o jsonpath='{.spec.containers[0].env[?(@.name=="GREETING")].valueFrom.configMapKeyRef.name}')" = greeting ;;
*) echo "Drills: 1-12"; exit 1 ;;
esac
finish "ckad-$n"
