# Level 10 · Solutions

[Español](solutions.es.md)

Open this only after writing your own diagnosis. Each fault follows the five steps of inference note 25 and ends with the message to the customer (note 26). What users see depends on whether you already fixed the fallback for `team-a` (task 5): with it, most faults turn into "slow" instead of "down", which is exactly why fallbacks need their own alert.

## 1 · The model server is OOMKilled

- **Metric:** gateway 5xx, or, with the fallback working, every request served slowly by `qwen-backup` (one slot) and the `FallbackInUse` alert.
- **Layer:** the engine. `kubectl get pods -n inference` shows `qwen` in `CrashLoopBackOff`; `kubectl describe pod -l app=qwen -n inference` says `Last State: Terminated, Reason: OOMKilled`.
- **Phase / ceiling:** none of the capacity ceilings: the server never starts. Memory limit 150Mi against a model that needs about 500 MiB.
- **Change:** someone lowered the memory limit (`kubectl rollout history deploy/qwen -n inference`). With `maxSurge: 0` the old, healthy pod was removed first, so the bad rollout became an outage.
- **Fix:** `kubectl set resources deploy/qwen -n inference -c llama --requests=memory=512Mi --limits=memory=1Gi`, or apply `model.yaml` again.
- **To the customer:** "From 10:05 to 10:20 the main model server could not start after a configuration change, and your requests were served by the smaller backup server, so they were slower. We restored the configuration; response times are back to normal. We are adding a check so a server that cannot start does not replace a working one."
- **Production twin:** vLLM pods OOMKilled on the host side (CPU RAM, not GPU memory) when `--swap-space` or the tokenizer workers grow; or a GPU out-of-memory at start-up with too high `--gpu-memory-utilization`.

## 2 · The gateway points to the wrong port

- **Metric:** every request takes about 60 s and then succeeds (with the fallback), or fails after 60 s with a timeout (without it). Gateway p95 latency jumps; `FallbackInUse` fires.
- **Layer:** the gateway. `qwen` is healthy and idle (`llamacpp:requests_processing` 0) while `qwen-backup` does all the work. The engine metrics of `qwen` explain nothing because no traffic reaches it.
- **Evidence:** `kubectl logs deploy/litellm -n inference` shows connection errors and timeouts towards `http://qwen.inference:8000/v1`; `litellm_deployment_state` for that `api_base` is not 0. The Service listens on 8080. Traffic to a port the Service does not expose is silently dropped, so it ends in a timeout instead of a quick "connection refused".
- **Change:** the `litellm-config` ConfigMap was edited and the gateway restarted.
- **Fix:** put back `8080` in the ConfigMap (`kubectl edit configmap litellm-config -n inference`) **and** `kubectl rollout restart deploy/litellm -n inference`: the config is mounted with `subPath`, so the pod never sees ConfigMap changes until it restarts.
- **To the customer:** "Since 10:05 requests took about a minute because a configuration change sent them to the wrong address of the main server; after waiting, they went to the backup server. We corrected it at 10:25. We will review gateway configuration changes before they are applied."
- **Lessons:** a fallback turns an outage into slowness, which is better for users and worse for detection; set `request_timeout` to something users can bear, and alert on fallbacks.

## 3 · The context per slot is too small

- **Metric:** short questions work; long ones (`LONG=1 ./level-10/load.sh 2`) fail with 400, or, if the fallback is allowed, are answered slowly by `qwen-backup`. Only the RAG-like tenant complains.
- **Layer:** the engine. `kubectl logs deploy/qwen -n inference | grep n_ctx_slot` shows `n_ctx_slot = 256` instead of 1024; the error body says the request exceeds the available context size.
- **Phase / ceiling:** memory, by configuration: `--ctx-size 1024` split into 4 slots leaves 256 tokens per request, while the long prompt is about 700.
- **Change:** `--ctx-size` was lowered in the Deployment (`kubectl rollout history`, or compare with `model.yaml`).
- **Fix:** restore `--ctx-size 4096` (apply `model.yaml`). The trade-off is the one in inference note 20: total context ÷ slots = context per request. More slots means more users at once, each with a shorter context.
- **To the customer:** "Since 10:05 requests that include long documents failed, because a change reduced the maximum length each request can have. Short requests were not affected. We restored the limit at 10:20; long requests up to about 1,000 tokens work again."
- **Production twin:** `--max-model-len` set lower than what the clients send, or a new client app that suddenly sends 60k-token prompts to a server sized for 8k (inference case 2).

## 4 · One slot instead of four

- **Metric:** no errors at all. Latency grows with load and total tokens/s drops: `./level-10/load.sh 4 8` takes about four times longer than before.
- **Layer / phase:** the engine, waiting. `llamacpp:requests_processing` never goes above 1; `llamacpp:requests_deferred` is 3 or more under load; `ModelRequestsQueued` fires after a while.
- **Ceiling:** capacity, by configuration: `--parallel 1` (`n_slots = 1` in the log). Batching is gone, so the throughput gain of task 4 disappears.
- **Fix:** restore `--parallel 4`.
- **To the customer:** "Since 10:05 the model was answering one request at a time instead of four, so at busy moments requests waited in a queue. Nothing failed, but answers took up to four times longer. We restored the configuration at 10:20."
- **Production twin:** `--max-num-seqs` set too low, or a KV cache too small for the context lengths in use: the engine looks healthy and simply queues (inference case 1).

## 5 · Postgres is down

- **Metric:** within a minute or two every tenant gets `503 no_db_connection` ("the authentication database is temporarily unreachable"). The first requests may still pass, because LiteLLM caches recently used keys for a short time. Model servers are idle and healthy.
- **Layer:** the gateway's dependency. `kubectl get pods -n inference`: `postgres-0` is gone and `litellm` is `0/1` Ready (its readiness check includes the database), so the `litellm` Service has no endpoints either.
- **Change:** the StatefulSet was scaled to 0 (`kubectl get sts postgres -n inference`).
- **Fix:** `kubectl scale sts/postgres -n inference --replicas=1`. The gateway recovers by itself within a minute; keys, teams and spend are intact on the PVC.
- **To the customer:** "From 10:05 to 10:15 all requests were rejected because the database the gateway uses to check API keys was down. The models themselves were fine. We restarted the database; nothing was lost. We are moving the database to a highly available setup."
- **Lessons:** the gateway database is in the request path of every call: run it highly available (CloudNativePG or a managed database), back it up, alert on it, and know that without it nobody can authenticate.
