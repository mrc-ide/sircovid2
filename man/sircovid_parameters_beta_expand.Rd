% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/parameters.R
\name{sircovid_parameters_beta_expand}
\alias{sircovid_parameters_beta_expand}
\title{Expand beta steps}
\usage{
sircovid_parameters_beta_expand(step, beta_step)
}
\arguments{
\item{step}{A vector of steps}

\item{beta_step}{A vector of betas}
}
\value{
A numeric vector the same length as \code{step}
}
\description{
Expand \code{beta_step} based on a series of \code{step}s.  Use this to
convert between the values passed to \code{\link[=sircovid_parameters_beta]{sircovid_parameters_beta()}}
and the actual beta values for a given set of steps.
}
