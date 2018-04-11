(in-package #:cl-notebook)

; Basic server-side definitions and handlers
;;;;; HTTP Handlers
;;;;;;;;;; Notebook-level hooks
(define-json-handler (cl-notebook/notebook/rewind) ((book :notebook) (index :integer))
  (hash :facts (rewind-to book index) :history-size (total-entries book) :history-position index :id (notebook-id book)))

(define-json-handler (cl-notebook/notebook/current) ((book :notebook))
  (hash :facts (current book) :history-size (total-entries book) :id (notebook-id book)))

(define-json-handler (cl-notebook/notebook/new) ((path :nonexistent-file))
  (let ((book (new-notebook! path)))
    (write! book)
    (publish-update! book 'new-book :book-name (notebook-name book))
    (hash :facts (current book) :history-size (total-entries book) :id (notebook-id book))))

(define-json-handler (cl-notebook/notebook/load) ((path :existing-filepath))
  (let ((book (load-notebook! path)))
    (publish-update! book 'new-book :book-name (notebook-name book))
    (hash :facts (current book) :history-size (total-entries book) :id (notebook-id book))))

(define-json-handler (cl-notebook/notebook/repackage) ((book :notebook) (new-package :string))
  (eval-package book new-package)
  :ok)

(define-json-handler (cl-notebook/notebook/rename) ((book :notebook) (new-name :string))
  (multiple-value-bind (book renamed?) (rename-notebook! book new-name)
    (when renamed?
      (unless (or (lookup book :b :package-edited?) (lookup book :b :package-error))
	(repackage-notebook! book (default-package book))
	(publish-update! book 'finished-package-eval :contents (notebook-package-spec-string book)))
      (write! book)
      (publish-update! book 'rename-book :new-name new-name)))
  :ok)

;;;;;;;;;; Cell-level hooks
(define-json-handler (cl-notebook/notebook/eval-to-cell) ((book :notebook) (cell-id :integer) (contents :string))
  (let ((cont-fact (first (lookup book :a cell-id :b :contents)))
	(val-fact (first (lookup book :a cell-id :b :result)))
	(cell-lang (caddar (lookup book :a cell-id :b :cell-language)))
	(cell-type (caddar (lookup book :a cell-id :b :cell-type))))
    (change! book cont-fact (list cell-id :contents contents))
    (publish-update! book 'content-changed :cell cell-id :contents contents)
    (eval-cell book cell-id contents val-fact cell-lang cell-type))
  :ok)

(define-json-handler (cl-notebook/notebook/change-cell-contents) ((book :notebook) (cell-id :integer) (contents :string))
  (let ((cont-fact (first (lookup book :a cell-id :b :contents))))
    (unless (string= contents (third cont-fact))
      (change! book cont-fact (list cell-id :contents contents))
      (insert! book (list cell-id :stale t))
      (publish-update! book 'content-changed :cell cell-id :contents contents)))
  :ok)

(define-json-handler (cl-notebook/notebook/change-cell-language) ((book :notebook) (cell-id :integer) (new-language :keyword))
  (let ((cont-fact (first (lookup book :a cell-id :b :contents)))
	(val-fact (first (lookup book :a cell-id :b :result)))
	(cell-type (caddar (lookup book :a cell-id :b :cell-type)))
	(lang-fact (first (lookup book :a cell-id :b :cell-language))))
    (unless (eq (third lang-fact) new-language)
      (change! book lang-fact (list cell-id :cell-type new-language))
      (publish-update! book 'change-cell-language :cell cell-id :new-language new-language)
      (eval-cell book cell-id (third cont-fact) val-fact new-language cell-type)))
  :ok)

(define-json-handler (cl-notebook/notebook/change-cell-type) ((book :notebook) (cell-id :integer) (new-type :keyword))
  (let ((cont-fact (first (lookup book :a cell-id :b :contents)))
	(val-fact (first (lookup book :a cell-id :b :result)))
	(cell-lang (caddar (lookup book :a cell-id :b :cell-language)))
	(tp-fact (first (lookup book :a cell-id :b :cell-type))))
    (unless (eq (third tp-fact) new-type)
      (change! book tp-fact (list cell-id :cell-type new-type))
      (publish-update! book 'change-cell-type :cell cell-id :new-type new-type)
      (eval-cell book cell-id (third cont-fact) val-fact cell-lang new-type)))
  :ok)

(define-json-handler (cl-notebook/notebook/change-cell-noise) ((book :notebook) (cell-id :integer) (new-noise :keyword))
  (let ((old-noise-fact (first (lookup book :a cell-id :b :noise)))
	(new-noise-fact (unless (eq new-noise :normal) (list cell-id :noise new-noise))))
    (cond ((and old-noise-fact new-noise-fact)
	   (change! book old-noise-fact new-noise-fact))
	  (old-noise-fact
	   (delete! book old-noise-fact))
	  (new-noise-fact
	   (insert! book new-noise-fact))))
  (publish-update! book 'change-cell-noise :cell cell-id :new-noise new-noise)
  :ok)

(define-json-handler (cl-notebook/notebook/new-cell) ((book :notebook) (cell-language :keyword) (cell-type :keyword))
  (let ((cell-id (new-cell! book :cell-type cell-type :cell-language cell-language)))
    (write! book)
    (publish-update! book 'new-cell :cell-id cell-id :cell-type cell-type :cell-language cell-language))
  :ok)

(define-json-handler (cl-notebook/notebook/kill-cell) ((book :notebook) (cell-id :integer))
  (loop for f in (lookup book :a cell-id) do (delete! book f))
  (write! book)
  (publish-update! book 'kill-cell :cell cell-id)
  :ok)
