FROM centos-base:latest
COPY ./files/* /tmp/
COPY ./*.sh /tmp/
WORKDIR /tmp/
RUN sh ./install_rabbitmq.sh
RUN rm -v ./install_rabbitmq.sh
CMD sh boot.sh
