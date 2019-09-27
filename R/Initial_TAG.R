initial.TAG <- function(y, X,  Candi.lambda= seq(from=-2, to=2,by=0.5),
                         Adj.omega = TRUE, nug=0.001,
                         nbasis=10, rannum=20, big=FALSE, nsub=31, method.1d = "DiceKriging"){

  d <- ncol(X)
  n <- nrow(X)
  parini <- matrix(0,ncol=2,nrow=ncol(X))
  dat <- data.frame(y,X)
  colnames(dat) <- c("Y.t", paste0("x",1:d))
  ntemp=nsub
  score.v <- rep(0,length=length( Candi.lambda))
  for(ind in 1:length( Candi.lambda)){
    lam =  Candi.lambda[ind]
    if(lam == 0){
      Y.t <- log(y)
      J <- sum(log(1/y))
    }else{
      Y.t <- (y^(lam) - 1)/lam
      J <- sum(log(y^(lam - 1)))
    }
    dat[,1] <- Y.t
    if(big == TRUE){
      b <- bam(as.formula(paste("Y.t ~ ",paste0("s(x",1:d,", k=",nbasis,")", collapse="+"))), data=dat)
    }else{
      b <- gam(as.formula(paste("Y.t ~ ",paste0("s(x",1:d,", k=",nbasis,")", collapse="+"))), data=dat)
    }
    score.v[ind] <- b$gcv.ubre

    sigma.v <- sqrt(mean((b$residuals)^2))
    score.v[ind] <- -J + n*log(sigma.v)
  }

  lam <-  Candi.lambda[which.min(score.v)]
  if(lam == 0){
    Y.t <- log(y)
    J <- sum(log(1/y))
  }else{
    Y.t <- (y^(lam) - 1)/lam
    J <- sum(log(y^(lam - 1)))
  }

  ntemp <- ntemp - 1
  dat[,1] <- Y.t
  b <- bam(as.formula(paste("Y.t ~ ",paste0("s(x",1:d,", k=",nbasis,")", collapse="+"))),data=dat)
  Mat <- predict.gam(b, type = "terms")
  parini[, 1] <- apply(Mat,2,var)
  newd <- matrix(rep(c(0:ntemp)/ntemp,d), byrow=FALSE, ncol=d,nrow=(ntemp+1))
  newd <- as.data.frame(newd)
  colnames(newd) <- paste0("x",1:d)
  pred <- predict.gam(b, newd, type="terms")

  omega.new <- parini[,1]/sum(parini[,1])
  if(Adj.omega == TRUE){
    eta <- 1-(1/n)
    for(ind in 1:d){
      omega.new[ind]  <- eta*omega.new[ind] + (1-eta)*(1/d)
    }
  }

  if(method.1d == "DiceKriging"){
    for(ind in 1:d){
      temp.m <- km(formula=~1, design=as.matrix(newd[,ind]), response=pred[,ind], covtype="gauss", nugget = nug, multistart = rannum)
      parini[ind,2] <- sqrt(2*(coef(temp.m)$range^2))
    }
  }else if(method.1d == "mlegp"){
    for(ind in 1:d){
      parini[ind,2] <- 1/sqrt(mlegp(newd[,ind], pred[,ind], nugget=nug, nugget.known = 0)$beta)
    }
  }else{
    stop("Please Specify method.1d = 'DiceKriging' or 'mlegp'")
  }

  if(summary(b)$r.sq < 0){
    rsq <- 1 - sum(b$residuals^2)/(sum((log(y)-mean(log(y)))^2))
  }else{
    rsq <- summary(b)$r.sq
  }

  obj <- list(omega = omega.new, s = parini[,2], lambda=lam,
              delta = log(((1/rsq) - 1), base=10), y = y, X = X)
  class(obj) <- "initial.TAG"
  return(obj)

}