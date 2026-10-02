FROM httpd:2.4
 
ADD ./assets /usr/local/apache2/htdocs/assets/
COPY ./cookies.html /usr/local/apache2/htdocs/
COPY ./index.html /usr/local/apache2/htdocs/
COPY ./sd.ttl /usr/local/apache2/htdocs/sd.ttl
COPY ./vocab/pmw.ttl /usr/local/apache2/htdocs/vocab/pmw.ttl
 
ENV PATH /usr/local/apache2/bin:$PATH

# NOTE: deliberately no VOLUME for /usr/local/apache2/htdocs here — Docker/Compose
# preserves an existing anonymous volume's contents across container recreation,
# which silently shadows anything newly added to htdocs by this Dockerfile (bit
# us with sd.ttl and .well-known/void going stale after a rebuild). Nothing here
# needs htdocs to persist across recreations: script.sh regenerates its sed edits
# on every start, and .well-known/void is republished by the data-load scripts.

EXPOSE 80 443

WORKDIR /app
 
COPY ./script.sh /app/script.sh

RUN chmod 755 /app/script.sh
RUN chmod +x /app/script.sh

COPY ./entrypoint.sh /app/entrypoint.sh

RUN chmod 755 /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Copy proxy configuration for /sparql -> Virtuoso
COPY ./httpd-proxy.conf /usr/local/apache2/conf/extra/httpd-proxy.conf
 
# Include proxy config in main httpd.conf
RUN echo "Include conf/extra/httpd-proxy.conf" >> /usr/local/apache2/conf/httpd.conf

ENTRYPOINT ["/app/entrypoint.sh"]
