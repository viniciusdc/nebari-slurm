resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "digitalocean_ssh_key" "main" {
  name       = "${var.name}-qhub-hpc-automated-ssh-key"
  public_key = tls_private_key.main.public_key_openssh
}

resource "digitalocean_vpc" "main" {
  name     = "${var.name}-network"
  region   = var.region
  ip_range = var.ip_range
}

resource "digitalocean_droplet" "master-node" {
  name     = "${var.name}-master"
  image    = var.master-image
  size     = var.worker-instance
  region   = var.region
  vpc_uuid = digitalocean_vpc.main.id

  ssh_keys = [digitalocean_ssh_key.main.fingerprint]

  tags = concat([
    "qhub-hpc", "master"
  ], var.tags)
}

resource "digitalocean_droplet" "worker-nodes" {
  count = var.worker-count

  name     = "${var.name}-worker-${count.index}"
  image    = var.worker-image
  size     = var.worker-instance
  region   = var.region
  vpc_uuid = digitalocean_vpc.main.id

  ssh_keys = [digitalocean_ssh_key.main.fingerprint]

  tags = concat([
    "qhub-hpc", "worker"
  ], var.tags)
}

resource "local_file" "ansible_inventory" {
  content = <<EOT
# autogenerated by terraform

${var.name}-master ansible_host=${digitalocean_droplet.master-node.ipv4_address} ansible_user=root ansible_ssh_private_key_file=./${var.ssh-private-key-name}
${join("\n", formatlist("%s ansible_host=%s ansible_user=root ansible_ssh_private_key_file=./${var.ssh-private-key-name}", digitalocean_droplet.worker-nodes.*.name, digitalocean_droplet.worker-nodes.*.ipv4_address))}

[hpc_master]
${var.name}-master

[hpc_worker]
${join("\n", formatlist("%s", digitalocean_droplet.worker-nodes.*.name))}
EOT

  filename = "inventory"
}

resource "local_file" "ssh_private_key" {
  content         = tls_private_key.main.private_key_pem
  filename        = var.ssh-private-key-name
  file_permission = "0600"
}

resource "local_file" "ssh_public_key" {
  content         = tls_private_key.main.public_key_pem
  filename        = "${var.ssh-private-key-name}.pub"
  file_permission = "0600"
}
