#' @title Analyses of simulation studies with multiple estimands at once, including Monte Carlo error
#' @description `multisimsum` is an extension of [simsum()] that can handle multiple estimated parameters at once.
#' `multisimsum` calls [simsum()] internally, each estimands at once.
#' There is only one new argument that must be set when calling `multisimsum`: `par`, a string representing the column of `data` that identifies the different estimands.
#' Additionally, with `multisimsum` the argument `true` can be a named vector, where names correspond to each estimand (see examples).
#' Otherwise, constant values (or values identified by a column in `data`) will be utilised.
#' See `vignette("E-custom-inputs", package = "rsimsum")` for more details.
#' @param par The name of the variable containing the methods to compare.
#' Can be `NULL`.
#' @inheritParams simsum
#' @return An object of class `multisimsum`.
#' @export
#' @details
#' The following names are not allowed for `estvarname`, `se`, `methodvar`, `by`, `par`: `stat`, `est`, `mcse`, `lower`, `upper`, `:methodvar`.
#' @examples
#' data("frailty", package = "rsimsum")
#' ms <- multisimsum(
#'   data = frailty,
#'   par = "par", true = c(trt = -0.50, fv = 0.75),
#'   estvarname = "b", se = "se", methodvar = "model",
#'   by = "fv_dist"
#' )
#' ms
multisimsum <- function(data,
                        par,
                        estvarname,
                        se = NULL,
                        true = NULL,
                        methodvar = NULL,
                        ref = NULL,
                        by = NULL,
                        ci.limits = NULL,
                        df = NULL,
                        dropbig = FALSE,
                        x = FALSE,
                        control = list()) {
  ### Check arguments
  arg_checks <- checkmate::makeAssertCollection()
  # 'methodvar', 'ref', 'par' must be a single string value
  checkmate::assert_string(x = par, add = arg_checks)
  # 'methodvar', 'par' must be in 'data'
  checkmate::assert_subset(x = methodvar, choices = names(data), add = arg_checks)
  checkmate::assert_subset(x = par, choices = names(data), add = arg_checks)
  # Report
  if (!arg_checks$isEmpty()) checkmate::reportAssertions(arg_checks)
  ### <- The above assumes that the other checks will be run by repeated calls to simsum() below

  ### Set control parameters
  control.default <- list(mcse = TRUE, level = 0.95, power_df = NULL, na.rm = TRUE, char.sep = "~", dropbig.max = 10, dropbig.semax = 100, dropbig.robust = TRUE)
  control.tmp <- unlist(list(
    control[names(control) %in% names(control.default)],
    control.default[!(names(control.default) %in% names(control))]
  ), recursive = FALSE)
  control <- control.tmp

  ### Factorise 'par', 'methodvar'
  data <- .factorise(data = data, cols = c(par, methodvar))

  ### Check that levels of factors are ok
  .validate_levels(data = data, cols = c(par, methodvar), char = ifelse(!is.null(control$char.sep), control$char.sep, "~"))

  ### Set reference method if 'ref' is not specified
  if (!is.null(methodvar)) {
    if (is.null(ref)) {
      if (length(methodvar) > 1) {
        ref <- .compact_method_columns(data = data, methodvar = methodvar)$reftable[[":methodvar"]][1]
      } else {
        ref <- levels(data[[methodvar]])[1]
        data[[methodvar]] <- relevel(data[[methodvar]], ref = ref)
      }
      message(paste("'ref' method was not specified,", ref, "set as the reference"))
    }
  }

  ### Throw a warning if `ref` is specified and `methodvar` is not
  if (is.null(methodvar) & !is.null(ref)) {
    warning("'ref' method is specified while 'methodvar' is not: 'ref' will be ignored")
    ref <- NULL
  }

  ### Split data by 'par'
  par_split <- .split_by(data = data, by = par)

  ### Call 'simsum' on each element of 'par_split'; save data if 'x = TRUE'
  par_simsum <- vector(mode = "list", length = length(par_split))
  if (x) par_data <- vector(mode = "list", length = length(par_split))
  for (i in seq_along(par_split)) {
    if (rlang::is_named(true) | is.null(true)) {
      run <- simsum(data = par_split[[i]], estvarname = estvarname, true = true[names(par_split)[i]], se = se, methodvar = methodvar, ref = ref, by = by, ci.limits = ci.limits, df = df, dropbig = dropbig, x = x, control = control)
    } else {
      run <- simsum(data = par_split[[i]], estvarname = estvarname, true = true, se = se, methodvar = methodvar, ref = ref, by = by, ci.limits = ci.limits, dropbig = dropbig, x = x, control = control)
    }
    par_simsum[[i]] <- run[["summ"]]
    if (x) par_data[[i]] <- run[["x"]]
  }
  names(par_simsum) <- names(par_split)

  ### Add a column with the parameter to each slot, and turn it into factor
  for (i in seq_along(par_simsum)) par_simsum[[i]][[par]] <- names(par_simsum)[i]

  ### Bind summ slots
  summ <- .br(x = par_simsum)
  summ <- .factorise(data = summ, cols = par)
  row.names(summ) <- NULL

  ### Include stuff into object to return
  obj <- list()
  obj$summ <- summ
  obj$par <- par
  obj$estvarname <- estvarname
  obj$true <- true
  obj$se <- se
  obj$methodvar <- methodvar
  obj$ref <- ref
  obj$dropbig <- dropbig
  obj$ci.limits <- ci.limits
  obj$df <- df
  obj$by <- by
  obj$control <- control
  if (x) {
    obj$x <- .br(par_data)
    rownames(obj$x) <- NULL
  }

  ### Return object of class simsum
  class(obj) <- c("multisimsum", "list")
  return(obj)
}
