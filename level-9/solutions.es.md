# Soluciones del nivel 9

| App | Síntoma | Causa | Nivel | Arreglo |
| --- | --- | --- | --- | --- |
| `api` | `CrashLoopBackOff` | La app sale con error; `logs --previous` dice que falta `DATABASE_URL` | 2 y 4 | Añadir la clave al gestor de secretos y a la ExternalSecret |
| `worker` | `OOMKilled` y reinicios | Reserva 200 MiB con un limit de 64Mi | 2 | Subir `resources.limits.memory` en los values del chart |
| `web` | Pods `Running`, el Service no responde | El selector del Service (`app: frontend`) no coincide con las labels de los pods (`app: web`): sin endpoints | 3 | Corregir la plantilla del Service |
| `reports` | `Pending` | El `nodeSelector` pide un NodePool `gpu` que no existe: `didn't match Pod's node affinity/selector` | 5 | Corregir el `nodeSelector` o crear ese NodePool |
| `queue` | `CreateContainerConfigError` | No existe el Secret `queue-credentials` | 4 | Crear su ExternalSecret y el secreto en origen |
