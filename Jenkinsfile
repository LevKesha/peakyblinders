pipeline {
/*─────────────────────────────────────────────
  0. Top-level agent – Docker-in-Docker
─────────────────────────────────────────────*/
    agent {
        docker {
            image 'keshagold/peaky:ci-toolchain-latest'
            args  '-v /var/run/docker.sock:/var/run/docker.sock'
            // registryCredentialsId 'dockerhub-keshagold'   // if repo is private
        }
    }

    /*──────── Build-time parameters ────────*/
    parameters {
        string  (name: 'DOCKERHUB_USR', defaultValue: 'keshagold',
                 description: 'Docker Hub username')
        password(name: 'DOCKERHUB_PSW',
                 description: 'Docker Hub PAT / password (masked)')
    }

    options  { timestamps() }
    triggers { githubPush() }

    /*──────── Global env ────────*/
    environment {
        REPO_URL        = 'https://github.com/LevKesha/peakyblinders.git'
        REGISTRY_PREFIX = 'docker.io/keshagold'
        TAG             = "${env.BUILD_NUMBER}"
        GIT_SHA         = "${env.GIT_COMMIT?.take(7) ?: 'dev'}"
        COMPOSE_FILE    = 'infra/docker-compose.yml'
    }

    stages {

/*─────────────────────────────────────────────
  1. Clone micro-service branches (parallel)
─────────────────────────────────────────────*/
        stage('Clone Code') {
            parallel {
                stage('frontend')    { steps { sh "git clone --branch frontend-dev       ${REPO_URL} frontend"          } }
                stage('api-gateway') { steps { sh "git clone --branch api-gateway-dev    ${REPO_URL} api-gateway"       } }
                stage('user-service'){ steps { sh "git clone --branch user-service-dev   ${REPO_URL} user-service"      } }
                stage('inventory')   { steps { sh "git clone --branch inventory-dev      ${REPO_URL} inventory-service" } }
                stage('database')    { steps { sh "git clone --branch database-dev       ${REPO_URL} database"          } }
            }
        }

/*─────────────────────────────────────────────
  2. Resolve build-time dependencies
─────────────────────────────────────────────*/
        stage('Check Requirements') {
            parallel {
                /*---- Node projects ----*/
stage('frontend deps') {
    steps {
        dir('frontend') {
            script {
                if (fileExists('package.json')) {
                    if (fileExists('package-lock.json')) {
                        sh 'npm ci --loglevel=error'
                    } else {
                        sh 'npm install --loglevel=error'
                    }
                } else {
                    echo '⚠️  frontend skipped: no package.json'
                }
            }
        }
    }
}
                stage('gateway deps') {
                    steps {
                        dir('api-gateway') {
                            script {
                                if (fileExists('package-lock.json') || fileExists('npm-shrinkwrap.json')) {
                                    sh 'npm ci --loglevel=error'
                                } else {
                                    sh 'npm install --loglevel=error'
                                }
                            }
                        }
                    }
                }

                /*---- Python service ----*/
                stage('user-svc deps') {
                    steps {
                        retry(3) {
                            dir('user-service') {
                                sh 'pip install -q -r requirements.txt'
                            }
                        }
                    }
                }

                /*---- Java service ----*/
stage('inventory deps') {
    steps {
        dir('inventory-service') {
            script {
                if (fileExists('pom.xml')) {
                    sh 'mvn -q dependency:resolve'
                } else {
                    echo '⚠️  inventory-service skipped: no pom.xml'
                }
            }
        }
    }
}

                /*---- DB scripts ----*/
                stage('db deps') {
                    steps { dir('database') { sh 'psql --version' } }
                }
            }
        }

/*─────────────────────────────────────────────
  3. Build Docker images
─────────────────────────────────────────────*/
        stage('Build Docker Images') {
            parallel {
                stage('frontend img') {
                    steps {
                        sh """
                          docker build -t ${REGISTRY_PREFIX}/peaky-frontend:${TAG} \
                                       -t ${REGISTRY_PREFIX}/peaky-frontend:${GIT_SHA} \
                                       ./frontend
                        """
                    }
                }
                stage('gateway img') {
                    steps {
                        sh """
                          docker build -t ${REGISTRY_PREFIX}/peaky-gateway:${TAG} \
                                       -t ${REGISTRY_PREFIX}/peaky-gateway:${GIT_SHA} \
                                       ./api-gateway
                        """
                    }
                }
                stage('user-svc img') {
                    steps {
                        sh """
                          docker build -t ${REGISTRY_PREFIX}/peaky-user-svc:${TAG} \
                                       -t ${REGISTRY_PREFIX}/peaky-user-svc:${GIT_SHA} \
                                       ./user-service
                        """
                    }
                }
                stage('inventory img') {
                    steps {
                        sh """
                          docker build -t ${REGISTRY_PREFIX}/peaky-inventory:${TAG} \
                                       -t ${REGISTRY_PREFIX}/peaky-inventory:${GIT_SHA} \
                                       ./inventory-service
                        """
                    }
                }
                stage('db img') {
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
  4. Push images (typed creds)
─────────────────────────────────────────────*/
        stage('Push to Registry') {
            when { anyOf { branch 'main'; branch 'master'; branch 'release/*' } }

            stages {
                stage('Login') {
                    steps {
                        withEnv(["USR=${params.DOCKERHUB_USR}", "PSW=${params.DOCKERHUB_PSW}"]) {
                            sh '''
                              set +x
                              printf "%s" "$PSW" | docker login -u "$USR" --password-stdin
                            '''
                        }
                    }
                }

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
  5. Integration test (docker-compose)
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
  6. Deploy example
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
  7. Post-build cleanup
─────────────────────────────────────────────*/
    post {
        always {
            sh '''
              if [ -f "$COMPOSE_FILE" ]; then
                  docker compose -f "$COMPOSE_FILE" down -v --remove-orphans || true
              fi
            '''
            cleanWs()
        }
        success { echo "✅  SUCCESS – images tagged $TAG and $GIT_SHA" }
        failure { echo "❌  FAILURE – check pipeline log" }
    }
}
