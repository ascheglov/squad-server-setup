// Init:
//
// $ terraform init -backend-config="secret_key=$(...)"
//
// Apply changes:
//
// $ YC_TOKEN=$(yc config get token) terraform apply

variable "cloud_id" {
  default = "b1g4aa5s77qtes5u9nq4"
}

variable "folder_id" {
  default = "b1ggv9ktngb0t3k1udn1"
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
}

resource "yandex_vpc_network" "default" {
  name = "default"
}

resource "yandex_vpc_subnet" "subnet-c" {
  v4_cidr_blocks = ["10.130.0.0/24"]
  zone           = "ru-central1-c"
  network_id     = yandex_vpc_network.default.id
}

resource "yandex_iam_service_account" "squad-ig-sa" {
  name = "squad-ig-sa"
}

data "yandex_compute_image" "ubuntu-latest" {
  family = "ubuntu-1804-lts"
}

resource "yandex_compute_instance_group" "squad-group" {
  name               = "squad-group"
  description        = "Squad servers"
  service_account_id = yandex_iam_service_account.squad-ig-sa.id

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
