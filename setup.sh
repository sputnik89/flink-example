#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$project_dir"
python_version="$(tr -d '[:space:]' < .python-version)"
venv_dir="$project_dir/.venv"
setup_installer=""

cleanup() {
    if [[ -n "$setup_installer" ]]; then
        rm -f -- "$setup_installer"
    fi
}
trap cleanup EXIT

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

if [[ $# -ne 0 ]]; then
    fail "Usage: ./setup.sh"
fi

# Match the Java installation PyFlink will use.
if [[ -n "${JAVA_HOME:-}" ]]; then
    java_bin="$JAVA_HOME/bin/java"
else
    java_bin="$(command -v java || true)"
fi
[[ -n "$java_bin" && -x "$java_bin" ]] || \
    fail "Install Java 17 and add it to PATH or set JAVA_HOME, then rerun ./setup.sh."
if ! java_settings="$("$java_bin" -XshowSettings:properties -version 2>&1)"; then
    fail "Java could not start. Install Java 17 and check PATH/JAVA_HOME."
fi
java_version="$(printf '%s\n' "$java_settings" | awk -F'= ' '/^[[:space:]]*java.specification.version =/ {print $2; exit}')"
[[ "$java_version" == "17" ]] || \
    fail "Java 17 is required (found ${java_version:-unknown}). Set PATH/JAVA_HOME to Java 17."
printf 'Using Java %s\n' "$java_version"

if command -v uv >/dev/null 2>&1; then
    uv_bin="$(command -v uv)"
elif [[ -x "$project_dir/.tools/uv" ]]; then
    uv_bin="$project_dir/.tools/uv"
else
    command -v curl >/dev/null 2>&1 || fail "Install curl, then rerun ./setup.sh."
    printf 'Installing uv...\n'
    setup_installer="$(mktemp)"
    curl -fsSL --retry 3 https://astral.sh/uv/0.12.13/install.sh -o "$setup_installer"
    UV_UNMANAGED_INSTALL="$project_dir/.tools" sh "$setup_installer"
    uv_bin="$project_dir/.tools/uv"
fi
"$uv_bin" --version

if [[ -e "$venv_dir" || -L "$venv_dir" ]]; then
    [[ -f "$venv_dir/pyvenv.cfg" && -x "$venv_dir/bin/python3" ]] || \
        fail "Existing .venv is invalid. Move it aside and rerun ./setup.sh."
    existing_version="$("$venv_dir/bin/python3" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
    [[ "$existing_version" == "$python_version" ]] || \
        fail "Existing .venv uses Python $existing_version; Python $python_version is required. Move it aside and rerun ./setup.sh."
    printf 'Reusing .venv (Python %s)\n' "$existing_version"
else
    printf 'Creating .venv with Python %s...\n' "$python_version"
    "$uv_bin" venv --python "$python_version" --seed "$venv_dir"
fi

"$uv_bin" pip install --python "$venv_dir/bin/python3" \
    --project "$project_dir" -r "$project_dir/requirements.txt"
"$uv_bin" pip check --python "$venv_dir/bin/python3"
"$venv_dir/bin/python3" -c 'import pyflink; from importlib.metadata import version; print("PyFlink " + version("apache-flink") + " is ready.")'

printf '\nSetup complete. Run:\n  cd %q\n  source .venv/bin/activate\n  python3 process.py\n' "$project_dir"
