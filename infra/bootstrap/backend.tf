terraform {
  # Supply non-secret settings through the verified external .tfbackend.json.
  # Keep credentials, state, and backend metadata outside the checkout.
  backend "s3" {}
}
