#!/usr/bin/env bash
#
# Recolecta el estado del nodo de Alex y lo guarda en estado-alex.txt
# El Claude de Alex: corré esto, luego:
#   git add estado-alex.txt && git commit -m "estado nodo alex" && git push
#
OUT=estado-alex.txt
{
echo "===== REPORTE DE ESTADO - nodo de Alex ====="
echo "fecha: $(date)"
echo
echo "== 1. Cassandra instalada? (debe ser 4.1.x, NO 5.0) =="
dpkg -l cassandra 2>/dev/null | tail -1 || echo "NO instalada (dpkg)"
cassandra -v 2>&1 || echo "binario 'cassandra' no encontrado"
echo
echo "== 2. Java (debe ser 11) =="
java -version 2>&1 | head -1
echo
echo "== 3. Servicio =="
echo -n "activo: "; systemctl is-active cassandra 2>/dev/null
echo -n "habilitado: "; systemctl is-enabled cassandra 2>/dev/null
echo
echo "== 4. cassandra.yaml (valores clave) =="
sudo grep -E "^cluster_name:|- seeds:|^listen_address:|^rpc_address:|^broadcast_rpc_address:|^endpoint_snitch:" /etc/cassandra/cassandra.yaml 2>/dev/null || echo "no se pudo leer el yaml"
echo
echo "== 5. nodetool status (¿aparecen los 4 nodos UN?) =="
nodetool status 2>&1
echo
echo "== 6. Tailscale (IP propia y estado) =="
echo -n "mi IP: "; tailscale ip -4 2>&1
tailscale status 2>&1
echo
echo "== 7. Conectividad + latencia a los otros nodos (para ver si la conexión es rápida) =="
for ip in 100.64.210.124 100.74.29.122 100.126.124.40; do
  echo "--- $ip ---"
  ping -c3 -W3 "$ip" 2>&1 | tail -2
  echo -n "puerto 7000 (gossip): "; timeout 5 bash -c "echo > /dev/tcp/$ip/7000" 2>/dev/null && echo ABIERTO || echo "cerrado/inalcanzable"
  echo -n "ruta tailscale (direct=rápido / relay=lento): "; tailscale ping -c 2 "$ip" 2>&1 | tail -1
done
echo
echo "== 8. Errores recientes en el log =="
sudo tail -20 /var/log/cassandra/system.log 2>/dev/null | grep -iE "error|exception|unable|already exists|schema readiness" | tail -8 || echo "sin errores accesibles / log vacío"
echo "===== FIN DEL REPORTE ====="
} | tee "$OUT"
echo
echo ">>> LISTO. Ahora subí la respuesta:"
echo "    git add estado-alex.txt && git commit -m 'estado nodo alex' && git push"
