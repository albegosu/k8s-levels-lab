# Nivel 3 · Red

[English](README.md)

Necesita `level-2/web.yaml` aplicado. El addon `gateway` lo instala `./lab.sh up`.

## Conceptos

- **Service.** Una IP y un nombre DNS fijos delante de un grupo de pods, que encuentra por labels. Solo envía tráfico a pods **listos**; si no hay ninguno, sus endpoints quedan vacíos y las peticiones fallan.
- **DNS del clúster.** Cada Service recibe `<service>.<namespace>.svc.cluster.local`.
- **Gateway API.** La sucesora de Ingress. **GatewayClass** y **Gateway** son del equipo de plataforma; cada app tiene su **HTTPRoute** (host, paths, Service de destino). Aquí el controlador es **Envoy Gateway**.
- En la nube, el Service de Envoy se convierte en un balanceador que suele terminar TLS, y **ExternalDNS** crea el registro DNS a partir de la HTTPRoute. kind no tiene ninguna de las dos cosas, así que usamos `port-forward` y una cabecera `Host`.
- **NetworkPolicy.** Un cortafuegos entre pods. Por defecto todo pod puede hablar con todo pod.

## Service y DNS

```bash
kubectl apply -f level-3/service.yaml
kubectl get svc,endpointslices -n shop
kubectl run client --rm -it --image=busybox:1.36 -n sandbox -- wget -qO- shop-web.shop
kubectl scale deployment shop-web --replicas=0 -n shop
kubectl get endpointslices -n shop   # sin endpoints: el Service no tiene a quién mandar
kubectl scale deployment shop-web --replicas=2 -n shop
```

## Gateway API con Envoy

```bash
kubectl get gatewayclass
kubectl get gateway -n envoy-gateway-system
kubectl apply -f level-3/httproute.yaml
kubectl describe httproute shop-web -n shop   # Accepted y ResolvedRefs a True
SVC=$(kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=internal -o name)
kubectl port-forward -n envoy-gateway-system $SVC 8080:80
```

En otra terminal:

```bash
curl -s -H 'Host: shop.lab.local' localhost:8080 | head
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: other.lab.local' localhost:8080   # 404: ninguna ruta
```

El Service de Envoy sale con `EXTERNAL-IP <pending>`: en kind no hay quien cree un balanceador.

## NetworkPolicy

```bash
kubectl apply -f level-3/networkpolicy.yaml
kubectl run client --rm -it --image=busybox:1.36 -n sandbox -- wget -qO- -T 3 shop-web.shop   # ahora falla
curl -s -H 'Host: shop.lab.local' localhost:8080 | head                                         # por Envoy sigue entrando
kubectl delete -f level-3/networkpolicy.yaml
```

## Corrige tu trabajo

```bash
LAB_LANG=es ./lab.sh check 3
```

Comprueba los endpoints y el estado de la HTTPRoute, y lanza una petición real a través de Envoy desde dentro del clúster.

## Comprueba que lo has entendido

- [ ] ¿Por qué falla un Service sin endpoints aunque el Deployment exista?
- [ ] Recorre una petición desde el navegador hasta el pod, nombrando cada pieza.
- [ ] ¿Qué objetos son del equipo de plataforma y cuáles de cada app?
