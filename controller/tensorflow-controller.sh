#!/bin/bash

# check for tensorsets in all namespaces that do not have corresponding rcs/svcs

if [ -e /run/secrets/kubernetes.io/serviceaccount/token ]; then
  KUBERNETES_TOKEN=$(</run/secrets/kubernetes.io/serviceaccount/token)
fi

if [ -e /run/secrets/kubernetes.io/serviceaccount/ca.crt ]; then
  ca_cert_flag="--ca-cert=/run/secrets/kubernetes.io/serviceaccount/ca.crt"
fi

export tensorsets=$(curl -s -L --header "Authorization: Bearer $KUBERNETES_TOKEN" $ca_cert_flag  http://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/apis/stable.elsonrodriguez.com/v0/tensorsets)

#number of items in namespace
num_items=$(jq -n '$tensorsets | fromjson  | .items | length' --arg tensorsets "$tensorsets")

max_index=$(($num_items - 1))


for i in `seq 0 1`; do
  tensorset_name=$(jq -rn '$tensorsets | fromjson  | .items['0'].metadata.name' --arg tensorsets "$tensorsets")
  tensorset_namespace=$(jq -rn '$tensorsets | fromjson  | .items['0'].metadata.name' --arg tensorsets "$tensorsets")

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
 echo "$tensorset_objects"  
 
done




# clean up wayward objects by checking all namespaces for objects with tensorset labels that do not have corresponding tensorset objects

#Failsafes:
## Check if there is another TensorSet controller running anywhere, exit if so.
##  
