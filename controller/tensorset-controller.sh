#!/bin/bash

#Failsafes:
## Check if there is another TensorSet controller running anywhere, exit if so.
## ...


echo "Started TensorSet Controller"

TENSORSET_API_VERSION="stable.elsonrodriguez.com/v0"
# apis/stable.elsonrodriguez.com/v0/namespaces/eorodrig/tensorsets/cluster-1

while true; do
  if [ -e /run/secrets/kubernetes.io/serviceaccount/token ]; then
    KUBERNETES_TOKEN=$(</run/secrets/kubernetes.io/serviceaccount/token)
  fi

  if [ -e /run/secrets/kubernetes.io/serviceaccount/ca.crt ]; then
    ca_cert_flag="--cacert /run/secrets/kubernetes.io/serviceaccount/ca.crt"
  fi

  #FIXME detect http or https for BASE_K8S_API
  if [ "$KUBERNETES_SERVICE_PORT" == "443" ]; then
    KUBERNETES_SERVICE_PROTOCOL=https
  else
    KUBERNETES_SERVICE_PROTOCOL=http
  fi

  BASE_CURL_CMD="curl -s -L --header 'Authorization: Bearer ${KUBERNETES_TOKEN}' --header 'Accept: application/json, */*' ${ca_cert_flag}"
  BASE_K8S_API=${KUBERNETES_SERVICE_PROTOCOL}://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}

  tensorsets=$(eval "${BASE_CURL_CMD} ${BASE_K8S_API}/apis/${TENSORSET_API_VERSION}/tensorsets")

  #get number of tensorsets
  num_tsets=$(jq -n '$tensorsets | fromjson  | .items | length' --arg tensorsets "$tensorsets")
  if [ "${num_tsets}" -gt 0 ]; then
    max_index=$(($num_tsets - 1))

    for i in `seq 0 $max_index`; do
      # set variables
      tensorset_name=$(jq -rn '$tensorsets | fromjson  | .items['$i'].metadata.name' --arg tensorsets "$tensorsets")
      tensorset_namespace=$(jq -rn '$tensorsets | fromjson  | .items['$i'].metadata.namespace' --arg tensorsets "$tensorsets")

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
      post_response=$(echo "$tensorset_objects" | kubectl create --namespace=$tensorset_namespace -f - 2>&1 | grep -v AlreadyExists)
      echo "Enforcing objects for TensorSet ${tensorset_name}"
    done
  fi
    # clean up wayward objects by checking all namespaces for objects with tensorset labels that do not have corresponding tensorset objects
  for object_type in replicationcontrollers services; do
    tensorset_objs=$(eval "${BASE_CURL_CMD} ${BASE_K8S_API}/api/v1/${object_type}?labelSelector=creator%3Dtensorset-controller")
    num_objs=$(jq -n '$tensorset_objs | fromjson | .items | length' --arg tensorset_objs "$tensorset_objs")

    if [ "${num_objs}" -gt 0 ]; then
      max_index=$(($num_objs - 1))

      for i in `seq 0 $max_index`; do
        obj_name=$(jq -rn '$tensorset_obj | fromjson | .items['$i'].metadata.name' --arg tensorset_obj "$tensorset_objs")
        obj_namespace=$(jq -rn '$tensorset_obj | fromjson | .items['$i'].metadata.namespace' --arg tensorset_obj "$tensorset_objs")
        obj_cluster_name=$(jq -rn '$tensorset_obj | fromjson | .items['$i'].metadata.labels."ts-cluster-name"' --arg tensorset_obj "$tensorset_objs")
        obj_selflink=$(jq -rn '$tensorset_obj | fromjson | .items['$i'].metadata.selfLink' --arg tensorset_obj "$tensorset_objs")

        STATUSCODE=$(eval "${BASE_CURL_CMD} ${BASE_K8S_API}/apis/${TENSORSET_API_VERSION}/namespaces/${obj_namespace}/tensorsets/${obj_cluster_name} --output /dev/null --write-out '%{http_code}'")
        if [ $STATUSCODE -eq 404 ]; then
          if [ "$object_type" == "replicationcontrollers" ]; then
            # need to scale replicas before delete rc until server-side cascading deletes are implemented.
            scale_patch="{\"spec\":  {\"replicas\": 0}  }"
            patch_output=$(eval "${BASE_CURL_CMD} -XPATCH ${BASE_K8S_API}${obj_selflink} --header 'Content-Type: application/merge-patch+json' -d '${scale_patch}'")
            #FIXME should enter a loop to check if resize has finished.
            echo "Scaled $object_type $obj_name to 0"
            sleep 2
          fi
          delete_options="{\"kind\":\"DeleteOptions\",\"apiVersion\":\"v1\",\"orphanDependents\":false}"
          delete_output=$(eval "${BASE_CURL_CMD} -XDELETE ${BASE_K8S_API}${obj_selflink} --header "Content-Type: application/json" -d '${delete_options}'")
          echo "Deleted orphaned $object_type $obj_name"
        fi
      done
    fi
  done
  #This should be replaced with a watch when this is rewritten.
  sleep 1
done
