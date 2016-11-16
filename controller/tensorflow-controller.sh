#!/bin/bash

#Failsafes:
## Check if there is another TensorSet controller running anywhere, exit if so.
## ...

TENSORSET_API_VERSION="stable.elsonrodriguez.com/v0/"
# apis/stable.elsonrodriguez.com/v0/namespaces/eorodrig/tensorsets/cluster-1

# check for tensorsets in all namespaces that do not have corresponding rcs/svcs

if [ -e /run/secrets/kubernetes.io/serviceaccount/token ]; then
  KUBERNETES_TOKEN=$(</run/secrets/kubernetes.io/serviceaccount/token)
fi

if [ -e /run/secrets/kubernetes.io/serviceaccount/ca.crt ]; then
  ca_cert_flag="--ca-cert=/run/secrets/kubernetes.io/serviceaccount/ca.crt"
fi

export tensorsets=$(curl -s -L --header "Authorization: Bearer $KUBERNETES_TOKEN" $ca_cert_flag  http://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/apis/stable.elsonrodriguez.com/v0/tensorsets)

#get number of tensorsets
num_tsets=$(jq -n '$tensorsets | fromjson  | .items | length' --arg tensorsets "$tensorsets")

max_index=$(($num_tsets - 1))

for i in `seq 0 $max_index`; do
  # set variables
  tensorset_name=$(jq -rn '$tensorsets | fromjson  | .items['$i'].metadata.name' --arg tensorsets "$tensorsets")
  tensorset_namespace=$(jq -rn '$tensorsets | fromjson  | .items['$i'].metadata.name' --arg tensorsets "$tensorsets")

  grpc_port=$(jq -rn '$tensorsets | fromjson  | .items['$i'].spec.grpcPort' --arg tensorsets "$tensorsets")
  image=$(jq -rn '$tensorsets | fromjson  | .items['$i'].spec.image' --arg tensorsets "$tensorsets")
  parameter_servers=$(jq -rn '$tensorsets | fromjson  | .items['$i'].spec.parameterServers' --arg tensorsets "$tensorsets")
  workers=$(jq -rn '$tensorsets | fromjson  | .items['$i'].spec.workers' --arg tensorsets "$tensorsets")
  request_load_balancer=$(jq -rn '$tensorsets | fromjson  | .items['$i'].spec.requestLoadBalancer' --arg tensorsets "$tensorsets")

  # create object template via scripts/k8s_tensorflow.py 
  tensorset_objects=$(scripts/k8s_tensorflow.py --cluster_name $tensorset_name \
                            --num_workers $workers \
                            --num_parameter_servers $parameter_servers \
                            --grpc_port $grpc_port \
                            --request_load_balancer $request_load_balancer \
                            --docker_image $image)

  # submit object yaml to api under the tensorset's namespace
  #echo "$tensorset_objects"
done

# clean up wayward objects by checking all namespaces for objects with tensorset labels that do not have corresponding tensorset objects
# rcs first
tensorset_rcs=$(curl -s -L --header "Authorization: Bearer $KUBERNETES_TOKEN" $ca_cert_flag  http://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/api/v1/replicationcontrollers?labelSelector=creator%3Dtensorset-controller)
num_rcs=$(jq -n '$tensorset_rcs | fromjson | .items | length' --arg tensorset_rcs "$tensorset_rcs")

max_index=$(($num_rcs - 1))
for i in `seq 0 $max_index`; do
  rc_name=$(jq -rn '$tensorset_rc | fromjson | .items['$i'].metadata.name' --arg tensorset_rc "$tensorset_rcs")
  rc_namespace=$(jq -rn '$tensorset_rc | fromjson | .items['$i'].metadata.namespace' --arg tensorset_rc "$tensorset_rcs")
  rc_cluster_name=$(jq -rn '$tensorset_rc | fromjson | .items['$i'].metadata.labels."ts-cluster-name"' --arg tensorset_rc "$tensorset_rcs")
  rc_selflink=$(jq -rn '$tensorset_rc | fromjson | .items['$i'].metadata.selfLink' --arg tensorset_rc "$tensorset_rcs") 

  #echo $rc_name
  #echo $rc_namespace
  #echo $rc_cluster_name 
  #if 0 tensorsets with cluster_name and namespace then delete rc
  #apis/stable.elsonrodriguez.com/v0/namespaces/eorodrig/tensorsets/cluster-1
  STATUSCODE=$(curl -s -L --header "Authorization: Bearer $KUBERNETES_TOKEN" $ca_cert_flag --output /dev/stderr --write-out "%{http_code}" http://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/apis/$TENSORSET_API_VERSION/namespaces/$rc_namespace/tensorsets/$rc_cluster_name)
  if [ $STATUSCODE -eq 404 ]; then
    #delete rc
    delete_output=$(curl -XDELETE -s -L --header "Authorization: Bearer $KUBERNETES_TOKEN" $ca_cert_flag  http://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}${rc_selflink})
    echo $delete_output
    echo "boop" 
  fi
done
  
tensorset_svcs=$(curl -s -L --header "Authorization: Bearer $KUBERNETES_TOKEN" $ca_cert_flag  http://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/api/v1/services?labelSelector=creator%3Dtensorset-controller)
num_svcs=$(jq -n '$tensorset_svcs | fromjson | .items | length' --arg tensorset_svcs "$tensorset_svcs")
