FROM alpine:latest
RUN apk add --no-cache bash
RUN apk --no-cache add curl
RUN apk --no-cache add jq
RUN wget https://releases.hashicorp.com/sentinel/0.18.11/sentinel_0.18.11_linux_amd64.zip
RUN unzip sentinel_0.18.11_linux_amd64.zip && mv sentinel /usr/local/bin/sentinel
RUN mkdir /opt/sentinel
RUN mkdir /opt/sentinel/config-code
RUN mkdir /opt/sentinel/policies
RUN mkdir /opt/sentinel/common-functions
COPY script.sh /opt/sentinel/script.sh
RUN ["chmod", "+x", "/opt/sentinel/script.sh"]
ENTRYPOINT ["/opt/sentinel/script.sh"]
