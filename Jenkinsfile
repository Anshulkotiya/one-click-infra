// ============================================================================
// One-Click ELK Infra Pipeline
//
// Flow: checkout -> terraform init/plan/apply -> discover new instance IPs
//       -> generate ansible inventory -> run ansible playbook (ES + Kibana)
//       -> print access info
//
// Required Jenkins credentials (Manage Jenkins > Credentials):
//   aws-elk-creds        (AWS Credentials plugin)      -> AWS access/secret key
//   elk-ec2-ssh-key       (SSH Username with private key) -> key used for EC2 (bastion + app nodes)
//
// NOTE: Bastion SSH access is open to 0.0.0.0/0 by default (var.admin_cidr in
// variables.tf) — kept simple. Restrict it to your own IP for better security
// if needed. Elasticsearch/Kibana passwords also use the defaults already
// set in ansible/playbook.yml (not injected from Jenkins).
//
// Required Jenkins tools/plugins: Terraform (or terraform on PATH), AWS CLI,
// Ansible, jq.
// ============================================================================

pipeline {
  agent any

  parameters {
    choice(name: 'ACTION', choices: ['apply', 'destroy'], description: 'Terraform action to run')
    string(name: 'KEY_PAIR_NAME', defaultValue: 'my-ec2-keypair', description: 'Existing AWS EC2 key pair name')
    string(name: 'TF_STATE_BUCKET', defaultValue: 'my-terraform-assignment-bucket-anshul2026', description: 'S3 bucket for terraform remote state (created once via terraform/backend-setup)')
    string(name: 'AWS_REGION', defaultValue: 'ap-south-1', description: 'AWS region')
    booleanParam(name: 'AUTO_APPROVE', defaultValue: false, description: 'Skip manual approval before apply/destroy (use with care)')
  }

  environment {
    TF_DIR        = "terraform"
    TF_VAR_key_name = "${params.KEY_PAIR_NAME}"
    TF_VAR_aws_region = "${params.AWS_REGION}"
    ANSIBLE_DIR   = "ansible"
    
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Terraform Init') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-elk-creds']]) {
          dir(TF_DIR) {
            sh '''
              terraform init -input=false \
                -backend-config="bucket=${TF_STATE_BUCKET}" \
                -backend-config="key=elk-infra/terraform.tfstate" \
                -backend-config="region=${AWS_REGION}" \
                -backend-config="encrypt=true"
            '''
          }
        }
      }
    }

    stage('Terraform Validate & Plan') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-elk-creds']]) {
          dir(TF_DIR) {
            script {
              def destroyFlag = (params.ACTION == 'destroy') ? '-destroy' : ''
              sh """
                terraform validate
                terraform plan -input=false ${destroyFlag} -out=tfplan
              """
            }
          }
        }
      }
    }

    stage('Approval') {
      when { expression { return !params.AUTO_APPROVE } }
      steps {
        input message: "Review the Terraform plan above. Proceed with '${params.ACTION}'?"
      }
    }

    stage('Terraform Apply / Destroy') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-elk-creds']]) {
          dir(TF_DIR) {
            // Works for both actions: the plan file already encodes whether
            // this is a create/update plan or a destroy plan (see previous stage).
            sh 'terraform apply -input=false -auto-approve tfplan'
          }
        }
      }
    }

   
stage('Read Bastion IP') {
    when {
        expression { params.ACTION == 'apply' }
    }

    steps {
        withCredentials([
            [$class: 'AmazonWebServicesCredentialsBinding',
             credentialsId: 'aws-elk-creds']
        ]) {

            dir(TF_DIR) {
                script {
                    env.BASTION_IP = sh(
                        script: "terraform output -raw bastion_public_ip",
                        returnStdout: true
                    ).trim()

                    echo "Bastion IP = ${env.BASTION_IP}"
                }
            }

        }
    }
}








    stage('Wait for SSH') {
      when { expression { params.ACTION == 'apply' } }
      steps {
        withCredentials([
    [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-elk-creds'],
    sshUserPrivateKey(credentialsId: 'elk-ec2-ssh-key', keyFileVariable: 'SSH_KEY_FILE')
]) {
           dir(ANSIBLE_DIR) {

            sh '''

               . /var/lib/jenkins/venv/bin/activate
                   
               export ANSIBLE_SSH_COMMON_ARGS="-o StrictHostKeyChecking=no -o ProxyJump=ubuntu@${BASTION_IP} -i ${SSH_KEY_FILE}" 



              # Simple readiness loop: retry ansible ping for up to 5 minutes
              for i in $(seq 1 30); do
                 if ansible role_elk -m ping \
  -i inventory/aws_ec2.yml \
  --private-key ${SSH_KEY_FILE}; then
                  echo "All hosts reachable."
                  break
                fi
                echo "Hosts not ready yet, retrying in 10s... ($i/30)"
                sleep 10
              done
            '''
          }
        }
      }
    }

    stage('Run Ansible Playbook (Install ES + Kibana)') {
  when { expression { params.ACTION == 'apply' } }
  steps {
    withCredentials([
      [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-elk-creds'],
     sshUserPrivateKey(credentialsId: 'elk-ec2-ssh-key', keyFileVariable: 'SSH_KEY_FILE')
    ]) {
      dir(ANSIBLE_DIR) {
        sh '''
          source /var/lib/jenkins/venv/bin/activate
           
          export ANSIBLE_SSH_COMMON_ARGS="-o StrictHostKeyChecking=no -o ProxyJump=ubuntu@${BASTION_IP} -i ${SSH_KEY_FILE}"

             
            echo "===== DEBUG ====="
  which ansible
  ansible --version
  pwd
  cat ansible.cfg

  aws sts get-caller-identity

  echo "===== INVENTORY ====="
  ansible-inventory -i inventory/aws_ec2.yml --graph

  echo "===== PLAYBOOK ====="

          ansible-playbook \
-i inventory/aws_ec2.yml \
playbook.yml \
--private-key ${SSH_KEY_FILE}
        '''
      }
    }
  }
}


    stage('Show Access Info') {
      when { expression { params.ACTION == 'apply' } }
      steps {
        dir(TF_DIR) {
          sh '''
            echo "=================================================="
            echo " Kibana URL   : http://$(terraform output -raw alb_dns_name)"
            echo " Bastion IP   : $(terraform output -raw bastion_public_ip)"
           echo "=================================================="
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'terraform/tfplan', allowEmptyArchive: true
      archiveArtifacts artifacts: 'ansible/inventory/aws_ec2.yml', allowEmptyArchive: true
    }
    success {
      echo "Pipeline completed successfully (${params.ACTION})."
    }
    failure {
      echo "Pipeline failed — check the stage logs above."
    }
  }
}
