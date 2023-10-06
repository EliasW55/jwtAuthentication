#!/bin/bash

# Start PostgreSQL using Docker Compose
echo "Starting up docker resource container..."
docker-compose up -d > /dev/null 2>&1

until nc -z localhost 5432 > /dev/null 2>&1; do
    echo "Waiting for PostgreSQL..."
    sleep 1
done

# Start your Spring Boot Application (assuming you use Maven)
echo "Running app..."
mvn spring-boot:run &> /dev/null 2>&1 &

APP_PID=$!  # Capture the process ID of the Spring Boot app

# Wait until Spring Boot is fully initialized (for example, by checking port 8080)
while ! nc -z localhost 8080 > /dev/null 2>&1; do
    sleep 0.5  # wait for half a second before checking again
done

# Register User
echo "Registering user..."
REGISTRATION_URL="http://localhost:8080/api/v1/auth/register"

REG_TOKEN=$(curl -s -X POST \
                  -H "Content-Type: application/json" \
                  -d '{
                        "firstname": "Elias",
                        "lastname": "Warres",
                        "email":  "elias.warres@gmail.com",
                        "password": "password",
                        "role":  "ADMIN"
                      }' \
                  $REGISTRATION_URL | jq -r '.token' 2> /dev/null)

echo "Registration code received: $REG_TOKEN"

# Authenticate user
echo "Authenticating user..."
AUTHENTICATE_URL="http://localhost:8080/api/v1/auth/authenticate"
AUTH_TOKEN=$(curl -s -X POST \
                  -H "Content-Type: application/json" \
                  -d '{
                        "email":  "elias.warres@gmail.com",
                        "password": "password"
                      }' \
                  $AUTHENTICATE_URL | jq -r '.token' 2> /dev/null)


# Check if the token was successfully retrieved
if [ -z "$AUTH_TOKEN" ]; then
    echo "Failed to retrieve the auth token. Exiting."
    exit 1
fi

echo "Authorization code received: $AUTH_TOKEN"

# Query the Demo endpoint
echo "Accessing resource with authorization token..."
DEMO_URL="http://localhost:8080/api/v1/demo-controller"

RESPONSE=$(curl -s -X GET \
                -H "Authorization: Bearer $AUTH_TOKEN" \
                $DEMO_URL)
echo $RESPONSE
echo

# Check if we could access the resource
if [[ $RESPONSE == *"Resource endpoint successfully reached."* ]]; then
    echo "SUCCESS"
else
    echo "FAIL"
fi

echo

# Stop the Docker containers initiated by docker-compose
echo "Stopping Docker containers..."
docker-compose down > /dev/null 2>&1

# Terminate the Spring Boot application (assuming it's the only Java process running)
echo "Stopping Spring Boot application..."
kill $APP_PID > /dev/null 2>&1

exit 0
