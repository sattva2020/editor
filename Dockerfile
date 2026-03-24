FROM oven/bun:1.3 AS builder

WORKDIR /app

# Copy everything
COPY . .

# Install dependencies
RUN bun install --frozen-lockfile

# Skip env validation during build
ENV SKIP_ENV_VALIDATION=true
ENV NEXT_TELEMETRY_DISABLED=1

# Install Node.js for Next.js build
RUN apt-get update && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Build the editor app
RUN bunx turbo run build --filter=editor

# Production image
FROM node:22-slim AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000

# Copy entire workspace (needed for internal packages resolution)
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/apps/editor ./apps/editor
COPY --from=builder /app/packages ./packages
COPY --from=builder /app/tooling ./tooling

WORKDIR /app/apps/editor

EXPOSE 3000

CMD ["npx", "next", "start", "-p", "3000"]
