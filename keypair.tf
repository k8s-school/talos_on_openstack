resource "openstack_compute_keypair_v2" "keypair" {
  name       = var.key_pair_name
  public_key = file(var.public_key_path)
}