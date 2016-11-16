#!/bin/bash

#Failsafes:
## Check if there is another TensorSet controller running anywhere, exit if so.
## ...


TENSORSET_API_VERSION="stable.elsonrodriguez.com/v0/"
# apis/stable.elsonrodriguez.com/v0/namespaces/eorodrig/tensorsets/cluster-1

while true; do
if [ -e /run/secrets/kubernetes.io/serviceaccount/token ]; then
  KUBERNETES_TOKEN=$(</run/secrets/kubernetes.io/serviceaccount/token)
fi

if [ -e /run/secrets/kubernetes.io/serviceaccount/ca.crt ]; then
  ca_cert_flag="--ca-cert=/run/secrets/kubernetes.io/serviceaccount/ca.crt"
fi

#FIXME detect http or https for BASE_K8S_API
#KUBERNETES_SERVICE_PROTOCOL=http

BASE_CURL_CMD=curl -s -L --header "Authorization: Bearer $KUBERNETES_TOKEN" --header "Accept: application/json, */*" $ca_cert_flag
BASE_K8S_API=${KUBERNETES_SERVICE_PROTOCOL}://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}

tensorsets=$(curl -s -L --header "Authorization: Bearer $KUBERNETES_TOKEN" $ca_cert_flag  http://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/apis/stable.elsonrodriguez.com/v0/tensorsets)

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
  # it doesn't look like there's an api endpoint that accepts a hodgepodge of objects. the yaml must be parsed on client side and then submitted to the respective object-type endpoints per namespace. so we're punting to kubectl for this one.
  post_response=$(echo "$tensorset_objects" | kubectl create -f - 2>&1 | grep -v AlreadyExists)
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
  #STATUSCODE=200
  STATUSCODE=$(curl -s -L --header "Authorization: Bearer $KUBERNETES_TOKEN" $ca_cert_flag --output /dev/null --write-out "%{http_code}" http://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/apis/$TENSORSET_API_VERSION/namespaces/$rc_namespace/tensorsets/$rc_cluster_name)
  if [ $STATUSCODE -eq 404 ]; then
    # scale replicas, delete rc.
    original_rc=$(jq -rn '$tensorset_rc | fromjson | .items['$i']' --arg tensorset_rc "$tensorset_rcs")
    #patch_output=$(curl -XPATCH -s -L -k --header "Authorization: Bearer $KUBERNETES_TOKEN" $ca_cert_flag  http://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/api/v1/namespaces/eorodrig/replicationcontrollers/cluster-2-tf-ps0 -H "Accept: application/json, */*" -H "Content-Type: application/merge-patch+json" -d '{"spec":  {"replicas": 0}  }')
    new_rc=$(echo $original_rc | jq ".spec.replicas=0")
    put_output=$(echo $new_rc | curl -XPUT -s -L --header "Authorization: Bearer $KUBERNETES_TOKEN" $ca_cert_flag  http://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}${rc_selflink} -H "Content-Type:application/json" -d @- )
    #FIXME should enter a loop to check if resize has finished.
    sleep 2
    delete_output=$(curl -XDELETE -s -L --header "Authorization: Bearer $KUBERNETES_TOKEN" $ca_cert_flag  http://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}${rc_selflink} -d '{"kind":"DeleteOptions","apiVersion":"v1","orphanDependents":false}' -H "Accept: application/json, */*" -H "Content-Type: application/json")
    echo "Deleted orphaned rc $rc_name"
  fi
done
  
tensorset_svcs=$(curl -s -L --header "Authorization: Bearer $KUBERNETES_TOKEN" $ca_cert_flag  http://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/api/v1/services?labelSelector=creator%3Dtensorset-controller)
num_svcs=$(jq -n '$tensorset_svcs | fromjson | .items | length' --arg tensorset_svcs "$tensorset_svcs")

#Put watch on tensorsets to indicate when to trigger, or just sleep for x seconds.
done
