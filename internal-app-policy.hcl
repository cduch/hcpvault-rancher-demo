# Enable and manage the key/value secrets engine at `secret/` path
path "secret/*"
{
  capabilities = ["read"]
}
