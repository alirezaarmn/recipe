# recipe
Django rest api for cooking recipe

command to run flake which is a linting tool to highlights syntax errors, typos and formatting issues.
```bash
docker-compose run --rm app sh -c "flake8"
```

Step to build django project via docker compose that we create:
```bash
docker-compose run --rm app sh -c "django-admin startproject app ."
```