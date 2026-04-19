FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY . /app

RUN mkdir -p /app/staticfiles

EXPOSE 80 443

# gunicorn: config.wsgi is the module and application callable for Django
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:80", "--workers", "2", "--log-level", "info"]