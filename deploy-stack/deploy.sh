#!/bin/bash

# This Bash script is responsible for the deploying the Servian Tech Challenge App to AWS
# Usage:
#   Create the stack:   ./deploy.sh c
#   Update the stack:   ./deploy.sh u
#   Delete the stack:   ./deploy.sh d

stackName="Servian-Tech-Challenge-App-Stack"
region="ap-southeast-2"

case $1 in
    c)
        echo "Creating the stack"
        aws cloudformation create-stack --stack-name $stackName --template-body file://aws-golang-stack.yaml --capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_IAM
        aws cloudformation wait stack-create-complete --stack-name $stackName
        echo "Stack created"
        exit 0
        ;;
    
    u)
        echo "Updating the stack"
        aws cloudformation update-stack --stack-name $stackName --template-body file://aws-golang-stack.yaml --capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_IAM
        aws cloudformation wait stack-update-complete --stack-name $stackName
        echo "Stack update complete"
        exit 0
        ;;

    d)
        echo "Deleting the stack"
        aws cloudformation delete-stack --stack-name $stackName
        aws cloudformation wait stack-delete-complete --stack-name $stackName
        echo "Stack deleted"
        exit 0
        ;;

    *)
        echo -e "\nUsage Instructions:"
        echo -e "\tCreate the stack: ./deploy.sh c"
        echo -e "\tUpdate the stack: ./deploy.sh u"
        echo -e "\tDelete the stack: ./deploy.sh d"
        exit 1
        ;;
esac