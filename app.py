print("Servidor iniciando")
from flask import Flask, render_template
import requests
import time

app = Flask(__name__)

# Lista de serviços para monitorar
SERVICES = [
    {"name": "Google", "url": "https://www.google.com"},
    {"name": "GitHub", "url": "https://www.github.com"},
    {"name": "RNP", "url": "https://www.rnp.br"},
    {"name": "Futuro Site", "url": "http://localhost:5000"}  # Este será o nosso próprio dashboard, para testar localmente
]

@app.route('/')
def index():
    # Esta função será executada quando alguém acessar a página principal (/) do nosso site
    
    status_data = []
    for service in SERVICES:
        service_name = service["name"]
        service_url = service["url"]
        
        try:
            # Tenta fazer uma requisição HTTP para a URL do serviço
            # O timeout é o tempo máximo que esperamos por uma resposta (5 segundos)
            response = requests.get(service_url, timeout=5)
            
            # Verifica se o status da resposta indica sucesso (códigos 2xx)
            if response.status_code >= 200 and response.status_code < 300:
                status = "Online"
                status_class = "online"  # Classe CSS para estilização
            else:
                status = f"Offline ({response.status_code})"
                status_class = "offline"
        except requests.exceptions.RequestException as e:
            # Se ocorrer um erro na requisição (ex: site fora do ar, problema de rede)
            status = "Offline (Erro de Conexão)"
            status_class = "offline"
        except Exception as e:
            # Captura outros erros inesperados
            status = f"Offline (Erro Inesperado: {e})"
            status_class = "offline"
            
        status_data.append({"name": service_name, "url": service_url, 
                            "status": status, "class": status_class})
        
    # Renderiza o template HTML (index.html) e passa os dados de status para ele
    return render_template('index.html', services=status_data, 
                           current_time=time.strftime('%H:%M:%S'))

if __name__ == '__main__':
    # Esta parte garante que o servidor Flask seja iniciado apenas quando executamos app.py diretamente
    app.run(debug=True, host='0.0.0.0')  # debug=True para ver erros, host='0.0.0.0' para ser acessível de fora do container