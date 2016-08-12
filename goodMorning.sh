#!/bin/bash

ELBNAME="ELBTEST"
ELB_SG=sg-2ce9ae57
UBUNTU1404_IMAGE="ami-2d39803a"
LC_NAME="LCTEST"
KEY_NAME="TESTDEVOPS"
ASG_NAME="ASG_TEST"
APIS_ASG_NAME="ASG_API"
MIN_SIZE=1
MAX_SIZE=3
DESIRED_CAPACITY=1
HEALTH_CHECK_TYPE="ELB"
HEALTH_CHECK_GRACE_PERIOD=300
SUBNETS='subnet-013c3c77,subnet-48401d10,subnet-c76030ed,subnet-023f0c3f'

echo "CREATING ELB..."
aws elb create-load-balancer --load-balancer-name $ELBNAME \
	--listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" \
	--subnets subnet-013c3c77 subnet-48401d10 subnet-c76030ed subnet-023f0c3f  \
	--security-groups $ELB_SG

echo "Configuring Health Check..."
aws elb configure-health-check --load-balancer-name $ELBNAME \
	--health-check Target=TCP:80,Interval=30,UnhealthyThreshold=10,HealthyThreshold=2,Timeout=5

echo "Tagging ELB..."
aws elb add-tags --load-balancer-name $ELBNAME --tags "Key=Name,Value=$ELBNAME" "Key=ENV,Value=TEST"
echo "ELB successfully created!"


SG_API="$(aws ec2 describe-security-groups --filters Name=ip-permission.from-port,Values=80 \
				Name=ip-permission.to-port,Values=80 \
				Name=ip-permission.from-port,Values=22 Name=ip-permission.to-port,Values=22 \
				| jq -r .SecurityGroups[].GroupId)"


if [ -z "${SG_API}" ] 
then
	echo "Error while recovering API AMI or API Security Group. Quiting!"
	exit 1
fi

echo "CREATING LAUNCH CONFIGURATION..."
aws autoscaling create-launch-configuration --launch-configuration-name $LC_NAME \
				--key-name $KEY_NAME --image-id $UBUNTU1404_IMAGE --security-groups $SG_API \
				--instance-type t2.micro \
				--iam-instance-profile Admin \
				--user-data file://~/userdata.txt 
echo "Launch Configuration created successfully!"



LC_NAME="$(aws autoscaling describe-launch-configurations \
			| jq -r .LaunchConfigurations[].LaunchConfigurationName)"
ELB_NAME="$(aws elb describe-load-balancers \
			| jq -r .LoadBalancerDescriptions[].LoadBalancerName)"


if [ -z "${ELB_NAME}" ] || [ -z "${LC_NAME}" ] 
then
	echo "Error while recovering LaunchConfiguration name or ELB name. Quiting!"
	exit 1
fi

echo "CREATING AUTOSCALING GROUP..."
aws autoscaling create-auto-scaling-group --auto-scaling-group-name $ASG_NAME \
			--launch-configuration-name $LC_NAME --load-balancer-names $ELB_NAME \
			--min-size $MIN_SIZE --max-size $MAX_SIZE --desired-capacity $DESIRED_CAPACITY \
			--vpc-zone-identifier $SUBNETS --health-check-type $HEALTH_CHECK_TYPE\
			--health-check-grace-period $HEALTH_CHECK_GRACE_PERIOD \
			--tags ResourceId=$ASG_NAME,ResourceType=auto-scaling-group,Key=Name,Value=$APIS_ASG_NAME Key=ENV,Value=TEST

echo "Creating autoscaling policies..."
INCREASE_POLICY_ARN=$(aws autoscaling put-scaling-policy --policy-name IncreasePolicy \
 			--auto-scaling-group-name $ASG_NAME  --scaling-adjustment 1 --adjustment-type ChangeInCapacity \
			| jq -r .PolicyARN)

DECREASE_POLICY_ARN=$(aws autoscaling put-scaling-policy --policy-name DecreasePolicy \
 			--auto-scaling-group-name $ASG_NAME  --scaling-adjustment -1 --adjustment-type ChangeInCapacity \
			| jq -r .PolicyARN)

if [ -z "${INCREASE_POLICY_ARN}" ] || [ -z "${DECREASE_POLICY_ARN}" ] 
then
	echo "Error while recovering LaunchConfiguration name, ELB name or API instance ID. Quiting!"
	exit 1
fi

echo "Creating metric alarms for the policies..."
aws cloudwatch put-metric-alarm --alarm-name CPUReaches80Percent --metric-name CPUUtilization \
			--namespace AWS/EC2 --statistic Average --period 60 --threshold 80 \
			--comparison-operator GreaterThanOrEqualToThreshold --dimensions "Name=AutoScalingGroupName,Value=$ASG_NAME" \
			--evaluation-periods 3 --alarm-actions $INCREASE_POLICY_ARN

aws cloudwatch put-metric-alarm --alarm-name CPULessThan40Percent --metric-name CPUUtilization \
 			--namespace AWS/EC2 --statistic Average --period 60 --threshold 40 \
 			--comparison-operator LessThanOrEqualToThreshold --dimensions "Name=AutoScalingGroupName,Value=$ASG_NAME" \
 			--evaluation-periods 3 --alarm-actions $DECREASE_POLICY_ARN

echo "Autoscaling Group created successfully!"
