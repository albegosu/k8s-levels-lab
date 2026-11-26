# Nivel 10 · Soluciones

[English](solutions.md)

Ábrelo solo cuando hayas escrito tu propio diagnóstico. Cada avería sigue los cinco pasos de la nota de inferencia 25 y termina con el mensaje para el cliente (nota 26). Lo que ven los usuarios depende de si ya arreglaste el fallback de `team-a` (tarea 5): con él, casi todas las averías pasan de «caído» a «lento», y justo por eso los fallbacks necesitan su propia alerta.

## 1 · El servidor de modelos muere por OOMKilled

- **Métrica:** 5xx en el gateway o, con el fallback funcionando, todas las peticiones servidas despacio por `qwen-backup` (un solo slot) y la alerta `FallbackInUse`.
- **Capa:** el motor. `kubectl get pods -n inference` muestra `qwen` en `CrashLoopBackOff`; `kubectl describe pod -l app=qwen -n inference` dice `Last State: Terminated, Reason: OOMKilled`.
- **Fase / techo:** ninguno de los techos de capacidad: el servidor no llega a arrancar. Límite de memoria de 150Mi para un modelo que necesita unos 500 MiB.
- **Cambio:** alguien bajó el límite de memoria (`kubectl rollout history deploy/qwen -n inference`). Con `maxSurge: 0` se quitó primero el pod viejo y sano, así que el rollout malo se convirtió en una caída.
- **Arreglo:** `kubectl set resources deploy/qwen -n inference -c llama --requests=memory=512Mi --limits=memory=1Gi`, o volver a aplicar `model.yaml`.
- **Al cliente:** «De 10:05 a 10:20 el servidor principal del modelo no pudo arrancar tras un cambio de configuración, y vuestras peticiones las atendió el servidor de respaldo, más pequeño, así que fueron más lentas. Hemos restaurado la configuración y los tiempos han vuelto a la normalidad. Vamos a añadir una comprobación para que un servidor que no arranca no sustituya a uno que funciona.»
- **Gemelo en producción:** pods de vLLM con OOMKilled en el lado del host (RAM de CPU, no memoria de GPU) cuando crecen `--swap-space` o los workers del tokenizador; o un out-of-memory de GPU al arrancar con un `--gpu-memory-utilization` demasiado alto.

## 2 · El gateway apunta al puerto equivocado

- **Métrica:** cada petición tarda unos 60 s y luego funciona (con fallback) o falla a los 60 s por timeout (sin él). Se dispara la latencia p95 del gateway; salta `FallbackInUse`.
- **Capa:** el gateway. `qwen` está sano y ocioso (`llamacpp:requests_processing` a 0) mientras `qwen-backup` hace todo el trabajo. Las métricas del motor de `qwen` no explican nada porque no le llega tráfico.
- **Evidencia:** `kubectl logs deploy/litellm -n inference` muestra errores de conexión y timeouts hacia `http://qwen.inference:8000/v1`; `litellm_deployment_state` para ese `api_base` no es 0. El Service escucha en 8080. El tráfico a un puerto que el Service no expone se descarta en silencio, así que acaba en timeout y no en un «connection refused» rápido.
- **Cambio:** se editó el ConfigMap `litellm-config` y se reinició el gateway.
- **Arreglo:** volver a poner `8080` en el ConfigMap (`kubectl edit configmap litellm-config -n inference`) **y** `kubectl rollout restart deploy/litellm -n inference`: la configuración se monta con `subPath`, así que el pod no ve los cambios del ConfigMap hasta que se reinicia.
- **Al cliente:** «Desde las 10:05 las peticiones tardaban alrededor de un minuto porque un cambio de configuración las mandaba a una dirección equivocada del servidor principal; tras esperar, pasaban al servidor de respaldo. Lo corregimos a las 10:25. Revisaremos los cambios de configuración del gateway antes de aplicarlos.»
- **Lecciones:** un fallback convierte una caída en lentitud, que es mejor para los usuarios y peor para detectarlo; pon un `request_timeout` que los usuarios puedan soportar y alerta sobre los fallbacks.

## 3 · El contexto por slot es demasiado pequeño

- **Métrica:** las preguntas cortas funcionan; las largas (`LONG=1 ./level-10/load.sh 2`) fallan con 400 o, si el fallback está permitido, las responde despacio `qwen-backup`. Solo se queja el tenant tipo RAG.
- **Capa:** el motor. `kubectl logs deploy/qwen -n inference | grep n_ctx_slot` muestra `n_ctx_slot = 256` en lugar de 1024; el cuerpo del error dice que la petición supera el contexto disponible.
- **Fase / techo:** memoria, por configuración: `--ctx-size 1024` repartido en 4 slots deja 256 tokens por petición, y el prompt largo tiene unos 700.
- **Cambio:** se bajó `--ctx-size` en el Deployment (`kubectl rollout history`, o compáralo con `model.yaml`).
- **Arreglo:** restaurar `--ctx-size 4096` (aplicar `model.yaml`). El compromiso es el de la nota de inferencia 20: contexto total ÷ slots = contexto por petición. Más slots significa más usuarios a la vez, cada uno con menos contexto.
- **Al cliente:** «Desde las 10:05 fallaban las peticiones que incluían documentos largos, porque un cambio redujo la longitud máxima de cada petición. Las peticiones cortas no se vieron afectadas. Restauramos el límite a las 10:20; las peticiones largas de hasta unos 1.000 tokens vuelven a funcionar.»
- **Gemelo en producción:** un `--max-model-len` más bajo que lo que envían los clientes, o una aplicación nueva que de repente manda prompts de 60k tokens a un servidor dimensionado para 8k (caso de inferencia 2).

## 4 · Un slot en lugar de cuatro

- **Métrica:** ningún error. La latencia crece con la carga y los tokens/s totales bajan: `./level-10/load.sh 4 8` tarda unas cuatro veces más que antes.
- **Capa / fase:** el motor, esperando. `llamacpp:requests_processing` nunca pasa de 1; `llamacpp:requests_deferred` está en 3 o más con carga; al rato salta `ModelRequestsQueued`.
- **Techo:** capacidad, por configuración: `--parallel 1` (`n_slots = 1` en el log). Sin batching, desaparece la ganancia de throughput de la tarea 4.
- **Arreglo:** restaurar `--parallel 4`.
- **Al cliente:** «Desde las 10:05 el modelo atendía una petición a la vez en lugar de cuatro, así que en los momentos de más uso las peticiones esperaban en cola. No ha fallado nada, pero las respuestas han tardado hasta cuatro veces más. Restauramos la configuración a las 10:20.»
- **Gemelo en producción:** un `--max-num-seqs` demasiado bajo, o una KV cache demasiado pequeña para las longitudes de contexto en uso: el motor parece sano y simplemente encola (caso de inferencia 1).

## 5 · Postgres está caído

- **Métrica:** en uno o dos minutos todos los tenants reciben `503 no_db_connection` («the authentication database is temporarily unreachable»). Las primeras peticiones pueden pasar aún, porque LiteLLM guarda en caché un rato las claves usadas hace poco. Los servidores de modelos están ociosos y sanos.
- **Capa:** la dependencia del gateway. `kubectl get pods -n inference`: `postgres-0` no está y `litellm` está `0/1` Ready (su readiness incluye la base de datos), así que el Service `litellm` tampoco tiene endpoints.
- **Cambio:** el StatefulSet se escaló a 0 (`kubectl get sts postgres -n inference`).
- **Arreglo:** `kubectl scale sts/postgres -n inference --replicas=1`. El gateway se recupera solo en un minuto; claves, equipos y gasto siguen en el PVC.
- **Al cliente:** «De 10:05 a 10:15 se rechazaron todas las peticiones porque estaba caída la base de datos con la que el gateway comprueba las claves de API. Los modelos estaban bien. Reiniciamos la base de datos y no se ha perdido nada. Vamos a pasarla a una configuración de alta disponibilidad.»
- **Lecciones:** la base de datos del gateway está en el camino de cada petición: córrela en alta disponibilidad (CloudNativePG o una base de datos gestionada), haz copias de seguridad, alerta sobre ella y ten claro que sin ella nadie puede autenticarse.
