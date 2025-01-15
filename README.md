# How to Bulk Download applicant details from LinkedIn job post
Follow the following steps to download the CVs of the job applicants for a LinkedIn job application.

### Setup
1. Log into your LinkedIn account.
2. Go to **Jobs** --> **My Jobs** --> **Posted Jobs** and select the Job Application you want.
3. Copy the job Id (ie:4351345687) from the browser URL and save it to be used later.
4. Open the Network tracer and select the **Cookies** tab of a request sent to a `https://www.linkedin.com` URL.
5. Copy the value of the **li_at** cookie and save it to be used later.
6. Open the [download_cvs.sh](./download_cvs.sh) file and paste the cookie value at the **LI_AT_COOKIE** variable and the job id at **job_id**.
7. Set a value for the **cv_count** variable as needed to control the number of CVs that needs to be downloaded.

### Running the script
Run `bash download_cvs.sh` to run the download script. 
> If the file has been edited in Windows, please use `sed -i 's/\r$//' download_cvs.sh` command to replace the **\r** file endings


A folder will be created named **CVs** with downloaded CVs of each applicant and the file **applicant_data.csv** will save the applicant details. 
