#TensorSets

TensorSets are a [third-party resource](http://kubernetes.io/docs/user-guide/thirdpartyresources/) to manage [TensorFlow](https://github.com/tensorflow) training clusters running in [Kubernetes](https://kubernetes.io/).

## What's new

This is the initial release of the `tensorsets` repo.

# Known issues

This is a POC. Using this in production may result in errors.

## Walkthrough

First we define our ThirdPartyResource. This declares a new Kubernetes object type called `TensorSets`.

```
kubectl create -f kubernetes/tensorset-tpr-v0.yaml
```

Next, we deploy our TensorSet controller. The controller is a small app that performs actions based on TensorSet objects.

```
kubectl create -f kubernetes/tensorset-controller-v0.yaml
```

Now we create our first TensorSet:

```
kubectl create -f kubernetes/cluster1-ts-v0.yaml
```

The TensorSet controller will create your training cluster, and eventually you will see a bunch of pods in your current namespace.

Once they are all ready, start a training job:

```
kubectl create -f kubernetes/cluster1-job-v0.yaml
```

To see the progress of your job:

```
pods=$(kubectl get pods --selector=ts-cluster-name=cluster1 --output=jsonpath={.items..metadata.name})
kubectl logs -f pods
```

Once done with your training cluster, delete it:

```
kubectl delete tensorset cluster1
```

And your cluster will be gone!

## Roadmap

- v0 will wrap the existing python examples with some bash glue: https://github.com/tensorflow/tensorflow/tree/master/tensorflow/tools/dist_test
- v1 will allow more flexibility, incorporate learnings from v0, and will be re-implemented in Go.
