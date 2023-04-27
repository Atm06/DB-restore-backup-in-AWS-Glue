#!/bin/bash

folder_path="/home/ec2-user/folder1"

#AWS SES CONFIGURATION

AWS_REGION="ap-south-1"

AWS_ACCESS_KEY_ID=""

AWS_SECRET_ACCESS_KEY=""

DB_USER="root"

DB_PASSWORD="redhat"

log_dir="/var/log/db_scripts"
log_file="$log_dir/$(date +"%Y-%m-%d")_db_creation.log"

user=$(whoami)

today=$(date "+%Y%m%d")
time=$(date +"%Y-%m-%d %H:%M:%S")

declare -A latest_files


for file in "$folder_path"/*; do

  #Condition that matches file names having projectname befoore "prod" and today's date after "prod"

  if [[ "$file" =~ ^(.*)_prod_${today}.sql.gz$ ]]; then

    project_name=$(basename "$file" | cut -d'_' -f1) #For filename "reflexvms_prod_20230419", project_name will be "reflexvms"

    file_date=$(date -r "$file" +"%Y%m%d") #Gives the modification date of file

    #Check if the file is the latest_files array for this project or not

    if [[ -z ${latest_files[$project_name]} || $file_date -gt ${latest_files[$project_name]} ]]; then

      #update the latest file for the project

      latest_files[$project_name]=$file_date
    fi
  fi
done

# Create databases for each project with latest file

for project_name in "${!latest_files[@]}"; do

  #extract latest file name for project

  latest_file=$(ls -t "${folder_path}/${project_name}"*_prod_*.sql.gz | head -n1)

  #Extract DB name

  DB_NAME="${project_name}_prod"

  if mysql -u $DB_USER -p$DB_PASSWORD -e "use $DB_NAME" >/dev/null 2>&1; then

    echo "Database $DB_NAME already exists, Dropping..."

    echo "${time} - ${user} - Database $DB_NAME dropped" >> $log_file

    mysql -u $DB_USER -p$DB_PASSWORD -e "DROP DATABASE ${DB_NAME}"

  fi

  #Create new DB

  mysql -u $DB_USER -p$DB_PASSWORD -e "CREATE DATABASE ${DB_NAME};"

  if [[ "$?" -eq 0 ]]; then

    echo "${time} - ${user} - Database $DB_NAME created" >> ${log_file}

    aws ses send-email --from mallickatm06@gmail.com --to ashutoshmallick1003@gmail.com --subject "Database was created successfully" --text "Database $DB_NAME was created successfully"

  else

    echo "${time} - ${user} - Failed to create Database $DB_NAME" >> ${log_file}

    aws ses send-email --from mallickatm06@gmail.com --to ashutoshmallick1003@gmail.com --subject " Failed to create Database" --text "There was an error creating database $DB_NAME please check"
  fi

  #Restore backup

  if gunzip < "$latest_file" | mysql -u $DB_USER -p$DB_PASSWORD "$DB_NAME"; then

    echo "${time} - ${user} - Database $DB_NAME Backup is Done" >> ${log_file}

    aws ses send-email --from mallickatm06@gmail.com --to ashutoshmallick1003@gmail.com --subject " Backup restore Successful" --text "Backup for $DB_NAME was restored successfully"

  fi

  #Remove backup file

  for OLD_FILE in $(ls -t $folder_path/$DB_NAME* | tail -n+2); do
    rm -rf $OLD_FILE
    echo "Deleted old backup file: $OLD_FILE"
  done
done
