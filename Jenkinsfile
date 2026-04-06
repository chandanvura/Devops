// ─────────────────────────────────────────────────────────────────
// Jenkins Pipeline — devops-app
// Stages: Checkout → Build → Test → Security Scan → Docker Build
//         → Push to Registry → Deploy NonProd → Gate → Deploy Prod
// ─────────────────────────────────────────────────────────────────

pipeline {

  // Run pipeline steps inside a Kubernetes pod agent
  // Each stage gets a fresh pod — no leftover state between builds
  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: maven
    image: maven:3.9-eclipse-temurin-17
    command: ['cat']
    tty: true
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"
  - name: docker
    image: docker:24-dind
    securityContext:
      privileged: true
    env:
    - name: DOCKER_TLS_CERTDIR
      value: ""
  - name: helm
    image: alpine/helm:3.14.0
    command: ['cat']
    tty: true
"""
    }
  }

  environment {
    APP_NAME     = 'devops-app'
    REGISTRY     = 'ghcr.io/chandanvura'  // update this
    IMAGE_TAG    = "${env.GIT_COMMIT[0..7]}-${env.BUILD_NUMBER}"
    HELM_CHART   = './helm/devops-app'
  }

  options {
    timeout(time: 20, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '10'))
    disableConcurrentBuilds()  // no parallel runs on same branch
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
        echo "Branch: ${env.GIT_BRANCH} | Commit: ${env.GIT_COMMIT[0..7]}"
      }
    }

    stage('Build') {
      steps {
        container('maven') {
          sh 'mvn clean package -DskipTests -f app/pom.xml -q'
          echo "JAR built: app/target/devops-app-*.jar"
        }
      }
    }

    stage('Unit Tests') {
      steps {
        container('maven') {
          sh 'mvn test -f app/pom.xml'
        }
      }
      post {
        always {
          // Publish test results in Jenkins UI
          junit 'app/target/surefire-reports/*.xml'
        }
      }
    }

    stage('Security Scan') {
      steps {
        // Trivy scans filesystem for CVEs before building image
        sh '''
          docker run --rm \
            -v $(pwd):/project \
            aquasec/trivy:latest fs \
            --exit-code 0 \
            --severity HIGH,CRITICAL \
            --format table \
            /project/app
        '''
        echo "Security scan complete — review output above"
      }
    }

    stage('Docker Build') {
      steps {
        container('docker') {
          sh "docker build -t ${REGISTRY}/${APP_NAME}:${IMAGE_TAG} ./app"
          sh "docker tag ${REGISTRY}/${APP_NAME}:${IMAGE_TAG} ${REGISTRY}/${APP_NAME}:latest"
          echo "Image: ${REGISTRY}/${APP_NAME}:${IMAGE_TAG}"
        }
      }
    }

    stage('Docker Push') {
      steps {
        container('docker') {
          withCredentials([usernamePassword(
            credentialsId: 'github-registry-creds',
            usernameVariable: 'DOCKER_USER',
            passwordVariable: 'DOCKER_PASS'
          )]) {
            sh """
              echo \$DOCKER_PASS | docker login ghcr.io -u \$DOCKER_USER --password-stdin
              docker push ${REGISTRY}/${APP_NAME}:${IMAGE_TAG}
              docker push ${REGISTRY}/${APP_NAME}:latest
            """
          }
        }
      }
    }

    stage('Deploy → NonProd') {
      steps {
        container('helm') {
          sh """
            helm upgrade --install ${APP_NAME} ${HELM_CHART} \
              --namespace nonprod \
              --create-namespace \
              --set image.repository=${REGISTRY}/${APP_NAME} \
              --set image.tag=${IMAGE_TAG} \
              --set env.APP_ENV=nonprod \
              --values ${HELM_CHART}/values-nonprod.yaml \
              --wait --timeout 5m
          """
          echo "Deployed to nonprod: ${APP_NAME}:${IMAGE_TAG}"
        }
      }
    }

    stage('Smoke Test') {
      steps {
        // Basic health check against nonprod
        sh """
          sleep 10
          kubectl get pods -n nonprod -l app=${APP_NAME}
          echo "Smoke test: checking /actuator/health"
          kubectl exec -n nonprod \
            \$(kubectl get pod -n nonprod -l app=${APP_NAME} -o jsonpath='{.items[0].metadata.name}') \
            -- wget -q -O- http://localhost:8080/actuator/health
        """
      }
    }

    stage('Deploy → Production') {
      when {
        branch 'main'  // only deploy to prod from main branch
      }
      input {
        message 'Deploy to PRODUCTION?'
        ok 'Yes — deploy now'
        submitter 'devops-lead,tech-lead'
      }
      steps {
        container('helm') {
          sh """
            helm upgrade --install ${APP_NAME} ${HELM_CHART} \
              --namespace prod \
              --create-namespace \
              --set image.repository=${REGISTRY}/${APP_NAME} \
              --set image.tag=${IMAGE_TAG} \
              --set env.APP_ENV=prod \
              --values ${HELM_CHART}/values-prod.yaml \
              --wait --timeout 10m
          """
          echo "Deployed to PRODUCTION: ${APP_NAME}:${IMAGE_TAG}"
        }
      }
    }
  }

  post {
    success {
      echo "Pipeline PASSED — ${APP_NAME}:${IMAGE_TAG} deployed"
    }
    failure {
      script {
        // Auto rollback if prod deployment failed
        if (env.STAGE_NAME == 'Deploy → Production') {
          container('helm') {
            sh "helm rollback ${APP_NAME} 0 --namespace prod || true"
            echo "AUTO-ROLLBACK executed for ${APP_NAME} in prod"
          }
        }
      }
      echo "Pipeline FAILED at stage: ${env.STAGE_NAME}"
    }
    always {
      // Clean up dangling Docker images on the agent
      sh 'docker image prune -f || true'
    }
  }
}
