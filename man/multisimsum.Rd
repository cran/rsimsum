% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/multisimsum.R
\name{multisimsum}
\alias{multisimsum}
\title{Analyses of simulation studies with multiple estimands at once, including Monte Carlo error}
\usage{
multisimsum(
  data,
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
  control = list()
)
}
\arguments{
\item{data}{A \code{data.frame} in which variable names are interpreted.
It has to be in tidy format, e.g. each variable forms a column and each observation forms a row.}

\item{par}{The name of the variable containing the methods to compare.
Can be \code{NULL}.}

\item{estvarname}{The name of the variable containing the point estimates.
Note that some column names are forbidden: these are listed below in the \emph{Details} section.}

\item{se}{The name of the variable containing the standard errors of the point estimates.
Note that some column names are forbidden: these are listed below in the \emph{Details} section.}

\item{true}{The true value of the parameter; this is used in calculations of bias, relative bias, coverage, and mean squared error and is required whenever these performance measures are requested.
\code{true} can be a numeric value or a string that identifies a column in \code{data}.
In the former setting, \code{simsum} will assume the same value for all replications; conversely, each replication will use a distinct value for \code{true} as identified by each row of \code{data}.
See \code{vignette("E-custom-inputs", package = "rsimsum")} for more details.
Note that some column names are forbidden: these are listed below in the \emph{Details} section.}

\item{methodvar}{The name of the variable containing the methods to compare.
For instance, methods could be the models compared within a simulation study.
Can be \code{NULL}.
If a vector of column names is passed to \code{simsum()}, those columns will be combined into a single column named \verb{:methodvar} using the \code{\link[base:interaction]{base::interaction()}} function before computing all performance measures.
Note that some column names are forbidden: these are listed below in the \emph{Details} section.}

\item{ref}{Specifies the reference method against which relative precision will be calculated.
Only useful if \code{methodvar} is specified.}

\item{by}{A vector of variable names to compute performance measures by a list of factors. Factors listed here are the (potentially several) data-generating mechanisms used to simulate data under different scenarios (e.g. sample size, true distribution of a variable, etc.).
Can be \code{NULL}.
Note that some column names are forbidden: these are listed below in the \emph{Details} section.}

\item{ci.limits}{Can be used to specify the limits (lower and upper) of confidence intervals used to calculate coverage and bias-eliminated coverage.
Useful for non-Wald type estimators (e.g. bootstrap).
Defaults to \code{NULL}, where Wald-type confidence intervals based on the provided SEs are calculated for coverage; otherwise, it can be a numeric vector (for fixed confidence intervals) or a vector of strings that identify columns in \code{data} with replication-specific lower and upper limits.
See \code{vignette("E-custom-inputs", package = "rsimsum")} for more details.
Note that some column names are forbidden: these are listed below in the \emph{Details} section.}

\item{df}{Can be used to specify that a column containing the replication-specific number of degrees of freedom that will be used to calculate confidence intervals for coverage (and bias-eliminated coverage) assuming t-distributed critical values (rather than normal theory intervals).
See \code{vignette("E-custom-inputs", package = "rsimsum")} for more details.
Note that some column names are forbidden: these are listed below in the \emph{Details} section.}

\item{dropbig}{Specifies that point estimates or standard errors beyond the maximum acceptable values should be dropped. Defaults to \code{FALSE}.}

\item{x}{Set to \code{TRUE} to include the \code{data} argument used to calculate summary statistics (i.e. after pre-processing the input dataset e.g. removing values deemed too large via the \code{dropbig} argument) as a slot. Calling \code{simsum} with \code{x = TRUE} is required to produce zipper plots. The downside is that the size of the returned object increases considerably, therefore it is set to \code{FALSE} by default.}

\item{control}{A list of parameters that control the behaviour of \code{simsum}.
Possible values are:
\itemize{
\item \code{mcse}, whether to calculate Monte Carlo standard errors. Defaults to \code{TRUE};
\item \code{level}, the significance level used for coverage, bias-eliminated coverage, and power. Defaults to 0.95;
\item \code{power_df}, whether to use robust critical values from a t distribution with \code{power_df} degrees of freedom when calculating power. Defaults to \code{NULL}, in which case a Gaussian distribution is used;
\item \code{na.rm}, whether to remove point estimates or standard errors where either (or both) is missing. Defaults to \code{TRUE};
\item \code{char.sep}, a character utilised when splitting the input dataset \code{data}. Generally, this should not be changed;
\item \code{dropbig.max}, specifies the maximum acceptable absolute value of the point estimates, after standardisation. Defaults to 10;
\item \code{dropbig.semax}, specifies the maximum acceptable absolute value of the standard error, after standardisation. Defaults to 100
\item \code{dropbig.robust}, specifies whether to use robust standardisation (using median and inter-quartile range) rather than normal standardisation (using mean and standard deviation). Defaults to \code{TRUE}, in which case robust standardisation will be used for \code{dropbig}.
}}
}
\value{
An object of class \code{multisimsum}.
}
\description{
\code{multisimsum} is an extension of \code{\link[=simsum]{simsum()}} that can handle multiple estimated parameters at once.
\code{multisimsum} calls \code{\link[=simsum]{simsum()}} internally, each estimands at once.
There is only one new argument that must be set when calling \code{multisimsum}: \code{par}, a string representing the column of \code{data} that identifies the different estimands.
Additionally, with \code{multisimsum} the argument \code{true} can be a named vector, where names correspond to each estimand (see examples).
Otherwise, constant values (or values identified by a column in \code{data}) will be utilised.
See \code{vignette("E-custom-inputs", package = "rsimsum")} for more details.
}
\details{
The following names are not allowed for \code{estvarname}, \code{se}, \code{methodvar}, \code{by}, \code{par}: \code{stat}, \code{est}, \code{mcse}, \code{lower}, \code{upper}, \verb{:methodvar}.
}
\examples{
data("frailty", package = "rsimsum")
ms <- multisimsum(
  data = frailty,
  par = "par", true = c(trt = -0.50, fv = 0.75),
  estvarname = "b", se = "se", methodvar = "model",
  by = "fv_dist"
)
ms
}
