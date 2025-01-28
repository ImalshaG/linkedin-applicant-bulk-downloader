#!/bin/bash

# User input
cv_count=10
LI_AT_COOKIE="<cookie>"
job_id="<job-id>"
DEBUG=false

# Global constants
CXRF_TOKEN="ajax:1372933860098402467"
LIST_QUERY_ID="voyagerHiringDashJobApplications.ac5767650ca37d8dc63546898d8e5af2"
APPLICANT_QUERY_ID="voyagerHiringDashJobApplications.731eb2cfbc4991a433044de5e3967c89"
CVS_DIR="CVs"
APPLICANT_DATA_FILE="applicant_data.csv"
FAILED_APPLICANTS_FILE="failed.csv"
PAG_LIMIT=100

# Function to url encode the applicant ID.
urlencode() {
    local raw="$1"
    local encoded=""
    for (( i=0; i<${#raw}; i++ )); do
        local char="${raw:i:1}"
        case "$char" in
            [a-zA-Z0-9.~_-]) encoded+="$char" ;;
            *) encoded+="$(printf '%%%02X' "'$char")" ;;
        esac
    done
    echo "$encoded"
}

min() {
  local num1="$1"
  local num2="$2"

  if ((num1 <= num2)); then
      min=$num1
  else
      min=$num2
  fi
  echo "$min"
}

# Function to extract applicant data
extract_applicant_data() {

  local applicant_data="$1"
  local output_file="$2"

  identifier=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].applicantProfile.publicIdentifier')
  first_name=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].applicantProfile.firstName')
  last_name=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].applicantProfile.lastName')
  headline=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].applicantProfile.headline' | tr -d '\t\n' | sed 's/"//g')
  email=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].contactEmail')
  phone_number=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].contactPhoneNumber.number')
  rating=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].rating')
  timestamp=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].createdAt')
  jobApplicationNote=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].jobApplicationNote')
  jobApplicationTopChoice=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].jobApplicationTopChoice.topChoiceMessage')
  skillBasedQualificationResponse=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].skillBasedQualificationResponse')
  candidateRejectionRecord=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].candidateRejectionRecord')

  echo "$identifier,$first_name,$last_name,\"$headline\",$email,$phone_number,$rating,$timestamp,$jobApplicationNote,$jobApplicationTopChoice,\"$skillBasedQualificationResponse\",$candidateRejectionRecord" >> $output_file
  echo "$identifier"
}

# Function to get applicant's data and download their CV
get_applicant_data() {

  local id="$1"

  debug_log "Retriving applicant data for $id"
  encoded_id=$(urlencode "$id")
  applicant_url="https://www.linkedin.com/voyager/api/graphql?variables=(jobApplicationUrns:List($encoded_id))&queryId=$APPLICANT_QUERY_ID"

  applicant_response=$(curl -s -w "\n%{http_code}" "$applicant_url" \
    -H "csrf-token: $CXRF_TOKEN" \
    -H "Cookie: JSESSIONID=$CXRF_TOKEN; li_at=$li_at_cookie")

  applicant_response_code=$(echo "$applicant_response" | tail -n 1)
  applicant_response_body=$(echo "$applicant_response" | sed '$d')

  if [[ $applicant_response_code -ne 200 ]]; then
    echo "Error when retrieving the applicant data. HTTP Status: $applicant_response_code"
    echo "null",$id >> $FAILED_APPLICANTS_FILE
    return 0
  fi
  debug_log "Applicant data retrieved successfully for $id"

  download_url=$(echo "$applicant_response_body" | jq -r '.data.hiringDashJobApplicationsByIds[0].jobApplicationResume.elements[0].downloadUrl')
  
  if [[ -n "$download_url" ]]; then
    cv_path="./$CVS_DIR/$name.pdf"

    #### Extract data of the applicant from the response.
    name=$(extract_applicant_data "$applicant_response_body" "$APPLICANT_DATA_FILE")
    
    #### Download the CV of each applicant.
    echo "Downloading CV for $name"

    download_response_code=$(curl -s -w "%{http_code}" "$download_url" \
      -H "Cookie: li_at=$li_at_cookie" \
      --output "$cv_path")

    if [[ $download_response_code -ne 200 ]]; then
      echo "Error when downloading the CV for $name."
      echo $name,$id >> $FAILED_APPLICANTS_FILE
    else
      debug_log "Applicant CV successfully downloaded!"  
    fi
  else
    echo "Download URL not available for $name."
    echo $name,$id >> $FAILED_APPLICANTS_FILE
  fi
  return 1
}

create_failed_file() {
  echo "Applicant","ID" > $FAILED_APPLICANTS_FILE
}

debug_log() {
  if [ "$DEBUG" == "true" ]; then
    echo "[DEBUG] $1"
  fi
}

#### Create the files and directories.
[ ! -d $CVS_DIR ] && mkdir $CVS_DIR
echo "Applicant,First Name,Last Name,Headline,Email,ContactNumber,Rating,Timestamp,JobApplicationNote,JobApplicationTopChoice,SkillBasedQualificationResponse,CandidateRejectionRecord" > "$APPLICANT_DATA_FILE"
create_failed_file

echo "Downloading CVs for $cv_count applicants..."
for i in $(seq 0 $(($cv_count/$PAG_LIMIT)));
do
  start_index=$(($i*$PAG_LIMIT))
  count=$(min "$PAG_LIMIT" $(($cv_count-$start_index)))
  APPLICANT_LIST_URL="https://www.linkedin.com/voyager/api/graphql?variables=(start:$start_index,count:$count,jobPosting:urn%3Ali%3Afsd_jobPosting%3A$job_id,sortType:APPLIED_DATE,sortOrder:DESCENDING,ratings:List(UNRATED,GOOD_FIT,MAYBE))&queryId=$LIST_QUERY_ID"

  #### Retrieving the applicant list for the job application.
  echo "Retrieving applicant list"
  applicant_list_response=$(curl -s -w "\n%{http_code}" "$APPLICANT_LIST_URL" \
    -H "csrf-token: $CXRF_TOKEN" \
    -H "Cookie: JSESSIONID=$CXRF_TOKEN; li_at=$li_at_cookie")

  applicant_list_response_code=$(echo "$applicant_list_response" | tail -n 1)
  applicant_list_response_body=$(echo "$applicant_list_response" | sed '$d')

  if [[ $applicant_list_response_code -ne 200 ]]; then
    echo "Error when retrieving the applicant list. HTTP Status: $applicant_list_response_code"
    continue
  elif [[ $(echo "$applicant_list_response_body" | jq -r '.data.hiringDashJobApplicationsByCriteria') == "null" ]]; then
    echo "No applicants for the given Job Id."
    continue
  else
    debug_log "Applicant list retrieval successful for $count CVs starting from $start_index."
  fi

  #### Get data of each applicant.
  echo "$applicant_list_response_body" | jq -r '.data.hiringDashJobApplicationsByCriteria.elements[].entityUrn' | while read -r entityUrn; do
    if ! get_applicant_data "$entityUrn"; then
      continue
    fi
  done
done

## Re-run the process to download CVs of failed applicants.
csv_content=$(<$FAILED_APPLICANTS_FILE) 
echo "Re-running the tool for any failed applicants."
create_failed_file

echo "$csv_content" | tail -n +2 | while IFS=, read -r applicant id; do
  if ! get_applicant_data "$id"; then
    continue
  fi
done
