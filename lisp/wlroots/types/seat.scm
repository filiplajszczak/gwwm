(define-module (wlroots types seat)
  #:use-module (wayland list)
  #:use-module (wayland display)
  #:use-module (wayland signal)
  #:use-module (wayland listener)
  #:use-module (srfi srfi-26)
  ;; #:use-module (wlroots render renderer)
  ;; #:use-module (wlroots types output-layout)
  #:use-module (wlroots utils)
  #:use-module (bytestructures guile)
  #:use-module ((system foreign) #:select ((uint32 . ffi:uint32)
                                           (float . ffi:float)
                                           (int . ffi:int)
                                           (void . ffi:void)
                                           %null-pointer
                                           string->pointer))
  #:use-module (oop goops)
  #:export (wrap-wlr-seat
            unwrap-wlr-seat
            wlr-seat-create
            wlr-seat-pointer-notify-frame
            WLR_POINTER_BUTTONS_CAP))

(define WLR_POINTER_BUTTONS_CAP 16)
(define %wlr-serial-range-struct
  (bs:struct `((min-incl ,uint32)
               (max-incl ,uint32))))

(define %wlr-serial-ringset
  (bs:struct `((data ,%wlr-serial-range-struct)
               (end ,int)
               (count ,int))))
(define %wlr-seat-client-struct
  (bs:struct `((client ,(bs:pointer '*))
               (seat ,(bs:pointer (delay %wlr-seat-struct)))
               (link ,%wl-list)
               (resources ,%wl-list)
               (pointers ,%wl-list)
               (keyboards ,%wl-list)
               (touches ,%wl-list)
               (data-devices ,%wl-list)
               (events ,(bs:struct `((destroy ,%wl-signal-struct))))
               (serials ,%wlr-serial-ringset)
               (needs-touch-frame ,int))))
(define %wlr-seat-pointer-state-struct
  (bs:struct `((seat ,(bs:pointer (delay %wlr-seat-struct)))
               (focused-client ,(bs:pointer '*))
               (focused-surface ,(bs:pointer '*))
               (sx ,double)
               (sy ,double)
               (grab ,(bs:pointer '*))
               (default-grab ,(bs:pointer '*))
               (sent-axis-source ,int)
               (cached-axis-source ,int)
               (buttons ,(bs:vector WLR_POINTER_BUTTONS_CAP uint32))
               (button-count ,size_t)
               (grab-button ,uint32)
               (grab-serial ,uint32)
               (grab-time ,uint32)
               (surface-destroy ,%wl-listener)
               (events ,(bs:struct `((focus-change ,%wl-listener)))))))
(define %wlr-seat-keyboard-state-struct
  (bs:struct `((seat ,(bs:pointer (delay %wlr-seat-struct)))
               (keyboard ,(bs:pointer '*))
               (focused-client ,(bs:pointer %wlr-seat-client-struct))
               (focused-surface ,(bs:pointer '*))
               (keyboard-destroy ,%wl-listener)
               (keyboard-keymap ,%wl-listener)
               (keyboard-repeat-info ,%wl-listener)
               (surface-destroy ,%wl-listener)
               (grab ,(bs:pointer '*))
               (default-grab ,(bs:pointer '*))
               (events ,(bs:struct `((focus-change ,%wl-listener)))))))
(define %wlr-seat-touch-state-struct
  (bs:struct `((seat ,(bs:pointer '*))
               (touch-points ,%wl-list)
               (grab-serial ,uint32)
               (grab-id ,uint32)
               (grab ,(bs:pointer '*))
               (default-grab ,(bs:pointer '*)))))
(define %wlr-seat-struct
  (bs:struct `((global ,(bs:pointer '*))
               (display ,(bs:pointer '*))
               (clients ,%wl-list)
               (name ,cstring-pointer)
               (capabilities ,uint32)
               (accumulated-capabilities ,uint32)
               (last-event ,(bs:struct `((tv-sec ,long)
                                         (tv-nsec ,long))))
               (selection-source ,(bs:pointer '*))
               (selection-serial ,uint32)
               (selection-offers ,%wl-list)
               (primary-selection-source ,(bs:pointer '*))
               (primary-selection-serial ,uint32)
               (drag ,(bs:pointer '*))
               (drag-source ,(bs:pointer '*))
               (drag-serial ,uint32)
               (drag-offers ,%wl-list)
               (pointer-state ,%wlr-seat-pointer-state-struct)
               (keyboard-state ,%wlr-seat-keyboard-state-struct)
               (touch-state ,%wlr-seat-touch-state-struct)
               (display-destroy ,%wl-listener)
               (selection-source-destroy ,%wl-listener)
               (primary-selection-source-destroy ,%wl-listener)
               (drag-source-destroy ,%wl-listener)
               (event ,(bs:struct (map (cut cons <> (list %wl-signal-struct))
                                       '(pointer-grab-begin
                                         pointer-grab-end
                                         keyboard-grab-begin
                                         keyboard-grab-end
                                         touch-grab-begin
                                         touch-grab-end
                                         request-set-cursor

                                         request-set-selection

                                         set-selection

                                         request-set-primary-selection

                                         set-primary-selection

                                         request-start-drag
                                         start-drag

                                         destroy))
                                  ))
               (data ,(bs:pointer 'void)))))

(define-class <wlr-seat> ()
  (pointer #:accessor .pointer #:init-keyword #:pointer))
(define (wrap-wlr-seat p)
  (make <wlr-seat> #:pointer p))
(define (unwrap-wlr-seat o)
  (.pointer o))

(define wlr-seat-create
  (let ((proc (wlr->procedure '* "wlr_seat_create" '(* *))))
    (lambda (display name)
      (wrap-wlr-seat (proc (unwrap-wl-display display)
                           (string->pointer name ))))))
(define wlr-seat-pointer-notify-frame
  (let ((proc (wlr->procedure ffi:void "wlr_seat_pointer_notify_frame" '(*))))
    (lambda (seat)
      (proc (unwrap-wlr-seat seat)))))