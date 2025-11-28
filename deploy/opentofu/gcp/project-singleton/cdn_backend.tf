resource "google_compute_backend_bucket" "cdn_backend" {
  count       = var.enable_cdn ? 1 : 0
  project     = var.project_id
  name        = "${var.project_suffix}-cdn-backend"
  bucket_name = "${var.project_suffix}-cdn-bucket"
  enable_cdn  = true

  cdn_policy {
    cache_mode        = "CACHE_ALL_STATIC"
    default_ttl       = 3600
    client_ttl        = 7200
    max_ttl           = 86400
    negative_caching  = true
    serve_while_stale = 86400
  }
}
