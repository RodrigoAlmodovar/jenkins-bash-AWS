#!/bin/bash

INSTANCENAME="ASG_API"
INSTANCE_IDS="$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$INSTANCENAME" \
			"Name=instance-state-code,Values=16" \
			| jq -r .Reservations[].Instances[].InstanceId)"
ELB_NAME="$(aws elb describe-load-balancers \
			| jq -r .LoadBalancerDescriptions[].LoadBalancerName)"
LC_NAME="$(aws autoscaling describe-launch-configurations \
			| jq -r .LaunchConfigurations[].LaunchConfigurationName)"
ASG_NAME="$(aws autoscaling describe-auto-scaling-groups \
			| jq -r .AutoScalingGroups[].AutoScalingGroupName)"

#There is no need for iteration, we can terminate more than one instance at once
echo "Terminating instances..."
aws ec2 terminate-instances --region us-east-1 --instance-ids $INSTANCE_IDS
echo "Deleting ELB..."
aws elb delete-load-balancer --load-balancer-name $ELB_NAME
#First we remove the ASG. Otherwise we couldn't delete the LC due to it is attached to an ASG
echo "Deleting ASG..."
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $ASG_NAME --force-delete
echo "Deleting Launch Configuration..."
aws autoscaling delete-launch-configuration --launch-configuration-name $LC_NAME
