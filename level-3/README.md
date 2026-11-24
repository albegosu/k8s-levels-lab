# Level 3 · Networking

[Español](README.es.md)

Needs `level-2/web.yaml` applied. The `gateway` add-on is installed by `./lab.sh up`.

**See it first:** the [path of a request](https://albegosu.github.io/k8s-levels-lab/request.html) shows every hop and what each fault looks like from `curl`.

## Concepts

- **Service.** A stable IP and DNS name in front of a group of pods, found by labels. It only sends traffic to **ready** pods; with none, its endpoints are empty and requests fail.
- **Cluster DNS.** Every Service gets `<service>.<namespace>.svc.cluster.local`.
- **Gateway API.** The successor of Ingress. **GatewayClass** and **Gateway** belong to the platform team; each app owns its **HTTPRoute** (host, paths, backend Service). Here the controller is **Envoy Gateway**.
- In the cloud, the Envoy Service becomes a load balancer that usually terminates TLS, and **ExternalDNS** creates the DNS record from the HTTPRoute. kind has neither, so we use `port-forward` and a `Host` header.
- **NetworkPolicy.** A firewall between pods. By default every pod can talk to every pod.

## Service and DNS

```bash
kubectl apply -f level-3/service.yaml
kubectl get svc,endpointslices -n shop
kubectl run client --rm -it --image=busybox:1.36 -n sandbox -- wget -qO- shop-web.shop
kubectl scale deployment shop-web --replicas=0 -n shop
kubectl get endpointslices -n shop   # no endpoints: the Service has nowhere to send traffic
kubectl scale deployment shop-web --replicas=2 -n shop
```

## Gateway API with Envoy

```bash
kubectl get gatewayclass
kubectl get gateway -n envoy-gateway-system
kubectl apply -f level-3/httproute.yaml
kubectl describe httproute shop-web -n shop   # Accepted and ResolvedRefs set to True
SVC=$(kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=internal -o name)
kubectl port-forward -n envoy-gateway-system $SVC 8080:80
```

In another terminal:

```bash
curl -s -H 'Host: shop.lab.local' localhost:8080 | head
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: other.lab.local' localhost:8080   # 404: no route
```

The Envoy Service shows `EXTERNAL-IP <pending>`: on kind there is nobody to create a load balancer.

## NetworkPolicy

```bash
kubectl apply -f level-3/networkpolicy.yaml
kubectl run client --rm -it --image=busybox:1.36 -n sandbox -- wget -qO- -T 3 shop-web.shop   # now it fails
curl -s -H 'Host: shop.lab.local' localhost:8080 | head                                         # through Envoy it still works
kubectl delete -f level-3/networkpolicy.yaml
```

## Check your work

```bash
./lab.sh check 3
```

It checks the endpoints and the HTTPRoute status, and sends a real request through Envoy from inside the cluster.

## Check yourself

- [ ] Why does a Service with no endpoints fail even if the Deployment exists?
- [ ] Walk a request from the browser to the pod, naming every piece.
- [ ] Which objects belong to the platform team and which to each app?
