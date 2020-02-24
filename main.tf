// Init:
//
// $ terraform init
//
// Apply changes:
//
// $ terraform apply

data "external" "token" {
  program = ["/bin/bash", "-c", "yc config get token | jq -Rn '{token: input}'"]
}

variable "cloud_id" {
  default = "b1g4aa5s77qtes5u9nq4"
}

variable "folder_id" {
  default = "b1ggv9ktngb0t3k1udn1"
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  token     = data.external.token.result.token
}

resource "yandex_vpc_network" "default" {
  name = "default"
}

resource "yandex_vpc_subnet" "subnet-c" {
  v4_cidr_blocks = ["10.130.0.0/24"]
  zone           = "ru-central1-c"
  network_id     = yandex_vpc_network.default.id
}

resource "yandex_iam_service_account" "common" {
  name = "squad-common-sa"
}

resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  folder_id = var.folder_id

  role = "editor"

  members = [
    "serviceAccount:${yandex_iam_service_account.common.id}",
  ]
}

data "yandex_compute_image" "ubuntu-latest" {
  family = "ubuntu-1804-lts"
}

resource "yandex_compute_instance_group" "squad-group" {
  name               = "squad-group"
  service_account_id = yandex_iam_service_account.common.id

  instance_template {
    platform_id = "standard-v2"
    resources {
      memory = 4
      cores  = 2
    }
    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = data.yandex_compute_image.ubuntu-latest.id
        size     = 30
      }
    }
    network_interface {
      network_id = yandex_vpc_network.default.id
      nat        = true
      subnet_ids = [
        yandex_vpc_subnet.subnet-c.id,
      ]
    }
    scheduling_policy {
      preemptible = true
    }
    metadata = {
      user-data = "${file("cloud-config.yaml")}"
    }
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
  }

  scale_policy {
    fixed_scale {
      size = 1
    }
  }

  allocation_policy {
    zones = ["ru-central1-c"]
  }
}
