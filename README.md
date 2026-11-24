PAINEL DA CASA INTELIGENTE

Este projeto foi feito em Flask e simula o controle de alguns dispositivos de uma casa inteligente. Ele foi desenvolvido para a disciplina PSI129A – Conectividade em Sistemas Ciberfísicos e pode ser executado no Linux ou no WSL 2.

O QUE O PROGRAMA FAZ

Mostra a temperatura, o estado da lâmpada da sala, o estado do alarme, o sensor de movimento da porta e o estado da porta tecnológica.
Permite ligar e desligar a lâmpada.
Permite ativar e desativar o alarme.
Simula detecção de movimento na porta e abre a porta tecnológica automaticamente (quando ela não está travada), além de permitir controlar a porta manualmente.
Pede um token para aceitar as requisições.
Verifica os dados enviados e informa quando existe algum erro.
Permite atender mais de uma requisição ao mesmo tempo.
Salva registros de funcionamento em um arquivo de log.

A temperatura é fixa, pois o projeto é uma simulação. As informações ficam na memória e voltam ao padrão quando o servidor é iniciado novamente.

O QUE PRECISA INSTALAR

Python 3.8 ou superior
Flask

O projeto também usa as bibliotecas logging, os e threading, que já fazem parte do Python.

Biblioteca Para que é usada
Flask Criar o servidor e as rotas da API
logging Registrar as atividades em um arquivo
threading Atender várias requisições e proteger os dados compartilhados com Lock
os Ler as configurações do ambiente

INSTALAÇÃO

No terminal, entre na pasta do projeto:

cd trabalho_sistema

É recomendado criar um ambiente virtual:

python3 -m venv venv
source venv/bin/activate

Depois, instale o Flask:

pip install flask

Se aparecer o erro externally managed environment, use o ambiente virtual indicado acima.

CONFIGURAÇÕES

O programa aceita duas variáveis de ambiente:

Variável Valor padrão Para que serve
PAINEL_API_TOKEN token_da_casa_123 Token usado para acessar a API
PAINEL_LOG_FILE painel_casa.log Nome ou caminho do arquivo de log

Exemplo de configuração:

export PAINEL_API_TOKEN="troque_este_token"
export PAINEL_LOG_FILE="painel_casa.log"

O token padrão serve apenas para facilitar os testes. Se for usar o projeto em uma rede, configure outro token e não publique esse valor no repositório.

INICIANDO O SERVIDOR

Configure o token e execute:

export PAINEL_API_TOKEN="token_da_casa_123"
python painel.py

Se o comando python não funcionar, tente python3 painel.py.

O servidor usa a porta 5000 e aceita conexões de outras máquinas por estar configurado com host=0.0.0.0.

Para acessar no próprio computador:

http://localhost:5000

Também é possível acessar pelo IP da máquina na rede, por exemplo:

http://192.168.25.20:5000

Para verificar se a porta está em uso:

ss -tlnp | grep 5000

Para acompanhar os registros enquanto o programa funciona:

tail -f painel_casa.log

O arquivo de log pode ser protegido com:

chmod 640 painel_casa.log

Também é recomendado executar o painel com um usuário comum, sem privilégios de administrador.

ROTAS DISPONÍVEIS

A API possui duas rotas:

Método Rota O que faz
GET /status Mostra o estado atual da casa
POST /comando Envia um comando para um dispositivo

Todas as requisições precisam enviar o token no cabeçalho:

Authorization: Bearer token_da_casa_123

ENVIANDO UM COMANDO

O comando é enviado em formato JSON. Por exemplo, para ligar a lâmpada:

{
"dispositivo": "lampada_sala",
"acao": "ligada"
}

As ações disponíveis são:

Dispositivo Ações
lampada_sala ligada ou desligadaalarme ativado ou desativadosensor_movimento_porta sem_movimento ou movimento_detectadoporta_tecnologica fechada, aberta ou travada

Quando sensor_movimento_porta recebe movimento_detectado, a porta_tecnologica muda automaticamente para aberta caso não esteja travada. A temperatura é apenas uma informação de leitura, então não aceita comandos.

CÓDIGOS DE RESPOSTA

Código Significado
200 Requisição realizada com sucesso
400 Corpo da requisição ausente ou JSON inválido
401 Token ausente ou incorreto
404 Dispositivo não encontrado
422 Campo faltando ou ação inválida
500 Erro inesperado no servidor

TESTANDO A API

Com o servidor ligado, abra outro terminal. Os exemplos abaixo usam o token padrão. Se você configurou outro, troque o valor nos comandos.

1. Consultar o estado da casa

curl -i -H "Authorization: Bearer token_da_casa_123" http://localhost:5000/status

O resultado esperado é o código 200 e uma resposta parecida com esta:

{"alarme":"ativado","lampada_sala":"desligada","porta_tecnologica":"fechada","sensor_movimento_porta":"sem_movimento","temperatura":22.5}

2. Testar um token incorreto

curl -i -H "Authorization: Bearer token_errado" http://localhost:5000/status

O resultado esperado é 401. No log, deve aparecer um aviso com o IP de origem, por exemplo:

[WARNING] ... - Token invalido de 127.0.0.1

3. Consultar sem enviar token

curl -i http://localhost:5000/status

O resultado esperado é 401.

4. Ligar a lâmpada

curl -i -X POST http://localhost:5000/comando

-H "Authorization: Bearer token_da_casa_123"

-H "Content-Type: application/json"

-d '{"dispositivo":"lampada_sala","acao":"ligada"}'

O resultado esperado é 200. Depois, consulte /status novamente para confirmar que a lâmpada está ligada.

5. Simular movimento na porta tecnológica

curl -i -X POST http://localhost:5000/comando

-H "Authorization: Bearer token_da_casa_123"

-H "Content-Type: application/json"

-d '{"dispositivo":"sensor_movimento_porta","acao":"movimento_detectado"}'

O resultado esperado é 200, abrindo a porta_tecnologica caso ela não esteja travada.

6. Enviar um JSON inválido

curl -i -X POST http://localhost:5000/comando

-H "Authorization: Bearer token_da_casa_123"

-H "Content-Type: application/json"

-d 'isto nao e json'

O resultado esperado é 400.

7. Enviar um comando sem informar a ação

curl -i -X POST http://localhost:5000/comando

-H "Authorization: Bearer token_da_casa_123"

-H "Content-Type: application/json"

-d '{"dispositivo":"lampada_sala"}'

O resultado esperado é 422.

8. Tentar controlar um dispositivo que não existe

curl -i -X POST http://localhost:5000/comando

-H "Authorization: Bearer token_da_casa_123"

-H "Content-Type: application/json"

-d '{"dispositivo":"garagem","acao":"ligada"}'

O resultado esperado é 404.

9. Enviar uma ação inválida

curl -i -X POST http://localhost:5000/comando

-H "Authorization: Bearer token_da_casa_123"

-H "Content-Type: application/json"

-d '{"dispositivo":"lampada_sala","acao":"banana"}'

O resultado esperado é 422.

10. Testar várias requisições ao mesmo tempo

O comando abaixo envia 20 requisições, com até 10 acontecendo ao mesmo tempo:

seq 20 | xargs -P 10 -I{} curl -s -o /dev/null -w "%{http_code}\n"

-H "Authorization: Bearer token_da_casa_123" http://localhost:5000/status

Todas devem retornar 200. No arquivo painel_casa.log, o nome das threads permite ver que diferentes threads atenderam as requisições.

RESUMO DOS TESTES

Teste Resultado esperado
Consultar status com token correto 200
Consultar status com token incorreto 401
Consultar status sem token 401
Ligar a lâmpada 200
Simular movimento na porta tecnológica 200
Enviar JSON inválido 400
Enviar comando sem um campo 422
Informar dispositivo inexistente 404
Informar ação inválida 422
Enviar 20 requisições ao mesmo tempo Todas 200

PROBLEMAS COMUNS

A porta 5000 já está em uso: confira com ss -tlnp | grep 5000. Se necessário, encerre o outro processo ou altere a porta no final do arquivo painel.py.Não consegue acessar de outro computador: confira se o servidor está usando host="0.0.0.0", se o IP está correto e se o firewall permite a porta 5000. No Ubuntu, por exemplo, use sudo ufw allow 5000/tcp.A API sempre responde 401: confira se o token enviado é o mesmo configurado em PAINEL_API_TOKEN e se o cabeçalho está no formato Authorization: Bearer <token>.Quer conferir se o arquivo Python tem erro de sintaxe: execute python -m py_compile painel.py.
