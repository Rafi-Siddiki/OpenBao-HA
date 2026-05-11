ui = true
disable_mlock = true

api_addr     = "http://10.9.0.70:8200"
cluster_addr = "http://10.9.0.72:8201"

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable     = true
}

storage "raft" {
  path    = "/openbao/file"
  node_id = "bao2"

  retry_join {
    leader_api_addr = "http://10.9.0.71:8200"
  }

  retry_join {
    leader_api_addr = "http://10.9.0.73:8200"
  }

  performance_multiplier = 1
}
