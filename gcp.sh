#!/usr/bin/env bash
# GCP Petclinic Deployment Script (Artifact Registry version, idempotent)
#   ./gcp_petclinic.sh up     # create infra
#   ./gcp_petclinic.sh push   # push image to Artifact Registry
#   ./gcp_petclinic.sh run    # run container on VM
#   ./gcp_petclinic.sh down   # cleanup

set -euo pipefail
source .env


up() {
  gcloud services enable compute.googleapis.com artifactregistry.googleapis.com

  # Networking
  if ! gcloud compute networks describe $NETWORK &>/dev/null; then
    gcloud compute networks create $NETWORK --subnet-mode=custom
  fi

  if ! gcloud compute networks subnets describe $SUBNET --region=$REGION &>/dev/null; then
    gcloud compute networks subnets create $SUBNET \
      --network=$NETWORK --region=$REGION --range=10.10.0.0/24
  fi

  if ! gcloud compute firewall-rules describe petallow-ssh &>/dev/null; then
    gcloud compute firewall-rules create petallow-ssh --network=$NETWORK --allow=tcp:22
  fi
  if ! gcloud compute firewall-rules describe petallow-http &>/dev/null; then
    gcloud compute firewall-rules create petallow-http --network=$NETWORK --allow=tcp:$PORT
  fi

  if ! gcloud compute addresses describe $IP --region=$REGION &>/dev/null; then
    gcloud compute addresses create $IP --region=$REGION
  fi
  ADDR=$(gcloud compute addresses describe $IP --region=$REGION --format='value(address)')

  if ! gcloud compute instances describe $VM --zone=$ZONE &>/dev/null; then
    gcloud compute instances create $VM \
      --zone=$ZONE --machine-type=e2-medium --subnet=$SUBNET \
      --address=$ADDR --image-family=debian-12 --image-project=debian-cloud
    gcloud compute ssh $VM --zone=$ZONE --command \
      "sudo apt-get update && sudo apt-get install -y docker.io"
  fi

  if ! gcloud artifacts repositories describe $REPO --location=$REGION &>/dev/null; then
    gcloud artifacts repositories create $REPO \
      --repository-format=docker \
      --location=$REGION \
      --description="Spring Petclinic Docker repo"
  fi
}

push() {
  gcloud auth configure-docker $REGION-docker.pkg.dev --quiet
  docker tag spring-petclinic-ar:latest $IMAGE
  docker push $IMAGE
}

run() {
  gcloud compute ssh $VM --zone=$ZONE --command \
    "sudo docker pull $IMAGE && sudo docker run -d -p $PORT:$PORT $IMAGE || echo 'Container may already be running'"
  ADDR=$(gcloud compute addresses describe $IP --region=$REGION --format='value(address)')
  echo "App running at: http://$ADDR:$PORT"
}

down() {
  gcloud compute instances delete $VM --zone=$ZONE --quiet || true
  gcloud compute firewall-rules delete petallow-ssh petallow-http --quiet || true
  gcloud compute addresses delete $IP --region=$REGION --quiet || true
  gcloud compute networks subnets delete $SUBNET --region=$REGION --quiet || true
  gcloud compute networks delete $NETWORK --quiet || true
  gcloud artifacts docker images delete $IMAGE --delete-tags --quiet || true
}

case "${1:-}" in
  up) up ;;
  push) push ;;
  run) run ;;
  down) down ;;
  *) echo "Usage: $0 {up|push|run|down}" ;;
esac
