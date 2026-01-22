FROM fluent/fluentd:v1.16-debian-1

USER root

# Elasticsearch у нас 7.17.x, тому фіксуємо сумісні версії gem'ів.
# Інакше можна отримати помилки на кшталт `undefined method [] for nil:NilClass`.
RUN apt-get update \
	&& apt-get install -y --no-install-recommends build-essential \
	&& gem install fluent-plugin-elasticsearch -v 5.2.5 --no-document \
	&& gem uninstall elasticsearch elasticsearch-api elasticsearch-transport elastic-transport -aIx || true \
	&& gem install elasticsearch -v 7.17.0 --no-document \
	&& apt-get purge -y --auto-remove build-essential \
	&& rm -rf /var/lib/apt/lists/*

COPY fluent.conf /fluentd/etc/fluent.conf

USER fluent