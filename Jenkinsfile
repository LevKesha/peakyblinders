pipeline {
    agent any
    options { timestamps() }
    triggers { githubPush() }           // run on *every* push

    environment {
        REPO_URL = 'https://github.com/LevKesha/peakyblinders.git'
        TAG      = "latest"
    }

    stages {

    /*── 1. CLONE CODE (always for all components) ──*/
        stage('Clone Code') {
            parallel {
                stage('Frontend')    { steps { echo "git clone --branch frontend-dev       ${REPO_URL} frontend"          } }
                stage('API-Gateway') { steps { echo "git clone --branch api-gateway-dev    ${REPO_URL} api-gateway"       } }
                stage('User-Svc')    { steps { echo "git clone --branch user-service-dev   ${REPO_URL} user-service"      } }
                stage('Inventory')   { steps { echo "git clone --branch inventory-dev      ${REPO_URL} inventory-service" } }
                stage('Database')    { steps { echo "git clone --branch database-dev       ${REPO_URL} database"          } }
            }
        }

    /*── 2. CHECK REQUIREMENTS ──*/
        stage('Check Requirements') {
            parallel {
                stage('Frontend deps')  { steps { retry(3) { echo 'npm ci' } } }
                stage('Gateway deps')   { steps { retry(3) { echo 'npm ci' } } }
                stage('User-Svc deps')  { steps { retry(3) { echo 'pip install -r requirements.txt' } } }
                stage('Inventory deps') { steps { retry(3) { echo 'mvn dependency:resolve' } } }
                stage('DB deps')        { steps { retry(3) { echo 'psql --version && flyway --help' } } }
            }
        }

    /*── 3. BUILD DOCKER IMAGES ──*/
        stage('Build Docker Images') {
            parallel {
                stage('Frontend img')   { steps { echo "docker build -t peakyblinders/frontend:${TAG}         ./frontend"          } }
                stage('Gateway img')    { steps { echo "docker build -t peakyblinders/api-gateway:${TAG}      ./api-gateway"       } }
                stage('User-Svc img')   { steps { echo "docker build -t peakyblinders/user-service:${TAG}     ./user-service"      } }
                stage('Inventory img')  { steps { echo "docker build -t peakyblinders/inventory-service:${TAG} ./inventory-service" } }
                stage('DB img')         { steps { echo "docker build -t peakyblinders/db:${TAG}               ./database"          } }
            }
        }

    /*── 4. PUSH TO REGISTRY ──*/
        stage('Push to Registry') {
            parallel {
                stage('Push Frontend')   { steps { echo "docker push peakyblinders/frontend:${TAG}" } }
                stage('Push Gateway')    { steps { echo "docker push peakyblinders/api-gateway:${TAG}" } }
                stage('Push User-Svc')   { steps { echo "docker push peakyblinders/user-service:${TAG}" } }
                stage('Push Inventory')  { steps { echo "docker push peakyblinders/inventory-service:${TAG}" } }
                stage('Push DB')         { steps { echo "docker push peakyblinders/db:${TAG}" } }
            }
        }

    /*── 5. INTEGRATION TEST ──*/
        stage('Integration Test (compose)') {
            steps {
                echo 'docker compose -f infra/docker-compose.yml up -d --build'
                echo './test.sh'
            }
        }
    }

    post {
        always  { echo 'docker compose -f infra/docker-compose.yml down' }
        success { echo 'SUCCESS – deploy would go here.' }
        failure { echo 'FAILURE – investigate logs.' }
    }
}
