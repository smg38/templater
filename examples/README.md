# Примеры

```bash
cd examples
../templater.sh config.j3
cat config.out
```

Ожидаемый результат:

```yaml
app: MY-SERVICE
greeting: 'hello world'
url: https://example.com/?q=hello%20world
token: czNjcjN0
token_sha256: <hex>
```
