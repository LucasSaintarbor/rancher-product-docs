---
# Placeholders that the draft-release-notes.yml workflow replaces in the PR body:
#   __VERSION__: the release being documented, for example `v2.13.1`.
#   __MINOR_VERSION__: the minor version directory, for example `v2.13`.
# The workflow strips this front matter, including these comments, from the PR body.
applyTo: "**/release-notes/*.1.adoc"
---
@copilot

Update the release notes for the first SUSE Rancher Prime release of a minor version (the `.1` release). Work through the sections below in order.

The file to edit is `versions/__MINOR_VERSION__/modules/en/pages/release-notes/__VERSION__.adoc`. Edit only this file. Do not change any other file. Collect your findings as you go and post them in a single PR comment in section 8.

## 1. Keep the carried-over content

The `.1` release carries over the content of the `.0` release notes. Do not clean up the file:

1. Do not remove the `Security Fixes for Vulnerabilities` section.
2. Do not remove the `What's New` section. Its heading can be worded differently between releases, so match any `==` heading that starts with `What's New`.
3. Do not remove any release notes under `Major Bug Fixes` or `Features and Enhancements` sections.
4. Do not move any issues from `Behavior Changes` or `Known Issues` sections to `Previous Rancher Behavior Changes` or `Long-standing Known Issues`.

## 2. Find the release note issues

1. Use the search queries in the PR body to find issues labeled `release-note` or `release-note-prime`.
2. Do not run the query for the private `rancher/rancher-prime` repository. You cannot access it. List the query in the PR comment with a warning that a person must check it manually.
3. Record each other query and its results for the PR comment.

## 3. Write a release note for each issue

1. Scan the issue body, comments, referenced pull requests, referenced issues, and labels. Use them to understand the full context of the Rancher `__VERSION__` release and the status of the issue.
2. Summarize what you found as a release note. Follow the format used in the `__VERSION__.adoc` file.
3. If the issue is a backport or forwardport, it references the issue it was copied from. Check that issue for a `release-note` or `release-note-prime` label. If it has one, reuse its description.
4. If a comment on the issue contains a release note summary, reuse it as the description.
5. Edit reused descriptions for clarity and grammar as needed.

## 4. Add the release notes to the file

1. Determine the correct area section by scanning the issue labels for Rancher areas and teams. If you cannot determine a suitable section, use `Rancher General`.
2. Determine the release note type of the issue. Place it under the matching subsection of that area section: `Features and Enhancements`, `Behavior Changes`, `Major Bug Fixes`, or `Known Issues`.
3. If an issue has the `release-note-prime` label and does not have the `release-note` label, it applies to SUSE Rancher Prime only. Wrap its release note in an AsciiDoc conditional, with each directive on its own line. Consecutive Prime-only notes can share one conditional block. For example:

   ```asciidoc
   ifeval::["{build-type}" != "community"]
   * Release note text. See https://github.com/rancher/rancher/issues/12345[#12345].
   endif::[]
   ```

4. Do not add the conditional to issues that have the `release-note` label, with or without the `release-note-prime` label.
5. Record the area, type, and whether you added the conditional for each issue for the PR comment.

## 5. Check for references to removed or deprecated items

Do this for any feature, component, role, flag, or API that is removed or deprecated in `__VERSION__`. Identify these items from `Behavior Changes`, `Previous Rancher Behavior Changes`, `Removed Legacy Features`, and from the issues and pull requests you found.

1. Search `versions/__MINOR_VERSION__/modules/en/pages/` for remaining references to each item. Examples are obsolete roles, deprecated CLI subcommands, and removed feature flags.
2. Do not edit the documentation files that contain these references. Report them only.
3. For each reference, record the file path and the line number or surrounding context for the PR comment.

## 6. Review the long-standing known issues

1. Scan the issues listed in the `Long-standing Known Issues` section of `__VERSION__.adoc`.
2. Follow the links to each issue. Find the issues closed in the past 45 days. Ignore issues closed as not planned.
3. For each closed issue, record the close date and a summary of the latest updates for the PR comment.
4. If a scanned issue has a comment containing `/backport __VERSION__` or `/forwardport __VERSION__`, record this for the PR comment. It means a port of the issue to this release was requested.
5. For each long-standing known issue, find the issues created from it as backports or forwardports. Look for `[backport]` or `[forwardport]` references and links in the original issue.
6. Mark each long-standing known issue that has been ported in `__VERSION__.adoc`. Choose the update based on the status of the port issue:
   * Port issue open: keep the known issue. Add a sentence that names the target version and links the port issue, for example `A backport to v2.12.x is tracked in https://github.com/rancher/rancher/issues/12345[#12345].`
   * Port issue closed as completed: remove the known issue from `__VERSION__.adoc`. Record the removed entry, the port issue link, and the version containing the fix for the PR comment.
   * Port issue closed as not planned: do not change the known issue. Mention it in the PR comment.
7. Record each ported issue, the port issue link, its status, and the update you made for the PR comment.

## 7. Remove empty placeholder sections

Remove empty placeholder sections from `__VERSION__.adoc`.

## 8. Post the summary comment

Post one comment on the PR that summarizes the issues found and the actions taken. Format it as follows:

1. Add a separate table for each search query from section 2. Each table must include the determined category, whether the release note is Prime only, and the related issues or pull requests.
2. Add a warning that the `rancher/rancher-prime` query was not run and must be checked manually. Include the query link from the PR body.
3. Add a summary or table of the removed or deprecated items identified for `__VERSION__`. Include all occurrences found under `versions/__MINOR_VERSION__/`, as described in section 5.
4. Add a table of the long-standing known issues closed in the past 45 days, as described in section 6. Include the date and a summary of the latest updates.
5. Report any `/backport __VERSION__` or `/forwardport __VERSION__` comments found in section 6.
6. Add a table of the long-standing known issues marked as ported in section 6. Include the port issue link, its status, and the update made to `__VERSION__.adoc`. Identify the issues removed because the port issue is closed.
