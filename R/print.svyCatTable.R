##' Format and print \code{svyCatTable} class objects
##'
##' \code{print} method for the \code{svyCatTable} class objects created by \code{\link{svyCreateCatTable}} function.
##'
##' @param x The result of a call to the \code{\link{svyCreateCatTable}} function.
##' @param digits Number of digits to print in the table.
##' @param pDigits Number of digits to print for p-values (also used for standardized mean differences).
##' @param quote Whether to show everything in quotes. The default is FALSE. If TRUE, everything including the row and column names are quoted so that you can copy it to Excel easily.
##' @param missing Whether to show missing data information.
##' @param explain Whether to add explanation to the variable names, i.e., (\%) is added to the variable names when percentage is shown.
##' @param printToggle Whether to print the output. If FALSE, no output is created, and a matrix is invisibly returned.
##' @param noSpaces Whether to remove spaces added for alignment. Use this option if you prefer to align numbers yourself in other software.
##' @param format The default is "fp" frequency (percentage). You can also choose from "f" frequency only, "p" percentage only, and "pf" percentage (frequency).
##' @param showAllLevels Whether to show all levels. FALSE by default, i.e., for 2-level categorical variables, only the higher level is shown to avoid redundant information.
##' @param cramVars A character vector to specify the two-level categorical variables, for which both levels should be shown in one row.
##' @param dropEqual Whether to drop " = second level name" description indicating which level is shown for two-level categorical variables.
##' @param test Whether to show p-values. TRUE by default. If FALSE, only the numerical summaries are shown.
##' @param exact This option is not available for tables from weighted data.
##' @param smd Whether to show standardized mean differences. FALSE by default. If there are more than one contrasts, the average of all possible standardized mean differences is shown. For individual contrasts, use \code{summary}.
##' @param CrossTable Whether to show the cross table objects held internally using gmodels::CrossTable function. This will give an output similar to the PROC FREQ in SAS.
##' @param ... For compatibility with generic. Ignored.
##' @return A matrix object containing what you see is also invisibly returned. This can be assinged a name and exported via \code{write.csv}.
##' @author Kazuki Yoshida
##' @seealso
##' \code{\link{svyCreateTableOne}}, \code{\link{svyCreateCatTable}}, \code{\link{summary.svyCatTable}}
##' @examples
##'
##' ## See the examples for svyCreateTableOne()
##'
##' @export
print.svyCatTable <-
function(x,                        # CatTable object
         digits = 1, pDigits = 3,  # Number of digits to show
         quote         = FALSE,    # Whether to show quotes

         missing       = FALSE,    # Show missing values (not implemented yet)
         explain       = TRUE,     # Whether to show explanation in variable names
         printToggle   = TRUE,     # Whether to print the result visibly
         noSpaces      = FALSE,    # Whether to remove spaces for alignments

         format        = c("fp","f","p","pf")[1], # Format f_requency and/or p_ercent
         showAllLevels = FALSE,
         cramVars      = NULL,     # variables to be crammed into one row
         dropEqual     = FALSE,    # Do not show " = second level" for two-level variables

         test          = TRUE,     # Whether to add p-values
         exact         = NULL,     # Which variables should be tested with exact tests

         smd           = FALSE,    # Whether to add standardized mean differences

         CrossTable    = FALSE,    # Whether to show gmodels::CrossTable

         ...) {

    ## x and ... required to be consistent with generic print(x, ...)
    CatTable <- x

### Check the data structure first

    ## CatTable has a strata(list)-variable(list)-table(dataframe) structure
    ## Get the position of the non-null element
    logiNonNullElement <- !sapply(CatTable, is.null)
    ## Stop if all elements are null.
    if (sum(logiNonNullElement) == 0) {stop("All strata are null strata. Check data.")}
    ## Get the first non-null position
    posFirstNonNullElement <- which(logiNonNullElement)[1]
    ## Save variable names using the first non-null element
    varNames <- names(CatTable[[posFirstNonNullElement]])
    ## Check the number of variables (list length)
    nVars <- length(varNames)


    ## Returns a numeric vector: 1 for approx test variable; 2 for exact test variable
    exact <- ModuleHandleDefaultOrAlternative(switchVec       = exact,
                                              nameOfSwitchVec = "exact",
                                              varNames        = varNames)


    ## Check format argument. If it is broken, choose "fp" for frequency (percent)
    if (!length(format) == 1  | !format %in% c("fp","f","p","pf")) {
        warning("format only accepts one of fp, f, p, or pf. Choosing fp.")
        format <- "fp"
    }

    ## Obtain the strata sizes in a character vector. This has to be obtained from the original data
    ## Added as the top row later
    strataN <- sapply(CatTable,
                      FUN = function(stratum) { # loop over strata
                          ## each stratum is a list of one data frame for each variable
                          ## Obtain n from all variables and all levels (list of data frames)
                          n <- unlist(sapply(stratum, getElement, "n"))
                          ## Pick the first non-null element
                          n[!is.null(n)][1]
                          ## Convert NULL to 0
                          ifelse(is.null(n),
                                 "0",
                                 sprintf(fmt = paste0("%.", digits, "f"), n))
                      },
                      simplify = TRUE) # vector with as many elements as strata


### Formatting for printing

    ## Variables to format using digits option
    varsToFormat <- c("n","miss","p.miss","freq","percent","cum.percent")

    ## Obtain collpased result by looping over strata
    ## within each stratum, loop over variables
    CatTableCollapsed <-
    ModuleCatFormatStrata(CatTable      = CatTable,
                          digits        = digits,
                          varsToFormat  = varsToFormat,
                          cramVars      = cramVars,
                          dropEqual     = dropEqual,
                          showAllLevels = showAllLevels)


### Obtain the original column width in characters for alignment in print.TableOne
    ## Name of the column to keep
    widthCol <- c("nCharFreq","nCharFreq","nCharPercent","nCharPercent")[format == c("fp","f","p","pf")]
    vecColWidths <- sapply(CatTableCollapsed,
                            FUN = function(LIST) {

                                ## Get the width of the column (freq or percent, whichever comes left)
                                out <- attributes(LIST)[widthCol]
                                ## Return NA if null
                                if (is.null(out)) {
                                    return(NA)
                                } else {
                                    return(as.numeric(out))
                                }
                            },
                            simplify = TRUE)


    ## Fill the null element using the first non-null element's dimension (Make sure to erase data)
    CatTableCollapsed[!logiNonNullElement] <- CatTableCollapsed[posFirstNonNullElement]
    ## Access the filled-in data frames, and erase them with place holders.
    for (i in which(!logiNonNullElement)) {
        ## Replace all elements with a place holder variable by variable
        CatTableCollapsed[[i]][] <- lapply(CatTableCollapsed[[i]][],
                                           function(var) {

                                               var <- rep("-", length(var))
                                           })
    }

    ## Choose the column name for the right format
    nameResCol <- c("freqPer","freq","percent","perFreq")[format == c("fp","f","p","pf")]


    ## Create output matrix without variable names with the right format
    out <- do.call(cbind, lapply(CatTableCollapsed, getElement, nameResCol))
    out <- as.matrix(out)

    ## Add column names if multivariable stratification is used. (No column names added automatically)
    if (length(attr(CatTable, "dimnames")) > 1) {

        colnames(out) <- ModuleCreateStrataNames(CatTable)
    }


    ## Set the variables names
    rownames(out) <- CatTableCollapsed[[posFirstNonNullElement]][,"var"]
    ## Get positions of rows with variable names
    logiNonEmptyRowNames <- CatTableCollapsed[[posFirstNonNullElement]][, "firstRowInd"] != ""


    ## Add p-values when requested and available
    if (test == TRUE & !is.null(attr(CatTable, "pValues"))) {

        ## Pick test types used (used for annonation)
        testTypes <- c("","exact")[exact]

        ## Pick the p-values requested, and format like <0.001
        pVec <- ModulePickAndFormatPValues(TableObject = CatTable,
                                           switchVec   = exact,
                                           pDigits     = pDigits)

        ## Create an empty p-value column and test column
        out <- cbind(out,
                     p     = rep("", nrow(out))) # Column for p-values
        ## Put the values at the non-empty positions
        out[logiNonEmptyRowNames,"p"] <- pVec

        ## Create an empty test type column, and add test types
        out <- cbind(out,
                     test = rep("", nrow(out))) # Column for test types
        ## Put the test types  at the non-empty positions (all rows in continuous!)
        out[logiNonEmptyRowNames,"test"] <- testTypes

    }


    ## Add SMDs when requested and available
    if (smd & !is.null(attr(CatTable, "smd"))) {

        ## Create an empty column
        out <- cbind(out,
                     SMD = rep("", nrow(out))) # Column for p-values
        ## Put the values at the non-empty positions
        out[logiNonEmptyRowNames,"SMD"] <-
        ModuleFormatPValues(attr(CatTable, "smd")[,1], pDigits = pDigits)
    }


    ## Add percentMissing when requested and available
    if (missing & !is.null(attr(CatTable, "percentMissing"))) {

        ## Create an empty column
        out <- cbind(out,
                     Missing = rep("", nrow(out))) # Column for p-values
        ## Put the values at the non-empty positions
        out[logiNonEmptyRowNames,"Missing"] <- ModuleFormatPercents(attr(CatTable, "percentMissing"), 1)
    }


    ## Add freq () explanation if requested
    if (explain) {
        ## Choose the format of the explanation string
        explainString <- c(" (%)", "", " (%)", " % (freq)")[format == c("fp","f","p","pf")]
        ## Only for rows with row names
        rownames(out)[logiNonEmptyRowNames] <- paste0(rownames(out)[logiNonEmptyRowNames],
                                                      explainString)
    }

    ## Keep column names (strataN does not have correct names
    ## if stratification is by multiple variables)
    outColNames <- colnames(out)
    ## rbind sample size row, padding necessary "" for p value, etc
    nRow <- c(strataN, rep("", ncol(out) - length(strataN)))
    out <- rbind(n = nRow, out)
    ## Put back the column names (overkill for non-multivariable cases)
    colnames(out) <- outColNames

    ## Add level names if showAllLevels is TRUE.
    ## This adds the level column to the left, thus, after nRow addition.
    ## Need come after column naming.
    if (showAllLevels) {
        out <-
        cbind(level = c("", CatTableCollapsed[[posFirstNonNullElement]][,"level"]),
              out)
    }

    ## Add stratification information to the column header depending on the dimension
    names(dimnames(out)) <- c("", paste0("Stratified by ",
                                         attr(CatTable, "strataVarName")))

    ## Remove spaces if asked.
    out <- ModuleRemoveSpaces(mat = out, noSpaces = noSpaces)

    ## Modular version of quote/print toggle.
    out <- ModuleQuoteAndPrintMat(matObj = out,
                                  quote = quote, printToggle = printToggle)

    ## Print CrossTable() if requested
    if (CrossTable) {
        junk <- lapply(attributes(CatTable)$xtabs, gmodels::CrossTable)
    }

    ## Add attributes for column widths in characters
    attributes(out) <- c(attributes(out),
                         list(vecColWidths = vecColWidths,
                              ## Add one FALSE for sample size row
                              logiNameRows = c(FALSE, logiNonEmptyRowNames)))

    ## return a matrix invisibly
    return(invisible(out))
}
