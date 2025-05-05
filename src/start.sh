#!/usr/bin/env bash
set -eo pipefail                    # -u yok; undefined-var yerine boş kabul edilir

###############################################################################
# ÖN KOŞUL — GEREKLİ TOKEN’LAR
###############################################################################
: "${HF_TOKEN:?⛔  HF_TOKEN unset}"
: "${CIVI_TOKEN:?⛔  CIVI_TOKEN unset}"

###############################################################################
# 0)  RUNPOD VOLUME → COMFYUI
###############################################################################
RUNPOD_VOL="/runpod-volume"
mkdir -p "$RUNPOD_VOL/models"
ln -sf "$RUNPOD_VOL/models" /comfyui/models   # ComfyUI tüm modelleri burada görür

###############################################################################
# 1)  İNDİRİLECEK DOSYALAR (MODEL_TYPE'e göre)
###############################################################################
MODEL_TYPE="${MODEL_TYPE:-dev-fp8}"

declare -A DOWNLOADS
case "$MODEL_TYPE" in
  dev-fp8|dev)
    DOWNLOADS=(
      ["loras/comfyui_portrait_lora64.safetensors"]="https://huggingface.co/ali-vilab/ACE_Plus/resolve/main/portrait/comfyui_portrait_lora64.safetensors?download=true"
      ["diffusion_models/fluxFillFP8_v10.safetensors"]="https://civitai.com/api/download/models/1085456?type=Model&format=SafeTensor&size=full&fp=fp8"
      ["checkpoints/flux1-dev-fp8.safetensors"]="https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev-fp8.safetensors?download=true"
      ["text_encoders/clip_l.safetensors"]="https://huggingface.co/Comfy-Org/stable-diffusion-3.5-fp8/resolve/main/text_encoders/clip_l.safetensors?download=true"
      ["text_encoders/t5xxl_fp8_e4m3fn.safetensors"]="https://huggingface.co/Comfy-Org/stable-diffusion-3.5-fp8/resolve/main/text_encoders/t5xxl_fp8_e4m3fn.safetensors?download=true"
      ["vae/ae.safetensors"]="https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors?download=true"
    )
    ;;
  *)
    echo "⛔  Unknown MODEL_TYPE: $MODEL_TYPE"; exit 1 ;;
esac

###############################################################################
# 2)  İNDİRME FONKSİYONU
###############################################################################
download_all() {
  local missing=false
  for REL_PATH in "${!DOWNLOADS[@]}"; do
    local TARGET="$RUNPOD_VOL/models/$REL_PATH"
    local URL="${DOWNLOADS[$REL_PATH]}"

    if [[ -f "$TARGET" ]]; then
      echo "✅  $REL_PATH already exists"
      continue
    fi

    echo "⏬  Downloading $REL_PATH ..."
    mkdir -p "$(dirname "$TARGET")"

    if [[ "$URL" == *"civitai.com"* ]]; then
      curl -L --fail --retry 5 --retry-delay 5 \
           -H "Authorization: Bearer ${CIVI_TOKEN}" \
           -o "$TARGET" "$URL" || rm -f "$TARGET"
    else
      wget -c --retry-connrefused --waitretry=5 -t 5 \
           --header="Authorization: Bearer ${HF_TOKEN}" \
           -O "$TARGET" "$URL" || rm -f "$TARGET"
    fi

    if [[ -f "$TARGET" ]]; then
      echo "✅  Finished $REL_PATH"
    else
      echo "❌  Failed $REL_PATH"
      missing=true
    fi
  done
  $missing && return 1 || return 0
}

###############################################################################
# 3)  DOWNLOAD RETRY DÖNGÜSÜ
###############################################################################
MAX_RETRY=3
for ((try=1; try<=MAX_RETRY; try++)); do
  if download_all; then
    echo "🎉  All models present"
    break
  fi
  if (( try == MAX_RETRY )); then
    echo "❌  Download failed after $MAX_RETRY attempts — exiting"
    exit 1
  fi
  echo "↻  Retry $try/$MAX_RETRY in 30 s…"
  sleep 30
done

###############################################################################
# 4)  BELLEK OPTİMİZASYONU
###############################################################################
TCMALLOC="$(ldconfig -p | grep -Po 'libtcmalloc.so.\d+' | head -n 1 || true)"
[[ -n "$TCMALLOC" ]] && export LD_PRELOAD="$TCMALLOC"

###############################################################################
# 5)  COMFYUI & RUNPOD HANDLER
###############################################################################
python3 /comfyui/main.py --disable-auto-launch --disable-metadata --listen &
echo "✅  ComfyUI running on :8188"

COMFY_HOST=${COMFY_HOST:-"127.0.0.1:8188"}
export COMFY_HOST

if [[ "${SERVE_API_LOCALLY:-false}" == "true" ]]; then
  echo "🔌  Starting RunPod Handler (local API)"
  python3 -u /rp_handler.py --rp_serve_api --rp_api_host=0.0.0.0
else
  python3 -u /rp_handler.py
fi
