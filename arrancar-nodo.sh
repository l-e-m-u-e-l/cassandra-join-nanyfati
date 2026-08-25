#!/usr/bin/env bash
# Actualiza el cassandra.yaml con la IP actual de Tailscale y arranca el nodo.
# Correr DESPUES de 'sudo tailscale up'.
set -uo pipefail
Y=/opt/cassandra/conf/cassandra.yaml

MYIP="$(tailscale ip -4 2>/dev/null | head -1)"
if [[ -z "${MYIP:-}" || "$MYIP" != 100.* ]]; then
  echo "!! Tailscale todavia no tiene IP. Corre primero:  sudo tailscale up"
  exit 1
fi
echo "Mi IP de Tailscale: $MYIP"

echo -n "Alcanzo el seed 100.64.210.124? ... "
ping -c2 -W3 100.64.210.124 >/dev/null 2>&1 && echo "si" || { echo "NO -- revisa que sea la cuenta compartida del grupo"; exit 1; }

cp "$Y" "$Y.bak.$(date +%Y%m%d-%H%M%S)"
sed -i "s|^listen_address:.*|listen_address: $MYIP|"                 "$Y"
sed -i "s|^rpc_address:.*|rpc_address: $MYIP|"                       "$Y"
sed -i "s|^broadcast_rpc_address:.*|broadcast_rpc_address: $MYIP|"   "$Y"

python3 -c "import yaml,sys; yaml.safe_load(open('$Y')); print('yaml OK')" || { echo "!! yaml invalido, restaurando"; cp "$(ls -t $Y.bak.* | head -1)" "$Y"; exit 1; }
grep -E "^cluster_name:|^listen_address:|^rpc_address:|^broadcast_rpc_address:|^endpoint_snitch:" "$Y" | sed 's/^/   /'

echo "Arrancando Cassandra..."
/opt/cassandra/bin/cassandra >/dev/null 2>&1

for i in $(seq 1 20); do
  if /opt/cassandra/bin/nodetool status 2>/dev/null | grep -qE "^UN.*$MYIP"; then
    echo; echo "==========  UNIDO AL CLUSTER  =========="
    /opt/cassandra/bin/nodetool status
    exit 0
  fi
  echo "   ...esperando ($i/20)"; sleep 12
done

echo "!! Todavia no aparece como UN. Mira el error real con:"
echo "   tail -30 /opt/cassandra/logs/system.log"
exit 1
