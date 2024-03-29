% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{s_date_Eti}
\alias{s_date_Eti}
\title{Make Etiology design matrix for dates with R format.}
\usage{
s_date_Eti(Rdate, Y, basis = "ps", dof = ifelse(basis == "ncs", 5, 10),
  ...)
}
\arguments{
\item{Rdate}{a vector of dates of R format}

\item{Y}{Binary case/control status; 1 for case; 0 for controls}

\item{basis}{"ncs" for natural cubic splines; "ps" for penalized-splines based
on B-spline basis functions (NB: baker does not recommend setting ncs using 
this function; use splines::ns)}

\item{dof}{Degree-of-freedom for the bases. For "ncs" basis, \code{dof} is
the number of columns; For "ps" basis,  the number of columns is \code{dof}
if \code{intercept=TRUE}; \code{dof-1} if \code{FALSE}.}

\item{...}{Other arguments as in \code{\link[splines]{bs}}}
}
\value{
\itemize{
\item \code{Z_Eti} design matrix for etiology regression on dates.
}
}
\description{
\code{s_date_Eti} creates design matrices for etiology regressions;
}
\seealso{
\code{\link{nplcm}}
}
