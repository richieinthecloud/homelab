# k3s Homelab GitOps

## Purpose

It exists to build real, practical fluency in Kubernetes, GitOps workflows, and cluster operations. Not just theory, but actual scars from actual troubleshooting.

The guiding principle: **learn by running real workloads on real hardware**, using the same patterns and tools found in production environments.

## What This Runs On

| Node | Hardware | Role |
|---|---|---|
| `ubuntu-dell-7430` | Dell Latitude 7430 | Control-plane |
| `ubuntu-macbook-pro` | 2013 MacBook Pro | Worker |
| `ubuntu-optiplex` | Optiplex 5050 | Worker |

All three nodes run **Ubuntu Server 24.04**, accessed remotely via SSH (key-based auth, separate keys per node). The MacBook Pro runs headless with lid-close suspend disabled so it stays reachable at all times.

## Tools & Stack

- **k3s** lightweight Kubernetes distribution, chosen for its low resource footprint (ideal for older/modest hardware) and simple single-binary install
- **containerd**: the container runtime bundled with k3s (no Docker required on the cluster nodes themselves)
- **Traefik**: ingress controller, bundled with k3s, handling routing into the cluster
- **ArgoCD**: GitOps continuous delivery tool, watching this repo and reconciling cluster state against it. Running in **manual sync** mode for now, while still building confidence in the workflow
- **Kubernetes manifests**: plain YAML to start, with a planned migration to **Helm charts** once the underlying patterns are second nature
- **GitHub**: source of truth for all infrastructure/deployment config

## Repo Philosophy: Separation of App Code and Infra Code

Following GitOps best practice, **application source code and infrastructure/deployment manifests live in separate repositories.** This repo contains only the deployment side. The Kubernetes manifests, Argo CD Application definitions, and cluster configuration. It never contains application source code or Dockerfiles for apps built from scratch.

The two are linked only by container image tags: an app repo builds and publishes an image, and this repo references that image tag in a Deployment manifest. ArgoCD watches this repo, not the app repos.

## Structure

```
apps/                      Kubernetes manifests, one folder per application
infra/argocd/applications/ ArgoCD Application definitions (what ArgoCD watches)
clusters/homelab/          Cluster-level bootstrap config
```

## Workloads

- **Galaga**: a containerized version of a Galaga clone, used as the first test deployment to validate the cluster and GitOps pipeline end-to-end before adding anything more complex
- **Immich**: a self-hosted photo/video management platform, deployed once the pipeline is proven out with Galaga. Introduces persistent storage (PVCs) as a new concept beyond the stateless Galaga deployment

## Status

🚧 Actively under construction — this is a learning project, and the README/structure will evolve as new tools and workloads are added.
