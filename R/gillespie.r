#
is.wholenumber = function(x, tol = .Machine$double.eps^0.5)  abs(x - round(x)) < tol


hazard.part = function(sys, engine="R")
{
    engine = pmatch(engine, c("R","C"))

    check.system(sys)

    switch(engine,
    {
        # R implementation
        hp = numeric(sys$r)
        for (i in 1:sys$r) hp[i] = sum(lchoose(sys$X, sys$Pre[i,]))+sys$lmult[i]
        return(exp(hp))
    },
    {
        # C implementation
        out = .C("hazard_part_R",
                 as.integer(sys$s), 
                 as.integer(sys$r), 
                 as.integer(t(sys$Pre)), 
                 as.integer(t(sys$Post)), 
                 as.double(sys$lmult),
                 as.integer(sys$X), 

                 hp=double(sys$r))

        return(out$hp)
    })
}


#' Calculates the hazard for a stochastic chemical kinetic system
#' 
#' @param sys the stochastic chemical kinetic system
#' @param tau the time interval for the hazard
#' @param engine use 'R' or 'C' code
#' @return a list containing the hazard and the hazard part (hazard divided by rates)
#' @author Jarad Niemi \email{niemi@@iastate.edu}
#' @seealso \code{\link{tau_leap}}
#' @export hazard
#' @useDynLib tlpl
#'
hazard = function(sys, tau=1, engine="R")
{
    engine = pmatch(engine, c("R","C"))
    
    check.system(sys)

    switch(engine,
    {
        # R implementation
        hp = hazard.part(sys)
        return(list(h=hp*sys$theta,hp=hp))
    },
    {
        # C implementation
        out = .C("hazard_R",
                 as.integer(sys$s), 
                 as.integer(sys$r), 
                 as.integer(t(sys$Pre)), 
                 as.integer(t(sys$Post)), 
                 as.double(sys$lmult),
                 as.double(sys$theta), 
                 as.integer(sys$X), 
                 as.double(tau),

                 hp=double(sys$r), 
                 h= double(sys$r))

        return(list(h=out$h,hp=out$hp))
    })
}

update.species = function(sys, nr, engine="R")
{
    engine = pmatch(engine, c("R","C"))
    
    check.system(sys)

    switch(engine,
    {
        # R implementation
        return(as.numeric(sys$X + sys$stoich %*% nr))
    },
    {
        # C implementation
        out = .C("update_species_R",
                 as.integer(sys$s), 
                 as.integer(sys$r), 
                 as.integer(t(sys$Pre)), 
                 as.integer(t(sys$Post)), 
                 as.integer(nr), 

                 X=as.integer(sys$X))

        return(out$X)
    })

}


tau_leap_one_step = function(sys, tau=1, while.max=1000, engine="R")
{
    engine = pmatch(engine, c("R","C"))
    
    check.system(sys)
    stopifnot(tau>0, while.max>0)

    h = hazard(sys,tau,engine="R")$h*tau

    switch(engine,
    {
        # R implementation
        count = 0
        X = rep(-1,sys$s)
        while (any(X<0))
        {
            nr = rpois(sys$r,h)
            X  = update.species(sys,nr,engine="R")
            count = count + 1
            if (count > while.max) 
                stop("R:tau_leap_one_step: Too many unsuccessful simulation iterations.")
        }
        return(list(X=X,nr=nr))
    },
    {
        # C implementation
        out = .C("tau_leap_one_step_R",
                 as.integer(sys$s), 
                 as.integer(sys$r), 
                 as.integer(t(sys$Pre)), 
                 as.integer(t(sys$Post)), 
                 as.double(sys$lmult),
                 as.double(h), 
                 as.integer(while.max), 

                 nr=integer(sys$r), 
                 X=as.integer(sys$X))

        return(list(X=out$X, nr=out$nr))
    },
    {
        stop(paste("No 'engine' matching: ",engine,".\n")) 
    })

}



#' Performs tau-leaped simulations
#'
#' @param sys a list defining a stochastic chemical kinetic system
#' @param n an integer defining the number of time-points to simulate
#' @param tau a positive vector defining the times between observations
#' @param while.max at each time point the maximum number of simulations to try to ensure non-negativity of all species
#' @param engine use 'R' or 'C'
#' @return a list containing the species counts at each time point ('X') which is an (n+1) x s matrix and the number of transitions between each time point ('nr') which is an n x r matrix
#' @author Jarad Niemi \email{niemi@@iastate.edu}
#' @export tau_leap
#' @useDynLib tlpl
#'
tau_leap = function(sys, n=1, tau=1, while.max=1000, engine="R")
{
    engine = pmatch(engine, c("R","C"))
   
    sys$lmult = log(sys$mult) 
    check.system(sys)
    stopifnot(tau>0, while.max>0, n>0)
    if (length(tau)==1) tau=rep(tau,n)
    stopifnot(length(tau)==n)

    switch(engine,
    {
        # R implementation
        X = matrix(sys$X, n+1, sys$s, byrow=T)
        nr = matrix(NA, n, sys$r)
        for (i in 1:n) { 
            sys$X = X[i,]
            tmp = tau_leap_one_step(sys,tau[i],while.max,engine="R")
            X[i+1,] = tmp$X
            nr[i,]  = tmp$nr
        }
        return(list(X=X,nr=nr))
    },
    {
        # C implementation
        out = .C("tau_leap_R",
                 as.integer(sys$s), 
                 as.integer(sys$r), 
                 as.integer(t(sys$Pre)), 
                 as.integer(t(sys$Post)), 
                 as.double(sys$lmult),
                 as.double(sys$theta), 
                 as.double(tau), 
                 as.integer(n), 
                 as.integer(while.max),

                 nr=integer(n*sys$r), 
                 X=as.integer(rep(sys$X,n+1)))

        return(list(X=matrix(out$X, n+1, sys$s, byrow=T), nr=matrix(out$nr, n, sys$r, byrow=T)))    
    },
    {
        stop(paste("No 'engine' matching: ",engine,".\n", sep="")) 
    })
}




gillespie = function(sys, n, tau) 
{
    # Error checking
    check.system(sys)
    stopifnot(tau>0, n>0)

    # if tau is constant
    if (length(tau)==1) tau=rep(tau,n)

    # 
    if (!is.wholenumber(n)) 
    {
        warning("Since n is not a whole number, using round(n) instead.")
        n = round(n)
    }

    out = .C("gillespie_R",
             as.integer(sys$s), as.integer(sys$r), as.integer(t(sys$Pre)), as.integer(t(sys$Post)), 
             as.double(sys$theta), as.double(tau), as.integer(n),
             X=as.integer(rep(sys$X,n+1)))
    return(matrix(out$X, n+1, sys$s, byrow=T))
}

