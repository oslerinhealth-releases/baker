% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/simulate-nplcm.R
\name{simulate_ss}
\alias{simulate_ss}
\title{Simulate Silver-Standard Data}
\usage{
simulate_ss(set_parameter, latent_samples)
}
\arguments{
\item{set_parameter}{True model parameters in a npLCM specification. It is a list comprised
of the following elements:
 \itemize{
    \item{\code{cause_list}} a vector of disease classes names among cases (since
    the causes could be multi-pathogen, so its length could be longer than the total number of unique
    pathogens)
    \item{\code{etiology}} a vector of proportions that sum to one
    \item{\code{pathogen_BrS}} a vector of pathogen names measured in bronze-standard data.
    This current function only simulates one slice defined by {specimen}{test}{pathogen}
    \item{\code{pathogen_SS}} a vector of pathogen names measured in silver-standard data.
    \item{\code{meas_nm}} a list of {specimen}{test} names e.g., \code{list(MBS = c("NPPCR"),MSS="BCX")}
    for nasalpharyngeal specimen tested by polymerase chain reaction and blood tested by culture (Cx)
    \item{\code{Lambda}} subclass weights \eqn{\nu_1, \nu_2, \ldots, \nu_K} among controls; 
    a vector of \code{K} probabilities that sum to 1.
    \item{\code{Eta}}    a matrix of dimension \code{length(cause_list)} by K;
    each row are subclass weights \eqn{\eta_1, \eta_2, \ldots, \eta_K} for each disease class,
    so needs to sum to one. In Wu et al 2016, the subclass weights are the same across disease
    classes across rows. But when simulating data, one can specify rows with distinct
    probabilities - it is a matter whether we can recover these parameters (possible when
    we randomly observe some cases' true disease classes)
    \item{\code{PsiBS/PsiSS}} False positive rates \eqn{\Psi} for Bronze-Standard data and 
    for Silver-Standard data. Dimension is J by K. 
    \code{PsiSS} is supposed to be 0 vector (by perfect specificity in silver-standard measures).
    \item{\code{ThetaBS/ThetaSS}}  true positive rates \eqn{\Theta} for Bronze-Standard data and 
    for Silver-Standard data. Dimension is J by K (can contain NA if the total number of pathogens is
    more than the measured pathogens in SS).
    \item{\code{Nu}} the number of controls
    \item{\code{Nd}} the number of cases
 }}

\item{latent_samples}{sampled latent status for all the subjects, for use in simulate
BrS measurements.}
}
\value{
a data frame with first column being case-control status (case at top) and
columns of silver-standard measurements
}
\description{
simulate SS measurements:
}
\seealso{
Other simulation functions: \code{\link{simulate_brs}},
  \code{\link{simulate_latent}},
  \code{\link{simulate_nplcm}}
}
\concept{simulation functions}
