---
name: html-communication
description: Use when the user wants a plan, spec, write-up, findings, summary, report, comparison, or set of UI mocks presented as readable HTML; or if they mention HTML with no additional context. Do not use for HTML that ships as part of the product.
---

# HTML Communication

Produce a readable HTML artifact for a human —a document to read outside the terminal— and give the user a link or file path to open it.

## Writing the file

- Write one self-contained HTML file. Keep all CSS and JavaScript inline in style and script tags.
- Write plainly: short sentences, plain words, one idea per sentence. Follow the Google developer documentation style guide.
- Write it like a spec, not a landing page. Avoid marketing language. Structure it as a technical document and a presentation.
- For UI mocks: label them A, B, C for easy selection, and lay them out for direct comparison.
- Keep one file across iterations so its path (and, once published, its hosted URL) stays stable.

## Publishing

<!-- Disabled until startline is ready.

- Always upload the file after writing it (via the startline-publish skill) and respond with the URL.
- Never claim the document is hosted before the upload succeeds.
- Re-uploading the same path versions it in place, keeping the hosted URL stable.

-->

- Never open a browser without the user's approval.
