#lang racket

(require json
         racket/file
         racket/list
         racket/path
         file/zip)

(define repo-root
  (simplify-path (build-path (find-system-path 'run-file) ".." "..")))

(define extension-root (build-path repo-root "editors" "vscode-s"))
(define package-path (build-path extension-root "package.json"))
(define dist-dir (build-path repo-root "dist"))
(define build-dir (build-path repo-root "build" "vscode-s-vsix"))
(define stage-dir (build-path build-dir "stage"))
(define extension-stage (build-path stage-dir "extension"))

(define package-json
  (call-with-input-file package-path read-json))

(define (json-ref key)
  (hash-ref package-json key))

(define name (json-ref 'name))
(define display-name (json-ref 'displayName))
(define version (json-ref 'version))
(define publisher (json-ref 'publisher))
(define description (json-ref 'description))
(define vscode-engine
  (hash-ref (json-ref 'engines) 'vscode))

(define output-path
  (build-path dist-dir (format "~a-~a.vsix" name version)))

(define (xml-escape value)
  (define text (format "~a" value))
  (regexp-replace*
   #rx"[&<>\"]"
   text
   (lambda (match)
     (case (string-ref match 0)
       [(#\&) "&amp;"]
       [(#\<) "&lt;"]
       [(#\>) "&gt;"]
       [(#\") "&quot;"]
       [else match]))))

(define (write-text path text)
  (make-parent-directory* path)
  (call-with-output-file path
    #:exists 'replace
    (lambda (out) (display text out))))

(define content-types
  #<<XML
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="json" ContentType="application/json"/>
  <Default Extension="md" ContentType="text/markdown"/>
  <Default Extension="svg" ContentType="image/svg+xml"/>
  <Default Extension="txt" ContentType="text/plain"/>
  <Override PartName="/extension.vsixmanifest" ContentType="text/xml"/>
</Types>
XML
  )

(define vsix-manifest
  (format
   #<<XML
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="~a" Version="~a" Publisher="~a"/>
    <DisplayName>~a</DisplayName>
    <Description xml:space="preserve">~a</Description>
    <Tags>s,language,syntax,highlighting</Tags>
    <Categories>Programming Languages</Categories>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code"/>
  </Installation>
  <Dependencies/>
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/>
  </Assets>
  <Prerequisites>
    <Prerequisite Id="Microsoft.VisualStudio.Code" Version="~a" DisplayName="Visual Studio Code"/>
  </Prerequisites>
</PackageManifest>
XML
   (xml-escape name)
   (xml-escape version)
   (xml-escape publisher)
   (xml-escape display-name)
   (xml-escape description)
   (xml-escape vscode-engine)))

(define (relative-file-list root)
  (for/list ([path (in-directory root)]
             #:when (file-exists? path))
    (find-relative-path root path)))

(define (main)
  (when (directory-exists? build-dir)
    (delete-directory/files build-dir))
  (make-directory* stage-dir)
  (make-directory* dist-dir)
  (copy-directory/files extension-root extension-stage)
  (write-text (build-path stage-dir "[Content_Types].xml") content-types)
  (write-text (build-path stage-dir "extension.vsixmanifest") vsix-manifest)
  (when (file-exists? output-path)
    (delete-file output-path))
  (define entries
    (append
     (list (string->path "[Content_Types].xml")
           (string->path "extension.vsixmanifest"))
     (map (lambda (path) (build-path "extension" path))
          (relative-file-list extension-stage))))
  (parameterize ([current-directory stage-dir])
    (apply zip output-path entries))
  (printf "~a\n" (find-relative-path repo-root output-path)))

(module+ main
  (main))
