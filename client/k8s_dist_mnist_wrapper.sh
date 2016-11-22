#!/bin/bash

if [ -z ${TS_CLUSTER_NAME} ]; then
  echo "TS_CLUSTER_NAME is not defined, exiting"
  exit 1
fi

if [ -z ${TS_CLUSTER_NAMESPACE} ]; then
  echo "TS_CLUSTER_NAMESPACE is not defined, exiting"
  exit 1
fi

#We should probably be in a waiting pattern until all components of the training cluster are ready. This will require inspecting the tensorset definition against what's out there.
workers=$(kubectl get svc -l tf-component=worker,ts-cluster-name=${TS_CLUSTER_NAME} --namespace=${TS_CLUSTER_NAMESPACE} -o jsonpath='{range .items[*]}{.metadata.name}{":"}{.spec.ports[?(@.name=="tensorflow")].port}{","}{end}') 
parameter_servers=$(kubectl get svc -l tf-component=parameter-server,ts-cluster-name=${TS_CLUSTER_NAME} --namespace=${TS_CLUSTER_NAMESPACE} -o jsonpath='{range .items[*]}{.metadata.name}{":"}{.spec.ports[?(@.name=="tensorflow")].port}{","}{end}')

#remove that last comma... please don't kill me.
workers=${workers%,}
parameter_servers=${parameter_servers%,}

/var/tf-k8s/scripts/dist_mnist_test.sh  --existing_servers True --ps_hosts $parameter_servers --worker_hosts $workers
