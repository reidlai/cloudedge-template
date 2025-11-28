data "terraform_remote_state" "singleton" {
  backend = "gcs"
  config = {
    bucket = "vibetics-cloudedge-nonprod-tfstate"
    prefix = "vibetics-cloudedge-nonprod-singleton"
  }
}
