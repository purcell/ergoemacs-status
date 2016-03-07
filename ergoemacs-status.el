;;; ergoemacs-status.el --- Adapatave Status Bar / Mode Line -*- lexical-binding: t -*-
;; 
;; Filename: ergoemacs-status.el
;; Description: Adaptive Status Bar / Mode Line for Emacs
;; Author: Matthew Fidler
;; Maintainer: Matthew Fidler
;; Created: Fri Mar  4 14:13:50 2016 (-0600)
;; Version: 0.1
;; Package-Requires: ((powerline "2.3") (mode-icons "0.1.0"))
;;
;;; Commentary:
;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;; This program is free software: you can redistribute it and/or modify
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
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.
;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;;; Code:
(require 'powerline nil t)
(require 'mode-icons nil t)

(declare-function ergoemacs-next-emacs-buffer "ergoemacs-lib")
(declare-function ergoemacs-next-user-buffer "ergoemacs-lib")
(declare-function ergoemacs-previous-emacs-buffer "ergoemacs-lib")
(declare-function ergoemacs-previous-user-buffer "ergoemacs-lib")

(defvar ergoemacs-menu--get-major-modes)

(declare-function mode-icons-get-mode-icon "mode-icons")
(declare-function mode-icons-mode "mode-icons")
(declare-function mode-icons-propertize-mode "mode-icons")

(declare-function powerline-current-separator "powerline")
(declare-function powerline-selected-window-active "powerline")

(defvar ergoemacs-status-file (locate-user-emacs-file ".ergoemacs-status.el")
  "The `ergoemacs-status-mode' preferences file.")

(defcustom ergoemacs-status-popup-languages t
  "Allow Swapping of `major-modes' when clicking the `mode-name'."
  :type 'boolean
  :group 'ergoemacs-status)

(defcustom ergoemacs-status-change-buffer 'ergoemacs-status-group-function
  "Method of changing buffer."
  :type '(choice
	  (function :tag "Function to group buffers.")
	  (const :tag "Switch to next/previous user/emacs buffer." 'ergoemacs)
	  (const :tag "Use emacs default method." nil))
  :group 'ergoemacs-status)

(defface ergoemacs-status-selected-element
  '((t :background "#e6c200" :foreground "#0024e6" :inherit mode-line))
  "Face for the modeline in buffers with Flycheck errors."
  :group 'ergoemacs-status)

(defvar ergoemacs-status--major-mode-menu-map nil)

(defun ergoemacs-status--major-mode-menu-map (&optional _)
  "Popup major modes and information about current mode."
  (interactive)
  (or ergoemacs-status--major-mode-menu-map
      (set (make-local-variable 'ergoemacs-status--major-mode-menu-map)
	   (let ((map (and ergoemacs-status-popup-languages
			   ;; Mode in menu
			   (memq major-mode ergoemacs-menu--get-major-modes)
			   (key-binding [menu-bar languages])))
		 mmap)
	     (if (not map)
		 (mouse-menu-major-mode-map)
	       (setq mmap (mouse-menu-major-mode-map))
	       (define-key map [major-mode-sep-b] '(menu-item  "---"))
	       (define-key map [major-mode] (cons (nth 1 mmap) mmap))
	       map)))))

(defun ergoemacs-status-buffer-list ()
  "List of buffers shown in popup menu."
  (delq nil
        (mapcar #'(lambda (b)
                    (cond
                     ;; Always include the current buffer.
                     ((eq (current-buffer) b) b)
                     ((buffer-file-name b) b)
                     ((char-equal ?\  (aref (buffer-name b) 0)) nil)
                     ((buffer-live-p b) b)))
                (buffer-list))))

(defun ergoemacs-status-group-function (&optional buffer)
  "What group does the current BUFFER belong to?"
  (if (char-equal ?\* (aref (buffer-name buffer) 0))
      "Emacs Buffer"
    "User Buffer"))

(defun ergoemacs-status-menu (&optional buffer)
  "Create the BUFFER name menu."
  (let* ((cb (or buffer (current-buffer)))
	 (group (with-current-buffer cb
		  (if (functionp ergoemacs-status-change-buffer)
		      (funcall ergoemacs-status-change-buffer)
		    '("Common"))))
	 (groups '())
	 (buf-list (sort
		    (mapcar
		     ;; for each buffer, create list: buffer, buffer name, groups-list
		     ;; sort on buffer name; store to bl (buffer list)
		     (lambda (b)
		       (let (tmp0 tmp1 tmp2)
			 (with-current-buffer b
			   (setq tmp0 b
				 tmp1 (buffer-name b)
				 tmp2 (if (functionp ergoemacs-status-change-buffer)
					  (funcall ergoemacs-status-change-buffer)
					"Common"))
			   (unless (or (string= group tmp2) (assoc tmp2 groups))
			     (push (cons tmp2 (intern tmp2)) groups))
			   (list tmp0 tmp1 tmp2 (intern tmp1)))))
		     (ergoemacs-status-buffer-list))
		    (lambda (e1 e2)
		      (or (and (string= (nth 2 e2) (nth 2 e2))
			       (not (string-lessp (nth 1 e1) (nth 1 e2))))
			  (not (string-lessp (nth 2 e1) (nth 2 e2)))))))
	 menu menu2 tmp)
    (dolist (item buf-list)
      (if (string= (nth 2 item) group)
	  (unless (eq cb (nth 0 item))
	    (push `(,(nth 3 item) menu-item ,(nth 1 item) (lambda() (interactive) (funcall menu-bar-select-buffer-function ,(nth 0 item)))) menu))
	(if (setq tmp (assoc (nth 2 item) menu2))
	    (push `(,(nth 3 item) menu-item ,(nth 1 item) (lambda() (interactive) (funcall menu-bar-select-buffer-function ,(nth 0 item))))
		  (cdr tmp))
	  (push (list (nth 2 item) `(,(nth 3 item) menu-item ,(nth 1 item) (lambda() (interactive) (funcall menu-bar-select-buffer-function ,(nth 0 item))))) menu2))))
    (setq menu `(keymap ,(if (or menu (> (length menu2) 1))
			     group
			   (car (car menu2)))
			,@(if (or menu (> (length menu2) 1))
			      (mapcar
			       (lambda(elt)
				 `(,(intern (car elt)) menu-item ,(car elt) (keymap ,@(cdr elt))))
			       menu2)
			    (cdr (car menu2)))
			,(when (and menu (>= (length menu2) 1))
			   '(sepb menu-item "--"))
			,@menu))
    menu))

(defun ergoemacs-status-mouse-1-buffer (event)
  "Next ergoemacs buffer.

EVENT is where the mouse-click occured and is used to figure out
what window is associated with the mode-line click."
  (interactive "e")
  (with-selected-window (posn-window (event-start event))
    (let ((emacs-buffer-p (string-match-p "^[*]" (buffer-name))))
      (cond
       ((functionp ergoemacs-status-change-buffer)
	(popup-menu (ergoemacs-status-menu)))
       ((not ergoemacs-status-change-buffer)
	(next-buffer))
       (emacs-buffer-p
	(ergoemacs-next-emacs-buffer))
       (t
	(ergoemacs-next-user-buffer))))))

(defun ergoemacs-status-mouse-3-buffer (event)
  "Prevous ergoemacs buffer.

EVENT is where the mouse clicked and is used to figure out which
buffer is selected with mode-line click."
  (interactive "e")
  (with-selected-window (posn-window (event-start event))
    (let ((emacs-buffer-p (string-match-p "^[*]" (buffer-name))))
      (cond
       ((functionp ergoemacs-status-change-buffer)
	(popup-menu (ergoemacs-status-menu)))
       ((not ergoemacs-status-change-buffer)
	(previous-buffer))
       (emacs-buffer-p
	(ergoemacs-previous-emacs-buffer))
       (t
	(ergoemacs-previous-user-buffer))))))

(defcustom ergoemacs-status-minor-modes t
  "Include minor-modes in `mode-line-format'."
  :type 'boolean
  :group 'ergoemacs-status)

(defcustom ergoemacs-status-use-vc t
  "Include vc in mode-line."
  :type 'boolean
  :group 'ergoemacs-status)

(defun ergoemacs-status--property-substrings (str prop)
  "Return a list of substrings of STR when PROP change."
  ;; Taken from powerline by Donald Ephraim Curtis, Jason Milkins and
  ;; Nicolas Rougier
  (let ((beg 0) (end 0)
        (len (length str))
        (out))
    (while (< end (length str))
      (setq end (or (next-single-property-change beg prop str) len))
      (setq out (append out (list (substring str beg (setq beg end))))))
    out))

(defun ergoemacs-status--ensure-list (item)
  "Ensure that ITEM is a list."
  (or (and (listp item) item) (list item)))

(defun ergoemacs-status--add-text-property (str prop val)
  ;; Taken from powerline by Donald Ephraim Curtis, Jason Milkins and
  ;; Nicolas Rougier
  ;; Changed so that prop is not just 'face
  ;; Also changed to not force list, or add a nil to the list
  (mapconcat
   (lambda (mm)
     (let ((cur (get-text-property 0 prop mm)))
       (if (not cur)
	   (propertize mm prop val)
	 (propertize mm prop (append (ergoemacs-status--ensure-list cur) (list val))))))
   (ergoemacs-status--property-substrings str prop)
   ""))

(defun ergoemacs-status--if--1 (lst-or-string)
  (cond
   ((consp lst-or-string)
    (catch 'found-it
      (dolist (elt lst-or-string)
	(cond
	 ((functionp elt)
	  (let ((tmp (funcall elt)))
	    (if (or (and tmp (stringp tmp)) (listp tmp))
		(throw 'found-it tmp)
	      ;; Otherwise, assume its a boolean.
	      ;; If didn't
	      (when (and (booleanp tmp)
			 (not tmp))
		(throw 'found-it "")))))
	 
	 ((and elt (stringp elt))
	  (throw 'found-it elt))
	 ((and elt (consp elt))
	  (throw 'found-it elt))
	 ((and (symbolp elt) (boundp elt) (or (consp (symbol-value elt)) (stringp (symbol-value elt))))
	  (throw 'found-it (symbol-value elt)))))
      ""))
   ((and lst-or-string (stringp lst-or-string))
    lst-or-string)
   (t "")))

(defun ergoemacs-status--if (str &optional face pad)
  "Render STR as mode-line data using FACE and optionally PAD import on left (l), right (r) or both (b)."
  (let* ((rendered-str (format-mode-line (ergoemacs-status--if--1 str)))
	 (padded-str (concat
		      (when (and (> (length rendered-str) 0) (memq pad '(l left b both))) " ")
		      rendered-str
		      (when (and (> (length rendered-str) 0) (memq pad '(r right b both))) " "))))
    (if face
	(ergoemacs-status--add-text-property padded-str 'face face)
      padded-str)))

(defun ergoemacs-status--set-buffer-file-coding-system (event)
  "Set buffer file-coding.
EVENT tells what window to set the codings system."
  (interactive "e")
  (with-selected-window (posn-window (event-start event))
    (call-interactively #'set-buffer-file-coding-system)))

(defun ergoemacs-status--encoding ()
  "Encoding mode-line."
  (propertize (format "%s" (coding-system-type buffer-file-coding-system))
	      'mouse-face 'mode-line-highlight
	      'help-echo (format "mouse-1: Change buffer coding system\n%s"
				 (coding-system-doc-string buffer-file-coding-system))
	      'local-map '(keymap
			   (mode-line keymap
				      (mouse-1 . ergoemacs-status--set-buffer-file-coding-system)))))

(defvar powerline-default-separator-dir)
(defun ergoemacs-status--sep (dir &rest args)
  "Separator with DIR.
The additional ARGS are the fonts applied.  This uses `powerline' functions."
  (let ((separator (and (fboundp #'powerline-current-separator)
			(intern (format "powerline-%s-%s"
					(powerline-current-separator)
					(or (and (eq dir 'left)
						 (car powerline-default-separator-dir))
					    (cdr powerline-default-separator-dir))))))
	(args (mapcar
	       (lambda(f)
		 (let ((fa (assoc f face-remapping-alist)))
		   (if fa
		       (car (cdr fa))
		     f)))
	       args)))
    (when (fboundp separator)
      (let ((img (apply separator args)))
	(when (and (listp img) (eq 'image (car img)))
	  (propertize " " 'display img
		      'face (plist-get (cdr img) :face)))))))

(defvar ergoemacs-status--lhs nil)
(defvar ergoemacs-status--center nil)
(defvar ergoemacs-status--rhs nil)

(defvar ergoemacs-status--space-hidden-minor-modes nil
  "List of minor modes hidden due to space limitations.")

;; Adapted from powerline.
(defvar ergoemacs-status--suppressed-minor-modes '(isearch-mode)
  "List of suppressed minor modes.")


(defun ergoemacs-minor-mode-menu-from-indicator (indicator &optional dont-popup)
  "Show menu for minor mode specified by INDICATOR.

Interactively, INDICATOR is read using completion.
If there is no menu defined for the minor mode, then create one with
items `Turn Off', `Hide' and `Help'.

When DONT-POPUP is non-nil, return the menu without actually popping up the menu."
  (interactive
   (list (completing-read
	  "Minor mode indicator: "
	  (describe-minor-mode-completion-table-for-indicator))))
  (let* ((minor-mode (or (and (stringp indicator) (lookup-minor-mode-from-indicator indicator))
			 (and (symbolp indicator) indicator)))
         (mm-fun (or (get minor-mode :minor-mode-function) minor-mode)))
    (unless minor-mode (error "Cannot find minor mode for `%s'" indicator))
    (let* ((map (cdr-safe (assq minor-mode minor-mode-map-alist)))
           (menu (and (keymapp map) (lookup-key map [menu-bar])))
	   (hidden (memq minor-mode ergoemacs-status--space-hidden-minor-modes)))
      (setq menu
            (if menu
                (if hidden
		    (mouse-menu-non-singleton menu)
		  `(,@(mouse-menu-non-singleton menu)
		    (sep-minor-mode-ind menu-item "--")
		    (hide menu-item ,(if dont-popup
					 "Show this minor-mode"
				       "Hide this minor-mode")
			  (lambda () (interactive)
			    (ergoemacs-minor-mode-hide ',mm-fun ,dont-popup)))))
	      `(keymap
                ,indicator
                (turn-off menu-item "Turn Off minor mode" ,mm-fun)
		,(if hidden nil
		   `(hide menu-item ,(if dont-popup
				     "Show this minor-mode"
				   "Hide this minor-mode")
		      (lambda () (interactive)
			(ergoemacs-minor-mode-hide ',mm-fun ,dont-popup))))
                (help menu-item "Help for minor mode"
                      (lambda () (interactive)
                        (describe-function ',mm-fun))))))
      (if dont-popup menu
	(popup-menu menu)))))

(defun ergoemacs-status--minor-mode-mouse (click-group click-type string)
  "Return mouse handler for CLICK-GROUP given CLICK-TYPE and STRING."
  ;; Taken from Powerline
  (cond ((eq click-group 'minor)
         (cond ((eq click-type 'menu)
                `(lambda (event)
                   (interactive "@e")
                   (ergoemacs-minor-mode-menu-from-indicator ,string)))
               ((eq click-type 'help)
                `(lambda (event)
                   (interactive "@e")
                   (describe-minor-mode-from-indicator ,string)))
               (t
                `(lambda (event)
                   (interactive "@e")
                   nil))))
        (t
         `(lambda (event)
            (interactive "@e")
            nil))))

(defvar ergoemacs-status--hidden-minor-modes '()
  "List of tempoarily hidden modes.")

(defun ergoemacs-status-save-file--sym (sym)
  "Print SYM Emacs Lisp value in current buffer."
  (let ((print-level nil)
          (print-length nil))
      (insert "(setq " (symbol-name sym) " '")
      (prin1 (symbol-value sym) (current-buffer))
      (goto-char (point-max))
      (insert ")\n")))

(defvar ergoemacs-status-save-symbols
  '(ergoemacs-status--hidden-minor-modes
    ergoemacs-status--suppressed-minor-modes
    ergoemacs-status-current
    ergoemacs-status--suppressed-elements)
  "List of symbols to save in `ergoemacs-status-file'.")

(defun ergoemacs-status-save-file ()
  "Save preferences to `ergoemacs-status-file'."
  (with-temp-file ergoemacs-status-file
    (insert ";; -*- coding: utf-8-emacs -*-\n"
	    ";; This file is automatically generated by the `ergoemacs-status-mode'.\n")
    (dolist (sym ergoemacs-status-save-symbols)
      (ergoemacs-status-save-file--sym sym))
    (insert "(ergoemacs-status-current-update)\n;;; end of file\n")))

(defun ergoemacs-minor-mode-hide (minor-mode &optional show)
  "Hide a minor-mode based on mode indicator MINOR-MODE.

When SHOW is non-nil, show instead of hide the MINOR-MODE.
u
This function also saves your prefrences to
`ergoemacs-status-file' by calling the function
`ergoemacs-status-save-file'."
  (if show
      (setq ergoemacs-status--hidden-minor-modes (delq minor-mode ergoemacs-status--hidden-minor-modes))
    (unless (memq minor-mode ergoemacs-status--hidden-minor-modes)
      (push minor-mode ergoemacs-status--hidden-minor-modes)))
  (ergoemacs-status-save-file)
  (force-mode-line-update))

(defun ergoemacs-minor-mode-hidden-menu (&optional _event)
  "Display a list of the hidden minor modes."
  (interactive "@e")
  (popup-menu
   `(keymap
     ,@(mapcar
       (lambda(m)
	 `(,m menu-item ,(format "%s" m) ,(ergoemacs-minor-mode-menu-from-indicator m t)))
       (let (ret)
	 (dolist (elt (append ergoemacs-status--hidden-minor-modes
			      ergoemacs-status--space-hidden-minor-modes))
	   (when (and (boundp elt) (symbol-value elt))
	     (push elt ret)))
	 ret)))))

(defun ergoemacs-minor-mode-alist ()
  "Get a list of the minor-modes"
  (let (ret)
    (dolist (a (reverse minor-mode-alist))
      (unless (memq (car a) (append ergoemacs-status--hidden-minor-modes ergoemacs-status--suppressed-minor-modes))
	(push a ret)))
    ret))

(defvar ergoemacs-status--minor-modes-p t
  "Determine if `ergoemacs-status--minor-modes' generates space")

(defvar ergoemacs-status--minor-modes-available nil)
(defun ergoemacs-status--minor-modes-available (mode-line face1 face2 &optional reduce)
  (let (lhs rhs center)
    (setq ergoemacs-status--minor-modes-p nil)
    (unwind-protect
	(setq lhs (ergoemacs-status--eval-lhs mode-line face1 face2 reduce)
	      rhs (ergoemacs-status--eval-rhs mode-line face1 face2 reduce)
	      center (ergoemacs-status--eval-center mode-line face1 face2))
      (setq ergoemacs-status--minor-modes-p t
	    ergoemacs-status--minor-modes-available (- (ergoemacs-status--eval-width)
						     (+ (ergoemacs-status--eval-width lhs)
							(ergoemacs-status--eval-width rhs)
							(ergoemacs-status--eval-width center)))))))
(defun ergoemacs-status--minor-modes ()
  "Get minor modes."
  (let* ((width 0)
	 (ret ""))
    (when ergoemacs-status--minor-modes-p
      (setq ergoemacs-status--space-hidden-minor-modes nil
	    ret (replace-regexp-in-string
		 " +$" ""
		 (concat
		  (mapconcat (lambda (mm)
			       (if (or (not (numberp ergoemacs-status--minor-modes-available))
				       (< width ergoemacs-status--minor-modes-available))
				   (let ((cur (propertize mm
							  'mouse-face 'mode-line-highlight
							  'help-echo "Minor mode\n mouse-1: Display minor mode menu\n mouse-2: Show help for minor mode\n mouse-3: Toggle minor modes"
							  'local-map (let ((map (make-sparse-keymap)))
								       (define-key map
									 [mode-line down-mouse-1]
									 (ergoemacs-status--minor-mode-mouse 'minor 'menu mm))
								       (define-key map
									 [mode-line mouse-2]
									 (ergoemacs-status--minor-mode-mouse 'minor 'help mm))
								       (define-key map
									 [mode-line down-mouse-3]
									 (ergoemacs-status--minor-mode-mouse 'minor 'menu mm))
								       (define-key map
									 [header-line down-mouse-3]
									 (ergoemacs-status--minor-mode-mouse 'minor 'menu mm))
								       map))))
				     (setq width (+ width (ergoemacs-status--eval-width cur) 1))
				     (if (or (not (numberp ergoemacs-status--minor-modes-available))
					     (< width ergoemacs-status--minor-modes-available))
					 cur
				       (push (lookup-minor-mode-from-indicator mm) ergoemacs-status--space-hidden-minor-modes)
				       ""))
				 (push (lookup-minor-mode-from-indicator mm) ergoemacs-status--space-hidden-minor-modes)
				 ""))
			     (split-string (format-mode-line (ergoemacs-minor-mode-alist)))
			     " ")))))
    (when (or (not ergoemacs-status--minor-modes-p)
	      ergoemacs-status--space-hidden-minor-modes
	      (catch 'found
		(dolist (elt ergoemacs-status--hidden-minor-modes)
		  (when (and (boundp elt) (symbol-value elt))
		    (throw 'found t)))
		nil))
      (setq ret (concat ret " "
			(propertize (if (and (fboundp #'mode-icons-propertize-mode))
					(mode-icons-propertize-mode "+" (list "+" #xf151 'FontAwesome))
				      "+")
				    'mouse-face 'mode-line-highlight
				    'help-echo "Hidden Minor Modes\nmouse-1: Display hidden minor modes"
				    'local-map (let ((map (make-sparse-keymap)))
						 (define-key map [mode-line down-mouse-1] 'ergoemacs-minor-mode-hidden-menu)
						 (define-key map [mode-line down-mouse-3] 'ergoemacs-minor-mode-hidden-menu)
						 map)))))
    ret))

(defvar ergoemacs-status-position-map
  (let ((map (copy-keymap mode-line-column-line-number-mode-map)))
    ;; (define-key map [mode-line down-mouse-3]
    ;;   (lookup-key map [mode-line down-mouse-1]))
    ;; (define-key (lookup-key map [mode-line down-mouse-3])
    ;;   [size-indication-mode]
    ;;   '(menu-item "Display Buffer Size"
    ;; 		  size-indication-mode
    ;; 		  :help "Toggle displaying file size in the mode-line"
    ;; 		  :button (:toggle . size-indication-mode)))
    (define-key map [mode-line down-mouse-1] 'ignore)
    (define-key map [mode-line mouse-1] 'ergoemacs-status-goto-line)
    map)
  "Position map (includes function `size-indication-mode').")

(defun ergoemacs-status-goto-line (event)
  (interactive "e")
  (with-selected-window (posn-window (event-start event))
    (call-interactively #'goto-line)))

(defun ergoemacs-status-position ()
  "`ergoemacs-status-mode' line position."
  (let ((col (propertize
	      (or (and line-number-mode "%3c") "")
	      'mouse-face 'mode-line-highlight
	      'local-map ergoemacs-status-position-map)))
    (when  (>= (current-column) 80)
      (setq col (propertize col 'face 'error)))
    (concat (format-mode-line mode-line-position)
	    (propertize
	     (or (and column-number-mode "%4l") "")
	     ;; 'face 'bold
	     'mouse-face 'mode-line-highlight
	     'local-map ergoemacs-status-position-map)
	    (or (and column-number-mode line-number-mode ":") "")
	    col)))

(defun ergoemacs-status-size-indication-mode ()
  "Gives mode-line information when variable `size-indication-mode' is non-nil."
  (when size-indication-mode
    (propertize
     "%I"
     'mouse-face 'mode-line-highlight
     'local-map ergoemacs-status-position-map)))

(defun ergoemacs-status--read-only ()
  "Gives read-only indicator."
  (propertize (mode-icons--read-only-status)
	      'face 'mode-line-buffer-id))

(defun ergoemacs-status--modified ()
  "Gives modified indicator."
  (when (buffer-file-name)
    (propertize (mode-icons--modified-status)
		'face 'mode-line-buffer-id)))

(defcustom ergoemacs-status-elements
  '((:read-only (ergoemacs-status--read-only) 3 nil "Read Only Indicator")
    (:buffer-id (ergoemacs-status-buffer-id) nil nil "Buffer Name")
    (:modified (ergoemacs-status--modified) nil nil "Modified Indicator")
    (:size (ergoemacs-status-size-indication-mode) 2 nil "Buffer Size")
    (:position (ergoemacs-status-position) 2 "Line/Column")
    (:vc (ergoemacs-status-use-vc powerline-vc) 1 l "Version Control")
    (:minor (ergoemacs-status--minor-modes)  4 r "Minor Mode List")
    (:narrow (mode-icons--generate-narrow) 4 r "Narrow Indicator")
    (:global (global-mode-string) nil nil "Global String")
    (:coding ((lambda() (not (string= "undecided" (ergoemacs-status--encoding)))) ergoemacs-status--encoding) 2 nil "Coding System")
    (:eol ((lambda() (not (string= ":" (mode-line-eol-desc)))) mode-icons--mode-line-eol-desc mode-line-eol-desc) 2 nil "End Of Line Convention")
    (:major (ergoemacs-status-major-mode-item) nil nil "Language/Major mode")
    (:which-func (ergoemacs-status-which-function-mode) nil nil "Which function")
    (:process (mode-line-process) 1 nil "Process"))
  "Elements of mode-line recognized by `ergoemacs-status-mode'.

This is a list of element recognized by `ergoemacs-status-mode'."
  :type '(repeat
	  (list
	   (symbol :tag "Element Name")
	   (sexp :tag "Element Expression")
	   (choice :tag "How this element is collapsed"
	     (const :tag "Always keep this element" nil)
	     (integer :tag "Reduction Level"))
	   (choice :tag "Default padding of this element"
		   (const :tag "Left Padding" l)
		   (const :tag "Right Padding" r)
		   (const :tag "Left and Right Padding" b)
		   (const :tag "No Padding" nil))
	   (choice :tag "Description"
		   (const :tag "No Description")
		   (string :tag "Description"))))
  :group 'ergoemacs-status)

(defun ergoemacs-status-elements-toggle (elt)
  "Toggle the display of ELT."
  (if (memq elt ergoemacs-status--suppressed-elements)
      (setq ergoemacs-status--suppressed-elements (delq elt ergoemacs-status--suppressed-elements))
    (push elt ergoemacs-status--suppressed-elements))
  (ergoemacs-status-save-file)
  (ergoemacs-status-current-update)
  (force-mode-line-update))

(defun ergoemacs-status-right-click (event)
  "Right click context menu for EVENT."
  (interactive "e")
  (with-selected-window (posn-window (event-start event))
    (ergoemacs-status-elements-popup)))

(defun ergoemacs-status-elements-popup (&optional dont-popup)
  "Popup menu about displayed `ergoemacs-status' elements.
When DONT-POPUP is non-nil, just return the menu"
  (let ((map (make-sparse-keymap "Display Status Bar"))
	(i 0)
	tmp)
    (dolist (elt (append (plist-get ergoemacs-status-current :left)
			 (list "--")
			 (plist-get ergoemacs-status-current :center)
			 (list "--")
			 (plist-get ergoemacs-status-current :right)))
      (cond
       ((equal elt "--")
	(define-key map (vector (intern (format "status-element-popup-sep-%s" i))) '(menu-item  "---")))
       ((consp elt)
	(dolist (group-elt elt)
	  (when (setq elt (assoc group-elt ergoemacs-status-elements))
	    (define-key map (vector (car elt))
	      `(menu-item ,(nth 4 elt) (lambda(&rest _) (interactive) (ergoemacs-status-elements-toggle ,(car elt)))
			  :button (:toggle . (not (memq ,(car elt) ergoemacs-status--suppressed-elements))))))))
       (t
	(when (setq elt (assoc elt ergoemacs-status-elements))
	  (define-key map (vector (car elt))
	    `(menu-item ,(nth 4 elt) (lambda(&rest _) (interactive) (ergoemacs-status-elements-toggle ,(car elt)))
			:button (:toggle . (not (memq ,(car elt) ergoemacs-status--suppressed-elements))))))))
      (setq i (1+ i)))
    (popup-menu map)))

(defvar ergoemacs-status-current nil
  "Current layout of mode-line.")

(defun ergoemacs-status--atom ()
  "Atom style layout."
  (setq ergoemacs-status-current
	'(:left ((:read-only :buffer-id :modified) :size :position :vc)
		:center ((:minor :narrow))
		:right (:global :coding :eol :major)))
  (ergoemacs-status-current-update)
  (force-mode-line-update))

(defvar ergoemacs-status-buffer-id-map
  (let ((map (make-sparse-keymap)))
    (define-key map [mode-line mouse-1] #'ergoemacs-status-mouse-1-buffer)
    (define-key map [mode-line mouse-3] #'ergoemacs-status-mouse-3-buffer)
    map)
  "Keymap for clicking on the buffer status.")

(defun ergoemacs-status-buffer-id ()
  "Gives the Buffer identification string."
  (propertize "%12b"
	      'mouse-face 'mode-line-highlight
	      'face 'mode-line-buffer-id
	      'local-map ergoemacs-status-buffer-id-map
	      'help-echo "Buffer name\nBuffer menu"))

(defvar ergoemacs-status-major-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [mode-line down -mouse-3] (lookup-key mode-line-major-mode-keymap [mode-line down-mouse-3]))
    (define-key map [mode-line mouse-2] #'describe-mode)
    (define-key map [mode-line down-mouse-1]
      `(menu-item "Menu Bar" ignore :filter ergoemacs-status--major-mode-menu-map))
    map)
  "Major mode keymap.")

(defun ergoemacs-status-major-mode-item ()
  "Gives major-mode item for mode-line."
  (propertize mode-name
	      'mouse-face 'mode-line-highlight
	      'local-map ergoemacs-status-major-mode-map
	      'help-echo "Major mode\nmouse-1: Display major mode menu\nmouse-2: Show help for major mode\nmouse-3: Toggle minor modes"))

(defvar which-func-format)
(defun ergoemacs-status-which-function-mode ()
  "Display `which-function-mode' without brackets."
  (when (and (boundp 'which-function-mode) which-function-mode)
    (substring (format-mode-line which-func-format) 1 -1)))


(defvar ergoemacs-status--suppressed-elements nil
  "List of suppressed `ergoemacs-status' elements.")

(defun ergoemacs-status-current-update (&optional theme-list direction)
  "Update mode-line processing based on `ergoemacs-status-current'."
  (if (not direction)
      (setq ergoemacs-status--lhs (ergoemacs-status-current-update (plist-get ergoemacs-status-current :left) :left)
	    ergoemacs-status--center (ergoemacs-status-current-update (plist-get ergoemacs-status-current :center) :center) 
	    ergoemacs-status--rhs (ergoemacs-status-current-update (plist-get ergoemacs-status-current :right) :right))
    (let (ret
	  stat-elt
	  pad
	  reduce
	  ifc
	  lst tmp1 tmp2 tmp3
	  first-p
	  last-p)
      (dolist (elt (reverse theme-list))
	(setq first-p t)
	(if (consp elt)
	    (dolist (combine-elt (reverse elt))
	      (when (setq stat-elt (and (not (memq combine-elt ergoemacs-status--suppressed-elements))
					(assoc combine-elt ergoemacs-status-elements)))
		(setq ifc (nth 1 stat-elt)
		      reduce (nth 2 stat-elt)
		      pad (nth 3 stat-elt)
		      last-p (eq (car theme-list) combine-elt) 
		      pad (cond
			   ((and (and (not first-p) (not last-p))
				 (not pad)) 'r)
			   ((and (and (not first-p) (not last-p))
				 (eq pad 'r)) nil)
			   ((and (and (not first-p) (not last-p))
				 (eq pad 'l))
			    ;; Modify last interaction, if possible
			    (setq tmp1 (pop ret)
				  tmp2 (pop tmp1)
				  tmp3 (plist-get tmp1 :pad))
			    (prog1 'r
			      ;; drop right padding (if possible)
			      (cond
			       ((eq tmp3 'b)
				(setq tmp1 (plist-put tmp1 :pad 'l)))
			       ((eq tmp3 'r)
				(setq tmp1 (plist-put tmp1 :pad nil)))))
			    (push tmp2 tmp1)
			    (push tmp1 ret))
			   ;; Otherwise
			   ((not pad) 'b)
			   ((eq pad 'l) 'r)
			   ((eq pad 'r) 'l)
			   ((eq pad 'b)) nil)
		      lst nil)
		(when pad
		  (push pad lst)
		  (push :pad lst))
		(when reduce
		  (push reduce lst)
		  (push :reduce lst))
		(push elt lst)
		(push :element lst)
		(unless (or (and last-p (not (eq direction :right)))
			    (and first-p (eq direction :right)))
		  (push t lst)
		  (push :last-p lst))
		(push ifc lst)
		(push lst ret)
		(setq first-p nil)))
	  (when (setq stat-elt (and (not (memq elt ergoemacs-status--suppressed-elements))
				    (assoc elt ergoemacs-status-elements)))
	    (setq ifc (nth 1 stat-elt)
		  reduce (nth 2 stat-elt)
		  pad (nth 3 stat-elt)
		  pad (cond
		       ((and (eq :center direction)
			     (and ret (not (eq (car theme-list) elt)))
			     (not pad)) 'r)
		       ((and (eq :center direction)
			     (and ret (not (eq (car theme-list) elt)))
			     (eq pad 'r)) nil)
		       ((and (eq :center direction)
			     (and ret (not (eq (car theme-list) elt)))
			     (eq pad 'l))
			;; Modify last interaction, if possible
			(setq tmp1 (pop ret)
			      tmp2 (pop tmp1)
			      tmp3 (plist-get tmp1 :pad))
			(prog1 'r
			  ;; drop right padding (if possible)
			  (cond
			   ((eq tmp3 'b)
			    (setq tmp1 (plist-put tmp1 :pad 'l)))
			   ((eq tmp3 'r)
			    (setq tmp1 (plist-put tmp1 :pad nil)))))
			(push tmp2 tmp1)
			(push tmp1 ret)) 
		       ;; :center and (not ret)
		       ((not pad) 'b)
		       ((eq pad 'l) 'r)
		       ((eq pad 'r) 'l)
		       ((eq pad 'b)) nil)
		  lst nil)
	    (when pad
	      (push pad lst)
	      (push :pad lst))
	    (when reduce
	      (push reduce lst)
	      (push :reduce lst))
	    (push elt lst)
	    (push :element lst)
	    (push ifc lst)
	    (push lst ret))))
      ret)))
(defun ergoemacs-status--center ()
  "Center theme."
  (setq ergoemacs-status-current
	'(:left (:major :which :vc :size :position)
		 :center (:read-only :buffer-id :modified)
		 :right (:global :process :coding :eol (:minor :narrow))))
  (ergoemacs-status-current-update)
  (force-mode-line-update))

(defun ergoemacs-status--xah ()
  "Xah theme"
  (setq ergoemacs-status-current
	'(:left ((:read-only :buffer-id :modified) :size :position :major :global)))
  (ergoemacs-status-current-update)
  (force-mode-line-update))

(ergoemacs-status--center)

(defun ergoemacs-status--eval-center (mode-line face1 _face2 &optional reduce)
  (ergoemacs-status--stack ergoemacs-status--center mode-line face1 'center reduce))

(defun ergoemacs-status--eval-lhs (mode-line face1 _face2 &optional reduce)
  (ergoemacs-status--stack ergoemacs-status--lhs mode-line face1 'left reduce))

(defun ergoemacs-status--eval-rhs (mode-line face1 _face2 &optional reduce)
  (ergoemacs-status--stack ergoemacs-status--rhs mode-line face1 'right reduce))


(defvar ergoemacs-status-down-element nil)

(defvar ergoemacs-status--eval nil)

(defun ergoemacs-status-hover (x-position)
  "Get the hover element at the X-POSITION."
  (let ((i 0))
    (catch 'found
      (dolist (elt ergoemacs-status--eval)
	(setq i (+ i (nth 1 elt)))
	(when (<= x-position i)
	  (throw 'found (nth 0 elt))))
      nil)))

(defun ergoemacs-status-swap-hover-- (elt hover)
  "Internal function for `ergoemacs-status-swap-hover'.
Swaps ELT based on HOVER element and `ergoemacs-status-down-element'"
  (cond
   ((equal elt hover)
    ergoemacs-status-down-element)
   ((equal elt ergoemacs-status-down-element)
    hover)
   (t elt)))

(defun ergoemacs-status-swap-hover (hover)
  "Change `ergoemacs-status-current' baesd on swapping HOVER
element with `ergoemacs-status-down-element' element."
  (when ergoemacs-status-down-element
    (let* ((left (plist-get ergoemacs-status-current :left))
	   (center (plist-get ergoemacs-status-current :center))
	   (right (plist-get ergoemacs-status-current :right))
	   (down (cond
		  ((member ergoemacs-status-down-element left) 'left)
		  ((member ergoemacs-status-down-element center) 'center)
		  ((member ergoemacs-status-down-element right) 'right)))
	   (hover-region (cond
			  ((member hover left) 'left)
			  ((member hover center) 'center)
			  ((member hover right) 'right)))
	   ;; (left-p (member ergoemacs-status-down-element left))
	   ;; (left (mapcar (lambda(elt) (ergoemacs-status-swap-hover-- elt hover)) (plist-get ergoemacs-status-current :left)))
	   ;; (center (mapcar (lambda(elt) (ergoemacs-status-swap-hover-- elt hover)) (plist-get ergoemacs-status-current :center)))
	   ;; (right (mapcar (lambda(elt) (ergoemacs-status-swap-hover-- elt hover)) (plist-get ergoemacs-status-current :right)))
	   tmp)
      (cond
       ;; Same element.
       ((and (eq down hover-region) (eq down 'left))
	(setq left (mapcar (lambda(elt) (ergoemacs-status-swap-hover-- elt hover)) left)))
       ((and (eq down hover-region) (eq down 'center))
	(setq center (mapcar (lambda(elt) (ergoemacs-status-swap-hover-- elt hover)) center)))
       ((and (eq down hover-region) (eq down 'right))
	(setq right (mapcar (lambda(elt) (ergoemacs-status-swap-hover-- elt hover)) right)))
       ;; left->center
       ((and (eq down 'left) (eq hover-region 'center))
	(setq left (reverse left))
	(push (pop left) center)
	(setq left (reverse left)))
       ;; center->left
       ((and (eq down 'center) (eq hover-region 'left))
	(setq left (reverse left))
	(push (pop center) left)
	(setq left (reverse left)))
       ;; left->right
       ((and (eq down 'left) (eq hover-region 'right))
	(setq left (reverse left))
	(push (pop left) right)
	(setq left (reverse left)))
       ;; right->left
       ((and (eq down 'right) (eq hover-region 'left))
	(setq left (reverse left))
	(push (pop right) left)
	(setq left (reverse left)))
       ;; center->right
       ((and (eq down 'center) (eq hover-region 'right))
	(setq center (reverse center))
	(push (pop center) right)
	(setq center (reverse center)))
       ;; right->center
       ((and (eq down 'right) (eq hover-region 'center))
	(setq center (reverse center))
	(push (pop right) center)
	(setq center (reverse center)))
       )
      (setq ergoemacs-status-current `(:left ,left :center ,center :right ,right))
      (ergoemacs-status-current-update)
      (force-mode-line-update))))

(defun ergoemacs-status-down (start-event)
  "Handle down-mouse events on `mode-line'."
  (interactive "e")
  (let* ((start (event-start start-event))
	 (window (posn-window start))
	 (frame (window-frame window))
	 (object (posn-object start))
	 (minibuffer-window (minibuffer-window frame))
	 (element (and (stringp (car object))
		       (get-text-property (cdr object) :element (car object))))
	 hover finished event position)
    (setq ergoemacs-status-down-element element)
    (force-mode-line-update)
    (track-mouse
      (while (not finished)
	(setq event (read-event)
	      position (mouse-position))
	;; Do nothing if
	;;   - there is a switch-frame event.
	;;   - the mouse isn't in the frame that we started in
	;;   - the mouse isn't in any Emacs frame
	;; Drag if
	;;   - there is a mouse-movement event
	;;   - there is a scroll-bar-movement event (Why? -- cyd)
	;;     (same as mouse movement for our purposes)
	;; Quit if
	;;   - there is a keyboard event or some other unknown event.
	(cond
	 ((not (consp event))
	  (setq finished t))
	 ((memq (car event) '(switch-frame select-window))
	  nil)
	 ((not (memq (car event) '(mouse-movement scroll-bar-movement)))
	  (when (consp event)
	    ;; Do not unread a drag-mouse-1 event to avoid selecting
	    ;; some other window.  For vertical line dragging do not
	    ;; unread mouse-1 events either (but only if we dragged at
	    ;; least once to allow mouse-1 clicks get through).
	    (unless (eq (car event) 'drag-mouse-1)
	      (push event unread-command-events)))
	  (setq finished t))
	 ((not (and (eq (car position) frame)
		    (cadr position)))
	  nil))
	(when (and (not finished))
	  (setq hover (ergoemacs-status-hover (car (cdr position))))
	  (when hover
	    (ergoemacs-status-swap-hover hover)))))
    (setq ergoemacs-status-down-element nil)
    (ergoemacs-status-save-file)
    (force-mode-line-update)))

(defun ergoemacs-status--modify-map (map)
  "Modify MAP to include context menu. Also allows arrangment
with C- M- or S- dragging of elements."
  (let ((map map)
	down-mouse-1
	mouse-1 tmp)
    (if (not map)
	(setq map (make-sparse-keymap))
      (setq map (copy-keymap map)))
    (when (or (not (setq tmp (lookup-key map [mode-line mouse-3])))
	      (memq tmp '(ergoemacs-ignore ignore)))
      ;; (message "Add to %s" elt)
      (define-key map [mode-line mouse-3] #'ergoemacs-status-right-click))
    (define-key map [mode-line C-down-mouse-1] #'ergoemacs-status-down)
    (define-key map [mode-line M-down-mouse-1] #'ergoemacs-status-down)
    (define-key map [mode-line S-down-mouse-1] #'ergoemacs-status-down)
    ;; (setq down-mouse-1 (lookup-key map [mode-line down-mouse-1])
    ;; 	  mouse-1 (lookup-key map [mode-line mouse-1]))
    ;; (when (and down-mouse-1 (or (not mouse-1) (memq mouse-1 '(ignore ergoemacs-ignore))))
    ;;   (define-key map [mode-line mouse-1] down-mouse-1)
    ;;   (define-key map [mode-line down-mouse-1] #'ergoemacs-status-down)
    ;;   (define-key map [mode-line drag-mouse-1] #'ergoemacs-status-drag))
    map))

(defun ergoemacs-status--stack (mode-line-list face1 face2 dir &optional reduction-level)
  "Stacks mode-line elements."
  (let* (ret
	 (face-list (list face1 face2))
	 (len (length face-list))
	 (i 0)
	 plist ifs reduce
	 (lst (if (eq dir 'right)
		  mode-line-list
		(reverse mode-line-list)))
	 last-face cur-face tmp)
    (dolist (elt lst)
      (setq ifs (car elt)
	    plist (cdr elt)
	    reduce (plist-get plist :reduce))
      (unless (and reduce (integerp reduce)
		   reduction-level (integerp reduction-level)
		   (<= reduce reduction-level))
	;; Still in the running.
	(setq tmp (ergoemacs-status--if ifs (if (and ergoemacs-status-down-element
						     (equal (plist-get plist :element) ergoemacs-status-down-element))
						'ergoemacs-status-selected-element 
					      (nth (mod i len) face-list))
					(plist-get plist :pad)))
	(unless (and tmp (stringp tmp) (string= (format-mode-line tmp) ""))
	  (unless (or (plist-get plist :last-p) (eq dir 'center))
	    (setq i (1+ i)))
	  (setq tmp (propertize tmp :element (plist-get plist :element)))
	  (push tmp ret))))
    (when (eq (get-text-property 0 'face (format-mode-line (nth 0 ret)))
		(nth 1 face-list))
      ;; Reverse faces
      (setq ret (mapcar (lambda(elt)
      			  (cond
      			   ((eq (get-text-property 0 'face elt) (nth 0 face-list))
      			    (propertize elt 'face (nth 1 face-list)))
      			   ((eq (get-text-property 0 'face elt) (nth 1 face-list))
      			    (propertize elt 'face (nth 0 face-list)))
      			   (t elt)))
      			ret)))
    ;; Fix keys -- Right click brings up conext menu.
    (setq ret (mapcar
	       (lambda(elt)
		 (mapconcat
		  (lambda (mm)
		    (propertize mm 'local-map (ergoemacs-status--modify-map (get-text-property 0 'local-map mm))))
		  (ergoemacs-status--property-substrings elt 'local-map)
		  ""))
	       ret))
    ;; Add separators
    (setq last-face (get-text-property 0 'face (nth 0 ret))
	  ret (mapcar
	       (lambda(elt)
		 (setq cur-face (get-text-property 0 'face elt))
		 (prog1
		     (cond
		      ((eq cur-face last-face) elt)
		      ((eq dir 'left)
		       (concat (ergoemacs-status--sep dir last-face cur-face) elt))
		      ((eq dir 'right)
		       (concat elt (ergoemacs-status--sep dir cur-face last-face)))
		      ((eq dir 'center)
		       elt))
		   (setq last-face cur-face)))
	       ret))
    (cond
     ((eq dir 'center)
      (setq ret (append (list (ergoemacs-status--sep 'left face2 face1))
  			  ret
  			  (list (ergoemacs-status--sep 'right face1 face2)))))
     ((eq last-face face2))
     ((eq dir 'left)
      (setq ret (append ret (list (ergoemacs-status--sep dir last-face face2)))))
     ((eq dir 'right)
      (setq ret (append ret (list (ergoemacs-status--sep dir face2 last-face))))))
    (setq ret (if (eq dir 'right)
		  (reverse ret)
		ret))))

(defcustom ergoemacs-status-extra-width 0
  "Extra width to add."
  :type 'integer
  :group 'ergoemacs-status)

(defcustom ergoemacs-status-width-multiplier 1.0
  "Multiplier for width."
  :type 'number
  :group 'ergoemacs-status)

(defvar ergoemacs-status--pixel-width-p nil
  "Determines if the mode line tries to calculate width")

(defun ergoemacs-status--eval-width (&optional what)
  (if ergoemacs-status--pixel-width-p
      (ergoemacs-status--eval-width-pixels what)
    (ergoemacs-status--eval-width-col what)))

(defun ergoemacs-status--eval-string-width-pixels (str)
  "Get string width in pixels."
  (with-current-buffer (get-buffer-create " *ergoemacs-eval-width*")
	(delete-region (point-min) (point-max))
	(insert str)
	(car (window-text-pixel-size nil (point-min) (point-max)))))

(defun ergoemacs-status--eval-width-pixels (&optional what)
  "Get the width of the display in pixels."
  (ergoemacs-status--eval-width-col what t))

(defun ergoemacs-status--eval-width-col-string (str &optional pixels-p)
  "Figure out the column width of STR."
  (apply
   '+
   (mapcar (lambda(x)
	     (let ((display (get-text-property 0 'display x)))
	       (if display
		   (car (image-size display pixels-p))
		 (if pixels-p
		     (ergoemacs-status--eval-string-width-pixels x)
		   (string-width x)))))
	   (ergoemacs-status--property-substrings str 'display))))

(defvar ergoemacs-stats--ignore-eval-p nil
  "Determine if the evaluate will complete.")

(defun ergoemacs-status--eval-width-col (&optional what pixels-p)
  "Eval width of WHAT, which is formated with `format-mode-line'.
When WHAT is nil, return the width of the window"
  (or (and what (ergoemacs-status--eval-width-col-string (format-mode-line what pixels-p)))
      (if pixels-p
	  (let ((width (ergoemacs-status--eval-width-col))
		(cw (frame-char-width)))
	    (* cw width))
	(let ((width (window-width))
	      ;; (cw (frame-char-width))
	      
	      tmp)
	  (when (setq tmp (window-margins))
	    (setq width (apply '+ width (list (or (car tmp) 0) (or (cdr tmp) 0)))))
	  (setq width (* ergoemacs-status-width-multiplier (+ width ergoemacs-status-extra-width)))
	  (setq ergoemacs-stats--ignore-eval-p t)
	  (unwind-protect
	      (setq width (- width (ergoemacs-status--eval-width-col-string (format-mode-line mode-line-format) pixels-p)))
	    (setq ergoemacs-stats--ignore-eval-p nil))))))

(defvar ergoemacs-status-max-reduction 4)

(defvar mode-icons-read-only-space)

(defvar mode-icons-show-mode-name)

(defvar mode-icons-eol-text)

(defvar mode-icons-cached-mode-name)

(defun ergoemacs-status--eval ()
  (if ergoemacs-stats--ignore-eval-p ""
    ;; This will dynamically grow/fill areas
    (setq mode-icons-read-only-space nil
	  mode-icons-show-mode-name t
	  mode-icons-eol-text t
	  mode-name (or (and (fboundp #'mode-icons-get-mode-icon)
			     (mode-icons-get-mode-icon (or mode-icons-cached-mode-name mode-name)))
			mode-name))
    (let* ((active (or (and (fboundp #'powerline-selected-window-active) (powerline-selected-window-active)) t))
	   (mode-line (if active 'mode-line 'mode-line-inactive))
	   (face1 (if active 'powerline-active1 'powerline-inactive1))
	   (face2 (if active 'powerline-active2 'powerline-inactive2))
	   (mode-icons-read-only-space nil)
	   (mode-icons-show-mode-name t)
	   lhs rhs center
	   wlhs wrhs wcenter
	   available
	   (reduce-level 1))
      (setq ergoemacs-status--minor-modes-available nil
	    lhs (ergoemacs-status--eval-lhs mode-line face1 face2)
	    rhs (ergoemacs-status--eval-rhs mode-line face1 face2)
	    center (ergoemacs-status--eval-center mode-line face1 face2)
	    wlhs (ergoemacs-status--eval-width lhs)
	    wrhs (ergoemacs-status--eval-width rhs)
	    wcenter (ergoemacs-status--eval-width center))
      (when (> (+ wlhs wrhs wcenter) (ergoemacs-status--eval-width))
	(setq mode-icons-read-only-space nil
	      mode-icons-show-mode-name nil
	      mode-icons-eol-text nil
	      mode-name (or (and (fboundp #'mode-icons-get-mode-icon)
				 (mode-icons-get-mode-icon (or mode-icons-cached-mode-name mode-name)))
			    mode-name)
	      lhs (ergoemacs-status--eval-lhs mode-line face1 face2)
	      rhs (ergoemacs-status--eval-rhs mode-line face1 face2)
	      center (ergoemacs-status--eval-center mode-line face1 face2)
	      wlhs (ergoemacs-status--eval-width lhs)
	      wrhs (ergoemacs-status--eval-width rhs)
	      wcenter (ergoemacs-status--eval-width center))
	(while (and (<= reduce-level ergoemacs-status-max-reduction)
		    (> (+ wlhs wrhs wcenter) (ergoemacs-status--eval-width)))
	  (setq mode-icons-read-only-space nil
		mode-icons-show-mode-name nil
		mode-icons-eol-text nil
		lhs (ergoemacs-status--minor-modes-available mode-line face1 face2)
		lhs (ergoemacs-status--eval-lhs mode-line face1 face2 reduce-level)
		rhs (ergoemacs-status--eval-rhs mode-line face1 face2 reduce-level)
		center (ergoemacs-status--eval-center mode-line face1 face2 reduce-level)
		wlhs (ergoemacs-status--eval-width lhs)
		wrhs (ergoemacs-status--eval-width rhs)
		wcenter (ergoemacs-status--eval-width center)
		reduce-level (+ reduce-level 1))))
      (setq available (/ (- (ergoemacs-status--eval-width) (+ wlhs wrhs wcenter)) 2))
      (if ergoemacs-status--pixel-width-p
	  (setq available (list available)))
      ;; (message "a: %s (%3.1f %3.1f %3.1f; %3.1f)" available wlhs wrhs wcenter (ergoemacs-status--eval-width))
      (prog1
	  (set (make-local-variable 'ergoemacs-status--eval)
		(list lhs
		      (propertize " " 'display `((space :width ,available))
				  'face face1)
		      center
		      (propertize " " 'display `((space :width ,available))
				  'face face1)
		      rhs))
	(set (make-local-variable 'ergoemacs-status--eval)
	      (mapcar
	       (lambda(x)
		 (list (get-text-property 0 :element x)
		       (or (ignore-errors (ergoemacs-status--eval-width x))
			   available)))
	       (ergoemacs-status--property-substrings (format-mode-line ergoemacs-status--eval) :element)))))))

(defun ergoemacs-status--variable-pitch (&optional frame)
  (dolist (face '(mode-line mode-line-inactive
			    powerline-active1
			    powerline-inactive1
			    powerline-active2 powerline-inactive2))
    (set-face-attribute face frame
			  :family (face-attribute 'variable-pitch :family)
			  :foundry (face-attribute 'variable-pitch :foundry)
			  :height 125)))

(defvar ergoemacs-old-mode-line-format nil
  "Old `mode-line-format'.")

(defvar ergoemacs-old-mode-line-front-space nil
  "Old `mode-line-front-space'.")

(defvar ergoemacs-old-mode-line-mule-info nil
  "Old `mode-line-mule-info'.")

(defvar ergoemacs-old-mode-line-client nil
  "Old `mode-line-client'.")

(defvar ergoemacs-old-mode-line-modified nil
  "Old `mode-line-modified'.")

(defvar ergoemacs-old-mode-line-remote nil
  "Old `mode-line-remote'.")

(defvar ergoemacs-old-mode-line-frame-identification nil
  "Old `mode-line-frame-identification'.")

(defvar ergoemacs-old-mode-line-buffer-identification nil
  "Old `mode-line-buffer-identification'.")

(defvar ergoemacs-old-mode-line-position nil
  "Old `mode-line-position'.")

(defvar ergoemacs-old-mode-line-modes nil
  "Old `mode-line-modes'.")

(defvar ergoemacs-old-mode-line-misc-info nil
  "Old `mode-line-misc-info'.")

(defvar ergoemacs-old-mode-line-end-spaces nil
  "Old `mode-line-end-spaces'.")

(defvar ergoemacs-status-save-mouse-3 nil
  "Old mouse-3")

(defun ergoemacs-status-format (&optional restore)
  "Setup `ergoemacs-status' `mode-line-format'."
  (if restore
      (progn
	(set-default 'mode-line-format
		     ergoemacs-old-mode-line-format)
	(setq mode-line-front-space ergoemacs-old-mode-line-front-space
	      mode-line-mule-info ergoemacs-old-mode-line-mule-info
	      mode-line-client ergoemacs-old-mode-line-client
	      mode-line-modified ergoemacs-old-mode-line-modified
	      mode-line-remote ergoemacs-old-mode-line-remote
	      mode-line-frame-identification ergoemacs-old-mode-line-frame-identification
	      mode-line-buffer-identification ergoemacs-old-mode-line-buffer-identification
	      mode-line-position ergoemacs-old-mode-line-position
	      mode-line-modes ergoemacs-old-mode-line-modes
	      mode-line-misc-info ergoemacs-old-mode-line-misc-info
	      mode-line-end-spaces ergoemacs-old-mode-line-end-spaces)
	(define-key global-map [mode-line mouse-3] (symbol-value ergoemacs-status-save-mouse-3))
	;; FIXME -- restore old in all buffers.e
	)
    (unless ergoemacs-old-mode-line-format
      (setq ergoemacs-old-mode-line-format mode-line-format
	    ergoemacs-old-mode-line-front-space mode-line-front-space
	    ergoemacs-old-mode-line-mule-info mode-line-mule-info
	    ergoemacs-old-mode-line-client mode-line-client
	    ergoemacs-old-mode-line-modified mode-line-modified
	    ergoemacs-old-mode-line-remote mode-line-remote
	    ergoemacs-old-mode-line-frame-identification mode-line-frame-identification
	    ergoemacs-old-mode-line-buffer-identification mode-line-buffer-identification
	    ergoemacs-old-mode-line-position mode-line-position
	    ergoemacs-old-mode-line-modes mode-line-modes
	    ergoemacs-old-mode-line-misc-info mode-line-misc-info
	    ergoemacs-old-mode-line-end-spaces mode-line-end-spaces
	    ergoemacs-status-save-mouse-3 (key-binding [mode-line mouse-3])))

    (setq-default mode-line-format
		  `("%e" mode-line-front-space
		    ;; mode-line-mule-info
		    ;; mode-line-client
		    ;; mode-line-modified
		    ;; mode-line-remote
		    ;; mode-line-frame-identification
		    ;; mode-line-buffer-identification
		    ;; mode-line-position -- in position function
		    ;; mode-line-modes --not changed
		    (:eval (ergoemacs-status--eval))
		    mode-line-misc-info
		    mode-line-end-spaces))
    (setq mode-line-front-space (list "")
	  mode-line-mule-info (list "")
	  mode-line-client (list "")
	  mode-line-modified (list "")
	  mode-line-remote (list "")
	  mode-line-frame-identification (list "")
	  mode-line-buffer-identification (list "")
	  mode-line-position (list "")
	  mode-line-modes (list "")
	  mode-line-misc-info (list "")
	  mode-line-end-spaces (list ""))
    ;; FIXME -- Apply to all buffers.
    (force-mode-line-update)))

(defvar ergoemacs-status-turn-off-mode-icons nil)
(defvar mode-icons-mode)
(define-minor-mode ergoemacs-status-mode
  "Ergoemacs status mode."
  :global t
  (if ergoemacs-status-mode
      (progn
	(if (and (boundp 'mode-icons-mode) mode-icons-mode)
	    (setq ergoemacs-status-turn-off-mode-icons nil)
	  (setq ergoemacs-status-turn-off-mode-icons t)
	  (mode-icons-mode 1))
	(ergoemacs-status-format))
    (when ergoemacs-status-turn-off-mode-icons
      (mode-icons-mode -1))
    (ergoemacs-status-format t)))

(load ergoemacs-status-file t)

(provide 'ergoemacs-status)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ergoemacs-status.el ends here
