FROM scratch
LABEL maintainer="Kutti Project Maintainers <support@kuttiproject.org>"
WORKDIR /app
COPY  out/kutti-localprovisioner .
ENTRYPOINT [ "./kutti-localprovisioner" ]
