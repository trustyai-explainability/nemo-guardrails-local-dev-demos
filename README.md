# NeMo Guardrails Local Dev Demos

Develop and evaluate [NeMo Guardrails](https://github.com/trustyai-explainability/NeMo-Guardrails) configurations on your local machine (no GPU or LLM required). This repo provides:

- **Demo notebooks** for interactive guardrail config development in a local, non-GPU environment
- **Sample NeMo configs** for prompt injection and toxicity protection
- **Local evaluation** via [EvalHub](https://github.com/opendatahub-io/eval-hub) using the NeMo Guardrails adapter from [eval-hub-contrib](https://github.com/opendatahub-io/eval-hub-contrib)

## Quick Start

1. Run the setup script, which will create a virtual environment, install dependencies, clone the EvalHub adapter, start the EvalHub server, and register the NeMo Guardrails evaluation provider:

   ```bash
   ./setup_evalhub.sh
   ```

2. The setup script will print instructions. Copy the printed commands:

    ```
    source .venv/bin/activate
    export PROVIDER_ID=<some provider ID>
    ```

3. Run an evaluation:

   ```bash
   evalhub eval run \
     --name deberta-test \
     --model-url http://localhost:9999 \
     --model-name nemo-guardrails \
     --provider $PROVIDER_ID \
     --benchmark prompt_injection \
     --param nemo_config=prompt_injection_deberta \
     --watch
   ```

4. Check results:

   ```bash
   evalhub eval results <JOB_ID>
   ```

## Notebooks

### Setup
The `./setup_evalhub.sh` script provides all necessary prerequisites for running the notebooks:
```bash
./setup_evalhub.sh
source .venv/bin/activate
jupyter notebook
```

### Blog Post Demo

`notebooks/local_guardrail_development_demo.ipynb` walks through developing and testing NeMo Guardrails configurations on your local machine. 

### Interactive Guardrails Playground

After completing the blog post demo, use `notebooks/local_guardrail_development_playground.ipynb` as a workspace to interactively develop and test guardrail configs. 


## NeMo Configs

Sample guardrail configurations in `nemo_configs/`:

| Config | Description |
|--------|-------------|
| `prompt_injection_deberta` | DeBERTa v3 classifier + language detection |
| `prompt_injection_naive_regex` | Regex pattern matching (~25 patterns) |
| `granite-guardian-hap-125m` | IBM Granite Guardian HAP classifier (125M) |
| `granite-guardian-hap-38m` | IBM Granite Guardian HAP classifier (38M) |

### Creating a New Config

```bash
mkdir nemo_configs/my_config
```

Create `nemo_configs/my_config/config.yml`. See the [NeMo Guardrails documentation](https://docs.nvidia.com/nemo/guardrails/) for the full config reference.

## Running Local Evaluations

```bash
evalhub eval run \
  --name my-test-run \
  --model-url http://localhost:9999 \
  --model-name nemo-guardrails \
  --provider $PROVIDER_ID \
  --benchmark <benchmark-id> \
  --param nemo_config=<nemo-config-name> \
  --watch
```

- `--benchmark` -- The benchmark ID (e.g., `prompt_injection`, `toxicity`, `personally_identifiable_information`)
- `--param nemo_config=...` -- The directory name under `nemo_configs/`

### Optional Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `nemo_config` | benchmark ID | NeMo config directory name |
| `server_port` | `9999` | Port for the NeMo Guardrails server |
| `server_host` | `localhost` | Host for the NeMo Guardrails server |
| `startup_timeout` | `120` | Seconds to wait for server startup |
| `workers` | `1` | Concurrent evaluation workers |
| `verbose` | `false` | Print each prompt, ground-truth label, and NeMo decision |

## Managing the Server

```bash
evalhub server start          # start the EvalHub server
evalhub server stop           # stop the EvalHub server
evalhub health                # check server health
evalhub providers list        # list registered providers
```
