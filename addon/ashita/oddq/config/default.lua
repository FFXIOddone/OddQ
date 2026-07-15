local config = {}

-- ODD_CXI_CONFIG_START
-- ODD_CXI_REQUIRED:
-- Replace these values when CatseyeXI hosts OddQ.
config.server_name = "ODD_CXI_REPLACE_SERVER_NAME"
config.api_base_url = "ODD_CXI_REPLACE_API_BASE_URL"
config.route_endpoint = "ODD_CXI_REPLACE_ROUTE_ENDPOINT"
config.manifest_endpoint = "ODD_CXI_REPLACE_MANIFEST_ENDPOINT"
config.allowed_hostnames = { "ODD_CXI_REPLACE_ALLOWED_HOSTNAMES" }
config.public_signing_key = "ODD_CXI_REPLACE_PUBLIC_SIGNING_KEY"
config.enable_path_ingest = false
config.enable_auto_update_check = false
-- ODD_CXI_CONFIG_END

config.cache_path = "config/addons/oddq/cache/last_route.json"
config.sample_route_path = "addons/oddq/cache/sample_route.json"
config.bridge_base_url = "http://127.0.0.1:17776"

return config
