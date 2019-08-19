# Jenkins EC2 Plugin AMI build

This template is slightly opinionated with a few assumptions

* That VPC subnets have a 'Network' tag to identify them
* Images will contain AWS SSM Agent, Git, AWS CLI & JDK 8
* Images will build from the latest AWS provided ECS Optimized AMI
* You have Linux EC2 with Docker working prior to building

While the Linux AMI built is not technically needed as you can run the provided
Amazon Linux ECS Optimized AMI without modification using UserData, I like to
lock in the build for all instances to ensure behavior so I have it made as a
parameter.

## Setup

The following should help provided guidance in getting this working.

### Jenkins Configuration-As-Code

Under your `jenkins:clouds` configuration for `amazonEC2` type you need to
have a template along the lines of the following examples. The templated values
can be through whatever means you want or added as static values. I make use of
AWS SSM Parameter Store with a CASC_SSM_PREFIX environment variable set to handle
multiple Jenkins instances with different values.

```
templates:
  # Amazon Linux ECS Optimized EC2 Instances
  - ami: ${cloud.ec2.ami.linux}
    amiType:
      unixData:
        rootCommandPrefix: sudo
        sshPort: 22
    associatePublicIp: false
    connectBySSHProcess: false
    connectionStrategy: PRIVATE_IP
    customDeviceMapping: /dev/xvda=:250:true:gp2,/dev/xvdcz=:250:true:gp2
    deleteRootOnTermination: true
    description: Amazon Linux Docker
    ebsOptimized: true
    iamInstanceProfile: ${cloud.ec2.instanceProfile}
    idleTerminationMinutes: 30
    instanceCapStr: 2
    labelString: linux docker docker:linux
    launchTimeoutStr: 300
    maxTotalUses: -1
    mode: EXCLUSIVE
    monitoring: false
    numExecutors: ""
    remoteAdmin: ec2-user
    remoteFS: /home/ec2-user
    securityGroups: ${cloud.ec2.securityGroup}
    spotConfig:
      fallbackToOndemand: true
      useBidPrice: false
    stopOnTerminate: false
    subnetId: ${cloud.ec2.subnets}
    type: M5aXlarge
    userData: |
      #cloud-config
      package_update: true
      package_upgrade: true
      runcmd:
        - ['start', 'amazon-ssm-agent']
  # Windows Server 2019 ECS Optimized EC2 Instances
  - ami: ${cloud.ec2.ami.windows2019}
    amiType:
      windowsData:
        bootDelay: 180
        useHTTPS: false
    associatePublicIp: false
    connectBySSHProcess: false
    connectionStrategy: PRIVATE_IP
    customDeviceMapping: /dev/sda1=:250:true:gp2
    deleteRootOnTermination: true
    description: Windows Server 2019 Docker
    ebsOptimized: true
    iamInstanceProfile: ${cloud.ec2.instanceProfile}
    idleTerminationMinutes: 30
    initScript: |
      if not exist C:\Jenkins mkdir C:\Jenkins
    instanceCapStr: 2
    labelString: windows docker:windows
    maxTotalUses: -1
    mode: EXCLUSIVE
    monitoring: false
    numExecutors: ""
    remoteAdmin: Administrator
    remoteFS: C:\Jenkins
    securityGroups: ${cloud.ec2.securityGroup}
    spotConfig:
      fallbackToOndemand: true
      useBidPrice: false
    stopOnTerminate: false
    subnetId: ${cloud.ec2.subnets}
    type: M5aXlarge
    userData: |
      <powershell>
      Write-Output 'Setting up WinRM-HTTPS';
      Set-NetFirewallRule -Name 'WINRM-HTTP-In-TCP' -Enabled False;
      Set-NetFirewallRule -Name 'WINRM-HTTP-In-TCP-PUBLIC' -Enabled False;
      $Cert = New-SelfSignedCertificate -CertstoreLocation cert:\LocalMachine\My -DnsName $env:COMPUTERNAME;
      Remove-WSManInstance -ResourceURI Winrm/Config/Listener -SelectorSet @{Address = '*'; Transport = 'HTTPS'}
      New-WSManInstance -ResourceURI Winrm/Config/Listener -SelectorSet @{Address = '*'; Transport = 'HTTPS'} -ValueSet @{Hostname = $env:COMPUTERNAME; CertificateThumbprint = $Cert.Thumbprint};
      Restart-Service -Name 'WinRM';
      Write-Output 'Opening NetFirewall';
      Set-NetFirewallRule -Name 'FPS-SMB-In-TCP' -Enabled True;
      Set-NetFirewallRule -Name 'WINRM-HTTP-In-TCP' -Enabled True;
      Set-NetFirewallRule -Name 'WINRM-HTTP-In-TCP-PUBLIC' -Enabled True;
      New-NetFirewallRule -Name 'WINRM-HTTPS-In-TCP' -DisplayName 'Windows Remote Management (HTTPS-In)' -Description 'Inbound rule for Windows Remote Management via WS-Management. [TCP 5986]' -Direction Inbound -Group '@FirewallAPI.dll,-30267' -Action Allow -LocalPort 5986 -Protocol TCP -Profile 'Domain, Private' -Enabled True;
      New-NetFirewallRule -Name 'WINRM-HTTPS-In-TCP-PUBLIC' -DisplayName 'Windows Remote Management (HTTPS-In)' -Description 'Inbound rule for Windows Remote Management via WS-Management. [TCP 5986]' -Direction Inbound -Group '@FirewallAPI.dll,-30267' -Action Allow -LocalPort 5986 -Protocol TCP -Profile Public -Enabled True;
      </powershell>
```

### AWS IAM

The AWS IAM Instance profile I use is very simple to provide the ability use AWS SSM SystemManager
for remote access to the node for debugging purposes.

```
EC2Role:
  Type: AWS::IAM::Role
  Properties:
    AssumeRolePolicyDocument:
      Statement:
        - Effect: Allow
          Principal:
            Service:
              - 'ec2.amazonaws.com'
              - 'ssm.amazonaws.com'
          Action:
            - sts:AssumeRole
    ManagedPolicyArns:
      - arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM
    Path: /

EC2InstanceProfile:
  Type: AWS::IAM::InstanceProfile
  Properties:
    Path: /
    Roles:
      - Ref: EC2Role
```

Your Jenkins Master needs to be provided the necessary IAM permissions to instantiate the EC2
agents. If the master runs in ECS this would be in the `TaskRole` or if the master runs on an EC2
instance this would be in the `InstanceProfile`. In either case you would need to add the following
policy statement.

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt1312295543082",
            "Action": [
                "ec2:DescribeSpotInstanceRequests",
                "ec2:CancelSpotInstanceRequests",
                "ec2:GetConsoleOutput",
                "ec2:RequestSpotInstances",
                "ec2:RunInstances",
                "ec2:StartInstances",
                "ec2:StopInstances",
                "ec2:TerminateInstances",
                "ec2:CreateTags",
                "ec2:DeleteTags",
                "ec2:DescribeInstances",
                "ec2:DescribeKeyPairs",
                "ec2:DescribeRegions",
                "ec2:DescribeImages",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "iam:ListInstanceProfilesForRole",
                "iam:PassRole",
                "ec2:GetPasswordData"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
```

### AWS Security Groups

The AWS Security Group provided to the EC2 instance I keep very clean and simple only allowing access
from the Jenkins Master itself. You can use the following CloudFormation template snippet as an example
to work from. In the snippet `JenkinsMasterSecurityGroup` is the security group assigned to the Jenkins
Master and `JenkinsAgentSecurityGroup` is the security group assigned to the Jenkins Agent. This should
work for Linux or Windows using SSH or WinRM (with or without SSL).

```
JenkinsAgentSecurityGroupSSHIngress:
  Type: AWS::EC2::SecurityGroupIngress
  Properties:
    GroupId: !Ref JenkinsAgentSecurityGroup
    IpProtocol: tcp
    FromPort: 22
    ToPort: 22
    SourceSecurityGroupId: !Ref JenkinsMasterSecurityGroup
    Description: Jenkins Master SSH Access

JenkinsAgentSecurityGroupSMBIngress:
  Type: AWS::EC2::SecurityGroupIngress
  Properties:
    GroupId: !Ref JenkinsAgentSecurityGroup
    IpProtocol: tcp
    FromPort: 445
    ToPort: 445
    SourceSecurityGroupId: !Ref JenkinsMasterSecurityGroup
    Description: Jenkins Master CIFS Access

JenkinsAgentSecurityGroupWinRMHTTPIngress:
  Type: AWS::EC2::SecurityGroupIngress
  Properties:
    GroupId: !Ref JenkinsAgentSecurityGroup
    IpProtocol: tcp
    FromPort: 5985
    ToPort: 5985
    SourceSecurityGroupId: !Ref JenkinsMasterSecurityGroup
    Description: Jenkins Master WinRM-HTTP Access

JenkinsAgentSecurityGroupWinRMHTTPSIngress:
  Type: AWS::EC2::SecurityGroupIngress
  Properties:
    GroupId: !Ref JenkinsAgentSecurityGroup
    IpProtocol: tcp
    FromPort: 5986
    ToPort: 5986
    SourceSecurityGroupId: !Ref JenkinsMasterSecurityGroup
    Description: Jenkins Master WinRM-HTTPS Access
```
