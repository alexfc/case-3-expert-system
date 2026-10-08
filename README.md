# АвтоМото-Диагност - прототип экспертной системы (кейс-задача № 3)

Диагностика неисправностей авто- и мототехники по симптомам и подбор запчастей
из каталога интернет-магазина. Оболочка - CLIPS 6.4 (через clipspy), интерфейс - Flask + HTML/JS на Bootstrap 5.3.

## Структура

| Путь | Назначение |
|---|---|
| `es/knowledge_base.clp` | База знаний CLIPS: шаблоны, справочные факты, 51 правило |
| `es/engine.py` | Интеграция механизма вывода: запуск CLIPS, сбор результата и трассы |
| `app.py` | Веб-сервер и REST API (`/api/catalog`, `/api/diagnose`) |
| `static/index.html` | Интерфейс пользователя (Bootstrap 5.3, только CSS) |
| `static/vendor/bootstrap/` | Локальная копия Bootstrap 5.3.3 (CSS) - работает без интернета |
| `tests/test_es.py` | 20 автотестов |
| `report/` | Отчёт (.docx), скриншоты, вывод тестов |

## Запуск

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python app.py            # http://localhost:5050
.venv/bin/python -m unittest tests.test_es -v
```

Параметры URL для быстрого сценария, например:
`/?type=car&mileage=120000&battery=5&s=starter-clicks,dim-lights,cold-weather&run=1&open=1`
