;;; anki-whitespace.el --- A more lightweight syntax for anki-editor -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Tony Zorman
;;
;; Author: Tony Zorman <soliditsallgood@mailbox.org>
;; Keywords: convenience
;; Version: 0.1
;; Package-Requires: ((emacs "29.1") (anki-editor "0.3.3") (dash "2.19.1"))
;; Homepage: https://github.com/anki-editor/anki-whitespace

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or (at
;; your option) any later version.
;;
;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides an alternative syntax for `anki-editor', focusing
;; more on whitespace separated blocks, than full-blown headlines.  It is meant
;; to be used as an alternative to `anki-editor' when a lighter syntax may be
;; appropriate; for example, when integrating spaced-repetition notes into a
;; Zettelkasten-like system.

;;; Code:

(require 'anki-editor)
(require 'dash)

(defgroup anki-whitespace nil
  "Customizations for anki-whitespace."
  :group 'anki-editor)

(defcustom anki-whitespace-prefix ">>> "
  "Prefix of a note.
This is the prefix that `anki-whitespace' looks for when pushing notes
in the current region or buffer.  It should be \"unique enough\"—i.e.,
not commonly found in other text."
  :type 'string
  :group 'anki-whitespace)

(defcustom anki-whitespace-options '("deck" "type" "id" "title")
  "Options for notes.
These are the options that may appear after `anki-whitespace-prefix' in
a OPTION: VALUE fashion.  Will be sent to Anki as appropriate."
  :type '(repeat string)
  :group 'anki-whitespace)

(defcustom anki-whitespace-export-alist
  '(("Cloze" . anki-whitespace-export-cloze)
    ("Basic" . anki-whitespace-export-basic))
  "How to export the given note into an anki note type.
This is a list of (NAME . PARSE) pairs, where NAME corresponds to an
Anki note type, and PARSE is a function that gets the note extents as
its input, and produces a list of (FIELD . CONTENT) pairs to be pushed
to Anki.'"
  :type '(alist :key-type string :value-type function)
  :group 'anki-whitespace)

(defun anki-whitespace-export-cloze (_beg end)
  "Export the Cloze note from BEG to END."
  `(("Text" . ,(buffer-substring-no-properties (point) end))))

(defun anki-whitespace-export-basic (beg end)
  "Export the Basic note from BEG to END."
  (save-excursion
    (goto-char beg)
    (let ((case-fold-search nil))
      (when-let (q-start (search-forward-regexp "Q:\\( \\|\n\\)" end t))
        (when-let (a-start (search-forward-regexp "A:\\( \\|\n\\)" end t))
          `(("Front" . ,(buffer-substring-no-properties q-start (- a-start 4)))
            ("Back"  . ,(buffer-substring-no-properties a-start end))))))))

(defun anki-whitespace--get-whitespace-note ()
  "Get the beginning and end of the note at point.
Return a cons-cell of (BEG . END)."
  (save-excursion
    (let* ((sep "

")
           (beg (progn (re-search-backward sep)
                       (forward-char 2) ; Length sep
                       (point)))
           (end (if (re-search-forward sep (point-max) t)
                    (progn (backward-char 2)
                           (point))
                  ;; If we can't find a separator, just assume the note runs
                  ;; until the end of the buffer.
                  (point-max))))
      (cons beg end))))

(defun anki-whitespace--get-information (beg)
  "Return note information.
BEG marks the beginning of the note (see `anki-whitespace-prefix').
Gather all of the `anki-whitespace-options' we can find and returns an
alist with this information."
  (goto-char beg)
  (let ((opts (concat "\\(" (mapconcat #'identity anki-whitespace-options "\\|") "\\):\s"))
        (sep "\\(\s\\|,\\|\n\\)"))
    (save-match-data
      (let (res)
        (while (search-forward-regexp opts (pos-eol) t)
          (let* ((match (match-string-no-properties 1))
                 (pt (point))
                 (val (when (search-forward-regexp sep (1+ (pos-eol)) t)
                        (buffer-substring-no-properties
                         pt
                         (- (point)
                            (length (match-string-no-properties 1)))))))
            (push (cons match val) res)))
        (beginning-of-line 1)
        res))))

(defun anki-whitespace-note-at-point (old-fun)
  "Make a note struct from current entry.
OLD-FUN will be `anki-editor-note-at-point', which this function is
meant as `:around' advice for."
  (if (not anki-whitespace-mode)
      (funcall old-fun)
    (cl-flet ((get (key alist) (alist-get key alist nil nil #'string=)))
      (-let* (((beg . end) (anki-whitespace--get-whitespace-note))
              (info (anki-whitespace--get-information beg))
              (note-type (get "type" info))
              (fields (funcall (get note-type anki-whitespace-export-alist) (point) end))
              (deck (get "deck" info))
              (format (anki-editor-entry-format))
              (note-id (get "id" info))
              (tags (cl-set-difference (anki-editor--get-tags)
                                       anki-editor-ignored-org-tags
                                       :test #'string=))
              (exported-fields
               (--map (cons (car it) (anki-editor--export-string (cdr it) format))
                      fields)))
        (unless deck (user-error "Missing deck"))
        (unless note-type (user-error "Missing note type"))
        (make-anki-editor-note
         :id note-id
         :model note-type
         :deck deck
         :tags tags
         :fields exported-fields)))))

(defun anki-whitespace--delete-field (field)
  "Delete FIELD of the note at point."
  (save-mark-and-excursion
    (-let (((beg . _) (anki-whitespace--get-whitespace-note)))
      (goto-char beg)
      (search-forward-regexp (regexp-quote field) (pos-eol))
      (goto-char (match-beginning 0))
      (if (looking-back ",\s" (pos-bol))
          (progn (goto-char (match-beginning 0))
                 (push-mark)
                 (forward-char))
        (push-mark))
      (if (search-forward-regexp (regexp-quote ",") (pos-eol) t)
          (delete-region (mark) (1- (point)))
        (search-forward-regexp "$" (pos-eol) t)
        (delete-region (mark) (point))))))

(defun anki-whitespace-delete-note-at-point ()
  "Delete the note at point from Anki."
  (interactive)
  (save-excursion
    (let* ((note (anki-editor-note-at-point))
           (note-id (string-to-number (anki-editor-note-id note))))
      (when (not note-id)
        (user-error "Note at point is not in Anki (no note-id)"))
      (when (yes-or-no-p
             (format (concat "Do you really want to delete note %s " "from Anki?")
                     note-id))
        (anki-editor-api-call-result 'deleteNotes :notes (list note-id))
        (anki-whitespace--delete-field "id")
        (message "Deleted note %s from Anki" note-id)))))

(defun anki-whitespace--push-note-at-point (old-fun)
  "Push note at point to Anki.
OLD-FUN will be `anki-editor-push-note-at-point', which this function is
meant as `:around' advice for."
  (interactive)
  (if (not anki-whitespace-mode)
      (funcall old-fun)
    (anki-editor--push-note (anki-editor-note-at-point))
    (message "Successfully pushed note at point to Anki.")))

(defun anki-whitespace-push-notes-dwim (&optional begin end)
  "Push notes to Anki.
If BEGIN and END are given, push all notes in that region.  Otherwise,
push the note at point."
  (interactive "r")
  (if (and begin end)
      ;; Active region, so push all notes in it.
      (progn
        (goto-char begin)
        (while (and (> end (point))
                    (search-forward anki-whitespace-prefix end t))
          (anki-editor-push-note-at-point)))
    ;; No active region, so default to note at point.
    (anki-editor-push-note-at-point)))

(defun anki-whitespace-push-notes-in-buffer ()
  "Push all notes in the current buffer."
  (interactive)
  (anki-whitespace-push-notes-dwim (point-min) (point-max)))

(defun anki-whitespace--set-note-id (old-fun id)
  "Set note-id of anki-editor note at point to ID.
OLD-FUN will be `anki-editor--set-note-id', which this function is meant
as `:around' advice for."
  (if (not anki-whitespace-mode)
      (funcall old-fun id)
    (unless id
      (error "Note creation failed for unknown reason"))
    (-let (((beg . _) (anki-whitespace--get-whitespace-note)))
      (goto-char beg)
      (end-of-line)
      (insert ", id: " (number-to-string id)))))

;; TODO: things should perhaps have their own syntax?
(defun anki-whitespace-new-note (type deck)
  "Create a new note of TYPE in DECK."
  (interactive
   (list (completing-read "Note type: " (mapcar #'car anki-whitespace-export-alist))
         (completing-read "Deck: " (anki-editor-api-call-result 'deckNames))))
  (insert anki-whitespace-prefix)
  (insert "deck: " deck ", ")
  (insert "type: " type)
  (newline))

(define-minor-mode anki-whitespace-mode
  "A minor mode for making Anki cards with Org."
  :lighter " anki-whitespace"
  :keymap (make-sparse-keymap)
  (unless (equal major-mode 'org-mode)
    (user-error "Anki-whitespace only works in org-mode buffers"))
  (if anki-whitespace-mode
      (progn
        (anki-editor-setup-minor-mode)
        (advice-add 'anki-editor-note-at-point        :around   #'anki-whitespace-note-at-point)
        (advice-add 'anki-editor-push-note-at-point   :around   #'anki-whitespace--push-note-at-point)
        (advice-add 'anki-editor--set-note-id         :around   #'anki-whitespace--set-note-id)
        (advice-add 'anki-editor-delete-note-at-point :override #'anki-whitespace-delete-note-at-point))
    (anki-editor-teardown-minor-mode)
    (advice-remove 'anki-editor-note-at-point        #'anki-whitespace-note-at-point)
    (advice-remove 'anki-editor-push-note-at-point   #'anki-whitespace--push-note-at-point)
    (advice-remove 'anki-editor--set-note-id         #'anki-whitespace--set-note-id)
    (advice-remove 'anki-editor-delete-note-at-point #'anki-whitespace-delete-note-at-point)))

(provide 'anki-whitespace)
;;; anki-whitespace.el ends here
