# Fink profile for IJCLab: enable with `./deploy.sh -p fink-ijclab`.
# Same big worker as profiles/fink.tfvars, with an IJCLab flavor.
# TODO: access to the external HDFS and Kafka of IJCLab (external_access).

# Dedicated pool for the memory-heavy Spark job raw2science
bigworker_count       = 1
bigworker_flavor_name = "os.16" # 16 vCPU, 32 GB, as fink.m2.xlarge.1 at CC-IN2P3
bigworker_node_labels = {
  "fink.io/pool" = "raw2science"
}
bigworker_taint = "dedicated=raw2science:NoSchedule"
