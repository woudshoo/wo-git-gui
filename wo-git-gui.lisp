;;;; wo-git-gui.lisp

(in-package #:wo-git-gui)

;;; "wo-git-gui" goes here. Hacks and glory await!

(defparameter *dot-cmd*
  #+linux "/usr/bin/dot"
  #+darwin "/usr/local/bin/dot"
  #+win32 "d:/Programs/graphviz/bin/dot.exe")

(defparameter *git-project*
  #P"/Users/woudshoo/Development/Source/Lisp/wo-git-gui/.git")

(defparameter *webserver-acceptor* nil)
(defparameter *default-graph* nil)

(defparameter *dead-revisions*  '("F0BCC1A07FFB8E0BC0098B679C5BB79C92208337"
				  "7091DFADB75F1D895F527DCF880915DD243C8047"
				  "FEBF3F4A1780FA249C7ADC3C58DC7FF75751D61C"
				  "952B1C5647528855A2BF5E4E52ABAE4DAA2D3D4F"
				  "391F4E6A0AE71C99B0E822A981F3C94155B7062A"
				  "9EDA00F6C3422F7C85B0D2306BD00D7A74FA31F6"
				  "0299B35B107A7446AE33EEEACD131ED4093C3956"
				  "9C4CF09585BC879770AECE7C19BF5217A42BF41F"
				  "CC859C37D9F4280159839BD92ACAE8681A9A6706"
				  "DA137585F0460EEABB4C63FC2115F6B2D7537825"
				  "4286494064976A89452EB52F85FD4E03006DA5FD" ;; nextmajor
				  "CF52C30B0B84E5E8126AEA6B79F710543D0A6BA6"
				  "6506AA16859E815DE4C384DB3C443B3ADEE1B201"
				  "6BC8C53C6B8080CB095A0BC35CC06055463DB7EE"
				  "FFD9E70E636C8C4F763DF82064F4C328CCCB330D"
				  "71C7509FEEB234174E9876051E9F99C917A0B1A6"
				  "C13BCBFAEC238394BFF8558E422D25EA5CA01DB6" ;; keep table modifications
				  "086DB3D876D6819F1B0B162FB93F0636501E0F57"

				  ;;;; testing

				  "56B42CE22FF63BDC6A2A2C1548E10FFECEC6ABE5"

				  ;;;; list for TODO.org
				  "32D04CA435FAF8B54E1FA992570EFCC4FE171F95"
				  "45A98B42AD00946A06E01223BDB682AE56EC5F2C"
				  "D372AF3358BCC9AE550D2D025C082F61CFC56C3B"
				  "B6F2A2CBA01893B3416A907048E2029C5957E4B0"
				  "642728CBA67CD7A985857C53882BC878C5D20070"
				  "4949740753B4EF96811AE54FC8180B750D888208"
				  "681CAF77F9607C63D0C10073F70BA1BF1A2697F5"
				  "1BF27E8C649FDFF4AAC160F704FB8B224BD6AD07"
				  "6571BA8F8594D944C31F9F61BF6F65DAEE89A55F"
				  "823756B8A07AE6C4F9E5DF774F0528392D7FF451"
				  "08489F848F6F2C0972FC9C3C2764EEBA95DFD1A5"
				  "EF9EE96A72BC8EABE277B6E636B3C1D9ADF6C985"
				  "3D5D788D72ADD658D8FF53FB49663E526D29C63D"
				  "54E4BAEB8E25BFA4600E78C0987738C88FB9FB44"
				  "5EF1977BFF43F5243F252C45DF6903C29C12725F"
				  "CE1F85618CACDC3CCA303EB96803257209939252"
				  "C3AC4E4BBD7B6D59F500EE9084EF1CECD46507FB"
				  "6878D943118FEE9CE6AF671C8FDE9E902C3C88A5"
				  "08A9CFC10FDEF03FA0410B21C5AA45A9E10219A9"
				  "850654138B55E393066C4D1D15C685D0571507BA"
				  "F0662B5A3ADA491AA2747AC48EF6D743A33B1361"
				  "B4B4143080F78DFD743169D1DB5DF95451BC66E0"
				  "AD76190277BFED9F465E8FF3A6F76B596E471428"
				  ))

(defparameter *version-names-scanner*
  (cl-ppcre:create-scanner "v[0-9]+\\.[0-9]+\\.[0-9]\\.[0-9]+"))

(defparameter *filter-names-scanner*
  (cl-ppcre:create-scanner "/bob/"))

(defparameter *default-reducers*
  (list
   (wo-graph-functions:make-single-sided-reducer
    #'wo-graph:sources-of-vertex
    #'wo-graph:targets-of-vertex
    0 nil)
   (wo-graph-functions:make-single-sided-reducer
    #'wo-graph:targets-of-vertex
    #'wo-graph:sources-of-vertex
    0 nil)
   (wo-graph-functions:make-single-sided-reducer
    #'wo-graph:targets-of-vertex
    #'wo-graph:sources-of-vertex
    1 (lambda (sr tg g) (wo-graph:add-edge sr tg
					   (make-array 3 :initial-contents (list 'reduced
										 sr
										 tg))
					   g)))
   (wo-graph-functions:make-single-sided-reducer
    #'wo-graph:sources-of-vertex
    #'wo-graph:targets-of-vertex
    1 (lambda (tg sr g) (wo-graph:add-edge sr tg
					   (make-array 3 :initial-contents (list 'reduced
										 sr
										 tg))
					   g)))))


;;(eval-when (:compile-toplevel :execute :load-top-level))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (setf (logical-pathname-translations "tmp")
	'(("**;*.*.*" "/tmp/"))))


(defun make-tmp-name (base-name type)
  "Creates a tmp file with name taken from base-name and the type from `type'.
Its main use is to create a set of related files based upon a given name, e.g.
name.dot name.png name.svg, ..."
  (merge-pathnames (make-pathname :host "tmp" :type type) base-name))

(defun tmp-name-exists (base-name type)
  "I added here translate-logical-pathname because
this function fails with a complaint about a _ when
sbcl is started in a directory containing a _"
  (directory (translate-logical-pathname (make-tmp-name base-name type))))

(defun pathname-to-string (pathname)
  "Converts a CL pathname to a string representation that
can be used an argument to an external process."
  (format nil "~A" (translate-logical-pathname pathname)))

(defun clear-cache ()
  "Remove all cache files that are generated by wo-git-gui.
Note that it just removes all files matching '.dot' and '.svg'
from the logical path tmp, so be carefull."
  (mapc #'delete-file (directory #P"tmp:*.dot"))
  (mapc #'delete-file (directory #P"tmp:*.svg")))

(defun read-graph (&optional (git-project *git-project*))
  (setf *default-graph* (wo-git:get-git-graph git-project)))

(defun reset ()
;  (wo-git:run-git *git-project* "fetch")
  (clear-cache)
  (read-graph))

(defun run-dot (dot-file image-file &optional &key cmap-file (node-href "\\N"))
  "Run dot on the `dot-file' and the resulting image will be written
to `image-file'.  If the optional `cmap-file' is given, the cmapx file is written to
that file.

The dot commad is taken from the *dot-cmd* variable and the command line for dot is

 dot <dot-file>  -Nhref=\\N r-T <type of image-file> -o <image-file>

or

 dot <dot-file> -Nhref=\\N -T <type of image-file> -o <image-file> -Tcmapx -o <cmap-file>
"
  (sb-ext:run-program *dot-cmd*
	       #-sbcl :arguments (if cmap-file
				     (list
				      (pathname-to-string dot-file)
				      (format nil "-Nhref=~A" node-href)
				      "-T"
				      (string-downcase (pathname-type image-file))
				      "-o"
				      (pathname-to-string image-file)
				      "-Tcmapx" "-o"
				      (pathname-to-string cmap-file))
				     (list
				      (pathname-to-string dot-file)
				      (format nil "-Nhref=~A" node-href)
				      "-T"
				      (string-downcase (pathname-type image-file))
				      "-o"
				      (pathname-to-string image-file)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun vertex-or-name-to-string (vertex)
  (etypecase vertex
    (integer (format nil "~(~40,'0X~)" vertex))
    (string vertex)))

(defun vertex-or-name-to-url-id (vertex)
  "Encodes a vertex or a symbolic name to a string suitable for embedding in a url.
The converse function is basically `name-or-rev-to-vertex'. Except for the asymmetry that this function does `url-encode' and the `name-or-rev-to-vertex' does not do the decode."
  (url-encode (vertex-or-name-to-string vertex)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Want to change it to weblocks.  If that is able to include svg's at least.
;;;
(pushnew (hunchentoot:create-folder-dispatcher-and-handler
	  "/include-files/"
	  (merge-pathnames (make-pathname :directory '(:relative "include-files"))
			   (asdf:system-source-directory :wo-git-gui)))
	 hunchentoot:*dispatch-table*)

(defun start-server (&optional &key (port 8988))
  "Start git gui webserver at port 8988 on this host."
  (unless *webserver-acceptor*
    (setf *webserver-acceptor* (make-instance 'hunchentoot:easy-acceptor :port port)))
  (hunchentoot:start *webserver-acceptor*))

(defun stop-server ()
  "Stops the git gui webserver"
  (hunchentoot:stop *webserver-acceptor*))

(defun turn-on-debugging ()
  (setf hunchentoot:*show-lisp-errors-p* t)
  (setf hunchentoot:*show-lisp-backtraces-p* t))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun subgraph (vertex-set graph)
  (wo-graph-functions:simplify graph :selector (lambda (v g)
			      (declare (ignore g))
			      (member v vertex-set :test #'equalp))
	    :reducers (list (wo-graph-functions:make-subgraph-reducer))))



(defun make-default-edge-attributes (selector-p)
  "Returns a edge attribute function which will color
the edge gray if one of the nodes is not interesting."
  (lambda (e g)
    (if (and (funcall selector-p (wo-graph:source-vertex e g) g)
	     (funcall selector-p (wo-graph:target-vertex e g) g))
	'(:color "black")
	'(:color "gray"))))

(defun make-color-edge-attributes ()
  "Returns a edge attribute function which will color
the edge gray if one of the nodes is not interesting."
  (lambda (e g)
    (declare (ignore g))
    (list :color
	  (if (= 3 (length e))
	      "gray"
	      "black"))))

(defun simplify-node-name (name)
  "Simplifies a full revision/tag name.  Typically they start with
lots of junk like 'refs/remove/...'  so we shorten them a bit with
this function."
  (subseq name (+ 1 (or (position #\/ name :from-end t) -1))))

(defun make-default-node-attribute (&optional &key (color))
  "Returns a node attribute function which will show either
a dot if the vertex does not have any names or a box
with all names if the vertex does have names.

If a color function is supplied it will be used to add a color attribute with
the result of the `color' function called on the vertex."
  (lambda (v g)
    (concatenate 'list
		 (alexandria:if-let ((names (mapcar #'simplify-node-name (wo-git:vertex-names v g))))
		   `(:shape :box :label ,(format nil "\"~{~A~^\\n~}\"" names))
		   (list :shape :point))
		 (when color
		   `(:color ,(funcall color v))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Utility function
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun name-or-rev-to-vertex (name graph)
  "Basically a wrapper around the function with the same name in the wo-git package.
But this one will return a valid vertex even if the name is empty."
  (let ((candidate (wo-git:name-or-rev-to-vertex name graph)))
    (if (member candidate (wo-graph:all-vertices graph) :test #'equal)
	candidate
	(first (wo-graph:all-vertices graph)))))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun to-be-merged-graph (mark-a mark-b graph stream)
  (let* ((outgoing-a (wo-graph-functions:neighborhood mark-a graph :selector #'wo-graph:targets-of-vertex))
	 (incoming-b (wo-graph-functions:neighborhood mark-b graph :selector #'wo-graph:sources-of-vertex)))

    (labels ((selector (v g)
	       (or (equalp mark-a v)
		   (and (wo-git:vertex-names v g)
			(and (member v outgoing-a :test #'equalp))
			(not (member v incoming-b :test #'equalp))
			(not (member v *dead-revisions* :test #'equalp)))))

	     (color (v)
	       (cond
		 ((equalp v mark-a) "blue")
		 ((equalp v mark-b) "green")
		 ((not ( member v incoming-b :test #'equalp)) "black")
		 (t "gray"))))

      (let ((result (wo-graph-functions:simplify graph :selector #'selector
						 :reducers *default-reducers*)))
	(write-to-dot stream result
		      :graph-attributes '(:rankdir "LR")
		      :node-attributes (make-default-node-attribute :color #'color)
		      :edge-attributes (make-default-edge-attributes #'selector)
		      :node-to-id #'vertex-or-name-to-string)
	result))))


(defun classified-by-edge-graph (graph stream)
  "Just for testing, very very inefficient."
  (let* ((edge-vertices  (wo-util:remove-from-set (mapcar (lambda (v) (name-or-rev-to-vertex v graph))
							  (wo-git::boundary-names graph))
						  *dead-revisions*
						  :test #'equalp))
	 (classification (wo-graph-functions::classify-by-reacheability edge-vertices graph))
	 (result (make-instance 'wo-git::git-graph))
	 (seen-edges (make-hash-table :test #'equalp))
	 (v-v-map (make-hash-table :test #'equalp))
	 (counter 0))

    (setf (wo-git::name-map result) (make-hash-table :test #'equalp))


    (maphash (lambda (k v)
	       (incf counter)
	       (wo-graph:add-vertex counter result)
	       (setf (gethash counter (wo-git::name-map result))
		     (if (eq (caar k) (cadr k))
			 (wo-git:vertex-names (caar k) graph)
			 (list (format nil "#: ~D" (length v)))))
	       (loop :for v2 :in v :do
		  (setf (gethash v2 v-v-map) counter)))
	     classification)

    (setf (wo-git::reverse-name-map result) (wo-util:reverse-table (wo-git::name-map result)))
    (loop :for v :in (wo-graph:all-vertices graph)
       :for v2 = (gethash v v-v-map)
       :do
       (loop :for tv :in (wo-graph:targets-of-vertex v graph)
	  :for tv2 = (gethash tv v-v-map)
	  :do
	  (unless (or (eql v2 tv2) (gethash (cons v2 tv2) seen-edges))
	    (wo-graph:add-edge v2 tv2 nil result)
	    (setf (gethash (cons v2 tv2) seen-edges) t))))


    (write-to-dot stream result
		  :node-attributes (make-default-node-attribute)
		  :edge-attributes (make-default-edge-attributes
				    (lambda (e g) t))
		  :node-to-id #'vertex-or-name-to-string)))

(defun neighborhood-graph (vertex graph distance stream &optional &key
			   mark-a mark-b (reducers *default-reducers*))
  "Write the neighborhood graph as a dot file to `stream'
and returns the reduced graph.

The neighboorhood is taken of `vertex' with the given `distance'.
It will also make sure that `mark-a' and `mark-b' are not removed from
the graph if they are specified.

Finally the optinal argument `reducers' is a list of reducers which is applied
to the graph.  This list of reducers is what makes the graph smaller."
  (let* ((neighbor-vertices
	  (wo-util:add-non-nil
	   (wo-graph-functions:neighborhood vertex graph :max-distance distance)
	   (list mark-a mark-b)))
	 (extended-neighbor-vertices
	  (wo-util:add-non-nil
	   (wo-graph-functions:neighborhood vertex graph :max-distance (+ 1 distance))
	   (list mark-a mark-b))))

    (labels ((selector (v g)
	       (declare (ignore g))
	       (member v extended-neighbor-vertices :test #'equalp))

	     (color (v)
	       (cond
		 ((equalp v vertex) "red")
		 ((equalp v mark-a) "blue")
		 ((equalp v mark-b) "green")
		 ((member v neighbor-vertices :test #'equalp) "black")
		 (t "gray"))))

      (let ((result (wo-graph-functions:simplify graph :selector #'selector
						 :reducers reducers)))
	(write-to-dot stream result
		      :node-attributes (make-default-node-attribute :color #'color)
		      :edge-attributes (make-color-edge-attributes)
		      :node-to-id #'vertex-or-name-to-string)
	result))))


(defun simple-name-attribute (vertex graph)
  (let ((names (wo-git:vertex-names vertex graph)))
    (if names
	(list :shape "box" :label (format nil "\"~{~A~^\\n~}\"" names))
	(list :shape "point"))))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun copy-file-to-stream (file-name stream &optional &key (skip 0))
  (with-open-file (in-stream file-name :direction :input)
    (loop :for line = (read-line in-stream nil nil)
       :repeat skip
       :while line)
    (loop :for line = (read-line in-stream nil nil)
       :while line
       :do
       (write-line line stream))))

(defun html-select-git-name (var-name default-vertex names stream)
  "`default-vertx' can either be a string indiciating a reference, or a integer, indicating a revision."
  (cl-who:with-html-output (s stream)
    ((:select :name var-name)
     (loop 
	:with default-name = (vertex-or-name-to-string default-vertex)
	:for name :in (sort (copy-seq names) #'string<)
	:finally (when default-name
		   (cl-who:htm ((:option :value default-vertex :selected "true")
				 (cl-who:str default-name))))
	:do
	(if (string-equal name default-name)
	    (progn (cl-who:htm
		    ((:option :value name :selected "true") (cl-who:str name)))
		   (setf default-name nil))
	    (cl-who:htm
	     ((:option :value name) (cl-who:str name))))))))

(defun create-svg-graph (base-name graph-to-dot-writer &optional node-ref-string)
  "Creates dot file if needed and runs dot if needed."
    (unless (tmp-name-exists base-name "dot")
      (with-open-file (s (make-tmp-name base-name "dot") :direction :output :if-exists :supersede)
	(funcall graph-to-dot-writer s)))
    (unless (tmp-name-exists base-name "svg")
      (run-dot (make-tmp-name base-name "dot")
	       (make-tmp-name base-name "svg")
	       :node-href node-ref-string )))

(defun write-info-selected-revision (vertex stream)

  (cl-git:with-repository (*git-project*)
    (let* ((commit (cl-git:git-lookup :object vertex))
	   (author (cl-git:git-author commit)))
      (cl-who:with-html-output (s stream)
	(:table
	 (:tr (:td "Message")
	      (:td (cl-who:esc (cl-git:git-message commit))))
	 (:tr (:td "Author")
	      (:td (cl-who:esc (getf author :name))))
	 (:tr (:td "Time")
	      (:td (cl-who:esc (local-time:to-rfc1123-timestring (getf author :time))))))
	(cl-git:git-free commit)))))


(defun write-version-info-revision (vertex stream)
  (let ((versions-after (version-or-after vertex))
	(versions-before (version-or-before vertex)))
    (when (or versions-after versions-before)
      (cl-who:with-html-output (s stream)
	(:h2 "Versions")
	(:table
	 (:tr (when versions-after (cl-who:htm (:th "Next Versions")))
	      (when versions-before (cl-who:htm (:th "Previous Versions"))))
	 (:tr
	  (when versions-after
	    (cl-who:htm
	     (:td
	      (:table
	       (:tr
		(loop :for name-list :in versions-after
		   :do
		   (cl-who:htm
		    (:td
		     (:table
		      (loop :for name :in name-list :do
			 (cl-who:htm
			  (:tr (:td (cl-who:str name))))))))))))))
	  (when versions-before
	    (cl-who:htm
	     (:td
	      (:table
	       (:tr
		(loop :for name-list :in versions-before
		   :do
		   (cl-who:htm
		    (:td
		     (:table
		      (loop :for name :in name-list :do
			 (cl-who:htm
			  (:tr (:td (cl-who:str name))))))))))))))))))))

(defun git-names-for-dropdown (graph)
  (remove-if (lambda (s) (cl-ppcre:scan *filter-names-scanner* s))
	     (wo-git:all-names graph)))

(define-easy-handler (neighborhood :uri "/neighborhood-graph")
    (vertex distance mark-a mark-b)
  "Shows the default neighborhood graph with a default distance.

Need to figure out how to embed this into a complete page with selection
possibilities etc.   Might just be embedded by using different means in html, but
not so sure yet."

  (let* ((*print-pretty* nil)
	 (distance (or (and distance (parse-integer distance)) 2))
	 (distance-str (format nil "~D" distance))
	 (vertex-vertex (name-or-rev-to-vertex vertex *default-graph*))
	 (vertex-a (name-or-rev-to-vertex mark-a *default-graph*))
	 (vertex-b (name-or-rev-to-vertex mark-b *default-graph*))
	 (base-name (format nil "nbh-~D-~A-~A-~A"
			    distance vertex-vertex vertex-a vertex-b)))

    (create-svg-graph base-name
		      (lambda (s)
			(neighborhood-graph vertex-vertex *default-graph*
					    distance s
					    :mark-a vertex-a :mark-b vertex-b))
		      (format nil "neighborhood-graph?vertex=\\N&distance=~D&mark-a=~A&mark-b=~A"
			      distance (vertex-or-name-to-url-id (or mark-a vertex-a))
			      (vertex-or-name-to-url-id (or mark-b vertex-b))))

    (setf (hunchentoot:content-type*) "application/xml")

    (cl-who:with-html-output-to-string (ss nil :prologue nil)
      ((:html
	 :xmlns "http://www.w3.org/1999/xhtml"
	 "xmlns:svg" "http://www.w3.org/2000/svg"
	 "xmlns:xlink" "http://www.w3.org/1999/xlink")
       (:head
	(:title "Neighborhood")
	(:link :rel "stylesheet" :href "/include-files/default.css"))
       (:body
	(:h1 "NEIGHBORHOOD")
	(:table
	 (:tr
	  ((:td :valign "top")
	   ((:form :action "neighborhood-graph" :method "get")
	    (:table
	     (:tr (:td "Starting revision (blue)")
		  (:td (html-select-git-name "mark-a" (or mark-a vertex-a) (git-names-for-dropdown *default-graph*) ss)))
	     (:tr (:td "End revision (green)")
		  (:td (html-select-git-name "mark-b" (or  mark-b vertex-b) (git-names-for-dropdown *default-graph*) ss)))
	     (:tr (:td "Selected revision (red)")
		  (:td (html-select-git-name "vertex" (or vertex vertex-vertex) (git-names-for-dropdown *default-graph*) ss)))
	     (:tr (:td "Distance")
		  (:td ((:input :type "text" :name "distance" :value distance-str)))))
	    ((:input :type "submit" :value "Regenerate")))
	   (:h2 "Other graphs")
	   ;; still to change vertex-a and vertex-b back to mark-a and mark-b
	   (:a :href (format nil "unmerged?mark-a=~A&amp;mark-b=~A"
			     (vertex-or-name-to-url-id (or mark-a vertex-a))
			     (vertex-or-name-to-url-id (or mark-b vertex-b))) "UNMERGED")
	   (write-version-info-revision vertex-vertex ss)
	   (:h2 "Selected Revision")
	   (write-info-selected-revision vertex-vertex ss))
	  ((:td :valign "top")
	   (copy-file-to-stream (make-tmp-name base-name "svg") ss :skip 4)))))))))

(define-easy-handler (master-overview :uri "/master-view")
    ()
  "Shows the master graph"

  (create-svg-graph "master"
		    (lambda (s)
		      (classified-by-edge-graph *default-graph* s)))
  (setf (hunchentoot:content-type*) "application/xml")
  (cl-who:with-html-output-to-string (s nil :prologue nil)
    ((:html
      :xmlns "http://www.w3.org/1999/xhtml"
      "xmlns:svg" "http://www.w3.org/2000/svg"
      "xmlns:xlink" "http://www.w3.org/1999/xlink")
     (:thead
      (:title "Master Ovierview"))
     (:body
      (:h1 "Master Overview")
      (copy-file-to-stream (make-tmp-name "master" "svg") s :skip 4)))))

(define-easy-handler (boundary :uri "/boundary")
    ()
  (cl-who:with-html-output-to-string (s)
    ((:html)
     (:thead
      (:title "---Boundary---"))
     (:body
      (:h1 "Boundary")
      (:table
       (cl-git:with-repository (*git-project*)
	 (loop :for name :in (sort (wo-git::boundary-names *default-graph*) #'string<)
	    :for rev = (wo-git:name-to-vertex name *default-graph*)
	    :for commit = (cl-git:git-lookup :commit rev)
	    :for author = (cl-git:git-author commit)
	    :for author-name = (getf author :name)
	    :for author-time = (getf author :time)
	    :do
	    (cl-who:htm
	     (:tr (:td (cl-who:str name)) 
		  (:td (cl-who:str (subseq (vertex-or-name-to-string rev) 0 5 )))
		  (:td (cl-who:str author-name)) 
		  (:td (cl-who:str author-time)))
	     (cl-git:git-free commit)))))))))

(define-easy-handler (non-merged :uri "/unmerged")
    (mark-a mark-b)
  (let* ((*print-pretty* nil)
	 (vertex-a (name-or-rev-to-vertex mark-a *default-graph*))
	 (vertex-b (name-or-rev-to-vertex mark-b *default-graph*))
	 (base-name (format nil "tbm-~A-~A" vertex-a vertex-b))

	 (unmerged-revisions
	  (wo-util:remove-from-set
	   (wo-graph-functions::reachable-from-not-reachable-from
	    vertex-a #'wo-graph:targets-of-vertex
	    vertex-b #'wo-graph:sources-of-vertex
	    *default-graph*)
	   (mapcar (lambda (s) (name-or-rev-to-vertex s *default-graph*)) *dead-revisions*) 
	   :test #'eql)))

    (create-svg-graph base-name
		      (lambda (s)
			(to-be-merged-graph vertex-a vertex-b *default-graph* s)))

    (setf (hunchentoot:content-type*) "application/xml")
    (cl-who:with-html-output-to-string (s nil :prologue nil)
      ((:html
	:xmlns "http://www.w3.org/1999/xhtml"
	 "xmlns:svg" "http://www.w3.org/2000/svg"
	 "xmlns:xlink" "http://www.w3.org/1999/xlink"
	)
       (:thead
	(:title "UNmerged"))
       (:body
	(:h1 "UNMERGED")
	((:form :action "unmerged" :method "get")
	 (:table
	  (:tr (:td "Starting revision")
	       (:td (html-select-git-name "mark-a" mark-a (wo-git:all-names *default-graph*) s)))
	  (:tr (:td "End revision")
	       (:td (html-select-git-name "mark-b" mark-b (wo-git:all-names *default-graph*) s)))
	  ((:input :type "submit" :value "Regenerate"))))
	(:h2 "Other graphs")
	(:a :href (format nil "neighborhood-graph?vertex=~A&amp;mark-a=~A&amp;mark-b=~A"
			  (vertex-or-name-to-url-id mark-a) 
			  (vertex-or-name-to-url-id mark-a)
			  (vertex-or-name-to-url-id mark-b)) "NEIGHBORHOOD")
	(:h2 "Table")
	(:table
	 (loop :for rev :in unmerged-revisions
	    :for names = (wo-git:vertex-names rev *default-graph*)
	    :do
	    (when names
	      (cl-who:htm
	       (:tr (:td (cl-who:str rev)) (:td (format s  "~{~A~^,~}" names)))))))
	(:h2 "Graph")
	(copy-file-to-stream (make-tmp-name base-name "svg") s :skip 4))))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun version-or-after (vertex)
  "First attempt to get the version number info for commits"
  (flet ((selector (v graph)
	   (let ((names (wo-git:vertex-names v graph)))
	     (some (lambda (name)
		     (cl-ppcre:scan *version-names-scanner* name))
		   names))))

    (mapcar (lambda (v) (wo-git:vertex-names v *default-graph*))
	    (wo-graph-functions:minimal-boundary-from vertex
					      #'wo-graph:targets-of-vertex
					      #'selector
					      *default-graph*))))


(defun version-or-before (vertex)
"Given a vertex in the git graphs stored in *default-graph* it will
return a list of versions which is either contains the version of
`vertex' if `vertex' has a version, or the minimal set of versions
preceding `vertex'.  

A version is a tag/branch name matching the regular expresion *version-names-scanner*.
"
  (flet ((selector (v graph)
	   (let ((names (wo-git:vertex-names v graph)))
	     (some (lambda (name)
		     (cl-ppcre:scan *version-names-scanner* name))
		   names))))

    (mapcar (lambda (v) (wo-git:vertex-names v *default-graph*))
	    (wo-graph-functions:minimal-boundary-from vertex
					      #'wo-graph:sources-of-vertex
					      #'selector
					      *default-graph*))))
;;; Idea
;;; What is needed is an algorithm which returns
;;;
;;; Input:  Set V of vertices in G
;;;         S a function V --> {false, true}
;;;
;;; Output:
;;;         Set W of vertices in G such that for each
;;;         w in W :
;;;             1. S(w) = true
;;;             2. All paths {v'=u1, u2, ... uk, w}, from v' in V to w
;;;                have that S(u_i) = false.
;;;
;;;
;;; One way: forward forward.
;;;
;;; Walk forward and mark with 'searching and collect all boundary elements.  When a boundary element is found, mark with 'found
;;; forward from there with 'deleting.  The 'deleting walk need to walk over all unmarked and all marked 'searching vertices.
;;; The 'searching need to walk over only unmarked elements.
;;;
;;; When done, collect all elements marked with 'found.
;;;
;;; Transition of mark:
;;;
;;;       state            from-state              S of destination              new state
;;;
;;;       unmarked          'search                      false                    'search
;;;       unmarked          'search                      true                     'found
;;;       unmarked          'found                       true/false               'delete
;;;       unmarked          'delete                      true/false               'delete
;;;       search            'search                       --                        ---
;;;       search            'delete                      true/false               'delete
;;;       found             'search                       --                        ---
;;;       found             '...
;;;
;;;
;;; Maybe simpler.
;;;
;;; Mark with integer 'n'
;;;
;;;
;;;
