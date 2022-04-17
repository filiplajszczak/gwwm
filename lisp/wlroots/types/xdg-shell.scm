(define-module (wlroots types xdg-shell)
  #:use-module (wlroots types)
  #:use-module (wayland)
  #:use-module (wlroots util box)
  #:use-module (bytestructures guile)
  #:use-module (oop goops)
  #:use-module ((system foreign) #:select ((uint32 . ffi:uint32)))
  #:use-module (wlroots utils)
  #:export (%wlr-xdg-shell-struct
            %wlr-xdg-surface-struct
            wlr-xdg-shell-create
            wrap-wlr-xdg-shell
            unwrap-wlr-xdg-shell
            wrap-wlr-xdg-surface
            unwrap-wlr-xdg-surface
            wlr-xdg-surface-from-wlr-surface
            wlr-xdg-toplevel-set-activated))
(define-wlr-types-class wlr-xdg-shell)
(define %wlr-xdg-shell-struct
  (bs:struct `((global ,(bs:pointer '*))
               (clients ,%wl-list)
               (popup-grabs ,%wl-list)
               (ping-timeout ,uint32)
               (display-destroy ,%wl-listener)
               (events ,(bs:struct `((new-surface ,%wl-signal-struct)
                                     (destroy ,%wl-signal-struct))))
               (data ,(bs:pointer 'void)))))
;; (define (wrap-wlr-xdg-shell p)
;;   )
(define %wlr-xdg-surface-state-struct
  (bs:struct `((configure-serial ,uint32)
               (geometry ,%wlr-box-struct))))
(define %wlr-xdg-surface-struct
  (bs:struct `((client ,(bs:pointer '*))
               (resource ,(bs:pointer '*))
               (surface ,(bs:pointer '*))
               (link ,%wl-list)
               (role ,int)
               (union ,(bs:union `((toplevel ,(bs:pointer '*))
                                   (popup ,(bs:pointer '*)))))
               (popups ,%wl-list)
               (added ,int)
               (configured ,int)
               (mapped ,int)
               (configure-idle ,(bs:pointer '*))
               (scheduled-serial ,uint32)
               (configure-list ,%wl-list)
               (current ,%wlr-xdg-surface-state-struct)
               (pending ,%wlr-xdg-surface-state-struct)
               (surface-destroy ,%wl-listener)
               (surface-commit ,%wl-listener)
               (events ,(bs:struct `((destroy ,%wl-signal-struct)
                                     (ping-timeout ,%wl-signal-struct)
                                     (new-popup ,%wl-signal-struct)
                                     (map ,%wl-signal-struct)
                                     (unmap ,%wl-signal-struct)
                                     (configure ,%wl-signal-struct)
                                     (ack-configure ,%wl-signal-struct))))
               (data ,(bs:pointer 'void)))))
(define-wlr-procedure (wlr-xdg-shell-create display)
  ('* "wlr_xdg_shell_create" '(*))
  (wrap-wlr-xdg-shell
   (% (unwrap-wl-display display))))
(define-wlr-types-class wlr-xdg-surface)

(define-wlr-procedure (wlr-xdg-surface-from-wlr-surface surface)
  ('* "wlr_xdg_surface_from_wlr_surface" '(*))
  (wrap-wlr-xdg-surface
   (% (unwrap-wlr-xdg-surface surface))))

(define-wlr-procedure (wlr-xdg-toplevel-set-activated surface activated)
  (ffi:uint32 "wlr_xdg_toplevel_set_activated" (list '* ffi:int))
  "Returns the associated configure serial."
  (% (unwrap-wlr-xdg-surface surface) (if activated 1 0)))