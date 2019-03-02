FROM balenalib/raspberrypi3

RUN install_packages arpwatch nullmailer rsyslog ca-certificates psmisc

ADD cmd.sh /cmd.sh
ADD rsyslog.conf /rsyslog.conf

CMD ["bash", "cmd.sh"]

