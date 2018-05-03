FROM alpine:3.6

COPY ./files/* /tmp/

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN addgroup -S rabbitmq && adduser -S -h /var/lib/rabbitmq -G rabbitmq rabbitmq

# grab su-exec for easy step-down from root
RUN apk add --no-cache 'su-exec>=0.2'

RUN apk add --no-cache \
# Bash for docker-entrypoint
		bash \
# Procps for rabbitmqctl
		procps \
# Erlang for RabbitMQ
		erlang-asn1 \
		erlang-hipe \
		erlang-crypto \
		erlang-eldap \
		erlang-inets \
		erlang-mnesia \
		erlang \
		erlang-os-mon \
		erlang-public-key \
		erlang-sasl \
		erlang-ssl \
		erlang-syntax-tools \
		erlang-xmerl \
		curl

ENV RABBITMQ_HOME /opt/rabbitmq
ENV PATH $RABBITMQ_HOME/sbin:$PATH

# gpg: key 6026DFCA: public key "RabbitMQ Release Signing Key <info@rabbitmq.com>" imported
ENV RABBITMQ_GPG_KEY 0A9AF2115F4687BD29803A206B73A36E6026DFCA

ENV RABBITMQ_VERSION 3.6.15
ENV RABBITMQ_GITHUB_TAG rabbitmq_v3_6_15

RUN set -ex; \
	\
	apk add --no-cache --virtual .build-deps \
		ca-certificates \
		gnupg \
		libressl \
		xz \
	; \
    mv /tmp/rabbitmq-server-generic-unix-3.6.15.tar.xz /tmp/rabbitmq-server.tar.xz ; \
    mv /tmp/rabbitmq-server-generic-unix-3.6.15.tar.xz.asc /tmp/rabbitmq-server.tar.xz.asc ; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$RABBITMQ_GPG_KEY"; \
	gpg --batch --verify /tmp/rabbitmq-server.tar.xz.asc /tmp/rabbitmq-server.tar.xz; \
	rm -rf "$GNUPGHOME"; \
	\
	mkdir -p "$RABBITMQ_HOME"; \
	tar \
		--extract \
		--verbose \
		--file /tmp/rabbitmq-server.tar.xz \
		--directory "$RABBITMQ_HOME" \
		--strip-components 1 \
	; \
	rm -f /tmp/rabbitmq-server.tar.xz*; \
	\
# update SYS_PREFIX (first making sure it's set to what we expect it to be)
	grep -qE '^SYS_PREFIX=\$\{RABBITMQ_HOME\}$' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
	sed -ri 's!^(SYS_PREFIX=).*$!\1!g' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
	grep -qE '^SYS_PREFIX=$' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
	apk del .build-deps; \
    mkdir -p /var/lib/rabbitmq /etc/rabbitmq /var/log/rabbitmq \
	&& chown -R rabbitmq:rabbitmq /var/lib/rabbitmq /etc/rabbitmq /var/log/rabbitmq \
	&& chmod -R 777 /var/lib/rabbitmq /etc/rabbitmq /var/log/rabbitmq ; \
    mv -f /tmp/*.ez $RABBITMQ_HOME/plugins; \
    mv -f /tmp/rabbitmq.config /etc/rabbitmq; \
    rabbitmq-plugins enable --offline rabbitmq_management autocluster; \
    rabbitmq-plugins list; \
    mv /tmp/boot.sh /

CMD bash /boot.sh
