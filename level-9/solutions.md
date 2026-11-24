# Level 9 solutions

| App | Symptom | Cause | Level | Fix |
| --- | --- | --- | --- | --- |
| `api` | `CrashLoopBackOff` | The app exits with an error; `logs --previous` says `DATABASE_URL` is not set | 2 and 4 | Add the key to the secret manager and to the ExternalSecret |
| `worker` | `OOMKilled` and restarts | It allocates 200 MiB with a 64Mi limit | 2 | Raise `resources.limits.memory` in the chart values |
| `web` | Pods `Running`, Service does not answer | The Service selector (`app: frontend`) does not match the pod labels (`app: web`): no endpoints | 3 | Fix the Service template |
| `reports` | `Pending` | `nodeSelector` asks for a `gpu` NodePool that does not exist: `didn't match Pod's node affinity/selector` | 5 | Fix the `nodeSelector`, or create that NodePool |
| `queue` | `CreateContainerConfigError` | The `queue-credentials` Secret does not exist | 4 | Create its ExternalSecret and the secret at the source |
