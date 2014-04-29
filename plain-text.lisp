;;;; Render Geneva document as plain text.

(defpackage geneva.plain-text
  (:documentation "Render Geneva document as plain text.")
  (:use :cl
	:geneva
        :geneva.utilities
        :pretty-string)
  (:export :render-plain-text))

(in-package :geneva.plain-text)

;;; This package is an ugly hack on top of GENEVA.MK2:PRINT-MK2 and uses
;;; many otherwise internal routines of the mk2 package. Assuming the mk2
;;; package is stable, this is a reasonable and *short* implemetation
;;; despite bad code style.

(defmacro with-indent/mk2 ((indent) &body body)
  "Evaluate BODY with GENEVA.MK2::*INDENT* bound to INDENT."
  `(let ((geneva.mk2::*indent* ,indent))
     ,@body))

(defmacro with-no-escape/mk2 (&body body)
  "Disable mk2 escaping for BODY."
  `(let ((geneva.mk2::*to-escape* nil))
     ,@body))

(defun render-text/mk2 (text)
  "Render TEXT using internal functions of GENEVA.MK2."
  (geneva.mk2::print-string
   (geneva.mk2::text-string text)))

(defun render-table/mk2 (rows)
  "Render table ROWS using internal functions of GENEVA.MK2."
  (geneva.mk2::print-string
   (geneva.mk2::table-string rows "  ")
   :wrap nil))

(defun render-listing/mk2 (items)
  "Render listing ITEMS using internal functions of GENEVA.MK2."
  (dolist (item items)
    (geneva.mk2::write-string
     (geneva.mk2::listing-string (list item) " * "))
    (terpri)))

(defun render-plaintext/mk2 (string)
  "Render plaintext STRING using internal functions of GENEVA.MK2."
  (geneva.mk2::print-string string :wrap nil))

(defun render-header/mk2 (level text)
  "Render TEXT as header at LEVEL using internal functions of
GENEVA.MK2."
  (with-indent/mk2 (0)
    (write-string (geneva.mk2::listing-string
                   (list text)
                   (format nil "~a " (level-string level))))
    (terpri)))

(defun render-content (content &optional (level (null-level)))
  "Render CONTENT at LEVEL."
  (with-no-escape/mk2
    (with-indent/mk2 (3)
      (ecase (content-type content)

        (#.+paragraph+ (render-text/mk2 (content-values content))
                       (terpri))

        (#.+listing+   (render-listing/mk2 (content-values content)))

        (#.+table+     (multiple-value-bind (caption rows)
                           (content-values content)
                         (render-table/mk2 rows)
                         (when caption
                           (with-indent/mk2 (7)
                             (render-text/mk2 caption))
                           (terpri))))

        (#.+media+     (multiple-value-bind (caption url)
                           (content-values content)
                         (format t "     URI: ~a~%~%" url)
                         (when caption
                           (with-indent/mk2 (7)
                             (render-text/mk2 caption))
                           (terpri))))

        (#.+plaintext+ (multiple-value-bind (caption pre)
                           (content-values content)
                         (with-indent/mk2 (5)
                           (render-plaintext/mk2 pre))
                         (format t "~&")
                         (terpri)
                         (when caption
                           (with-indent/mk2 (7)
                             (render-text/mk2 caption))
                           (terpri))))

        (#.+section+   (multiple-value-bind (header contents)
                           (content-values content)
                         (render-header/mk2 level header)
                         (let ((sublevel (descend-level level)))
                           (dolist (content contents)
                             (render-content content sublevel)))
                         (incf-level level)))))))

(defun render-index/mk2 (index &optional (indent "   "))
  "Render INDEX as plain text using interal mk2 functions."
  (loop for (level header subsections) in index
        for prefix = (format nil "~a~a " indent (level-string level))
     do
       (write-string (geneva.mk2::listing-string (list header) prefix))
       (render-index/mk2 subsections
                         (make-string (length prefix)
                                      :initial-element #\Space))))

(defun render-plain-text (document
                          &key (stream *standard-output*)
                               title
                               author
                               date
                               (index-p t)
                               (index-caption *default-index-caption*))
  "Render DOCUMENT as plain text to STREAM."
  (let ((level (null-level))
        (*standard-output* stream)
        (geneva.mk2::*discard-text-markup-p* t))
    (when title
      (write-string (align-string title :center geneva.mk2::*columns*))
      (terpri))
    (when author
      (write-string (align-string author :right geneva.mk2::*columns*)))
    (when date
      (write-string
       (align-string date :right geneva.mk2::*columns*)))
    (when (or author date)
      (terpri))
    (when index-p
      (format t "~a~%~%" index-caption)
      (render-index/mk2 (document-index document))
      (terpri))
    (dolist (content document)
      (render-content content level))))
