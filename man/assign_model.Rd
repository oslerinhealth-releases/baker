% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/assign-model.R
\name{assign_model}
\alias{assign_model}
\title{Interpret the model specified by user}
\usage{
assign_model(model_options, data_nplcm, silent = TRUE)
}
\arguments{
\item{model_options}{See \code{\link{nplcm}} function.}

\item{data_nplcm}{Data. See \code{\link{nplcm}} function for data structure.}

\item{silent}{Default is \code{TRUE} for no messages; \code{FALSE} otherwise.}
}
\value{
A list of model specifications:
\itemize{
   \item \code{num_slice} A vector counting the No. of measurement slices for each
   level of measurement quality (e.g., MBS, MSS, MGS representing
   Bronze-Standard Measurements - case-control, 
   Silver-Standard Measurements and Gold-Standard
   Measurements - case-only);
   \item \code{nested} Local dependence specification for modeling bronze-standard
   data. \code{TRUE} for nested models (conditional dependence given disease class); 
   \code{FALSE} for non-nested models (conditional independence given disease class). 
   One for each BrS slice.
   \item \code{regression}
       \itemize{
           \item \code{do_reg_Eti} \code{TRUE} for doing etiology regression.
           It means let the etiology fractions vary with explanatory variables. 
           \code{FALSE} otherwise;
           \item \code{do_reg_FPR} A vector whose names represent the slices
           of bronze-standard data. For each slice of BrS measurements, 
           \code{TRUE} does false positive rate regression. It means the false
           positive rates, estimatable from controls, can vary with 
           covariates; \code{FALSE} otherwise.
           \item code{is_discrete_predictor} A list of names "Eti", and 
           the names for every slice of bronze-standard data. \code{TRUE}
           if all predictors are discrete; \code{FALSE} otherwise.
       }
}
}
\description{
\code{assign_model} translates options specified by a user (e.g., in 
\code{model_options}) into information that can be understood by \code{baker}.
}
\details{
\code{assign_model} will be modified to check if data are conformable
to specified model.
}
\concept{specification checking functions}
