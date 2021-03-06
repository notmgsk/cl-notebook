sbcl --load "build.lisp" --quit

./buildapp --manifest-file build.manifest --load-system cl-css --load-system cl-who --load-system named-readtables --load-system trivial-gray-streams --load-system closer-mop --load-system sb-bsd-sockets --load-system sb-posix --load-system cl-json --load-system cl-ppcre --load-system cl-base64 --load-system anaphora --load-system alexandria --load-system parenscript --load-system flexi-streams --load-system optima --load-system usocket --load-system bordeaux-threads --load-system cl-fad --load-system local-time --load-system session-token --load-system house --load-system fact-base --load-system cl-notebook --eval '(cl-notebook::read-statics)' --output cl-notebook --entry cl-notebook:main

sha512sum cl-notebook > cl-notebook.sha512
sha256sum cl-notebook > cl-notebook.sha256
tar -zcvf cl-notebook.tar.gz cl-notebook
