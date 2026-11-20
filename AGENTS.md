# Contributor and Agent Guidelines: SUSE Rancher Documentation

You are assisting contributors (technical writers, editors, engineers, and community members) working in the **SUSE Rancher Documentation** repository (`rancher-product-docs`).

All contributors and assisting agents must follow this unified standard combining the build and architectural conventions from [README.md](README.md) with the editorial guidelines from [product-docs-common/ai-prompts/Style-Guide-onefile.md](product-docs-common/ai-prompts/Style-Guide-onefile.md).

---

## 1. Prerequisites & Essential Commands

- **Setup & Dependencies**:
  ```bash
  git submodule update --init --recursive    # Required: fetches Antora UI, shared docs & nested submodules
  npm ci                                     # Installs Antora and build dependencies (or: make environment)
  ```
- **Local Builds**:
  - Rancher Prime (Product): `make product-local` (or `npx antora playbook-product-local.yml`)
  - Rancher Manager (Community): `make community-local` (or `npx antora playbook-community-local.yml`)
  - SUSE Rancher for AWS: `make srfa-local` (or `npx antora playbook-srfa-local.yml`)
- **Local Previews**:
  - `make preview-product-local` (serves `build/site-product-local` on port 8081)
  - `make preview-community-local` (serves `build/site-community-local` on port 8080)
  - `make preview-srfa-local` (serves `build/site-srfa-local` on port 8082)
- **Clean Build Directory**: `make clean`
- **Reference**: See [README.md](README.md) for remote playbooks, Node LTS requirements, and troubleshooting.

---

## 2. Repository Architecture & Single-Sourcing Invariants

Documentation is built with **Antora** from **AsciiDoc** (`.adoc`) source files. Content is single-sourced across Prime, Community, and SRFA editions.

- **Directory Layout**:
  - **Product (Prime)**: `versions/<VERSION>/modules/<LOCALE>/pages/` (for example, `versions/v2.10/modules/en/pages/`)
  - **Community**: `community-docs/<VERSION>/modules/ROOT/pages/` (for example, `community-docs/v2.10/modules/ROOT/pages/`)
  - **Assets**: `versions/<VERSION>/modules/<LOCALE>/images/`
- **Single-Sourcing Symlinks**:
  - Most AsciiDoc files in `community-docs` are symlinks pointing directly to their product counterparts in `versions/`.
  - When editing existing topics, updating either file updates the underlying shared content.
  - When creating a *new* topic, create the product file, establish the community symlink, and define the paths in the file header.
- **Mandatory Header Path Attributes**:
  Every `.adoc` page must declare its relative path in both trees at the very top. It also needs to define a short description of the page, the revision date, and the list of other languages if other translations of the page exist:
  ```asciidoc
  :page-community-path: reference-guides/kubernetes-concepts.adoc
  :page-product-path: about-rancher/concepts.adoc
  :description: Explain Kubernetes concepts important for understanding Rancher, covering clusters, nodes, etcd, control plane, worker nodes, and Helm, with a simplified explanation
  :revdate: 2025-08-27
  :page-revdate: {revdate}
  :page-languages: [en, de, es, fr, ja, pt, zh]
  ```
- **Conditionals for Target Builds**:
  Use `ifeval::["{build-type}" == "..."]` directives to conditionally render content:
  - `"{build-type}" == "community"`: Rancher Community only
  - `"{build-type}" == "product"`: SUSE Rancher Prime only
  - `"{build-type}" == "srfa"`: SUSE Rancher for AWS only
  - `"{build-type}" != "srfa"`: Applies to both Community and Prime, excluded from SRFA
- **Mandatory Explicit Heading Anchors**:
  Every section heading (`==`, `===`, etc.) **must** have an explicit Antora-style anchor (`[#_anchor_name]`) placed on the line immediately preceding it. Format the anchor ID in lowercase, prefixed with an underscore (`_`), with words separated by underscores (`_`) and punctuation removed. Auto-generated anchors break during translation.
  ```asciidoc
  [#_configuring_storage]
  == Configuring Storage
  ```
- **Cross-References (`xref`)**:
  - Always use Antora `xref:` macros: `xref:path/to/page.adoc[Link Text]`.
  - If a target page has different paths in community vs. product builds, use attribute substitution:
    ```asciidoc
    ifeval::["{build-type}" != "community"]
    :xref-guide: xref:installation-and-upgrade/best-practices/tuning-rancher-at-scale.adoc
    endif::[]
    ifeval::["{build-type}" == "community"]
    :xref-guide: xref:reference-guides/best-practices/rancher-server/tuning-and-best-practices-for-rancher-at-scale.adoc
    endif::[]

    Refer to the {xref-guide}[Tuning and Best Practices] guide.
    ```
- **Navigation File Updates**:
  Whenever adding, moving, renaming, or removing a page, update `nav.adoc` in **both** trees:
  - `community-docs/<VERSION>/modules/ROOT/nav.adoc`
  - `versions/<VERSION>/modules/en/nav.adoc`
- **Translations & Locales**:
  - Translations are published exclusively for the Prime site and located under `versions/<VERSION>/modules/<LOCALE>/` (for example, `de`, `es`, `fr`, `ja`, `pt`, `zh`).
  - **No Manual Translation Updates**: Translations are imported in automated batches. Contributors and AI agents must not manually edit translated files in non-English module directories unless explicitly instructed to do so. All drafting, revisions, and fixes must otherwise be made in the English source files (`versions/<VERSION>/modules/en/` and `community-docs/`).

---

## 3. Branching & Contribution Workflow

- Work in feature branches from a personal fork. Do not push directly to `main`.
- **Target Branches**:
  - Version-specific fixes/content: Target the specific release branch (for example, `v2.10.10`).
  - Next minor version or general ongoing updates: Target `main`.

---

## 4. SUSE Documentation Style Guidelines

All content must conform to the SUSE Style Guide ([product-docs-common/ai-prompts/Style-Guide-onefile.md](product-docs-common/ai-prompts/Style-Guide-onefile.md)). Assisting agents must enforce these rules:

1. **Grammar & Sentence Structure**:
   - Write in **American English**, active voice, second person ("you"), and simple present tense.
   - Keep sentences short: **maximum 25 words per sentence**. Split complex or compound sentences.
   - Spell out numbers **zero through nine**; use numerals for **10 and above**.
   - **No Latin abbreviations**: Use "that is" instead of "i.e.", "for example" instead of "e.g.", and avoid "etc.". Avoid slash alternatives (use "or", not "/").
2. **Tone & Word Choice**:
   - Professional, objective, direct, and concise. Avoid filler and marketing jargon.
   - Avoid buzzwords: Use "use", "help", "enable"; avoid "leverage", "utilize", "facilitate".
3. **Terminology & Acronyms**:
   - Expand acronyms on first occurrence (e.g., "Role-Based Access Control (RBAC)").
   - Never use possessive forms of trademarks or acronyms (write "features of Rancher", not "Rancher's features"; "specification of XML", not "XML's specification").
4. **Headings & Capitalization**:
   - Use **sentence-style capitalization** for all headings (capitalize only the first word and proper nouns).
   - Prefer natural-language questions for H2/H3 (`How to configure storage`) and action-oriented gerunds for task headings (`Configuring storage`).
5. **Inclusive Language**:
   - Use gender-neutral, culturally independent phrasing.
   - Use "primary/secondary" (not "master/slave"), "allowlist/denylist" (not "whitelist/blacklist"), and "they/their" (not "he/she").
6. **Web & Search (GEO) Inverted Pyramid**:
   - Lead with a direct 40–80 word answer to the primary user intent immediately under the heading.
   - Break content into scannable chunks (1–3 paragraphs per section). Avoid long narrative introductions.
7. **Modular Procedures**:
   - Use numbered lists (`1. ... 2. ...`) for sequential procedures.
   - Ensure parallel grammatical phrasing across all list items.

---

## 5. Extended References

- **Build, Playbooks, & Troubleshooting**: [README.md](README.md)
- **Minimal Style Guide**: [product-docs-common/ai-prompts/Style-Guide-onefile.md](product-docs-common/ai-prompts/Style-Guide-onefile.md)
- **Topic-by-Topic Editorial Prompts**: [product-docs-common/ai-prompts/suse-style-guide/](product-docs-common/ai-prompts/suse-style-guide/)
