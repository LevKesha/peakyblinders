pipeline {
/*─────────────────────────────────────────────
  0. Top-level agent – runs Docker-in-Docker
─────────────────────────────────────────────*/
    agent {
        docker {
            image 'peakyblinders/ci-toolchain:latest'   // pre-baked tool-chain
            args  '-v /var/run/docker.sock:/var/run/docker.sock'
        }
    }

    options  { timestamps() }
    triggers { githubPush() }                           // build every push

/*─────────────────────────────────────────────
  1. Global vars & credentials
─────────────────────────────────────────────*/
    environment {
        REGISTRY      = 'docker.io/peakyblinders'       // change to GHCR/ECR if needed
        TAG           = "${env.BUILD_NUMBER}"           // unique, reproducible tag
        COMPOSE_FILE  = 'infra/docker-compose.yml'
        // export short Git SHA for “latest-but-immutable” tag if desired
        GIT_SHA       = "${env.GIT_COMMIT?.take(7) ?: 'dev'}"
    }

    /* map Docker Hub creds to env.USER / env.PASS */
    // store the credential under “dockerhub-peaky” in Jenkins
    tools { }   // <- leave empty; tool-chain is baked into the image

    stages {

/*─────────────────────────────────────────────
  2. (Optional) one-time bootstrap if image is bare
─────────────────────────────────────────────*/
        stage('Bootstrap Tool-chain') {
            when { expression { !fileExists('/.toolchain_ready') } }
            steps {
                sh '''
                  set -e
                  echo "Tool-chain missing – installing once ..."
                  apt-get update -qq
                  DEBIAN_FRONTEND=noninteractive \
                  apt-get install -y --no-install-recommends \
                        nodejs npm python3-pip maven postgresql-client
                  touch /.toolchain_ready
                '''
            }
        }

/*─────────────────────────────────────────────
  3. Clone each service branch in parallel
─────────────────────────────────────────────*/
        stage('Clone Code') {
            parallel {
                stage('frontend')        { steps { sh "git clone --branch frontend-dev       ${REPO_URL} frontend"          } }
                stage('api-gateway')     { steps { sh "git clone --branch api-gateway-dev    ${REPO_URL} api-gateway"       } }
                stage('user-service')    { steps { sh "git clone --branch user-service-dev   ${REPO_URL} user-service"      } }
                stage('inventory')       { steps { sh "git clone --branch inventory-dev      ${REPO_URL} inventory-service" } }
                stage('database')        { steps { sh "git clone --branch database-dev       ${REPO_URL} database"          } }
            }
        }

/*─────────────────────────────────────────────
  4. Resolve build-time dependencies
─────────────────────────────────────────────*/
        stage('Check Requirements') {
            parallel {
                stage('frontend deps')  { steps { retry(3) { dir('frontend')          { sh 'npm ci --loglevel=error' } } } }
                stage('gateway  deps')  { steps { retry(3) { dir('api-gateway')       { sh 'npm ci --loglevel=error' } } } }
                stage('user-svc deps')  { steps { retry(3) { dir('user-service')      { sh 'pip install -q -r requirements.txt' } } } }
                stage('inventory deps') { steps { retry(3) { dir('inventory-service') { sh 'mvn -q dependency:resolve' } } } }
                stage('db       deps')  { steps { dir('database') { sh 'psql --version' } } }
            }
        }

/*─────────────────────────────────────────────
  5. Build all images (fan-out)
─────────────────────────────────────────────*/
        stage('Build Docker Images') {
            parallel {
                stage('frontend img')   {
                    steps { sh "docker build -t ${REGISTRY}/frontend:${TAG}          -t ${REGISTRY}/frontend:${GIT_SHA}          ./frontend" }
                }
                stage('gateway img')    {
                    steps { sh "docker build -t ${REGISTRY}/api-gateway:${TAG}       -t ${REGISTRY}/api-gateway:${GIT_SHA}       ./api-gateway" }
                }
                stage('user-svc img')   {
                    steps { sh "docker build -t ${REGISTRY}/user-service:${TAG}      -t ${REGISTRY}/user-service:${GIT_SHA}      ./user-service" }
                }
                stage('inventory img')  {
                    steps { sh "docker build -t ${REGISTRY}/inventory-service:${TAG} -t ${REGISTRY}/inventory-service:${GIT_SHA} ./inventory-service" }
                }
                stage('db img')         {
                    steps { sh "docker build -t ${REGISTRY}/db:${TAG}                -t ${REGISTRY}/db:${GIT_SHA}                ./database" }
                }
            }
        }

/*─────────────────────────────────────────────
  6. Push (needs registry credentials)
─────────────────────────────────────────────*/
        stage('Push to Registry') {
            when { anyOf { branch 'main'; branch 'master'; branch 'release/*' } }
            /* ----- docker login once, then push in parallel ---- */
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-peaky',
                                  usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                    sh 'echo "$PASS" | docker login -u "$USER" --password-stdin'

                    parallel (
                        "push frontend"  : { sh "docker push ${REGISTRY}/frontend:${TAG}          && docker push ${REGISTRY}/frontend:${GIT_SHA}" },
                        "push gateway"   : { sh "docker push ${REGISTRY}/api-gateway:${TAG}       && docker push ${REGISTRY}/api-gateway:${GIT_SHA}" },
                        "push user-svc"  : { sh "docker push ${REGISTRY}/user-service:${TAG}      && docker push ${REGISTRY}/user-service:${GIT_SHA}" },
                        "push inventory" : { sh "docker push ${REGISTRY}/inventory-service:${TAG} && docker push ${REGISTRY}/inventory-service:${GIT_SHA}" },
                        "push db"        : { sh "docker push ${REGISTRY}/db:${TAG}                && docker push ${REGISTRY}/db:${GIT_SHA}" }
                    )
                }
            }
        }

/*─────────────────────────────────────────────
  7. Integration test with docker-compose
─────────────────────────────────────────────*/
        stage('Integration Test') {
            steps {
                sh """
                    if [ -f ${COMPOSE_FILE} ]; then
                        docker compose -f ${COMPOSE_FILE} \
                                       --pull never \
                                       up -d --force-recreate
                        ./test.sh
                    else
                        echo '🛈  No compose file – skipping integration test.'
                    fi
                """
            }
        }

/*─────────────────────────────────────────────
  8. (Optional) Deploy
─────────────────────────────────────────────*/
        stage('Deploy (prod)') {
            when { branch 'main' }
            steps {
                sshagent(credentials: ['ec2-key']) {
                    sh """
                      ssh -o StrictHostKeyChecking=no ec2-user@1.2.3.4 \
                        'docker pull ${REGISTRY}/frontend:${TAG} && \
                         docker stack deploy -c /srv/peakyblinder/stack.yml peaky'
                    """
                }
            }
        }
    }

/*─────────────────────────────────────────────
  9. Post-build cleanup
─────────────────────────────────────────────*/
    post {
        always {
            sh """
              if [ -f ${COMPOSE_FILE} ]; then
                  docker compose -f ${COMPOSE_FILE} down -v --remove-orphans || true
              fi
              docker logout || true
            """
            cleanWs()
        }
        success { echo "SUCCESS – images tagged ${TAG} + ${GIT_SHA}" }
        failure { echo "FAILURE – check pipeline log" }
    }
}
