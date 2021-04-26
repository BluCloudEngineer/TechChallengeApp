#!/bin/bash

# This Bash script is responsible for the following:
#   1.  Compiling the Go applicaiton locally
#   2.  Creating a Docker continer of the Go applicaiton
#   3.  Pushing the Docker container to AWS
#   4.  Deploying a stack on AWS to run the docker container


# Usage:
#   Create the stack:   ./deploy.sh c
#   Update the stack:   ./deploy.sh u
#   Delete the stack:   ./deploy.sh d



# Varaibles
stackName="Servian-Tech-Challenge-App-Stack"
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
    ecrUrl=$(aws cloudformation --region $region describe-stacks --stack-name $stackName --query "Stacks[0].Outputs[2].OutputValue" --output text)
    ecrRepositoryName=$(aws cloudformation --region $region describe-stacks --stack-name $stackName --query "Stacks[0].Outputs[1].OutputValue" --output text)
    
    # Authenticate Docker client to the repository
    aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $ecrUrl

    # Build Docker image
    docker build -t techchallengeapp-ecr-repository .

    # Tag local Docker image
    docker tag $ecrRepositoryName":latest" $ecrUrl"/"$ecrRepositoryName":latest"

    # Push the Docker image to the ECR Repository
    docker push $ecrUrl"/"$ecrRepositoryName":latest"

    # Delete unencrypted Docker credentials
    rm ~/.docker/config.json
}



# Start deployment script
case $1 in
    c) # Create the stack - Run this first if you have NOT deplyed the stack already
        # Compile Go code
        compileGoCode

        # Create stack
        echo "Creating the stack..."
        aws cloudformation create-stack --stack-name $stackName --template-body file://aws-golang-stack.yaml --capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_IAM
        aws cloudformation wait stack-create-complete --stack-name $stackName
        
        # Push container to ECS Repository
        createAndPushDockerImage

        # Show completion banner and exit
        echo "Stack created!"
        exit 0
        ;;
    
    u) # Update the stack - Run this after you have created the stack
        # Compile Go code
        compileGoCode
        
        # Update stack
        echo "Updating the stack..."
        aws cloudformation update-stack --stack-name $stackName --template-body file://aws-golang-stack.yaml --capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_IAM
        aws cloudformation wait stack-update-complete --stack-name $stackName

        # Push container to ECS Repository
        createAndPushDockerImage

        # Show completion banner and exit
        echo "Stack update complete!"
        exit 0
        ;;

    d) # Delete the stack - If you no longer need the stack you can delete it this way (recommended) or using the AWS Management Console. If you choose to use the AWS Management Console, you will need to delete all images in the ECR Repository
        # Get ECR Repository name
        ecrRepositoryName=$(aws cloudformation --region $region describe-stacks --stack-name $stackName --query "Stacks[0].Outputs[1].OutputValue" --output text)

        # Delete all images in the ECR Repository
        aws ecr batch-delete-image --repository-name $ecrRepositoryName --image-ids imageTag=latest

        # Delete the stack
        echo "Deleting the stack..."
        aws cloudformation delete-stack --stack-name $stackName
        aws cloudformation wait stack-delete-complete --stack-name $stackName
        echo "Stack deleted!"
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