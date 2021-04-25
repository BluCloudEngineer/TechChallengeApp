// Copyright © 2020 Servian
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

package config

import (
	"strings"
	"github.com/spf13/viper"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/awserr"
	"github.com/aws/aws-sdk-go/aws/session"
	"fmt"
	"encoding/json"
)

// internalConfig wraps the config values as the toml library was
// having issue with getters and setters on the struct
type Config struct {
	DbUser     string
	DbPassword string
	DbName     string
	DbHost     string
	DbPort     string
	ListenHost string
	ListenPort string
}

func LoadConfig() (*Config, error) {
	var conf = &Config{}

	v := viper.New()

	v.SetConfigName("conf")
	v.SetConfigType("toml")
	v.AddConfigPath(".")

	v.SetEnvPrefix("VTT")
	v.AutomaticEnv()

	v.SetDefault("DbUser", "postgres")
	v.SetDefault("DbPassword", "postgres")
	v.SetDefault("DbName", "postgres")
	v.SetDefault("DbPort", "postgres")
	v.SetDefault("DbHost", "localhost")

	v.SetDefault("ListenHost", "127.0.0.1")
	v.SetDefault("ListenPort", "3000")

	err := v.ReadInConfig() // Find and read the config file

	if err != nil {
		return nil, err
	}

	// Set variables for AWS Secrets Manager
	secretName := "/Servian/TechChallengeApp/RDS"
	region := "ap-southeast-2"

	// Create a Secrets Manager client
	svc := secretsmanager.New(session.New(), aws.NewConfig().WithRegion(region))
	input := &secretsmanager.GetSecretValueInput{
		SecretId:     aws.String(secretName),
		VersionStage: aws.String("AWSCURRENT"),
	}

	// Get result from AWS Secrets Manager
    result, err := svc.GetSecretValue(input)
	if err != nil {
		if aerr, ok := err.(awserr.Error); ok {
			switch aerr.Code() {
				case secretsmanager.ErrCodeDecryptionFailure:
				// Secrets Manager can't decrypt the protected secret text using the provided KMS key.
				fmt.Println(secretsmanager.ErrCodeDecryptionFailure, aerr.Error())

				case secretsmanager.ErrCodeInternalServiceError:
				// An error occurred on the server side.
				fmt.Println(secretsmanager.ErrCodeInternalServiceError, aerr.Error())

				case secretsmanager.ErrCodeInvalidParameterException:
				// You provided an invalid value for a parameter.
				fmt.Println(secretsmanager.ErrCodeInvalidParameterException, aerr.Error())

				case secretsmanager.ErrCodeInvalidRequestException:
				// You provided a parameter value that is not valid for the current state of the resource.
				fmt.Println(secretsmanager.ErrCodeInvalidRequestException, aerr.Error())

				case secretsmanager.ErrCodeResourceNotFoundException:
				// We can't find the resource that you asked for.
				fmt.Println(secretsmanager.ErrCodeResourceNotFoundException, aerr.Error())
			}
		} else {
			// Print the error, cast err to awserr.Error to get the Code and
			// Message from an error.
			fmt.Println(err.Error())
		}
	}
	
	// Deserialising secretString data
	var secretString = *result.SecretString
	var data map[string]interface{}
	json.Unmarshal([]byte(secretString), &data)

	// Set config data using AWS Secrets Manager
	conf.DbUser = data["username"].(string)
	conf.DbPassword = data["password"].(string)
	conf.DbName = data["dbname"].(string)
	conf.DbHost = data["host"].(string)
	conf.DbPort = fmt.Sprintf("%g", data["port"]) // Convert integer to string

	// Set config results using local file
	conf.ListenHost = strings.TrimSpace(v.GetString("ListenHost"))
	conf.ListenPort = strings.TrimSpace(v.GetString("ListenPort"))

	// Return configuration data
	return conf, nil
}