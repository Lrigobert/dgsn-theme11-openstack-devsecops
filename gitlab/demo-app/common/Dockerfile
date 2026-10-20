# Image minimale, utilisateur non root, sans outils de build dans l'image finale
FROM python:3.12-alpine
RUN apk upgrade --no-cache && apk add --no-cache iputils-ping \
    && addgroup -S app && adduser -S -G app app
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
USER app
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://127.0.0.1:8000/health || exit 1
CMD ["gunicorn", "-b", "0.0.0.0:8000", "-w", "2", "app:app"]
