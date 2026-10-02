FROM node:22-alpine AS frontend
WORKDIR /build/web
RUN npm install --global pnpm@10.24.0
COPY app/web/package.json app/web/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY app/web/ ./
RUN pnpm release

FROM golang:1.25-alpine AS backend
WORKDIR /build
RUN apk add --no-cache git ca-certificates
COPY app/go.mod app/go.sum ./
RUN go mod download
COPY app/ ./
COPY --from=frontend /build/server/router/frontend/dist ./server/router/frontend/dist
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -tags netgo,osusergo -o /memos ./cmd/memos

FROM alpine:3.21 AS runtime
RUN apk add --no-cache ca-certificates tzdata && \
    addgroup -S -g 1001 appuser && \
    adduser -S -D -u 1001 -G appuser appuser && \
    mkdir -p /var/opt/memos && \
    chown appuser:appuser /var/opt/memos
COPY --from=backend /memos /usr/local/bin/memos
WORKDIR /var/opt/memos
ENV MEMOS_PORT=8081 MEMOS_DATA=/var/opt/memos
USER 1001:1001
EXPOSE 8081
ENTRYPOINT ["memos"]