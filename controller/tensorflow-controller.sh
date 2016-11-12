#!/bin/bash

# check for tensorsets in all namespaces that do not have corresponding rcs/svcs

curl http://127.0.0.1:8080/apis/stable.elsonrodriguez.com/v0/namespaces/$namespace/tensorsets


# create object template via scripts/k8s_tensorflow.py

# submit object yaml to api under the tensorset's namespace

# clean up wayward objects by checking all namespaces for objects with tensorset labels that do not have corresponding tensorset objects
