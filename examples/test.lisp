(def a (quote (+ 1 2 3)))

(+ (eval a) 4)

(eq? 6 (apply + (list 1 2 3)))

(cond ((eq? 2 3) 34)
      ((eq? (eval a) 6) 17)
      (true 55))