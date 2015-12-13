// This models is derived from section 11.3 of "Stan Modeling Language
// User's Guide and Reference Manual"

functions {
  int first_capture(int[] y_i) {
    for (k in 1:size(y_i))
      if (y_i[k])
        return k;
    return 0;
  }

  int last_capture(int[] y_i) {
    for (k_rev in 0:(size(y_i) - 1)) {
      int k;
      k <- size(y_i) - k_rev;
      if (y_i[k])
        return k;
    }
    return 0;
  }

  matrix prob_uncaptured(int nind, int n_occasions,
                         matrix p, matrix phi) {
    matrix[nind, n_occasions] chi;

    for (i in 1:nind) {
      chi[i, n_occasions] <- 1.0;
      for (t in 1:(n_occasions - 1)) {
        int t_curr;
        int t_next;

        t_curr <- n_occasions - t;
        t_next <- t_curr + 1;
        chi[i, t_curr] <- (1 - phi[i, t_curr]) +
                          phi[i, t_curr] *
                          (1 - p[i, t_next - 1]) *
                          chi[i, t_next];
      }
    }
    return chi;
  }
}

data {
  int<lower=0> nind;
  int<lower=2> n_occasions;
  int<lower=0,upper=1> y[nind, n_occasions];
  int<lower=1> g;
  int<lower=1,upper=g> group[nind];
}

transformed data {
  int<lower=0,upper=n_occasions> first[nind];
  int<lower=0,upper=n_occasions> last[nind];
  real beta1;

  for (i in 1:nind)
    first[i] <- first_capture(y[i]);
  for (i in 1:nind)
    last[i] <- last_capture(y[i]);
  beta1 <- 0;      // Corner constraint
}

parameters {
  real<lower=0,upper=1> mean_phi;    // Mean survival
  real<lower=0,upper=1> mean_p;      // Mean recapture
  real gamma[n_occasions - 1];       // Time effects
  real<lower=0,upper=1> p_g[g];      // Group-spec. recapture
  real beta2;                        // Prior for difference in male and
                                     // female survival
}

transformed parameters {
  matrix<lower=0,upper=1>[nind, n_occasions - 1] phi;
  matrix<lower=0,upper=1>[nind, n_occasions - 1] p;
  matrix<lower=0,upper=1>[nind, n_occasions] chi;
  vector[g] beta;

  beta[1] <- beta1;
  beta[2] <- beta2;

  // Constraints
  for (i in 1:nind) {
    for (t in 1:(first[i] - 1)) {
      phi[i, t] <- 0;
      p[i, t] <- 0;
    }
    for (t in first[i]:(n_occasions - 1)) {
      phi[i, t] <- inv_logit(beta[group[i]] + gamma[t]);
      p[i, t] <- p_g[group[i]];
    }
  }

  chi <- prob_uncaptured(nind, n_occasions, p, phi);
}

model {
  // Priors
  mean_phi ~ uniform(0, 1);
  mean_p ~ uniform(0, 1);
  beta2 ~ normal(0, 10)T[-10,10];
  p_g ~ uniform(0, 1);
  gamma ~ normal(0, 10);

  // Likelihood
  for (i in 1:nind) {
    if (first[i] > 0) {
      for (t in (first[i] + 1):last[i]) {
        1 ~ bernoulli(phi[i, t - 1]);
        y[i, t] ~ bernoulli(p[i, t - 1]);
      }
      1 ~ bernoulli(chi[i, last[i]]);
    }
  }
}

generated quantities {
  real<lower=0,upper=1> phi_g1[n_occasions - 1];
  real<lower=0,upper=1> phi_g2[n_occasions - 1];

  for (t in 1:(n_occasions - 1)) {
    phi_g1[t] <- inv_logit(gamma[t]); // Back-transformed survival of males
    phi_g2[t] <- inv_logit(gamma[t] + beta[2]); // Back-transformed survival of females
  }
}
