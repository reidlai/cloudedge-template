output "lb_frontend_ip" {
  description = "The public IP address of the Global Load Balancer."
  value       = google_compute_global_address.lb_ip.address
}