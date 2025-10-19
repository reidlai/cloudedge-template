# --- TLS Provider Configuration ---
# This module uses the native tls provider to generate a self-signed certificate
# declaratively, removing the need for external files or tools like openssl.

# First, generate a new private key
resource "tls_private_key" "self_signed" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Then, create a self-signed certificate using that key
resource "tls_self_signed_cert" "self_signed" {
  private_key_pem = tls_private_key.self_signed.private_key_pem

  subject {
    common_name  = "example.com"
    organization = "Vibetics"
  }

  validity_period_hours = 12 # Short-lived for testing purposes

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Finally, upload the generated certificate to Google Cloud
resource "google_compute_ssl_certificate" "self_signed" {
  project     = var.project_id
  name        = "${var.environment}-self-signed-cert"
  private_key = tls_private_key.self_signed.private_key_pem
  certificate = tls_self_signed_cert.self_signed.cert_pem

  lifecycle {
    create_before_destroy = true
  }
}
