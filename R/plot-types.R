### Forest plot
#' @keywords internal
.forest_plot <- function(data, methodvar, by, stats, ci, target, scales) {
  ### Build basic plot
  if (!is.null(methodvar)) {
    methodvar <- rlang::sym(methodvar)
    gg <- ggplot2::ggplot(data = data, ggplot2::aes(x = {{ methodvar }}, y = est))
  } else {
    gg <- ggplot2::ggplot(data = data, ggplot2::aes(x = "Single Method", y = est)) +
      ggplot2::labs(x = "")
  }
  gg <- gg +
    ggplot2::geom_hline(yintercept = target, linetype = "dotted") +
    ggplot2::geom_point() +
    ggplot2::labs(y = stats)

  ### Wrap by 'by' factors if defined
  if (!is.null(by)) {
    by <- rlang::syms(by)
    gg <- gg +
      ggplot2::facet_wrap(facets = ggplot2::vars(!!!{{ by }}), labeller = ggplot2::label_both, scales = scales)
  }

  ### Add confidence intervals if we are calling autoplot on a summary object
  if (ci) {
    gg <- gg +
      ggplot2::geom_errorbar(ggplot2::aes(ymin = lower, ymax = upper), width = 1 / 3)
  }

  ### Return plot
  return(gg)
}

### Lolly plot
#' @keywords internal
.lolly_plot <- function(data, methodvar, by, stats, ci, target, scales) {
  ### Build basic plot
  if (!is.null(methodvar)) {
    methodvar <- rlang::sym(methodvar)
    gg <- ggplot2::ggplot(data = data, ggplot2::aes(x = est, y = {{ methodvar }})) +
      ggplot2::geom_vline(xintercept = target, linetype = "dotted") +
      ggplot2::geom_segment(aes(xend = target, yend = {{ methodvar }}))
  } else {
    gg <- ggplot2::ggplot(data = data, ggplot2::aes(x = est, y = "Single Method")) +
      ggplot2::geom_vline(xintercept = target, linetype = "dotted") +
      ggplot2::geom_segment(aes(xend = target, yend = "Single Method")) +
      ggplot2::labs(y = "")
  }
  gg <- gg +
    ggplot2::geom_point() +
    ggplot2::labs(x = stats)

  ### Wrap by 'by' factors if defined
  if (!is.null(by)) {
    by <- rlang::syms(by)
    gg <- gg +
      ggplot2::facet_wrap(facets = ggplot2::vars(!!!{{ by }}), labeller = ggplot2::label_both, scales = scales)
  }

  ### Add confidence intervals if we are calling autoplot on a summary object
  if (ci) {
    if (!is.null(methodvar)) {
      gg <- gg +
        ggplot2::geom_point(ggplot2::aes(x = lower, y = {{ methodvar }}), shape = 40) +
        ggplot2::geom_point(ggplot2::aes(x = upper, y = {{ methodvar }}), shape = 41)
    } else {
      gg <- gg +
        ggplot2::geom_point(ggplot2::aes(x = lower, y = "Single Method"), shape = 40) +
        ggplot2::geom_point(ggplot2::aes(x = upper, y = "Single Method"), shape = 41)
    }
  }

  ### Return plot
  return(gg)
}

### Zip plot
#' @keywords internal
.zip_plot <- function(data, estvarname, se, true, methodvar, by, ci.limits, df, control, summ, zoom, zip_ci_colours) {
  ### Extract overall coverage
  summ <- summ[summ$stat == "cover", ]
  summ$cover <- summ$est
  if (all(c("lower", "upper") %in% names(summ))) {
    summ$cover_lower <- summ$lower
    summ$cover_upper <- summ$upper
    summ$lower <- NULL
    summ$upper <- NULL
  } else {
    summ$cover_lower <- summ$cover - stats::qnorm(1 - (1 - 0.95) / 2) * summ$mcse
    summ$cover_upper <- summ$cover + stats::qnorm(1 - (1 - 0.95) / 2) * summ$mcse
  }
  summ$est <- NULL
  summ$stat <- NULL
  summ$mcse <- NULL

  ### Define critical value utilised to compute coverage probabilities
  if (is.null(df)) {
    data[["crit"]] <- stats::qnorm(1 - (1 - control$level) / 2)
  } else {
    data[["crit"]] <- stats::qt(1 - (1 - control$level) / 2, df = data[[df]])
  }

  ### Compute coverage
  if (is.null(ci.limits)) {
    data[["lower"]] <- data[[estvarname]] - data[["crit"]] * data[[se]]
    data[["upper"]] <- data[[estvarname]] + data[["crit"]] * data[[se]]
  } else if (is.character(ci.limits)) {
    data[["lower"]] <- data[[ci.limits[1]]]
    data[["upper"]] <- data[[ci.limits[2]]]
  } else if (is.numeric(ci.limits)) {
    data[["lower"]] <- ci.limits[1]
    data[["upper"]] <- ci.limits[2]
  }
  data[["covering"]] <- (true >= data[["lower"]] & true <= data[["upper"]])
  data[["covering"]] <- factor(data[["covering"]], levels = c(FALSE, TRUE), labels = c("Non-coverers", "Coverers"))

  ### Compute z value
  data[["z"]] <- abs((data[[estvarname]] - true) / data[[se]])

  ### Split data by 'methodvar', 'by'
  data <- .split_by(data = data, by = by)
  data <- lapply(data, function(x) .split_by(data = x, by = methodvar))

  ### Compute ranking for each data split
  for (i in seq_along(data)) {
    for (j in seq_along(data[[i]])) {
      A <- rank(data[[i]][[j]][["z"]])
      B <- max(A)
      data[[i]][[j]][["rank"]] <- A / B
    }
    data[[i]] <- .br(data[[i]])
  }
  data <- .br(data)

  ### Merge back summary statistics
  data <- merge(x = data, y = summ)

  ### Label of the y-axis
  ylab <- ifelse(is.null(df), "Fractional centile of |z-score|", "Fractional centile of |t-score|")

  ### Define CI lines colors
  if (length(zip_ci_colours) == 2) {
    data$line_color_lower <- ifelse(data$cover_lower <= control$level & control$level <= data$cover_upper, zip_ci_colours[1], zip_ci_colours[2])
    data$line_color_upper <- ifelse(data$cover_lower <= control$level & control$level <= data$cover_upper, zip_ci_colours[1], zip_ci_colours[2])
  } else if (length(zip_ci_colours) == 3) {
    data$line_color_lower <- ifelse(data$cover_lower > control$level & data$cover_upper > control$level, zip_ci_colours[3],
      ifelse(data$cover_lower < control$level & data$cover_upper < control$level, zip_ci_colours[2],
        ifelse(data$cover_lower <= control$level & control$level <= data$cover_upper, zip_ci_colours[1], NA)
      )
    )

    data$line_color_upper <- ifelse(data$cover_lower > control$level & data$cover_upper > control$level, zip_ci_colours[3],
      ifelse(data$cover_lower < control$level & data$cover_upper < control$level, zip_ci_colours[2],
        ifelse(data$cover_lower <= control$level & control$level <= data$cover_upper, zip_ci_colours[1], NA)
      )
    )
  } else {
    data$line_color_lower <- zip_ci_colours
    data$line_color_upper <- zip_ci_colours
  }

  ### Build plot
  gg <- ggplot2::ggplot(data, ggplot2::aes(y = rank, x = lower, color = covering)) +
    ggplot2::geom_segment(ggplot2::aes(yend = rank, xend = upper)) +
    ggplot2::geom_vline(xintercept = true, color = "black", linetype = "dashed") +
    ggplot2::geom_hline(ggplot2::aes(yintercept = cover_lower), color = data$line_color_lower, linetype = "dashed", linewidth = 1) +
    ggplot2::geom_hline(ggplot2::aes(yintercept = 0.95), color = "black", linetype = "dashed") +
    ggplot2::geom_hline(ggplot2::aes(yintercept = cover_upper), color = data$line_color_upper, linetype = "dashed", linewidth = 1) +
    ggplot2::labs(y = ylab, x = paste0(100 * control$level, "% confidence intervals"), color = "") +
    theme(legend.position = "bottom")

  ### If 'by', use facet_grid; facet_wrap otherwise
  if (!is.null(by) & !is.null(methodvar)) {
    by <- rlang::syms(by)
    methodvar <- rlang::sym(methodvar)
    gg <- gg +
      ggplot2::facet_grid(cols = ggplot2::vars(!!!{{ by }}), rows = ggplot2::vars({{ methodvar }}), labeller = ggplot2::labeller(.rows = ggplot2::label_value, .cols = ggplot2::label_both))
  } else if (is.null(by) & !is.null(methodvar)) {
    methodvar <- rlang::sym(methodvar)
    gg <- gg +
      ggplot2::facet_wrap(facets = ggplot2::vars({{ methodvar }}))
  } else if (!is.null(by) & is.null(methodvar)) {
    by <- rlang::syms(by)
    gg <- gg +
      ggplot2::facet_wrap(facets = ggplot2::vars(!!!{{ by }}))
  }

  ### Zoom (or not)
  gg <- gg +
    ggplot2::coord_cartesian(ylim = c(1 - zoom, 1))

  ### Return plot
  return(gg)
}

### Method vs method; supports Bland-Altman type plots
#' @keywords internal
.vs_plot <- function(data, b, methodvar, by, fitted, scales, ba) {
  ### Compute internal df
  internal_df <- .make_internal_df(data = data, b = b, methodvar = methodvar, by = by)

  ### if Bland-Altman type plot, replace X and Y for mean and diff
  if (ba) {
    internal_df[["mean"]] <- (internal_df[["X"]] + internal_df[["Y"]]) / 2
    internal_df[["diff"]] <- internal_df[["X"]] - internal_df[["Y"]]
    internal_df[["X"]] <- internal_df[["mean"]]
    internal_df[["Y"]] <- internal_df[["diff"]]
    internal_df[["mean"]] <- NULL
    internal_df[["diff"]] <- NULL
  }

  ### Build plot
  caption <- paste0("Comparison of variable '", b, "'")
  if (ba) caption <- paste0(caption, "; Bland-Altman type plot")
  gg <- ggplot2::ggplot(data = internal_df, ggplot2::aes(x = X, y = Y)) +
    ggplot2::geom_point() +
    ggplot2::labs(caption = caption)

  ### Add reference line, depending on the type of plot
  if (ba) {
    gg <- gg +
      ggplot2::geom_hline(yintercept = 0, linetype = "dashed")
  } else {
    gg <- gg +
      ggplot2::geom_abline(slope = 1, intercept = 0, linetype = "dashed")
  }

  ### if Bland-Altman type plot, fix labels
  if (ba) {
    gg <- gg +
      ggplot2::labs(x = "Mean", y = "Difference")
  }

  ### If 'by', use facet_grid; facet_wrap otherwise
  if (!is.null(by)) {
    by <- rlang::syms(by)
    gg <- gg +
      ggplot2::facet_grid(cols = ggplot2::vars(!!!{{ by }}), rows = ggplot2::vars(contrast), scales = scales, labeller = ggplot2::labeller(.rows = ggplot2::label_value, .cols = ggplot2::label_both))
  } else {
    gg <- gg +
      ggplot2::facet_wrap(~contrast, scales = scales)
  }

  ### If 'fitted' add regression line
  if (fitted) {
    gg <- gg +
      ggplot2::geom_smooth(method = "lm")
  }

  ### Return plot
  return(gg)
}

### Ridgeline plot
#' @keywords internal
.ridge_plot <- function(data, b, methodvar, by) {
  ### Create a .dgm column
  if (!is.null(by)) {
    tmp <- lapply(by, function(x) data[[x]])
    data[[".dgm"]] <- do.call(paste, c(tmp, sep = ", "))
  } else {
    data[[".dgm"]] <- "Single DGM"
  }

  ### Build plot
  b <- rlang::sym(b)
  if (!is.null(methodvar)) {
    methodvar <- rlang::sym(methodvar)
    gg <- ggplot2::ggplot(data = data, ggplot2::aes(x = !!{{ b }}, y = .dgm, color = {{ methodvar }}, fill = {{ methodvar }}))
  } else {
    gg <- ggplot2::ggplot(data = data, ggplot2::aes(x = !!{{ b }}, y = .dgm))
  }
  gg <- gg +
    ggridges::geom_density_ridges(alpha = 0.25) +
    ggplot2::labs(y = "")

  ### Return plot
  return(gg)
}

### Heat plot
#' @keywords internal
.heat_plot <- function(data, methodvar, by, stats) {
  ### Create a .dgm column
  if (!is.null(by)) {
    tmp <- lapply(by, function(x) data[[x]])
    data[[".dgm"]] <- do.call(paste, c(tmp, sep = ", "))
  } else {
    data[[".dgm"]] <- "Single DGM"
  }

  ### Build basic plot
  if (!is.null(methodvar)) {
    methodvar <- rlang::sym(methodvar)
    gg <- ggplot2::ggplot(data = data, ggplot2::aes(x = {{ methodvar }}, y = .dgm, fill = est))
  } else {
    gg <- ggplot2::ggplot(data = data, ggplot2::aes(x = "Single Method", y = .dgm, fill = est)) +
      ggplot2::labs(x = "")
  }
  gg <- gg +
    ggplot2::geom_tile() +
    ggplot2::labs(y = "", fill = stats)

  ### Return plot
  return(gg)
}

### Nested loop plot
#' @keywords internal
.nlp <- function(data, methodvar, by, stats, target, top) {
  ### Compute internal data
  opts <- lapply(X = by, FUN = function(x) levels(data[[x]]))
  names(opts) <- by
  dgms <- do.call(expand.grid, opts)
  dgms[[".scenario"]] <- seq(nrow(dgms))
  opts_methods <- lapply(X = methodvar, FUN = function(x) levels(data[[x]]))
  names(opts_methods) <- methodvar
  opts_methods[[".scenario"]] <- unique(dgms[[".scenario"]])
  opts_methods <- do.call(expand.grid, opts_methods)
  dgms <- merge(dgms, opts_methods)
  data <- merge(x = data, y = dgms)
  data <- data[order(data[[".scenario"]]), ]

  ### Compute limits and placement of nested loop plot labels
  limits <- range(data[["est"]], na.rm = TRUE)
  delta <- diff(range(data[["est"]])) / 10
  placement <- vector(mode = "list", length = length(by))
  for (i in seq_along(placement)) {
    if (i == 1) {
      if (top) {
        placement[[i]] <- c(round(limits[2], digits = 2) + delta, round(limits[2], digits = 2) + 2 * delta)
      } else {
        placement[[i]] <- c(round(limits[1], digits = 2) - 2 * delta, round(limits[1], digits = 2) - delta)
      }
    } else {
      if (top) {
        placement[[i]] <- c(placement[[i - 1]][2] + delta, placement[[i - 1]][2] + 2 * delta)
      } else {
        placement[[i]] <- c(placement[[i - 1]][1] - 2 * delta, placement[[i - 1]][1] - delta)
      }
    }
  }

  ### Identify if simulation design is fully factorial
  ff <- max(data[[".scenario"]]) == length(unique(data[[".scenario"]]))
  num_ff <- length(unique(data[[".scenario"]]))

  ### Rescale variables included in the nested loop plot
  for (i in seq_along(by)) {
    data[[paste0(".", by[i])]] <- scales::rescale(x = as.numeric(data[[by[i]]]), to = placement[[i]])
  }

  ### Add back scenarios, to obtain equivalent fully-factorial NLP
  data <- merge(x = data, y = dgms, all = TRUE)
  data[[".notmissing"]] <- !is.na(data[["est"]])

  ### Build basic plot
  if (!is.null(methodvar)) {
    methodvar <- rlang::sym(methodvar)
    gg <- ggplot2::ggplot(data = data, mapping = ggplot2::aes(x = .scenario, y = est)) +
      ggplot2::geom_hline(yintercept = target, linetype = "dotted") +
      ggplot2::geom_step(mapping = ggplot2::aes(color = !!methodvar))
  } else {
    gg <- ggplot2::ggplot(data = data, mapping = ggplot2::aes(x = .scenario, y = est)) +
      ggplot2::geom_hline(yintercept = target, linetype = "dotted") +
      ggplot2::geom_step()
  }
  if (ff) {
    gg <- gg +
      ggplot2::labs(x = paste0(paste(vapply(X = by, FUN = function(x) length(levels(data[[x]])), FUN.VALUE = numeric(1)), collapse = " x "), " = ", length(unique(data[[".scenario"]])), " ordered scenarios"), y = stats)
  } else {
    gg <- gg +
      ggplot2::labs(x = paste0(num_ff, " ordered scenarios"), y = stats)
  }

  ### Build and add legends of nested loop plot
  for (i in seq_along(by)) {
    .tmp <- rlang::sym(paste0(".", by[i]))
    gg <- gg +
      ggplot2::geom_step(mapping = ggplot2::aes(y = !!.tmp)) +
      ggplot2::annotate(geom = "text", x = 1, y = placement[[i]][2] + delta / 2, label = paste0(by[i], ": ", paste(levels(data[[by[i]]]), collapse = ", ")), hjust = 0, vjust = 0.5)
  }

  ### Return plot
  return(gg)
}

#' @keywords internal
.density_plot <- function(data, b, methodvar, by, fitted, scales, hex, density.legend) {
  ### Compute internal df
  internal_df <- .make_internal_df(data = data, b = b, methodvar = methodvar, by = by)

  ### Build plot
  caption <- paste0("Comparison of variable '", b, "'")
  gg <- ggplot2::ggplot(data = internal_df, ggplot2::aes(x = X, y = Y)) +
    ggplot2::labs(caption = caption, fill = "Count")

  ### Add layer with contour or hexbin plot
  if (hex) {
    gg <- gg +
      ggplot2::geom_hex(show.legend = density.legend)
  } else {
    gg <- gg +
      ggplot2::stat_density_2d(mapping = ggplot2::aes(fill = after_stat(level)), geom = "polygon", show.legend = density.legend)
  }

  ### Add reference line
  gg <- gg +
    ggplot2::geom_abline(slope = 1, intercept = 0, linetype = "dashed")

  ### If 'by', use facet_grid; facet_wrap otherwise
  if (!is.null(by)) {
    by <- rlang::syms(by)
    gg <- gg +
      ggplot2::facet_grid(cols = ggplot2::vars(!!!{{ by }}), rows = ggplot2::vars(contrast), scales = scales, labeller = ggplot2::labeller(.rows = ggplot2::label_value, .cols = ggplot2::label_both))
  } else {
    gg <- gg +
      ggplot2::facet_wrap(~contrast)
  }

  ### If 'fitted' add regression line
  if (fitted) {
    gg <- gg +
      ggplot2::geom_smooth(method = "lm")
  }

  ### Return plot
  return(gg)
}
