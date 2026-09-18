<div align="center">

# Reproducing the TerraFormer Study

**A Practical, Beginner Friendly Playbook**

*Reference paper: Jana, Davidson, Bhasker, Kan, Deoras and Callot, ICSE SEIP 2026*

![Terraform](https://img.shields.io/badge/Terraform-1.12.0-7B42BC?logo=terraform&logoColor=white)
![OPA](https://img.shields.io/badge/Open%20Policy%20Agent-Rego-4D4D4D?logo=openpolicyagent&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)
![Model](https://img.shields.io/badge/Base%20model-Qwen2.5%20Coder-FF6F00)
![Platform](https://img.shields.io/badge/Platform-Linux-FCC624?logo=linux&logoColor=black)

</div>

---

## Table of Contents

1. [What this document is for](#1-what-this-document-is-for)
2. [What the paper does, in plain language](#2-what-the-paper-does-in-plain-language)
   - [2.1 The three checkers you must understand](#21-the-three-checkers-you-must-understand)
   - [2.2 The two tasks](#22-the-two-tasks)
3. [Reproducibility assessment: read this before spending money](#3-reproducibility-assessment-read-this-before-spending-money)
   - [3.1 The resource gap](#31-the-resource-gap)
   - [3.2 What a defensible scaled reproduction looks like](#32-what-a-defensible-scaled-reproduction-looks-like)
4. [Phase A. Setting up the machine](#4-phase-a-setting-up-the-machine)
   - [4.1 Install the base tools](#41-install-the-base-tools)
   - [4.2 Install Terraform version 1.12.0](#42-install-terraform-version-1120)
   - [4.3 Install Open Policy Agent, TFLint and Checkov](#43-install-open-policy-agent-tflint-and-checkov)
   - [4.4 Install the Python machine learning stack](#44-install-the-python-machine-learning-stack)
   - [4.5 A first sanity check](#45-a-first-sanity-check)
5. [Phase B. Rebuilding the three verification oracles](#5-phase-b-rebuilding-the-three-verification-oracles)
   - [5.1 Oracles one and two](#51-oracles-one-and-two)
   - [5.2 Credentials and the plan command](#52-credentials-and-the-plan-command)
   - [5.3 Oracle three, the policy checker](#53-oracle-three-the-policy-checker)
   - [5.4 What you should have at the end of Phase B](#54-what-you-should-have-at-the-end-of-phase-b)
6. [Phase C. Rebuilding a dataset](#6-phase-c-rebuilding-a-dataset)
   - [6.1 Get the raw material](#61-get-the-raw-material)
   - [6.2 Filter](#62-filter)
   - [6.3 The multi turn repair loop](#63-the-multi-turn-repair-loop)
   - [6.4 Generate the prompts and the policies](#64-generate-the-prompts-and-the-policies)
   - [6.5 Build the two task datasets](#65-build-the-two-task-datasets)
   - [6.6 Splitting train and test without cheating](#66-splitting-train-and-test-without-cheating)
   - [6.7 Budget warning](#67-budget-warning)
7. [Phase D. Reproducing the baseline evaluation](#7-phase-d-reproducing-the-baseline-evaluation)
   - [7.1 Get the public benchmark](#71-get-the-public-benchmark)
   - [7.2 Pick your models](#72-pick-your-models)
   - [7.3 Run inference](#73-run-inference)
   - [7.4 Score it](#74-score-it)
   - [7.5 The comparison you should expect](#75-the-comparison-you-should-expect)
8. [Phase E. Fine tuning](#8-phase-e-fine-tuning)
   - [8.1 Stage one, supervised fine tuning](#81-stage-one-supervised-fine-tuning)
   - [8.2 Stage two, reinforcement learning with verifier feedback](#82-stage-two-reinforcement-learning-with-verifier-feedback)
   - [8.3 The practical warning](#83-the-practical-warning)
9. [Phase F. Quality assessment and reporting](#9-phase-f-quality-assessment-and-reporting)
   - [9.1 How to report your reproduction](#91-how-to-report-your-reproduction)
10. [Schedule](#10-schedule)
11. [Glossary](#11-glossary)
12. [Things that will go wrong, and what they mean](#12-things-that-will-go-wrong-and-what-they-mean)

### Progress overview

| Phase | Topic |
| :---: | --- |
| A | [Setting up the machine](#4-phase-a-setting-up-the-machine) |
| B | [Verification oracles](#5-phase-b-rebuilding-the-three-verification-oracles) |
| C | [Dataset rebuild](#6-phase-c-rebuilding-a-dataset) |
| D | [Baseline evaluation](#7-phase-d-reproducing-the-baseline-evaluation) |
| E | [Fine tuning](#8-phase-e-fine-tuning) |
| F | [Quality assessment and reporting](#9-phase-f-quality-assessment-and-reporting) |

---

## 1. What this document is for

This playbook explains, in plain language, how to rebuild the experiments described in the TerraFormer paper. It assumes you have never installed Terraform, never fine tuned a language model, and never run a policy engine. Every step says what to type, what should happen, and what to do when it does not happen.

Read [section 2](#2-what-the-paper-does-in-plain-language) first. It explains what the paper actually did. [Sections 4](#4-phase-a-setting-up-the-machine) to [9](#9-phase-f-quality-assessment-and-reporting) are the hands on part, in the order you should do them. [Section 11](#11-glossary) is a glossary. If a word looks unfamiliar, it is probably defined there.

> [!WARNING]
> **The full paper cannot be reproduced exactly.** The authors spent roughly fifteen thousand US dollars on commercial model calls and used eight A100 GPUs with eighty gigabytes of memory each. They also did not publish their two datasets.
>
> [Section 3](#3-reproducibility-assessment-read-this-before-spending-money) explains what is reproducible, what is not, and what an honest scaled down reproduction looks like. **That scaled down version is the realistic target.**

<p align="right"><a href="#table-of-contents">↑ Back to contents</a></p>

---

## 2. What the paper does, in plain language

Infrastructure as Code, usually shortened to **IaC**, means describing cloud servers, storage and networks in a text file instead of clicking buttons in a web console. **Terraform** is the most popular tool for this. Its language is called **HCL**.

Writing Terraform by hand is slow and error prone, so the obvious idea is to let a language model write it. The problem is that models frequently invent resource names and attributes that do not exist. **The paper attacks this in four moves:**

1. **Build three automatic checkers, called verification oracles.**
   - The first checks that the file is **syntactically valid**.
   - The second checks that it could **plausibly be deployed**.
   - The third checks that it **actually does what the user asked for**.
2. **Curate a clean dataset.** Take a large pile of real, messy Terraform files from GitHub and run them through the three checkers. When a file fails, ask a strong commercial model to repair it using the error message. Repeat up to five times and keep whatever survives.
3. **Generate prompts and policies.** For each clean file, ask a model to write the natural language request that would have produced it, plus a machine readable policy that acts as a unit test for that request.
4. **Train small open models.** Use that dataset to train two small open models, first by imitation and then by reinforcement learning, where the reward comes from the three checkers rather than from text similarity.

The result, called **TerraFormer**, is a fourteen billion parameter model that beats much larger models such as Claude Sonnet 3.7 and GPT 4.1 on the authors' own test sets.

### 2.1 The three checkers you must understand

| Name | Command | What it answers |
| :---: | --- | --- |
| **FV i** | `terraform validate` | Is the syntax correct, and are all references and required fields declared? |
| **FV ii** | `terraform plan` | Could this actually be deployed? Terraform builds a dependency graph and checks provider compatibility and resource dependencies. Nothing is created in the cloud. |
| **FV iii** | `opa eval` | Does the configuration satisfy a policy written in Rego, which encodes what the user asked for? This is the closest thing to a unit test for infrastructure. |

These three form a ladder:

```text
Correctness (FV iii)  ──requires──▶  Deployability (FV ii)  ──requires──▶  Compilability (FV i)
```

- A file **can** pass the first and fail the second.
- A file **can never** pass the third while failing the first.

### 2.2 The two tasks

| Task | Input | Output |
| --- | --- | --- |
| **IaC generation** | A natural language prompt. | A Terraform file written from scratch. |
| **IaC mutation** | An existing Terraform file plus a prompt asking for a change. | The modified file. The paper claims this is the first dataset for this task. |

<p align="right"><a href="#table-of-contents">↑ Back to contents</a></p>

---

## 3. Reproducibility assessment: read this before spending money

A reproduction study is only credible if you are explicit about what you could and could not obtain. The table below is the honest starting position.

| Artefact from the paper | Available | Consequence for you |
| --- | :---: | --- |
| TF Gen dataset, 152,475 instances | ❌ No | Must be rebuilt with your own pipeline. Yours will differ. |
| TF Mutn dataset, 52,516 instances | ❌ No | Same. No baseline to compare your rebuild against. |
| IaC Eval benchmark, 458 instances | ✅ Yes | This is the anchor. Public, human curated, and used in the paper. **Start here.** |
| TerraDS seed corpus | ✅ Yes | Published at MSR 2025 by Buehler and colleagues. **This is the raw material for the pipeline.** |
| Qwen2.5 Coder 3B and 14B base models | ✅ Yes | Open weights. Downloadable. |
| Terraform, OPA, TFLint, Checkov | ✅ Yes | All free and open source. |
| Training and evaluation code | ❌ On request (**No**) | Appendix A says the codebase can be shared on request. Ask for it; this single email may save you months.<br>**O pedido foi feito, mas recusaram-se a atendê-lo.** |
| Identity of the curation model | ❌ No | The paper says only "a leading commercial scale LLM". You must choose one and say which. |
| Full prompt templates | ⚠️ Partial | Appendix B gives the structure, but the few shot examples are placeholders. |

### 3.1 The resource gap

The authors used eight NVIDIA A100 GPUs with eighty gigabytes each for training, and eight A100 cards with forty gigabytes for inference. Dataset curation cost about fifteen thousand US dollars in commercial model tokens.

If you do not have this, and almost no single researcher/student does, you do not abandon the reproduction. **You scale it and you document the scaling.**

### 3.2 What a defensible scaled reproduction looks like

1. **Rebuild the three verification oracles exactly.** This part is free and it is the scientific core of the paper.
2. **Reproduce the baseline evaluation table** for the models you can actually run, on IaC Eval, which is public. This alone is a publishable partial replication.
3. **Rebuild the curation pipeline** but run it on a sample of a few thousand configurations rather than 279,410. Report the sample size honestly.
4. **Fine tune only the three billion parameter model.** The fourteen billion model needs quantization and LoRA and much more memory.
5. **State clearly** which numbers you reproduced, which you approximated, and which you could not attempt.

> [!IMPORTANT]
> A reproduction that honestly reports a partial result is a scientific contribution. A reproduction that quietly changes the setup and claims full agreement is not.

<p align="right"><a href="#table-of-contents">↑ Back to contents</a></p>

---

## 4. Phase A. Setting up the machine


Everything here runs on Linux. If your machine runs Windows, install the Windows Subsystem for Linux (WSL) first and do all the work inside it. On macOS most commands work with Homebrew instead of `apt`.

### 4.1 Install the base tools

Open a terminal and run the following. Each line is one command. Press Enter after each and wait for it to finish.

```bash
sudo apt update
sudo apt install -y git curl unzip build-essential python3.12 python3.12-venv
```

### 4.2 Install Terraform version 1.12.0

> [!IMPORTANT]
> The version matters. The paper used exactly **1.12.0**, and Terraform changes behaviour between versions, so a different version can silently change your results.

```bash
curl -LO https://releases.hashicorp.com/terraform/1.12.0/terraform_1.12.0_linux_amd64.zip
unzip terraform_1.12.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform version
```

The last command should print `Terraform v1.12.0`. If it prints anything else, you have another Terraform earlier in your `PATH`.

### 4.3 Install Open Policy Agent, TFLint and Checkov

```bash
# Open Policy Agent
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64_static
chmod 755 opa && sudo mv opa /usr/local/bin/

# TFLint
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Python virtual environment
Python virtual environment
python3.12 -m venv ~/tfenv
source ~/tfenv/bin/activate

# Checkov
pip install checkov
```

Check each tool by running:

```bash
opa version
tflint --version
checkov --version
```

All three must answer.

### 4.4 Install the Python machine learning stack

Stay inside the virtual environment you just activated.

> [!TIP]
> You must reactivate the environment every time you open a new terminal, with `source ~/tfenv/bin/activate`.

```bash
pip install torch transformers datasets accelerate peft trl bitsandbytes
pip install python-Levenshtein pandas matplotlib
```

### 4.5 A first sanity check

Create a folder, put one tiny Terraform file in it, and run the first two checkers. This proves your environment works before you build anything on top of it.

```bash
mkdir -p ~/tf-test && cd ~/tf-test

cat > main.tf <<'EOF'
terraform {
  required_version = "~> 1.12.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "us-east-1" }

resource "aws_s3_bucket" "demo" { bucket = "my-demo-bucket-12345" }
EOF
```

Then run the three commands below, in order.

```bash
terraform init
terraform validate
terraform plan -out tfplan
```

| Command | What it does |
| --- | --- |
| `terraform init` | Downloads the AWS provider plugin, so you need an internet connection the first time. If you ever set or change modules or backend configuration, rerun this command to reinitialize your working directory. If you forget, other commands will detect it and remind you. |
| `terraform validate` | Should say the configuration is valid. |
| `terraform plan -out tfplan` | - `terraform plan` It calculates what will be created, changed, or destroyed. __   - `-out tfplan` Save this plan in a file called `tfplan`. Then, apply exactly that plan with `terraform apply tfplan`. |

> [!NOTE]
> `terraform plan` may complain that no credentials are configured. [Section 5.2](#52-credentials-and-the-plan-command) explains how to handle that.

<p align="right"><a href="#table-of-contents">↑ Back to contents</a></p>

---

## 5. Phase B. Rebuilding the three verification oracles

> [!IMPORTANT]
> **This is the heart of the paper and the part you can reproduce faithfully.**

Build it as a small Python module with **one function per oracle**, each returning a **pass or fail flag** and **the error text**. The paper calls that error text an **error certificate**, and it is used twice:

- once to **repair files**;
- once to **compute rewards**.

### 5.1 Oracles one and two

Both are Terraform commands run inside a temporary folder. The pattern is always the same:

1. **Write the configuration** to a folder.
2. **Run `terraform init`** without a backend.
3. **Run the command** (`validate` or `plan`).
4. **Capture** the exit code and the standard error stream.

```bash
terraform init -backend=false -input=false
terraform validate -no-color
terraform plan -input=false -no-color -out tfplan
```

> [!NOTE]
> **Sobre `-backend=false`:** desativa a configuração do backend, pois o objetivo é apenas testar o código (bom para CI/CD).

An exit code of **zero means pass**. Anything else means fail, and the text you captured is the error certificate.

> [!WARNING]
> **Always pass `-input=false`.** Without it, Terraform waits forever for a human to type a value for an undeclared variable, and your pipeline will appear to hang. The paper hit exactly this problem and instructed its repair model to insert plausible default values.

### 5.2 Credentials and the plan command

`terraform plan` normally wants **cloud credentials**. You are not deploying anything, so you have **two clean options**:

- **Option A:** set fake environment variables and a fixed region;
- **Option B:** configure the AWS provider block to skip credential validation.

The paper reports that its repair model was told to remove `assume_role` blocks and custom profiles precisely because they cause permission errors.

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
```

> [!TIP]
> **Add a timeout of about thirty seconds around every `plan` call.** Some configurations hang on network lookups. The paper used the same threshold.

### 5.3 Oracle three, the policy checker

This is the least familiar piece. Terraform can export its plan as a machine readable structure. A **Rego** policy then inspects that structure and answers yes or no. Rego is the language of Open Policy Agent.

```bash
terraform show -json tfplan > plan.json
```

A minimal policy that checks whether the plan creates an **S3** bucket looks like this. Save it as `policy.rego`.

```rego
package terraform.policy

default allow = false

allow {
  some i
  input.resource_changes[i].type == "aws_s3_bucket"
}
```

Then evaluate it:

```bash
opa eval --format pretty --data policy.rego --input plan.json "data.terraform.policy.allow"
```

Real policies in the paper contain many rules, one per element mentioned in the prompt, with names such as `is_valid_vpc` and `is_valid_subnet`. That structure matters, because the reward function counts **how many individual rules passed** rather than treating the policy as a single yes or no.

> [!TIP]
> Design your policies as a set of named rules from the beginning.

### 5.4 What you should have at the end of Phase B

- [ ] A Python function that takes Terraform source text and returns **compilable** true or false, plus the error text.
- [ ] A second function that returns **deployable** true or false, plus the error text and the plan as structured data.
- [ ] A third function that takes a plan and a Rego policy and returns the **number of rules passed** and the **total number of rules**.
- [ ] A short test suite with about ten files you already know should pass or fail.

<p align="right"><a href="#table-of-contents">↑ Back to contents</a></p>

---

## 6. Phase C. Rebuilding a dataset

The two datasets in the paper are not published, so you rebuild a smaller equivalent. The recipe mirrors Figure 3 of the paper.

### 6.1 Get the raw material

Start from **TerraDS**, published at the Mining Software Repositories conference (MSR) in 2025 by Buehler, Spielmann, Meier and Salvaneschi. It contains Terraform files from **62,406 GitHub repositories** under permissive licences.

Because HCL is declarative, the paper concatenates every file ending in `.tf` inside one module folder into a single configuration.

### 6.2 Filter

Keep only configurations that use the **AWS provider** plus the utility providers the paper allowed:

`random` · `null` · `local` · `template` · `tls` · `time` · `external` · `http` · `archive` · `docker` · `terraform`

In the paper this cut the corpus to roughly **forty two percent** of its original size. Then remove exact duplicates.

### 6.3 The multi turn repair loop

This is the single most important mechanism in the paper, and it is simple:

```text
for each configuration:
    run the checker
    if it passes → keep it
    else, up to 5 times:
        send configuration + error certificate to the LLM
        ask it to explain the error, describe the fix, and return a corrected configuration
        run the checker again on the answer
        if it passes → keep it and stop
    if it still fails → discard it
```

Appendix B of the paper gives the full prompt template for this loop. Copy its structure. The important instructions in it are that the model:

- may change anything, including whole blocks;
- must target **Terraform 1.12.0**;
- must add **default values for variables**, so that execution is non interactive;
- must return the answer **between explicit tags**, so that you can extract it reliably.

Run this loop **first for syntax, then for deployability**. In the paper, the syntax stage recovered **58%** of failing files and the deployability stage recovered about **59%**.

### 6.4 Generate the prompts and the policies

For every surviving configuration, ask a model to write the natural language request that would produce it. The paper instructs the model to:

- start with a directive verb such as *Generate*, *Set up* or *Deploy*;
- describe **what** to provision rather than **how**.

It generates three levels of abstraction and uses the middle one. A second model acts as a **judge**, compares the prompt back to the code, and the prompt is revised until the judge is satisfied.

Then ask a model to write a **Rego policy** that encodes the intent of that prompt, and validate it with oracle three. In the paper this succeeded for about **71%** of cases.

### 6.5 Build the two task datasets

| Dataset | Procedure | Keep the instance only if |
| --- | --- | --- |
| **Generation** | Ask the model to write a second, different implementation of the same infrastructure. This teaches the model that many valid solutions exist. | It is deployable, satisfies the same policy, and differs from the original. |
| **Mutation** | Ask the model to modify the configuration, produce an updated policy, and write a prompt describing the change. | The new file is deployable, satisfies the new policy, and the new policy differs from the old one. |

### 6.6 Splitting train and test without cheating

The paper puts an instance in the test set **only if it traces back to a GitHub repository containing exactly one module**. This prevents two variants of the same infrastructure from landing on both sides of the split.

> [!TIP]
> Copy this rule. It is a cheap safeguard against a serious form of data leakage.

### 6.7 Budget warning

> [!CAUTION]
> Every step above calls a commercial model many times.

The paper reports about **US$ 15,000 for 200,000 instances** at Bedrock pricing:

| Token type | Price per thousand tokens |
| --- | --- |
| Input | US$ 0.003 |
| Output | US$ 0.015 |

Scale linearly: **two thousand instances is roughly US$ 150**. Decide your sample size from your budget, not the other way round, and consider using a strong open model locally for the repair loop instead.

<p align="right"><a href="#table-of-contents">↑ Back to contents</a></p>

---

## 7. Phase D. Reproducing the baseline evaluation

This phase produces your first real table and it needs **no training at all**. It is the fastest route to a result you can show.

### 7.1 Get the public benchmark

Download **IaC Eval**, from Kon and colleagues, published at NeurIPS 2024. It has **458 human curated AWS examples** and is, according to the paper, the only public benchmark for this task. Because it is public, your numbers on it are directly comparable to Table 2 of the paper.

### 7.2 Pick your models

Choose models you can actually run. A single consumer graphics card with 24 GB handles models up to about eight billion parameters when quantized.

> [!TIP]
> Start with **Qwen2.5 Coder 3B**, because it is the base model of the small TerraFormer variant and gives you the exact comparison point the paper reports.

### 7.3 Run inference

For each benchmark instance, send the prompt to the model with **three in context examples**, exactly as in Appendix B, and extract the configuration from between the tags. Allow **one attempt per instance**. This is the strict **pass@1** protocol used throughout the paper.

### 7.4 Score it

Run every generated file through your five metrics.

| Metric | How it is computed |
| --- | --- |
| **Compilability** | Percentage of files where `terraform validate` exits with zero. |
| **Deployability** | Percentage where `terraform plan` exits with zero. |
| **Correctness** | Percentage where the plan satisfies the reference policy. The strictest of the three. |
| **Linter pass rate** | Percentage where TFLint reports no findings. |
| **Security compliance** | Average, across instances, of the percentage of Checkov checks passed. |

### 7.5 The comparison you should expect

For reference, the paper reports the following correctness on IaC Eval:

| Model | Correctness |
| --- | :---: |
| Qwen2.5 Coder 3B | 6.55% |
| Claude Sonnet 3.7 | 35.37% |

If your numbers for the same model land within a few points, your harness is probably correct.

> [!WARNING]
> If they are wildly different, the problem is almost certainly in your **prompt** or your **extraction of the code** from the model output, not in the model.

<p align="right"><a href="#table-of-contents">↑ Back to contents</a></p>

---

## 8. Phase E. Fine tuning

> [!IMPORTANT]
> Only attempt this once [Phase B](#5-phase-b-rebuilding-the-three-verification-oracles) and [Phase D](#7-phase-d-reproducing-the-baseline-evaluation) work end to end. Fine tuning without a working evaluation harness gives you a model you cannot measure.

### 8.1 Stage one, supervised fine tuning

This is imitation learning. You show the model a prompt and the correct Terraform file and train it to produce that file token by token. The loss is **cross entropy**. Use the `SFTTrainer` class from the `trl` library.

| Setting in the paper | Value |
| --- | --- |
| Base model | Qwen2.5 Coder 3B or 14B |
| Precision, 3B | Full parameter fine tuning in `bfloat16` |
| Precision, 14B | 4 bit NF4 quantization with LoRA on all linear layers in attention and feed forward, rank 16 and alpha 16 |
| Learning rate | `5e-6` with cosine schedule and warmup ratio `0.05` |
| Distribution | DeepSpeed ZeRO stage 2 |

### 8.2 Stage two, reinforcement learning with verifier feedback

Here the model generates a configuration, your three oracles score it, and that score becomes the reward. The algorithm is **Group Relative Policy Optimization (GRPO)**, available as `GRPOTrainer` in `trl`. A **Kullback Leibler penalty** keeps the model from drifting too far from the supervised checkpoint.

The reward function is the key design choice, and it is worth stating exactly:

| Outcome of the generated file | Reward |
| --- | :---: |
| Does not compile | `0` |
| Compiles but cannot be deployed | `0.5` |
| Deployable | `1 + (fraction of policy rules passed)` |

So the reward runs from **0 to 2**, and the model receives partial credit for partially correct infrastructure instead of a single pass or fail signal.

The reinforcement learning stage uses a learning rate of `1e-6` with the same warmup ratio.

### 8.3 The practical warning

> [!WARNING]
> Each reward computation runs `terraform init`, `validate` and `plan`, plus an OPA evaluation. That is **seconds** of wall clock time per sample, not milliseconds.

Caching provider plugins locally and running the oracles in parallel worker processes is the difference between a training run that finishes in days and one that never finishes. **Plan for this before you start.**

<p align="right"><a href="#table-of-contents">↑ Back to contents</a></p>

---

## 9. Phase F. Quality assessment and reporting

The paper does not stop at accuracy numbers. Its Section 7 checks whether the dataset itself is any good. If you are reproducing the study, this part is easy to skip and expensive to omit, because it is where the claim of dataset quality actually rests.

- **Expert survey.** One hundred instances from each dataset are shown to people with cloud experience, who rate whether the policy captures the prompt and whether the code implements it, on a three point scale. Agreement between raters is measured with **Gwet's AC1 coefficient**, which behaves better than alternatives when almost all answers fall into one category.
- **Mutation complexity.** The edit distance between the original and the modified file is computed and correlated with human ratings. The paper derives these thresholds:

  | Complexity | Edit distance |
  | --- | --- |
  | Low | below 160 |
  | Medium | 160 to 1,200 |
  | High | above 1,200 |

- **Repair loop effectiveness.** Success and failure of the repair loop is plotted against the number of resources, the number of inter resource relations, and the number of lines. The paper finds that policy generation gets **easier** with complexity, while mutation generation gets **harder**.

> [!TIP]
> To recruit twenty cloud experts is very costly and seems unfeasible. So, you will not recruit twenty cloud experts. A defensible substitute is a smaller panel of three or four raters on a smaller sample, with the agreement coefficient reported and the reduced sample size stated as a limitation.

### 9.1 How to report your reproduction

Structure your write up around three columns:

| What the paper reported | What you obtained | What differed in your setup |
| --- | --- | --- |
| *…* | *…* | *…* |

Where a number differs, say whether the cause is a different dataset, a different curation model, a different hardware budget, or an unknown.

> [!CAUTION]
> Never present a number that came from a different setup as agreement.

<p align="right"><a href="#table-of-contents">↑ Back to contents</a></p>

---

## 10. Schedule

| Period | Focus | Deliverable |
| --- | --- | --- |
| Weeks 1 to 2 | Environment and oracles | Working checker module and its test suite |
| Weeks 3 to 4 | Baseline evaluation on IaC Eval | First reproduction table for two or three models |
| Weeks 5 to 7 | Curation pipeline on a sample | Small dataset with prompts and policies |
| Weeks 7 to 9 | Supervised fine tuning of the small model | Fine tuned checkpoint and its scores |
| Weeks 9 to 11 | Reinforcement learning stage | Second checkpoint and reward curves |
| Weeks 12 to 15 | Quality assessment and write up | Reproduction report with the three column comparison |

> [!NOTE]
> The order matters more than the durations. Each phase produces something presentable on its own, so a delay in a later phase never leaves you with nothing to report.

<p align="right"><a href="#table-of-contents">↑ Back to contents</a></p>

---

## 11. Glossary

| Term | Meaning |
| --- | --- |
| **IaC** | Infrastructure as Code. Describing cloud resources in text files instead of clicking in a console. |
| **Terraform** | The most widely used IaC tool. Made by HashiCorp. |
| **HCL** | HashiCorp Configuration Language. The language Terraform files are written in. |
| **Provider** | A plugin that lets Terraform talk to one platform, for example `aws` or `docker`. |
| **Resource** | One thing to be created, for example an `aws_s3_bucket`. |
| **Module** | A folder containing Terraform files that are used together. |
| **Plan** | A dry run. Terraform works out what it would create without creating anything. |
| **Oracle** | An automatic checker that gives a definite verdict on a piece of code. |
| **Error certificate** | The diagnostic text a failing checker produces. Used as feedback to a model. |
| **OPA** | Open Policy Agent. A tool that evaluates policies against structured data. |
| **Rego** | The language OPA policies are written in. |
| **Linter** | A tool that flags style and best practice problems. TFLint here. |
| **Checkov** | A scanner that looks for security misconfigurations. |
| **SFT** | Supervised fine tuning. Training a model to imitate correct examples. |
| **RL** | Reinforcement learning. Training a model using a reward rather than a target answer. |
| **GRPO** | Group Relative Policy Optimization. The reinforcement learning algorithm used in the paper. |
| **LoRA** | Low Rank Adaptation. A way to fine tune a large model by training a small number of extra parameters. |
| **Quantization** | Storing model weights with fewer bits so they fit in less memory. |
| **pass@1** | The model gets exactly one attempt per problem. The strictest scoring protocol. |
| **Data leakage** | When test data influences training, making results look better than they are. |

<p align="right"><a href="#table-of-contents">↑ Back to contents</a></p>

---

## 12. Things that will go wrong, and what they mean

| Symptom | Cause and fix |
| --- | --- |
| The pipeline hangs with no output | Terraform is waiting for a variable value. Add `-input=false` and a timeout. |
| `terraform init` fails | No internet access, or a provider version that no longer exists. Cache the provider plugins locally. |
| Every plan fails on credentials | Set the fake AWS environment variables described in [section 5.2](#52-credentials-and-the-plan-command). |
| The model returns prose instead of code | Your extraction is not finding the tags. Enforce the tag format in the prompt and reject answers without them. |
| Scores far below the paper for the same model | Almost always the prompt or the extraction, not the model. Inspect twenty raw outputs by hand before changing anything else. |
| Reinforcement learning is impossibly slow | The oracles dominate the runtime. Parallelise them and cache the provider directory. |
| Results change between runs | Model sampling is not deterministic. Fix the seed and the temperature and record both. |

<p align="right"><a href="#table-of-contents">↑ Back to contents</a></p>
