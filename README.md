# ДЗ: Monitoring-2 — EFK (Elasticsearch + Fluentd + Kibana)

## Опис завдання
Потрібно:
1. Створити Docker-образ для Node.js застосунку.
2. Підготувати `docker-compose.yaml` і підняти стек **EFK**.
3. Запустити Node.js застосунок у Docker і налаштувати відправку логів у EFK.
4. Переконатися, що логи видно в Kibana.

Джерело застосунку (оригінальне посилання з умови):
- https://gitlab.com/dan-it/groups/devops_soft/-/tree/main/Monitoring-2?ref_type=heads

## Документація по етапах
- Етап 1: Docker-образ для Node.js застосунку — див. [docs/01-nodejs-docker-image.md](docs/01-nodejs-docker-image.md)
- Етап 2 (частина 1): EFK — Elasticsearch — див. [docs/02-efk-elasticsearch.md](docs/02-efk-elasticsearch.md)
- Етап 2 (частина 2): EFK — Kibana — див. [docs/03-efk-kibana.md](docs/03-efk-kibana.md)
- Етап 2 (частина 3): EFK — Fluentd — див. [docs/04-efk-fluentd.md](docs/04-efk-fluentd.md)

## Швидкий запуск (коли все з нуля)
Скрипт [deploy.sh](deploy.sh) піднімає EFK через `docker compose`, збирає образ Node.js та запускає контейнер Node.js з Docker logging driver `fluentd`. Також генерує тестовий лог (через Docker fluentd logging driver), щоб зʼявився індекс `fluentd-*`.

Запуск (Git Bash / WSL):
- `bash deploy.sh`

Примітка: скрипт розрахований на сценарій «нічого ще не створено». Якщо контейнери вже існують і є конфлікти імен — зупини їх окремо і запусти скрипт ще раз.

Увага: зараз `deploy.sh` на початку робить cleanup (видаляє контейнери/volumes та локальні образи, створені цією ДЗ), щоб запуск завжди був «з нуля».

## Формат здачі
- Код Dockerfile
- Код `docker-compose.yaml`
- Код файлів конфігурації
- Скріни запуску й роботи EFK
- Скріни роботи Kibana
