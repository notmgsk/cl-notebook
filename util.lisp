(in-package :cl-notebook)

(defun sys-dir (path)
  (let ((path (cl-fad:pathname-as-directory path)))
    (ensure-directories-exist path)
    path))

(defmethod last-char ((pth pathname))
  (last-char (file-namestring pth)))

(defmethod last-char ((str string))
  (aref str (- (length str) 1)))

(defmethod stem-path ((path pathname) stem-from)
  (let ((stemmed (member stem-from (cdr (pathname-directory path)) :test #'string=)))
    (make-pathname 
     :directory
     (if stemmed
	 (cons :relative stemmed)
	 (pathname-directory path))
     :name (pathname-name path)
     :type (pathname-type path))))

(defun update (&rest k/v-pairs)
  (let ((hash (make-hash-table)))
    (loop for (k v) on k/v-pairs by #'cddr
       do (setf (gethash k hash) v))
    (json:encode-json-to-string hash)))

(defun instance->alist (instance)
  (loop for s in (closer-mop:class-slots (class-of instance))
     for slot-name = (slot-definition-name s)
     when (slot-boundp instance slot-name)
     collect (cons (intern (symbol-name slot-name) :keyword) 
		   (slot-value instance slot-name))))

(defun alist (&rest k/v-pairs)
  "Association lists with less consing"
  (loop for (k v) on k/v-pairs by #'cddr
     collect (cons k v)))

(defun type-tag (thing)
  "Extracts just the type tag from compound type specifications.
Returns primitive type specifications as-is."
  (let ((tp (type-of thing)))
    (if (listp tp)
	(first tp)
	tp)))

(defun ignored-error-prop? (prop-name)
  (member prop-name
	  (list :args :control-string :second-relative :print-banner
		:references :format-control :format-arguments :offset
		:stream
		:new-location)))

(defun stringified-error-prop? (prop-name)
  (member prop-name
	  (list :name :new-function :specializers :old-method)))

(defun front-end-error (form e)
  "Takes a form and an error pertaining to it.
Formats the error for front-end display, including a reference to the form."
  (let ((err-alist (instance->alist e)))
    `((condition-type . ,(symbol-name (type-tag e)))
      ,@(let ((f-tmp (cdr (assoc :format-control err-alist)))
	      (f-args (cdr (assoc :format-arguments err-alist))))
	     (when (and f-tmp f-args)
	       (list (cons :error-message (apply #'format nil f-tmp f-args)))))
      ,@(when form (list (cons :form form)))
      ,@(loop for (a . b) in err-alist
	   if (stringified-error-prop? a)
	   collect (cons a (format nil "~s" b))
	   else if (not (ignored-error-prop? a))
	   collect (cons a b)))))

(defmethod read-all ((str stream))
  (let ((eof (gensym "EOF-")))
    (loop for s-exp = (read str nil eof) until (eq s-exp eof)
       collect s-exp)))

(defmethod read-all ((str string))
  (read-all (make-string-input-stream str)))

(defmethod capturing-eval ((str stream))
  "Takes the next s-expression from a stream and tries to evaluate it.
   Returns either NIL (if there are no further expressions)
or a (:stdout :warnings :values) alist representing
  - The *standard-output* emissions
  - collected warnings
  - return values (which may be errors)
from each expression in turn."
  (let* ((eof (gensym "EOF-"))
	 (res nil)
	 (warnings)
	 (exp)
	 (stdout
	  (with-output-to-string (*standard-output*)
	    (handler-case
		(handler-bind ((warning (lambda (w) (push (front-end-error nil w) warnings))))
		  (setf
		   exp (read str nil eof)
		   res (if (eq eof exp)
			   :eof
			   (mapcar
			    (lambda (v) (alist :type (type-tag v) :value (write-to-string v))) 
			    (multiple-value-list (eval exp))))))
	      (error (e) 
		(setf res (list
			   (alist 
			    :type 'error 
			    :value (front-end-error (format nil "~s" exp) e)))))))))
    (if (eq :eof res)
	nil
	(alist :stdout stdout :warnings warnings :values res))))

(defmethod capturing-eval ((str string))
  "Evaluates each form in the given string, collecting return values, warnings and *standard-output* emissions."
  (let ((stream (make-string-input-stream str)))
    (loop for res = (capturing-eval stream)
       while res collect res)))
