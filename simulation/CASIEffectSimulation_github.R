###############################################################
# Libraries
###############################################################

library(dplyr)
library(tidyr)

###############################################################
# Bring data and subset to complete cases & relevant vars
###############################################################

casi.raw<-read.csv('./simulation/casi_apic.csv')

###############################################################
# Subset population to those with potential matches
###############################################################

diff.start <- 10
diff.end <- - 30

ids<-data.frame()
for (i in 1:length(casi.raw$subjectid)){

  id <- casi.raw$subjectid[i]

  dPlacebo <- casi.raw[casi.raw$subjectid==id,]
  dTreat <- casi.raw[! casi.raw$subjectid == id,]

  i1 <- abs(dPlacebo$physician.severity.scale.scr-dTreat$physician.severity.scale.scr)<=diff.start  ## baseline within 10
  i2 <- dPlacebo$physician.severity.scale.v6 >= dTreat$physician.severity.scale.v6 # end of study sev is bigger in the placebo
  i3 <- (dTreat$physician.severity.scale.v6-dPlacebo$physician.severity.scale.v6)>=diff.end  # end of study sev: trt-placebo >= -30

  di <- data.frame(cbind(i1, i2, i3))
  ind <- sum((di$i1+di$i2+di$i3)==3)

  thisRow <-data.frame(subjectid=as.character(id), nMatches=ind)
  ids<-rbind(ids,thisRow)
}

### subset population
goodids<- ids[ids$nMatches>0,]$subjectid
casi <- casi.raw[casi.raw$subjectid %in% goodids,]

###############################################################
# Set parameters for simulation
###############################################################

sim.count <- 1000 #number of simulations we want to run
sim.size <- 0 #number of simulations meeting our criteria (starts at 0)
sim.tot <- 0 #total number of simulations (starts at 0)
#group.size<-250
start.time <- proc.time()
effects<-NULL
all <- NULL


###############################################################
# Run simulation
###############################################################

trtfor <- function(group.size=50){

  effects<-NULL
  all <- NULL

  while(sim.size < sim.count){

    #pick your placebo group entirely at random
    placebo <- casi[sample(nrow(casi),group.size,replace=T),]

    #Pick your treatement group based on given criteria
    treatment <- data.frame()
    treat.n<-1

    while(treat.n<=group.size){

      placebo.severity<-placebo[treat.n,]$physician.severity.scale.v6 #get the score in the placebo group

      #pick a person with end of study severity <= the corresponding placebo participant
      matches<-casi[casi$physician.severity.scale.v6<=placebo.severity,] #find all the matches for that person

      #Make sure the effect isn't toooo big
      matches<-matches[(matches$physician.severity.scale.v6-placebo.severity)>=diff.end,]

      #Pick a person with similar baseline score
      placebo.severity.baseline<-placebo[treat.n,]$physician.severity.scale.scr #get the score in the placebo group
      matches<-matches[abs(matches$physician.severity.scale.scr-placebo.severity.baseline)<=diff.start,]

      matches<-matches[matches$subjectid != placebo[treat.n,]$subjectid,]#can't match yourself

      # if that person has a match, move on
      if(dim(matches)[1]>0){
        match<-matches[sample(nrow(matches),1),]
        treatment<-rbind(treatment,match)
        treat.n<-treat.n+1
      }else{
        print(paste0("No match found for ",placebo[treat.n,]$subjectid))
      }
    }

    success<-1 #assume we succeeded unless we fail a test

    ### Test for difference at baseline
    baseline.test <- t.test(placebo$physician.severity.scale.scr,treatment$physician.severity.scale.scr)
    if(baseline.test$p.value<=0.10) success<-0

    ### Test that effect is between 8 and 12
    change.placebo <- placebo$physician.severity.scale.v6 - placebo$physician.severity.scale.scr
    change.treatment <- treatment$physician.severity.scale.v6 - treatment$physician.severity.scale.scr
    effect.sev = mean(change.treatment)-mean(change.placebo)

    p1 <- t.test(change.placebo, change.treatment, alternative='less', mu=8)$p.val   # test that diff is greater than 8
    p2 <- t.test(change.placebo, change.treatment, alternative='greater', mu=12)$p.val  # test that diff is less than 12

    if (p1<=0.10 | p2<=0.10) success <-0


    ### Count the simulation/success
    sim.tot<-sim.tot+1
    sim.size<-sim.size+success

    ### Find corresponding CASI effect
    change.placebo.casi <- mean(placebo$casi.v6 - placebo$casi.scr)
    change.treatment.casi <- mean(treatment$casi.v6 - treatment$casi.scr)
    effect.casi <- change.treatment.casi - change.placebo.casi

    ### Keep effect as long as it meets allt he requirements
    if(success) effects<-rbind(effects,
                               data.frame(sim.n=sim.size,group.size=group.size,effect.casi=effect.casi,effect.sev=effect.sev))
  }

  all <- rbind(all, effects)
  return(all)
}

set.seed(5378)
a50 <- trtfor(group.size=50)

set.seed(5378)
a100 <- trtfor(group.size=100)

set.seed(5378)
a150 <- trtfor(group.size=150)

set.seed(5378)
a200 <- trtfor(group.size=200)

set.seed(5378)
a250 <- trtfor(group.size=250)

set.seed(5378)
a500 <- trtfor(group.size=500)

set.seed(5378)
a1000 <- trtfor(group.size=1000)

final <- rbind(a50,a100, a150, a200, a250, a500, a1000)

### result of simulation with 250 per arm
summarise(a250, med = median( effect.casi  ), q25 = quantile( effect.casi  , prob=0.025), q75=quantile( effect.casi  , prob=0.975))


print(paste0("Tried ",sim.tot," simulations with ",group.size," people to get ",sim.count," successes"))
proc.time()-start.time

### output results
write.csv(final,"CASIEffectSimulation.csv" )



r <- final %>%
  gather(var, val, effect.casi:effect.sev) %>%
  group_by(group.size, var) %>%
  summarise(med = median(val), q25 = quantile(val, prob=0.025), q75=quantile(val, prob=0.975)) %>% 
  filter(var=='effect.casi')

### output summary
write.csv(r,"CASIEffectSimulation_summary.csv", row.names=F)




