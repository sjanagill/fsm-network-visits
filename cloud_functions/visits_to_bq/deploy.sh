#!/bin/bash

# For manual deployment: Authenticate
#gcloud auth login
#gcloud auth application-default login

# GCP_PROJECT : DEV or PROD
GCP_PROJECT=$1

# Check for GCP_PROJECT parameter
if [ -z "$GCP_PROJECT" ]; then
  echo "GCP_PROJECT environment variable not set"
  exit 1
fi

# COPY UTILS
if [ ! -d utils ]; then
  mkdir utils
fi
# Copy util files
cp ../../utils/cf_utils.py utils

# Deploy scoreboard-postprocess
gcloud functions deploy visits_to_bq  \
--quiet \
--gen2 \
--project $GCP_PROJECT \
--region europe-west1 \
--runtime python39 \
--timeout 1500s  \
--memory 256MB \
--env-vars-file env.yaml \
--service-account $SA_ACCOUNT \
--entry-point visits_to_bq \
--ingress-settings internal-only \
--trigger-http



