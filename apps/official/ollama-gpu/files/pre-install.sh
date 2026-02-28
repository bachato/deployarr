#!/bin/bash
# pre-install.sh for ollama-gpu
# Detects GPU vendor (NVIDIA or AMD) and configures compose accordingly.

COMPOSE_FILE="$DOCKER_FOLDER/compose/$HOSTNAME/ollama-gpu.yml"

f_print_substep "Detecting GPU hardware..."

GPU_VENDOR=""

# --- NVIDIA detection ---
if command -v nvidia-smi &>/dev/null && cat /tmp/.deployrr_sudo | sudo -S nvidia-smi &>/dev/null; then
    GPU_VENDOR="nvidia"
    GPU_LABEL="NVIDIA (CUDA)"
fi

# --- AMD detection (check for ROCm device nodes) ---
if [[ -z "$GPU_VENDOR" ]]; then
    if cat /tmp/.deployrr_sudo | sudo -S ls /dev/kfd &>/dev/null; then
        GPU_VENDOR="amd"
        GPU_LABEL="AMD (ROCm)"
    fi
fi

# --- Fallback: no supported GPU found ---
if [[ -z "$GPU_VENDOR" ]]; then
    f_print_error "No supported GPU detected. nvidia-smi not found and /dev/kfd not present."
    f_print_error "Install NVIDIA drivers or ROCm before installing Ollama (GPU)."
    return 1
fi

f_print_substep "Detected: $GPU_LABEL — configuring compose..."

if [[ "$GPU_VENDOR" == "nvidia" ]]; then
    # NVIDIA: use standard ollama image + deploy.resources block
    cat /tmp/.deployrr_sudo | sudo -S sed -i \
        "s|GPU-IMAGE-PLACEHOLDER|ollama/ollama:latest|" \
        "$COMPOSE_FILE"

    # Replace the GPU-CONFIG-PLACEHOLDER comment with the NVIDIA deploy block
    cat /tmp/.deployrr_sudo | sudo -S sed -i \
        "s|    # GPU-CONFIG-PLACEHOLDER|    deploy:\n      resources:\n        reservations:\n          devices:\n            - driver: nvidia\n              device_ids: ['all']\n              capabilities: [gpu]|" \
        "$COMPOSE_FILE"

elif [[ "$GPU_VENDOR" == "amd" ]]; then
    # AMD: use ROCm image tag + device passthrough (no deploy block needed)
    cat /tmp/.deployrr_sudo | sudo -S sed -i \
        "s|GPU-IMAGE-PLACEHOLDER|ollama/ollama:rocm|" \
        "$COMPOSE_FILE"

    # Replace the GPU-CONFIG-PLACEHOLDER comment with AMD device lines
    cat /tmp/.deployrr_sudo | sudo -S sed -i \
        "s|    # GPU-CONFIG-PLACEHOLDER|    devices:\n      - /dev/kfd:/dev/kfd\n      - /dev/dri:/dev/dri\n    group_add:\n      - video\n      - render|" \
        "$COMPOSE_FILE"
fi

# Export for post-install message substitution
export GPU_LABEL

f_print_success "GPU configuration applied: $GPU_LABEL"
