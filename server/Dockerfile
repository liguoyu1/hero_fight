# ---- Builder Stage ----
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev

# ---- Runner Stage ----
FROM node:20-alpine AS runner
WORKDIR /app

# Security: create non-root user
RUN addgroup -g 1001 appgroup && \
    adduser -u 1001 -G appgroup -s /bin/sh -D appuser

# Copy production dependencies and source
COPY --from=builder /app/node_modules ./node_modules
COPY package.json ./
COPY index.js ./
COPY db.js ./

# Switch to non-root user
USER appuser

EXPOSE 3000 3001

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "index.js"]
