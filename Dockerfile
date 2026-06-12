FROM directus/directus:11.16.1

USER root

RUN mkdir -p /directus/extensions /directus/uploads /directus/snapshot

COPY extensions /directus/extensions
COPY snapshot /directus/snapshot
COPY docker-entrypoint.sh /directus/docker-entrypoint.sh

RUN chown -R node:node /directus/extensions /directus/uploads /directus/snapshot /directus/docker-entrypoint.sh \
    && sed -i 's/\r$//' /directus/docker-entrypoint.sh \
    && chmod -R 755 /directus/extensions /directus/uploads /directus/snapshot \
    && chmod +x /directus/docker-entrypoint.sh

USER root

EXPOSE 8055

ENTRYPOINT ["/bin/sh", "/directus/docker-entrypoint.sh"]
