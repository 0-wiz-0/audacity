;nyquist plug-in
;version 4
;type process
;preview linear
;name "Spectral edit parametric EQ..."
;action "Filtering..."
;author "Paul Licameli"
;copyright "Released under terms of the GNU General Public License version 2"


;; SpectralEditParametricEQ.ny by Paul Licameli, November 2014.
;; Updated to version 4 by Steve Daulton November 2014.
;; Released under terms of the GNU General Public License version 2:
;; http://www.gnu.org/licenses/old-licenses/gpl-2.0.html

;control control-gain "Gain (dB)" real "" 0 -24 24

(setf control-gain (min 24 (max -24 control-gain))) ; excessive settings may crash

(defmacro validate (hz)
"Ensure frequency is below Nyquist"
  `(setf ,hz (max 0 (min (/ *sound-srate* 2.0) ,hz))))

(defun wet (sig gain f0 f1)
  ;; (re)calculate bw and fc to ensure we do not exceed Nyquist frequency
  (validate f0)
  (validate f1)
  (let ((fc (sqrt (* f0 f1)))
	(bw (/ (log (/ f1 f0))
	       (log 2.0))))
    (when (= bw 0)
      (throw 'error-message (format nil "~aBandwidth is zero.~%Select a frequency range." p-err)))
    (eq-band sig fc gain (/ bw 2))))

(defun result (sig)
  (let*
      ((f0 (get '*selection* 'low-hz))
       (f1 (get '*selection* 'high-hz))
       (tn (truncate len))
       (rate (snd-srate sig))
       (transition (truncate (* 0.01 rate)))  ; 10 ms
       (t1 (min transition (/ tn 2)))         ; fade in length (samples)
       (t2 (max (- tn transition) (/ tn 2)))  ; length before fade out (samples)
       (breakpoints (list t1 1.0 t2 1.0 tn))
       (env (snd-pwl 0.0 rate breakpoints)))
    (cond
      ((not (or f0 f1))
        (throw 'error-message (format nil "~aPlease select frequencies." p-err)))
      ((or (not f0) (= f0 0))
         (throw 'error-message (format nil "~aLow frequency is undefined." p-err)))
      ((not f1)
         (throw 'error-message (format nil "~aHigh frequency is undefined." p-err)))
      ;; If seleted frequency band is above Nyquist, do nothing.
      ((< f0 (/ *sound-srate* 2.0))
          (sum (prod env (wet sig control-gain f0 f1)) (prod (diff 1.0 env) sig))))))

(catch 'error-message
  (setf p-err "")
  (if (= control-gain 0)		; Allow dry preview
      "Gain is zero. Nothing to do."
    (multichan-expand #'result *track*)))
