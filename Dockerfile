FROM oven/bun:1.3 AS base

# Install dependencies only
FROM base AS deps
WORKDIR /app

# Copy workspace config files
COPY package.json bun.lock turbo.json ./
COPY apps/editor/package.json ./apps/editor/
COPY packages/ ./packages/
COPY tooling/ ./tooling/

# Install all dependencies
RUN bun install --frozen-lockfile

# Build the application
FROM base AS builder
WORKDIR /app

# Need node for next build
RUN apt-get update && apt-get install -y nodejs npm && rm -rf /var/lib/apt/lists/*

COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/apps/editor/node_modules ./apps/editor/node_modules
COPY --from=deps /app/packages/ ./packages/
COPY --from=deps /app/tooling/ ./tooling/
COPY . .

# Skip env validation during build
ENV SKIP_ENV_VALIDATION=true
ENV NEXT_TELEMETRY_DISABLED=1

# Build the editor app using turbo
RUN bun run build --filter=editor

# Production image
FROM node:22-slim AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000

# Copy the built Next.js app
COPY --from=builder /app/apps/editor/.next ./.next
COPY --from=builder /app/apps/editor/public ./public
COPY --from=builder /app/apps/editor/package.json ./package.json
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/apps/editor/node_modules ./apps/editor/node_modules

EXPOSE 3000

CMD ["npx", "next", "start", "-p", "3000"]
