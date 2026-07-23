#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

VENV_DIR="$SCRIPT_DIR/.venv"
CONTRIB_DIR="$SCRIPT_DIR/.eval-hub-contrib"
ADAPTER_DIR="$CONTRIB_DIR/adapters/nemo-guardrails"

RED='\033[31m'
GREEN='\033[32m'
CYAN='\033[36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}=== NeMo Guardrails Local Demo Setup ===${NC}"

# 0. Check for uv
if ! command -v uv &>/dev/null; then
    echo "Error: uv is required but not installed."
    echo "Install it with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# 1. Create venv and install dependencies
echo ""
echo -e "${BOLD}${CYAN}Step 1:${NC} Creating virtual environment and installing dependencies..."
if [ ! -d "$VENV_DIR" ]; then
    uv venv --python 3.12 "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"

# Install notebook dependencies and nemoguardrails
uv pip install \
    "nemoguardrails[all] @ git+https://github.com/trustyai-explainability/NeMo-Guardrails.git@develop" \
    "eval-hub-sdk[server,cli,adapter]>=0.4.3" \
    "notebook>=7.5,<8" \
    ipykernel \
    requests \
    pyyaml \
    scikit-learn \
    tqdm \
    jq \
    datasets

python -m ipykernel install --user --name nemo-guardrails-local --display-name "NeMo Guardrails Local"

# Workaround: nemoguardrails server expects examples/bots/ relative to the
# package's site-packages dir. Create it so the server module can be imported.
NEMO_EXAMPLES_DIR=$(python3 -c "
import os, nemoguardrails.utils as u
print(os.path.normpath(os.path.join(os.path.dirname(u.__file__), '..', 'examples', 'bots')))
")
if [ ! -d "$NEMO_EXAMPLES_DIR" ]; then
    mkdir -p "$NEMO_EXAMPLES_DIR"
    echo "  Created missing examples/bots directory for NeMo server compatibility"
fi

# 2. Clone eval-hub-contrib (contains the NeMo Guardrails adapter)
echo ""
echo -e "${BOLD}${CYAN}Step 2:${NC} Setting up eval-hub-contrib adapter..."
if [ -d "$CONTRIB_DIR" ]; then
    echo "  eval-hub-contrib already cloned, pulling latest..."
    git -C "$CONTRIB_DIR" pull --quiet
else
    echo "  Cloning eval-hub-contrib..."
    git clone --quiet --branch AddNeMoFramework https://github.com/RobGeada/eval-hub-contrib.git "$CONTRIB_DIR"
fi

if [ ! -d "$ADAPTER_DIR" ]; then
    echo -e "${RED}Error: NeMo Guardrails adapter not found at $ADAPTER_DIR${NC}"
    exit 1
fi

# 3. Configure and start EvalHub server
echo ""
echo -e "${BOLD}${CYAN}Step 3:${NC} Starting EvalHub server..."
evalhub config set server_config_file "$SCRIPT_DIR/evalhub_config.yaml"
evalhub config set base_url http://localhost:8080

if evalhub health &>/dev/null 2>&1; then
    echo ""
    W=60
    echo -e "${RED}╔$(printf '═%.0s' $(seq 1 $W))╗${NC}"
    printf -v l1 "  ${BOLD}${RED}ERROR${NC}: An EvalHub server is already running on port 8080"
    printf -v l2 "  Stop it first with: ${BOLD}evalhub server stop${NC}"
    v1="  ERROR: An EvalHub server is already running on port 8080"
    v2="  Stop it first with: evalhub server stop"
    printf -v p1 "%-$((W - ${#v1}))s" ""
    printf -v p2 "%-$((W - ${#v2}))s" ""
    echo -e "${RED}║${NC}${l1}${p1}${RED}║${NC}"
    echo -e "${RED}║${NC}${l2}${p2}${RED}║${NC}"
    echo -e "${RED}╚$(printf '═%.0s' $(seq 1 $W))╝${NC}"
    echo ""
    exit 1
fi
evalhub server start
echo "  Waiting for server..."
sleep 2
evalhub health

# 4. Register the NeMo Guardrails provider
echo ""
echo -e "${BOLD}${CYAN}Step 4:${NC} Registering NeMo Guardrails provider..."

# Resolve the local command path so EvalHub can find main.py
sed \
    -e "s|command: python main.py|command: python $ADAPTER_DIR/main.py|" \
    "$ADAPTER_DIR/provider.yaml" > /tmp/evalhub_provider_resolved.yaml

PROVIDER_OUTPUT=$(evalhub providers create --file /tmp/evalhub_provider_resolved.yaml 2>&1)
echo "$PROVIDER_OUTPUT"
rm /tmp/evalhub_provider_resolved.yaml

PROVIDER_ID=$(echo "$PROVIDER_OUTPUT" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)
PROVIDER_ID="${PROVIDER_ID:-UNKNOWN}"

echo ""
echo -e "${BOLD}${GREEN}=== Setup Complete ===${NC}"
echo ""
echo "Activate the environment and set the provider ID:"
echo ""
echo -e "${BOLD}${CYAN}source $VENV_DIR/bin/activate${NC}"
echo -e "${BOLD}${CYAN}export PROVIDER_ID=$PROVIDER_ID${NC}"
echo ""
echo "Then run an evaluation:"
echo ""
echo -e "${BOLD}${CYAN}evalhub eval run \\\\${NC}"
echo -e "${BOLD}${CYAN}  --name <run-name> \\\\${NC}"
echo -e "${BOLD}${CYAN}  --model-url http://localhost:9999 \\\\${NC}"
echo -e "${BOLD}${CYAN}  --model-name nemo-guardrails \\\\${NC}"
echo -e "${BOLD}${CYAN}  --provider \$PROVIDER_ID \\\\${NC}"
echo -e "${BOLD}${CYAN}  --benchmark <benchmark-id> \\\\${NC}"
echo -e "${BOLD}${CYAN}  --param nemo_config=$SCRIPT_DIR/nemo_configs/<nemo-config-name> \\\\${NC}"
echo -e "${BOLD}${CYAN}  --watch${NC}"
echo ""
echo "Where:"
echo "  <run-name>         Any descriptive name for this run (e.g. 'deberta-test')"
echo "  <benchmark-id>     A benchmark 'id' from the provider (e.g. 'prompt_injection')"
echo "  <nemo-config-name> A directory under nemo_configs/ (e.g. 'prompt_injection_deberta')"
echo ""
echo "Check results with:"
echo ""
echo -e "${BOLD}${CYAN}evalhub eval results <JOB_ID>${NC}"
echo ""
echo "Stop the server with:"
echo ""
echo -e "${BOLD}${CYAN}evalhub server stop${NC}"
