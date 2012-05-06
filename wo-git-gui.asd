;;;; wo-git-gui.asd

(asdf:defsystem #:wo-git-gui
  :serial t
  :depends-on (#:hunchentoot #:cl-who #:wo-git #:wo-graph-functions #:cl-ppcre)
  :components ((:file "package")
               (:file "wo-git-gui")))

