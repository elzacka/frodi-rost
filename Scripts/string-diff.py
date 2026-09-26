#!/usr/bin/env python3
"""Every user-facing string that changed since a commit.

    Scripts/string-diff.py <ref>

Prints the Norwegian string literals in Frodi/ and FrodiWidgets/ that were
removed (-) or added (+) between <ref> and the working tree. This is the
sign-off list a build upload waits for. Log lines and identifiers are left
out; a string that changed shows as one line removed and one added.
"""
import re
import subprocess
import sys

LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')


def literals(ref):
    if ref == "WORKTREE":
        files = subprocess.run(["git", "ls-files", "Frodi", "FrodiWidgets"], capture_output=True, text=True).stdout
        read = lambda f: open(f, encoding="utf-8").read()
    else:
        files = subprocess.run(["git", "ls-tree", "-r", "--name-only", ref, "Frodi", "FrodiWidgets"], capture_output=True, text=True).stdout
        read = lambda f: subprocess.run(["git", "show", f"{ref}:{f}"], capture_output=True, text=True).stdout
    found = set()
    for path in files.split("\n"):
        if not path.endswith(".swift"):
            continue
        for match in LITERAL.finditer(read(path)):
            text = match.group(1)
            if len(text) < 3 or text.startswith(("com.", "\\(", ".")):
                continue
            # One capitalised word is a button or a label: «Behold», «Opptak».
            word = re.fullmatch(r"[A-ZÆØÅ][a-zæøå]{2,}", text) is not None
            if not word and re.fullmatch(r"[A-Za-z0-9_\-\.\\\(\)/:%]+", text):
                continue
            if "privacy: .public" in text or text.startswith(("Recording ", "Live Activity ", "Interruption ", "Media services", "Seal of", "No container", "Empty recording")):
                continue
            if word or re.search(r"[æøåÆØÅ]", text) or (" " in text and text[0].isupper()):
                found.add(text)
    return found


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    before, after = literals(sys.argv[1]), literals("WORKTREE")
    for text in sorted(before - after):
        print(f"- {text}")
    for text in sorted(after - before):
        print(f"+ {text}")


if __name__ == "__main__":
    main()
