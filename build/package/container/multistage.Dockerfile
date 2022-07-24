FROM golang:1.18-alpine AS builder
ARG VERSION_STRING
WORKDIR /kuttiproject/provisioner-local
COPY . .
RUN apk update && apk add git
RUN go mod tidy
RUN CGO_ENABLED='0' go build -o out/kutti-localprovisioner -ldflags "-X main.version=${VERSION_STRING}" ./cmd/kutti-localprovisioner/

FROM scratch AS final
LABEL maintainer="Kutti Project Maintainers <support@kuttiproject.org>"
WORKDIR /app
COPY --from=builder /kuttiproject/provisioner-local/out/kutti-localprovisioner .
ENTRYPOINT ["./kutti-localprovisioner"] 