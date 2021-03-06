## E and R stage indexed by i, j, k with
## i for the age group
## j for the progression (not exponential latent and infectious period)
## k for the infectivity group

## Number of age classes & number of transmissibility classes
N_age <- user()
trans_classes <- user(1)

## Definition of the time-step and output as "time"
dt <- user()
initial(time) <- 0
update(time) <- (step + 1) * dt

## Core equations for transitions between compartments:
update(S[]) <- S[i] - n_SE[i]
update(E[, , ]) <- E[i, j, k] + delta_E[i, j, k]
update(I_asympt[, , ]) <- I_asympt[i, j, k] + delta_I_asympt[i, j, k]
update(I_mild[, , ]) <- I_mild[i, j, k] + delta_I_mild[i, j, k]
update(I_ILI[, , ]) <- I_ILI[i, j, k] + delta_I_ILI[i, j, k]
update(R[]) <- R[i] + delta_R[i]
update(I_hosp[, , ]) <- I_hosp[i, j, k] + delta_I_hosp[i, j, k]
update(I_ICU[, , ]) <- new_I_ICU[i, j, k]
update(R_hosp[, , ]) <- R_hosp[i, j, k] + delta_R_hosp[i, j, k]

update(D[]) <- new_D[i]

## Stuff we want to track in addition to number of individuals
## in each compartment.

## Individual probabilities of transition:
p_SE[] <- 1 - exp(-lambda[i] * dt) # S to I - age dependent
p_EE <- 1 - exp(-gamma_E * dt) # progression of latent period
p_II_asympt <- 1 - exp(-gamma_asympt * dt) # progression of infectious period
p_II_mild <- 1 - exp(-gamma_mild * dt)
p_II_ILI <- 1 - exp(-gamma_ILI * dt)
p_II_hosp <- 1 - exp(-gamma_hosp * dt)
p_II_ICU <- 1 - exp(-gamma_ICU * dt)
p_R_hosp <- 1 - exp(-gamma_rec * dt)

## Draws from binomial distributions for numbers changing between
## compartments:
n_SE[] <- rbinom(S[i], p_SE[i])
n_EE[, , ] <- rbinom(E[i, j, k], p_EE)
n_II_asympt[, , ] <- rbinom(I_asympt[i, j, k], p_II_asympt)
n_II_mild[, , ] <- rbinom(I_mild[i, j, k], p_II_mild)
n_II_ILI[, , ] <- rbinom(I_ILI[i, j, k], p_II_ILI)
n_II_hosp[, , ] <- rbinom(I_hosp[i, j, k], p_II_hosp)
n_II_ICU[, , ] <- rbinom(I_ICU[i, j, k], p_II_ICU)
n_R_hosp[, , ] <- rbinom(R_hosp[i, j, k], p_R_hosp)

## Computes the number of asymptomatic
n_EI_asympt[, ] <- rbinom(n_EE[i, s_E, j], p_asympt[i])


## Computes the number of mild cases - p_sympt_ILI gives the
## proportion of febrile/ILI cases among the symptomatics
n_EI_mild[, ] <-
  rbinom(n_EE[i, s_E, j] - n_EI_asympt[i, j], 1 - p_sympt_ILI[i])

## Computes the number of ILI cases
n_EI_ILI[, ] <- n_EE[i, s_E, j] - n_EI_asympt[i, j] - n_EI_mild[i, j]

## Compute the aux_p_bin matrix of binom nested coeff
aux_p_bin[, 1] <- trans_profile[i, 1]
aux_p_bin[, 2:(trans_classes - 1)] <-
  trans_profile[i, j] / sum(trans_profile[i, j:trans_classes])

## Implementation of multinom via nested binomial
aux_EE[, 1, 1] <- rbinom(n_SE[i], aux_p_bin[i, 1])
aux_EE[, 1, 2:(trans_classes - 1)] <-
  rbinom(n_SE[i] - sum(aux_EE[i, 1, 1:(k - 1)]), aux_p_bin[i, k])
aux_EE[, 1, trans_classes] <-
  n_SE[i] - sum(aux_EE[i, 1, 1:(trans_classes - 1)])

## Work out the E->E transitions
aux_EE[, 2:s_E, ] <- n_EE[i, j - 1, k]
aux_EE[, 1:s_E, ] <- aux_EE[i, j, k] - n_EE[i, j, k]
delta_E[, , ] <- aux_EE[i, j, k]

## Work out the I_asympt->I_asympt transitions
aux_II_asympt[, 1, ] <- n_EI_asympt[i, k]
aux_II_asympt[, 2:s_asympt, ] <- n_II_asympt[i, j - 1, k]
aux_II_asympt[, 1:s_asympt, ] <- aux_II_asympt[i, j, k] - n_II_asympt[i, j, k]
delta_I_asympt[, , ] <- aux_II_asympt[i, j, k]

## Work out the I_mild->I_mild transitions
aux_II_mild[, 1, ] <- n_EI_mild[i, k]
aux_II_mild[, 2:s_mild, ] <- n_II_mild[i, j - 1, k]
aux_II_mild[, 1:s_mild, ] <- aux_II_mild[i, j, k] - n_II_mild[i, j, k]
delta_I_mild[, , ] <- aux_II_mild[i, j, k]

## Work out the I_ILI->I_ILI transitions
aux_II_ILI[, 1, ] <- n_EI_ILI[i, k]
aux_II_ILI[, 2:s_ILI, ] <- n_II_ILI[i, j - 1, k]
aux_II_ILI[, 1:s_ILI, ] <- aux_II_ILI[i, j, k] - n_II_ILI[i, j, k]
delta_I_ILI[, , ] <- aux_II_ILI[i, j, k]

## Work out the I_hosp->I_hosp transitions
n_ILI_to_hosp[, ] <- rbinom(n_II_ILI[i, s_ILI, j], 1 - p_recov_ILI[i])
aux_II_hosp[, 1, ] <- n_ILI_to_hosp[i, k]
aux_II_hosp[, 2:s_hosp, ] <- n_II_hosp[i, j - 1, k]
aux_II_hosp[, 1:s_hosp, ] <- aux_II_hosp[i, j, k] - n_II_hosp[i, j, k]
delta_I_hosp[, , ] <- aux_II_hosp[i, j, k]

## Work out the death in hospital without getting critical care
n_death_hosp[, ] <- rbinom(n_II_hosp[i, s_hosp, j], p_death_hosp[i])

## Work out the I_ICU -> I_ICU transitions
n_hosp_to_ICU[, ] <-
  rbinom(n_II_hosp[i, s_hosp, j] - n_death_hosp[i, j],
         1 - p_recov_hosp[i] - p_death_hosp[i])
aux_II_ICU[, 1, ] <- n_hosp_to_ICU[i, k]
aux_II_ICU[, 2:s_ICU, ] <- n_II_ICU[i, j - 1, k]
aux_II_ICU[, 1:s_ICU, ] <- aux_II_ICU[i, j, k] - n_II_ICU[i, j, k]
delta_I_ICU[, , ] <- aux_II_ICU[i, j, k]

new_I_ICU[, , ] <- I_ICU[i, j, k] + delta_I_ICU[i, j, k]

## Work out the R_hosp -> R_hosp transitions
n_ICU_to_R_hosp[, ] <- rbinom(n_II_ICU[i, s_ICU, j], p_recov_ICU[i])
aux_R_hosp[, 1, ] <- n_ICU_to_R_hosp[i, k]
aux_R_hosp[, 2:s_rec, ] <- n_R_hosp[i, j - 1, k]
aux_R_hosp[, 1:s_rec, ] <- aux_R_hosp[i, j, k] - n_R_hosp[i, j, k]
delta_R_hosp[, , ] <- aux_R_hosp[i, j, k]

## Work out the number of deaths
delta_D[] <- sum(n_II_ICU[i, s_ICU, ]) - sum(n_ICU_to_R_hosp[i, ]) +
  sum(n_death_hosp[i, ])

new_D[] <- D[i] + delta_D[i]

## Work out the number of recovery
delta_R[] <-
  sum(n_II_asympt[i, s_asympt, ]) +
  sum(n_II_mild[i, s_mild, ]) +
  sum(n_II_ILI[i, s_ILI, ]) -
  sum(n_ILI_to_hosp[i, ]) +
  sum(n_II_hosp[i, s_hosp, ]) -
  sum(n_hosp_to_ICU[i, ]) -
  sum(n_death_hosp[i, ]) +
  sum(n_R_hosp[i, s_rec, ])

## Compute the force of infection
I_with_diff_trans[, ] <- trans_increase[i, j] * (
  sum(I_asympt[i, , j]) +
  sum(I_mild[i, , j]) +
  sum(I_ILI[i, , j]) +
  hosp_transmission * sum(I_hosp[i, , j]) +
  ICU_transmission * sum(I_ICU[i, , j]))

s_ij[, ] <- m[i, j] * sum(I_with_diff_trans[j, ])
lambda[] <- beta * sum(s_ij[i, ])

## Initial states are all zerod as we will provide a state vector
## setting S and I based on the seeding model.
initial(S[]) <- 0
initial(E[, , ]) <- 0
initial(I_asympt[, , ]) <- 0
initial(I_mild[, , ]) <- 0
initial(I_ILI[, , ]) <- 0
initial(I_hosp[, , ]) <- 0
initial(I_ICU[, , ]) <- 0
initial(R_hosp[, , ]) <- 0
initial(R[]) <- 0
initial(D[]) <- 0
initial(N_tot) <- 0

## aggregate our reporting statistics
initial(I_ICU_tot) <- 0
update(I_ICU_tot) <- sum(new_I_ICU)

initial(D_tot) <- 0
update(D_tot) <- sum(new_D)

## User defined parameters - default in parentheses:

## Parameters of the E classes
s_E <- user()
gamma_E <- user(0.1)

## Probability of transitioning from the E to the asymptomatic,
## febrile classes, the rest goes in mild i.e with mild symptoms
p_asympt[] <- user()
p_sympt_ILI[] <- user()

## Parameters of the I_asympt classes
s_asympt <- user()
gamma_asympt <- user(0.1)

## Parameters of the I_mild classes
s_mild <- user()
gamma_mild <- user(0.1)

## Parameters of the I_ILI classes
s_ILI <- user()
gamma_ILI <- user(0.1)
p_recov_ILI[] <- user()

## Parameters of the I_hosp classes
s_hosp <- user()
gamma_hosp <- user(0.1)
p_recov_hosp[] <- user()
p_death_hosp[] <- user()

## Parameters of the I_ICU classes
s_ICU <- user()
gamma_ICU <- user(0.1)
p_recov_ICU[] <- user()

## Parameters of the R_hosp classes
s_rec <- user()
gamma_rec <- user(0.1)

## Parameters of the age stratified transmission
beta_step[] <- user()
dim(beta_step) <- user()
## What we really want is min(step + 1, length(beta_step)) but that's not
## supported by odin (it could be made to support this). This code
## does currently create a compiler warning with -Wsign-compare on
## because we have an unsigned/signed integer comparison
beta <- if (step >= length(beta_step))
          beta_step[length(beta_step)] else beta_step[step + 1]

## Useful for debugging
initial(beta_out) <- beta_step[1]
update(beta_out) <- beta

m[, ] <- user()
## TODO: trans_profile and trans_increase can be removed as not used;
## this will required removing one layer off many variables so be
## careful.
trans_profile[, ] <- 1
trans_increase[, ] <- 1
hosp_transmission <- user()
ICU_transmission <- user()

## Dimensions of the different "vectors" here vectors stand for
## multi-dimensional arrays

## Vectors handling the S class
dim(S) <- N_age

## Vectors handling the E class
dim(E) <- c(N_age, s_E, trans_classes)
dim(aux_EE) <- c(N_age, s_E, trans_classes)
dim(delta_E) <- c(N_age, s_E, trans_classes)
dim(n_EE) <- c(N_age, s_E, trans_classes)

## Vectors handling the I_asympt class
dim(I_asympt) <- c(N_age, s_asympt, trans_classes)
dim(aux_II_asympt) <- c(N_age, s_asympt, trans_classes)
dim(delta_I_asympt) <- c(N_age, s_asympt, trans_classes)
dim(n_II_asympt) <- c(N_age, s_asympt, trans_classes)

## Vectors handling the I_mild class
dim(I_mild) <- c(N_age, s_mild, trans_classes)
dim(aux_II_mild) <- c(N_age, s_mild, trans_classes)
dim(delta_I_mild) <- c(N_age, s_mild, trans_classes)
dim(n_II_mild) <- c(N_age, s_mild, trans_classes)

## Vectors handling the I_ILI class
dim(I_ILI) <- c(N_age, s_ILI, trans_classes)
dim(aux_II_ILI) <- c(N_age, s_ILI, trans_classes)
dim(delta_I_ILI) <- c(N_age, s_ILI, trans_classes)
dim(n_II_ILI) <- c(N_age, s_ILI, trans_classes)
dim(p_recov_ILI) <- c(N_age)

## Vectors handling the I_hosp class
dim(I_hosp) <- c(N_age, s_hosp, trans_classes)
dim(aux_II_hosp) <- c(N_age, s_hosp, trans_classes)
dim(delta_I_hosp) <- c(N_age, s_hosp, trans_classes)
dim(n_II_hosp) <- c(N_age, s_hosp, trans_classes)
dim(p_recov_hosp) <- c(N_age)
dim(n_death_hosp) <- c(N_age, trans_classes)

## Vectors handling the I_ICU class
dim(I_ICU) <- c(N_age, s_ICU, trans_classes)
dim(aux_II_ICU) <- c(N_age, s_ICU, trans_classes)
dim(delta_I_ICU) <- c(N_age, s_ICU, trans_classes)
dim(n_II_ICU) <- c(N_age, s_ICU, trans_classes)
dim(p_recov_ICU) <- c(N_age)
dim(new_I_ICU) <- c(N_age, s_ICU, trans_classes)

## Vectors handling the R_hosp class
dim(R_hosp) <- c(N_age, s_rec, trans_classes)
dim(aux_R_hosp) <- c(N_age, s_rec, trans_classes)
dim(delta_R_hosp) <- c(N_age, s_rec, trans_classes)
dim(n_R_hosp) <- c(N_age, s_rec, trans_classes)

## Vectors handling the R class
dim(R) <- c(N_age)
dim(delta_R) <- c(N_age)

## Vectors handling the D class
dim(D) <- c(N_age)
dim(delta_D) <- c(N_age)
dim(new_D) <- c(N_age)

## Vectors handling the S->E transition where infected are split
## between level of infectivity
dim(p_SE) <- N_age
dim(n_SE) <- N_age
dim(aux_p_bin) <- c(N_age, trans_classes)

## Vectors handling the E->I transition where newly infectious cases
## are split between level of severity
dim(n_EI_asympt) <- c(N_age, trans_classes)
dim(n_EI_mild) <- c(N_age, trans_classes)
dim(n_EI_ILI) <- c(N_age, trans_classes)

## Vectors handling number of new hospitalisations, ICU admissions and
## recoveries in hospital
dim(n_hosp_to_ICU) <- c(N_age, trans_classes)
dim(n_ILI_to_hosp) <- c(N_age, trans_classes)
dim(n_ICU_to_R_hosp) <- c(N_age, trans_classes)

## Vectors handling the severity profile
dim(p_asympt) <- c(N_age)
dim(p_sympt_ILI) <- c(N_age)

## Vectors handling the potential death in hospital before critical care
dim(p_death_hosp) <- c(N_age)

## Vectors handling the age specific heterogeneous transmission process
dim(lambda) <- N_age
dim(s_ij) <- c(N_age, N_age)
dim(m) <- c(N_age, N_age)
dim(trans_profile) <- c(N_age, trans_classes)
dim(trans_increase) <- c(N_age, trans_classes)
dim(I_with_diff_trans) <- c(N_age, trans_classes)

## Used for error checking - population should be constant
update(N_tot) <- sum(S) + sum(R) + sum(D) + sum(E) + sum(I_asympt) +
  sum(I_mild) + sum(I_ILI) + sum(I_hosp) + sum(I_ICU) + sum(R_hosp)
