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
RUN sed -i '1a import node from "@astrojs/node";' astro.config.ts && \
    sed -i 's/adapter: vercel(),/adapter: node({ mode: "standalone" }),/' astro.config.ts

# Build the application
RUN bun run build

# Runtime stage
FROM node:18-alpine

WORKDIR /app

# Set NODE_ENV to production
ENV NODE_ENV=production

# Copy built application and dependencies from build stage
COPY --from=build /app/dist ./
COPY --from=build /app/node_modules ./node_modules/

# Expose port 4321
EXPOSE 4321

# Start the server
CMD ["node", "server/entry.mjs"]