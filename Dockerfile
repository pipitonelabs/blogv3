# Multi-stage Dockerfile for Astro-based website optimized for Kubernetes
# 
# This Dockerfile creates a production-ready container for Kubernetes deployment
# with optimized image sizes, security hardening, and proper asset handling

# ==============================================================================
# Build Stage
# ==============================================================================
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Install build dependencies for Sharp (image processing)
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    cairo-dev \
    jpeg-dev \
    pango-dev \
    musl-dev \
    giflib-dev \
    pixman-dev \
    pangomm-dev \
    libjpeg-turbo-dev \
    freetype-dev

# Copy package files
COPY package*.json ./
COPY bun.lock ./

# Copy source code
COPY . .

# Install dependencies
RUN npm ci --only=production --no-audit --no-fund

# Install astro-pure CLI tools
RUN npm install -g astro-pure

# Set build environment
ENV NODE_ENV=production
ENV npm_config_loglevel=error

# Modify astro.config.ts to use Node adapter for standalone deployment
RUN sed -i '1a import node from "@astrojs/node";' astro.config.ts && \
    sed -i 's/adapter: vercel(),/adapter: node({ mode: "standalone" }),/' astro.config.ts

# Build the application
RUN npm run build

# Verify build output
RUN ls -la dist/ && \
    test -f dist/server/entry.mjs && \
    test -d dist/client

# ==============================================================================
# Runtime Stage
# ==============================================================================
FROM node:18-alpine AS runtime

# Install runtime dependencies for Sharp (not build tools)
RUN apk add --no-cache \
    cairo \
    jpeg \
    pango \
    musl \
    giflib \
    pixman \
    pangomm \
    libjpeg-turbo \
    freetype

# Create non-root user for security
RUN addgroup -g 1001 -S astro && \
    adduser -S astro -u 1001

# Set working directory
WORKDIR /app

# Copy built application and dependencies from builder stage
COPY --from=builder --chown=astro:astro /app/dist ./
COPY --from=builder --chown=astro:astro /app/node_modules ./node_modules/

# Create necessary directories with proper permissions
RUN mkdir -p /app/logs /app/.cache /app/.tmp && \
    chown -R astro:astro /app

# Switch to non-root user
USER astro

# Set environment variables
ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=4321
ENV npm_config_loglevel=warn

# Health check for Kubernetes
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "fetch('http://localhost:4321/').then(r => r.ok ? process.exit(0) : process.exit(1)).catch(() => process.exit(1))"

# Expose port
EXPOSE 4321

# Set startup command with error handling
CMD ["sh", "-c", "node server/entry.mjs || (echo 'Server failed to start' && sleep 5 && exit 1)"]

# ==============================================================================
# Development Stage (Optional - for debugging)
# ==============================================================================
# Uncomment for development builds
# FROM node:18-alpine AS development
# WORKDIR /app
# COPY package*.json ./
# RUN npm install
# COPY . .
# EXPOSE 4321
# CMD ["npm", "run", "dev"]