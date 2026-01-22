# Базовий образ з Node.js 20 на Alpine Linux (маленький розмір образу)
FROM node:20-alpine

# Робоча директорія всередині контейнера, де буде лежати код застосунку
WORKDIR /app

# Копіюємо лише файли залежностей (package.json / package-lock.json якщо є)
# Це дає кешування шарів Docker: залежності не перевстановлюються, якщо код змінюється, а package*.json — ні
COPY package*.json ./

# Встановлюємо лише production-залежності (devDependencies пропускаємо)
# Прапорці --no-fund/--no-audit прибирають зайвий шум у логах збірки
RUN npm install --omit=dev --no-fund --no-audit

# Копіюємо решту коду застосунку в контейнер
COPY . .

# Команда, яка буде виконана при старті контейнера
CMD ["node", "index.js"]