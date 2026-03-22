# AGENTS.md

## Project Purpose

Construct and maintain a reproducible data pipeline to assemble, clean, visualize, describe, and do inference on Ad Hoc Farm Payments made accessible through a FOIA request.

## Working Directory
- 0_inputs contains a .txt file to a Box folder that you should be able to access, as does 2_processed_data
- 1_code contains all of the code you should edit. Update the readme habitually to reflect the changes we make during design and plan execution.
- 3_outputs contains outputs that will be used in Latex files, PowerPoint presentations and working papers. So 3_outputs should contain all tables, visualizations/illustrations, and associated regression outputs.

## Environment
- We will primarily use R to explore, transform, visualize and analyze data.
- Do not introduce Python or other languages unless explicitly requested.
- Avoid network calls unless accessing the filepath stated in 0_inputs or writing to 2_processed_data; assume required data are already present locally unless told otherwise. Do not implement other network calls without explicit permission.

## Pathing Rules
- Do not hardcode user-specific paths unless asked. All code should use a relative pathing regime.

## Outputs
- Document every output file written by scripts, including ad hoc outputs.
- Default to non-destructive updates; do not overwrite existing outputs unless explicitly instructed.

## Documentation
- Keep README detailed and internally focused.
- Document legacy code in `1_code/legacy` in a separate README section.
- If adding new scripts, update the README with purpose, inputs, outputs, and dependencies.
- the agent-docs folder contains guidance on how to update the README.

## Safety
- Never run destructive git commands unless explicitly asked.
- If unexpected changes or ambiguities appear, stop and ask before proceeding.

## Communication
- Be concise and explicit about assumptions.
- Ask before writing outside the repository or making any network calls.

## Task-Specific Docs
- Task-specific routines and planning documents are contained in `agent-docs`.

./agent-docs/PLANS.md - Use this as a template in the planning phase.

./agent-docs/execplans/. - Use this subfolder to store plans we have finalized as a .md file. During the planning phase, I'll iterate on these files with you, which will then be used to execute workplans.

## README Governance and Automation Rules

Codex is authorized to update the README **only** within the boundaries defined below.  
Codex is not authorized to reinterpret project goals, redefine scope, or infer intent beyond explicit instructions.
Codex should update the README after each execplan is marked close, and confirm changes to the README when an execplan is completed. When the README is to be updated, please follow the instruction set provided in /agent-docs/README_update_instructset.md.

## Reasoning & Scope Control
- Optimize for correctness, transparency and reproducibility over elegance.
- When writing code, comment the code as if you are teaching an economics graduate student about each step of the coding process. The goal of comments should be to ensure reproducibility and auditability to an audience that is technically capable, but one step removed from the coding process. 
- While the use of helper functions are permitted, helper functions should not be used in the code pipeline without commenting the purpose of the helper and citing its origin (ƒrom which file did the helper originate?)
- Do not introduce new estimators, identification strategies, variable constructions, or sample definitions unless explicitly requested.
- If sample restrictions are introduced in the reduced form or descriptives, explicit comment should be made of such restriction. Do not drop data from descriptive or estimation procedures without explicitly noting as such either in the file preamble or code comment.
- Never infer research intent from file names, directory structure, or reference documents.
