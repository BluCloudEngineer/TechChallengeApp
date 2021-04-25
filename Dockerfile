# Download Ubuntu 20.04 LTS image
FROM ubuntu:focal

# Run commands to configure the Docker container
RUN apt update -y
RUN apt dist-upgrade -y
RUN apt install curl unzip -y
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
RUN unzip /tmp/awscliv2.zip -d /tmp
RUN /tmp/aws/install
RUN aws configure set default.region ap-southeast-2

# Add TechChallengeApp files
ADD dist/TechChallengeApp /TechChallengeApp
ADD dist/conf.toml /conf.toml
COPY dist/assets/ /assets

# Expose the required port
EXPOSE 3000

# Run the following commands when executing the Docker container
CMD /TechChallengeApp updatedb -s && /TechChallengeApp serve