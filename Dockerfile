# PlantMetWiki SPARQL Explorer: the Snorql-UI engine (wikipathways/Snorql-UI) plus
# PlantMetWiki's configuration, theme, images and metadata, and the Apache config that
# puts the explorer in front of Virtuoso (SPARQL proxy, service description, VoID,
# dereferenceable IRIs, example IRIs). Updating the engine is a change of ENGINE;
# docker compose passes SNORQL_ENGINE (.env, default in docker-compose.yml) instead.
ARG ENGINE=ghcr.io/wikipathways/snorql-ui:1.5.1
FROM ${ENGINE}

COPY config.js /usr/local/apache2/htdocs/assets/js/config.js
COPY theme.css /usr/local/apache2/htdocs/assets/css/theme.css
COPY images/ /usr/local/apache2/htdocs/assets/images/
COPY head-extra.html /usr/local/apache2/htdocs/head-extra.html
COPY sd.ttl /usr/local/apache2/htdocs/sd.ttl
COPY vocab/pmw.ttl /usr/local/apache2/htdocs/vocab/pmw.ttl

# /sparql -> Virtuoso and the other routes; see httpd-proxy.conf.
COPY httpd-proxy.conf /usr/local/apache2/conf/extra/httpd-proxy.conf
RUN echo "Include conf/extra/httpd-proxy.conf" >> /usr/local/apache2/conf/httpd.conf
