#!/usr/bin/env bash
# =============================================================================
#  PC-USER · equipo del usuario en la VLAN 10 (detrás de R-USERS)
#  Nodo GNS3: PC-1 · Ubuntu Server 26.04 · hostname pc-user20250813
#  Seguridad de Redes · Infraestructura 3 · Maxyohan Montas (2025-0813)
#
#  Qué hace:
#    1. Nombre del equipo con la matrícula (pc-user20250813) y zona horaria
#    2. Red por DHCP (la entrega R-USERS: 10.20.25.10 - .100)
#    3. Herramientas de prueba (traceroute, curl)
#  El cliente VPN (strongSwan) se configura después con pc-user-strongswan.sh
#
#  Uso:  sudo bash pc-user-setup.sh
# =============================================================================
set -euo pipefail

IFACE="${IFACE:-ens4}"
HOST="pc-user20250813"

echo "[1/3] Nombre del equipo y hora local"
hostnamectl set-hostname "$HOST"
sed -i '/^127\.0\.1\.1/d' /etc/hosts
echo "127.0.1.1 $HOST" >> /etc/hosts
timedatectl set-timezone America/Santo_Domingo   # AST, UTC-4

echo "[2/3] Red por DHCP en $IFACE"
mkdir -p /root/netplan-orig
mv /etc/netplan/*.yaml /root/netplan-orig/ 2>/dev/null || true
cat > /etc/netplan/01-lab.yaml <<EOF
network:
  version: 2
  ethernets:
    ${IFACE}:
      dhcp4: true
      dhcp-identifier: mac
EOF
chmod 600 /etc/netplan/01-lab.yaml
systemctl disable --now apache2 2>/dev/null || true   # el PC del usuario no es servidor web

echo "[3/3] Herramientas de prueba"
apt-get install -y traceroute curl

netplan apply
networkctl reconfigure "$IFACE"
sleep 8
ip -br a show "$IFACE"    # debe mostrar 10.20.25.x/25 (DHCP de R-USERS)
ip route | head -n 1      # default via 10.20.25.1
