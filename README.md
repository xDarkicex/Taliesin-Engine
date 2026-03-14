# Taliesin Engine

> A deterministic Perl pipeline for preparing classic and public-domain text for Kokoro TTS audiobook generation.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Perl](https://img.shields.io/badge/Perl-5%2B-blue.svg)](https://www.perl.org/)
[![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20windows-lightgrey)]()

---

## Overview

**Taliesin Engine** is a deterministic, phase-based text normalization tool written in pure Perl. It converts messy plain-text sources — OCR scans, Project Gutenberg dumps, and historical editions — into clean, TTS-ready input for [Kokoro](https://github.com/aedocw/epub2tts-kokoro)-based audiobook pipelines.

It is purpose-built for `epub2tts-kokoro`, which reads audiobook metadata from the first two lines of a `.txt` file in the following format:

```text
Title: The Mabinogion
Author: Anonymous
```

Taliesin Engine writes those lines automatically via command-line flags.

---

## The Problem It Solves

Classic and public-domain texts are rarely TTS-ready out of the box. Common issues include:

- Hard-wrapped lines from OCR or print layout
- Ligatures, soft hyphens, and unusual Unicode characters
- Project Gutenberg boilerplate headers and footers
- Archaic contractions and abbreviations that confuse phonemizers
- Dash patterns, malformed ellipses, and repeated punctuation
- Short ALL-CAPS headings that TTS engines read as shouted text

Taliesin Engine cleans and normalizes these issues so Kokoro produces smoother prosody, fewer mispronunciations, and more natural-sounding output — without altering the meaning of the source text.

---

## Requirements

- **Perl 5** (no version constraints beyond standard availability)
- Core modules only — no CPAN dependencies:
  - `strict`
  - `warnings`
  - `utf8`
  - `Getopt::Long`

---

## Installation

Clone the repository and make the script executable:

```bash
git clone https://github.com/xDarkicex/Taliesin_Engine.git
cd Taliesin_Engine
chmod +x Taliesin_Engine.pl
```

No installation step is required. The script runs directly with any standard Perl 5 interpreter.

---

## Usage

```bash
perl Taliesin_Engine.pl [OPTIONS] input.txt > output.txt
```

### Options

| Flag | Description |
|------|-------------|
| `--title="Name"` | Writes `Title: Name` as line 1 of the output |
| `--author="Name"` | Writes `Author: Name` as line 2 of the output |
| `--help` | Prints usage information and exits |

### Basic Example

```bash
perl Taliesin_Engine.pl \
  --title="The Mabinogion" \
  --author="Anonymous" \
  raw_input.txt > cleaned.txt
```

---

## Workflow

A typical Kokoro audiobook generation workflow using Taliesin Engine looks like this:

### Step 1 — Normalize the source text

```bash
perl Taliesin_Engine.pl \
  --title="The Mabinogion" \
  --author="Anonymous" \
  raw_input.txt > cleaned.txt
```

### Step 2 — Generate the audiobook

```bash
epub2tts-kokoro cleaned.txt --cover cover.png
```

### Step 3 — Tag additional metadata (optional)

`epub2tts-kokoro` only reads `Title` and `Author` from the text file. Additional metadata such as genre, year, or publisher must be applied afterward:

```bash
ffmpeg -i book.m4b \
  -metadata genre="Mythology" \
  -metadata date="1849" \
  -metadata comment="Publisher: Everyman" \
  -c copy book_tagged.m4b
```

---

## Processing Phases

Taliesin Engine applies eight deterministic normalization phases in sequence. The same input always produces the same output.

| Phase | Description |
|-------|-------------|
| **1. Raw byte normalization** | Fixes CRLF line endings, removes soft hyphens, expands OCR ligatures, normalizes exotic Unicode whitespace |
| **2. Boilerplate stripping** | Removes Project Gutenberg headers and footers, license text, editorial brackets, asterisms, and horizontal rules |
| **3. Line structure repair** | Rejoins hyphenated line breaks and merges soft-wrapped prose lines into natural sentence flow |
| **4. Punctuation cleanup** | Normalizes em-dashes, smart quotes, ellipses, repeated punctuation, and spacing around punctuation marks |
| **5. Abbreviation protection** | Identifies and protects initials and common abbreviations to prevent damage during sentence-level cleanup |
| **6. Prosody adjustments** | Modernizes select archaic contractions and smooths conjunction behavior for more natural TTS delivery |
| **7. Artifact cleanup and restoration** | Removes residual punctuation artifacts and restores protected abbreviation tokens to their final form |
| **8. Final whitespace normalization** | Collapses excessive spaces and blank lines, then emits the final output in a stable, consistent format |

---

## Before and After

### Input

```text
*** START OF THE PROJECT GUTENBERG EBOOK ***

THE SONG OF TALIESIN

``Who art thou?'' said he.
And
then the king—stern and dark—look'd on him...

J.R.R. Tolkien was not here.
```

### Output

```text
Title: The Song of Taliesin
Author: Anonymous

the song of taliesin

"Who art thou?" said he, and then the king, stern and dark, look'd on him...

J. R. R. Tolkien was not here.
```

Exact output will vary depending on source formatting, but the result is consistently more stable and natural when processed by Kokoro.

---

## Design Goals

| Goal | Description |
|------|-------------|
| **Deterministic output** | Identical input always produces identical output |
| **TTS-first formatting** | Every decision optimizes for readable rhythm and pronunciation, not typographic fidelity |
| **Classic-text friendly** | Built around OCR artifacts, Gutenberg conventions, and older editorial styles |
| **Minimal dependencies** | Pure Perl with no CPAN requirements |
| **Pipeline-friendly** | Reads from a file, writes to stdout — easy to compose in shell scripts and batch jobs |

---

## Input and Output

### Input

A UTF-8 encoded plain-text file. Typical sources include:

- Project Gutenberg `.txt` downloads
- OCR output from scanned books
- EPUB-to-text conversions
- Manual transcriptions or plain-text exports

### Output

A UTF-8 plain-text file beginning with:

```text
Title: Your Title
Author: Your Author
```

followed by normalized book content ready for downstream use with `epub2tts-kokoro` or any other Kokoro-based TTS pipeline.

---

## Caveats

- This tool performs **structural and phonemic normalization**, not semantic editing. It does not alter meaning.
- It makes deliberate prosody-oriented substitutions that favor speech flow over typographic accuracy.
- It is best suited for classic and public-domain works. Contemporary texts with standard formatting may need little or no preprocessing.
- Dramatic verse layout, scholarly annotations, and highly unusual formatting may still require manual review after processing.

---

## License

MIT © 2026 [xDarkicex](https://github.com/xDarkicex)
