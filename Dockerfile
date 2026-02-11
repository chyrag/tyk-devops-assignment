# --- build stage ---
FROM golang:1.25-alpine AS builder
RUN apk add --no-cache make git
WORKDIR /app
COPY go.mod .
RUN go mod download
COPY . .
RUN make build-static

# --- runtime stage ---
FROM scratch
COPY --from=builder /app/dist/httpbin-static /httpbin
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
ENTRYPOINT ["/httpbin"]
