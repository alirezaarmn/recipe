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

Create new app
```bash
docker-compose run --rm app sh -c "python manage.py startapp core"
```

Doing some clean up on the core app:
- remove test.py, because we will add `tests` folder
- remove views.py because core app isn't going to serve any web views
