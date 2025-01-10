#!/bin/bash
echo "*******************************************************"
echo "#####################################################################"
echo "Waiting for 40 seconds..."
sleep 30

echo "Execution resumed"
INPUT_TITLE="My GELF TCP"
check_input(){
    echo "checking input script called"
    curl -H "Authorization: Basic YWRtaW46YWRtaW4=" http://graylog:9000/api/system/inputs | jq --arg title "$INPUT_TITLE" '.inputs[] | select(.title == $title)'

}

# Function to create inputs in Graylog
create_input() {
echo "Creating input script called"
curl --location 'http://graylog:9000/api/system/inputs' \
--header 'X-Requested-By: cli' \
--header 'Content-Type: application/json' \
--header 'Authorization: Basic YWRtaW46YWRtaW4=' \
--data "{
\"title\": \"$INPUT_TITLE\",
\"type\": \"org.graylog2.inputs.gelf.tcp.GELFTCPInput\",
\"configuration\": {
\"bind_address\": \"0.0.0.0\",
\"port\": 12201,
\"recv_buffer_size\": 1048576,
\"number_worker_threads\": 16,
\"use_null_delimiter\": true,
\"max_message_size\": 2097152,
\"override_source\": null,
\"charset_name\": \"UTF-8\",
\"decompress_size_limit\": 8388608
},
\"global\": true
}"
}

# Function to create user in Graylog
create_user() {
echo "Creating user creation script called"
#-u admin:admin \
curl -X POST http://graylog:9000/api/users \
-H 'Content-Type: application/json' \
-H 'X-Requested-By:cli' \
-Header 'Authorization: Basic YWRtaW46YWRtaW4=' \
-d '{
"username": "newuser1",
"password": "newpassword",
"email": "user@example.com",
"first_name": "New",
"last_name": "User",
"roles":["Admin"],
"permissions": ["*"]
}'
}

# Function to continuously run a background process
keep_container_running() {
echo "Keeping container running..."
tail -f /dev/null
}

# Execute the functions
# check_input
create_input
# create_user
keep_container_running



