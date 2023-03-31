#!/bin/bash

# Set the database name and backup filename
DB_NAME=my_database
BACKUP_FILE=my_database_backup.sql.gz

# Set the S3 bucket and key for the backup file
BUCKET=my_s3_bucket
KEY=my_backup_folder/$BACKUP_FILE

# Set the email address for the status email
EMAIL=youremail@example.com

# Set the timestamp for the status email subject
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)

# Set the Glue job name and IAM role
JOB_NAME=my_glue_job_name
ROLE_NAME=my_iam_role_name

# Unzip the backup file
gunzip $BACKUP_FILE

# Restore the database from the backup file using Glue
aws glue start-job-run --job-name $JOB_NAME --arguments \
    '{"--database-name": "'$DB_NAME'", "--s3-backup-path": "s3://'$BUCKET'/'$KEY'", "--overwrite-existing-tables": "true"}' \
    --output text --query 'JobRunId' > job_run_id.txt

# Check the status of the Glue job and send a status email
STATUS=$(aws glue get-job-run --job-name $JOB_NAME --run-id $(cat job_run_id.txt) --query 'JobRun.JobRunState' --output text)

if [ "$STATUS" = "SUCCEEDED" ]; then
    echo "Database restore completed successfully."
    echo "Removing backup file..."
    rm $BACKUP_FILE
    echo "Backup file removed."
    echo "Sending status email..."
    echo "Subject: Database restore completed successfully ($TIMESTAMP)" | \
        aws ses send-email --from "youremail@example.com" --to "$EMAIL" --output text
    echo "Status email sent."
else
    echo "Database restore failed."
    echo "Sending status email..."
    echo "Subject: Database restore failed ($TIMESTAMP)" | \
        aws ses send-email --from "youremail@example.com" --to "$EMAIL" --output text
    echo "Status email sent."
fi

# Remove the job run ID file
rm job_run_id.txt
