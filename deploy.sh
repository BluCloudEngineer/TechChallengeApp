#!/bin/bash

# This Bash script is responsible for the following:
#   1.  Compiling the Go application locally
#   2.  Creating a Docker continer of the Go application
#   3.  Pushing the Docker container to AWS
#   4.  Deploying a stack on AWS to run the docker container


# Usage:
#   Create the stack:   ./deploy.sh c
#   Update the stack:   ./deploy.sh u
#   Delete the stack:   ./deploy.sh d



# Varaibles
stackName1="Servian-Tech-Challenge-App-Stack-1"
stackName2="Servian-Tech-Challenge-App-Stack-2"
region="ap-southeast-2"


# Functions
compileGoCode () { # Compile Go code
    echo "Compiling Go code..."

    if [ -d "dist" ]; then
        rm -rf dist
    fi

    mkdir -p dist

    go mod tidy
    go build -ldflags="-s -w" -a -v -o TechChallengeApp .

    cp TechChallengeApp dist/
    cp -r assets dist/
    cp conf.toml dist/

    rm TechChallengeApp

    echo -e "Go code compiled!\n"
}

createAndPushDockerImage () {
    # Get Amazon ECR URL and name of the ECR repository
    ecrUrl=$(aws cloudformation --region $region describe-stacks --stack-name $stackName1 --query "Stacks[0].Outputs[1].OutputValue" --output text)
    ecrRepositoryName=$(aws cloudformation --region $region describe-stacks --stack-name $stackName1 --query "Stacks[0].Outputs[0].OutputValue" --output text)

    # Authenticate Docker client to the repository
    aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $ecrUrl

    # Build Docker image
    docker build -t $ecrRepositoryName .

    # Tag local Docker image
    docker tag $ecrRepositoryName":latest" $ecrUrl"/"$ecrRepositoryName":latest"

    # Push the Docker image to the ECR Repository
    docker push $ecrUrl"/"$ecrRepositoryName":latest"

    # Delete unencrypted Docker credentials
    rm ~/.docker/config.json
}



# Start deployment script
case $1 in
    c) # Create the stacks - Run this first if you have NOT deplyed the stack already
        # Compile Go code
        compileGoCode

        # Create stack 1
        echo "Creating stack 1 of 2..."
        aws cloudformation create-stack --stack-name $stackName1 --template-body file://1-aws-ecr-stack.yaml
        aws cloudformation wait stack-create-complete --stack-name $stackName1
        
        # Push container to ECS Repository
        createAndPushDockerImage

        # Create stack 2
        echo "Creating stack 2 of 2..."
        aws cloudformation create-stack --stack-name $stackName2 --template-body file://2-aws-golang-stack.yaml --capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_IAM CAPABILITY_NAMED_IAM
        aws cloudformation wait stack-create-complete --stack-name $stackName2
    
        # Show completion banner and Network Load Balancer URL
        echo "Stacks created!"
        elbUrl=$(aws cloudformation --region $region describe-stacks --stack-name $stackName2 --query "Stacks[0].Outputs[2].OutputValue" --output text)
        echo -e "To access the deployed solution, navigate to the following URL using a web browser:\t${elbUrl}"
        
        # Exit the script
        exit 0
        ;;
    
    u) # Update the stack - Run this after you have created the stack
        # Compile Go code
        compileGoCode

        # Push container to ECS Repository
        createAndPushDockerImage
        
        # Update stack
        echo "Updating the stack..."
        aws cloudformation update-stack --stack-name $stackName2 --template-body file://2-aws-golang-stack.yaml --capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_IAM CAPABILITY_NAMED_IAM
        aws cloudformation wait stack-update-complete --stack-name $stackName2

        # Show completion banner and Network Load Balancer URL
        echo "Stacks created!"
        elbUrl=$(aws cloudformation --region $region describe-stacks --stack-name $stackName2 --query "Stacks[0].Outputs[2].OutputValue" --output text)
        echo -e "To access the deployed solution, navigate to the following URL using a web browser:\t${elbUrl}"
        
        # Exit the script
        exit 0
        ;;

    d) # Delete the stacks - If you no longer need the stack you can delete it this way (recommended) or using the AWS Management Console. If you choose to use the AWS Management Console, you will need to delete all images in the ECR Repository
        # Get ECR Repository name
        ecrRepositoryName=$(aws cloudformation --region $region describe-stacks --stack-name $stackName1 --query "Stacks[0].Outputs[0].OutputValue" --output text)

        # Delete all images in the ECR Repository
        aws ecr batch-delete-image --repository-name $ecrRepositoryName --image-ids imageTag=latest

        # Delete the stack - 2 of 2
        echo "Deleting the stacks..."
        aws cloudformation delete-stack --stack-name $stackName2
        aws cloudformation wait stack-delete-complete --stack-name $stackName2

        # Delete the stack - 1 of 2
        aws cloudformation delete-stack --stack-name $stackName1
        aws cloudformation wait stack-delete-complete --stack-name $stackName1
        echo "Stacks deleted!"
        exit 0
        ;;

    *) # Invalid arguments - Show the help and usage instructions
        echo -e "\nUsage Instructions:"
        echo -e "\tCreate the stack: ./deploy.sh c"
        echo -e "\tUpdate the stack: ./deploy.sh u"
        echo -e "\tDelete the stack: ./deploy.sh d"
        exit 1
        ;;
esac