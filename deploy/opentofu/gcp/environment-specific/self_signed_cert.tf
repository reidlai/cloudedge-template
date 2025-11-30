resource "tls_private_key" "self_signed_key" {
  count     = var.enable_self_signed_cert ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "self_signed_cert" {
  count             = var.enable_self_signed_cert ? 1 : 0
  private_key_pem   = tls_private_key.self_signed_key[0].private_key_pem
  is_ca_certificate = true

  subject {
    common_name  = "demo-web-app.vibetics.com"
    organization = "Test"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = ["demo-web-app.vibetics.com"]
}
