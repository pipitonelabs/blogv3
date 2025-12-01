# Build stage
FROM oven/bun:1 AS build

WORKDIR /app

# Copy package files and local packages
COPY package*.json bun.lock ./
COPY packages/ ./packages/

# Install dependencies (including local packages)
RUN bun install

# Install @astrojs/node for standalone deployment
RUN bun add @astrojs/node

# Copy source code
COPY . .

# Modify astro.config.ts to use Node adapter instead of Vercel
# Also use passthrough image service (no Sharp optimization needed in container)
RUN sed -i '1a import node from "@astrojs/node";' astro.config.ts && \
    sed -i 's/adapter: vercel(),/adapter: node({ mode: "standalone" }),/' astro.config.ts && \
    sed -i "s/entrypoint: 'astro\/assets\/services\/sharp'/entrypoint: 'astro\/assets\/services\/noop'/" astro.config.ts

# Build the application
RUN bun run build

# Runtime stage
FROM node:18-alpine

WORKDIR /app

# Minimal dependencies (no Sharp needed with noop image service)
RUN apk add --no-cache libc6-compat

# Copy built application from build stage
COPY --from=build /app/dist ./

# Copy node_modules from build stage
COPY --from=build /app/node_modules ./node_modules/

# Expose port 4321
EXPOSE 4321

# Enable verbose debug logging for image processing issues
ENV NODE_ENV=development
ENV DEBUG=*
ENV NODE_DEBUG=module,http
ENV NODE_OPTIONS="--trace-warnings --unhandled-rejections=strict"

# Start the server with error logging wrapper
CMD ["sh", "-c", "node server/entry.mjs 2>&1 | tee /dev/stderr"]