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

# Basta con que UN nodo del cluster responda: cualquiera sirve de punto de contacto.
VIVOS=""
for ip in 100.64.210.124 100.126.124.40 100.74.29.122; do
  if ping -c2 -W3 "$ip" >/dev/null 2>&1; then
    echo "   nodo vivo: $ip"
    VIVOS="${VIVOS:+$VIVOS,}$ip"
  else
    echo "   apagado:   $ip"
  fi
done
if [[ -z "$VIVOS" ]]; then
  echo "!! Ningun nodo del cluster responde. Puede que esten todos apagados,"
  echo "   o que Tailscale no este bien conectado. Revisa con: tailscale status"
  exit 1
fi

cp "$Y" "$Y.bak.$(date +%Y%m%d-%H%M%S)"
sed -i "s|^listen_address:.*|listen_address: $MYIP|"                 "$Y"
sed -i "s|^rpc_address:.*|rpc_address: $MYIP|"                       "$Y"
sed -i "s|^broadcast_rpc_address:.*|broadcast_rpc_address: $MYIP|"   "$Y"
sed -i "s|- seeds: .*|- seeds: \"$VIVOS\"|"                            "$Y"

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
