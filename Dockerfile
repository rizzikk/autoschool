FROM node:22-slim
ARG PB_VERSION=0.40.6
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl unzip ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
RUN curl -fsSL -o pb.zip "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip" \
    && unzip -q pb.zip pocketbase \
    && chmod +x pocketbase \
    && rm pb.zip
COPY pocketbase/pb_hooks ./pb_hooks
COPY pocketbase/tools ./tools
COPY pocketbase/start.sh ./start.sh
RUN sed -i 's/\r$//' start.sh && chmod +x start.sh
ENV PORT=10000
EXPOSE 10000
CMD ["./start.sh"]
