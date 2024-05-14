(def a (quote (+ 1 2 3)))

(+ (eval a) 4)

(apply + (list 1 2 3))