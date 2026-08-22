;;; ============================================================================
;;; PDF-PEN-SORT.LSP
;;; Pen-based audit and layer sorting for PDFIMPORT geometry
;;; Target: Autodesk Civil 3D / AutoCAD 2027 (Windows)
;;; Pure AutoLISP / Visual LISP. No .NET, no ObjectARX, no external files.
;;;
;;; Commands:
;;;   PDFAUDIT - read-only scan of model space; prints a summary table of
;;;              distinct (color, lineweight, linetype, entity-type) combos
;;;              and writes <dwgname>_pdfaudit.csv next to the DWG.
;;;   PDFSORT  - same scan, then creates one layer per distinct COLOR named
;;;              Z-PDF-ACI-<n> or Z-PDF-RGB-<r>-<g>-<b>, colors the layer to
;;;              match, and moves each eligible object onto its color's layer.
;;;              All changes are inside one undo group.
;;;
;;; Eligibility (both commands): only entities on layer "0" or on layers whose
;;; names begin with "PDF_" are processed. Layers already named Z-PDF-* and
;;; all other layers are skipped and reported, so re-running is safe and user
;;; layers are never touched.
;;;
;;; Color resolution (per entity):
;;;   1. DXF 420 present            -> true color (24-bit packed RGB)
;;;   2. else DXF 62 = 0            -> ByBlock: resolved to ACI 7, tagged
;;;   3. else DXF 62 = 256 / absent -> ByLayer: resolved to the layer's own
;;;                                    color (its 420 first, else its 62), tagged
;;;   4. else DXF 62 = 1..255       -> explicit ACI
;;; The audit reports how many entities fell into each of the four cases.
;;; ============================================================================

(vl-load-com)

;;; ---------------------------------------------------------------- utilities

(defun pps:acdoc ()
  (vla-get-ActiveDocument (vlax-get-acad-object)))

;; Decompose packed 24-bit RGB integer -> (r g b)
(defun pps:rgb-split (n)
  (list (lsh n -16) (logand (lsh n -8) 255) (logand n 255)))

;; Human/CSV-safe color spec string. clr = (tag . value) where tag is one of
;; "TRUE" "ACI" "BYLAYER-TRUE" "BYLAYER-ACI" "BYBLOCK", value is packed rgb
;; or aci depending on tag.
(defun pps:colorspec (clr / tag val rgb)
  (setq tag (car clr)
        val (cdr clr))
  (if (wcmatch tag "*TRUE*")
    (progn (setq rgb (pps:rgb-split val))
           (strcat "RGB-" (itoa (car rgb)) "-" (itoa (cadr rgb)) "-" (itoa (caddr rgb))))
    (strcat "ACI-" (itoa val))))

;; Lineweight (DXF 370) -> display string. Absent/-1 ByLayer, -2 ByBlock,
;; -3 Default; otherwise value is 1/100 mm.
(defun pps:lw-str (lw)
  (cond ((or (null lw) (= lw -1)) "ByLayer")
        ((= lw -2) "ByBlock")
        ((= lw -3) "Default")
        (t (rtos (/ lw 100.0) 2 2))))

;; Layer color cache: name -> (tag . value). Layer 62 may be negative (layer
;; off); use abs. Layer may itself carry a 420 true color.
(setq *pps:laycolors* nil)
(defun pps:layer-color (lname / ed c420 c62)
  (cond
    ((cdr (assoc (strcase lname) *pps:laycolors*)))
    (t
     (setq ed (entget (tblobjname "LAYER" lname))
           c420 (cdr (assoc 420 ed))
           c62  (cdr (assoc 62 ed)))
     (setq c (if c420 (cons "BYLAYER-TRUE" c420)
                      (cons "BYLAYER-ACI" (abs (if c62 c62 7)))))
     (setq *pps:laycolors* (cons (cons (strcase lname) c) *pps:laycolors*))
     c)))

;; Resolve one entity's color. Returns (tag . value); tag in
;; TRUE / ACI / BYLAYER-TRUE / BYLAYER-ACI / BYBLOCK
(defun pps:ent-color (ed / c420 c62 lay lc)
  (setq c420 (cdr (assoc 420 ed))
        c62  (cdr (assoc 62 ed))
        lay  (cdr (assoc 8 ed)))
  (cond
    (c420 (cons "TRUE" c420))
    ((and c62 (= c62 0)) (cons "BYBLOCK" 7))       ; top-level ByBlock plots as 7
    ((or (null c62) (= c62 256))                    ; ByLayer -> layer's color
     (setq lc (pps:layer-color lay))
     (cons (car lc) (cdr lc)))
    (t (cons "ACI" c62))))

;; Is this layer eligible for processing?
(defun pps:eligible-layer-p (lname / u)
  (setq u (strcase lname))
  (and (not (wcmatch u "Z-PDF-*"))
       (or (= u "0") (wcmatch u "PDF_*"))))

;;; ------------------------------------------------------------------- scan
;;; Walk every entity in model space once. Returns a list:
;;;   (table  src-counts  skipped)
;;;   table:      ((key colorspec cs-tag lw-str lt etype count) ...)
;;;   src-counts: (ntrue naci nbylayer nbyblock)
;;;   skipped:    ((layername . count) ...) entities on ineligible layers

(defun pps:scan (/ ss i n ed lay lt lw et clr cs key row table
                   ntrue naci nbyl nbyb skipped sk ename)
  (setq table nil skipped nil
        ntrue 0 naci 0 nbyl 0 nbyb 0)
  (setq ss (ssget "_X" '((67 . 0))))               ; all of model space
  (if ss
    (progn
      (setq n (sslength ss) i 0)
      (while (< i n)
        (setq ename (ssname ss i)
              ed    (entget ename)
              lay   (cdr (assoc 8 ed)))
        (if (pps:eligible-layer-p lay)
          (progn
            (setq clr (pps:ent-color ed)
                  cs  (pps:colorspec clr)
                  lt  (cond ((cdr (assoc 6 ed))) ("ByLayer"))
                  lw  (pps:lw-str (cdr (assoc 370 ed)))
                  et  (cdr (assoc 0 ed)))
            (cond ((= (car clr) "TRUE")    (setq ntrue (1+ ntrue)))
                  ((= (car clr) "ACI")     (setq naci  (1+ naci)))
                  ((= (car clr) "BYBLOCK") (setq nbyb  (1+ nbyb)))
                  (t                       (setq nbyl  (1+ nbyl))))
            (setq key (strcat cs "|" (car clr) "|" lw "|" lt "|" et))
            (if (setq row (assoc key table))
              (setq table (subst (list key cs (car clr) lw lt et (1+ (nth 6 row)))
                                 row table))
              (setq table (cons (list key cs (car clr) lw lt et 1) table))))
          ;; ineligible layer -> count as skipped
          (if (setq sk (assoc lay skipped))
            (setq skipped (subst (cons lay (1+ (cdr sk))) sk skipped))
            (setq skipped (cons (cons lay 1) skipped))))
        (setq i (1+ i)))))
  (list (vl-sort table '(lambda (a b) (> (nth 6 a) (nth 6 b))))
        (list ntrue naci nbyl nbyb)
        skipped))

;;; ---------------------------------------------------------------- printing

(defun pps:pad (s w / )
  (while (< (strlen s) w) (setq s (strcat s " ")))
  s)

(defun pps:print-table (scan / table srcs skipped row)
  (setq table   (car scan)
        srcs    (cadr scan)
        skipped (caddr scan))
  (princ "\n")
  (princ (strcat (pps:pad "COUNT" 8) (pps:pad "COLOR" 18)
                 (pps:pad "SOURCE" 14) (pps:pad "LWT" 10)
                 (pps:pad "LINETYPE" 14) "TYPE\n"))
  (princ (strcat (pps:pad "-----" 8) (pps:pad "-----" 18)
                 (pps:pad "------" 14) (pps:pad "---" 10)
                 (pps:pad "--------" 14) "----\n"))
  (foreach row table
    (princ (strcat (pps:pad (itoa (nth 6 row)) 8)
                   (pps:pad (nth 1 row) 18)
                   (pps:pad (nth 2 row) 14)
                   (pps:pad (nth 3 row) 10)
                   (pps:pad (nth 4 row) 14)
                   (nth 5 row) "\n")))
  (princ (strcat "\nColor source breakdown: "
                 (itoa (nth 0 srcs)) " true-color (420), "
                 (itoa (nth 1 srcs)) " explicit ACI (62), "
                 (itoa (nth 2 srcs)) " ByLayer (resolved to layer color), "
                 (itoa (nth 3 srcs)) " ByBlock (resolved to ACI 7).\n"))
  (if skipped
    (progn
      (princ "Skipped (ineligible layers, not touched):\n")
      (foreach row skipped
        (princ (strcat "  " (pps:pad (car row) 30) (itoa (cdr row)) " objects\n"))))
    (princ "Skipped: none.\n"))
  (princ))

;;; --------------------------------------------------------------------- CSV

(defun pps:csv-path ()
  (strcat (getvar "DWGPREFIX")
          (vl-filename-base (getvar "DWGNAME"))
          "_pdfaudit.csv"))

(defun pps:write-csv (scan / f path row srcs skipped)
  (setq path (pps:csv-path)
        f (open path "w"))
  (if f
    (progn
      (write-line "count,color,source,lineweight,linetype,type" f)
      (foreach row (car scan)
        (write-line (strcat (itoa (nth 6 row)) "," (nth 1 row) ","
                            (nth 2 row) "," (nth 3 row) ","
                            (nth 4 row) "," (nth 5 row)) f))
      (setq srcs (cadr scan))
      (write-line "" f)
      (write-line (strcat "true-color-objects," (itoa (nth 0 srcs))) f)
      (write-line (strcat "explicit-aci-objects," (itoa (nth 1 srcs))) f)
      (write-line (strcat "bylayer-resolved-objects," (itoa (nth 2 srcs))) f)
      (write-line (strcat "byblock-resolved-objects," (itoa (nth 3 srcs))) f)
      (foreach row (caddr scan)
        (write-line (strcat "skipped-layer," (car row) "," (itoa (cdr row))) f))
      (close f)
      (princ (strcat "\nCSV written: " path "\n")))
    (princ (strcat "\nWARNING: could not open " path " for writing (drawing "
                   "never saved, or folder read-only). CSV skipped.\n")))
  (princ))

;;; --------------------------------------------------------------- error trap

(defun pps:begin (/)
  (setq *pps:oldecho* (getvar "CMDECHO")
        *pps:olderr*  *error*
        *error* (lambda (msg)
                  (if (/= (getvar "CMDECHO") *pps:oldecho*)
                    (setvar "CMDECHO" *pps:oldecho*))
                  (vl-catch-all-apply 'vla-EndUndoMark (list (pps:acdoc)))
                  (setq *error* *pps:olderr*)
                  (if (and msg (/= msg "Function cancelled")
                               (/= msg "quit / exit abort"))
                    (princ (strcat "\nError: " msg)))
                  (princ)))
  (setvar "CMDECHO" 0)
  (setq *pps:laycolors* nil))     ; fresh layer-color cache each run

(defun pps:end ()
  (setvar "CMDECHO" *pps:oldecho*)
  (setq *error* *pps:olderr*)
  (princ))

;;; ---------------------------------------------------------------- PDFAUDIT

(defun c:PDFAUDIT (/ scan)
  (pps:begin)
  (princ "\nScanning model space...")
  (setq scan (pps:scan))
  (if (car scan)
    (progn (pps:print-table scan)
           (pps:write-csv scan))
    (princ "\nNo eligible objects found (layers 0 / PDF_*)."))
  (pps:end))

;;; ----------------------------------------------------------------- PDFSORT
;;; Layer creation: entmake a LAYER record carrying both 62 (nearest use:
;;; for true colors we still must supply a valid 62; AutoCAD keeps 420 as the
;;; display color) and 420 when the pen is a true color.

(defun pps:make-layer (lname clr / rec rgb)
  (if (not (tblsearch "LAYER" lname))
    (progn
      (setq rec (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord")
                      '(100 . "AcDbLayerTableRecord")
                      (cons 2 lname) '(70 . 0) '(6 . "Continuous")))
      (if (wcmatch (car clr) "*TRUE*")
        (setq rec (append rec (list '(62 . 7) (cons 420 (cdr clr)))))
        (setq rec (append rec (list (cons 62 (cdr clr))))))
      (entmake rec))))

(defun c:PDFSORT (/ doc ss i n ename ed lay clr lname moved mv counts row
                    scan)
  (pps:begin)
  (setq doc (pps:acdoc))
  (princ "\nScanning model space...")
  (setq scan (pps:scan))
  (if (null (car scan))
    (progn (princ "\nNo eligible objects found (layers 0 / PDF_*). Nothing done.")
           (pps:end))
    (progn
      (pps:print-table scan)
      (vla-StartUndoMark doc)
      (setq counts nil)
      (setq ss (ssget "_X" '((67 . 0))) n (sslength ss) i 0)
      (while (< i n)
        (setq ename (ssname ss i)
              ed    (entget ename)
              lay   (cdr (assoc 8 ed)))
        (if (pps:eligible-layer-p lay)
          (progn
            (setq clr   (pps:ent-color ed)
                  lname (strcat "Z-PDF-" (pps:colorspec clr)))
            (pps:make-layer lname clr)
            (if (/= (strcase lay) (strcase lname))
              (progn
                (entmod (subst (cons 8 lname) (assoc 8 ed) ed))
                (if (setq row (assoc lname counts))
                  (setq counts (subst (cons lname (1+ (cdr row))) row counts))
                  (setq counts (cons (cons lname 1) counts)))))))
        (setq i (1+ i)))
      (vla-EndUndoMark doc)
      (setq moved 0)
      (princ "\nLayers created / populated:\n")
      (foreach row (vl-sort counts '(lambda (a b) (> (cdr a) (cdr b))))
        (setq moved (+ moved (cdr row)))
        (princ (strcat "  " (pps:pad (car row) 26) (itoa (cdr row)) " objects\n")))
      (princ (strcat "Total objects moved: " (itoa moved)
                     ".  One U command reverses everything.\n"))
      (pps:end))))

(princ "\nPDF-PEN-SORT loaded.  Commands: PDFAUDIT (read-only report + CSV), PDFSORT (sort by pen color onto Z-PDF-* layers).")
(princ)
