\name{tlpl_quantile}
\alias{tlpl_quantile}
\title{This function will calculate the desired quantiles for tlpl output.}
\usage{
  tlpl_quantile(tlpl, probs = c(0.025, 0.5, 0.975),
    which = "xpr", verbose = 1)
}
\arguments{
  \item{tlpl}{output from tlpl}

  \item{probs}{numeric vector of probabilities with values
  in [0,1].}

  \item{which}{determines which variables quantiles should
  be produced for}

  \item{verbose}{level of verbosity while running}
}
\value{
  a list with elements 'X.quantiles', 'p.quantiles', and
  'r.quantiles' with dimensions s (or r) x p x n where s is
  the number of states, r is the number of reactions,
  p=length(probs), and n is the number of observations
}
\description{
  This function will calculate the desired quantiles for
  tlpl output.
}
\seealso{
  tlpl
}

