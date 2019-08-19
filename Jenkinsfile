pipeline {
  agent {
    docker {
      image 'hashicorp/packer:light'
      args '--entrypoint=\'\''
    }
  }
  parameters {
    string defaultValue: 'vpc-XXXXXXXX', description: 'AWS VPC ID to build within', name: 'VPC_ID', trim: true
    string defaultValue: 'Private', description: 'AWS Subnet Network tag value', name: 'SUBNET_TAG', trim: true
    string defaultValue: 'aws-credential-id', description: 'Jenkins AWS Credential ID', name: 'AWS_CREDENTIAL_ID', trim: true
    string defaultValue: 'us-east-1', description: 'AWS Region', name: 'AWS_REGION', trim: true
    booleanParam defaultValue: true, description: 'Build Windows AMI', name: 'BUILD_WINDOWS'
    booleanParam defaultValue: false, description: 'Build Linux AMI', name: 'BUILD_LINUX'
  }
  environment {
    VERSION = VersionNumber projectStartDate: '2019-01-01', versionNumberString: '${BUILD_YEAR}.${BUILD_MONTH}.${BUILD_DAY}-${BUILDS_TODAY}', worstResultForIncrement: 'SUCCESS'
  }
  options {
    parallelsAlwaysFailFast()
    disableConcurrentBuilds()
    buildDiscarder logRotator(numToKeepStr: '5')
    withAWS(credentials: params.AWS_CREDENTIAL_ID, region: params.AWS_REGION)
    timestamps()
  }

  stages {
    stage('Build servers') {
      parallel {
        stage('Windows AMI') {
          when {
            expression { return params.BUILD_WINDOWS }
          }
          steps {
            sh """
              packer validate windows-template.json
              packer build -debug -color=false -var 'build-vpc=${params.VPC_ID}' -var 'build-subnet=${params.SUBNET_TAG}' windows-template.json
            """
          }
        }

        stage('Linux AMI') {
          when {
            expression { return params.BUILD_LINUX }
          }
          steps {
            sh """
              packer validate linux-template.json
              packer build -debug -color=false -var 'build-vpc=${params.VPC_ID}' -var 'build-subnet=${params.SUBNET_TAG}' linux-template.json
            """
          }
        }
      }
    }
  }

  post {
    success {
      archiveArtifacts artifacts: "*-manifest.json", fingerprint: true
    }
    cleanup {
      deleteDir()
    }
  }
}
