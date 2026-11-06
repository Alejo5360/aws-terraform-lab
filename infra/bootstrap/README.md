# Backend bootstrap scaffold

This root will manage the S3 state backend in us-east-2. It currently defines only version requirements, provider configuration, and local inputs. **It contains no resources, data sources, or backend configuration.**

Use only the preparation commands in [the local-development guide](../../docs/local-development.md). In this milestone, initialization must use `-backend=false`, followed by `validate`.

Before adding the first bootstrap resource, explicitly configure a local backend with an absolute protected state path outside the checkout. Never rely on Terraform's implicit local-state default. Once the bucket exists, migrate bootstrap state to a dedicated remote key. The dev workload must use a different key. That implementation and migration are a later milestone.

Do not run a plan or apply against this scaffold. A passing validate checks configuration structure; it does not create a bucket or verify AWS authorization. Final backend cleanup must be separate from normal workload teardown.
