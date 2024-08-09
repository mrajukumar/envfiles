#!/bin/bash
 
#set -o errexit
 
LOG_FILE="/opt/aiq-reports/core/var/log/aiq-post-deployment.log"
exec >> $LOG_FILE 2>&1
 
#sudo iptables -F
 
userdata="/aiq/serverdetails.json"
while [ ! -f $userdata ]
do
  sleep 1 # or less like 0.2
done
 
serverip=$(hostname -I | awk '{print $1}')
domainname=$(sudo jq -r '.FQDN' $userdata)
awsinstanceid=$(sudo jq -r '.AC_INSTANCE_ID' $userdata)
awsregion=$(sudo jq -r '.AWS_REGION' $userdata)
dbport=$(sudo jq -r '.RDS_DATABASE_PORT' $userdata)
dbhost=$(sudo jq -r '.RDS_DATABASE_HOST' $userdata)
dbname=$(sudo jq -r '.RDS_DATABASE_NAME_AIQ' $userdata)
dbnameuaa=$(sudo jq -r '.RDS_DATABASE_NAME_UAA' $userdata)
dbuser=$(sudo jq -r '.RDS_DATABASE_USER' $userdata)
dbpassword=$(sudo jq -r '.RDS_DATABASE_PASSWORD' $userdata)
awsstreamagent=$(sudo jq -r '.AWS_KINESIS_AGENT_STREAM' $userdata)
awsstreamctr=$(sudo jq -r '.AWS_KINESIS_CTR_STREAM' $userdata)
mskkafka=$(sudo jq -r '.MSK_KAFKA_FLAG' $userdata)
kafkacluster=$(sudo jq -r '.MSK_KAFKA_CLUSTER' $userdata)
clusterip=$(sudo jq -r '.ZK_CLUSTER_IP' $userdata)
redishost=$(sudo jq -r '.ELASTIC_CACHE_HOST' $userdata)
securedredis=$(sudo jq -r '.SECURED_REDIS_FLAG' $userdata)
timestreamdb=$(sudo jq -r '.TIMESTREAM_DB' $userdata)
httpsproxy=$(sudo jq -r '.HTTPS_PROXY' $userdata)
noproxy=$(sudo jq -r '.NO_PROXY' $userdata)
enablechat=$(sudo jq -r '.ENABLE_CHAT_CHANNEL_FLAG' $userdata)
s3bucket=$(sudo jq -r '.S3_BUCKET' $userdata)
app_timezone=$(sudo jq -r '.APP_TIMEZONE' $userdata)
#newly adding queues,routingprofiles,timestream_vpc_endpoint
Queues=$(sudo jq -r '.QUEUE_PREFIX' $userdata)
Routing_profile=$(sudo jq -r '.ROUTING_PROFILE_PREFIX' $userdata)
Timestream_query_endpoint_url=$(sudo jq -r '.TIMESTREAM_QUERY_URL' $userdata)
Timestream_write_endpoint_url=$(sudo jq -r '.TIMESTREAM_WRITE_URL' $userdata)
 
 
#temparory fix for agent_state issue
report_generation_time_value=$(sudo jq -r '.REPORT_TIMESET' $userdata)
echo "REPORT_GENERATION_TIME_VALUE: $report_generation_time_value"
 
 
# aws region for timestream
aws_timestream_region=$(sudo jq -r '.AWS_TIMESTREAM_REGION' $userdata)
 
# cross account variables
cross_aws_account=$(sudo jq -r '.CROSS_AWS_ACCOUNT_FLAG' $userdata)
cross_account_arn=$(sudo jq -r '.CROSS_ACCOUNT_ROLE_ARN' $userdata)
session_duration=$(sudo jq -r '.ASSUMED_ROLE_SESSION_DURATION' $userdata)
cross_account_region=$(sudo jq -r '.CROSS_ACCOUNT_REGION' $userdata)
 
# Replacing the endpoints as per AiQ requirements
redishost=$(echo $redishost | sed "s/:6379//g")
kafkacluster=$(echo $kafkacluster | sed "s/9094/9092/g")
clusterip=$(echo $clusterip | sed "s/:2181//g")
 
OPENSSL="/opt/aiq-reports/core/etc/openssl.cnf"
CORE_ENV_FILE="/opt/aiq-reports/core/envfile.core"
UAA_ENV_FILE="/opt/aiq-reports/uaa/envfile.uaa"
REVERSE_PROXY="/opt/aiq-reports/revproxy/nginx/reverse_proxy.conf"
SELF_SIGN="/opt/aiq-reports/core/selfSigned-certificate.sh"
KINESIS_CONSUMER="/opt/aiq-reports/kinesis-consumer/env.kinesis"
KINESIS_CONSUMER_CTR="/opt/aiq-reports/kinesis-consumer/env.kinesis.ctr"
RT_FEEDER="/opt/aiq-reports/rtfeeder/env.rtfeeder"
RTK_CONSUMER="/opt/aiq-reports/rtkconsumer/env.kconsumer"
SCHEDULER="/opt/aiq-reports/scheduler/env.aiqscheduler"
 
#echo "admin@123" | sudo -S sleep 1 && sudo su - acqueon
 
SERVER_TZ=$(sudo timedatectl | grep "Time zone"  | perl -pe 's/.*?Time zone: (\w+\/\w+)?\s.*$/$1/og')
#SET UTC Graphite
sudo sed -i "s#TZ=.*#TZ=$SERVER_TZ#" $CORE_ENV_FILE $UAA_ENV_FILE $GRAPHITE_ENV_FILE
 
sudo sed -i "s#IP.1 =.*#IP.1 = $serverip#" $OPENSSL
sudo sed -i "s#SERVER_NAME=.*#SERVER_NAME=$domainname#" $CORE_ENV_FILE
sudo sed -i "s#server_name .*;#server_name $domainname;#" $REVERSE_PROXY
sudo sed -i "s#Access-Control-Allow-Origin: https://.*;#Access-Control-Allow-Origin: https://$domainname;#" $REVERSE_PROXY
sudo sed -i "s#host=.*#host=\"$domainname\"#" $SELF_SIGN
 
#sudo /opt/aiq-reports/core/selfSigned-certificate.sh
 
sudo sed -i "s#SERVER_NAME=.*#SERVER_NAME=$domainname#" $CORE_ENV_FILE $UAA_ENV_FILE
 
# Update AiQ Core config
sudo sed -i "s#DATABASE_PORT=.*#DATABASE_PORT=$dbport#" $CORE_ENV_FILE
sudo sed -i "s#DATABASE_NAME=.*#DATABASE_NAME=$dbname#" $CORE_ENV_FILE
sudo sed -i "s#DATABASE_HOST=.*#DATABASE_HOST=$dbhost#" $CORE_ENV_FILE
sudo sed -i "s#DATABASE_USER=.*#DATABASE_USER=$dbuser#" $CORE_ENV_FILE
sudo sed -i "s#DATABASE_KEY=.*#DATABASE_KEY=$dbpassword#" $CORE_ENV_FILE
sudo sed -i "s#TIMESTREAM_DB=.*#TIMESTREAM_DB=$timestreamdb#" $CORE_ENV_FILE
sudo sed -i "s#AWS_INSTANCE_ID=.*#AWS_INSTANCE_ID=$awsinstanceid#" $CORE_ENV_FILE
sudo sed -i "s#AWS_REGION=.*#AWS_REGION=$awsregion#" $CORE_ENV_FILE
sudo sed -i "s#AWS_TIMESTREAM_REGION=.*#AWS_TIMESTREAM_REGION=$aws_timestream_region#" $CORE_ENV_FILE
sudo sed -i "s#REDIS_HOST=.*#REDIS_HOST=$redishost#" $CORE_ENV_FILE
sudo sed -i "s#SECURED_REDIS=.*#SECURED_REDIS=$securedredis#" $CORE_ENV_FILE
sudo sed -i "s#HTTPS_PROXY=.*#HTTPS_PROXY=$httpsproxy#" $CORE_ENV_FILE
sudo sed -i "s#NO_PROXY=.*#NO_PROXY=$noproxy#" $CORE_ENV_FILE
sudo sed -i "s#CROSS_AWS_ACCOUNT=.*#CROSS_AWS_ACCOUNT=$cross_aws_account#" $CORE_ENV_FILE
sudo sed -i "s#CROSS_ACCOUNT_ARN=.*#CROSS_ACCOUNT_ARN=$cross_account_arn#" $CORE_ENV_FILE
sudo sed -i "s#CROSS_ACCOUNT_REGION=.*#CROSS_ACCOUNT_REGION=$cross_account_region#" $CORE_ENV_FILE
sudo sed -i "s#SHOW_MISCELLANEOUS=.*#SHOW_MISCELLANEOUS=True#" $CORE_ENV_FILE
sudo sed -i "s#S3_BUCKET_NAME=.*#S3_BUCKET_NAME=$s3bucket#" $CORE_ENV_FILE
sudo sed -i "s#SMARTSHEET_COUNT=.*#SMARTSHEET_COUNT=520#" $CORE_ENV_FILE
sudo sed -i "s#BILLING_REPORTS_MAX_COUNT=.*#BILLING_REPORTS_MAX_COUNT=1000#" $CORE_ENV_FILE
sudo sed -i "s#APP_TIMEZONE=.*#APP_TIMEZONE=$app_timezone#" $CORE_ENV_FILE
sudo sed -i "s#WALLBOARD_MESSAGE_MAX_COUNT=.*#WALLBOARD_MESSAGE_MAX_COUNT=3#" $CORE_ENV_FILE
#adding vpc end points
if grep -q "^TIMESTREAM_QUERY_END_POINT_URL=" "$CORE_ENV_FILE"; then
  sudo sed -i "s/^TIMESTREAM_QUERY_END_POINT_URL=.*/TIMESTREAM_QUERY_END_POINT_URL=$Timestream_query_endpoint_url/" "$CORE_ENV_FILE"
else
  sed -i '5a TIMESTREAM_QUERY_END_POINT_URL='"$Timestream_query_endpoint_url" "$CORE_ENV_FILE" && sudo sed -i '5i\' "$CORE_ENV_FILE"   
fi
grep "TIMESTREAM_QUERY_END_POINT_URL=" $CORE_ENV_FILE
 
if grep -q "^TIMESTREAM_WRITE_END_POINT_URL=" "$CORE_ENV_FILE"; then
  sudo sed -i "s/^TIMESTREAM_WRITE_END_POINT_URL=.*/TIMESTREAM_WRITE_END_POINT_URL=$Timestream_write_endpoint_url/" "$CORE_ENV_FILE"
else
  sed -i '6a TIMESTREAM_WRITE_END_POINT_URL='"$Timestream_write_endpoint_url" "$CORE_ENV_FILE" && sudo sed -i '6i\' "$CORE_ENV_FILE"   
fi
grep "TIMESTREAM_WRITE_END_POINT_URL=" $CORE_ENV_FILE
 
 
# Update UAA config
sudo sed -i "s#DB_PORT=.*#DB_PORT=$dbport#" $UAA_ENV_FILE
sudo sed -i "s#DB_NAME=.*#DB_NAME=$dbnameuaa#" $UAA_ENV_FILE
sudo sed -i "s#DB_HOST=.*#DB_HOST=$dbhost#" $UAA_ENV_FILE
sudo sed -i "s#DB_USER=.*#DB_USER=$dbuser#" $UAA_ENV_FILE
 
 
sudo sed -i "s#RCV_GET_TOKEN_URI=https://.*/sso/oidc/v2/token#RCV_GET_TOKEN_URI=https://$serverip/sso/oidc/v2/token#" $CORE_ENV_FILE
sudo sed -i "s#IDP_BASE_URL=https://.*#IDP_BASE_URL=https://$domainname#" $CORE_ENV_FILE
 
#Updte config Kinesis Consumer Agnet events
#sudo sed -i "s#AWS_INSTANCE_ID=.*#AWS_INSTANCE_ID=$awsinstanceid#" $KINESIS_CONSUMER
sudo sed -i "s#AWS_REGION=.*#AWS_REGION=$awsregion#" $KINESIS_CONSUMER
sudo sed -i "s#AWS_KINESIS_STREAM_NAME=.*#AWS_KINESIS_STREAM_NAME=$awsstreamagent#" $KINESIS_CONSUMER
sudo sed -i "s#MSK_KAFKA=.*#MSK_KAFKA=$mskkafka#" $KINESIS_CONSUMER
sudo sed -i "s#KAFKA_CLUSTER=.*#KAFKA_CLUSTER=$kafkacluster#" $KINESIS_CONSUMER
sudo sed -i "s#CLUSTER_IP=.*#CLUSTER_IP=$clusterip#" $KINESIS_CONSUMER
sudo sed -i "s#REDIS_HOST=.*#REDIS_HOST=$redishost#" $KINESIS_CONSUMER
sudo sed -i "s#SECURED_REDIS=.*#SECURED_REDIS=$securedredis#" $KINESIS_CONSUMER
sudo sed -i "s#HTTPS_PROXY=.*#HTTPS_PROXY=$httpsproxy#" $KINESIS_CONSUMER
sudo sed -i "s#NO_PROXY=.*#NO_PROXY=$noproxy#" $KINESIS_CONSUMER
sudo sed -i "s#CROSS_AWS_ACCOUNT=.*#CROSS_AWS_ACCOUNT=$cross_aws_account#" $KINESIS_CONSUMER
sudo sed -i "s#CROSS_ACCOUNT_ARN=.*#CROSS_ACCOUNT_ARN=$cross_account_arn#" $KINESIS_CONSUMER
sudo sed -i "s#ROLE_SESSION_DURATION=.*#ROLE_SESSION_DURATION=$session_duration#" $KINESIS_CONSUMER
sudo sed -i "s#CROSS_ACCOUNT_REGION=.*#CROSS_ACCOUNT_REGION=$cross_account_region#" $KINESIS_CONSUMER
 
#Updte config Kinesis Consumer CTR
#sudo sed -i "s#AWS_INSTANCE_ID=.*#AWS_INSTANCE_ID=$awsinstanceid#" $KINESIS_CONSUMER_CTR
sudo sed -i "s#AWS_REGION=.*#AWS_REGION=$awsregion#" $KINESIS_CONSUMER_CTR
sudo sed -i "s#AWS_KINESIS_STREAM_NAME=.*#AWS_KINESIS_STREAM_NAME=$awsstreamctr#" $KINESIS_CONSUMER_CTR
sudo sed -i "s#MSK_KAFKA=.*#MSK_KAFKA=$mskkafka#" $KINESIS_CONSUMER_CTR
sudo sed -i "s#KAFKA_CLUSTER=.*#KAFKA_CLUSTER=$kafkacluster#" $KINESIS_CONSUMER_CTR
sudo sed -i "s#CLUSTER_IP=.*#CLUSTER_IP=$clusterip#" $KINESIS_CONSUMER_CTR
sudo sed -i "s#REDIS_HOST=.*#REDIS_HOST=$redishost#" $KINESIS_CONSUMER_CTR
sudo sed -i "s#SECURED_REDIS=.*#SECURED_REDIS=$securedredis#" $KINESIS_CONSUMER_CTR
sudo sed -i "s#HTTPS_PROXY=.*#HTTPS_PROXY=$httpsproxy#" $KINESIS_CONSUMER_CTR
sudo sed -i "s#NO_PROXY=.*#NO_PROXY=$noproxy#" $KINESIS_CONSUMER_CTR
sudo sed -i "s#CROSS_AWS_ACCOUNT=.*#CROSS_AWS_ACCOUNT=$cross_aws_account#" $KINESIS_CONSUMER_CTR
sudo sed -i "s#CROSS_ACCOUNT_ARN=.*#CROSS_ACCOUNT_ARN=$cross_account_arn#" $KINESIS_CONSUMER_CTR
sudo sed -i "s#ROLE_SESSION_DURATION=.*#ROLE_SESSION_DURATION=$session_duration#" $KINESIS_CONSUMER_CTR
sudo sed -i "s#CROSS_ACCOUNT_REGION=.*#CROSS_ACCOUNT_REGION=$cross_account_region#" $KINESIS_CONSUMER_CTR
 
#Updte config RT Feeder
sudo sed -i "s#AWS_INSTANCE_ID=.*#AWS_INSTANCE_ID=$awsinstanceid#" $RT_FEEDER
sudo sed -i "s#AWS_REGION=.*#AWS_REGION=$awsregion#" $RT_FEEDER
sudo sed -i "s#CLUSTER_IP=.*#CLUSTER_IP=$clusterip#" $RT_FEEDER
sudo sed -i "s#REDIS_HOST=.*#REDIS_HOST=$redishost#" $RT_FEEDER
sudo sed -i "s#SECURED_REDIS=.*#SECURED_REDIS=$securedredis#" $RT_FEEDER
sudo sed -i "s#CHAT_ENABLED=.*#CHAT_ENABLED=$enablechat#" $RT_FEEDER
sudo sed -i "s#HTTPS_PROXY=.*#HTTPS_PROXY=$httpsproxy#" $RT_FEEDER
sudo sed -i "s#NO_PROXY=.*#NO_PROXY=$noproxy#" $RT_FEEDER
sudo sed -i "s#CROSS_AWS_ACCOUNT=.*#CROSS_AWS_ACCOUNT=$cross_aws_account#" $RT_FEEDER
sudo sed -i "s#CROSS_ACCOUNT_ARN=.*#CROSS_ACCOUNT_ARN=$cross_account_arn#" $RT_FEEDER
sudo sed -i "s#ROLE_SESSION_DURATION=.*#ROLE_SESSION_DURATION=$session_duration#" $RT_FEEDER
sudo sed -i "s#CROSS_ACCOUNT_REGION=.*#CROSS_ACCOUNT_REGION=$cross_account_region#" $RT_FEEDER
 
#Update KConsumer config
sudo sed -i "s#MSK_KAFKA=.*#MSK_KAFKA=$mskkafka#" $RTK_CONSUMER
sudo sed -i "s#KAFKA_CLUSTER=.*#KAFKA_CLUSTER=$kafkacluster#" $RTK_CONSUMER
sudo sed -i "s#CLUSTER_IP=.*#CLUSTER_IP=$clusterip#" $RTK_CONSUMER
sudo sed -i "s#REDIS_HOST=.*#REDIS_HOST=$redishost#" $RTK_CONSUMER
sudo sed -i "s#AWS_REGION=.*#AWS_REGION=$awsregion#" $RTK_CONSUMER
sudo sed -i "s#TIMESTREAM_DB=.*#TIMESTREAM_DB=$timestreamdb#" $RTK_CONSUMER
sudo sed -i "s#SECURED_REDIS=.*#SECURED_REDIS=$securedredis#" $RTK_CONSUMER
sudo sed -i "s#HTTPS_PROXY=.*#HTTPS_PROXY=$httpsproxy#" $RTK_CONSUMER
sudo sed -i "s#NO_PROXY=.*#NO_PROXY=$noproxy#" $RTK_CONSUMER
sudo sed -i "s#AWS_TIMESTREAM_REGION=.*#AWS_TIMESTREAM_REGION=$aws_timestream_region#" $RTK_CONSUMER
sudo sed -i "s#TIMESTREAM_TTL_HOURS=.*#TIMESTREAM_TTL_HOURS=72#" $RTK_CONSUMER
sudo sed -i "s#TIMESTREAM_TTL_DAYS=.*#TIMESTREAM_TTL_DAYS=1095#" $RTK_CONSUMER
sudo sed -i "s#SESSION_EXPIRY_FLAG=.*#SESSION_EXPIRY_FLAG=False#" $RTK_CONSUMER
sudo sed -i "s#SESSION_EXPIRY_DURATION=.*#SESSION_EXPIRY_DURATION=21600#" $RTK_CONSUMER
sudo sed -i "s#SCHEDULE_DURATION=.*#SCHEDULE_DURATION=5#" $RTK_CONSUMER
 
#reids keya state value
rediskeyexpiration_time_value=$(sudo jq -r '.REDISKEY_TIME_VALUE' $userdata)
echo "STATE_CHANGE_KEY_EXPIREY_value: $rediskeyexpiration_time_value"

echo "redis start"
#adding redis key
if grep -q "^STATE_CHANGE_KEY_EXPIREY=" "$RTK_CONSUMER"; then
  sudo sed -i "s/^STATE_CHANGE_KEY_EXPIREY=.*/STATE_CHANGE_KEY_EXPIREY=$rediskeyexpiration_time_value/" "$RTK_CONSUMER"
else
  sed -i '28a STATE_CHANGE_KEY_EXPIREY='"$rediskeyexpiration_time_value" "$RTK_CONSUMER" && sudo sed -i '28i\' "$RTK_CONSUMER"   
fi
grep "STATE_CHANGE_KEY_EXPIREY=" $RTK_CONSUMER
echo "redis stop"
 
 
 
#added queue,routing_profile,timestream_vpc_endpoints
 
if grep -q "^QUEUES_PREFIX=" "$RTK_CONSUMER"; then
  sudo sed -i "s/^QUEUES_PREFIX=.*/QUEUES_PREFIX=$Queues/" "$RTK_CONSUMER"
else
  sed -i '6a QUEUES_PREFIX='"$Queues" "$RTK_CONSUMER" && sudo sed -i '6i\' "$RTK_CONSUMER"   
fi
grep "QUEUES_PREFIX=" $RTK_CONSUMER
 
if grep -q "^ROUTING_PROFILES_PREFIX=" "$RTK_CONSUMER"; then
  sudo sed -i "s/^ROUTING_PROFILES_PREFIX=.*/ROUTING_PROFILES_PREFIX=$Routing_profile/" "$RTK_CONSUMER"
else
  sed -i '7a ROUTING_PROFILES_PREFIX='"$Routing_profile" "$RTK_CONSUMER" && sudo sed -i '7i\' "$RTK_CONSUMER"   
fi
grep "ROUTING_PROFILES_PREFIX=" $RTK_CONSUMER
 
if grep -q "^TIMESTREAM_QUERY_END_POINT_URL=" "$RTK_CONSUMER"; then
  sudo sed -i "s/^TIMESTREAM_QUERY_END_POINT_URL=.*/TIMESTREAM_QUERY_END_POINT_URL=$Timestream_query_endpoint_url/" "$RTK_CONSUMER"
else
  sed -i '8a TIMESTREAM_QUERY_END_POINT_URL='"$Timestream_query_endpoint_url" "$RTK_CONSUMER" && sudo sed -i '8i\' "$RTK_CONSUMER"   
fi
grep "TIMESTREAM_QUERY_END_POINT_URL=" $RTK_CONSUMER
 
if grep -q "^TIMESTREAM_WRITE_END_POINT_URL=" "$RTK_CONSUMER"; then
  sudo sed -i "s/^TIMESTREAM_WRITE_END_POINT_URL=.*/TIMESTREAM_WRITE_END_POINT_URL=$Timestream_write_endpoint_url/" "$RTK_CONSUMER"
else
  sed -i '9a TIMESTREAM_WRITE_END_POINT_URL='"$Timestream_write_endpoint_url" "$RTK_CONSUMER" && sudo sed -i '9i\' "$RTK_CONSUMER"   
fi
grep "TIMESTREAM_WRITE_END_POINT_URL=" $RTK_CONSUMER
 
 
 
 
 
#Update scheduler config
sudo sed -i "s#TIMESTREAM_DB=.*#TIMESTREAM_DB=$timestreamdb#" $SCHEDULER
sudo sed -i "s#REDIS_HOST=.*#REDIS_HOST=$redishost#" $SCHEDULER
sudo sed -i "s#SECURED_REDIS=.*#SECURED_REDIS=$securedredis#" $SCHEDULER
sudo sed -i "s#AWS_TIMESTREAM_REGION=.*#AWS_TIMESTREAM_REGION=$aws_timestream_region#" $SCHEDULER
sudo sed -i "s#HTTPS_PROXY=.*#HTTPS_PROXY=$httpsproxy#" $SCHEDULER
sudo sed -i "s#NO_PROXY=.*#NO_PROXY=$noproxy#" $SCHEDULER
sudo sed -i "s#SCHEDULER_TIME_ZONE=.*#SCHEDULER_TIME_ZONE=$app_timezone#" $SCHEDULER
grep "SCHEDULER_TIME_ZONE=" $SCHEDULER
# temporary fix for agent_state issue
echo "temp testing start"
 
#sudo sed -i "s#REPORT_GENERATION_TIME=.*#REPORT_GENERATION_TIME=$report_generation_time_value#" $SCHEDULER
#sudo sed -i "/^REPORT_GENERATION_TIME=/s/.*/REPORT_GENERATION_TIME=$report_generation_time_value/" $SCHEDULER || echo "REPORT_GENERATION_TIME=$report_generation_time_value" >> $SCHEDULER
 
#below two are working
#echo "REPORT_GENERATION_TIME=$report_generation_time_value" | sudo tee -a "$SCHEDULER"
#echo -e "REPORT_GENERATION_TIME=$report_generation_time_value\n" | sudo tee -a "$SCHEDULER"
if grep -q "^REPORT_GENERATION_TIME=" "$SCHEDULER"; then
  sudo sed -i "s/^REPORT_GENERATION_TIME=.*/REPORT_GENERATION_TIME=$report_generation_time_value/" "$SCHEDULER"
else
  #echo "REPORT_GENERATION_TIME=$report_generation_time_value" | sudo tee -a "$SCHEDULER"
  sed -i '10a REPORT_GENERATION_TIME='"$report_generation_time_value" "$SCHEDULER" && sudo sed -i '10i\' "$SCHEDULER"   
fi
grep "REPORT_GENERATION_TIME=" $SCHEDULER
 
echo "temp testing end"
#adding vpc end points
if grep -q "^TIMESTREAM_QUERY_END_POINT_URL=" "$SCHEDULER"; then
  sudo sed -i "s/^TIMESTREAM_QUERY_END_POINT_URL=.*/TIMESTREAM_QUERY_END_POINT_URL=$Timestream_query_endpoint_url/" "$SCHEDULER"
else
  sed -i '6a TIMESTREAM_QUERY_END_POINT_URL='"$Timestream_query_endpoint_url" "$SCHEDULER" && sudo sed -i '6i\' "$SCHEDULER"   
fi
grep "TIMESTREAM_QUERY_END_POINT_URL=" $SCHEDULER
 
if grep -q "^TIMESTREAM_WRITE_END_POINT_URL=" "$SCHEDULER"; then
  sudo sed -i "s/^TIMESTREAM_WRITE_END_POINT_URL=.*/TIMESTREAM_WRITE_END_POINT_URL=$Timestream_write_endpoint_url/" "$SCHEDULER"
else
  sed -i '7a TIMESTREAM_WRITE_END_POINT_URL='"$Timestream_write_endpoint_url" "$SCHEDULER" && sudo sed -i '7i\' "$SCHEDULER"   
fi
grep "TIMESTREAM_WRITE_END_POINT_URL=" $SCHEDULER
 
 
sudo sed -i "s#AWS_REGION=.*#AWS_REGION=$awsregion#" $SCHEDULER
sudo sed -i "s#S3_BUCKET_NAME=.*#S3_BUCKET_NAME=$s3bucket#" $SCHEDULER
sudo sed -i "s#DATABASE_PORT=.*#DATABASE_PORT=$dbport#" $SCHEDULER
sudo sed -i "s#DATABASE_NAME=.*#DATABASE_NAME=$dbname#" $SCHEDULER
sudo sed -i "s#DATABASE_HOST=.*#DATABASE_HOST=$dbhost#" $SCHEDULER
sudo sed -i "s#DATABASE_USER=.*#DATABASE_USER=$dbuser#" $SCHEDULER
sudo sed -i "s#DATABASE_KEY=.*#DATABASE_KEY=$dbpassword#" $SCHEDULER
 
 
sudo /bin/bash /opt/aiq-reports/core/selfSigned-certificate.sh
 
# Assigning permission for aiq-reports
sudo chmod 777 -R /opt/aiq-reports
 
# Updating login and logout url for AiQ-Client
login_uri="https://$domainname/aiq/login/"
logout_uri="https://$domainname/aiq/logout/"
jq --arg login_url "$login_uri" '.[].fields._redirect_uris = $login_url' /opt/aiq-reports/aiq-client.json > /opt/aiq-reports/aiq-client-temp.json && cp /opt/aiq-reports/aiq-client-temp.json /opt/aiq-reports/aiq-client.json
jq --arg logout_url "$logout_uri" '.[].fields._post_logout_redirect_uris = $logout_url' /opt/aiq-reports/aiq-client.json > /opt/aiq-reports/aiq-client-temp.json && cp /opt/aiq-reports/aiq-client-temp.json /opt/aiq-reports/aiq-client.json
rm /opt/aiq-reports/aiq-client-temp.json
 
sudo mount /tmp -o remount,exec
 
#sudo docker login
/opt/aiq-reports/corectl start
 
decoded_db_password=$(echo $dbpassword | base64 --decode)
 
# Encrypt UAA password
if [ "$(docker ps -q -f name=uaa-core)" ]; then
    echo "found uaa container"
    if [ "$(docker ps -aq -f status=running -f name=uaa-core)" ]; then
        echo "encrypting uaa db password"
        encrypted_db_password=$(docker exec uaa-core bash -c "python3.6 manage.py encrypt $decoded_db_password 2> /dev/null")
        updated_db_password=$(echo -n "$encrypted_db_password" | tr -d '\r')
	sudo sed -i "s#DB_KEY=.*#DB_KEY=$updated_db_password#" $UAA_ENV_FILE
    fi
fi
 
# Restart UAA docker container after encrypting password
docker-compose -f /opt/aiq-reports/uaa/docker-compose.yml stop uaa
docker-compose -f /opt/aiq-reports/uaa/docker-compose.yml up -d uaa
 
# Run migrations AIQ
# Load fixtures
 
if [ "$(docker ps -q -f name=aiq-rpt-core)" ]; then
    echo "found aiq core container"
    if [ "$(docker ps -aq -f status=running -f name=aiq-rpt-core)" ]; then
        echo "creating database for aiq and uaa"
        docker exec aiq-rpt-core bash -c "python3.6 /opt/webapp/conf/dbcreation.py $dbname $dbnameuaa"
        echo "executing deployer"
        docker exec aiq-rpt-core bash  -c "/opt/webapp/conf/deployer"
        docker exec aiq-rpt-core bash  -c "python3.6 manage.py shell < /opt/webapp/conf/dbpatch.py"
    fi
fi
 
# Run migrations UAA
# Load fixtures
 
if [ "$(docker ps -q -f name=uaa-core)" ]; then
    echo "found uaa container"
    if [ "$(docker ps -aq -f status=running -f name=uaa-core)" ]; then
        echo "executing deployer"
        docker exec uaa-core bash  -c "/opt/server/deployer aiq"
        cp /opt/aiq-reports/aiq-client.json /opt/aiq-reports/core/var/log
        docker exec uaa-core bash -c "python3.6 /opt/server/manage.py loaddata /opt/log/aiq-client.json"
        rm -f /opt/aiq-reports/core/var/log/aiq-client.json
        sudo sed -i "s/#read_only/read_only/" /opt/aiq-reports/uaa/docker-compose.yml
    fi
fi
 
# Run migratons for Scheduler
 
if [ "$(docker ps -q -f name=aiqscheduler)" ]; then
    echo "found aiqscheduler container"
    if [ "$(docker ps -aq -f status=running -f name=aiqscheduler)" ]; then
        echo "executing migrations for scheduler"
        docker exec aiqscheduler bash -c "python3 /opt/scheduler/manage.py migrate django_celery_results"
        docker exec aiqscheduler bash -c "python3 /opt/scheduler/manage.py migrate django_celery_beat"
    fi
fi
 
#Initialize Timestream DB and MSK Topic Creation
/opt/aiq-reports/aws-resource-initialize-script
 
#Updating Schema for Timestream tables
if [ "$(docker ps -q -f name=aiq-rpt-rtkconsumer)" ]; then
    echo "found aiq rtk consumer"
    if [ "$(docker ps -aq -f status=running -f name=aiq-rpt-rtkconsumer)" ]; then
        echo "updating schema for tables"
        docker exec aiq-rpt-rtkconsumer bash -c "python3 /opt/kconsumer/timestream-schema-update.py"
    fi
fi
 
#Update Domain name
hostentry="$serverip $domainname"
echo "$hostentry"
sudo bash -c "echo -e '$hostentry' >> /etc/hosts"
 
# Fix for docker network issue
sudo sed -i "/^    container_name: aiq-rpt-core/a  \    \extra_hosts:\n\      \- '$domainname:$serverip'" /opt/aiq-reports/docker-compose.yml
sudo sed -i "/^    container_name: uaa-core/a  \    \extra_hosts:\n\      \- '$domainname:$serverip'" /opt/aiq-reports/uaa/docker-compose.yml
 
# Restart containers for resolving multiple redirect issue
/opt/aiq-reports/corectl stop
/opt/aiq-reports/corectl start
 
exit $?
 
 