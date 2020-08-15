FROM scratch
LABEL maintainer="Kutti Project Maintainers"
WORKDIR /app
COPY  out/kutti-localprovisioner .
ENTRYPOINT [ "./kutti-localprovisioner" ]
