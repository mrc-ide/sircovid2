## General things that we need but that aren't that interesting.

## We always use these age bands, so rather than detect them, we will
## check that things conform to them.
sircovid_age_bins <- function() {
  end <- c(seq(4, 79, by = 5), 100)
  start <- c(0, end[-length(end)] + 1L)
  list(start = start, end = end)
}


check_age_bins <- function(age_headers) {
  bins <- sircovid_age_bins()
  expected <- sprintf("%d to %d", bins$start, bins$end)
  if (!identical(age_headers, expected)) {
    stop(sprintf("Incorrect age bands:\nexpected: %s\ngiven: %s",
                 paste(squote(expected), collapse = ", "),
                 paste(squote(age_headers), collapse = ", ")))
  }
  bins
}


sircovid_date <- function(date) {
  days_into_2020 <- as.numeric(as_date(date) - as_date("2019-12-31"))
  if (any(days_into_2020 < 0)) {
    stop("Negative dates, sircovid_date likely applied twice")
  }
  days_into_2020
}


sircovid_date_as_date <- function(date) {
  assert_sircovid_date(date)
  as_date("2019-12-31") + date
}


assert_sircovid_date <- function(date) {
  if (!is.numeric(date)) {
    stop("'date' must be numeric - did you forget sircovid_date()?")
  }
  date
}


as_sircovid_date <- function(date) {
  if (is.character(date)) {
    sircovid_date(as_date(date))
  } else if (is_date(date)) {
    sircovid_date(date)
  } else {
    assert_sircovid_date(date)
  }
}


sircovid_population <- function(region) {
  if (is.null(region)) {
    stop("'region' must not be NULL")
  }

  if (is.null(cache$population)) {
    cache$population <- read_csv(sircovid_file("extdata/population.csv"))
  }

  population <- cache$population[[tolower(region)]]
  if (is.null(population)) {
    valid <- setdiff(names(cache$population), "age")
    stop(sprintf("Population not found for '%s': must be one of %s",
                 region, paste(squote(valid), collapse = ", ")))
  }

  population
}


##' @importFrom stats dnbinom rexp
ll_nbinom <- function(data, model, k, exp_noise) {
  if (is.na(data)) {
    return(numeric(length(model)))
  }
  mu <- model + rexp(length(model), rate = exp_noise)
  dnbinom(data, k, mu = mu, log = TRUE)
}