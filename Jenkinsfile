pipeline {
/*─────────────────────────────────────────────
  GLOBAL DOCKER AGENT  (all stages *after* Prep run in here)
─────────────────────────────────────────────*/
    agent {
        docker {
            image 'keshagold/peaky:ci-toolchain-latest'
            args  '-v /var/run/docker.sock:/var/run/docker.sock'
            // registryCredentialsId 'dockerhub-keshagold'   // if repo is private
        }
    }

/*─────────────────────────────────────────────
  PARAMETERS / OPTIONS
─────────────────────────────────────────────*/
    parameters {
        string  (name: 'DOCKERHUB_USR', defaultValue: 'keshagold',
                 description: 'Docker Hub username')
        password(name: 'DOCKERHUB_PSW',
                 description: 'Docker Hub PAT / password (masked)')
    }

    options  {
        timestamps()               // keep timestamps
        skipDefaultCheckout()      // we do git clone manually
    }
    triggers { githubPush() }

/*─────────────────────────────────────────────
  GLOBAL ENV
─────────────────────────────────────────────*/
    environment {
        REPO_URL        = 'https://github.com/LevKesha/peakyblinders.git'
        REGISTRY_PREFIX = 'docker.io/keshagold'
        TAG             = "${env.BUILD_NUMBER}"
        GIT_SHA         = "${env.GIT_COMMIT?.take(7) ?: 'dev'}"
        COMPOSE_FILE    = 'infra/docker-compose.yml'
        GIT_SHA         = 'dev'        // will be overwritten in Set GIT_SHA stage
    }

/*─────────────────────────────────────────────
  STAGES
─────────────────────────────────────────────*/
    stages {

    /* 0. FULL CLEAN BEFORE CONTAINER STARTS */
        stage('Prep Workspace') {
            // run on the Jenkins node itself (no docker block here)
            agent { label '' }
            steps {
                cleanWs(deleteDirs: true, disableDeferredWipeout: true)
            }
        }

    /* 1. Clone code inside the Docker agent */
        stage('Clone Code') {
            parallel {
                stage('frontend')    { steps { sh "git clone --depth 1 --branch frontend-dev    ${REPO_URL} frontend" } }
                stage('api-gateway') { steps { sh "git clone --depth 1 --branch api-gateway-dev ${REPO_URL} api-gateway" } }
                stage('user-service'){ steps { sh "git clone --depth 1 --branch user-service-dev ${REPO_URL} user-service" } }
                stage('inventory')   { steps { sh "git clone --depth 1 --branch inventory-dev   ${REPO_URL} inventory-service" } }
                stage('database')    { steps { sh "git clone --depth 1 --branch database-dev    ${REPO_URL} database" } }
            }
        }

        stage('Set GIT_SHA') {
        steps {
            script {
                // pick one of the cloned repos; here we use frontend
                env.GIT_SHA = sh(returnStdout: true,
                                 script: 'git -C frontend rev-parse --short HEAD'
                                ).trim()
                echo "GIT_SHA set to ${env.GIT_SHA}"
            }
        }
    }

    /* 2. Resolve build-time dependencies */
        stage('Check Requirements') {
            parallel {
                /* Node ─────────────────────────────*/
                stage('frontend deps') {
                    steps {
                        dir('frontend') {
                            script {
                                if (fileExists('package.json')) {
                                    sh (fileExists('package-lock.json') ?
                                        'npm ci --loglevel=error' :
                                        'npm install --loglevel=error')
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
                                if (fileExists('package.json')) {
                                    sh (fileExists('package-lock.json') ?
                                        'npm ci --loglevel=error' :
                                        'npm install --loglevel=error')
                                } else {
                                    echo '⚠️  api-gateway skipped: no package.json'
                                }
                            }
                        }
                    }
                }
                /* Python ───────────────────────────*/
                stage('user-svc deps') {
                    steps {
                        retry(3) {
                            dir('user-service') {
                                sh 'pip install -q -r requirements.txt'
                            }
                        }
                    }
                }
                /* Java ─────────────────────────────*/
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
                /* DB ───────────────────────────────*/
                stage('db deps') {
                    steps { dir('database') { sh 'psql --version' } }
                }
            }
        }

    /* 3. Build Docker images */
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

    /* 4. Push images (main / release branches) */
        stage('Push to Registry') {
            when { anyOf { branch 'main'; branch 'master'; branch pattern: 'release/.+' } }
            stages {
                stage('Login') {
                    steps {
                        withEnv(["USR=${params.DOCKERHUB_USR}", "PSW=${params.DOCKERHUB_PSW}"]) {
                            sh 'set +x && printf "%s" "$PSW" | docker login -u "$USR" --password-stdin'
                        }
                    }
                }
                stage('Push Images') {
                    parallel {
                        stage('Push Frontend')  { steps { sh "docker push ${REGISTRY_PREFIX}/peaky-frontend:${TAG}"  } }
                        stage('Push Gateway')   { steps { sh "docker push ${REGISTRY_PREFIX}/peaky-gateway:${TAG}"   } }
                        stage('Push UserSvc')   { steps { sh "docker push ${REGISTRY_PREFIX}/peaky-user-svc:${TAG}" } }
                        stage('Push Inventory') { steps { sh "docker push ${REGISTRY_PREFIX}/peaky-inventory:${TAG}" } }
                        stage('Push DB')        { steps { sh "docker push ${REGISTRY_PREFIX}/peaky-db:${TAG}"       } }
                    }
                }
            }
        }

    /* 5. Integration test */
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

    /* 6. Deploy (main) */
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
  POST
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
    }
}
