#!/usr/bin/env bash
ct=0; gu=0; gt=0; mu=0; mt=1; gp=0; gn=GPU
for h in /sys/class/hwmon/hwmon*; do
  case "$(cat "$h/name" 2>/dev/null)" in
    coretemp|k10temp|zenpower) ct=$(( $(cat "$h/temp1_input") / 1000 )); break ;;
  esac
done

if command -v nvidia-smi >/dev/null 2>&1; then
  IFS=',' read -r gu gt mu mt gp gn <<<"$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw,name --format=csv,noheader,nounits 2>/dev/null | head -1)"
else
  for h in /sys/class/hwmon/hwmon*; do
    if [ "$(cat "$h/name" 2>/dev/null)" = amdgpu ]; then
      gt=$(( $(cat "$h/temp1_input") / 1000 )); d=$(readlink -f "$h/device")
      gu=$(cat "$d/gpu_busy_percent" 2>/dev/null || echo 0)
      mu=$(( $(cat "$d/mem_info_vram_used" 2>/dev/null || echo 0) / 1048576 ))
      mt=$(( $(cat "$d/mem_info_vram_total" 2>/dev/null || echo 1048576) / 1048576 ))
      break
    fi
  done
fi

num() { v="${1// /}"; case "$v" in ''|*[!0-9.]*) echo 0 ;; *) awk -v v="$v" 'BEGIN{printf "%d", v}' ;; esac; }
gu=$(num "$gu"); gt=$(num "$gt"); mu=$(num "$mu"); mt=$(num "$mt"); gp=$(num "$gp")
[ "$mt" -lt 1 ] && mt=1
mp=$(( mu * 100 / mt ))

printf '{"cpu_t":%d,"gpu_u":%d,"gpu_t":%d,"gpu_mu":%d,"gpu_mt":%d,"gpu_mperc":%d,"gpu_p":%d}\n' \
  "$ct" "$gu" "$gt" "$mu" "$mt" "$mp" "$gp"
