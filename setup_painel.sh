#!/bin/bash
# Script de configuracao, execucao e diagnostico - Painel Casa Inteligente
# Disciplina:  Conectividade em Sistemas Ciberfisicos
#
# Uso (na pasta do projeto, onde esta o painel.py):
#   export PAINEL_API_TOKEN="seu_token"   # opcional; sem isso usa o token de teste
#   bash setup_painel.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="/opt/painel_casa"
APP_USER="paineluser"
LOG_FILE="$APP_DIR/painel_casa.log"
TOKEN="${PAINEL_API_TOKEN:-token_da_casa_123}"
URL="http://127.0.0.1:5000"

if [ ! -f "$SCRIPT_DIR/painel.py" ]; then
  echo "ERRO: painel.py nao encontrado em $SCRIPT_DIR"
  exit 1
fi

echo "=== [1/4] Preparando diretorio, usuario e permissoes ==="
sudo useradd -r -s /usr/sbin/nologin "$APP_USER" 2>/dev/null || true
sudo mkdir -p "$APP_DIR"
sudo cp "$SCRIPT_DIR/painel.py" "$APP_DIR/painel.py"
sudo touch "$LOG_FILE"
sudo chown -R "$APP_USER:$APP_USER" "$APP_DIR"
sudo chmod 750 "$APP_DIR"
sudo chmod 640 "$LOG_FILE"

echo "Permissoes do diretorio e do log:"
sudo ls -ld "$APP_DIR"
sudo ls -la "$LOG_FILE"

echo ""
echo "=== [2/4] Instalando dependencias e iniciando o servidor Flask ==="
if [ ! -x "$APP_DIR/venv/bin/python" ]; then
  sudo -u "$APP_USER" python3 -m venv "$APP_DIR/venv" || { echo "ERRO ao criar venv (instale: sudo apt install python3-venv)"; exit 1; }
fi

if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
  sudo cp "$SCRIPT_DIR/requirements.txt" "$APP_DIR/requirements.txt"
  sudo chown "$APP_USER:$APP_USER" "$APP_DIR/requirements.txt"
  sudo -u "$APP_USER" "$APP_DIR/venv/bin/pip" install --quiet -r "$APP_DIR/requirements.txt" || { echo "ERRO ao instalar dependencias"; exit 1; }
else
  sudo -u "$APP_USER" "$APP_DIR/venv/bin/pip" install --quiet flask || { echo "ERRO ao instalar o Flask"; exit 1; }
fi

sudo pkill -f "$APP_DIR/painel.py" 2>/dev/null || true
sleep 1
sudo -u "$APP_USER" env PAINEL_API_TOKEN="$TOKEN" PAINEL_LOG_FILE="$LOG_FILE" \
  bash -c "cd '$APP_DIR' && nohup '$APP_DIR/venv/bin/python' '$APP_DIR/painel.py' > '$APP_DIR/server.out' 2>&1 &"
sleep 2

echo "Processo do servidor (deve rodar como $APP_USER, nao como root):"
ps -eo user=,pid=,args= | grep "[p]ainel.py" || {
  echo "ERRO: o servidor nao subiu. Saida:"; sudo cat "$APP_DIR/server.out"; exit 1; }

echo ""
echo "=== [3/4] Executando testes da API (curl) para evidencias ==="

echo "--> [T03] Teste 1: Requisicao sem token (Esperado: 401)"
curl -i "$URL/status"

echo -e "\n--> [T02] Teste 2: Requisicao com token invalido (Esperado: 401)"
curl -i -H "Authorization: Bearer token_errado" "$URL/status"

echo -e "\n--> [T01] Teste 3: Consulta de status com token valido (Esperado: 200)"
curl -i -H "Authorization: Bearer $TOKEN" "$URL/status"

echo -e "\n--> [T04] Teste 4: Comando valido - ligar lampada (Esperado: 200)"
curl -i -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dispositivo":"lampada_sala","acao":"ligada"}' \
  "$URL/comando"

echo -e "\n--> Teste 4b: Sensor de movimento na porta tecnologica (Esperado: 200 e porta aberta)"
curl -i -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dispositivo":"sensor_movimento_porta","acao":"movimento_detectado"}' \
  "$URL/comando"

echo -e "\n--> [T08] Teste 5: Acao invalida (Esperado: 422)"
curl -i -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dispositivo":"lampada_sala","acao":"voar"}' \
  "$URL/comando"

echo -e "\n--> [T07] Teste 6: Dispositivo inexistente (Esperado: 404)"
curl -i -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dispositivo":"geladeira","acao":"ligada"}' \
  "$URL/comando"

echo -e "\n--> [T05] Teste 7: JSON invalido (Esperado: 400)"
curl -i -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d 'isso_nao_e_json' \
  "$URL/comando"

echo -e "\n--> [T09] Teste 8: 20 requisicoes em paralelo (Esperado: todas 200)"
seq 20 | xargs -P 10 -I{} curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Bearer $TOKEN" "$URL/status" | sort | uniq -c

echo -e "\n--> Status final apos os comandos:"
curl -i -H "Authorization: Bearer $TOKEN" "$URL/status"

echo ""
echo "=== [4/4] Log e comandos de diagnostico do Linux ==="
echo "--> Conteudo do log ($LOG_FILE):"
sudo cat "$LOG_FILE"

echo -e "\n--> Interfaces de rede (ip a):"
ip a

echo -e "\n--> Portas escutando (ss -tlnp):"
sudo ss -tlnp

echo -e "\n--> Conectividade local (ping):"
ping -c 4 127.0.0.1

echo -e "\n--> Diagnostico de recursos (top):"
top -bn1 | head -n 15

echo -e "\n--> Versao do systemctl:"
systemctl --version | head -n 1

echo ""
echo "=== Execucao finalizada! ==="
echo "Para parar o servidor: sudo pkill -f $APP_DIR/painel.py"
