#!/bin/bash

if [ -z ${TS_CLUSTER_NAME ]; then
  
fi

workers=$(kubectl get svc -l tf-component=worker,ts-cluster-name=${TS_CLUSTER_NAME} --namespace=${TS_CLUSTER_NAMESPACE} -o jsonpath='{range .items[*]}{.metadata.name}{":"}{.spec.ports[?(@.name=="tensorflow")].port}{","}{end}') 
parameter_servers=$(kubectl get svc -l tf-component=parameter-servers,ts-cluster-name=${TS_CLUSTER_NAME} --namespace=${TS_CLUSTER_NAMESPACE} -o jsonpath='{range .items[*]}{.metadata.name}{":"}{.spec.ports[?(@.name=="tensorflow")].port}{","}{end}') 

#remove that last comma... please don't kill me.
workers=${workers%,}
parameter_servers=${parameter_servers%,}

/var/tf-k8s/scripts/dist_mnist_test.sh  --existing_servers True --ps_hosts $parameter_servers --worker_hosts $workers
