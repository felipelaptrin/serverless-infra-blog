package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/aws/aws-sdk-go-v2/service/sts"
)

type User struct {
	UserId    string `json:"userId"`
	Name      string `json:"name"`
	Email     string `json:"email"`
	CreatedAt string `json:"createdAt"`
}

func getEnv(key, fallback string) string {
	value, exists := os.LookupEnv(key)
	if !exists {
		value = fallback
	}
	return value
}

var dynamoClient *dynamodb.Client
var tableName = getEnv("TABLE_NAME", "table")

func init() {
	cfg, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion(getEnv("AWS_REGION", "us-east-1")))
	if err != nil {
		log.Fatalf("Failed to load AWS config: %v", err)
	}

	dynamoClient = dynamodb.NewFromConfig(cfg)

	stsClient := sts.NewFromConfig(cfg)
	identity, err := stsClient.GetCallerIdentity(context.TODO(), &sts.GetCallerIdentityInput{})
	if err != nil {
		log.Printf("Failed to get caller identity: %v", err)
	} else {
		log.Printf("Lambda is running as: %s", *identity.Arn)
	}
}

func handler(request events.APIGatewayV2HTTPRequest) (events.APIGatewayProxyResponse, error) {
	if request.RequestContext.HTTP.Method == "OPTIONS" {
		return events.APIGatewayProxyResponse{
			Headers: map[string]string{
				"Access-Control-Allow-Headers": "Content-Type",
				"Access-Control-Allow-Origin":  os.Getenv("FRONTEND_ENDPOINT"),
				"Access-Control-Allow-Methods": "OPTIONS,POST,GET",
			},
			StatusCode: 200,
		}, nil
	}
	if request.RequestContext.HTTP.Method == "POST" {
		return createUser(request)
	}

	return events.APIGatewayProxyResponse{
		Body:       "Method not supported",
		StatusCode: 405,
	}, nil
}

func createUser(request events.APIGatewayV2HTTPRequest) (events.APIGatewayProxyResponse, error) {
	var user User

	if err := json.Unmarshal([]byte(request.Body), &user); err != nil {
		return events.APIGatewayProxyResponse{
			Body:       fmt.Sprintf("Invalid request body: %v", err),
			StatusCode: 400,
		}, nil
	}

	if user.UserId == "" {
		return events.APIGatewayProxyResponse{
			Body:       "UserId must be provided",
			StatusCode: 400,
		}, nil
	}

	getItemOutput, err := dynamoClient.GetItem(context.TODO(), &dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"UserId": &types.AttributeValueMemberS{Value: user.UserId},
		},
	})
	if err != nil {
		return events.APIGatewayProxyResponse{
			Body:       fmt.Sprintf("Error checking for existing user: %v", err),
			StatusCode: 500,
		}, nil
	}

	if getItemOutput.Item != nil {
		return events.APIGatewayProxyResponse{
			Body:       "User already exists",
			StatusCode: 400,
		}, nil
	}

	user.CreatedAt = time.Now().UTC().Format(time.RFC3339)

	item := map[string]types.AttributeValue{
		"UserId":    &types.AttributeValueMemberS{Value: user.UserId},
		"Name":      &types.AttributeValueMemberS{Value: user.Name},
		"Email":     &types.AttributeValueMemberS{Value: user.Email},
		"CreatedAt": &types.AttributeValueMemberS{Value: user.CreatedAt},
	}

	_, err = dynamoClient.PutItem(context.TODO(), &dynamodb.PutItemInput{
		TableName: aws.String(tableName),
		Item:      item,
	})
	if err != nil {
		return events.APIGatewayProxyResponse{
			Body:       fmt.Sprintf("Failed to save user: %v", err),
			StatusCode: 500,
		}, nil
	}

	responseBody, _ := json.Marshal(map[string]string{
		"message": "User created successfully",
		"userId":  user.UserId,
	})

	return events.APIGatewayProxyResponse{
		Body:       string(responseBody),
		StatusCode: 201,
	}, nil
}

func main() {
	lambda.Start(handler)
}
