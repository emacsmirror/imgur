;;; imgur.el --- Imgur client -*- lexical-binding: t; -*-

;; Copyright (C) 2024 Peter Badida

;; Author: Peter Badida <keyweeusr@gmail.com>
;; Keywords: convenience, imgur, client
;; Version: 1.0.0
;; Package-Requires: ((emacs "25.1"))
;; Homepage: https://github.com/KeyWeeUsr/imgur

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; TBD

;;; Code:

(defgroup imgur nil
  "Imgur client configuration."
  :group 'external
  :group 'communication)

(defcustom imgur-default-session-name
  "default"
  "Name used as an alist key for `imgur-creds'."
  :group 'imgur
  :type 'string)

(defcustom imgur-log-prefix
  "imgur"
  "Log message prefix."
  :group 'imgur
  :type 'string)

(defvar imgur-creds nil
  "Credentials for all sessions in nested alists.")

(defvar imgur-procs nil
  "Process references for all sessions in alists.")

;; private/helper funcs
(defun imgur--server-create-sentinel (session cb)
  "Sentinel for auth listener.
Argument SESSION Session to store creds into `imgur-creds'.
Argument CB Callback."
  `(lambda (proc state)
     (when (alist-get (intern ,session) imgur-creds)
       (message "%s: (%s) Credentials obtained, closing server"
                imgur-log-prefix ,session)
       (condition-case nil
           (delete-process proc)
         (error t))
       (condition-case nil
           (progn
             (delete-process (alist-get (intern ,session) imgur-procs))
             (setf (alist-get (intern ,session) imgur-procs) nil))
         (error t))
       (when ,cb
         (funcall ,cb)))))

;; public funcs
(defun imgur-authorize (base client-id client-secret &rest args)
  "Authorize the client against BASE for SESSION.
Argument CLIENT-ID Imgur application client ID.
Argument CLIENT-SECRET Imgur application client secret.

Optional argument ARGS allows specifying these keys:
* :success - (function/nil) called on successful run
* :fail - (function/nil) called on failed run
* :session - (string/`imgur-default-session-name') session name"
  (let ((success (plist-get args :success))
        (fail (plist-get args :fail))
        (session (or (plist-get args :session) imgur-default-session-name)))

    (unless (or (functionp success) (null success))
      (error "Optional :success must be a funcall-able"))
    (unless (or (functionp fail) (null fail))
      (error "Optional :fail must be a funcall-able"))

    (when (or (null base) (eq 0 (length base)))
      (let ((err (format "Bad base (%s)" base)))
        (when fail (funcall fail err))
        (user-error err)))

    (when (or (null client-id) (eq 0 (length client-id)))
      (let ((err (format "Bad client-id (%s)" client-id)))
        (when fail (funcall fail err))
        (user-error err)))

    (when (or (null client-secret) (eq 0 (length client-secret)))
      (let ((err (format "Bad client-secret (%s)" client-secret)))
        (when fail (funcall fail err))
        (user-error err)))

    (if (alist-get (intern session) imgur-creds)
        (when success (funcall success))

      (condition-case nil
          (delete-process (get-process (format "imgur-authorize-server")))
        (error nil))

      ;; TODO: allow multi-session
      ;; a) single port + route
      ;; b) multi-port + session-port/session-url pairing for redir URLs
      (setf (alist-get (intern session) imgur-procs)
            (make-network-process
             :name (format "imgur-authorize-server")
             :server t
             :host "127.0.0.1"
             :service 61626
             :family 'ipv4
             :sentinel (imgur--server-create-sentinel session success)
             :filter (lambda (&rest _))))

      (unless (alist-get (intern session) imgur-procs)
        (error "Failed creating server"))

      (browse-url
       (format "%s/oauth2/authorize?client_id=%s&response_type=%s"
               base (url-hexify-string client-id) "token")))))

(defun imgur-authorize-interactive-with-session
    (base client-id client-secret session)
  "Authorize the client against BASE for SESSION.
Argument CLIENT-ID Imgur application client ID.
Argument CLIENT-SECRET Imgur application client secret."
  (interactive  "sURL base: \nsClient ID: \nsClient secret: \nsSession: ")
  (imgur-authorize base client-id client-secret :session session))

(defun imgur-authorize-interactive (base client-id client-secret)
  "Authorize the client against BASE using `imgur-default-session-name'.
Argument CLIENT-ID Imgur application client ID.
Argument CLIENT-SECRET Imgur application client secret."
  (interactive  "sURL base: \nsClient ID: \nsClient secret: ")
  (apply #'imgur-authorize-interactive-with-session
         `(,base ,client-id ,client-secret ,imgur-default-session-name)))

(provide 'imgur)
;;; imgur.el ends here
