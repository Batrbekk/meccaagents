FROM mcr.microsoft.com/playwright:v1.52.0-noble

# Install noVNC dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb \
    fluxbox \
    x11vnc \
    novnc \
    websockify \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy and install
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev

COPY src/ ./src/

# Create sessions directory
RUN mkdir -p /app/sessions

# noVNC startup script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3100 6080

ENTRYPOINT ["/entrypoint.sh"]
