(def a (quote (+ 1 2 3)))

(+ (eval a) 4)

(eq? 6 (apply + (list 1 2 3)))