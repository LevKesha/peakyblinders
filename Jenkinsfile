pipeline {
/*─────────────────────────────────────────────
  0. Top-level agent – Docker-in-Docker
─────────────────────────────────────────────*/
    agent {
        docker {
            // 👉 pulled from your Docker Hub repo
            image 'keshagold/peaky:ci-toolchain-latest'
            args  '-v /var/run/docker.sock:/var/run/docker.sock'
            // registryCredentialsId 'dockerhub-keshagold'  // ← only if repo is private
        }
    }

    /*── Build parameters (typed each run; not stored on Jenkins) ──*/
    parameters {
        string  (name: 'DOCKERHUB_USR', defaultValue: 'keshagold',
                 description: 'Docker Hub username')
        password(name: 'DOCKERHUB_PSW',
                 description: 'Docker Hub PAT / password (masked)')
    }

    options  { timestamps() }
    triggers { githubPush() }

    /*── Global env ──*/
    environment {
        REPO_URL = 'https://github.com/LevKesha/peakyblinders.git'

        // all micro-service images go to docker.io/keshagold
        REGISTRY_PREFIX = 'docker.io/keshagold'

        TAG          = "${env.BUILD_NUMBER}"                // unique CI tag
        GIT_SHA      = "${env.GIT_COMMIT?.take(7) ?: 'dev'}"
        COMPOSE_FILE = 'infra/docker-compose.yml'
    }

    stages {

/*─────────────────────────────────────────────
  1. (Optional) install extra tools if image is bare
─────────────────────────────────────────────*/

/*─────────────────────────────────────────────
  2. Clone micro-service branches in parallel
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
  3. Resolve build-time dependencies
─────────────────────────────────────────────*/
        stage('Check Requirements') {
            parallel {
                stage('frontend deps')  { steps { retry(3) { dir('frontend')          { sh 'npm ci --loglevel=error' } } } }
                stage('gateway  deps')  { steps { retry(3) { dir('api-gateway')       { sh 'npm ci --loglevel=error' } } } }
                stage('user-svc deps')  { steps { retry(3) { dir('user-service')      { sh 'pip install -q -r requirements.txt' } } } }
                stage('inventory deps') { steps { retry(3) { dir('inventory-service') { sh 'mvn -q dependency:resolve' } } } }
                stage('db deps')        { steps { dir('database') { sh 'psql --version' } } }
            }
        }

/*─────────────────────────────────────────────
  4. Build Docker images
─────────────────────────────────────────────*/
        stage('Build Docker Images') {
            parallel {
                stage('frontend img')   {
                    steps {
                        sh """
                          docker build -t ${REGISTRY_PREFIX}/peaky-frontend:${TAG} \
                                       -t ${REGISTRY_PREFIX}/peaky-frontend:${GIT_SHA} \
                                       ./frontend
                        """
                    }
                }
                stage('gateway img')    {
                    steps {
                        sh """
                          docker build -t ${REGISTRY_PREFIX}/peaky-gateway:${TAG} \
                                       -t ${REGISTRY_PREFIX}/peaky-gateway:${GIT_SHA} \
                                       ./api-gateway
                        """
                    }
                }
                stage('user-svc img')   {
                    steps {
                        sh """
                          docker build -t ${REGISTRY_PREFIX}/peaky-user-svc:${TAG} \
                                       -t ${REGISTRY_PREFIX}/peaky-user-svc:${GIT_SHA} \
                                       ./user-service
                        """
                    }
                }
                stage('inventory img')  {
                    steps {
                        sh """
                          docker build -t ${REGISTRY_PREFIX}/peaky-inventory:${TAG} \
                                       -t ${REGISTRY_PREFIX}/peaky-inventory:${GIT_SHA} \
                                       ./inventory-service
                        """
                    }
                }
                stage('db img')         {
                    steps {
                        sh """
                          docker build -t ${REGISTRY_PREFIX}/peaky-db:${TAG} \
                                       -t ${REGISTRY_PREFIX}/peaky-db:${GIT_SHA} \
                                       ./database
                        """
                    }
                }
            }
        }

/*─────────────────────────────────────────────
  5. Push images (type creds each run)
─────────────────────────────────────────────*/
        stage('Push to Registry') {
            when { anyOf { branch 'main'; branch 'master'; branch 'release/*' } }

            stages {
                /*── 5a: login once ──*/
                stage('Login') {
                    steps {
                        withEnv(["USR=${params.DOCKERHUB_USR}",
                                 "PSW=${params.DOCKERHUB_PSW}"]) {
                            sh '''
                              set +x
                              printf "%s" "$PSW" | docker login -u "$USR" --password-stdin
                            '''
                        }
                    }
                }

                /*── 5b: push all images in parallel ──*/
                stage('Push Images') {
                    parallel {
                        stage('Push Frontend')  { steps { sh "docker push ${REGISTRY_PREFIX}/peaky-frontend:${TAG}  && docker push ${REGISTRY_PREFIX}/peaky-frontend:${GIT_SHA}" } }
                        stage('Push Gateway')   { steps { sh "docker push ${REGISTRY_PREFIX}/peaky-gateway:${TAG}   && docker push ${REGISTRY_PREFIX}/peaky-gateway:${GIT_SHA}" } }
                        stage('Push UserSvc')   { steps { sh "docker push ${REGISTRY_PREFIX}/peaky-user-svc:${TAG}  && docker push ${REGISTRY_PREFIX}/peaky-user-svc:${GIT_SHA}" } }
                        stage('Push Inventory') { steps { sh "docker push ${REGISTRY_PREFIX}/peaky-inventory:${TAG} && docker push ${REGISTRY_PREFIX}/peaky-inventory:${GIT_SHA}" } }
                        stage('Push DB')        { steps { sh "docker push ${REGISTRY_PREFIX}/peaky-db:${TAG}       && docker push ${REGISTRY_PREFIX}/peaky-db:${GIT_SHA}" } }
                    }
                }
            }
        }

/*─────────────────────────────────────────────
  6. Integration test (docker-compose)
─────────────────────────────────────────────*/
        stage('Integration Test') {
            steps {
                sh """
                  if [ -f ${COMPOSE_FILE} ]; then
                      docker compose -f ${COMPOSE_FILE} --pull never up -d --force-recreate
                      ./test.sh
                  else
                      echo 'ℹ️  No compose file – skipping integration test.'
                  fi
                """
            }
        }

/*─────────────────────────────────────────────
  7. Deploy example
─────────────────────────────────────────────*/
        stage('Deploy (prod)') {
            when { branch 'main' }
            steps {
                sshagent(credentials: ['ec2-key']) {
                    sh """
                      ssh -o StrictHostKeyChecking=no ec2-user@1.2.3.4 '
                          docker pull ${REGISTRY_PREFIX}/peaky-frontend:${TAG} &&
                          docker stack deploy -c /srv/peakyblinder/stack.yml peaky'
                    """
                }
            }
        }
    } /* stages */

/*─────────────────────────────────────────────
  8. Post-build cleanup
─────────────────────────────────────────────*/
    post {
        always {
            sh '''
              if [ -f "$COMPOSE_FILE" ]; then
                  docker compose -f "$COMPOSE_FILE" down -v --remove-orphans || true
              fi
            '''
            sh 'docker logout || true'
            cleanWs()
        }
        success { echo "✅  SUCCESS – images tagged $TAG and $GIT_SHA" }
        failure { echo "❌  FAILURE – check pipeline log" }
    }
}
