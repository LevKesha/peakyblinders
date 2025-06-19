pipeline {
    agent any
    triggers { githubPush() }
    options  { timestamps() }

    environment {
        REPO_URL = 'https://github.com/LevKesha/peakyblinders.git'
        TAG      = "latest"
    }

    stages {

    /*── 1. CLONE (only what changed) ──*/
        stage('Clone Code') {
            parallel {
                stage('Frontend') {
                    when { changeset "**/frontend/**" }    // <─ only if files under /frontend changed
                    steps  { echo "git clone --branch frontend-dev ${REPO_URL} frontend" }
                }
                stage('API-Gateway') {
                    when { changeset "**/api-gateway/**" }
                    steps  { echo "git clone --branch api-gateway-dev ${REPO_URL} api-gateway" }
                }
                stage('User-Svc') {
                    when { changeset "**/user-service/**" }
                    steps  { echo "git clone --branch user-service-dev ${REPO_URL} user-service" }
                }
                stage('Inventory') {
                    when { changeset "**/inventory-service/**" }
                    steps  { echo "git clone --branch inventory-dev ${REPO_URL} inventory-service" }
                }
                stage('Database') {
                    when { changeset "**/database/**" }
                    steps  { echo "git clone --branch database-dev ${REPO_URL} database" }
                }
            }
        }

    /*── 2. CHECK REQUIREMENTS ──*/
        stage('Check Requirements') {
            parallel {
                stage('Frontend deps')  {
                    when { changeset "**/frontend/**" }
                    steps { retry(3) { echo 'npm ci' } }
                }
                stage('Gateway deps')   {
                    when { changeset "**/api-gateway/**" }
                    steps { retry(3) { echo 'npm ci' } }
                }
                stage('User-Svc deps')  {
                    when { changeset "**/user-service/**" }
                    steps { retry(3) { echo 'pip install -r requirements.txt' } }
                }
                stage('Inventory deps') {
                    when { changeset "**/inventory-service/**" }
                    steps { retry(3) { echo 'mvn dependency:resolve' } }
                }
                stage('DB deps')        {
                    when { changeset "**/database/**" }
                    steps { retry(3) { echo 'psql --version && flyway --help' } }
                }
            }
        }

    /*── 3. BUILD IMAGES ──*/
        stage('Build Docker Images') {
            parallel {
                stage('Frontend img')  {
                    when { changeset "**/frontend/**" }
                    steps { echo "docker build -t peakyblinders/frontend:${TAG} ./frontend" }
                }
                stage('Gateway img')   {
                    when { changeset "**/api-gateway/**" }
                    steps { echo "docker build -t peakyblinders/api-gateway:${TAG} ./api-gateway" }
                }
                stage('User-Svc img')  {
                    when { changeset "**/user-service/**" }
                    steps { echo "docker build -t peakyblinders/user-service:${TAG} ./user-service" }
                }
                stage('Inventory img') {
                    when { changeset "**/inventory-service/**" }
                    steps { echo "docker build -t peakyblinders/inventory-service:${TAG} ./inventory-service" }
                }
                stage('DB img')        {
                    when { changeset "**/database/**" }
                    steps { echo "docker build -t peakyblinders/db:${TAG} ./database" }
                }
            }
        }

    /*── 4. PUSH & 5. TEST ── (same idea; add matching `when { changeset … }`) */

    }  // stages

    post {
        always  { echo 'docker compose down' }
    }
}
