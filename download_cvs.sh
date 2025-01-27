#!/bin/bash

# User input
cv_count=10
LI_AT_COOKIE="<cookie>"
job_id="<job-id>"

# Global constants
CXRF_TOKEN="ajax:1372933860098402467"
list_query_id="voyagerHiringDashJobApplications.ac5767650ca37d8dc63546898d8e5af2"
applicant_query_id="voyagerHiringDashJobApplications.731eb2cfbc4991a433044de5e3967c89"
CVS_DIR="CVs"
APPLICANT_DATA_FILE="applicant_data.csv"
PAG_LIMIT=100

[ ! -d $CVS_DIR ] && mkdir $CVS_DIR
echo "Applicant,First Name,Last Name,Headline,Email,ContactNumber,Rating,Timestamp,JobApplicationNote,JobApplicationTopChoice,SkillBasedQualificationResponse,CandidateRejectionRecord" > "$APPLICANT_DATA_FILE"

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
  headline=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].applicantProfile.headline')
  email=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].contactEmail')
  phone_number=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].contactPhoneNumber.number')
  rating=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].rating')
  timestamp=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].createdAt')
  jobApplicationNote=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].jobApplicationNote')
  jobApplicationTopChoice=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].jobApplicationTopChoice')
  skillBasedQualificationResponse=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].skillBasedQualificationResponse')
  candidateRejectionRecord=$(echo "$applicant_data" | jq -r '.data.hiringDashJobApplicationsByIds[0].candidateRejectionRecord')

  echo "$identifier,$first_name,$last_name,\"$headline\",$email,$phone_number,$rating,$timestamp,$jobApplicationNote,$jobApplicationTopChoice,\"$skillBasedQualificationResponse\",$candidateRejectionRecord" >> $output_file
  echo "$identifier"
}

# Get the list of applicants.
for i in $(seq 0 $(($cv_count/$PAG_LIMIT)));
do
  start_index=$(($i*$PAG_LIMIT))
  count=$(min "$PAG_LIMIT" $(($cv_count-$start_index)))
  APPLICANT_LIST_URL="https://www.linkedin.com/voyager/api/graphql?variables=(start:$start_index,count:$count,jobPosting:urn%3Ali%3Afsd_jobPosting%3A$job_id,sortType:APPLIED_DATE,sortOrder:DESCENDING,ratings:List(UNRATED,GOOD_FIT,MAYBE))&queryId=$list_query_id"

  echo "Retrieving applicant list"
  applicant_list_response=$(curl -s "$APPLICANT_LIST_URL" \
    -H "csrf-token: $CXRF_TOKEN" \
    -H "Cookie: JSESSIONID=$CXRF_TOKEN; li_at=$LI_AT_COOKIE")

  # Get each applicant data.
  echo "$applicant_list_response" | jq -r '.data.hiringDashJobApplicationsByCriteria.elements[].entityUrn' | while read -r entityUrn; do

      echo "Retriving applicant data for $entityUrn"
      encoded_entityUrn=$(urlencode "$entityUrn")

      APPLICANT_DATA_URL="https://www.linkedin.com/voyager/api/graphql?variables=(jobApplicationUrns:List($encoded_entityUrn))&queryId=$applicant_query_id"

      applicant_response=$(curl -s "$APPLICANT_DATA_URL" \
        -H "csrf-token: $CXRF_TOKEN" \
        -H "Cookie: JSESSIONID=$CXRF_TOKEN; li_at=$LI_AT_COOKIE")

      # Extract applicant details
      name=$(extract_applicant_data "$applicant_response" "$APPLICANT_DATA_FILE")
      
      # Download CVs
      echo "Downloading CV for $name"
      DOWNLOAD_URL=$(echo "$applicant_response" | jq -r '.data.hiringDashJobApplicationsByIds[0].jobApplicationResume.elements[0].downloadUrl')
      CV_LOCATION="./$CVS_DIR/$name.pdf"

      curl "$DOWNLOAD_URL" \
      -H "csrf-token: $CXRF_TOKEN" \
      -H "Cookie: JSESSIONID=$CXRF_TOKEN; li_at=$LI_AT_COOKIE" \
      --output "$CV_LOCATION"

      if [ $? -eq 0 ]; then
        echo "Applicant CV successfully saved to $CV_LOCATION"
      else
        echo "Failed to fetch the data. Please check the URL or headers."
      fi
  done
done