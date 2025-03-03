(use-modules
 (guix utils) (guix packages)
 ((guix licenses) #:prefix license:)
 (gnu packages xorg)
 (guix download)
 (guix git-download)
 (gnu packages gettext)
 (guix gexp)
 (gnu packages gl)
 (gnu packages xdisorg)
 (guix build-system gnu)
 (gnu packages bash)
 (gnu packages)
 (gnu packages autotools)
 (gnu packages guile)
 (gnu packages gtk)
 (gnu packages guile-xyz)
 (gnu packages ibus)
 (gnu packages pkg-config)
 (gnu packages texinfo)
 (gnu packages wm)
 (gnu packages freedesktop))

(define %srcdir
  (dirname (current-filename)))

(define libdrm-next
  (package
    (inherit libdrm)
    (name "libdrm")
    (version "2.4.110")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://dri.freedesktop.org/libdrm/libdrm-"
                    version ".tar.xz"))
              (sha256
               (base32
                "0dwpry9m5l27dlhq48j4bsiqwm0247cxdqwv3b7ddmkynk2f9kpf"))))))
(define wayland-next
  (package
    (inherit wayland)
    (name "wayland")
    (version "1.20.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://wayland.freedesktop.org/releases/"
                                  name "-" version ".tar.xz"))
              (sha256
               (base32
                "09c7rpbwavjg4y16mrfa57gk5ix6rnzpvlnv1wp7fnbh9hak985q"))))))
(define wayland-protocols-next
  (package
    (inherit wayland-protocols)
    (name "wayland-protocols")
    (version "1.25")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://wayland.freedesktop.org/releases/"
                    "wayland-protocols-" version ".tar.xz"))
              (sha256
               (base32
                "0q0laxdvf8p8b7ks2cbpqf6q0rwrjycqrp8pf8rxm86hk5qhzzzi"))))
    (inputs
     (modify-inputs (package-inputs wayland-protocols)
                    (replace "wayland" wayland-next)))))
(define libinput-next
  (package
    (inherit libinput)
    (version "1.19.4")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://freedesktop.org/software/libinput/"
                                  "libinput-" version ".tar.xz"))
              (sha256
               (base32
                "0h5lz54rrl48bhi3vki6s08m6rn2h62rlf08dhgchdm9nmqaaczz"))))))
(define wlroots-next
  (package
    (inherit wlroots)
    (name "wlroots")
    (version "0.15.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://gitlab.freedesktop.org/wlroots/wlroots")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "00s73nhi3sc48l426jdlqwpclg41kx1hv0yk4yxhbzw19gqpfm1h"))))
    (arguments (substitute-keyword-arguments (package-arguments wlroots)
                 ((#:configure-flags flags ''())
                  `(cons "-Dbackends=['drm','libinput','x11']" ,flags))))

    (propagated-inputs
     (modify-inputs (package-propagated-inputs wlroots)
                    (prepend libdrm-next libglvnd xcb-util-renderutil)
                    (replace "wayland" wayland-next)
                    (replace "libinput-minimal" libinput-next)
                    (replace "wayland-protocols" wayland-protocols-next)))))

;; public package, used for 'guix system vm' test
(define-public gwwm
  (package
    (name "gwwm")
    (version "0.1")
    (source (local-file "." "gwwm-checkout"
                        #:recursive? #t
                        #:select? (git-predicate %srcdir)))
    (build-system gnu-build-system)
    (arguments
     (list #:make-flags
           #~(list "GUILE_AUTO_COMPILE=0")
                     ;;; XXX: is a bug? why can't use gexp for #:modules
           #:modules `(((guix build guile-build-system)
                        #:select (target-guile-effective-version))
                       ,@%gnu-build-system-modules)
           #:imported-modules `((guix build guile-build-system)
                                ,@%gnu-build-system-modules)
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'build 'load-extension
                 (lambda* (#:key outputs #:allow-other-keys)
                   (substitute*
                       (find-files "." ".*\\.scm")
                     (("\\(load-extension \"libgwwm\" *\"(.*)\"\\)" _ o)
                      (string-append
                       (object->string
                        `(or (false-if-exception (load-extension "libgwwm" ,o))
                             (load-extension
                              ,(string-append
                                (assoc-ref outputs "out")
                                "/lib/libgwwm.so")
                              ,o))))))))
               (add-after 'install 'wrap-executable
                 (lambda* (#:key inputs outputs #:allow-other-keys)
                   (let* ((out (assoc-ref outputs "out"))
                          (deps (map (lambda (a)
                                       (assoc-ref inputs a ))
                                     '("guile-wayland"
                                       "guile-wlroots"
                                       "guile-bytestructures"
                                       "util572")))
                          (effective (target-guile-effective-version))
                          (mods (map (lambda (o)
                                       (string-append
                                        o "/share/guile/site/" effective))
                                     (cons out deps)))
                          (gos
                           (map (lambda (o)
                                  (string-append
                                   o "/lib/guile/" effective "/site-ccache"))
                                (cons out deps))))
                     (wrap-program (search-input-file outputs "bin/gwwm")
                       #:sh (search-input-file inputs "bin/bash")
                       `("GUILE_AUTO_COMPILE" ":" = ("0"))
                       `("GUILE_LOAD_PATH" ":" prefix ,mods)
                       `("GUILE_LOAD_COMPILED_PATH" ":" prefix ,gos))))))))
    (native-inputs
     (list autoconf automake
           pkg-config
           libtool
           gettext-minimal
           guile-3.0-latest
           bash-minimal
           texinfo))
    (inputs (list guile-3.0-latest wlroots-next xorg-server-xwayland
                  guile-cairo
                  guile-bytestructures
                  (primitive-load
                   (string-append (dirname (dirname (current-filename)))
                                  "/guile-wayland/guix.scm"))
                  (primitive-load
                   (string-append (dirname (dirname (current-filename)))
                                  "/util572/guix.scm"))
                  (primitive-load
                   (string-append (dirname (dirname (current-filename)))
                                  "/guile-wlroots/guix.scm"))))
    (synopsis "")
    (description "")
    (home-page "")
    (license license:gpl3+)))

gwwm
