# syntax=docker/dockerfile:1

FROM --platform=${BUILDPLATFORM}  golang:1.24-alpine AS builder
ARG VERSION_STRING
WORKDIR /kuttiproject/provisioner-local
COPY . .
RUN go mod tidy
RUN <<EOMULTIARCH
PLATFORMS="amd64 arm arm64 ppc64le s390x"
for platform in ${PLATFORMS}
do
    CGO_ENABLED='0' GOOS=linux GOARCH=$platform go build -o out/kutti-localprovisioner-linux-${platform} -ldflags "-X main.version=${VERSION_STRING}" ./cmd/kutti-localprovisioner/
done
EOMULTIARCH

FROM scratch AS final
ARG TARGETARCH
LABEL maintainer="Kutti Project Maintainers <support@kuttiproject.org>"
WORKDIR /app
COPY --from=builder /kuttiproject/provisioner-local/out/kutti-localprovisioner-linux-${TARGETARCH} kutti-localprovisioner
ENTRYPOINT ["./kutti-localprovisioner"]
