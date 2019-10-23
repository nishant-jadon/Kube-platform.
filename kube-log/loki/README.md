# Kubernetes logging with Loki and Fluent-bit


### Install Loki & Fluent-bit in Kubernetes

#### Step #1 Create Namespace

```kubectl create ns kubelog```

#### Step #2 Create ServiceAccount

```kubectl create -f loki-fluent-bit-account.yaml```

#### Step #3 Create Configmap

```kubectl create -f fluent-bit-loki-cm.yaml```

#### Step #4 Create secret

```kubectl create secret generic loki -n kubelog --from-file=loki.yaml```

#### Step #5 Create Statefulset 

```kubectl create -f loki-statefulset.yaml```

##### Note: Before moving to next step make sure ```loki statefulset``` UP and running

#### Step #6 Create service

```kubectl create -f loki-svc.yaml```

#### Step #7 Create Daemonset

```kubectl create -f fluent-bit-loki-ds.yaml```

