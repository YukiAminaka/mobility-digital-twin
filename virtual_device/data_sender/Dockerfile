FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY send_gps.py /app/send_gps.py

USER 65532:65532

ENTRYPOINT ["python", "/app/send_gps.py"]
