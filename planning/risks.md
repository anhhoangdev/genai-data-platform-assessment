# Risks

- Risk: Time constraints across A01/A02/B01
  - Impact: Medium; Mitigation: Prioritize A01 deliverables first
- Risk: GCP service limits or IAM complexity
  - Impact: Medium; Mitigation: Parameterized Terraform; least-privilege IAM
- Risk: Dask multi-user resource contention
  - Impact: Medium; Mitigation: Quotas; worker limits; monitoring
