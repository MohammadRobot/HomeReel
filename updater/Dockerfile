ARG UPDATER_BASE_IMAGE=docker:29.8.0-cli
FROM ${UPDATER_BASE_IMAGE}

RUN apk add --no-cache python3

ENV PYTHONDONTWRITEBYTECODE=1

COPY update_server.py /usr/local/bin/update_server.py

ENTRYPOINT ["python3", "/usr/local/bin/update_server.py"]
