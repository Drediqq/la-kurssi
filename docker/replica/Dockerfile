FROM python:3.11-slim

WORKDIR /app

# Install dependencies required for MariaDB
RUN apt-get update && apt-get install -y \
    build-essential \
    libmariadb-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt gunicorn

COPY . .

# Run with Gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "counter:app"]