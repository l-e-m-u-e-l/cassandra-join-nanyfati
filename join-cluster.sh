#!/usr/bin/env bash
#
# Une un nodo Linux nativo (Debian/Ubuntu) al cluster Cassandra "nanyfati".
# Ejecutar en la máquina de Alex, DESPUÉS de tener Tailscale conectado.
#
# Uso:   chmod +x join-cluster.sh && ./join-cluster.sh
#
set -uo pipefail

# ===== Datos FIJOS del cluster (no cambiar) =====
CLUSTER_NAME="nanyfati"
SEED="100.64.210.124"                 # nodo seed principal
CASSANDRA_VERSION="4.1.12"            # MISMA serie 4.1 que el resto (NO 5.0)

echo "########################################################"
echo "#  Unir este nodo al cluster Cassandra '$CLUSTER_NAME'"
echo "########################################################"

# ===== 1. Tailscale debe estar conectado =====
echo; echo "== 1. Verificando Tailscale =="
if ! command -v tailscale >/dev/null 2>&1; then
  echo "!! Tailscale NO está instalado. Instalalo y conectate primero:"
  echo "     curl -fsSL https://tailscale.com/install.sh | sh"
  echo "     sudo tailscale up      # iniciar sesión con la cuenta COMPARTIDA del grupo"
  echo "   (pedí el correo/clave de Tailscale en el chat; es la misma para todos)"
  exit 1
fi
MYIP="$(tailscale ip -4 2>/dev/null | head -1)"
if [[ -z "${MYIP:-}" ]]; then
  echo "!! Tailscale no tiene IP asignada. Corré 'sudo tailscale up' y logueate con la cuenta compartida."
  exit 1
fi
echo "   Mi IP de Tailscale: $MYIP"
echo "   Probando alcance al seed $SEED ..."
if ping -c2 -W3 "$SEED" >/dev/null 2>&1; then echo "   OK, llego al seed."; else
  echo "   !! No llego al seed por Tailscale. ¿Están los dos en la misma cuenta de Tailscale?"; exit 1
fi

# ===== 2. Java 11 (Cassandra 4.1 NO corre en Java 17) =====
echo; echo "== 2. Instalando Java 11 =="
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-11-jre-headless curl gnupg >/dev/null
J11="$(update-alternatives --list java 2>/dev/null | grep -m1 'java-11' || ls /usr/lib/jvm/java-11-openjdk-*/bin/java 2>/dev/null | head -1)"
[[ -n "${J11:-}" ]] && sudo update-alternatives --set java "$J11" 2>/dev/null || true
echo "   Java activo: $(java -version 2>&1 | head -1)"

# ===== 3. Repositorio de Cassandra 4.1 =====
echo; echo "== 3. Agregando repo Cassandra 4.1 =="
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://downloads.apache.org/cassandra/KEYS | sudo tee /etc/apt/keyrings/apache-cassandra.asc >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/apache-cassandra.asc] https://debian.cassandra.apache.org 41x main" \
  | sudo tee /etc/apt/sources.list.d/cassandra.sources.list >/dev/null
sudo apt-get update -qq

# ===== 4. Instalar Cassandra 4.1.x =====
echo; echo "== 4. Instalando Cassandra $CASSANDRA_VERSION =="
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "cassandra=$CASSANDRA_VERSION" python3-six \
  || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y cassandra python3-six   # fallback a la 4.1 más nueva
echo "   Instalada: $(cassandra -v 2>&1)"

# ===== 5. Detener y configurar cassandra.yaml =====
echo; echo "== 5. Configurando cassandra.yaml =="
sudo systemctl stop cassandra 2>/dev/null || true
sleep 6
Y=/etc/cassandra/cassandra.yaml
sudo cp "$Y" "$Y.orig.$(date +%s)"
sudo sed -i "s|^cluster_name:.*|cluster_name: '$CLUSTER_NAME'|"                 "$Y"
sudo sed -i "s|- seeds:.*|- seeds: \"$SEED\"|"                                  "$Y"
sudo sed -i "s|^listen_address:.*|listen_address: $MYIP|"                       "$Y"
sudo sed -i "s|^rpc_address:.*|rpc_address: 0.0.0.0|"                           "$Y"
sudo sed -i "s|^# *broadcast_rpc_address:.*|broadcast_rpc_address: $MYIP|"      "$Y"
grep -q "^broadcast_rpc_address:" "$Y" || echo "broadcast_rpc_address: $MYIP" | sudo tee -a "$Y" >/dev/null
sudo sed -i "s|^endpoint_snitch:.*|endpoint_snitch: GossipingPropertyFileSnitch|" "$Y"
echo "   Valores aplicados:"
grep -E "^cluster_name:|- seeds:|^listen_address:|^rpc_address:|^broadcast_rpc_address:|^endpoint_snitch:" "$Y" | sed 's/^/     /'

# ===== 6. Vaciar datos (nodo nuevo) =====
echo; echo "== 6. Vaciando datos internos =="
sudo find /var/lib/cassandra/data /var/lib/cassandra/commitlog /var/lib/cassandra/saved_caches -mindepth 1 -delete 2>/dev/null || true

# ===== 7. Arrancar y esperar la unión =====
echo; echo "== 7. Arrancando Cassandra y uniendo al cluster =="
sudo systemctl start cassandra
for i in $(seq 1 24); do
  if nodetool status 2>/dev/null | grep -qE "^UN.*$MYIP"; then
    echo; echo "====================  ¡UNIDO AL CLUSTER!  ===================="
    nodetool status
    exit 0
  fi
  echo "   ...esperando (intento $i)"; sleep 12
done

echo; echo "!! Todavía no aparece como UN. Revisá el error con:"
echo "     sudo tail -30 /var/log/cassandra/system.log"
echo "   Si dice 'A node with address $MYIP already exists', pedí que en el SEED corran:"
echo "     nodetool assassinate $MYIP     (y volvé a correr: sudo systemctl restart cassandra)"
exit 1
