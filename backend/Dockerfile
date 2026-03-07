# Use official Python image
FROM python:3.11-slim

# Copy the Lambda Web Adapter (allows Flask to run on Lambda)
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.3 /lambda-adapter /opt/extensions/lambda-adapter

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsm6 \
    libxext6 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install
COPY requirements.txt .

# Install CPU-specific versions to keep image size small for Lambda
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu && \
    pip install --no-cache-dir -r requirements.txt

# Copy backend code
COPY . .

# Create a tmp directory for video processing
RUN mkdir -p /app/tmp && chmod 777 /app/tmp

# Expose port (App Runner default is often 8080, but we use 5000)
EXPOSE 5000

# Set environment variables for production
ENV FLASK_APP=server.py
ENV PORT=5000

# Run the server
CMD ["python", "server.py"]
