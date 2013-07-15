data {
  int<lower=0> N; 
  vector[N] dist;
  vector[N] arsenic;
  int<lower=0,upper=1> switch_w[N];
}
transformed data {
  vector[N] dist100;
  vector[N] c_dist100;
  vector[N] c_arsenic;
  vector[N] inter;
  real mu_dist100;
  real mu_arsenic;
  dist100 <- dist / 100;
  mu_dist100 <- mean(dist100);
  mu_arsenic <- mean(arsenic);
  c_dist100 <- dist100 - mu_dist100;
  c_arsenic <- arsenic - mu_arsenic;
  inter <- c_dist100 .* c_arsenic;
}
parameters {
  vector[4] beta;
} 
model {
  for (n in 1:N)
    switch_w[n] ~ bernoulli(inv_logit(beta[1] + beta[2] * c_dist100[n] 
                            + beta[3] * c_arsenic[n] + beta[4] * inter[n]));
}
