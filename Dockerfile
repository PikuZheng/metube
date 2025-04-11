FROM node:lts-alpine as builder

WORKDIR /metube
COPY ui ./
RUN npm ci && \
    export NODE_OPTIONS=--max_old_space_size=2000 && \
    node_modules/.bin/ng build --configuration production


FROM python:3.11-alpine

WORKDIR /app

COPY Pipfile* docker-entrypoint.sh ./

# Use sed to strip carriage-return characters from the entrypoint script (in case building on Windows)
# Install dependencies
RUN sed -i 's/\r$//g' docker-entrypoint.sh && \
    chmod +x docker-entrypoint.sh && \
    apk add --update aria2 coreutils shadow su-exec curl tini && \
    apk add --update --virtual .build-deps build-base gcc g++ musl-dev && \
    curl -s https://api.github.com/repos/lexiforest/curl-impersonate/releases/latest | \
     grep '"browser_download_url":' | grep "$(uname -m)-linux-musl.tar.gz" | grep 'libcurl-' | grep -o 'https://[^"]*' | \
     xargs wget -qO- |tar xvz -C /lib && \
    pip install --no-cache-dir pipenv curl_cffi==0.10 && \
    pipenv install --system --deploy --clear && \
    pip uninstall pipenv -y && \
    apk del .build-deps && \
    rm -rf /var/cache/apk/* && \
    mkdir /.cache && chmod 777 /.cache

COPY app ./app
COPY --from=builder /metube/dist/metube ./ui/dist/metube
COPY --from=mwader/static-ffmpeg:7.1 /ffmpeg /usr/local/bin/
COPY --from=mwader/static-ffmpeg:7.1 /ffprobe /usr/local/bin/

RUN chmod -R 755 ./app && \
    chmod 755 ./docker-entrypoint.sh

ENV UID=1000
ENV GID=1000
ENV UMASK=022

ENV DOWNLOAD_DIR /downloads
ENV STATE_DIR /downloads/.metube
ENV TEMP_DIR /downloads
VOLUME /downloads
EXPOSE 8090
ENTRYPOINT ["/sbin/tini", "-g", "--", "./docker-entrypoint.sh"]
