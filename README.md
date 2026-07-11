# Automated Web Application Deployment using AWS, Terraform, Docker, and GitHub Actions/Jenkins

## Objective
Build and deploy a containerized web application on AWS using Infrastructure as Code (Terraform) and a CI/CD pipeline (Jenkins), with SonarQube for code quality and Trivy for image vulnerability scanning.

## Architecture
```
GitHub Repo ──push──▶ Jenkins ──▶ SonarQube (code quality)
                          │
                          ▼
                    Build Docker Image
                          │
                          ▼
                    Trivy (vuln scan)
                          │
                          ▼
                    Docker Hub (push image)
                          │
                          ▼
                 SSH into EC2 (in AWS VPC, public subnet)
                          │
                          ▼
                 docker pull + docker run
                          │
                          ▼
              User accesses app via EC2 Public IP
```

---

## Prerequisites (install once, on your local Linux/WSL machine)

| Tool | Install command (Ubuntu/Debian) |
|---|---|
| AWS CLI | `curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && sudo ./aws/install` |
| Terraform | `sudo apt install -y gnupg software-properties-common && wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list && sudo apt update && sudo apt install terraform` |
| Docker | `curl -fsSL https://get.docker.com | sh && sudo usermod -aG docker $USER` |
| Git | `sudo apt install -y git` |

Also create free accounts for:
- **AWS** (with an IAM user that has `AmazonEC2FullAccess` + `AmazonVPCFullAccess`, and Access Key ID/Secret configured via `aws configure`)
- **GitHub** (for the repo)
- **Docker Hub** (for the image registry)

---

## Do I need a sample app / repo?

Yes. Terraform provisions infrastructure, Docker packages an app, and Jenkins automates the pipeline — but none of them create an application by themselves. This project includes a minimal Flask "Hello World" app (`app/app.py`) so you have something real to build, scan, and deploy. Push this entire folder structure to a new GitHub repository — that repo is what Jenkins will check out and build from.

```bash
cd devops-project
git init
git add .
git commit -m "Initial commit: Terraform + Docker + Jenkins DevOps project"
git branch -M main
git remote add origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```

---

## Phase 1 — AWS Infrastructure Setup (Terraform)

**Files:** `terraform/provider.tf`, `variables.tf`, `main.tf`, `outputs.tf`

1. Create an EC2 key pair in the AWS Console (EC2 → Key Pairs → Create) and download the `.pem` file. Keep it safe — you'll need it for SSH.
2. Find your public IP: `curl ifconfig.me`
3. Copy the example vars file and fill it in:
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # edit terraform.tfvars: set key_name and my_ip
   ```
4. Configure AWS credentials locally: `aws configure`
5. Initialize and apply:
   ```bash
   terraform init
   terraform plan
   terraform apply    # type "yes" when prompted
   ```
6. Note the `ec2_public_ip` output — you'll need it for Phases 3 and 4.

This provisions: a VPC, a public subnet with an internet gateway and route table, a security group (SSH restricted to your IP; HTTP, Jenkins UI, and the app port open), and an EC2 instance with Docker pre-installed via `user_data`.

---

## Phase 2 — Docker Configuration

**Files:** `app/Dockerfile`, `app/app.py`, `app/requirements.txt`

1. Build the image locally to test it:
   ```bash
   cd ../app
   docker build -t devops-project-app .
   docker run -p 5000:5000 devops-project-app
   curl http://localhost:5000
   ```
2. Create a Docker Hub repository named `devops-project-app` (hub.docker.com → Create Repository).
3. Push manually once, to confirm access works (Jenkins will automate this later):
   ```bash
   docker login
   docker tag devops-project-app <your-dockerhub-username>/devops-project-app:latest
   docker push <your-dockerhub-username>/devops-project-app:latest
   ```

---

## Phase 3 — CI/CD Pipeline (Jenkins + SonarQube + Trivy)

**File:** `Jenkinsfile`

### 3.1 Install Jenkins (on a separate small EC2 instance, or the same box, or your local machine)
```bash
sudo apt update
sudo apt install -y openjdk-17-jdk
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list
sudo apt update
sudo apt install -y jenkins
sudo systemctl enable --now jenkins
```
Access Jenkins at `http://<jenkins-host>:8080`, unlock with `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`, and install suggested plugins plus: **Docker Pipeline**, **SonarQube Scanner**, **SSH Agent**.

### 3.2 Install SonarQube (Docker is easiest)
```bash
docker run -d --name sonarqube -p 9000:9000 sonarqube:lts-community
```
Log into `http://<host>:9000` (default admin/admin), generate a token (My Account → Security), then in Jenkins go to **Manage Jenkins → System → SonarQube servers** and add a server named `MySonarQubeServer` with the URL and token.

### 3.3 Install Trivy (on the Jenkins agent)
```bash
sudo apt install -y wget apt-transport-https gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo gpg --dearmor -o /usr/share/keyrings/trivy.gpg
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt update && sudo apt install -y trivy
```

### 3.4 Add credentials in Jenkins (Manage Jenkins → Credentials)
- `dockerhub-creds` — Username/password type, your Docker Hub username + access token.
- `ec2-ssh-key` — SSH Username with private key type, using the `.pem` from Phase 1 (username `ubuntu`).

### 3.5 Create the pipeline job
- New Item → Pipeline → name it → under Pipeline, choose "Pipeline script from SCM" → Git → your repo URL → Script Path `Jenkinsfile`.
- Edit the `Jenkinsfile` in your repo: replace `your-dockerhub-username`, `<your-username>/<your-repo>`, and `<EC2_PUBLIC_IP>` with your real values.
- Click **Build Now**.

The pipeline: checks out code → runs SonarQube analysis and quality gate → builds the Docker image → scans it with Trivy → pushes to Docker Hub → SSHes into the EC2 instance and redeploys the container.

---

## Phase 4 — Deployment

This happens automatically as the last stage of the Jenkins pipeline, but here's what it's doing (and how to do it manually if you want to test first):

```bash
ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>
docker pull <your-dockerhub-username>/devops-project-app:latest
docker run -d --name app-container -p 80:5000 <your-dockerhub-username>/devops-project-app:latest
```

Then open `http://<EC2_PUBLIC_IP>` in your browser — you should see the Flask app's response.

---

## Deliverables checklist
- [x] GitHub Repository — push this whole `devops-project` folder
- [x] Terraform files — `terraform/`
- [x] Dockerfile — `app/Dockerfile`
- [x] Jenkinsfile (Groovy) — `Jenkinsfile`
- [ ] Screenshots — capture: `terraform apply` output, Docker Hub repo with pushed image, Jenkins pipeline stages (green), the app loading in browser via EC2 public IP
- [x] Architecture Diagram — see rendered diagram in this conversation, or export it as an image
- [x] Project Report — this README

## Cleanup (avoid AWS charges)
```bash
cd terraform
terraform destroy
```
