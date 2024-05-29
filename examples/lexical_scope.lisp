(def x 5)
(def f (fn (x) (fn () x)))
(def g (f 10))
(g)