# EPL Preparation Tooling
This repo contains undeploy and deploy scripts as tools to aid Apigee hybrid customers during the EPL ( Enhanced proxy limit) conversion process



#Instructions

Steps for Undeploying Proxies

Install apigeeecli by following instructions at this [repo](https://github.com/apigee/apigeecli?tab=readme-ov-file#installation) 

Generate a token with this command

```bash
  token=$(gcloud auth print-access-token)
```

In the undeploy script set following variables for 
Your Apigee Environments and your Apigee ORG Name

Run the undeploy.sh script with
```bash
  ./undeploy.sh
```

You can now proceed with your pre-checks for the EPL conversion
Check Apigee hbyrid Components are Error Free and in Running state 

Apigee Hybrid Pod status
```bash
  kubectl get pods -n apigee
```

Check or Encryption key and Cassandra errors
```bash
  kubectl logs apigee-cassandra-default-0  | grep errors
```


You can now engage your Apigee CE and Apigee Engineering team to proceed with the actual conversion steps 


Steps for Re-deploying Proxies 

redeploy the undeployed proxies earlier with the deploy script

```bash
  ./redeploy.sh
```

