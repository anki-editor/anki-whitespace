# anki-whitespace

**This is alpha software; only a few features from `anki-editor` are supported right now.**

A minor mode building on [anki-editor], with a more lightweight syntax.
This is useful when notes are to be integrated into a Zettelkasten-like system, such as [org-roam] or [denote].
See for example [Andy Matuschak's notes] for why such an integration might be useful;
in particular, `anki-whitespace`'s syntax is heavily inspired by the mnemonic-medium.

See [anki-editor]'s README for information on external dependencies,
like [AnkiConnect],
and how to interact with them.

[anki-editor]: https://github.com/anki-editor/anki-editor
[org-roam]: https://github.com/org-roam/org-roam/
[denote]: https://github.com/protesilaos/denote
[AnkiConnect]: https://github.com/FooSoft/anki-connect

## Installation

### Using `package-vc.el`

If you are on Emacs 29 and newer, you can use `package-vc-install`:

``` emacs-lisp
(package-vc-install
 '(anki-editor . (:url "https://github.com/anki-editor/anki-whitespace")))
```

Additionally, [vc-use-package] provides use-package integration:

``` emacs-lisp
(use-package anki-editor
  :vc (:fetcher github :repo anki-editor/anki-whitespace))
```

Alternatively, if you're on Emacs 30, a `:vc` keyword is built into use-package:

``` emacs-lisp
(use-package anki-editor
  :vc (:url "https://github.com/anki-editor/anki-whitespace" :rev :newest))
```

[vc-use-package]: https://github.com/slotThe/vc-use-package

## Usage

### Note layout

By default[^1], a note is a separate paragraph of text,
prefixed by `anki-whitespace-prefix` (which defaults to `>>> `).
Followed by the prefix are any of the following options:

  - `deck`: the deck that the note should be filed under.
  - `type`: the note type (Basic, Cloze, …).
  - `id`: Anki note ID (filled in automatically by Anki).
  - `title`: optional title for the note.

You can add new options to `anki-whitespace-options`,
and adjust `anki-whitespace-note-at-point` as needed.

Any further syntax is determined by the note type.
The only steadfast rule is that everything has to be one paragraph.
The two builtin types, `Basic` and `Cloze`, specify the following rules:

  - The `Basic` type looks for two things:
    a question beginning with `"Q: "`, and an answer beginning with `"A: "`.
    For example:

        >>> deck: Default, type: Basic
        Q: A question
        A: An answer

        >>> deck: Default::Maths, type: Basic
        Q: A question
        A: An answer
        \[
          \LaTeX
        \]

  - The `Cloze` type simply looks for `anki-editor`-style cloze-deletions:

        >>> deck: Default, type: Cloze
        Please {{c1::complete}} my sentence

        >>> deck: Default::Misc, type: Cloze
        Please {{c1::complete}} my sentence {{c2::completely}}

### Commands

`anki-whitespace` doesn't bind to any keys,
and indeed doesn't provide all that many new commands;
rather, it augments—by means of `nadvice.el`—the commands of `anki-editor`.
So far, the following things are implemented (and thus usable in `anki-whitespace-mode`):

  - Pushing notes:
    `anki-editor-push-note-at-point`,
    `anki-whitespace-push-notes-in-buffer`,
    `anki-whitespace-push-notes-dwim`.

  - Creating new notes:
    `anki-whitespace-new-note`.

  - Deleting notes:
    `anki-editor-delete-note-at-point`.

In particular, these functionalities also work when invoked via `anki-editor-ui`.

[^1]: The code functionality is relatively little code,
      so the exact syntax of the notes is quite configurable.
