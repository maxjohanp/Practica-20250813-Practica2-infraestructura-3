#!/usr/bin/env bash
# =============================================================================
#  Pruebas de la Infraestructura 3 · VPN de acceso remoto (se ejecuta en PC-USER)
#  Seguridad de Redes · Maxyohan Montas (2025-0813)
#
#  Uso:
#    bash pruebas-infra3.sh sinvpn   # antes de «sudo ipsec up fgt» o tras «down»
#    bash pruebas-infra3.sh convpn   # con la VPN conectada
#
#  Reglas que se comprueban:
#    · HTTPS al servidor SIN VPN, por la IP pública de FGT-B (VIP 20.25.8.13:443)
#    · SSH (TCP 22) al servidor SOLO con la VPN
#    · SSH a la IP pública (20.25.8.13:22) nunca: no hay política desde la WAN
#    · Por la VPN solo pasa lo necesario (SSH, ping, traceroute): no HTTPS
#  El SSH se prueba abriendo el puerto 22, sin iniciar sesión (no pide clave).
# =============================================================================
MODO="${1:-sinvpn}"
SRV="10.8.13.10"      # SRV-WEB (red privada detrás de FGT-B)
PUB="20.25.8.13"      # WAN de FGT-B = Virtual IP del HTTPS

if [[ "$MODO" != "sinvpn" && "$MODO" != "convpn" ]]; then
  echo "Uso: $0 sinvpn|convpn"; exit 1
fi
[[ "$MODO" == "convpn" ]] && VPN="si" || VPN="no"

verde=$'\e[32m'; rojo=$'\e[31m'; neg=$'\e[1m'; fin=$'\e[0m'
pasa=0; falla=0
resultado() {   # $1 = descripción, $2 = obtenido (si|no), $3 = esperado (si|no)
  if [[ "$2" == "$3" ]]; then
    printf '  [%sOK%s]    %s\n' "$verde" "$fin" "$1"; pasa=$((pasa+1))
  else
    printf '  [%sFALLA%s] %s\n' "$rojo" "$fin" "$1"; falla=$((falla+1))
  fi
}
puerto_abierto() {   # $1 = IP, $2 = puerto -> si|no
  timeout 6 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null && echo si || echo no
}
esperado() { [[ "$1" == si ]] && echo "debe responder" || echo "NO debe responder"; }

echo "${neg}== Infraestructura 3 · pruebas desde $(hostname) · modo: $MODO ==${fin}"
date
ip -4 -br a | grep -v '^lo'
echo

echo "${neg}1. Cliente VPN${fin}"
ip -4 -o addr | grep -q ' 10\.25\.13\.' && r=si || r=no
resultado "IP del pool de la VPN (10.25.13.x) $( [[ $VPN == si ]] && echo presente || echo ausente)" "$r" "$VPN"

echo "${neg}2. HTTPS sin VPN por la IP pública ($PUB, Virtual IP)${fin} — siempre"
codigo=$(curl -k -s -o /dev/null -m 6 -w '%{http_code}' "https://$PUB")
[[ "$codigo" == "200" ]] && r=si || r=no
resultado "curl https://$PUB -> código $codigo (esperado 200)" "$r" "si"

echo "${neg}3. SSH a la IP pública ($PUB:22)${fin} — nunca"
r=$(puerto_abierto "$PUB" 22)
resultado "puerto 22 de $PUB cerrado (no hay política de SSH desde la WAN)" "$r" "no"

echo "${neg}4. SSH al servidor ($SRV:22)${fin} — solo con VPN"
r=$(puerto_abierto "$SRV" 22)
resultado "puerto 22 de $SRV: $(esperado $VPN)" "$r" "$VPN"

echo "${neg}5. Ping al servidor ($SRV)${fin} — solo con VPN"
ping -c 3 -W 2 "$SRV" >/dev/null 2>&1 && r=si || r=no
resultado "ping $SRV: $(esperado $VPN)" "$r" "$VPN"

echo "${neg}6. HTTPS a la IP privada ($SRV) por la VPN${fin} — no permitido"
codigo=$(curl -k -s -o /dev/null -m 6 -w '%{http_code}' "https://$SRV")
[[ "$codigo" == "200" ]] && r=si || r=no
resultado "curl https://$SRV sin respuesta (la VPN solo deja SSH, ping y traceroute)" "$r" "no"

echo "${neg}7. Camino hacia el servidor (traceroute)${fin}"
traceroute -n -q 1 -w 2 -m 5 "$SRV"
echo "   Con VPN: FGT-B y luego $SRV (el túnel oculta al Cisco y al ISP)"
echo "   Sin VPN: 10.20.25.1 y luego * * * (el ISP no conoce la red privada)"

echo
echo "${neg}Resumen: $pasa OK · $falla FALLA${fin}"
date
