output "self_link" {
  description = "The self_link of the created self-signed SSL certificate."
  value       = google_compute_ssl_certificate.self_signed.self_link
}
