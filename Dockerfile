FROM directus/directus:12.1.1

USER root
WORKDIR /directus

RUN mkdir -p /directus/extensions /directus/uploads /directus/snapshot

COPY --chown=node:node extensions/ /directus/extensions/
COPY --chown=node:node snapshot/ /directus/snapshot/
COPY --chown=node:node scripts/ /directus/scripts/
COPY --chown=node:node docker-entrypoint.sh /directus/docker-entrypoint.sh

RUN sed -i 's/\r$//' /directus/docker-entrypoint.sh \
    && chown -R node:node /directus/extensions /directus/uploads /directus/snapshot /directus/scripts /directus/docker-entrypoint.sh \
    && find /directus/extensions /directus/uploads /directus/snapshot /directus/scripts -type d -exec chmod 755 {} \; \
    && find /directus/extensions /directus/uploads /directus/snapshot /directus/scripts -type f -exec chmod 644 {} \; \
    && chmod +x /directus/docker-entrypoint.sh

EXPOSE 8055

ENTRYPOINT ["/bin/sh", "/directus/docker-entrypoint.sh"]

