#!/usr/bin/env bash
# =============================================================================
#  SRV-WEB · servidor web HTTPS de la sede del servidor (detrás de FGT-B)
#  Nodo GNS3: Web0813-2 · Ubuntu Server 26.04 · hostname web-0813
#  Seguridad de Redes · Infraestructura 3 · Maxyohan Montas (2025-0813)
#
#  Qué hace:
#    1. Nombre del equipo (web-0813)
#    2. IP fija 10.8.13.10/28, puerta de enlace 10.8.13.1 (port1 de FGT-B)
#    3. Apache solo con HTTPS (443) y certificado autofirmado
#    4. Comprobación final (curl -kI https://localhost -> 200 OK)
#
#  Uso:  sudo bash srv-web-setup.sh
#  Nota: la clave privada (web-lab.key) se genera en el servidor y NUNCA
#        se sube al repositorio.
# =============================================================================
set -euo pipefail

IFACE="${IFACE:-ens4}"      # en este laboratorio la interfaz de los Ubuntu es ens4
HOST="web-0813"

echo "[1/4] Nombre del equipo: $HOST"
hostnamectl set-hostname "$HOST"
sed -i '/^127\.0\.1\.1/d' /etc/hosts
echo "127.0.1.1 $HOST" >> /etc/hosts

echo "[2/4] Red: 10.8.13.10/28 por $IFACE"
mkdir -p /root/netplan-orig
mv /etc/netplan/*.yaml /root/netplan-orig/ 2>/dev/null || true
cat > /etc/netplan/01-lab.yaml <<EOF
network:
  version: 2
  ethernets:
    ${IFACE}:
      dhcp4: false
      addresses: [10.8.13.10/28]
      routes:
        - to: default
          via: 10.8.13.1
      nameservers:
        addresses: [20.25.8.8]
EOF
chmod 600 /etc/netplan/01-lab.yaml
netplan apply

echo "[3/4] Apache con HTTPS y certificado autofirmado"
# apache2 ya venía en la plantilla de Ubuntu; si no, instalarlo antes:
#   apt-get install -y apache2
openssl req -x509 -nodes -newkey rsa:2048 -days 825 \
  -keyout /etc/ssl/private/web-lab.key -out /etc/ssl/certs/web-lab.crt \
  -subj "/O=Seguridad de Redes/CN=web.lab.local" \
  -addext "subjectAltName=DNS:web.lab.local,IP:10.8.13.10,IP:20.25.8.13"
a2enmod ssl

cat > /etc/apache2/sites-available/web-lab-ssl.conf <<'EOF'
<VirtualHost *:443>
    ServerName web.lab.local
    DocumentRoot /var/www/html
    SSLEngine on
    SSLCertificateFile    /etc/ssl/certs/web-lab.crt
    SSLCertificateKeyFile /etc/ssl/private/web-lab.key
    ErrorLog  ${APACHE_LOG_DIR}/web-lab-error.log
    CustomLog ${APACHE_LOG_DIR}/web-lab-access.log combined
</VirtualHost>
EOF
a2dissite 000-default default-ssl 2>/dev/null || true   # el puerto 80 queda sin sitio
a2ensite web-lab-ssl

cat > /var/www/html/index.html <<'EOF'
<!doctype html><html lang="es"><head><meta charset="utf-8"><title>SRV-WEB · HTTPS</title>
<style>body{font-family:Segoe UI,Arial;background:#0B1F3A;color:#fff;text-align:center;padding-top:12vh}
.card{display:inline-block;background:#1D6FE0;padding:32px 48px;border-radius:16px}
code{background:#0B1F3A;padding:2px 8px;border-radius:6px}</style></head>
<body><div class="card"><h1>Servidor web protegido</h1>
<p>Servicio HTTPS (443) en <code>srv-web</code> · 10.8.13.10</p>
<p>Seguridad de Redes · GNS3 + FortiGate</p></div></body></html>
EOF

systemctl enable apache2
systemctl restart apache2
systemctl enable --now ssh

echo "[4/4] Comprobación"
ip -br a show "$IFACE"                       # 10.8.13.10/28
curl -skI https://localhost | head -n 1     # HTTP/1.1 200 OK
ss -tlnp | grep -E ':(22|443) ' || true     # SSH (22) y HTTPS (443) escuchando
