FROM ubuntu:16.04
MAINTAINER Elson Rodriguez <elson.rodriguez@gmail.com>

ENV KUBECTL_VERSION v1.4.0

ADD scripts/ /
ADD tensorset-controller.sh /

RUN chmod +x /tensorset-controller.sh

ADD https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl /usr/local/bin/kubectl
RUN chmod +x /usr/local/bin/kubectl

ADD https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 /usr/local/bin/jq
RUN chmod +x /usr/local/bin/jq

ENTRYPOINT ["/tensorset-controller.sh"]


