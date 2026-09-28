# Fink profile: enable with `./deploy.sh -p fink` (links it as profile.auto.tfvars).
# Site-specific values (cluster size, server IPs) stay in terraform.tfvars.

# Dedicated pool for the memory-heavy Spark job raw2science
bigworker_count       = 1
bigworker_flavor_name = "fink.m2.xlarge.1"
bigworker_node_labels = {
  "fink.io/pool" = "raw2science"
}
bigworker_taint = "dedicated=raw2science:NoSchedule"

# Fink writes to the production HDFS cluster of the project, outside
# Kubernetes. The servers to open are listed in terraform.tfvars:
#   external_access_targets = { hdfs-from-k8s = ["<namenode IP>", "<datanode IP>", ...] }
router_name = "fink-router"
external_access = {
  hdfs-from-k8s = {
    description = "HDFS NameNode RPC (8020) and DataNode transfer (9866) from the Kubernetes cluster egress"
    ports       = [8020, 9866]
  }
}
