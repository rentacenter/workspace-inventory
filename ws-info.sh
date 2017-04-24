#!/bin/bash

#
# Creator: Hemanth Jayaraman
# Purpose:
#   Simple script to query and generate a PSV (Pipe Seperated Values) inventory
#   of all AWS Workspaces in a given account including Monthly pricing.
# Dependencies:
#   bash v4
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

# Some elements of this script require features available in Bash4
# Thanks to Alex Deputy (http://stackoverflow.com/users/18829/alex-dupuy)
# for the Bash4 version check
case `eval 'echo $BASH@${BASH_VERSINFO[0]}' 2>/dev/null` in
    */bash@[456789])
        # Claims bash version 4+, check for func-names and associative arrays
        if ! eval "declare -A _ARRAY && func-name() { :; }" 2>/dev/null; then
            echo >&2 "bash $BASH_VERSION is not supported (not really bash?)"
            exit 1
        fi
        ;;
    */bash@[123])
        echo >&2 "bash $BASH_VERSION is not supported (version 4+ required)"
        exit 1
        ;;
    *)
        echo >&2 "This script requires BASH (version 4+) - not regular sh"
        echo >&2 "Re-run as \"bash $CMD\" for proper operation"
        exit 1
        ;;
esac

PROFILE=""
OUTPUT_FILE=""

usage() {
  if [ -n "$1" ]; then
    echo "$1"
    echo
  fi

  echo "Usage: $0 options"
  echo
  echo "OPTIONS:"
  echo "   -h     Show this message"
  echo "   -p     AWS profile name"
  echo "   -o     Output filename (Required)"
  exit 1
}

# Parse command-line arguments
while getopts p:o:h opt; do
	case "${opt}" in
    p)
      PROFILE="${OPTARG}"
      ;;
		o)
			OUTPUT_FILE="${OPTARG}"
      ;;
		h)
      usage
			;;
    \?)
      usage "Invalid argument supplied"
      ;;
  esac
done

# Validate we received required parameters
if [ -z "${OUTPUT_FILE}" ]; then usage; fi

# List of Regions to inspect
REGIONS=("us-east-1" \
         "us-west-2" \
         "ap-southeast-1" \
         "ap-southeast-2" \
         "ap-northeast-1" \
         "eu-central-1" \
         "eu-west-1")

# Pricing by Region and Bundle - GRAPHICS is listed as zero as no Monthly pricing is available
# REGION|BUNDLE|HARDWARE RESOURCES|MONTHLY PRICING|BYOL MONTHLY PRICING
declare -A PRICING=(
  ["us-east-1|VALUE"]="1 vCPU, 2 GiB Memory, 10 GB User Storage|25|21" \
  ["us-east-1|STANDARD"]="2 vCPU, 4 GiB Memory, 50 GB User Storage|35|31" \
  ["us-east-1|PERFORMANCE"]="2 vCPU, 7.5 GiB Memory, 100 GB User Storage|60|56" \
  ["us-east-1|GRAPHICS"]="8 vCPU, 15 GiB Memory, 1 GPU, 4 GiB Video Memory, 100 GB User Storage|0|0" \
  ["us-west-2|VALUE"]="1 vCPU, 2 GiB Memory, 10 GB User Storage|25|21" \
  ["us-west-2|STANDARD"]="2 vCPU, 4 GiB Memory, 50 GB User Storage|35|31" \
  ["us-west-2|PERFORMANCE"]="2 vCPU, 7.5 GiB Memory, 100 GB User Storage|60|56" \
  ["us-west-2|GRAPHICS"]="8 vCPU, 15 GiB Memory, 1 GPU, 4 GiB Video Memory, 100 GB User Storage|0|0" \
  ["ap-southeast-1|VALUE"]="1 vCPU, 2 GiB Memory, 10 GB User Storage|34|30" \
  ["ap-southeast-1|STANDARD"]="2 vCPU, 4 GiB Memory, 50 GB User Storage|49|45" \
  ["ap-southeast-1|PERFORMANCE"]="2 vCPU, 7.5 GiB Memory, 100 GB User Storage|82|78" \
  ["ap-southeast-1|GRAPHICS"]="8 vCPU, 15 GiB Memory, 1 GPU, 4 GiB Video Memory, 100 GB User Storage|0|0" \
  ["ap-southeast-2|VALUE"]="1 vCPU, 2 GiB Memory, 10 GB User Storage|33|29" \
  ["ap-southeast-2|STANDARD"]="2 vCPU, 4 GiB Memory, 50 GB User Storage|45|41" \
  ["ap-southeast-2|PERFORMANCE"]="2 vCPU, 7.5 GiB Memory, 100 GB User Storage|75|71" \
  ["ap-southeast-2|GRAPHICS"]="8 vCPU, 15 GiB Memory, 1 GPU, 4 GiB Video Memory, 100 GB User Storage|0|0" \
  ["ap-northeast-1|VALUE"]="1 vCPU, 2 GiB Memory, 10 GB User Storage|34|30" \
  ["ap-northeast-1|STANDARD"]="2 vCPU, 4 GiB Memory, 50 GB User Storage|47|43" \
  ["ap-northeast-1|PERFORMANCE"]="2 vCPU, 7.5 GiB Memory, 100 GB User Storage|78|74" \
  ["ap-northeast-1|GRAPHICS"]="8 vCPU, 15 GiB Memory, 1 GPU, 4 GiB Video Memory, 100 GB User Storage|0|0" \
  ["eu-central-1|VALUE"]="1 vCPU, 2 GiB Memory, 10 GB User Storage|29|25" \
  ["eu-central-1|STANDARD"]="2 vCPU, 4 GiB Memory, 50 GB User Storage|40|36" \
  ["eu-central-1|PERFORMANCE"]="2 vCPU, 7.5 GiB Memory, 100 GB User Storage|70|66" \
  ["eu-central-1|GRAPHICS"]="8 vCPU, 15 GiB Memory, 1 GPU, 4 GiB Video Memory, 100 GB User Storage|0|0" \
  ["eu-west-1|VALUE"]="1 vCPU, 2 GiB Memory, 10 GB User Storage|27|23" \
  ["eu-west-1|STANDARD"]="2 vCPU, 4 GiB Memory, 50 GB User Storage|37|33" \
  ["eu-west-1|PERFORMANCE"]="2 vCPU, 7.5 GiB Memory, 100 GB User Storage|64|60" \
  ["eu-west-1|GRAPHICS"]="8 vCPU, 15 GiB Memory, 1 GPU, 4 GiB Video Memory, 100 GB User Storage|0|0")

# List of owners to look into
OWNERS=("" "AMAZON")

echo "UserName|DirectoryId|Directory Name| Directory Alias| ComputerName|State|Subnet|IP Address| BundleId|Bundle Description|Bundle Owner|Bundle Name|Bundle Storage|Hardware Resources|Monthly Pricing|BYOL Monthly Pricing" > ${OUTPUT_FILE}

for AWSREGION in "${REGIONS[@]}"; do
  echo "Working in region ${AWSREGION}"

  # Get list of Directory IDs
  echo -n "|--> Getting directories ... "
  DIRECTORY_IDS=$(aws ${PROFILE:+--profile ${PROFILE}} --region ${AWSREGION} workspaces describe-workspace-directories --query 'Directories[].[DirectoryId,DirectoryName,Alias]' --output text | tr "\t" "|")

  # Print out count of directories
  DIRECTORY_COUNT=$(echo "${DIRECTORY_IDS}" | wc -l | sed 's/ //g')
  if [ -z "${DIRECTORY_IDS}" ]; then
    echo "no directories found"
    continue
  else
    echo "found ${DIRECTORY_COUNT}"
  fi

  # Get a list of Bundles in each region and for each Owner (convert from tab-delimited to pipe-delimited file)
  BUNDLES=""
  echo -n "|--> Getting bundles ... "
  for OWNER in "${OWNERS[@]}"; do
    OUTPUT=$(aws ${PROFILE:+--profile ${PROFILE}} --region ${AWSREGION} workspaces describe-workspace-bundles ${OWNER:+--owner ${OWNER}} --query 'Bundles[].[BundleId,Description,Owner,Name,UserStorage.Capacity,ComputeType.Name]' --output text | tr "\t" "|")
    BUNDLES=$(echo -e "${BUNDLES}\n${OUTPUT}")
  done

  # Print out count of bundles
  BUNDLE_COUNT=$(echo "${BUNDLES}" | wc -l | sed 's/ //g')
  echo "found ${BUNDLE_COUNT}"

  # Iterate over each Directory ID
  while IFS= read DIR_ID_LINE; do
    # Parse out directory details
    DIRECTORY_ID=$(echo ${DIR_ID_LINE} | awk -F"|" '{print $1}')
    DIRECTORY_NAME=$(echo ${DIR_ID_LINE} | awk -F"|" '{print $2}')
    DIRECTORY_ALIAS=$(echo ${DIR_ID_LINE} | awk -F"|" '{print $3}')

    # Reset next token parameters for this directory
    NT=""

    echo -n "|--> Checking workspaces in directory ${DIRECTORY_NAME} ... "
    while true; do
      # Describe current page of workspaces
      OUTPUT=$(aws ${PROFILE:+--profile ${PROFILE}} --region ${AWSREGION} workspaces describe-workspaces --directory-id ${DIRECTORY_ID} ${NT:+--starting-token ${NT}} --output text --query '[[{NT:NextToken}], Workspaces[*].[UserName,DirectoryId,ComputerName,State,SubnetId,IpAddress,BundleId]]' | tr "\t" "|")
      WORKSPACES=$(echo "${OUTPUT}" | grep -v -E "^(None|NT)")
      NT=$(echo "${OUTPUT}" | grep "^NT|" | awk -F"|" '{print $NF}')

      while IFS= read WORKSPACES_LINE; do
        BUNDLE_ID=$(echo ${WORKSPACES_LINE} | awk -F"|" '{print $7}')
        BUNDLE_LINE=$(echo "${BUNDLES}" | grep "^${BUNDLE_ID}")
        COMPUTETYPE_NAME=$(echo "${BUNDLE_LINE}" | awk -F"|" '{print $6}')
        FULL_LINE=$(echo "${WORKSPACES_LINE}" | sed -e "s~${BUNDLE_ID}~${BUNDLE_LINE}~" -e "s~${DIRECTORY_ID}~${DIRECTORY_ID}|${DIRECTORY_NAME}|${DIRECTORY_ALIAS}~")

        for PRICE in "${!PRICING[@]}"; do
          if [ "${AWSREGION}|${COMPUTETYPE_NAME}" = "${PRICE}" ]; then
            echo "${FULL_LINE}" | sed "s~${COMPUTETYPE_NAME}~${PRICING[${PRICE}]}~" >> "${OUTPUT_FILE}"
            break
          fi
        done
      done <<< "${WORKSPACES}"

      # If there is not a next page, break out
      if [ -z "${NT}" ]; then
        break;
      fi
    done
    echo "completed"
  done <<< "${DIRECTORY_IDS}"
done
