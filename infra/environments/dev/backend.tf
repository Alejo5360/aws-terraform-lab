terraform {
  # Configure this partial backend only after bootstrap creates the bucket.
  # Credentials and actual backend configuration do not belong in Git.
  backend "s3" {}
}
