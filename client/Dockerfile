FROM elsonrodriguez/tf-dist-test-client:tensorset-example-0.0
MAINTAINER Elson Rodriguez <elson.rodriguez@gmail.com>

ENV KUBECTL_VERSION v1.4.0

ADD k8s_dist_mnist_wrapper.sh /
RUN chmod +x /k8s_dist_mnist_wrapper.sh

ADD https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl /usr/local/bin/kubectl
RUN chmod +x /usr/local/bin/kubectl

ENTRYPOINT ["/k8s_dist_mnist_wrapper.sh"]
