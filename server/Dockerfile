FROM python:3.12-slim
WORKDIR /app
COPY server/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt && useradd --create-home teamsync
COPY server /app/server
USER teamsync
EXPOSE 8000
CMD ["uvicorn", "server.app:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000", "--no-access-log"]
