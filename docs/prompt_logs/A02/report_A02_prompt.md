
# Phase 1: Planning

## 1. User Prompt

> # Mode: PLAN
>
> You are my Senior Data Architect and Platform Engineer mentor.
>
> I’m sharing a description of an AWS MWAA (Airflow) + Dask hybrid architecture for periodic, parallel data processing pipelines.
> Please break it down step-by-step, explaining how it works, its limitations, and key design decisions.

---

## 2. User Prompt

> Take the AWS MWAA + Dask architecture we just discussed and redesign it using GCP services instead of AWS.

---

## 3. User Prompt

> Here’s a GCP blog on scalable Python data processing using Dask:
> [https://cloud.google.com/blog/products/data-analytics/improve-data-science-experience-using-scalable-python-data-processing](https://cloud.google.com/blog/products/data-analytics/improve-data-science-experience-using-scalable-python-data-processing)
> Show me how to integrate the approach in the blog into the GCP architecture you proposed.

---

## 4. User Prompt

> Here’s the full documentation for my current A01 GCP data platform.
> Review it and suggest how Dask could be integrated.

---

## 5. User Prompt

> Given the current A01 platform, explain exactly how Dask can be integrated without breaking the existing environment.

---

## 6. User Prompt

> In the MWAA + Dask example from earlier, was Dataproc used, or is it running entirely on AWS services?

---

## 7. User Prompt

> Here’s the A01 platform specification again.
> Propose how to add a Dask cluster to this environment, step-by-step.

---

## 8. User Prompt

> I’ve chosen Option B: Dask on Dataproc.
> Write a detailed LLM prompt that includes my current A01 context, the integration goals, constraints, and expected outputs.

---

## 9. User Prompt

> Based on Option B (Dask on Dataproc), describe the end-to-end expected workflow for running a distributed job in my environment.

---

## 10. User Prompt

> Design the workflow for how developers will submit and run Dask jobs in this setup.
> Consider GitLab (or similar) integration to sync code into Composer/DAGs and package for Dataproc execution.

---