(in-package #:core-gp)

;;;
;;; subtree crossover
;;;

(defun apply-crossover (pop config)
  "Apply tree crossover to the population."
  (loop with population = (individuals pop) 
     for position from 0 below (size pop) by 2
     do (when (< (random 1.0) (cx-rate (operators config)))
	  (multiple-value-bind (o1 o2)
	      (funcall (cx-operator (operators config))
		       (genome (aref population position)) 
		       (genome (aref population (1+ position))) config)
	    (setf (aref population position) o1 
		  (aref population (1+ position)) o2)))))


;;;
;;; GA operators
;;;

(defgeneric one-point-crossover (genome1 genome2 config)
  (:documentation "One point crossover operator."))

(defmethod one-point-crossover ((genome1 bit-genome) (genome2 bit-genome) config)
  (let ((size (genome-size (population config))))
      (multiple-value-bind (o1 o2)
	  (cross-chromossomes (chromossome genome1) (chromossome genome2) size)
	(values (make-instance
		 'individual 
		 :id (generate-id) :genome (make-bit-genome o1 size)
		 :fitness (make-fitness (fitness-type (evaluation config))))
		(make-instance 
		 'individual 
		 :id (generate-id) :genome (make-bit-genome o2 size)
		 :fitness (make-fitness (fitness-type (evaluation config))))))))

(defmethod one-point-crossover ((genome1 integer-genome) (genome2 integer-genome) config)
  (let ((size (genome-size (population config))))
      (multiple-value-bind (o1 o2)
	  (cross-chromossomes (chromossome genome1) (chromossome genome2) size)
	(values (make-instance
		 'individual 
		 :id (generate-id) :genome (make-integer-genome o1 size)
		 :fitness (make-fitness (fitness-type (evaluation config))))
		(make-instance 
		 'individual 
		 :id (generate-id) :genome (make-integer-genome o2 size)
		 :fitness (make-fitness (fitness-type (evaluation config))))))))

(defun cross-chromossomes (c1 c2 size)
  (let ((cut-point (random size))
	(o1 (copy-array c1))
	(o2 (copy-array c2)))
    (loop for index from cut-point below size
       do (progn
	    (setf (aref o1 index) (aref c2 index))
	    (setf (aref o2 index) (aref c1 index)))
       finally (return (values o1 o2)))))



(defgeneric uniform-crossover (genome1 genome2 config)
  (:documentation "Uniform crossover operator."))

(defmethod uniform-crossover ((genome1 bit-genome) (genome2 bit-genome) config)
  (let ((size (genome-size (population config))))
    (multiple-value-bind (o1 o2)
	(uniform-cross-chromossomes (chromossome genome1) (chromossome genome2) size)
      (values (make-instance
	       'individual 
	       :id (generate-id) :genome (make-bit-genome o1 size)
	       :fitness (make-fitness (fitness-type (evaluation config))))
	      (make-instance 
	       'individual 
	       :id (generate-id) :genome (make-bit-genome o2 size)
	       :fitness (make-fitness (fitness-type (evaluation config))))))))
 
(defmethod uniform-crossover ((genome1 integer-genome) (genome2 integer-genome) config)
  (let ((size (genome-size (population config))))
    (multiple-value-bind (o1 o2)
	(uniform-cross-chromossomes (chromossome genome1) (chromossome genome2) size)
      (values (make-instance
	       'individual 
	       :id (generate-id) :genome (make-integer-genome o1 size)
	       :fitness (make-fitness (fitness-type (evaluation config))))
	      (make-instance 
	       'individual 
	       :id (generate-id) :genome (make-integer-genome o2 size)
	       :fitness (make-fitness (fitness-type (evaluation config))))))))

(defun uniform-cross-chromossomes (c1 c2 size)
   (let ((o1 (copy-array c1))
	 (o2 (copy-array c2)))
     (loop for g1 across c1 and g2 across c2
	for i from 0 below size
	when (< (random 1.0) 0.5) 
	do (progn
	     (setf (aref o2 i) c1)
	     (setf (aref o1 i) c2))
	finally (return (values o1 o2)))))


;; order-based uniform cx

(defmethod uniform-crossover ((genome1 permutation-genome) (genome2 permutation-genome) config)
  (let ((size (genome-size (population config))))
    (multiple-value-bind (o1 o2)
	(uniform-order-cross (chromossome genome1) (chromossome genome2) size)
      (values (make-instance
	       'individual 
	       :id (generate-id) :genome (make-permutation-genome o1 size)
	       :fitness (make-fitness (fitness-type (evaluation config))))
	      (make-instance 
	       'individual 
	       :id (generate-id) :genome (make-permutation-genome o2 size)
	       :fitness (make-fitness (fitness-type (evaluation config))))))))

(defun filter-genes (genes parent)
  (loop for gene across parent
	unless (member gene genes)
	collect gene into new-genes
	finally (return new-genes)))

(defun uniform-order-cross (parent1 parent2 size)
  (let ((offspring1 (make-array size
				:initial-contents
				(loop repeat size collect -1) 
				:element-type
				(array-element-type parent1)))
	(offspring2 (make-array size 
				:initial-contents
				(loop repeat size collect -1)
				:element-type
				(array-element-type parent2))))
    (loop for p1 across parent1 and p2 across parent2
       for i from 0 below size
       if (< (random 1.0) 0.5) 
       do (progn
	    (setf (aref offspring1 i) p1)
	    (setf (aref offspring2 i) p2))
       and collect p1 into genes1 and collect p2 into genes2
       finally (let ((genes-fill1 (filter-genes genes1 parent2))
		     (genes-fill2 (filter-genes genes2 parent1)))
		 (loop for g across offspring1
		    for j from 0 below size
		    when (= g -1) do (progn
				       (setf (aref offspring1 j) (first genes-fill1))
				       (setf genes-fill1 (rest genes-fill1))))
		 (loop for g across offspring2
		    for j from 0 below size
		    when (= g -1) do (progn
				       (setf (aref offspring2 j) (first genes-fill2))
				       (setf genes-fill2 (rest genes-fill2))))
		 (return (values offspring1 offspring2))))))


;;;
;;; GP operators
;;;

(defgeneric tree-crossover (genome1 genome2 config)
  (:documentation "Tree crossover operator."))

(defmethod tree-crossover ((genome1 tree-genome) (genome2 tree-genome) config)
  (multiple-value-bind (o1 o2)
      (cross-subtrees (chromossome genome1) 
		      (chromossome genome2) 
		      (maximum-size (population config)))
    (values (make-instance 
	     'individual 
	     :id (generate-id)
	     :genome (make-tree-genome
		      (copy-tree o1) (max-tree-depth o1) (count-tree-nodes o1))
	     :fitness (make-fitness (fitness-type (evaluation config))))
	    (make-instance 
	     'individual 
	     :id (generate-id)
	     :genome (make-tree-genome
		      (copy-tree o2) (max-tree-depth o2) (count-tree-nodes o2))
	     :fitness (make-fitness (fitness-type (evaluation config)))))))

(defun cross-subtrees (p1 p2 depth)
  "Exchanges two subtrees in a random point."
  (let* ((p1-point (random (count-tree-nodes p1)))
         (p2-point (random (count-tree-nodes p2)))
         (o1 (list (copy-tree p1)))
         (o2 (list (copy-tree p2))))
    (multiple-value-bind (p1-subtree p1-fragment)
        (get-subtree (first o1) o1 p1-point)
      (multiple-value-bind (p2-subtree p2-fragment)
          (get-subtree (first o2) o2 p2-point)
        (setf (first p1-subtree) p2-fragment)
        (setf (first p2-subtree) p1-fragment)))
    (validate-crossover p1 o1 p2 o2 depth)))

(defun get-subtree (tree point index)
  "Return a subtree."
  (if (= index 0)
      (values point (copy-tree tree) index)
      (if (consp tree)
	  (do* ((tree-rest (rest tree) (rest tree-rest))
		(arg (first tree-rest) (first tree-rest)))
	       ((not tree-rest) (values nil nil index))
	    (multiple-value-bind
		  (new-point new-tree new-index)
		(get-subtree arg tree-rest (1- index))
	      (if (= new-index 0)
		  (return (values new-point new-tree new-index))
		  (setf index new-index))))
	  (values nil nil index))))

(defun validate-crossover (p1 o1 p2 o2 depth)
  "Validates the offspring. If they pass the maximum depth they are rejected."
  (let ((p1-limit (max-tree-depth (first o1)))
        (p2-limit (max-tree-depth (first o2))))
    (values
     (if (or (= 1 p1-limit) (> p1-limit depth))
         p1 (first o1))
     (if (or (= 1 p2-limit) (> p2-limit depth))
         p2 (first o2)))))


