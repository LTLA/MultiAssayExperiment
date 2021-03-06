## Ensure ExperimentList elements are appropriate for the API and rownames
## are present
.checkGRL <- function(object) {
    ## use is() to exclude RangedRaggedAssay
    if (is(object, "GRangesList") && !is(object, "RangedRaggedAssay")) {
        stop(sQuote("GRangesList"), " class is not supported, use ",
             sQuote("RaggedExperiment"), " instead")
    }
    object
}

.hasDataFrames <- function(object) {
    hasdf <- vapply(object, is.data.frame, logical(1L))
    hasDF <- vapply(object, is, logical(1L), "DataFrame")
    any(hasdf, hasDF)
}

### ==============================================
### ExperimentList class
### ----------------------------------------------

#' A container for multi-experiment data
#'
#' The \code{ExperimentList} class is a container that builds on
#' the \code{SimpleList} with additional
#' checks for consistency in experiment names and length.
#' It contains a \code{SimpleList} of experiments with sample identifiers.
#' One element present per experiment performed.
#'
#' Convert from \code{SimpleList} or \code{list}
#' to the multi-experiment data container. When using the
#' \strong{mergeReplicates} method, additional arguments are passed to the
#' given \code{simplify} function argument (e.g., na.rm = TRUE)
#'
#' @examples
#' ExperimentList()
#'
#' @exportClass ExperimentList
#' @name ExperimentList-class
#' @docType class
setClass("ExperimentList", contains = "SimpleList")

### - - - - - - - - - - - - - - - - - - - - - - - -
### Constructor
###

#' Construct an \code{ExperimentList} object for the \code{MultiAssayExperiment}
#' object slot.
#'
#' The \code{ExperimentList} class can contain several different types of data.
#' The only requirements for an \code{ExperimentList} class are that the
#' objects contained have the following set of methods: \code{dim}, \code{[},
#' \code{dimnames}
#'
#' @param ... A named \code{list} class object
#' @return A \code{ExperimentList} class object of experiment data
#'
#' @example inst/scripts/ExperimentList-Ex.R
#' @export
ExperimentList <- function(...) {
    listData <- list(...)
    if (length(listData) == 1L) {
        if (is(listData[[1L]], "MultiAssayExperiment"))
            stop("MultiAssayExperiment input detected. ",
                "Did you mean 'experiments()'?")
        if (is(listData[[1L]], "ExperimentList"))
            return(listData[[1L]])
        if (is.list(listData[[1L]]) || (is(listData[[1L]], "List") &&
            !is(listData[[1L]], "DataFrame"))) {
            listData <- listData[[1L]]
            listData <- lapply(listData, .checkGRL)
                if (.hasDataFrames(listData))
                    message(
                        "ExperimentList contains data.frame or DataFrame,\n",
                        "  potential for errors with mixed data types")
        }
    } else if (!length(listData)) {
        return(new("ExperimentList",
            S4Vectors::SimpleList(structure(list(), .Names = character())))
        )
    }
    new("ExperimentList", S4Vectors::SimpleList(listData))
}

### - - - - - - - - - - - - - - - - - - - - - - - -
### Validity
###

## Helper function for .testMethodsTable
.getMethErr <- function(object) {
    supportedMethodFUN <- list(dimnames = dimnames, `[` =
        function(x) {x[integer(0L), ]}, dim = dim)
    methErr <- vapply(supportedMethodFUN, function(f) {
        "try-error" %in% class(try(f(object), silent = TRUE))
    }, logical(1L))
    if (any(methErr)) {
        unsupported <- names(which(methErr))
        msg <- paste0("class '", class(object),
            "' does not have compatible method(s): ",
            paste(unsupported, collapse = ", "))
        return(msg)
    }
    NULL
}

## 1.i. Check that [, colnames, rownames and dim methods are possible
.testMethodsTable <- function(object) {
    errors <- character(0L)
    for (i in seq_along(object)) {
        coll_err <- .getMethErr(object[[i]])
        if (!is.null(coll_err)) {
            errors <- c(errors, paste0("Element [", i, "] of ", coll_err))
        }
    }
    if (length(errors) == 0L) {
        NULL
    } else {
        errors
    }
}

## 1.ii. Check for null rownames and colnames for each element in the
## ExperimentList and duplicated element names
.checkExperimentListNames <- function(object) {
    errors <- character(0L)
    if (is.null(names(object))) {
        msg <- "ExperimentList elements must be named"
        errors <- c(errors, msg)
    }
    if (anyDuplicated(names(object))) {
        msg <- "Non-unique names provided"
        errors <- c(errors, msg)
    }
    if (length(errors) == 0L) {
        NULL
    } else {
        errors
    }
}

.validExperimentList <- function(object) {
    if (length(object) != 0L) {
        c(.testMethodsTable(object),
          .checkExperimentListNames(object))
    }
}

S4Vectors::setValidity2("ExperimentList", .validExperimentList)

#' @describeIn ExperimentList Show method for
#' \code{\linkS4class{ExperimentList}} class
#'
#' @param object,x An \code{\linkS4class{ExperimentList}} object
setMethod("show", "ExperimentList", function(object) {
    o_class <- class(object)
    elem_cl <- vapply(object, function(o) { class(o)[[1L]] }, character(1L))
    o_len <- length(object)
    o_names <- names(object)
    ldims <- vapply(object, dim, integer(2L))
    featdim <- ldims[1L, ]
    sampdim <- ldims[2L, ]
    cat(sprintf("%s", o_class),
        "class object of length",
        paste0(o_len, ":\n"),
        sprintf("[%i] %s: %s with %s rows and %s columns\n",
                seq(o_len), o_names, elem_cl, featdim, sampdim))
})


coerceToExperimentList <- function(from) {
    from <- as(from, "SimpleList")
    new("ExperimentList", from)
}

#' @rdname ExperimentList-class
#' @name coerce
#'
#' @aliases coerce,list,ExperimentList-method coerce,List,ExperimentList-method
#'
#' @section
#' coercion:
#'  Convert a \code{list} or S4 \code{List} to an ExperimentList using the
#'  `as()` function.
#'
#'  In the following example, \code{x} is either a \code{list} or
#'  \linkS4class{List}:
#'
#'  \preformatted{    \code{as(x, "ExperimentList")}}
#'
#' @md
#'
#' @exportMethod coerce

setAs("list", "ExperimentList", function(from) {
    coerceToExperimentList(from)
})

setAs("List", "ExperimentList", function(from) {
    coerceToExperimentList(from)
})

#' @describeIn ExperimentList check for zero length across all
#' experiments
setMethod("isEmpty", "ExperimentList", function(x) {
    x <- Filter(function(y) {
        !(is.matrix(y) && identical(dim(y), c(1L, 1L)) && isTRUE(is.na(y)))
    }, x)
    callNextMethod()
})
