# Deploying Microservices on Amazon EKS with Terraform

## Project Overview

This project demonstrates the deployment of a containerized WordPress application on Amazon Elastic Kubernetes Service (Amazon EKS) using Infrastructure as Code (IaC), Kubernetes, Helm, and AWS services.

The environment is provisioned with Terraform and includes highly available networking, managed Kubernetes worker nodes, persistent EBS storage, application autoscaling, and a complete Prometheus and Grafana observability stack.

The project demonstrates an end-to-end cloud engineering workflow covering infrastructure provisioning, Kubernetes workload deployment, persistent storage, autoscaling, monitoring, troubleshooting, and infrastructure cleanup.

---

## Architecture

```text
                         Internet
                            |
                     AWS Load Balancer
                            |
                     WordPress Service
                            |
                    Amazon EKS Cluster
                  /         |          \
             Worker 1    Worker 2    Worker 3
             t3.small    t3.small    t3.small
                  \         |          /
                   Kubernetes Workloads
                     /             \
                WordPress         MariaDB
                    |                |
                 EBS gp3          EBS gp3
                    |
             AWS EBS CSI Driver

              Observability Stack
                       |
        +--------------+--------------+
        |              |              |
   Prometheus       Grafana      Alertmanager
        |
   +----+----------------+
   |                     |
Node Exporter      kube-state-metrics
```

---

## Technologies Used

- Amazon Web Services (AWS)
- Amazon EKS
- Amazon EC2
- Amazon VPC
- Elastic Load Balancing
- Amazon EBS
- Terraform
- Kubernetes
- Helm
- Docker containers
- WordPress
- MariaDB
- Kubernetes Metrics Server
- Horizontal Pod Autoscaler (HPA)
- Prometheus
- Grafana
- Alertmanager
- kube-state-metrics
- Node Exporter
- Git and GitHub

---

## Infrastructure Provisioning

Terraform is used to provision the AWS infrastructure required by the EKS environment.

The infrastructure includes:

- Custom VPC
- Public and private subnets
- Internet Gateway
- NAT Gateway
- Route tables and associations
- Amazon EKS cluster
- EKS managed node group
- IAM roles and policies
- AWS EBS CSI driver
- EKS Pod Identity configuration

Terraform configuration is stored under:

```text
Terraform/
```

Typical deployment workflow:

```bash
cd Terraform

terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

---

## Amazon EKS Worker Nodes

The EKS managed node group uses three EC2 worker nodes.

```text
Instance Type: t3.small
Desired Nodes: 3
```

Node health can be verified with:

```bash
kubectl get nodes
```

The project initially tested smaller `t3.micro` instances. The monitoring workloads exposed resource and pod-density constraints, so the worker configuration was updated to `t3.small` to provide sufficient capacity for the application and observability stack.

---

## Kubernetes Persistent Storage

Persistent storage is provided using the AWS EBS CSI driver.

A custom `gp3` Kubernetes StorageClass is defined in:

```text
Kubernetes/storageclass.yaml
```

Storage can be verified with:

```bash
kubectl get storageclass
kubectl get pvc -A
kubectl get pv
```

Persistent volumes are dynamically provisioned for:

- WordPress
- MariaDB
- Prometheus
- Grafana

The deployment uses the `WaitForFirstConsumer` volume binding mode so EBS volumes are provisioned according to workload scheduling requirements.

---

## EBS CSI Validation

A dedicated Kubernetes storage test was used to verify dynamic EBS provisioning and persistent volume mounting.

```text
Kubernetes/storage-test.yaml
```

The validation confirmed that:

- PVC creation succeeds
- EBS volumes are dynamically provisioned
- PVCs transition to `Bound`
- Pods can mount the provisioned storage
- Data can be written to and read from the mounted volume

---

## WordPress Deployment

WordPress and MariaDB are deployed using the Bitnami WordPress Helm chart.

Application configuration is stored in:

```text
Helm/wordpress-values.yaml
```

The deployment creates:

- WordPress application pod
- MariaDB database
- Persistent storage
- Kubernetes services
- External AWS Load Balancer

Example deployment:

```bash
helm install wordpress bitnami/wordpress \
  --namespace wordpress \
  --create-namespace \
  -f Helm/wordpress-values.yaml
```

Sensitive passwords should be supplied securely at deployment time and must not be committed to the repository.

Verify the application:

```bash
kubectl get pods -n wordpress
kubectl get svc -n wordpress
kubectl get pvc -n wordpress
```

The WordPress service is exposed through an AWS Load Balancer.

---

## Kubernetes Metrics Server

Kubernetes Metrics Server provides resource metrics used by commands such as:

```bash
kubectl top nodes
kubectl top pods -n wordpress
```

These metrics also support Horizontal Pod Autoscaling.

---

## Horizontal Pod Autoscaling

The WordPress deployment uses a Kubernetes Horizontal Pod Autoscaler.

The HPA is configured to scale WordPress according to CPU and memory utilization.

```text
Minimum replicas: 1
Maximum replicas: 3
CPU target:       60%
Memory target:    70%
```

HPA status can be viewed with:

```bash
kubectl get hpa -n wordpress
```

During load testing, the HPA successfully increased the number of WordPress replicas in response to resource demand, demonstrating dynamic application scaling.

---

## Prometheus and Grafana Monitoring

The project uses the Prometheus Community `kube-prometheus-stack` Helm chart for Kubernetes observability.

The stack includes:

- Prometheus
- Grafana
- Alertmanager
- Prometheus Operator
- kube-state-metrics
- Node Exporter

Monitoring configuration is stored in:

```text
Helm/monitoring-values.yaml
```

The monitoring workloads run in the dedicated:

```text
monitoring
```

namespace.

Verify them with:

```bash
kubectl get pods -n monitoring
```

---

## Monitoring Persistence

Prometheus and Grafana use persistent AWS EBS `gp3` volumes.

The configured persistent storage includes:

```text
Grafana:     5 GiB
Prometheus: 10 GiB
```

Verify with:

```bash
kubectl get pvc -n monitoring
```

---

## Prometheus Validation

Prometheus was validated by querying Kubernetes metrics directly.

Examples:

```promql
up
```

The `up` query verifies that Prometheus can successfully scrape configured targets.

Additional Kubernetes queries include:

```promql
kube_node_info
```

and:

```promql
kube_pod_info{namespace="wordpress"}
```

These queries confirm visibility into the EKS worker nodes and WordPress workloads.

---

## Grafana Dashboards

Grafana provides visualization of the metrics collected by Prometheus.

Cluster-level monitoring was validated using:

```text
Kubernetes / Compute Resources / Cluster
```

This dashboard provides visibility into:

- Cluster CPU utilization
- Memory utilization
- CPU requests and limits
- Memory requests and limits
- Namespace resource consumption

Application-level monitoring was validated using:

```text
Kubernetes / Compute Resources / Namespace (Pods)
```

with:

```text
namespace = wordpress
```

This provides resource visibility for the WordPress and MariaDB workloads.

---

## Accessing Grafana

Grafana can be accessed locally without exposing another public AWS Load Balancer.

```bash
kubectl port-forward \
  -n monitoring \
  svc/monitoring-grafana \
  3000:80
```

Grafana is then available locally on port `3000`.

The administrator password should be retrieved from the Kubernetes Secret when needed and must never be committed to Git.

---

## Accessing Prometheus

Prometheus can also be accessed using Kubernetes port forwarding:

```bash
kubectl port-forward \
  -n monitoring \
  svc/monitoring-kube-prometheus-prometheus \
  9090:9090
```

Prometheus is then available locally on port `9090`.

---

## Project Structure

```text
.
├── Helm/
│   ├── monitoring-values.yaml
│   └── wordpress-values.yaml
│
├── Kubernetes/
│   ├── storage-test.yaml
│   └── storageclass.yaml
│
├── Terraform/
│   ├── .terraform.lock.hcl
│   ├── eks.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── versions.tf
│   └── vpc.tf
│
├── .gitignore
└── README.md
```

---

## Validation Commands

Useful commands for validating the complete environment:

```bash
kubectl get nodes
kubectl get pods -n wordpress
kubectl get pods -n monitoring
kubectl get pvc -A
kubectl get hpa -n wordpress
kubectl top nodes
helm list -A
```

Terraform configuration can be verified with:

```bash
cd Terraform

terraform fmt
terraform validate
terraform plan
```

---

## Troubleshooting and Lessons Learned

### EKS Worker Capacity

The initial worker configuration used `t3.micro` instances. When additional Kubernetes components were deployed, particularly the EBS CSI and monitoring workloads, the nodes experienced insufficient scheduling capacity.

The worker nodes were changed to `t3.small`, providing sufficient resources for WordPress, MariaDB, Prometheus, Grafana, and supporting Kubernetes components.

### EBS CSI Driver

The EBS CSI add-on initially became degraded because controller pods could not be scheduled due to insufficient node capacity.

Increasing worker-node capacity allowed the CSI controller pods to schedule successfully and the add-on became healthy.

### Helm and HPA Ownership

Manual Kubernetes modifications can conflict with resources managed by Helm. HPA configuration should therefore be maintained through Helm values whenever possible so that Helm remains the authoritative configuration source.

### Infrastructure Validation

The project demonstrated the importance of validating each layer independently:

1. Terraform infrastructure
2. EKS node health
3. CSI storage provisioning
4. Kubernetes workloads
5. Application availability
6. Metrics collection
7. Autoscaling
8. Prometheus monitoring
9. Grafana visualization

---

## Infrastructure Cleanup

AWS resources should be destroyed when the environment is no longer required to avoid unnecessary charges.

From the Terraform directory:

```bash
terraform plan -destroy
terraform destroy
```

Always review the destroy plan before approving it.

Application resources created separately through Kubernetes or Helm should also be reviewed as part of the cleanup process.

---

## Security Considerations

This repository intentionally excludes sensitive and generated files through `.gitignore`, including:

- Terraform state
- Terraform variable files
- AWS credentials
- Private keys
- Kubernetes configuration
- Local editor settings
- Temporary files

Secrets and application passwords should never be stored directly in Git.

---

## Project Outcome

This project successfully demonstrates:

- Infrastructure as Code with Terraform
- Amazon EKS provisioning
- Kubernetes workload orchestration
- Persistent storage using Amazon EBS
- Helm-based application deployment
- AWS Load Balancer integration
- Kubernetes resource monitoring
- Horizontal Pod Autoscaling
- Prometheus metrics collection
- Grafana dashboards and observability
- Infrastructure troubleshooting
- Git-based infrastructure management

The resulting environment provides a practical example of deploying, scaling, persisting, monitoring, and managing a Kubernetes-based application on AWS.