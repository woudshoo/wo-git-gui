;;;; package.lisp

(defpackage #:wo-git-gui
  (:use #:cl)
  (:import-from #:hunchentoot
		#:content-type*
		#:send-headers
		#:define-easy-handler
		#:url-encode)
  (:import-from #:wo-graph-functions
		#:write-to-dot)
  (:export
   #:*default-graph*
   #:start-server
   #:stop-server
   #:clear-cache
   #:read-graph
   #:reset
   #:*git-project*
   #:*dot-cmd*
   #:*dead-revisions*
   #:*version-names-scanner*))

