#!/bin/bash

# Set the directory where the files are being uploaded
UPLOAD_DIR=/path/to/upload/dir

# Set the MySQL username and password
DB_USER=username
DB_PASSWORD=password

# Get the latest uploaded file names
FILES=$(ls -t $UPLOAD_DIR/*.sql.gz)

# Loop through each file and create a database with the appropriate name
for FILE in $FILES
do
  # Extract the database name from the file name
  DB_NAME=$(echo $FILE | awk -F'[_.]' '{print $1 "_" $2 $3}')

  # Drop the database if it already exists
  mysql -u $DB_USER -p$DB_PASSWORD -e "DROP DATABASE IF EXISTS $DB_NAME"

  # Create the database
  mysql -u $DB_USER -p$DB_PASSWORD -e "CREATE DATABASE $DB_NAME"

  # Print a message to confirm that the database was created
  echo "Database $DB_NAME created"

  # Remove the file extension and gunzip the file
  BASENAME=$(basename $FILE .sql.gz)
  gunzip -c $FILE > $UPLOAD_DIR/$BASENAME.sql

  # Import the SQL file into the new database
  mysql -u $DB_USER -p$DB_PASSWORD $DB_NAME < $UPLOAD_DIR/$BASENAME.sql

  # Print a message to confirm that the SQL file was imported
  echo "SQL file $BASENAME.sql imported into $DB_NAME"

  # Remove the SQL file and gzipped file
  rm $UPLOAD_DIR/$BASENAME.sql
  rm $FILE
done

# Send email to notify that files have been restored
if [ $? -eq 0 ]; then
  SUBJECT="File Restore Complete"
  BODY="The latest files have been restored to the server and the corresponding databases have been created."
else
  SUBJECT="File Restore Failed"
  BODY="There was an error restoring the latest files to the server and creating the corresponding databases."
fi

echo "$BODY" | mail -s "$SUBJECT" user@example.com
