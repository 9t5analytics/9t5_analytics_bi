# Start from official Python 3.11 slim image
FROM python:3.11-slim

# Set working directory inside the container
WORKDIR /app

# Copy requirements first for better layer caching
COPY requirements.txt .

# Install Python packages
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the ingestion code
COPY . .

# Tell Python to not buffer output
# This ensures logs appear immediately in Cloud Run
ENV PYTHONUNBUFFERED=1

# Command to run when container starts
CMD ["python", "main.py"]