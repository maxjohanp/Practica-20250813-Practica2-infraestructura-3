#!/usr/bin/env bash
# =============================================================================
#  PC-USER · cliente de la VPN de acceso remoto (strongSwan, IKEv1 + XAuth)
#  Nodo GNS3: PC-1 · Ubuntu Server 26.04 · hostname pc-user20250813
#  Seguridad de Redes · Infraestructura 3 · Maxyohan Montas (2025-0813)
#
#  Qué hace:
#    1. Escribe /etc/ipsec.conf con la conexión «fgt» hacia FGT-B (20.25.8.13)
#    2. Pide la clave precompartida y la contraseña de vpnuser y escribe
#       /etc/ipsec.secrets (permisos 600). Los secretos NO van en el repositorio.
#    3. Reinicia strongSwan
#
#  Debe coincidir con el túnel VPN-REMOTO de FGT-B (Perfil B, licencia de
#  evaluación): IKEv1 modo agresivo · DES-SHA1 · DH grupo 2 (modp1024) ·
#  PFS grupo 2 · XAuth con vpnuser · IP del pool por Mode Config.
#
#  Paquetes necesarios (ya venían en la plantilla Ubuntu): strongswan-starter,
#  libstrongswan-standard-plugins y libcharon-extauth-plugins (XAuth).
#
#  Uso:  sudo bash pc-user-strongswan.sh
#        sudo ipsec up fgt      # conectar
#        sudo ipsec down fgt    # desconectar
# =============================================================================
set -euo pipefail

FGT="20.25.8.13"          # WAN de FGT-B
RED_SRV="10.8.13.0/28"    # red del servidor = selector local de la fase 2 en FGT-B
USUARIO="vpnuser"

echo "[1/3] /etc/ipsec.conf"
cat > /etc/ipsec.conf <<CONF
config setup
    charondebug="ike 1, knl 1, cfg 0"

conn fgt
    keyexchange=ikev1
    aggressive=yes
    authby=xauthpsk
    xauth=client
    left=%defaultroute
    leftid=@cliente-lab
    leftsourceip=%config
    xauth_identity=${USUARIO}
    right=${FGT}
    rightid=${FGT}
    rightsubnet=${RED_SRV}
    ike=des-sha1-modp1024!
    esp=des-sha1-modp1024!
    ikelifetime=8h
    keylife=1h
    dpdaction=restart
    dpddelay=30s
    auto=add
CONF

echo "[2/3] /etc/ipsec.secrets (lo que escribas no se muestra)"
read -r -s -p "  Clave precompartida (la misma de FGT-B): " PSK; echo
read -r -s -p "  Contraseña de ${USUARIO}: " XPASS; echo
umask 077
cat > /etc/ipsec.secrets <<SECRETS
@cliente-lab ${FGT} : PSK "${PSK}"
${USUARIO} : XAUTH "${XPASS}"
SECRETS
chmod 600 /etc/ipsec.secrets
unset PSK XPASS

echo "[3/3] Reiniciar strongSwan"
ipsec restart
sleep 2
ipsec statusall | head -n 12
echo "Listo. Conectar: sudo ipsec up fgt · desconectar: sudo ipsec down fgt"
