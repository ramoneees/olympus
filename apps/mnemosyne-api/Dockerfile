FROM python:3.12-slim
WORKDIR /app
RUN pip install --no-cache-dir \
    "fastapi>=0.115,<1" \
    "uvicorn>=0.30,<1" \
    "psycopg2-binary>=2.9,<3"
COPY src/app.py /app/app.py
EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
