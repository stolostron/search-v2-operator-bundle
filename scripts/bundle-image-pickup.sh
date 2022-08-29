#!/bin/bash

###############################################################################
# Copyright Contributors to the Open Cluster Management project
###############################################################################

####################
## COLORS
####################
CYAN="\033[0;36m"
GREEN="\033[0;32m"
PURPLE="\033[0;35m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m"

log_color () {
  case $1 in
    cyan)
      echo -e "${CYAN}$2 ${NC}"$3
    ;;
    green)
      echo -e "${GREEN}$2 ${NC}"$3
    ;;
    purple)
      echo -e "${PURPLE}$2 ${NC}"$3
    ;;
    red)
      echo -e "${RED}$2 ${NC}"$3
    ;;
    yellow)
      echo -e "${YELLOW}$2 ${NC}"$3
    ;;
  esac
}

log_color "cyan" "Initializing search bundle image pickup..."
echo -e "Current dir: $(pwd)\n"

####################
## ENV VARIABLES
####################
ORG=${ORG:-"stolostron"}
IMG_REGISTRY=${IMG_REGISTRY:-"quay.io/$ORG"}
PIPELINE_REPO=${PIPELINE_REPO:-"pipeline"}
RELEASE_BRANCH=${RELEASE_BRANCH:-"2.7-integration"}

####################
## IGNORE VARIABLES
####################
IGNORE_API_IMAGE_UPDATE=${IGNORE_API_IMAGE_UPDATE:-"false"}
IGNORE_COLLECTOR_IMAGE_UPDATE=${IGNORE_COLLECTOR_IMAGE_UPDATE:-"false"}
IGNORE_INDEXER_IMAGE_UPDATE=${IGNORE_INDEXER_IMAGE_UPDATE:-"false"}
IGNORE_OPERATOR_IMAGE_UPDATE=${IGNORE_OPERATOR_IMAGE_UPDATE:-"false"}
IGNORE_POSTGRES_IMAGE_UPDATE=${IGNORE_POSTGRES_IMAGE_UPDATE:-"true"}

####################
## PATHS (I.E DIR, FILES, ETC)
####################
OPERATOR_CSV_FILEPATH=${OPERATOR_CSV_FILEPATH:-"bundle/manifests/search-v2-operator.clusterserviceversion.yaml"}
README_FILEPATH=${README_FILEPATH:-"README.md"}

OPERATOR_CONTAINER_PATH=${OPERATOR_CONTAINER_PATH:-".spec.install.spec.deployments[0].spec.template.spec.containers[1]"}
OPERATOR_ENV_PATH=${OPERATOR_ENV_PATH:-"$OPERATOR_CONTAINER_PATH.env[].value"}
OPERATOR_IMAGE_PATH=${OPERATOR_IMAGE_PATH:-"$OPERATOR_CONTAINER_PATH.image"}

####################
## FUNCTIONS/METHODS
####################
display_component_images () {
  echo -e "Component Images"
  echo -e "==============================================================================" \
  "\nPOSTGRES:\t\t${POSTGRES_IMAGE}" \
  "\nSEARCH_API:\t\t${API_IMAGE}" \
  "\nSEARCH_COLLECTOR:\t${COLLECTOR_IMAGE}" \
  "\nSEARCH_INDEXER:\t\t${INDEXER_IMAGE}" \
  "\nSEARCH_OPERATOR:\t${OPERATOR_IMAGE}" \
  "\n==============================================================================\n"
}

ignore_component_update() {
  COMPONENT=$1
  case $COMPONENT in
    postgresql-13)
      IGNORE=$IGNORE_POSTGRES_IMAGE_UPDATE
    ;;
    search-collector)
      IGNORE=$IGNORE_COLLECTOR_IMAGE_UPDATE
    ;;
    search-indexer)
      IGNORE=$IGNORE_INDEXER_IMAGE_UPDATE
    ;;
    search-v2-api)
      IGNORE=$IGNORE_API_IMAGE_UPDATE
    ;;
    search-v2-operator)
      IGNORE=$IGNORE_OPERATOR_IMAGE_UPDATE
    ;;
    *)
      IGNORE=true
    ;;
  esac
  echo $IGNORE
}

get_images_from_csv () {
  log_color purple "Fetching component images from ${OPERATOR_CSV_FILEPATH}\n"

  for IMG in $(yq e ${OPERATOR_IMAGE_PATH} ${OPERATOR_CSV_FILEPATH}); do
    if [[ $IMG =~ .*"search-v2-operator".* ]]; then
      OPERATOR_IMAGE=$IMG
    fi
  done

  for IMG in $(yq e ${OPERATOR_ENV_PATH} ${OPERATOR_CSV_FILEPATH}); do
    if [[ $IMG =~ .*"postgres".* ]]; then
      POSTGRES_IMAGE=$IMG

    elif [[ $IMG =~ .*"search-collector".* ]]; then
      COLLECTOR_IMAGE=$IMG

    elif [[ $IMG =~ .*"search-indexer".* ]]; then
      INDEXER_IMAGE=$IMG

    elif [[ $IMG =~ .*"search-v2-api".* ]]; then
      API_IMAGE=$IMG
    fi
  done

  display_component_images
}

update_doc_entry () {
  # Check to see if the current date header is within the bundle-image-update.md file.
  if ! grep -q $(date +%m-%d-%Y) $README_FILEPATH; then
        echo -e "\n### Date of Change: $(date +%m-%d-%Y)\n" \
    "\n---" >> $README_FILEPATH
  fi

  echo -e "\n#### Updated Build Version: $(date)" >> $README_FILEPATH
  echo -e "\n| Image Name                                                             | Image Component  |\n" \
      "|------------------------------------------------------------------------|------------------|\n" \
      "| [postgresql-13](https://catalog.redhat.com/software/containers/rhel8/postgresql-13/5ffdbdef73a65398111b8362) | ${POSTGRES_IMAGE}  |\n" \
      "| [search-collector](https://github.com/stolostron/search-collector)     | ${COLLECTOR_IMAGE} |\n" \
      "| [search-indexer](https://github.com/stolostron/search-indexer)         | ${INDEXER_IMAGE}   |\n" \
      "| [search-v2-api](https://github.com/stolostron/search-v2-api)           | ${API_IMAGE}       |\n" \
      "| [search-v2-operator](https://github.com/stolostron/search-v2-operator) | ${OPERATOR_IMAGE}  |" >> $README_FILEPATH

  sed -i'.bak' 's/^[ \t]*//'  $README_FILEPATH
}

update_images_csv () {
  COMPONENT=$1
  NEW_IMAGE=$2
  IGNORE=$3

  log_color purple "Preparing to update component: ${COMPONENT} => ${NEW_IMAGE}\n"

  # TODO: Replace yq path with $OPERATOR_ENV_PATH. (Note: Adding the env variable seems to cause yq to return no results)
  if [[ $COMPONENT =~ .*"postgresql-13".* ]]; then
    yq -i e '.spec.install.spec.deployments[0].spec.template.spec.containers[1].env[1].value = "'${NEW_IMAGE}'"' $OPERATOR_CSV_FILEPATH
  
  elif [[ $COMPONENT =~ .*"search-indexer".* ]]; then
    yq -i e '.spec.install.spec.deployments[0].spec.template.spec.containers[1].env[1].value = "'${NEW_IMAGE}'"' $OPERATOR_CSV_FILEPATH

  elif [[ $COMPONENT =~ .*"search-collector".* ]]; then
    yq -i e '.spec.install.spec.deployments[0].spec.template.spec.containers[1].env[2].value = "'${NEW_IMAGE}'"' $OPERATOR_CSV_FILEPATH
  
  elif [[ $COMPONENT =~ .*"search-v2-api".* ]]; then
    yq -i e '.spec.install.spec.deployments[0].spec.template.spec.containers[1].env[3].value = "'${NEW_IMAGE}'"' $OPERATOR_CSV_FILEPATH

  # TODO: Replace yq path with $OPERATOR_IMAGE_PATH. (Note: Adding the env variable seems to cause yq to return no results)
  elif [[ $COMPONENT =~ .*"search-v2-operator".* && $IGNORE_POSTGRES_IMAGE_UPDATE == true ]]; then
    yq -i e '.spec.install.spec.deployments[0].spec.template.spec.containers[1].image = "'${NEW_IMAGE}'"' $OPERATOR_CSV_FILEPATH
  fi
}

# Fetch the current images from the csv file.
get_images_from_csv

# Set the default snapshot version.
if [ -f ./snapshot.ver ]; then
  DEFAULT_SNAPSHOT=`cat ./snapshot.ver`
  DEFAULT_POSTGRESQL_SNAPSHOT=`cat ./pg-snapshot.ver`

elif [[ " $@ " =~ " --silent " || " $@ " =~ " -s " ]]; then
  log_color "red" "ERROR: Silent mode will not work when ./snapshot.ver is missing"
  exit 1
fi

# Input or fetch the latest build image to update the csv file.
if [[ " $@ " =~ " --silent " || " $@ " =~ " -s " ]]; then
  log_color "cyan" "** Running in silent mode **"
else
  echo -e "Find snapshot tags @ https://quay.io/repository/stolostron/acm-custom-registry?tab=tags\nEnter SNAPSHOT TAG (SEARCH): (Press ENTER for default: ${DEFAULT_SNAPSHOT})\n"
  read -r SNAPSHOT_CHOICE

  if [[ "${SNAPSHOT_CHOICE}" != "" ]]; then
    DEFAULT_SNAPSHOT=$SNAPSHOT_CHOICE
    echo -e $DEFAULT_SNAPSHOT > ./snapshot.ver
  fi

  echo -e "Find snapshot tags @ https://catalog.redhat.com/software/containers/search?q=postgresql&p=1\nEnter SNAPSHOT TAG (POSTGRESQL): (Press ENTER for default: ${DEFAULT_POSTGRESQL_SNAPSHOT})\n"
  read -r SNAPSHOT_CHOICE

  if [[ "${SNAPSHOT_CHOICE}" != "" ]]; then
    DEFAULT_POSTGRES_SNAPSHOT=$SNAPSHOT_CHOICE
    echo -e $DEFAULT_SNAPSHOT > ./pg-snapshot.ver
  fi
fi

# Create an array containing the Search components that we will focus on for image versioning.
SEARCH_COMPONENTS=(postgresql-13 search-collector search-indexer search-v2-api search-v2-operator)

# Fetch component images and add current entry to bundle history markdown file.
# Running in silent mode will automatically fetch the latest image tag available within the stolostron/pipeline manifest.
if [[ " $@ " =~ " --silent " || " $@ " =~ " -s " ]]; then
  # Get the latest manifest file to capture the latest builds.
  PIPELINE_MANIFEST=$(curl GET https://raw.githubusercontent.com/$ORG/$PIPELINE_REPO/$RELEASE_BRANCH/manifest.json -H "Authorization: token $GITHUB_TOKEN")
  log_color "purple" "\nFetching image-tags from pipeline manifest.\n"
fi

for COMPONENT in ${SEARCH_COMPONENTS[@]}; do
  log_color "yellow" "Component: $COMPONENT"

  # Check to see if component update needs to be ignored.
  IGNORE=$(ignore_component_update $COMPONENT)

  if [[ $IGNORE == true ]]; then
    echo -e "Skipping image build update for component: $COMPONENT (IGNORE set to true)\n"
  else
    # Generate the base image.
    IMAGE=$IMG_REGISTRY/$COMPONENT

    if [[ " $@ " =~ " --silent " || " $@ " =~ " -s " ]]; then
      # Fetch search component within the manifest file.
      MANIFEST_JSON=$(echo $PIPELINE_MANIFEST | jq '.[] | select(."image-name" | match("'$COMPONENT'";"i"))')
      echo -e "Manifest Tag: $MANIFEST_JSON\n"

      # Extract the image tag from the manifest.
      TAG=$(echo $MANIFEST_JSON | jq -r '."image-tag"')  
    else
      # Set the image tag to the default/choice image.
      TAG=$DEFAULT_SNAPSHOT

      if [[ "$COMPONENT" == "postgresql-13" ]]; then
        TAG=$DEFAULT_POSTGRESQL_SNAPSHOT 
      fi
    fi

    # Build the latest image tag that will be used within the bundle.
    LATEST_TAG=$IMAGE:$TAG

    log_color "cyan" "Build Image: $LATEST_TAG"
    update_images_csv $COMPONENT $LATEST_TAG
  fi
done

echo "Checking image within csv after update.."
get_images_from_csv

# TODO: Create PR for latest image update.
if [[ `git status --porcelain | grep $OPERATOR_CSV_FILEPATH` ]]; then
  update_doc_entry

  # git add $OPERATOR_CSV_FILEPATH
  # git add $README_FILEPATH

#   git commit -sm "[release-2.7] Updated bundle image version"
fi

exit 0
