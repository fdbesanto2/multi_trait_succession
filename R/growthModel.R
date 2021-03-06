# load data & libraries

# Coding guidelines -arguments-> give in order: traits, size, env

# ALLOMETRIC MODEL FOR SIZE OF CONMPONENTS
Height <- function(A) {
  p.a1 * A^p.B1
}
dHdA <- function(A) {
  p.B1 * p.a1 * A^(p.B1 - 1)
}
LeafArea <- function(h) {
  (h/p.a1)^(1/p.B1)
}
LeafMass <- function(lma, A) {
  A * lma
}
RootMass <- function(A) {
  p.a3 * A
}
SapwoodMass <- function(rho, A, h) {
  rho/p.theta * etac(p.eta) * A * h
}
etac <- function(eta) {
  1 - 2/(1 + eta) + 1/(1 + 2 * eta)
}
BarkMass <- function(rho, A, h) {
  p.b * SapwoodMass(A, h, rho)
}
HeartwoodMass <- function(rho, A) {
  rho * p.a2 * A^p.B2
}
Diameter <- function(rho, stemMass) {
  (stemMass/rho/p.a5)^(1/p.B5)
}
TotalMass <- function(traits, A) {
  ml <- LeafMass(traits$lma, A)
  ms <- SapwoodMass(traits$rho, A, Height(A))
  mb <- BarkMass(traits$rho, A, Height(A))
  mr <- RootMass(A)
  mh <- HeartwoodMass(traits$rho, A)
  return(ml + ms + mb + mr + mh)
}

# SOLVE HEIGHT FOR GIVEN MASS
Height.mt <- function(traits, mt) {
  # returns mass for given height
  TotalMass.wrap <- function(x, traits, mt) {
    TotalMass(traits, LeafArea(x)) - mt
  }
  y <- 0 * mt
  for (i in 1:length(mt)) {
    y[i] <- uniroot(TotalMass.wrap, c(0, 50), traits = traits, mt = mt[i])$root
  }
  return(y)
}

# OPTIMISE GROWTH RATE WRT TRAIT: 1 = LMA, 2= WOOD DENSITY
optForGrowth <- function(traits, h, env, Range, option = 1) {
  if (length(h) > 1) {
    cat("error, h must length 1")
  }
  if (length(env) > 1) {
    cat("error, env must length 1")
  }

  # wrapper function to pass to optimise
  dHdt.wrap <- function(x, traits, h, env, option) {
    if (option == 1) {
      traits$lma <- x
      XLAB <- "LMA (kg/m2)"
    }
    if (option == 2) {
      traits$rho <- x
      XLAB <- "RHO (kg/m3)"
    }

    dHdt(traits, h, env)
  }
  return(optimise(dHdt.wrap, Range, maximum = T, tol = 1e-06, traits = traits,
    h = h, env = env, option = option))
}

# CALCULATE WPLCP
WPLCP <- function(traits, h) {
  if (length(h) > 1) {
    cat("error, h must length 1")
  }

  if (Production(traits, h, env = 1) < 0)
    out <- NA else {
    # wrapper function to pass to optimise
    production.wrap <- function(x, traits, h) {
      Production(traits, h, env = x)
    }
    out <- uniroot(production.wrap, c(0, 1), traits = traits, h = h)$root
  }
  out
}

# HEIGHT GROWTH RATE
dHdt <- function(traits, h, env) {
  dHdA(LeafArea(h)) * dAdMt(traits, LeafArea(h)) * Production(traits, h, env) *
    (1 - ReproductiveAllocation(traits$hmat, h))
}

# MARGINAL COST OF LEAF AREA GROWTH
dMldA <- function(lma, A) {
  A * 0 + lma
}
dMsdA <- function(rho, A) {
  rho/p.theta * etac(p.eta) * (Height(A) + A * dHdA(A))
}
dMbdA <- function(rho, A) {
  p.b * dMsdA(rho, A)
}
dMhdA <- function(rho, A) {
  rho * p.a2 * p.B2 * A^(p.B2 - 1)
}
dMrdA <- function(A) {
  A * 0 + p.a3
}
dMtdA <- function(traits, A) {
  dMldA(traits$lma, A) + dMbdA(traits$rho, A) + dMsdA(traits$rho, A) + dMhdA(traits$rho,
    A) + dMrdA(A)
}
dAdMt <- function(traits, A) {
  1/dMtdA(traits, A)
}

# MARGINAL COST OF HEIGHT GROWTH
dMldH <- function(lma, h) {
  A <- LeafArea(h)
  dMldA(lma, A)/dHdA(A)
}
dMsdH <- function(rho, h) {
  A <- LeafArea(h)
  dMsdA(rho, A)/dHdA(A)
}
dMbdH <- function(rho, h) {
  A <- LeafArea(h)
  dMbdA(rho, A)/dHdA(A)
}
dMhdH <- function(rho, h) {
  A <- LeafArea(h)
  dMhdA(rho, A)/dHdA(A)
}
dMrdH <- function(h) {
  A <- LeafArea(h)
  dMrdA(A)/dHdA(A)
}

# reproductive allocation
ReproductiveAllocation <- function(hmat, h) {
  p.c_r1/(1 + exp(p.c_r2 * (1 - h/hmat)))
}

# production functions
dMtdt <- function(traits, h, env) {
  Production(traits, h, env) * (1 - ReproductiveAllocation(traits$hmat, h))
}

Production <- function(traits, h, env, print = 0) {
  A <- LeafArea(h)
  ms <- SapwoodMass(traits$rho, A, h)
  mb <- BarkMass(traits$rho, A, h)
  mr <- RootMass(A)
  Production.detail(traits, A, ms, mb, mr, env, print)
}

Production.detail <- function(traits, A, ms, mb, mr, env, print = 0) {
  if (print == 1) {
    cat("Assim = ", Assim(A, env), "\n")
    cat("Resp = ", Respiration(A, ms/traits$rho, mb/traits$rho, mr), "\n")
    cat("Turn = ", Turnover(traits, A * traits$lma, ms, mb, mr), "\n")
  }
  Assim(A, env) - Respiration(A, ms/traits$rho, mb/traits$rho, mr) - Turnover(traits,
    A * traits$lma, ms, mb, mr)
}

Assim <- function(A, env) {
  p.Y * p.c_bio * A * p.c_p1 * env/(p.c_p2 + env)
}

Respiration <- function(A, vs, vb, mr) {
  Respiration.leaf(A) + Respiration.sapwood(vs) + Respiration.bark(vb) + Respiration.root(mr)
}

Respiration.leaf <- function(A) {
  p.Y * p.c_bio * (p.c_Rl * p.n_area * A)
}
Respiration.sapwood <- function(vs) {
  p.Y * p.c_bio * p.c_Rs * vs
}
Respiration.bark <- function(vb) {
  p.Y * p.c_bio * 2 * p.c_Rs * vb
}
Respiration.root <- function(mr) {
  p.Y * p.c_bio * p.c_Rr * mr
}

Turnover <- function(traits, ml, ms, mb, mr) {
  Turnover.leaf(traits$lma, ml) + Turnover.sapwood(ms) + Turnover.bark(mb) +
    Turnover.root(mr)
}
Turnover.leaf <- function(lma, ml) {
  (p.a4 * lma^-p.B4) * ml
}
Turnover.sapwood <- function(ms) {
  0
}
Turnover.bark <- function(mb) {
  p.k_b * mb
}
Turnover.root <- function(mr) {
  p.k_r * mr
}


getLMAvHeightGrowth <- function(x, traits, h, env = 1) {

  nLines <- max(length(h), length(env))
  if (length(h) < nLines) {
    h <- rep(h[1], nLines)
  }
  if (length(env) < nLines) {
    env <- rep(env[1], nLines)
  }

  # solve height growth rate for env and height combination
  y <- matrix(0, length(x), nLines)
  for (i in 1:nLines) {
    for (j in 1:length(x)) {
      traits$lma <- x[j]
      y[j, i] <- dHdt(traits, h[i], env[i])
    }
  }
  y
}

getLMAvMaxShading <- function(x, traits, h = 1, option = 1, ...) {

  nLines <- max(length(h))
  if (length(h) < nLines) {
    h <- rep(h[1], nLines)
  }

  y <- matrix(0, length(x), nLines)
  for (i in 1:nLines) {
    for (j in 1:length(x)) {
      traits$lma <- x[j]
      y[j, i] <- WPLCP(traits, h[i])
    }
  }
  y
}
