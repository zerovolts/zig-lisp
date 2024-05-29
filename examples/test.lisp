(def vx (fn (v) (head v)))
(def vy (fn (v) (head (tail v))))

(def vadd
     (fn (a b) 
         (list (+ (vx a) (vx b))
               (+ (vy a) (vy b)))))

(def a (list 3 4))
(def b (list 7 2))
(vadd a b)