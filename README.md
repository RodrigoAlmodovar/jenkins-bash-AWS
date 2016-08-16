# Jenkins&AWS

This exercise is a continuation from the AWS exercise. In this case, we will use the continuous integration tool Jenkins so we will run our architecture to start at 8:00 and shut down at 18:30 from Monday to Friday.

How it works, step by step:

##1. Jenkins:
In Jenkins, we must create 2 Jobs, one to start the machines and the other to shut them down.
For the script to be runnable, we need to add a plugin to Jenkins, CloudBees Amazon or Amazon EC2 (from Configure Jenkins -> Admin plugins)
This will allow us to set uop our AWS credentials.

Once this is done, we must go inside the project and, inside the Configure -> execution environment, click on Use secret text or file. This will show the Bindings field where the credentials will be automatically filled.

In the execute field, we must configure the region and then, the path to the file were our script is.

For the periodicity we must click on Execute periodically box, and then enter the proper order.

##2. Scripts:
There are 2 scripts in this repository, one for running the instances, and the second for shutting everything.
- goodMorning.sh
- goodNight.sh

##Explanation
###goodMorning.sh
This will be the code that will create the load balancer (ELB), launch configurations and autoscaling group (ASG). Then, it will automatically create one instance since the DESIRED_CAPACITY variable is set to 1. The architecture will be ready then to autoscale itself.

###goodNight.sh
This will terminate every instance with the specified name, remove the ELB, ASG and also the launch configuration.
