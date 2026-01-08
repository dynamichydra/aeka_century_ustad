# Multi-stage Dockerfile for React/TypeScript/Vite application

# Stage 1: Build stage
FROM node:22-alpine AS build

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json package-lock.json* ./

# Install dependencies
RUN npm ci --only=production=false

# Copy source code
COPY public ./public
COPY src ./src
COPY components.json db.json eslint.config.js index.html tsconfig.app.json tsconfig.json tsconfig.node.json vite.config.ts ./

# Build the application
RUN npm run build

# Stage 2: Production stage
FROM nginx:alpine AS production

# Copy the built application from build stage
COPY --from=build /app/dist /usr/share/nginx/html

# Copy custom nginx configuration if needed
# COPY nginx.conf /etc/nginx/nginx.conf

# Create a simple nginx configuration for SPA
RUN echo 'server { \
  listen 8000; \
  server_name localhost; \
  root /usr/share/nginx/html; \
  index index.html; \
  location / { \
  try_files $uri $uri/ /index.html; \
  } \
  location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ { \
  expires 1y; \
  add_header Cache-Control "public, immutable"; \
  } \
  }' > /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]