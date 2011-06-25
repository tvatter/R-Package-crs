## $Id: radial_constrained_second_partial.R,v 1.1 2011/06/25 14:14:00 jracine Exp jracine $

## Code to conduct restricted regression splines on evaluation
## data. Presumes continuous regressors, accepts an arbitrary number
## of regressors, and accepts arbitrary derivative restrictions.

rm(list=ls())

## Parameters to be set.

set.seed(12345)

n <- 1000
n.eval <- 50

x.min <- -5
x.max <- 5

## These will need to be modified if/when you modify Amat and bvec

lower <- 0
upper <- 10^6

## Load libraries

library(crs)
library(quadprog)

## IMPORTANT - you must be careful to NOT read data from environment -
## this appears to work - create a data frame.

## IMPORTANT - code that follows presumes y is the first variable in
## the data frame and all remaining variables are regressors used for
## the estimation.

## Generate a DGP, or read in your own data and create y, x1,
## etc. When you change this by adding or removing variables you need
## to change `data', `rm(...)', and `bw <- ...'. After that all code
## will need no modification.

x1 <- runif(n,x.min,x.max)
x2 <- runif(n,x.min,x.max)

y <- sin(sqrt(x1^2+x2^2))/sqrt(x1^2+x2^2) + rnorm(n,sd=.1)

data.train <- data.frame(y,x1,x2)

rm(y,x1,x2)

x1.seq <- seq(x.min,x.max,length=n.eval)
x2.seq <- seq(x.min,x.max,length=n.eval)
data.eval <- data.frame(y=0,expand.grid(x1=x2.seq,x2=x2.seq))

model.unres <- crs(y~x1+x2,
                   deriv=2,
                   basis="tensor",
                   data=data.train,
                   nmulti=5)

model.gradient.unres <- model.unres$deriv.mat

summary(model.unres)

## Start from uniform weights equal to 1/n. If constraints are
## non-binding these are optimal.

p <- rep(1/n,n)
Dmat <- diag(1,n,n)
dvec <- as.vector(p)

## If you wish to alter the constraints, you need to modify Amat and
## bvec.

## Create Aymat for jth regressor calling the Aymat.R code and
## function

## Evaluation data...

## Generate the estimated model computed for the evaluation data. Note
## - we need to premultiply the weights by n and each column must be
## multiplied by y

## For mean the following works and is identical to that below, but
## for derivatives you need to use prod.spline

## B <- model.matrix(model.unres$model.lm)

source("~/R/crs/R/spline.R")

B <- prod.spline(x=data.train[,-1],
                 K=cbind(model.unres$degree,model.unres$segments),
                 basis=model.unres$basis)

B.x1 <- prod.spline(x=data.train[,-1],
                 K=cbind(model.unres$degree,model.unres$segments),
                 basis=model.unres$basis,
                 deriv.index=1,
                 deriv=2)

Aymat.res.x1 <- n*t(t(B.x1%*%solve(t(B)%*%B)%*%t(B))*data.train$y)

B.x2 <- prod.spline(x=data.train[,-1],
                 K=cbind(model.unres$degree,model.unres$segments),
                 basis=model.unres$basis,
                 deriv.index=2,
                 deriv=2)

Aymat.res.x2 <- n*t(t(B.x2%*%solve(t(B)%*%B)%*%t(B))*data.train$y)


## Here is Amat

Amat <- t(rbind(rep(1,n),
                Aymat.res.x1,
                -Aymat.res.x1,
                Aymat.res.x2,
                -Aymat.res.x2))

## Conserve memory

rm(B,B.x1,B.x2,Aymat.res.x1,Aymat.res.x2)

## Here is bvec

bvec <- c(0,
          (rep(lower,n.eval)-model.gradient.unres[,1]),
          (model.gradient.unres[,1]-rep(upper,n.eval)),
          (rep(lower,n.eval)-model.gradient.unres[,2]),
          (model.gradient.unres[,2]-rep(upper,n.eval)))


## Solve the quadratic programming problem

QP.output <- solve.QP(Dmat=Dmat,dvec=dvec,Amat=Amat,bvec=bvec,meq=1)

## No longer needed...

rm(Amat,bvec,Dmat,dvec)

## Get the solution and update the uniform weights

w.hat <- QP.output$solution

p.updated <- p + w.hat

## Now estimate the restricted model

data.trans <- data.frame(y=p.updated*n*data.train$y,data.train[,2:ncol(data.train)])
names(data.trans) <- names(data.train) ## Necessary when there is only 1 regressor
model.res <- crs(y~x1+x2,cv="none",
                 degree=model.unres$degree,
                 segments=model.unres$segments,
                 basis=model.unres$basis,                                  
                 data=data.trans,
                 deriv=1)

## That's it.

## Plot the unrestricted and restricted fits

fitted.unres <- matrix(predict(model.unres,newdata=data.eval), n.eval, n.eval)
fitted.res <- matrix(predict(model.res,newdata=data.eval), n.eval, n.eval)

## Next, create a 3D perspective plot of the PDF f

ylim <- c(min(fitted(model.unres),max(fitted(model.unres))))

zlim <- c(min(fitted(model.unres)),max(fitted(model.unres)))

par(mfrow=c(1,2))

persp(x1.seq, x2.seq,
      fitted.unres,
      main="Unconstrained Regression Spline",
      col="lightblue",
      ticktype="detailed", 
      ylab="X2",
      xlab="X1",
      zlim=zlim,
      zlab="Conditional Expectation",
      theta=300,
      phi=30)

persp(x1.seq, x2.seq,
      fitted.res,
      main="Constrained Regression Spline",
      col="lightblue",
      ticktype="detailed", 
      ylab="X2",
      xlab="X1",
      zlim=zlim,
      zlab="Conditional Expectation",
      theta=300,
      phi=30)
