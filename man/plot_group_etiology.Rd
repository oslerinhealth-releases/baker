% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plot-group-etiology.R
\name{plot_group_etiology}
\alias{plot_group_etiology}
\title{Plot grouped (two groups) posterior and cascade distributions (next top-three) 
within each group}
\usage{
plot_group_etiology(DIR_NPLCM, dir_taxo = NULL, ksFrac = 1,
  levellabel = 5)
}
\arguments{
\item{DIR_NPLCM}{The file path to the result folder}

\item{dir_taxo}{File path to taxonomy information (.csv). The default is \code{NULL}.
If specified, it will override \code{patho_taxo_dir} in \code{clean_options} read 
from \code{DIR_NPLCM}.}

\item{ksFrac}{A number between 0 and 1, which is the fraction of samples used to
calculate kernel stats::density}

\item{levellabel}{The contour line to be drawn in the final plot. Default is
\code{5}, which represents the contour of the \code{95} percent support region.}
}
\value{
A figure with group etiology.
}
\description{
DN: 1. the pathogens should have been ordered as in the perch_clean_data()
function. This function picks out pathogens not based on pathogen category lookup
table, but based on the order of pathogens that enter the analysis.
}
\seealso{
Other visualization functions: \code{\link{plot_BrS_panel}},
  \code{\link{plot_SS_panel}},
  \code{\link{plot_check_common_pattern}},
  \code{\link{plot_check_pairwise_SLORD}},
  \code{\link{plot_etiology_regression}},
  \code{\link{plot_etiology_side_by_side}},
  \code{\link{plot_etiology_strat}},
  \code{\link{plot_panels}}, \code{\link{plot_pie_panel}},
  \code{\link{plot_selected_etiology}}
}
\concept{visualization functions}
