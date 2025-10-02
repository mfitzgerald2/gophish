# ──────────────────────────────────────────────────────────────────────────────
# Minify client side assets (JavaScript)
FROM node:lts AS build-js

RUN npm install -g gulp gulp-cli
WORKDIR /build
COPY . .
# If you have a lockfile, prefer: RUN npm ci --include=dev
RUN npm install --only=dev
RUN gulp


# ──────────────────────────────────────────────────────────────────────────────
# Build Golang binary (modern Go + modules)
FROM golang:1.22 AS build-golang

ENV GO111MODULE=on \
    CGO_ENABLED=1

WORKDIR /app

# Cache deps first
COPY go.mod go.sum ./
RUN go mod download

# Bring in the rest and build
COPY . .
RUN go build -v -o gophish .


# ──────────────────────────────────────────────────────────────────────────────
# Runtime container
FROM debian:stable-slim

RUN useradd -m -d /opt/gophish -s /bin/bash app

RUN apt-get update && \
    apt-get install --no-install-recommends -y jq libcap2-bin ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /opt/gophish

# App binary + app files (no inline comments on COPY lines)
COPY --from=build-golang /app/ ./
COPY --from=build-js /build/static/js/dist/ ./static/js/dist/
COPY --from=build-js /build/static/css/dist/ ./static/css/dist/

# Ensure config ownership and capabilities
RUN chown app. config.json
RUN setcap 'cap_net_bind_service=+ep' /opt/gophish/gophish

USER app

# Listen on all interfaces
RUN sed -i 's/127\.0\.0\.1/0.0.0.0/g' config.json
RUN touch config.json.tmp

EXPOSE 3333 8080 8443 80

CMD ["./docker/run.sh"]
