(define-module (wlroots types)
  #:use-module (wayland util)
  #:use-module (oop goops)
  #:use-module (srfi srfi-26)
  #:use-module ((system foreign) #:select(pointer-address pointer?))
  #:use-module ((bytestructures guile) #:select(bytestructure?))
  #:export-syntax ( define-wlr-types-class
                    define-wlr-types-class-public)
  #:export (get-pointer))

(define-class <wlr-type> ()
  (pointer #:accessor .pointer #:init-keyword #:pointer))

(define-method (= (f <wlr-type>) (l <wlr-type>))
  (= (.pointer f)
     (.pointer l)))

(define-generic get-pointer)
(define-syntax define-wlr-types-class
  (lambda (x)
    (syntax-case x ()
      ((_ name)
       (let ((symbol (syntax->datum #'name))
             (identifier (cut datum->syntax #'name <>)))
         (with-syntax ((rtd (identifier (symbol-append '< symbol '>)))
                       (wrap (identifier (symbol-append 'wrap- symbol )))
                       (unwrap (identifier (symbol-append 'unwrap- symbol)))
                       (is? (identifier (symbol-append symbol '?))))
           #`(begin
               (define-class rtd (<wlr-type>))
               (define (wrap p)
                 (make rtd #:pointer p))
               (define (unwrap o)
                 (.pointer o))
               (define-method (get-pointer (o rtd))
                 (let ((u (unwrap o)))
                   (cond ((pointer? u) u)
                         ((bytestructure? u) (bytestructure->pointer u)))))
               (define (is? o) (is-a? o rtd)))))))))

(define-syntax define-wlr-types-class-public
  (lambda (x)
    (syntax-case x ()
      ((_ name)
       (let ((symbol (syntax->datum #'name))
             (identifier (cut datum->syntax #'name <>)))
         (with-syntax ((rtd (identifier (symbol-append '< symbol '>)))
                       (wrap (identifier (symbol-append 'wrap- symbol )))
                       (unwrap (identifier (symbol-append 'unwrap- symbol)))
                       (is? (identifier (symbol-append symbol '?))))
           #`(begin
               (define-wlr-types-class name)
               (export wrap)
               (export unwrap)
               (export is? ))))))))
