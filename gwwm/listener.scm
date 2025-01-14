(define-module (gwwm listener)
  #:use-module (system foreign)
  #:use-module (wayland signal)
  #:use-module (wayland list)
  #:use-module (wayland listener)
  #:use-module (oop goops)
  #:export (<listener-manager>
            register-listener
            remove-listeners
            scm-from-listener
            add-listen))

(eval-when (expand load eval)
  (load-extension "libgwwm" "scm_init_gwwm_listener"))
(define-class <listener-manager> ()
  (listeners #:init-value (list)))
(define-method (register-listener (o <listener-manager>))
  (%register-listener o))

(define-method (remove-listeners (o <listener-manager>))
  (let* ((obj o)
         (listeners (slot-ref obj 'listeners)))
    (slot-set! obj 'listeners '())
    (for-each (lambda (o)
                (wl-list-remove (.link o)))
              listeners)))
(define-method (add-listen (o <listener-manager>)
                           (signal <wl-signal>)
                           (procedure <procedure>))
  (%add-listen o signal (procedure->pointer void
                                            (lambda (listener data)
                                              (procedure (wrap-wl-listener listener) data))
                                            (list '* '*))))
