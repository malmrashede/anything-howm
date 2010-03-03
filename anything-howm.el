;;; anything-howm.el

;; Copyright (C) 2009,2010  kitokitoki

;; Author: kitokitoki <morihenotegami@gmail.com>
;; Keywords: anything, howm
;; Prefix: anything-howm

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Installation:

;; install requires libraries:
;; `anything.el' http://www.emacswiki.org/emacs/anything.el
;; `anything-match-plugin.el'  http://www.emacswiki.org/emacs/anything-match-plugin.el
;; `anything-migemo.el' http://www.emacswiki.org/emacs/anything-migemo.el
;; `howm'  http://howm.sourceforge.jp/index-j.html

;; `anything-howm.el' http://github.com/kitokitoki/anything-howm (this file)

;;; Setting Sample

;; (require 'anything-howm)
;; (setq anything-howm-recent-menu-number-limit 70)
;; (setq anything-howm-data-directory "~/Dropbox/howm")
;; (global-set-key (kbd "M-h") 'anything-howm-menu-command)
;; (setq anything-sources
;;       (list anything-c-source-buffers
;;               ...
;;             ))
;; (setq anything-howm-data-directory "/home/taro/howm")

;; Change Log
;; 1.0.4: アクション"Open Marked howm file", "Delete file(s)" を作成
;; 1.0.3: メニュー用のソースを新規作成
;; 1.0.2: ファイル削除、新ウィンドウで開く、新フレームで開くアクションを追加
;;        リファクタリング
;; 1.0.1: 新しいメモをつくる機能を追加, migemo 対応
;; 1.0.0: 新規作成

;;; Commentary:

;;; Code:

(require 'cl)
(require 'anything)
(require 'anything-match-plugin)
(require 'anything-migemo)
(require 'howm)
(require 'howm-menu)

(defvar anything-howm-recent-menu-number-limit 10)
(defvar anything-howm-persistent-action-buffer "*howm-tmp*")
(defvar anything-howm-default-title "")
(defvar anything-howm-data-directory "/home")

(defvar anything-c-howm-recent
  '((name . "最近のメモ")
    (candidates .
      (lambda ()
        (anything-howm-get-recent-title-list
         (howm-recent-menu anything-howm-recent-menu-number-limit))))
    (candidate-number-limit . 9999)
    (action .
      (("Open howm file" .
          (lambda (candidate)
            (find-file
             (anything-howm-select-file-by-title candidate))))
       ("Open Marked howm file" .
          (lambda (candidate)
            (dolist (i (anything-marked-candidates))            
              (find-file
               (anything-howm-select-file-by-title i)))))
       ("Open howm file in other window" .
          (lambda (candidate)
            (find-file-other-window
             (anything-howm-select-file-by-title candidate))))
       ("Open howm file in other frame" .
          (lambda (candidate)
            (find-file-other-frame
             (anything-howm-select-file-by-title candidate))))
       ("Create new memo" .
          (lambda (template)
            (anything-howm-create-new-memo nil)))
       ("Create new memo on region" .
          (lambda (template)
            (anything-howm-create-new-memo (anything-howm-set-selected-text))))
       ("Delete file(s)" . anything-howm-delete-marked-files)))
    (persistent-action .
      (lambda (candidate)
        (anything-howm-persistent-action
         (anything-howm-select-file-by-title candidate))))
    (cleanup .
      (lambda ()
        (if (get-buffer anything-howm-persistent-action-buffer)
          (kill-buffer anything-howm-persistent-action-buffer))))
    (migemo)))

(defun anything-howm-persistent-action (c)
  (let ((b (get-buffer-create anything-howm-persistent-action-buffer)))
      (with-current-buffer b
        (erase-buffer)
        (insert-file-contents c)
        (goto-char (point-min)))
      (pop-to-buffer b)
      (howm-mode t)))

(defun anything-howm-select-file-by-title (title)
  (loop for recent-menu-x in (howm-recent-menu anything-howm-recent-menu-number-limit)
        for list-item-file  = (first recent-menu-x)
        for list-item-name  = (second recent-menu-x)
        if (string-equal title list-item-name)
          return list-item-file))

(defun anything-howm-get-recent-title-list (recent-menu-list)
  (loop for recent-menu-x in recent-menu-list
        for list-item-name  = (second recent-menu-x)
        collect list-item-name))

(defun anything-howm-create-new-memo (text)
  (let (memo-text str
        (cbuf (current-buffer)))
    (setq str text)
    (howm-create-file-with-title anything-howm-default-title nil nil nil nil)
    (save-excursion
      (goto-char (point-max))
      (insert str))
    (goto-char (point-min))
    (end-of-line)))

(defun anything-howm-delete-marked-files (candidate)
  (anything-aif (anything-marked-candidates)
      (if (y-or-n-p (format "Delete *%s Files " (length it)))
          (progn
            (dolist (i it)
              (set-text-properties 0 (length i) nil i)
              (delete-file
                (anything-howm-select-file-by-title i)))
            (message "%s Files deleted" (length it)))
          (message "(No deletions performed)"))
    (set-text-properties 0 (length candidate) nil candidate)
    (if (y-or-n-p
         (format "Really delete file `%s' " (anything-howm-select-file-by-title candidate)))
        (progn
          (delete-file
            (anything-howm-select-file-by-title candidate))
          (message "1 file deleted"))
        (message "(No deletions performed)"))))

(defun anything-howm-set-selected-text ()
  (if mark-active
      (buffer-substring-no-properties (region-beginning) (region-end))
    ""))

(defvar anything-howm-menu-list
      '(("1 メモを新規作成" . "(anything-howm-create-new-memo nil)")
        ("2 リージョンからメモを新規作成" . "(anything-howm-create-new-memo (anything-howm-set-selected-text))")
        ("3 予定(未着手)" . "(作成中)") ;todo
        ("4 grep 検索(作成中)" . "(作成中)") ;todo
        ("5 日付挿入" . "(howm-insert-date)")
        ))

(defvar anything-c-source-howm-menu
  '((name . "メニュー")
    (candidates . anything-howm-menu-list)    
    (type . sexp)
    (migemo)))

(defun anything-howm-menu-command ()
  (interactive)
  (anything-other-buffer
   '(anything-c-source-howm-menu
     anything-c-howm-recent)
   "*anything-howm-menu*"))

(provide 'anything-howm)