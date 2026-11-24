output "instance_connection_name" {
  description = "Use this (not the IP) for the Auth Proxy and Cloud Run connections."
  value       = google_sql_database_instance.this.connection_name
}

output "private_ip" {
  value = google_sql_database_instance.this.private_ip_address
}

output "network_id" {
  value = google_compute_network.this.id
}
