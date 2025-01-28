# Bulk Download applicant details from a LinkedIn job post

This tool will download applicant CVs for a given LinkedIn job application and extract the applicant's details to a CSV file to help you easily analyse the applicant information.

Follow the below steps to run the tool.

## Setup

1. Log into your LinkedIn account.
2. Go to **Jobs** --> **My Jobs** --> **Posted Jobs** and select the Job Application you want.
3. Copy the job Id (ie:4351345687) from the browser URL and save it to be used later.
4. Open the Network tracer and select the **Cookies** tab of a request sent to a `https://www.linkedin.com` URL.
5. Copy the value of the **li_at** cookie and save it to be used later.
6. Open the [download_cvs.sh](./download_cvs.sh) file and paste the cookie value at the **li_at_cookie** variable and the job id at **job_id**.
7. Set a value for the **cv_count** variable as needed to control the number of CVs that needs to be downloaded.

## Running the tool

Run `bash download_cvs.sh` to run the tool.

> If the file has been edited in Windows, please use `sed -i 's/\r$//' download_cvs.sh` command to replace the **\r** file endings.

## Output from the tool

A file named **applicant_data.csv** will be created with the following information regarding the applicants:

1. Applicant's public identifier
2. First name
3. Last name
4. Headline
5. Email
6. Contact number
7. Rating
8. Applied timestamp
9. Job application note
10. Job application top choice
11. Skill based qualification response
12. Candidate rejection record

The CVs will be collected to a folder named **CVs** where each CV will be named after the applicant's public identifier.

## Troubleshooting

In case of any failures in the API calls and if CV download fails for an applicant, a file named **failed.csv** will be created with the name and the Id of such applicants.

If you need to enable debug logs to further debug the behaviour of the tool, change the value of **DEBUG** variable to true and run the script.
