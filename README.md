# SUSE® Rancher Prime and Rancher Manager Documentation

This is the source for the official SUSE Rancher Prime, SUSE Rancher for AWS and Rancher Manager documentation.

For inquiries about the Rancher software, please refer to [Rancher GitHub repository](https://github.com/rancher/rancher/).

## Build the Documentation Site

This repository uses [Antora](https://docs.antora.org/antora/latest/) to build [AsciiDoc](https://docs.asciidoctor.org/asciidoc/latest/) content into a static website.

### Prerequisites

#### git

You need git to get the source code of this repository. Run the command below to check whether git is installed on your machine.

```bash
git --version
```

If you don't have git installed on your machine, it is recommended to install it through your operating system or distribution's package manager. Otherwise, you can download and install from the [git downloads](https://git-scm.com/downloads) page.

#### Node.js

Antora requires an active long term support (LTS) release of Node.js. Run the command below to check if you have Node.js installed, and which version. This command should return an [active Node.js LTS version number](https://nodejs.org/en/about/releases/).

```bash
node -v
```

If you don't have Node.js installed on your machine, install it, preferably via [nvm](https://github.com/nvm-sh/nvm).

### Install Dependencies

#### Git Submodules

This repository uses [git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules) to manage some of its dependencies, including the Antora files that provide the custom GUI for the documentation website. Run the command below to initialize the submodules recursively (including any nested submodules).

```bash
git submodule update --init --recursive
```

After initializing, and whenever the referenced commits for the submodules are updated in the repository (such as after a `git pull`), you need to use the `update` command to fetch the latest data for the submodules:

```bash
git submodule update --recursive
```

#### Node Modules

Open a terminal at the root of the git repository. Run the command below.

```bash
npm ci
```

### Build the Static Website Using the Local Documentation Content

There are several playbook files available to build different variants of the documentation site, such as the community (Rancher Manager), product (Rancher Prime), or SRFA (SUSE Rancher for AWS) site, using either local or remote content.

If you want to build and view the documentation content from your local machine, you can use one of the local playbooks:

- `playbook-community-local.yml`
- `playbook-product-local.yml`
- `playbook-srfa-local.yml`

Run the command below to build the site using your chosen playbook file, replacing `<PLAYBOOK_FILE>` with the respective playbook:

```bash
npx antora <PLAYBOOK_FILE>
```

To preview the built documentation using a local HTTP server, run the command below, replacing `<SITE_DIRECTORY>` with the corresponding build output directory (for example, `build/site-product-local`, `build/site-community-local`, or `build/site-srfa-local`):

```bash
npx http-server <SITE_DIRECTORY> -c-1
```

Alternatively, you can preview the documentation by accessing the HTML files directly. To do so, open the `<SITE_DIRECTORY>/index.html` file.

Subsequent updates require rebuilding (that is running `npx antora <PLAYBOOK_FILE>` again) as there is no live reloading.

### Using Make

Alternatively, you can use `make` to build and preview the documentation. Note that you must have the `make` package installed on your system to use this method.

The following targets are available in the `Makefile` for building the documentation locally:

- `make community-local`
- `make product-local`
- `make srfa-local`

To preview the built documentation using a local HTTP server, you can use the following targets:

- `make preview-community-local`
- `make preview-product-local`
- `make preview-srfa-local`

Other utility targets include `make environment` to install the `npm` dependencies, and `make clean` to remove the `build` directory.

## Contributing to the Documentation

You can contribute to the documentation by raising awareness about inaccuracies or suggesting changes directly. This can be done in two ways:

1. [Open an issue](https://github.com/rancher/rancher-product-docs/issues/new/choose).
1. Edit the documentation in the way you see fit and submitting a [pull request](https://github.com/rancher/rancher-product-docs/compare).

### Edit the Documentation

To get started, [fork](https://github.com/rancher/rancher-product-docs/fork) and clone the `rancher-product-docs` repository.

Our repository does not allow you to make changes directly to the `main` branch. Create a working branch and make pull requests from your fork to [rancher/rancher-product-docs](https://github.com/rancher/rancher-product-docs).

### Branching Strategy

Most documentation development happens on the `main` branch. However, when working on version-specific content, your pull requests should target a version branch (for example, `v2.10.10`). These version branches are created at the beginning of the development cycle for a specific release. Once the version is released, the release branch is merged back into `main`.

An exception to this is a new minor version (such as `v2.10.0`), for which development is opened on `main` from the beginning of the development cycle.

### File Organization

#### Content and Asset Files

There are two separate directory trees for documentation content:

- `community-docs/<VERSION>/`: Contains content for the community site, published at https://ranchermanager.docs.rancher.com/.
- `versions/<VERSION>/`: Contains content for the Prime site, published at https://documentation.suse.com/cloudnative/rancher-manager/.

To support single-sourcing, most of the AsciiDoc files in the `community-docs` tree are symlinked to their respective counterparts in the product `versions` directory. For community docs, these files are organized under the following directory structure:

- `community-docs/<VERSION>/modules/ROOT/pages/`

For product docs, the directory structure is as follows:

- `versions/<VERSION>/modules/<LOCALE>/pages/`

To define the location of the documentation page in the product `versions` documentation tree and its community symlink counterpart in the `community-docs` tree, use the `:page-community-path:` and `:page-product-path:` attributes at the top of the AsciiDoc file.

For example:

```asciidoc
:page-community-path: reference-guides/kubernetes-concepts.adoc 
:page-product-path: about-rancher/concepts.adoc
```

Other asset files (for example, images) have their own subdirectories. For example, `versions/<VERSION>/modules/en/images`.

#### Backporting Changes

When you need to backport changes between different versions, you can try running the `./product-docs-common/scripts/recurring/backport_modules.sh` script. This script helps contributors with porting changes as found in Git-modified files.

For example, to port changes to versions `v2.11` and `v2.12`, run:

```bash
./product-docs-common/scripts/recurring/backport_modules.sh v2.11 v2.12
```

For more information and a complete list of options, refer to the script's help menu by running:

```bash
./product-docs-common/scripts/recurring/backport_modules.sh --help
```

#### Single-Sourcing with Conditionals

Because most documentation content is single-sourced and shared across the community, product (Rancher Prime), and SRFA (SUSE Rancher for AWS) sites, you might encounter situations where certain text, links, or instructions apply to only one specific build type.

To handle these differences, use AsciiDoc `ifeval::[]` conditionals based on the `{build-type}` attribute. This ensures the appropriate content is selectively rendered for the respective target site.

Here are some practical examples of how to use these conditionals in the `.adoc` files:

```asciidoc
// Content specifically for the community site
ifeval::["{build-type}" == "community"]
This content only appears in the Rancher Community documentation.
endif::[]

// Content specifically for the Prime site
ifeval::["{build-type}" == "product"]
This content only appears in the SUSE Rancher Prime documentation.
endif::[]

// Content specifically for the SUSE Rancher for AWS (SRFA) site
ifeval::["{build-type}" == "srfa"]
This content only appears in the SUSE Rancher for AWS documentation.
endif::[]

// Content for everything except the SRFA site (that is, applies to both product and community build types)
ifeval::["{build-type}" != "srfa"]
This content applies to both the Rancher Community and SUSE Rancher Prime documentation, but is excluded from SRFA.
endif::[]
```

For more information on the directive syntax, refer to the [AsciiDoc Conditionals documentation](https://docs.asciidoctor.org/asciidoc/latest/directives/conditionals/).

#### Required Anchor IDs for Headings

To support content translations, you must use explicit anchors for cross-references. Auto-generated anchors do not survive the translation process, which causes links to break.

When creating a heading, always define an explicit anchor directly above it. Use the following anchor format:

```asciidoc
[#_my_anchor]
== My Anchor

My paragraph.
```

You can then safely refer to this heading using the explicit anchor:

```asciidoc
xref:#_my_anchor[My Anchor]
```

> [!NOTE]
> If you want to link from one documentation page to another, do not use absolute URLs. Antora uses a special xref: syntax to cross-reference pages. For example:
>
> ```asciidoc
> xref:installation/requirements.adoc[System Requirements]
> ```
>
> For more information, refer to the [Antora Xref documentation](https://docs.antora.org/antora/latest/page/xref/).

#### Cross-References (xrefs)

When referencing content across build targets, cross-references (xref) may point to pages whose file paths differ between builds (such as community vs. product) or exist in only one build type.

Always use a xref instead of hardcoding absolute domain URLs (such as [https://documentation.suse.com/](https://documentation.suse.com/) or [https://ranchermanager.docs.rancher.com/](https://ranchermanager.docs.rancher.com/)). Hardcoding URLs causes domain leakage across site builds and bypasses Antora's broken-link validation. Because target file paths differ across builds, you must conditionalize xref paths to prevent build errors. For example, referencing [https://documentation.suse.com/cloudnative/rancher-manager/v2.14/en/installation-and-upgrade/best-practices/tuning-rancher-at-scale.html](https://documentation.suse.com/cloudnative/rancher-manager/v2.14/en/installation-and-upgrade/best-practices/tuning-rancher-at-scale.html) without conditionalizing would mean this product docs page would be shown in the community docs.

The [xref macro](https://docs.antora.org/antora/latest/page/xref/) accepts an Antora resource ID (relative to the `pages` directory) specifying a publishable page. For example, the resource ID for [https://documentation.suse.com/cloudnative/rancher-manager/v2.14/en/installation-and-upgrade/best-practices/tuning-rancher-at-scale.html](https://documentation.suse.com/cloudnative/rancher-manager/v2.14/en/installation-and-upgrade/best-practices/tuning-rancher-at-scale.html) is `installation-and-upgrade/best-practices/tuning-rancher-at-scale.adoc`.

> [!TIP]
> To find the product or community file path of a file, go to the header block of the docs file and find the `:page-product-path:` or `:page-community-path:` attribute.

##### Attribute-Based Path Substitution for Inline Links

1. Set a file path attribute in the `.adoc` documentation file in the header metadata block based on the build type:

    ```asciidoc
    ifeval::["{build-type}" != "community"]
    :xref-tuning-rancher-at-scale: xref:installation-and-upgrade/best-practices/tuning-rancher-at-scale.adoc
    endif::[]

    ifeval::["{build-type}" == "community"]
    :xref-tuning-rancher-at-scale: xref:reference-guides/best-practices/rancher-server/tuning-and-best-practices-for-rancher-at-scale.adoc
    endif::[]
    ```

1. Reference the file path attribute in the text `{attribute-name}[custom link text]`. For example:

    ```asciidoc
    Refer to the {xref-tuning-rancher-at-scale}[Tuning and Best Practices for at Scale] guide for details.
    ```

#### Cross Project Documentation Links

When linking to portfolio projects that maintain separate documentation domains for community and SUSE product variants, single-source the target URLs using attributes in the metadata section. Hardcoding URLs for these dual-variant projects introduces domain leakage across site builds. If a project only maintains a single documentation site, single-sourcing the target URL is not required.

##### Single-Sourcing Project Documentation URLs

1. Add the URL attribute definitions in the `.adoc` file in the header metadata block based on the build type:

    ```asciidoc
    ifeval::["{build-type}" != "community"]
    :url-rke2-intro: https://documentation.suse.com/cloudnative/rke2/latest/en/introduction.html
    :url-k3s-intro: https://documentation.suse.com/cloudnative/k3s/latest/en/introduction.html
    endif::[]
    ifeval::["{build-type}" == "community"]
    :url-rke2-intro: https://docs.rke2.io/
    :url-k3s-intro: https://docs.k3s.io/
    endif::[]
    ```

1. Reference the URL attribute in the body text using `{attribute-name}[link text]`:

    ```asciidoc
    For more information, see the {url-rke2-intro}[RKE2 Introduction] or the {url-k3s-intro}[K3s Introduction].
    ```

> [!TIP]
> **Naming Convention:** Prefix project link attributes with `:url-<project>-<topic>:` (e.g., `:url-rke2-intro:`, `:url-k3s-intro:`, `:url-harvester-storage:`) to distinguish them from internal `:xref-...:` attributes.
> **Full URLs Only:** Define complete target URLs within the conditional attribute blocks. Avoid constructing links inline with base URL attributes (e.g., do not write `{url-base-rke2}/install`).

#### Updating Navigation

When adding a new documentation page, or renaming or removing an existing one, you must update the navigation file (`nav.adoc`) for the respective version (and locale). This ensures that the site's sidebar menu accurately reflects the available content.

If the page is single-sourced, the `nav.adoc` file needs to be updated in both the community and product directory trees, for example:

- `community-docs/<VERSION>/modules/ROOT/nav.adoc`
- `versions/<VERSION>/modules/en/nav.adoc`

For more information on how to structure the navigation lists, refer to the [Antora Navigation Files and Lists documentation](https://docs.antora.org/antora/latest/navigation/files-and-lists/).

#### Configuration Files

- Site-level configuration is done through a playbook file. For example, `playbook-community-local.yml`. Refer to the [Antora playbook documentation](https://docs.antora.org/antora/latest/playbook/) for more information.
- Component-level configuration is done through a file called `antora.yml`. For example, `versions/<VERSION>/antora.yml` or `community-docs/<VERSION>/antora.yml`. Refer to the [Antora  antora.yml documentation](https://docs.antora.org/antora/latest/component-version-descriptor/) for more information.

#### Translations

Translations are only published for the Prime site and are available under the `versions/<VERSION>/modules/` directory. Translations are imported in batches, so contributors should not update individual translations manually.

The list of available locales for each page is defined by the `:page-languages:` attribute at the beginning of each page. This attribute is used for the language switcher on the Prime site.

#### Troubleshooting Common Issues

**Error:** `Antora documentation component not found` or CSS formatting looks completely broken.
**Fix:** You likely forgot to initialize the submodules. Run `git submodule update --init --recursive` and rebuild.

**Error:**  `npm ERR! code EBADENGINE` or dependency conflicts.
**Fix:** Ensure you are using a modern Node.js LTS version (e.g., Node 18 or Node 20). If you used `npm install`, delete your `node_modules` directory and run `npm ci` instead.

**Issue:** Changes aren't updating in the browser.
**Fix:** Antora does not feature "live-reload". Every time you make a change to a file, you must stop your terminal process, rerun `npx antora <PLAYBOOK_FILE>`, and refresh your browser.

## License

Copyright (c) 2014-2026 [SUSE, LLC.](https://www.suse.com/)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
