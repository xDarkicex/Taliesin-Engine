#!/usr/bin/env perl

# ==============================================================================
# Taliesin_Engine.pl - High-Assurance Prosody & OCR Restoration Pipeline
# ==============================================================================
# GitHub: https://github.com/xDarkicex/Taliesin_Engine
# License: MIT © 2026 xDarkicex
# Purpose: Deterministic text normalization for neural TTS synthesis.
# ==============================================================================

use strict;
use warnings;
use utf8;
use Getopt::Long;
binmode(STDOUT, ":utf8");
binmode(STDIN,  ":utf8");

my $TITLE  = "Unknown Title";
my $AUTHOR = "Unknown Author";
my $HELP   = 0;

GetOptions(
    "title=s"  => \$TITLE,
    "author=s" => \$AUTHOR,
    "help"     => \$HELP,
) or print_usage();

print_usage() if $HELP;

sub print_usage {
    print <<EOF;
Taliesin_Engine.pl - Deterministic OCR & Prosody Restoration Pipeline

Usage:
  perl Taliesin_Engine.pl --title="Name" --author="Name" input.txt > output.txt

Options:
  --title=S     Book title written to line 1 of output (epub2tts-kokoro metadata)
  --author=S    Author name written to line 2 of output (epub2tts-kokoro metadata)
  --help        Show this help text

NOTE on metadata: epub2tts-kokoro only reads Title and Author from .txt files.
Fields like genre, publisher, and year must be embedded post-process via ffmpeg:
  ffmpeg -i book.m4b -metadata genre="Mythology" -metadata date="1849" \\
         -metadata comment="Publisher: Everyman" -c copy book_tagged.m4b

Summary of Operations:
  Phase 1  Normalizes raw bytes: CRLF, soft hyphens, ligatures, exotic Unicode.
  Phase 2  Strips Project Gutenberg boilerplate, asterisms, and horizontal rules.
  Phase 3  Repairs hyphenated line-breaks and joins soft-wrapped prose lines.
  Phase 4  Normalizes OCR-damaged punctuation, em-dashes, ellipses, and spacing.
  Phase 5  Protects initials and abbreviations via null-byte sentinel tokens.
  Phase 6  Bridges archaic contractions and bardic conjunctions for fluid prosody.
  Phase 7  Restores protected tokens and collapses punctuation artefacts.
  Phase 8  Final whitespace normalization.

EOF
    exit;
}

undef $/;
my $text = <>;

# ============================================================
# PHASE 1: RAW BYTES / ENCODING NORMALISATION
# ============================================================

# CRLF and stray CR -> LF  (must happen before any \n logic)
$text =~ s/\r\n/\n/g;
$text =~ s/\r/\n/g;

# Soft hyphen (U+00AD) — OCR inserts these invisibly, TTS sometimes pauses on them
$text =~ s/\x{00AD}//g;

# OCR ligatures — TTS can mispronounce these Unicode characters
$text =~ s/\x{FB01}/fi/g;   # ﬁ -> fi
$text =~ s/\x{FB02}/fl/g;   # ﬂ -> fl

# Exotic Unicode whitespace -> plain space
# (non-breaking, thin, hair, zero-width, ideographic, etc.)
$text =~ s/[\x{00A0}\x{2000}-\x{200B}\x{202F}\x{205F}\x{3000}]/ /g;

# Backtick-style and doubled-apostrophe quotes -> straight double quotes
$text =~ s/``/"/g;
$text =~ s/''/"/g;

# ============================================================
# PHASE 2: BOILERPLATE STRIPPING
# ============================================================

# Standard Gutenberg markers (with or without closing ***)
$text =~ s/\*\*\*\s*START OF.*?\*\*\*//si;
$text =~ s/\*\*\*\s*START OF.*?\n\n//si;   # variant: no closing ***
$text =~ s/\*\*\*\s*END OF.*//si;

# License tail that sometimes survives the above
$text =~ s/End of (the )?Project Gutenberg.*//si;

# Bracketed editorial annotations that break audiobook flow
# Covers "[Illustration]", "[Illustration: Castle]", "[Footnote 12: ...]"
$text =~ s/\[(Illustrations?|Illustration:[^\]]*|Footnote[^\]]*)\]//gi;

# Asterism section separators — TTS reads these as "star star star"
$text =~ s/^\s*\*\s*\*\s*\*\s*$/\n\n/mg;
$text =~ s/^\s*\*{3,}\s*$/\n\n/mg;

# Horizontal rules (--- or ___) used as section separators
$text =~ s/^[\-_]{3,}$/\n\n/mg;

# ============================================================
# PHASE 3: LINE STRUCTURE
# ============================================================

# Hyphenated line-breaks: "impor-\ntant" -> "important"
# \s* handles stray spaces OCR sometimes leaves around the break
# Requires letters on both sides to avoid eating list/bullet dashes
# Must run BEFORE soft-wrap joining
$text =~ s/([A-Za-z])-\s*\n\s*([A-Za-z])/$1$2/g;

# Join soft-wrapped lines — only when the next line starts lowercase,
# meaning it looks like sentence continuation rather than a new heading/line.
# Two passes: first catches lines ending in mid-sentence punctuation,
# second catches plain lowercase endings (e.g. "slowly\nthrough")
$text =~ s/([a-z,;:])\n(?=[a-z])/$1 /g;
$text =~ s/([a-z])\n(?=[a-z])/$1 /g;

# ============================================================
# PHASE 4: PUNCTUATION CLEANUP
# ============================================================

# Line-leading em-dashes signal dialogue in many editions:
#   —What are you doing?  ->  What are you doing?
# Strip to a space so the sentence flows without a prosody reset at the start.
$text =~ s/^\s*\x{2014}\s*/ /mg;

# Mid-sentence em-dashes (word—word) -> comma-space (preserve the breath)
$text =~ s/\s*\x{2014}\s*/, /g;

# Smart quotes / remaining dashes -> ASCII
$text =~ s/[\x{2018}\x{2019}]/'/g;
$text =~ s/[\x{201C}\x{201D}]/"/g;
$text =~ s/\x{2013}/-/g;

# ASCII double-hyphen (spaced only, avoids compound words)
$text =~ s/\s+--\s+/, /g;

# Double period -> ellipsis (OCR artifact); before ellipsis normalisation
$text =~ s/\.\.(?!\.)/.../g;

# Ellipsis normalisation
$text =~ s/\.{4,}/.../g;
$text =~ s/\.\s\.\s\./.../g;

# Repeated punctuation disasters from scanned/OCR text
$text =~ s/([!?]){2,}/$1/g;
$text =~ s/,{2,}/,/g;

# Stray spaces before punctuation
$text =~ s/\s+([,.!?])/$1/g;

# Missing space after ! and ? (periods left alone — too many decimal/abbrev traps)
$text =~ s/([!?])([^\s\n"'])/$1 $2/g;

# Missing space after comma — excludes digits to preserve "3,141" etc.
$text =~ s/,([^\s\n"'\d])/, $1/g;

# Semicolons -> commas (softer prosody boundary)
# Colons left alone — they introduce quotes/lists and carry their own rhythm
$text =~ s/;/,/g;

# ============================================================
# PHASE 5: ABBREVIATION & INITIAL PROTECTION
# ============================================================

my @abbrev_keys;
my $idx = 0;

# Normalise compact initials before protection rule runs
# "J.R.R." -> "J. R. R.",  "T.S." -> "T. S."
$text =~ s/\b([A-Z])\.([A-Z])\.([A-Z])\./$1. $2. $3./g;
$text =~ s/\b([A-Z])\.([A-Z])\./$1. $2./g;

# Protect spaced initials: "J. R. R." — prevents each dot reading as sentence end
$text =~ s/\b([A-Z])\.\s+(?=[A-Z]\.)/
    my $key = "\x00INIT${idx}\x00"; push @abbrev_keys, [$key, "$1. "]; $idx++; "$1$key"
/ge;

# Protect common abbreviations (military, government, academic, honorific,
# calendar, French titles, misc)
$text =~ s/\b(St|Mr|Mrs|Ms|Messrs|Mme|Mlle|Dr|Prof|Rev|Gen|Col|Capt|Lt|Sgt|Gov|Pres|Sr|Jr|Hon|Rt|Dept|Univ|No|Vol|Ch|vs|etc|cf|ed|Jan|Feb|Mar|Apr|Aug|Sept|Oct|Nov|Dec)\./
    my $key  = "\x00ABBRV${idx}\x00";
    my $orig = "$1.";
    push @abbrev_keys, [$key, $orig];
    $idx++;
    "$1$key"
/ge;

# ============================================================
# PHASE 6: PROSODY ADJUSTMENTS
# ============================================================

# Archaic contractions -> modern equivalents (improves phonemizer clarity)
$text =~ s/\btho'\b/though/gi;
$text =~ s/\bthro'\b/through/gi;
$text =~ s/\bo'er\b/over/gi;
$text =~ s/\bne'er\b/never/gi;
$text =~ s/\be'en\b/even/gi;

# Conjunction bridge: drop comma before coordinating conjunctions
$text =~ s/,\s+(and|but|or|nor|for|yet|so)\b/ $1/gi;

# Fix ", and then ," -> " and then " (sandwiched conjunction after dash conversion)
$text =~ s/,\s*(and|but|so|yet)\s*,/ $1 /gi;

# Soften sentence-initial bardic openers
$text =~ s/\.\s+(And|But|So|For|Yet|Nor|Then|Thereupon)\b/, \l$1/g;

# Downcase ALL-CAPS multi-word headings (2–6 words) so Kokoro doesn't shout them.
# Upper bound {1,5} prevents downcasing long proper-noun phrases like
# "UNITED STATES ARMY" which are content, not headings.
$text =~ s/^[A-Z0-9]+(?:\s+[A-Z0-9]+){1,5}$/\L$&/mg;

# ============================================================
# PHASE 7: ARTEFACT CLEANUP & RESTORATION
# ============================================================

$text =~ s/,(\s*,)+/,/g;    # collapse runs of commas
$text =~ s/,\s*\././g;      # orphaned comma before period

# Restore all protected tokens (initials and abbreviations)
for my $pair (@abbrev_keys) {
    my ($key, $orig) = @$pair;
    (my $prefix = $orig) =~ s/[\.\s]+$//;
    $text =~ s/\Q$prefix$key\E/$orig/g;
}

# ============================================================
# PHASE 8: FINAL WHITESPACE
# ============================================================

$text =~ s/[ \t]{2,}/ /g;
$text =~ s/\n{3,}/\n\n/g;
$text =~ s/^\s+//;

# ============================================================
# OUTPUT
# epub2tts-kokoro reads Title and Author from lines 1 and 2 only.
# All other audiobook metadata (genre, year, publisher) must be
# embedded post-process via ffmpeg on the final M4B file.
# ============================================================

print "Title: $TITLE\n";
print "Author: $AUTHOR\n\n";
print $text;
