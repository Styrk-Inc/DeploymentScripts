#!/bin/bash

#Synatx to give the values, to leave blank give *

# * * * * * command_to_execute
# - - - - -
# | | | | |
# | | | | +----- Day of week (0 - 7) (Sunday=0 or 7)
# | | | +------- Month (1 - 12)
# | | +--------- Day of month (1 - 31)
# | +----------- Hour (0 - 23)
# +------------- Minute (0 - 59)


# Parameters
Day_of_week="*"
Month="*"
Day_of_month="*"
Hour="17"
Minute="44"

# Full path to your script
SCRIPT_PATH="/home/vardaan/Documents/AI-Defend/Styrk_defend/defend_stage/aws-scripts/cloudformation-scripts/mongodb-backup.sh"

# Update the cron job line using the parameters
cron_job="$Minute $Hour $Day_of_month $Month $Day_of_week $SCRIPT_PATH"


crontab -l > mycron

echo "$cron_job" >> mycron

# cat mycron >> mycron.txt

# Install the new crontab
crontab mycron 

# Clean up
rm mycron

echo "Cron job added successfully."
