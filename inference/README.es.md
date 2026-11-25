# Notas de inferencia

[English](README.md)

Notas cortas sobre cómo se sirven los LLM: un concepto por nota, que se lee en unos 15 minutos, con algo para probar y tres preguntas para comprobar lo aprendido. Léelas en orden: cada una se apoya en las anteriores. No necesitas el clúster kind para seguirlas.

**Las notas están en inglés.** Este índice y las instrucciones para ejecutar los ejemplos están en español.

## Recorrido

| Fase | Notas | Conceptos | Fuente principal |
| --- | --- | --- | --- |
| 1 · Qué significa servir un modelo | 01–08 | pesos y parámetros, tokens (prompt y completion), prefill y decode, VRAM y tamaño del modelo, cuantización, ventana de contexto, la API compatible con OpenAI | [Fast & Efficient LLM Inference with vLLM](https://learn.deeplearning.ai/courses/fast-and-efficient-llm-inference-with-vllm) (DeepLearning.AI + Red Hat, 1 h 38 min) |
| 2 · Por qué va rápido o lento | 09–17 | qué importa en una GPU, instancias GPU en AWS, KV cache, PagedAttention, continuous batching, prefix caching, latencia y throughput, tensor parallelism, dimensionado | El mismo curso + [documentación de vLLM](https://docs.vllm.ai/) |
| 3 · Operarlo como plataforma | próximamente | gateway (LiteLLM): claves virtuales, presupuestos, rate limits, fallbacks; GPUs en Kubernetes (device plugin / GPU Operator, taints, node pools con GPU); métricas de serving; serving distribuido (llm-d) | [Documentación del proxy de LiteLLM](https://docs.litellm.ai/docs/proxy/deploy), [llm-d](https://llm-d.ai/) |

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

## Próximamente: nivel 10

El nivel 10 recorrerá todo el camino en el clúster kind, en CPU y con un modelo pequeño: la misma API y el mismo gateway que en producción, sin la GPU.

1. **Servidor de modelos:** un modelo pequeño (tipo Qwen 0.5B) detrás de una API compatible con OpenAI: llama.cpp server u Ollama en CPU. El mismo contrato `/v1/chat/completions` que vLLM.
2. **Gateway:** proxy LiteLLM con Postgres (lo necesitan las claves virtuales y los presupuestos) y Redis (rate limits compartidos cuando hay más de una réplica).
3. **Tenants:** dos claves virtuales, una con un presupuesto mínimo y un límite de RPM bajo. Comprobar que el límite y el presupuesto bloquean peticiones.
4. **Fallback:** una segunda ruta de modelo; matar el primer servidor y ver cómo LiteLLM conmuta.
5. **Métricas:** recoger las del gateway y del servidor de modelos en el Prometheus del nivel 8; un panel de Grafana con latencia, tokens/s y gasto por clave.
6. **Averías para encontrar a ciegas (como en el nivel 9):** presupuesto agotado, servidor de modelos con OOMKilled, nombre de modelo erróneo en la ruta, Postgres caído.

Lo que kind no puede enseñar aquí: scheduling de GPUs, el device plugin, MIG y el throughput real. Eso queda como notas en la fase 3.
