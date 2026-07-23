import enum
import subprocess, sys, os, tempfile, shutil, time, requests

DEFAULT_PORT = 9998

class TerminalColor(enum.Enum):
    PURPLE='\033[95m'
    BLUE='\033[94m'
    CYAN='\033[96m'
    GREEN='\033[92m'
    YELLOW='\033[93m'
    RED='\033[91m'
    ENDC='\033[0m'
    BOLD='\033[1m'
    UNDERLINE='\033[4m'

def wrap_color(color: TerminalColor, string: str):
    """
    Print a given string in the specified terminal color
    """
    return color.value + string + TerminalColor.ENDC.value


class NeMoGuardrailsServer():
    def __init__(self, config_yaml: str, port: int = DEFAULT_PORT):
        """Start a local NeMo Guardrails server with the given config YAML.

        Returns (check, cleanup, server_logs) functions.
        """
        self.base_url = f"http://localhost:{port}"
        self.config_dir = tempfile.mkdtemp(prefix="nemo_dev_")
        config_id = "dev-config"
        config_subdir = os.path.join(self.config_dir, config_id)
        os.makedirs(config_subdir)

        with open(os.path.join(config_subdir, "config.yml"), "w") as f:
            f.write(config_yaml)

        log_file = open(os.path.join(self.config_dir, "server.log"), "w")

        self.server_proc = subprocess.Popen(
            [sys.executable, "-m", "nemoguardrails", "server",
             "--config", self.config_dir, "--default-config-id", config_id,
             "--port", str(port), "--verbose"],
            stdout=log_file, stderr=log_file,
        )

        for _ in range(60):
            try:
                r = requests.get(f"{self.base_url}/v1/rails/configs", timeout=2)
                if r.status_code == 200:
                    print(f"Server ready. Configs: {r.json()}")
                    break
            except requests.ConnectionError:
                pass
            time.sleep(1)
        else:
            self.server_proc.terminate()
            raise RuntimeError("Server failed to start — run server_logs() to check")

    def check(self, prompt):
        r = requests.post(f"{self.base_url}/v1/guardrail/checks", json={
            "model": "dummy",
            "messages": [{"role": "user", "content": prompt}],
        })
        result = r.json()

        # remap a successful status to "allowed" for clarity
        if result["status"] == "success":
            result["status"] = "allowed"
        return result

    def logs(self):
        with open(os.path.join(self.config_dir, "server.log")) as f:
            print(f.read())

    def cleanup(self):
        print("Shutting down NeMo Guardrails server...", end="")
        self.server_proc.terminate()
        self.server_proc.wait(timeout=10)
        shutil.rmtree(self.config_dir, ignore_errors=True)
        print(wrap_color(TerminalColor.GREEN, "[DONE]"))
