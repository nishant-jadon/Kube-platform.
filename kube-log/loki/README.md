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


### Splunk integration
Sending logs to splunk, need to add following content to ```flunt-bit``` config file. Splunk output plugin allows to ingest logs into a Splunk Enterprise service through the HTTP Event Collector (HEC) interface. 

I use 15days trial Splunk cloud setup.

### Configure HTTP Event Collector on Splunk Enterprise

##### Enable HTTP Event Collector

Before you can use Event Collector to receive events through HTTP, you must enable it. For Splunk Enterprise, enable HEC through the Global Settings dialog box.

- Click Settings > Data Inputs.
- Click HTTP Event Collector.
- Click Global Settings.
- In the All Tokens toggle button, select Enabled.
- Rest leave as default
- Save

##### Create an Event Collector token
```
    [Output]
        Name           splunk
        Match          *
        Host           input-prd-p-vp7svl742rs7.cloud.splunk.com
        Port           8088
        TLS            On
        TLS.Verify     Off
        Message_Key    kubernetes
        Splunk_Token   <SPLUNK-TOKEN>
```

##### For Splunk testing use following curl 

```curl -k https://input-<SPLUNK-URL>:8088/services/collector/event -H "Authorization: Splunk <SPLUNK-TOKEN>" -d '{"event": "Hello World, Prasen"}'```
