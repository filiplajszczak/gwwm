(define-module (wayland display )
  #:use-module (ice-9 format)
  ;; #:use-module (srfi srfi-26)
  #:use-module (oop goops)
  #:use-module (wayland config)
  #:use-module (wayland proxy)
  #:use-module (wayland registry)
  #:use-module (wayland event-loop)
  #:use-module (wayland interface)
  #:use-module (wayland util)
  #:use-module (wayland list)
  #:use-module (wayland listener)
  #:use-module ((system foreign) #:select (null-pointer?
                                           bytevector->pointer
                                           make-pointer
                                           procedure->pointer
                                           pointer->procedure
                                           pointer->bytevector
                                           pointer->string
                                           string->pointer
                                           sizeof
                                           %null-pointer
                                           dereference-pointer
                                           define-wrapped-pointer-type
                                           pointer-address
                                           void
                                           (int . ffi:int)
                                           (uint32 . ffi:uint32)
                                           (double . ffi:double)
                                           (size_t . ffi:size_t)
                                           (uintptr_t . ffi:uintptr_t)))
  #:use-module (system foreign-object)
  #:use-module (system foreign-library)
  #:use-module (bytestructures guile)
  #:export (wl-display?
            wrap-wl-display
            unwrap-wl-display

            wl-display-create
            wl-display-add-socket
            wl-display-add-socket-auto
            wl-display-destroy
            wl-display-destroy-clients
            wl-display-run
            wl-display-get-event-loop
            wl-display-terminate
            wl-display-add-destroy-listener

            wl-display-add-client-created-listener
            wl-display-init-shm

            wl-display-flush-clients
            wl-display-get-client-list

            ;; client
            wl-display-connect
            wl-display-disconnect
            wl-display-get-registry
            wl-display-get-fd
            wl-display-dispatch
            wl-display-roundtrip


            wl-display-read-events
            wl-display-flush))

;; (define wl-display-interface-struct
;;   (bs:struct `((sync ,(bs:pointer 'void))
;;                (get-registry ,(bs:pointer 'void)))))
(define %wl-display-interface
  (pointer->wl-interface
   (wayland-server->pointer "wl_display_interface")))

;; (define-public (wl-display-get-registry)
;;   (pk 'wl-display-get-registry(bytestructure-ref
;;                                (pointer->bytestructure
;;                                 (wl-interface->pointer %wl-display-interface)
;;                                 wl-display-interface-struct)
;;                                'get-registry )))

(define WL_DISPLAY_GET_REGISTRY 1)

;; (define-wrapped-pointer-type wl-display
;;   wl-display?
;;   wrap-wl-display unwrap-wl-display
;;   (lambda (b p)
;;     (format p "#<wl-display ~x>" (pointer-address (unwrap-wl-display b)))))
(define-class <wl-display> (<wl-proxy>))
(define (wl-display? i) (eq? (class-of i) <wl-display>))
(define (wrap-wl-display p)
  (make <wl-display> #:pointer p))
(define (unwrap-wl-display i)
  (.pointer i))

(define (wl-display-create)
  (let ((out ((wayland-server->procedure '* "wl_display_create" '()))))
    (if (null-pointer? out)
        #f
        (wrap-wl-display out))))

(define (wl-display-destroy w-display)
  ((wayland-server->procedure
    void "wl_display_destroy" '(*))
   (unwrap-wl-display w-display)))

(define (wl-display-destroy-clients w-display)
  ((wayland-server->procedure
    void "wl_display_destroy_clients" '(*))
   (unwrap-wl-display w-display)))

(define (wl-display-get-event-loop w-display)
  (wrap-wl-event-loop
   ((wayland-server->procedure
     '* "wl_display_get_event_loop" '(*))
    (unwrap-wl-display w-display))))

(define wl-display-add-socket
  (let ((proc (wayland-server->procedure
               ffi:int "wl_display_add_socket" '(* *))))
    (lambda (a b)
      (proc (unwrap-wl-display a)
            (string->pointer b)))))

(define (wl-display-add-socket-auto display)
  (let ((out ((wayland-server->procedure
               '* "wl_display_add_socket_auto" '(*))
              (unwrap-wl-display display))))
    (if (null-pointer? out)
        #f
        (pointer->string out))))

(define wl-display-add-socket-fd
  (let ((proc (wayland-server->procedure
               ffi:int "wl_display_add_socket" (list '* ffi:int))))
    (lambda (a b)
      (proc (unwrap-wl-display a) b))))

(define wl-display-terminate
  (compose (wayland-server->procedure
            void "wl_display_terminate" '(*)) unwrap-wl-display))

(define (wl-display-run w-display)
  ((wayland-server->procedure
    void "wl_display_run" '(*))
   (unwrap-wl-display w-display)))

(define wl-display-flush-clients
  (compose (wayland-server->procedure
            void "wl_display_flush_clients" '(*)) unwrap-wl-display))

(define %wl-display-add-destroy-listener
  (wayland-server->procedure void "wl_display_add_destroy_listener" '(* *)))

(define (wl-display-add-destroy-listener w-display w-listener)
  (%wl-display-add-destroy-listener (unwrap-wl-display w-display)
                                    (unwrap-wl-listener w-listener)))
(define %wl-display-add-client-created-listener
  (wayland-server->procedure void "wl_display_add_client_created_listener"
                             '(* *)))

(define (wl-display-add-client-created-listener w-display w-listener)
  (%wl-display-add-client-created-listener
   (unwrap-wl-display w-display)
   (wl-listener->pointer w-listener)))

(define %wl-display-get-client-list
  (wayland-server->procedure
   '* "wl_display_get_client_list"
   '(*)))

(define (wl-display-get-client-list w-display)
  (wrap-wl-list
   (%wl-display-get-client-list
    (unwrap-wl-display w-display))))

(define %wl-display-init-shm (wayland-server->procedure ffi:int "wl_display_init_shm" '(*)))
(define (wl-display-init-shm w-display)
  (%wl-display-init-shm (unwrap-wl-display w-display)))

;; client

(define* (wl-display-connect #:optional (name #f))
  "if success, return wl-display else #f."
  (let ((out ((wayland-client->procedure '* "wl_display_connect" '(*))
              (if name (string->pointer name) %null-pointer))))
    (if (null-pointer? out)
        (error "not connect!")
        (wrap-wl-display out))))

(define (wl-display-connect-to-fd fd)
  "if success, return wl-display else #f."
  (let ((out ((wayland-client->procedure '* "wl_display_connect_to_fd" (list ffi:int))
              fd)))
    (if (null-pointer? out)
        #f
        (wrap-wl-display out))))

(define %wl-display-disconnect (wayland-client->procedure void "wl_display_disconnect" '(*)))
(define (wl-display-disconnect w-display)
  (unless (wl-display? w-display)
    (error "error display:" w-display))
  (%wl-display-disconnect
   (unwrap-wl-display w-display)))

(define (wl-display-get-fd display)
  ((wayland-client->procedure ffi:int "wl_display_get_fd" '(*))
   (unwrap-wl-display display)))

(define (wl-display-get-registry display)
  (wrap-wl-registry (wl-proxy-marshal-constructor
                     display
                     WL_DISPLAY_GET_REGISTRY
                     (wl-interface->pointer %wl-registry-interface))))

(define %wl-display-dispatch (wayland-client->procedure ffi:int "wl_display_dispatch" '(*)))

(define (wl-display-dispatch display)
  (%wl-display-dispatch
   (unwrap-wl-display display)))

(define (wl-display-roundtrip display)
  ((wayland-client->procedure ffi:int "wl_display_roundtrip" '(*))
   (unwrap-wl-display display)))

(define %wl-display-read-events
  (wayland-client->procedure ffi:int "wl_display_read_events" '(*)))
(define (wl-display-read-events display)
  (%wl-display-read-events (unwrap-wl-display display)))
(define %wl-display-flush (wayland-client->procedure ffi:int "wl_display_flush" '(*)))
(define (wl-display-flush w-display)
  (%wl-display-flush (unwrap-wl-display w-display)))
