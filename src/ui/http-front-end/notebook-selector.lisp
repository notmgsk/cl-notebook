(in-package :cl-notebook)

(define-handler (js/notebook-selector.js :content-type "application/javascript") ()
  (ps
    (defvar *current-fs-listing* nil)

    (defun notebook-link-template (notebook current-notebook-id)
      (if (equal? current-notebook-id (@ notebook :path))
          (who-ps-html
           (:li :class "book-link current-book" :title (@ notebook :path) (@ notebook :title)))
          (who-ps-html
           (:li :class "book-link" :title (@ notebook :path)
                (:a :href (+ "/#book=" (@ notebook :path)) (@ notebook :title))))))

    (defvar filesystem-input-change
      (debounce
       (lambda (event elem)
         (let* ((val (@ elem value))
                (dval (if (chain val (ends-with "/")) val (+ val "/")))
                (filtered (filter-fs-listing *current-fs-listing* val))
                (fnames (map (lambda (d) (@ d :string)) (@ filtered :files)))
                (dirnames (map (lambda (d) (@ d :string)) (@ filtered :directories)))
                (key-code (@ event key-code)))
           (console.log "KEY CODE" key-code)
           (cond
             ((= 9 key-code)
              (chain event (prevent-default))
              (chain elem (focus))
              (console.log "FOUND TAB KEYPRESS" "TODO"))
             ((and (= 13 key-code) (member? val fnames))
              (setf (@ window location href) (+ "/#book=" val)))
             ((and (= 13 key-code) (member? dval dirnames))
              (filesystem! (by-selector ".filesystem-view") dval))
             ((or (= 8 key-code) (= 46 key-code))
              (console.log "FOUND DELETING NON-CHAR KEYPRESS" key-code "RE-RUNNING ls REQUEST")
              (filesystem!
               (by-selector ".filesystem-view")
               (+ (chain val (split "/") (slice 0 -1) (join "/")) "/")
               :filter? f))
             ((not (= 0 (@ event char-code)))
              (unless (and (= 0 (length (@ filtered :directories))) (= 0 (length (@ filtered :files))))
                (render-filesystem! (by-selector ".filesystem-view") filtered)
                (cond
                  ((and (= (length (@ filtered :directories)) 1)
                        (= (length (@ filtered :files)) 0))
                   (console.log "FOUND UNIQUE DIRECTORY")
                   (setf (@ elem value) (@ filtered :directories 0 :string))
                   (filesystem! (by-selector ".filesystem-view") (@ filtered :directories 0 :string)))
                  ((and (= (length (@ filtered :directories)) 0)
                        (= (length (@ filtered :files)) 1))
                   (setf (@ window location href) (+ "/#book=" (@ filtered :files 0 :string))))))))))
       200))

    (defun filesystem-directory-click (directory)
      (setf (@ (by-selector ".filesystem-input") value) directory)
      (filesystem! (by-selector ".filesystem-view") directory))

    (defun selector-template ()
      (who-ps-html
       (:div :class "notebook-selector"
             (:ul :class "loaded-books-list")
             (:input :class "filesystem-input" :onkeypress "filesystemInputChange(event, this)")
             (:span :class "filesystem-view"))))

    (defun file-template (file)
      (who-ps-html
       (:li :class "file-link"
            (:a :href (+ "/#book=" (@ file :string)) (@ file :name)))))

    (defun directory-template (directory)
      (let ((call (+ "filesystemDirectoryClick('" (@ directory :string) "')")))
        (who-ps-html
         (:li :class "directory-link"
              (:span :class "directory-link" :onclick call
                     (last (@ directory :directory)))))))

    (defun filesystem-template (listing)
      (who-ps-html
       (:ul :class "filesystem-list"
            (+ (join (map directory-template (@ listing :directories)))
               (join (map file-template (@ listing :files)))))))

    (defun filter-fs-listing (listing prefix)
      (let ((f (lambda (path) (chain (@ path :string) (starts-with prefix)))))
        (create :directories (filter f (@ listing :directories))
                :files (filter f (@ listing :files)))))

    (defun render-filesystem! (elem listing)
      (dom-set elem (filesystem-template listing)))

    (defun filesystem! (elem directory &key (filter? t))
      (get/json "/cl-notebook/system/ls" (create :dir directory)
                (lambda (dat)
                  (setf *current-fs-listing*
                        (create :directories (or (@ dat :directories) (list))
                                :files (or (@ dat :files) (list))))
                  (render-filesystem!
                   elem
                   (if filter?
                       (filter-fs-listing
                        *current-fs-listing*
                        (@ (by-selector ".filesystem-input") value))
                       *current-fs-listing*)))))

    (defun loaded-books! (elem current-notebook-id)
      (get/json "/cl-notebook/loaded-books" (create)
                (lambda (dat)
                  (dom-set
                   elem
                   (join
                    (map
                     (lambda (bk)
                       (notebook-link-template bk current-notebook-id))
                     dat))))))

    (defun notebook-selector! (selector)
      (let ((elem (by-selector selector)))
        (dom-set elem (selector-template))
        (loaded-books! (by-selector elem ".loaded-books-list") (@ *notebook* id))
        (get/json "/cl-notebook/system/home-path" (create)
                  (lambda (initial-dir)
                    (setf (@ (by-selector elem ".filesystem-input") value) initial-dir)
                    (filesystem! (by-selector elem ".filesystem-view") initial-dir)))))))