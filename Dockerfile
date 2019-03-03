FROM balenalib/raspberrypi3 AS build

RUN install_packages python3

RUN curl -sSLf https://raw.githubusercontent.com/frispete/fetch-ethercodes/master/fetch_ethercodes.py -o /usr/local/bin/fetch_ethercodes.py && \
    chmod +x /usr/local/bin/fetch_ethercodes.py

RUN fetch_ethercodes.py -o /ethercodes.dat

FROM balenalib/raspberrypi3

RUN install_packages arpwatch nullmailer rsyslog ca-certificates psmisc

ADD cmd.sh /cmd.sh
ADD rsyslog.conf /rsyslog.conf
COPY --from=build /ethercodes.dat /usr/share/arpwatch/ethercodes.dat

CMD ["bash", "cmd.sh"]
