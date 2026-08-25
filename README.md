# Kit para unir el 4º nodo al cluster Cassandra "nanyfati"

> Actividad de Base de Datos (UGB). Cluster Cassandra distribuido entre compañeras
> por internet usando **Tailscale** como red privada. Ya hay 3 nodos activos; falta el de **Alex**.

## Para el Claude de Alex — contexto y qué hacer

Alex corre esto en **Linux nativo (Debian/Ubuntu)**. El objetivo: instalar Cassandra 4.1
y que su nodo aparezca como `UN` en `nodetool status` junto a los otros 3.

### Datos del cluster (fijos)
| Dato | Valor |
|---|---|
| `cluster_name` | `nanyfati` |
| Nodo seed | `100.64.210.124` |
| Versión Cassandra | **4.1.x** (la 4.1.12 del repo). **NO usar 5.0** |
| Java | **11** (Cassandra 4.1 NO corre en Java 17) |
| Snitch | `GossipingPropertyFileSnitch` |
| Datacenter | `dc1` |

Nodos ya activos: `100.64.210.124` (seed), `100.74.29.122`, `100.126.124.40`.

### Pasos

**1. Tailscale (esto es manual, necesita navegador):**
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up          # abre un link; iniciar sesión con la CUENTA COMPARTIDA del grupo
```
La cuenta de Tailscale (correo + clave) es la misma para todos — **pedirla en el chat del grupo**
(no está en este repo por seguridad). Al terminar, `tailscale ip -4` debe devolver una IP `100.x.x.x`
y `ping 100.64.210.124` debe responder.

**2. Correr el script (hace todo lo demás automático):**
```bash
chmod +x join-cluster.sh
./join-cluster.sh
```
El script: instala Java 11, agrega el repo 4.1, instala Cassandra 4.1.12, detecta la IP de
Tailscale de Alex sola, configura el `cassandra.yaml`, vacía los datos y arranca. Al final
imprime `nodetool status` con los 4 nodos.

### Si falla
- **`A node with address <IP> already exists`** → quedó un registro fantasma. Que en el **seed**
  (`100.64.210.124`) corran: `nodetool assassinate <IP-de-alex>` y después en la máquina de Alex:
  `sudo systemctl restart cassandra`.
- **`Could not achieve schema readiness`** → conexión lenta; reintentar `sudo systemctl restart cassandra`.
- Ver el error real: `sudo tail -30 /var/log/cassandra/system.log`.

### Nota sobre cqlsh
El `cqlsh` de la 4.1 puede fallar si el sistema trae Python 3.12+ (`No module named 'six.moves'`).
No afecta al cluster (que se prueba con `nodetool status`). Para consultas CQL, usar un Python 3.11
o correr `cqlsh` desde otro nodo.

## Cómo reportar de vuelta (opcional)
Si algo se traba, el Claude de Alex puede subir a este repo el archivo
`sudo tail -50 /var/log/cassandra/system.log > alex-log.txt` y commitearlo; así el otro Claude
lo revisa y sugiere el arreglo en el próximo turno.
