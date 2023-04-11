FROM node:lts-alpine as builder

WORKDIR /metube
COPY ui ./
RUN npm ci && \
    export NODE_OPTIONS=--max_old_space_size=2000 && \
    node_modules/.bin/ng build --configuration production


FROM python:3.8-alpine

WORKDIR /app

COPY Pipfile* docker-entrypoint.sh ./

RUN chmod +x docker-entrypoint.sh && \
    apk add --update aria2 coreutils shadow su-exec && \
    apk add --update --virtual .build-deps gcc g++ musl-dev && \
    pip install --no-cache-dir pipenv && \
    pipenv install --system --deploy --clear && \
    pip uninstall pipenv -y && \
    apk del .build-deps && \
    rm -rf /var/cache/apk/* && \
    mkdir /.cache && chmod 777 /.cache

COPY favicon ./favicon
COPY app ./app
COPY --from=builder /metube/dist/metube ./ui/dist/metube
COPY --from=mwader/static-ffmpeg:5.1.2 /ffmpeg /usr/local/bin/
COPY --from=mwader/static-ffmpeg:5.1.2 /ffprobe /usr/local/bin/

RUN chmod -R 755 ./app && \
    chmod -R 755 ./favicon && \
    mkdir ../.cache && \
    chmod 777 ../.cache && \
    chmod 755 ./docker-entrypoint.sh

ENV UID=1000
ENV GID=1000
ENV UMASK=022

ENV DOWNLOAD_DIR /downloads
ENV STATE_DIR /downloads/.metube
VOLUME /downloads
EXPOSE 8081
CMD [ "./docker-entrypoint.sh" ]
