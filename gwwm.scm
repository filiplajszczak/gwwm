(define-module (gwwm)
  #:use-module (oop goops)
  #:use-module (ice-9 getopt-long)
  #:use-module (ice-9 format)
  #:use-module (system repl server)
  #:use-module (gwwm keymap)
  #:use-module (gwwm i18n)
  #:use-module (gwwm monitor)
  #:use-module (gwwm layout)
  #:use-module (gwwm utils)
  #:use-module (gwwm utils srfi-215)
  #:use-module (wayland display)
  #:use-module (wlroots types pointer)
  #:use-module (wlroots backend)
  #:use-module (wlroots types output)
  #:use-module (wlroots types seat)
  #:use-module (gwwm configuration)
  #:use-module (gwwm hooks)
  #:use-module (gwwm commands)
  #:export (main))

(eval-when (expand load eval)
  (load-extension "libgwwm" "scm_init_gwwm"))


(define-public (keymap-global-set key command)
  (keymap-set (global-keymap) key command))
(define (init-global-keybind)
  (keymap-global-set (kbd (s S space))

                     togglefloating)
  (keymap-global-set (kbd (s S c))
                     killclient)

  (keymap-global-set
   (kbd (s f))
   togglefullscreen)
  (keymap-global-set
   (kbd (s j))
   (lambda ()
     (focusstack 1)))
  (keymap-global-set
   (kbd (s k))
   (lambda ()
     (focusstack -1)))
  (keymap-global-set
   (kbd (s e))
   (lambda ()
     (spawn "emacs")))
  (keymap-global-set
   (kbd (s Tab))
   zoom)
  (keymap-global-set
   (kbd (s S q))
   gwwm-quit)
  (for-each (lambda (a)
              (keymap-global-set
               (kbd* `(C M ,(string->symbol (string-append
                                             "F" (number->string a)))))
               (lambda () (chvt a))))
            (iota 12 1))
  (define (tagkeys k)
    (keymap-global-set (kbd* `(s ,k)) (lambda () (view k)))
    (keymap-global-set (kbd* `(C s ,k)) (lambda () (toggleview k)))
    (keymap-global-set (kbd* `(s S ,k)) (lambda () (tag k)))
    (keymap-global-set (kbd* `(C s S ,k)) (lambda () (toggletag k))))
  (for-each tagkeys (iota 10 0)))
(define option-spec
  '((version (single-char #\v) (value #f))
    (help (single-char #\h) (value #f))))
(define-public (parse-command-line)
  (let* ((options (getopt-long (command-line) option-spec))
         (help-wanted (option-ref options 'help #f))
         (version-wanted (option-ref options 'version #f)))
    (if (or version-wanted help-wanted)
        (begin (when version-wanted
                 (display (string-append "gwwm " %version "\n")))
               (when help-wanted
                 (display (G_ "\
gwwm [options]
  -v --version  Display version
  -h --help     Display this help
")))
               (exit 0)))))
(define-once global-keymap
  (make-parameter (make-keymap)))
(define (setup-server)
  (false-if-exception (spawn-server (make-tcp-server-socket))))
;; (primitive-load-path "gwwm/startup.scm")

(define (setup-socket)
  (let ((socket (wl-display-add-socket-auto (gwwm-display))))
    (if socket
        (begin (setenv "WAYLAND_DISPLAY" socket)
               (send-log DEBUG
                         (format #f (G_ "set WAYLAND_DISPLAY to ~S.") socket)
                         'SOCKET socket))
        (begin
          (send-log EMERGENCY (G_ "wl-display-add-socket-auto fail.") 'SOCKET socket)
          (exit 1)))))

(define (config-setup)
  (add-to-load-path
   (string-append
    (get-xdg-config-home)
    "/" "gwwm"))
  (%config-setup))

(define (main)
  (setlocale LC_ALL "")
  (textdomain %gettext-domain)
  (define (set-mode m)
    (let ((output (monitor-wlr-output m)))
      (wlr-output-set-mode output (wlr-output-preferred-mode output))))
  (add-hook! create-monitor-hook set-mode)
  (define (set-default-layout m)
    (set! (monitor-layouts m)
          (make-list 2
                     (make <layout>
                       #:symbol "[]="
                       #:procedure %tile))))
  (add-hook! create-monitor-hook set-default-layout)

  (define (pass-modifiers k)
    (wlr-seat-set-keyboard (gwwm-seat) (keyboard-input-device k)))
  (add-hook! axis-event-hook
             (lambda (event)
               (wlr-seat-pointer-notify-axis
                (gwwm-seat)
                (wlr-event-pointer-axis-time-msec event)
                (wlr-event-pointer-axis-orientation event)
                (wlr-event-pointer-axis-delta event)
                (wlr-event-pointer-axis-delta-discrete event)
                (wlr-event-pointer-axis-source event))))
  (current-log-callback
   (let ((p (current-error-port)))
     (lambda (msg)
       (let ((msg2 msg))
         (format p "[~a]| ~a | "
                 (cdr (assq 'SEVERITY msg))
                 (cdr (assq 'MESSAGE msg)))
         (set! msg2 (assoc-remove! (assoc-remove! msg2 'SEVERITY) 'MESSAGE))
         (for-each (lambda (a)
                     (display (car a) p)
                     (display ":" p)
                     (display (object->string(cdr a)) p)
                     (display " " p))
                   msg2)
         (newline p)))))
  (add-hook! modifiers-event-hook pass-modifiers )
  (parse-command-line)
  (send-log DEBUG (G_ "init global keybind ..."))
  (init-global-keybind)
  (unless (getenv "XDG_RUNTIME_DIR")
    (send-log EMERGENCY (G_ "XDG_RUNTIME_DIR must be set."))
    (exit 1))
  (setvbuf (current-output-port) 'line)
  (setvbuf (current-error-port) 'line)

  (%gwwm-setup)

  (config-setup)
  (set-current-module (resolve-module '(guile-user)))
  (setup-server)
  (setup-socket)
  ;; Start the backend. This will enumerate outputs and inputs, become the DRM
  ;; master, etc
  (if (wlr-backend-start (gwwm-backend))
      (send-log INFO (G_ "backend is started."))
      (begin (send-log ERROR (G_ "gwwm cannot start backend!"))
             (exit 1)))
  (%gwwm-run)
  (%gwwm-cleanup))
