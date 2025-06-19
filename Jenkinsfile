pipeline {
    agent any
    options { timestamps() }

    /* ←––––––––––––––––––––––––––
       automatically build on push
    ––––––––––––––––––––––––––––→ */
    triggers { githubPush() }

    environment {
        FRONTEND_REPO = 'git@github.com:peakyblinders/frontend.git'
        GATEWAY_REPO  = 'git@github.com:peakyblinders/api-gateway.git'
        USER_REPO     = 'git@github.com:peakyblinders/user-service.git'
        INV_REPO      = 'git@github.com:peakyblinders/inventory-service.git'
        DB_REPO       = 'git@github.com:peakyblinders/database.git'
        TAG           = "latest"
    }

    stages {
        /* …everything else exactly as you already have… */
    }

    post {
        always  { echo 'docker compose -f infra/docker-compose.yml down' }
        success { echo 'SUCCESS – deploy would go here.' }
        failure { echo 'FAILURE – investigate logs above.' }
    }
}
