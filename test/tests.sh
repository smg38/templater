#!/bin/bash
# 1. Создаём шаблон и .env
cat > config.j3 <<'EOF'
app: {{ APP_NAME | upper }}
url: https://example.com/?q={{ GREETING | urlencode }}
token: {{ SECRET | b64encode }}
EOF

cat > config.env <<'EOF'
APP_NAME=my-service
GREETING="hello world"
SECRET='s3cr3t'
EOF

# 2. Автопоиск: читает config.env, пишет config.out
./templater.sh config.j3
cat config.out
# app: MY-SERVICE
# url: https://example.com/?q=hello%20world
# token: czNjcjN0

# 3. Окружение перебивает .env
APP_NAME=override ./templater.sh config.j3
head -1 config.out
# app: OVERRIDE

# 4. Явные -e/-o переопределяют автопоиск
./templater.sh -e other.env -o /tmp/x.out config.j3
cat /tmp/x.out

# 5. stdin -> stdout (автопоиск отключён)
printf 'Hi {{ N }}\n' | N=you ./templater.sh -
# Hi you