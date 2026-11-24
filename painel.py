import logging
import os
import threading
from flask import Flask, jsonify, request

lock = threading.Lock()

LOG_FILE = os.getenv("PAINEL_LOG_FILE", "painel_casa.log")
AUTH_TOKEN = os.getenv("PAINEL_API_TOKEN", "token_da_casa_123")

logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(threadName)s - %(message)s",
)

app = Flask(__name__)

casa_status = {
    "temperatura": 22.5,
    "lampada_sala": "desligada",
    "alarme": "ativado",
    "sensor_movimento_porta": "sem_movimento",
    "porta_tecnologica": "fechada",
}

ACOES_VALIDAS = {
    "lampada_sala": {"ligada", "desligada"},
    "alarme": {"ativado", "desativado"},
    "sensor_movimento_porta": {"sem_movimento", "movimento_detectado"},
    "porta_tecnologica": {"fechada", "aberta", "travada"},
}


def token_valido():
    token = request.headers.get("Authorization")
    if token != f"Bearer {AUTH_TOKEN}":
        logging.warning("Token invalido de %s", request.remote_addr)
        return False
    return True


@app.route("/status", methods=["GET"])
def obter_status():
    if not token_valido():
        return jsonify({"erro": "Nao autorizado"}), 401

    logging.info("Status consultado")
    with lock:
        copia = dict(casa_status)
    return jsonify(copia), 200


@app.route("/comando", methods=["POST"])
def enviar_comando():
    if not token_valido():
        return jsonify({"erro": "Nao autorizado"}), 401

    dados = request.get_json(silent=True)
    if not isinstance(dados, dict):
        logging.error("JSON invalido de %s", request.remote_addr)
        return jsonify({"erro": "JSON invalido"}), 400

    dispositivo = dados.get("dispositivo")
    acao = dados.get("acao")
    if not dispositivo or not acao:
        logging.error("Campos faltando em %s", dados)
        return jsonify({"erro": "Informe dispositivo e acao"}), 422

    if dispositivo not in ACOES_VALIDAS:
        logging.warning("Dispositivo inexistente: %s", dispositivo)
        return jsonify({"erro": "Dispositivo nao encontrado"}), 404

    if acao not in ACOES_VALIDAS[dispositivo]:
        logging.warning("Acao invalida: %s -> %s", dispositivo, acao)
        return jsonify({"erro": "Acao invalida"}), 422

    with lock:
        casa_status[dispositivo] = acao
        if dispositivo == "sensor_movimento_porta" and acao == "movimento_detectado":
            if casa_status.get("porta_tecnologica") != "travada":
                casa_status["porta_tecnologica"] = "aberta"
                logging.info("Porta aberta automaticamente por sensor de movimento")
    logging.info("Comando executado: %s -> %s", dispositivo, acao)
    return jsonify({"ok": True, dispositivo: acao}), 200


@app.errorhandler(500)
def erro_servidor(erro):
    logging.error("Erro interno: %s", erro)
    return jsonify({"erro": "Erro interno"}), 500


if __name__ == "__main__":
    logging.info("Painel iniciado na porta 5000")
    app.run(host="0.0.0.0", port=5000, threaded=True)
