;; -*-scheme-*-

;; portfolio.scm
;; by Robert Merkel (rgmerk@mira.net)


(gnc:support "report/portfolio.scm")
(gnc:depend  "report-html.scm")

(let ()
  
  (define (options-generator)    
    (let* ((options (gnc:new-options)) 
           ;; This is just a helper function for making options.
           ;; See gnucash/src/scm/options.scm for details.
           (add-option 
            (lambda (new-option)
              (gnc:register-option options new-option))))

      (add-option
       (gnc:make-date-option
	(N_ "General") (N_ "Date")
	"a"
	(N_ "Date to report on")
	 (lambda () (cons 'absolute (cons (current-time) 0)))
        #f 'absolute #f ))

      (add-option
       (gnc:make-account-list-option
	(N_ "General") (N_ "Accounts")
	"b"
	(N_ "Stock Accounts to report on")
	(lambda () (filter gnc:account-is-stock?
                           (gnc:group-get-subaccounts
                            (gnc:get-current-group))))
	(lambda (accounts) (list  #t (filter gnc:account-is-stock? accounts)))
	#t))

      (gnc:options-add-currency! 
       options (N_ "General") (N_ "Report Currency") "c")

      (gnc:options-set-default-section options "General")      
      options))

  ;; This is the rendering function. It accepts a database of options
  ;; and generates an object of type <html-document>.  See the file
  ;; report-html.txt for documentation; the file report-html.scm
  ;; includes all the relevant Scheme code. The option database passed
  ;; to the function is one created by the options-generator function
  ;; defined above.
  (define (portfolio-renderer report-obj)
    
    ;; These are some helper functions for looking up option values.
    (define (get-op section name)
      (gnc:lookup-option (gnc:report-options report-obj) section name))
    
    (define (op-value section name)
      (gnc:option-value (get-op section name)))
    
    (define (table-add-stock-rows table accounts to-date
                                  currency pricedb collector)
      (if (null? accounts) collector
	  (let* ((current (car accounts))
		 (rest (cdr accounts))
		 (name (gnc:account-get-name current))
		(commodity (gnc:account-get-commodity current))
		(ticker-symbol (gnc:commodity-get-mnemonic commodity))
		(listing (gnc:commodity-get-namespace commodity))
		(unit-collector (gnc:account-get-comm-balance-at-date
                                 current to-date #f))
		(units (cadr (unit-collector 'getpair commodity #f)))

		(price (gnc:pricedb-lookup-nearest-in-time pricedb
                                                           commodity
                                                           currency
                                                           to-date))

                (price-value (if price
                                 (gnc:price-get-value price)
                                 (gnc:numeric-zero)))

		(value-num (gnc:numeric-mul
                            units 
                            price-value
                            (gnc:commodity-get-fraction currency)
                            GNC-RND-ROUND))

		(value (gnc:make-gnc-monetary currency value-num)))
	    (collector 'add currency value-num)
	    (gnc:html-table-append-row!
             table
             (list name
                   ticker-symbol
                   listing
                   (gnc:make-html-table-header-cell/markup
                    "number-cell" (gnc:numeric-to-double units))
                   (gnc:make-html-table-header-cell/markup
                    "number-cell" (gnc:make-gnc-monetary currency price-value))
                   (gnc:make-html-table-header-cell/markup
                    "number-cell" value)))
            (gnc:price-unref price)
	    (table-add-stock-rows
             table rest to-date currency pricedb collector))))

    ;; The first thing we do is make local variables for all the specific
    ;; options in the set of options given to the function. This set will
    ;; be generated by the options generator above.
    (let ((to-date     (vector-ref (op-value "General" "Date") 1))
          (accounts    (op-value "General" "Accounts"))
	  (currency    (op-value "General" "Report Currency"))
          (collector   (gnc:make-commodity-collector))
          ;; document will be the HTML document that we return.
	  (table (gnc:make-html-table))
          (document (gnc:make-html-document))
	  (pricedb (gnc:book-get-pricedb (gnc:get-current-book))))

        (gnc:html-document-set-title!
         document (sprintf #f
                           (_ "Investment Portfolio Report: %s")
                           (gnc:timepair-to-datestring to-date)))

	(gnc:html-table-set-col-headers!
	 table
	 (list (_ "Account")
               (_ "Symbol")
               (_ "Listing")
               (_ "Units")
               (_ "Price")
               (_ "Value")))

	(table-add-stock-rows
         table accounts to-date currency pricedb collector)

        (gnc:html-table-append-row!
         table
         (list
          (gnc:make-html-table-cell/size
           1 6 (gnc:make-html-text (gnc:html-markup-hr)))))

	(collector
         'format 
         (lambda (currency amount)
           (gnc:html-table-append-row! 
            table
            (list (gnc:make-html-table-cell/markup
                   "total-label-cell" (_ "Total"))
                  (gnc:make-html-table-cell/size/markup
                   1 5 "total-number-cell"
                   (gnc:make-gnc-monetary currency amount)))))
         #f)

	(gnc:html-document-add-object! document table)

	document))

  (gnc:define-report

   ;; The version of this report.
   'version 1

   ;; The name of this report. This will be used, among other things,
   ;; for making its menu item in the main menu. You need to use the
   ;; untranslated value here!
   'name (N_ "Investment Portfolio")

   ;; The options generator function defined above.
   'options-generator options-generator

   ;; The rendering function defined above.
   'renderer portfolio-renderer))
