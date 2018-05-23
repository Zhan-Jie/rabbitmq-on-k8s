FROM alpine:latest

RUN mkdir /scripts/
COPY ./kubectl /bin/
COPY ./do_it.sh /scripts/

CMD sh /scripts/do_it.sh