context("carehomes (support)")

test_that("carehomes progression parameters", {
  p <- carehomes_parameters_progression()
  expect_setequal(
    names(p),
    c("s_E", "s_asympt", "s_mild", "s_ILI", "s_comm_D", "s_hosp_D",
      "s_hosp_R", "s_ICU_D", "s_ICU_R", "s_triage", "s_stepdown", "s_PCR_pos",
      "gamma_E", "gamma_asympt", "gamma_mild", "gamma_ILI", "gamma_comm_D",
      "gamma_hosp_D", "gamma_hosp_R", "gamma_ICU_D", "gamma_ICU_R",
      "gamma_triage", "gamma_stepdown", "gamma_R_pre_1", "gamma_R_pre_2",
      "gamma_test", "gamma_PCR_pos"))

  ## TODO: Lilith; you had said that there were some constraints
  ## evident in the fractional representation of these values - can
  ## you write tests here that reflect that?
})


test_that("carehomes_parameters returns a list of parameters", {
  date <- sircovid_date("2020-02-01")
  p <- carehomes_parameters(date, "uk")

  expect_type(p, "list")
  expect_equal(p$beta_step, 0.08)

  ## Transmission matrix is more complicated - see below
  expect_identical(p$m[1:17, 1:17], sircovid_transmission_matrix())
  expect_identical(
    p$m,
    carehomes_transmission_matrix(0.1, 4e-5, 5e-4, p$population))

  progression <- carehomes_parameters_progression()
  expect_identical(p[names(progression)], progression)

  shared <- sircovid_parameters_shared(date, "uk", NULL, NULL)
  ## NOTE: This is updated with CHR and CHW but may be renamed later;
  ## see comment in carehomes_parameters()
  shared$N_age <- 19L
  expect_identical(p[names(shared)], shared)

  severity <- carehomes_parameters_severity(NULL, p$population, 0.7)
  expect_identical(p[names(severity)], severity)

  extra <- setdiff(names(p),
                   c("m", names(shared), names(progression), names(severity)))
  expect_setequal(
    extra,
    c("N_tot", "carehome_beds", "carehome_residents", "carehome_workers"))

  expect_equal(p$carehome_beds, sircovid_carehome_beds("uk"))
  expect_equal(p$carehome_residents, round(p$carehome_beds * 0.742))
  expect_equal(p$carehome_workers, p$carehome_residents)

  ## Can be slightly off due to rounding error
  expect_true(abs(sum(p$N_tot) - sum(p$population)) < 3)
  expect_length(p$N_tot, 19)
})


test_that("can compute severity for carehomes model", {
  population <- sircovid_population("uk")
  severity <- carehomes_parameters_severity(NULL, population, 0.7)
  expect_true(all(lengths(severity) == 19))
  expect_setequal(names(severity), names(sircovid_parameters_severity(NULL)))

  expect_true(
    all(severity$p_serocoversion == severity$p_serocoversion[[1]]))
  expect_equal(
    severity$p_death_comm, rep(c(0, 0.7), c(18, 1)))
  expect_equal(
    severity$p_admit_conf, rep(0.2, 19))
})


test_that("Can compute transmission matrix for carehomes model", {
  population <- sircovid_population("uk")
  m <- carehomes_transmission_matrix(0.1, 4e-5, 5e-4, population)
  expect_equal(rownames(m)[18:19], c("CHW", "CHR"))
  expect_equal(colnames(m)[18:19], c("CHW", "CHR"))
  expect_equal(dim(m), c(19, 19))
  expect_equal(m[1:17, 1:17], sircovid_transmission_matrix())
  expect_equal(unname(m[18:19, 18:19]),
               matrix(rep(c(4e-5, 5e-4), c(3, 1)), 2))
  expect_equal(m, t(m))

  ## TODO: we should get a check of the weighted mean and resident
  ## scaling here
})


test_that("can tune the noise parameter", {
  p1 <- carehomes_parameters_observation()
  p2 <- carehomes_parameters_observation(1e4)
  expect_setequal(names(p1), names(p2))
  v <- setdiff(names(p1), "exp_noise")
  expect_mapequal(p1[v], p2[v])
  expect_equal(p1$exp_noise, 1e6) # default
  expect_equal(p2$exp_noise, 1e4) # given
})


test_that("carehomes_index identifies ICU and D_tot in real model", {
  p <- carehomes_parameters(sircovid_date("2020-02-07"), "england")
  mod <- carehomes$new(p, 0, 10)
  info <- mod$info()
  index <- carehomes_index(info)
  expect_equal(index$run[[1]], which(names(info) == "I_ICU_tot"))
  expect_equal(index$run[[2]], which(names(info) == "general_tot"))
  expect_equal(index$run[[3]], which(names(info) == "D_comm_tot"))
  expect_equal(index$run[[4]], which(names(info) == "D_hosp_tot"))
  expect_equal(index$run[[5]], which(names(info) == "D_tot"))
  expect_equal(index$run[[6]], which(names(info) == "cum_admit_conf"))
  expect_equal(index$run[[7]], which(names(info) == "cum_new_conf"))
  expect_equal(index$run[[8]], which(names(info) == "R_pre_15_64"))
  expect_equal(index$run[[9]], which(names(info) == "R_neg_15_64"))
  expect_equal(index$run[[10]], which(names(info) == "R_pos_15_64"))
})


test_that("carehome worker index is sensible", {
  expect_equal(carehomes_index_workers(), 6:13)
})


test_that("Can compute initial conditions", {
  p <- carehomes_parameters(sircovid_date("2020-02-07"), "england")
  mod <- carehomes$new(p, 0, 10)
  info <- mod$info()

  initial <- carehomes_initial(info, 10, p)
  expect_setequal(names(initial), c("state", "step"))
  expect_equal(initial$step, p$initial_step)

  ## TODO: this index faff simplifies away after odin.dust improvements
  len <- vnapply(info, prod)
  start <- cumsum(len) - len + 1L
  expect_equal(
    initial$state[[start[["N_tot2"]]]],
    sum(p$population))
  expect_equal(
    initial$state[seq(start[["N_tot"]], length.out = len[["N_tot"]])],
    p$N_tot)

  i_S <- seq(start[["S"]], by = 1, length.out = info[["S"]])
  i_I <- seq(start[["I_asympt"]], by = 1, length.out = info[["I_asympt"]][[1]])

  expect_equal(
    initial$state[i_S] + initial$state[i_I],
    p$N_tot)
  expect_equal(
    initial$state[i_I],
    append(rep(0, 18), 10, after = 3))
  expect_equal(
    initial$state[[start[["R_pre"]] + 3]], 10)
  expect_equal(
    initial$state[[start[["PCR_pos"]] + 3]], 10)

  ## 19 (S) + 19 (N_tot) + 4 (N_tot2 + I_asympt[4] + R_pre[4] + PCR_pos[4])
  expect_equal(sum(initial$state != 0), 42)
})