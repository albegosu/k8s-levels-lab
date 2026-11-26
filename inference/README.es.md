# Notas de inferencia

[English](README.md)

Notas cortas sobre cómo se sirven los LLM: un concepto por nota, que se lee en unos 15 minutos, con algo para probar y tres preguntas para comprobar lo aprendido. Léelas en orden: cada una se apoya en las anteriores. No necesitas el clúster kind para seguirlas.

**Las notas están en inglés.** Este índice y las instrucciones para ejecutar los ejemplos están en español.

## Para qué sirve este recorrido

No es una lista de respuestas. Los clientes de inferencia traerán preguntas y problemas que nadie ha escrito todavía. El recorrido construye las tres capacidades que hacen falta para ellos:

1. **Entender** cómo se sirve un modelo, hasta la memoria, el ancho de banda, el cómputo y las colas (fases 1 y 2).
2. **Razonar** desde unas pocas ecuaciones hasta una respuesta que nunca has visto, y saber qué preguntar primero (fase 3, empezando por la [nota 18](notes/18-first-principles.md)).
3. **Practicar** estimar, diagnosticar y explicar, en papel y a ciegas, antes de que haya un cliente esperando ([práctica](practice/README.md)).

La fase 3 cubre lo que se le pregunta a quien opera: si el modelo X cabe en una H100 o en una B300, cuánta concurrencia, cómo cambia con el modelo y con la GPU, qué vigilar, sobre qué alertar, cómo escalar. Pero cada nota enseña el razonamiento, para que el mismo método sirva con el próximo modelo y la próxima GPU.

Herramientas: [`fit.py`](tools/fit.py), una calculadora de encaje y concurrencia, y un [`PrometheusRule`](manifests/prometheusrule-inference.yaml) con las alertas de la nota 23.

```bash
python3 inference/tools/fit.py --model qwen3-235b-a22b            # encaje y concurrencia en todas las GPUs
python3 inference/tools/fit.py --model llama-3.1-70b --gpu b300   # una GPU en detalle
```

## Recorrido

| Fase | Notas | Conceptos | Fuente principal |
| --- | --- | --- | --- |
| 1 · Qué significa servir un modelo | 01–08 | pesos y parámetros, tokens (prompt y completion), prefill y decode, VRAM y tamaño del modelo, cuantización, ventana de contexto, la API compatible con OpenAI | [Fast & Efficient LLM Inference with vLLM](https://learn.deeplearning.ai/courses/fast-and-efficient-llm-inference-with-vllm) (DeepLearning.AI + Red Hat, 1 h 38 min) |
| 2 · Por qué va rápido o lento | 09–17 | qué importa en una GPU, instancias GPU en AWS, KV cache, PagedAttention, continuous batching, prefix caching, latencia y throughput, tensor parallelism, dimensionado | El mismo curso + [documentación de vLLM](https://docs.vllm.ai/) |
| 3 · Razonarlo y operarlo | 18–27 + [práctica](practice/README.md) | las seis ecuaciones detrás de cada respuesta, si cabe y en qué GPU, la concurrencia y sus dos techos, cómo cambia con el modelo y la GPU, benchmarks, las cuatro capas de métricas, sobre qué alertar, escalado y arranques en frío, un método de diagnóstico, qué preguntar a un cliente, un dimensionado completo; 12 casos a ciegas y 16 ejercicios de estimación | [Documentación de vLLM](https://docs.vllm.ai/), [métricas de vLLM](https://docs.vllm.ai/en/latest/usage/metrics.html), [Prometheus en LiteLLM](https://docs.litellm.ai/docs/proxy/prometheus), [DCGM exporter](https://docs.nvidia.com/datacenter/cloud-native/gpu-telemetry/latest/dcgm-exporter.html) |
| 4 · El gateway y más allá | próximamente | LiteLLM a fondo (claves virtuales, presupuestos, rate limits, fallbacks, enrutado), serving desagregado y distribuido (llm-d, separar prefill y decode, expert parallelism a lo ancho), calidad del modelo y evals tras cuantizar | [Documentación del proxy de LiteLLM](https://docs.litellm.ai/docs/proxy/deploy), [llm-d](https://llm-d.ai/) |

## Notas

| # | Nota |
| --- | --- |
| 01 | [Qué significa servir un modelo](notes/01-serving-a-model.md) |
| 02 | [Tokens](notes/02-tokens.md) |
| 03 | [Tokens de prompt y de completion](notes/03-prompt-vs-completion.md) |
| 04 | [Prefill y decode](notes/04-prefill-and-decode.md) |
| 05 | [VRAM y tamaño del modelo](notes/05-vram-and-model-size.md) |
| 06 | [Cuantización](notes/06-quantization.md) |
| 07 | [Ventana de contexto](notes/07-context-window.md) |
| 08 | [La API compatible con OpenAI](notes/08-openai-compatible-api.md) |
| 09 | [Qué importa en una GPU](notes/09-what-matters-in-a-gpu.md) |
| 10 | [Instancias GPU en AWS](notes/10-gpu-instances-on-aws.md) |
| 11 | [KV cache](notes/11-kv-cache.md) |
| 12 | [PagedAttention](notes/12-pagedattention.md) |
| 13 | [Continuous batching](notes/13-continuous-batching.md) |
| 14 | [Prefix caching](notes/14-prefix-caching.md) |
| 15 | [Latencia y throughput](notes/15-latency-and-throughput.md) |
| 16 | [Tensor parallelism](notes/16-tensor-parallelism.md) |
| 17 | [Ejemplo de dimensionado: un modelo de 70B](notes/17-sizing-example.md) |
| 18 | [Primeros principios: seis ecuaciones detrás de cada respuesta](notes/18-first-principles.md) |
| 19 | [¿Me cabe el modelo X en la GPU Y?](notes/19-does-it-fit.md) |
| 20 | [¿Cuántos usuarios aguanta?](notes/20-how-many-users.md) |
| 21 | [Medirlo: el barrido de concurrencia](notes/21-benchmark.md) |
| 22 | [Visibilidad: qué mirar](notes/22-visibility.md) |
| 23 | [Sobre qué alertar](notes/23-what-to-alert-on.md) |
| 24 | [Escalado y capacidad en Kubernetes](notes/24-scaling.md) |
| 25 | [Un método para «va lento» y «falla»](notes/25-troubleshooting-method.md) |
| 26 | [Hacer las preguntas correctas, y responderlas](notes/26-asking-the-right-questions.md) |
| 27 | [Caso completo: 200 desarrolladores, ¿H100, H200 o B300?](notes/27-journey-h100-or-b300.md) |
| — | [Práctica: ejercicios y casos a ciegas](practice/README.md) |

## Ejecutar los ejemplos

Los ejemplos con `curl` usan dos variables, `BASE_URL` y `KEY`, así que funcionan con cualquier servidor compatible con OpenAI. Lo más sencillo es [Ollama](https://ollama.com/) en tu portátil, con un modelo pequeño:

```bash
brew install ollama
ollama serve &                      # escucha en localhost:11434
ollama pull qwen2.5:0.5b            # unos 400 MB, corre en CPU
export BASE_URL=http://localhost:11434 KEY=unused
curl -s $BASE_URL/v1/models | jq '.data[].id'
```

Usa `qwen2.5:0.5b` donde una nota diga `<model>`. Si tienes acceso a un gateway LiteLLM, pon su URL en `BASE_URL` y tu clave virtual en `KEY`. Dos endpoints solo existen en LiteLLM: `/key/info` (nota 03) y `/v1/model/info` (nota 07). Con Ollama, sáltate esas líneas.

## Formato de cada nota

| Sección | Qué contiene |
| --- | --- |
| **In one line** | La definición, en una frase |
| **The idea** | El concepto en palabras sencillas, con un diagrama o una tabla cuando ayuda |
| **Worked example** o **In the platform** | Números reales, o dónde aparece en LiteLLM, vLLM o los harnesses de agentes (OpenCode, Codex…) |
| **Try it** | Algo ejecutable: un `curl` contra el servidor, un cálculo, una página que inspeccionar |
| **Check yourself** | Tres preguntas, con las respuestas plegadas en `<details>` |
| **Read more** | Una o dos fuentes, indicando qué secciones leer y por qué |

Los nombres de métricas, los flags y las secciones de las fuentes se comprobaron contra la documentación vigente al escribir cada nota.

## Práctica real: nivel 10

El [nivel 10](../level-10/README.es.md) recorre todo el camino en el clúster kind, en CPU y con un modelo pequeño: un servidor de modelos llama.cpp con el mismo contrato `/v1/chat/completions` que vLLM, un gateway LiteLLM con Postgres, dos tenants con rate limits y presupuestos, un fallback, métricas en Prometheus, un dashboard de Grafana, alertas y cinco averías para diagnosticar a ciegas con la nota 25. Lo que kind no puede enseñar (GPUs, throughput real, tensor parallelism) queda en las notas 19–24.
