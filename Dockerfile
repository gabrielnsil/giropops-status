# Dockerfile mínimo pra avaliação rápida da aplicação.
# NÃO substitui o estudo da Fase 2 (Descomplicando Docker), onde você
# constrói este arquivo do zero, com layers, multistage, security, etc.
# Aqui o objetivo é só "subir e ver funcionando" em 1 comando.

FROM python:3.13-alpine

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV FLASK_APP=app.py \
    PYTHONUNBUFFERED=1

EXPOSE 5000

# Em produção: gunicorn ou similar. Pra avaliação local, Flask dev server resolve.
CMD ["python", "app.py"]
