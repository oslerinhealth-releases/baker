#' Fit nested partially-latent class model (low-level)
#'
#' @details This function prepares data, specifies hyperparameters in priors 
#' (true positive rates and etiology fractions), initializes the posterior
#' sampling chain, writes the model file (for JAGS or WinBUGS with slight differences
#' in syntax), and fits the model. Features:
#' \itemize{
#' \item no regression;
#' \item no nested
#' }
#' If running JAGS on windows, please go to control panel to add the directory to
#' jags into ENVIRONMENTAL VARIABLE! 
#'
#' @inheritParams nplcm
#' @return BUGS fit results.
#' 
#' @seealso \link{write_model_NoReg} for constructing .bug model file; This function
#' then put it in the folder \code{mcmc_options$bugsmodel.dir}.
#' 
#' @family model fitting functions 
#' 
#' @export
nplcm_fit_NoReg<-
  function(data_nplcm,model_options,mcmc_options){
    # Record the settings of current analysis:
    cat("==[baker] Results stored in: ==","\n",mcmc_options$result.folder,"\n")
    #model_options:
    dput(model_options,file.path(mcmc_options$result.folder,"model_options.txt"))
    #mcmc_options:
    dput(mcmc_options,file.path(mcmc_options$result.folder,"mcmc_options.txt"))
    
    # read in data:
    Mobs <- data_nplcm$Mobs
    Y    <- data_nplcm$Y
    
    # read in options:
    likelihood       <- model_options$likelihood
    use_measurements <- model_options$use_measurements
    prior            <- model_options$prior
    
    #####################################################################
    # 1. prepare data (including hyper-parameters):
    #####################################################################
    
    # sample sizes:
    Nd      <- sum(Y==1)
    Nu      <- sum(Y==0)
    
    # lengths of vectors:
    cause_list  <- likelihood$cause_list
    Jcause      <- length(cause_list)
    
    in_data <- in_init <- out_parameter <- NULL
    
    if ("BrS" %in% use_measurements){
      #
      # BrS measurement data: 
      #
      JBrS_list  <- lapply(Mobs$MBS,ncol)
      # mapping template (by `make_template` function):
      patho_BrS_list    <- lapply(Mobs$MBS,colnames)
      template_BrS_list <- lapply(patho_BrS_list,make_template,cause_list)
      for (s in seq_along(template_BrS_list)){
        if (sum(template_BrS_list[[s]])==0){
          warning(paste0("==[baker] Bronze-standard slice ", names(data_nplcm$Mobs$MBS)[s], " has no measurements informative of the causes specified in 'cause_list', except 'NoA'! 
                         Please check if you need this measurement slice columns correspond to causes other than 'NoA'.=="))  
        }
      }
      
      MBS.case_list <- lapply(Mobs$MBS,"[",which(Y==1),TRUE,drop=FALSE)
      MBS.ctrl_list <- lapply(Mobs$MBS,"[",which(Y==0),TRUE,drop=FALSE)
      MBS_list <- list()
      for (i in seq_along(MBS.case_list)){
        MBS_list[[i]]      <- rbind(MBS.case_list[[i]],MBS.ctrl_list[[i]])
      }
      names(MBS_list)   <- names(MBS.case_list)
      
      single_column_MBS <- which(lapply(MBS_list,ncol)==1)
      
      for(i in seq_along(JBrS_list)){
        assign(paste("JBrS", i, sep = "_"), JBrS_list[[i]])    
        assign(paste("MBS", i, sep = "_"), as.matrix_or_vec(MBS_list[[i]])) 
        assign(paste("templateBS", i, sep = "_"), as.matrix_or_vec(template_BrS_list[[i]]))   
      }
      
      # setup groupwise TPR for BrS:
      BrS_TPR_strat <- FALSE
      prior_BrS     <- model_options$prior$TPR_prior$BrS
      parsed_model <- assign_model(model_options,data_nplcm)
      if (parsed_model$BrS_grp){
        BrS_TPR_strat <- TRUE
        for(i in seq_along(JBrS_list)){
          assign(paste("GBrS_TPR", i, sep = "_"),  length(unique(prior_BrS$grp)))    
          assign(paste("BrS_TPR_grp", i, sep = "_"),  prior_BrS$grp)    
        }
      }
      
      # add GBrS_TPR_1, or 2 if we want to index by slices:
      for (i in seq_along(JBrS_list)){
        if (!is.null(prior_BrS$grp)){ # <--- need to change to list if we have multiple slices.
          assign(paste("GBrS_TPR", i, sep = "_"), length(unique(prior_BrS$grp))) # <--- need to change to depending on i if grp change wrt specimen.
        }
        if (is.null(prior_BrS$grp)){ # <--- need to change to list if we have multiple slices.
          assign(paste("GBrS_TPR", i, sep = "_"), 1)
        }
      }
      
      # set BrS measurement priors: 
      # hyper-parameters for sensitivity:
      
      alpha_mat <- list() # dimension for slices.
      beta_mat  <- list()
      
      for(i in seq_along(JBrS_list)){
        
        if (likelihood$k_subclass[i] == 1){BrS_tpr_prior <- set_prior_tpr_BrS_NoNest(i,model_options,data_nplcm)}
        if (likelihood$k_subclass[i] > 1) {BrS_tpr_prior <- set_prior_tpr_BrS_NoNest(i,model_options,data_nplcm)}
        
        GBrS_TPR_curr <- eval(parse(text = paste0("GBrS_TPR_",i)))
        alpha_mat[[i]] <- matrix(NA, nrow=GBrS_TPR_curr,ncol=JBrS_list[[i]])
        beta_mat[[i]]  <- matrix(NA, nrow=GBrS_TPR_curr,ncol=JBrS_list[[i]])
        
        colnames(alpha_mat[[i]]) <- patho_BrS_list[[i]]
        colnames(beta_mat[[i]]) <- patho_BrS_list[[i]]
        
        for (g in 1:GBrS_TPR_curr){
          alpha_mat[[i]][g,] <- unlist(BrS_tpr_prior[[1]][[g]]$alpha)
          beta_mat[[i]][g,]  <- unlist(BrS_tpr_prior[[1]][[g]]$beta)
        }
        
        if (GBrS_TPR_curr>1){
          assign(paste("alphaB", i, sep = "_"), alpha_mat[[i]])      # <---- input BrS TPR prior here.
          assign(paste("betaB", i, sep = "_"),  beta_mat[[i]])    
        }else{
          assign(paste("alphaB", i, sep = "_"), c(alpha_mat[[i]]))   # <---- input BrS TPR prior here.
          assign(paste("betaB", i, sep = "_"),  c(beta_mat[[i]]))    
        }
      }
      names(alpha_mat) <- names(beta_mat)<- names(Mobs$MBS)
      
      if (!BrS_TPR_strat){
        # summarize into one name (for all measurements):
        if (length(single_column_MBS)==0){
          # if all slices have >2 columns:
          in_data       <- c(in_data,"Nd","Nu","Jcause","alphaEti",
                             paste("JBrS",1:length(JBrS_list),sep="_"),
                             paste("MBS",1:length(JBrS_list),sep="_"),
                             paste("templateBS",1:length(JBrS_list),sep="_")
                             # paste("alphaB",1:length(JBrS_list),sep="_"),
                             # paste("betaB",1:length(JBrS_list),sep="_")
          )
        } else {
          # if there exist slices with 1 column:
          in_data       <- c(in_data,"Nd","Nu","Jcause","alphaEti",
                             paste("JBrS",1:length(JBrS_list),sep="_")[-single_column_MBS], # <---- no need to iterate in .bug file for a slice with one column.
                             paste("MBS",1:length(JBrS_list),sep="_"),
                             paste("templateBS",1:length(JBrS_list),sep="_")
                             # paste("alphaB",1:length(JBrS_list),sep="_"),
                             # paste("betaB",1:length(JBrS_list),sep="_")
          )
        }
      } else{
        # summarize into one name (for all measurements):
        if (length(single_column_MBS)==0){
          # if all slices have >2 columns:
          in_data       <- c(in_data,"Nd","Nu","Jcause","alphaEti",
                             paste("JBrS",1:length(JBrS_list),sep="_"),
                             paste("GBrS_TPR",1:length(JBrS_list),sep="_"),   # <-- added for TPR strata.
                             paste("BrS_TPR_grp",1:length(JBrS_list),sep="_"),# <-- added for TPR strata.
                             paste("MBS",1:length(JBrS_list),sep="_"),
                             paste("templateBS",1:length(JBrS_list),sep="_")
                             # paste("alphaB",1:length(JBrS_list),sep="_"),
                             # paste("betaB",1:length(JBrS_list),sep="_")
          )
        } else {
          # if there exist slices with 1 column:
          in_data       <- c(in_data,"Nd","Nu","Jcause","alphaEti",
                             paste("JBrS",1:length(JBrS_list),sep="_")[-single_column_MBS], # <---- no need to iterate in .bug file for a slice with one column.
                             paste("GBrS_TPR",1:length(JBrS_list),sep="_"),   # <-- added for TPR strata.
                             paste("BrS_TPR_grp",1:length(JBrS_list),sep="_"),# <-- added for TPR strata.
                             paste("MBS",1:length(JBrS_list),sep="_"),
                             paste("templateBS",1:length(JBrS_list),sep="_")
                             # paste("alphaB",1:length(JBrS_list),sep="_"),
                             # paste("betaB",1:length(JBrS_list),sep="_")
          )
        }
        
      }
      
      #
      # hyper-parameters:
      #
      
      # Set BrS measurement priors:
      # hyperparameter for sensitivity (can add for specificity if necessary): 
      
      for (s in seq_along(Mobs$MBS)){
        #if (likelihood$k_subclass[s] == 1){BrS_tpr_prior <- set_prior_tpr_BrS_NoNest(s,model_options,data_nplcm)}
        #if (likelihood$k_subclass[s] > 1){BrS_tpr_prior <- set_prior_tpr_BrS_NoNest(s,model_options,data_nplcm)}
        
        #assign(paste("alphaB", s, sep = "_"), BrS_tpr_prior[[1]]$alpha)     # <---- input BrS TPR prior here.
        #assign(paste("betaB", s, sep = "_"),  BrS_tpr_prior[[1]]$beta)    
        
        if (likelihood$k_subclass[s]==1){
          out_parameter <- c(out_parameter,paste(c("thetaBS","psiBS"), s, sep="_"))  
        }else{  # <--- TPR stratification for BrS data not implemented for K>1.
          assign(paste("K", s, sep = "_"), likelihood$k_subclass[s])
          in_data       <- unique(c(in_data,paste0("K_",s))) # <---- No. of subclasses for this slice.
          out_parameter <- unique(c(out_parameter,
                                    paste(c("ThetaBS","PsiBS","Lambda","Eta","alphadp0","alphadp0_case"),s,sep="_")
          ))
        }
      }
      
      #
      # collect in_data, out_parameter together:
      #
      in_data       <- c(in_data,
                         paste("alphaB",1:length(JBrS_list),sep="_"),
                         paste("betaB",1:length(JBrS_list),sep="_")
      )
      out_parameter <- c(out_parameter,"pEti")
    }
    
    
    if ("SS" %in% use_measurements){
      #
      # 2. SS measurement data: 
      #
      
      JSS_list   <- lapply(Mobs$MSS,ncol)
      
      # mapping template (by `make_template` function):
      patho_SS_list <- lapply(Mobs$MSS,colnames)
      template_SS_list <- lapply(patho_SS_list,make_template,cause_list)
      
      for (s in seq_along(template_SS_list)){
        if (sum(template_SS_list[[s]])==0){
          warning(paste0("==[baker] Silver-standard slice ", names(data_nplcm$Mobs$MSS)[s], 
                         " has no measurements informative of the causes! Please check if measurements' columns correspond to causes.==\n"))  
        }
      }
      
      MSS_list <- lapply(Mobs$MSS,"[",which(Y==1),TRUE,drop=FALSE)
      
      single_column_MSS <- which(lapply(MSS_list,ncol)==1)
      
      for(i in seq_along(JSS_list)){
        assign(paste("JSS", i, sep = "_"), JSS_list[[i]])    
        assign(paste("MSS", i, sep = "_"), as.matrix_or_vec(MSS_list[[i]])) 
        assign(paste("templateSS", i, sep = "_"), as.matrix_or_vec(template_SS_list[[i]]))   
      }
      
      # setup groupwise TPR for SS:
      SS_TPR_strat <- FALSE
      prior_SS     <- model_options$prior$TPR_prior$SS
      parsed_model <- assign_model(model_options,data_nplcm)
      if (parsed_model$SS_grp){
        SS_TPR_strat <- TRUE
        for(i in seq_along(JSS_list)){
          assign(paste("GSS_TPR", i, sep = "_"),  length(unique(prior_SS$grp)))    
          assign(paste("SS_TPR_grp", i, sep = "_"),  prior_SS$grp)    
        }
      }
      
      # add GSS_TPR_1, or 2 if we want to index by slices:
      for (i in seq_along(JSS_list)){
        if (!is.null(prior_SS$grp)){ # <--- need to change to list if we have multiple slices.
          assign(paste("GSS_TPR", i, sep = "_"), length(unique(prior_SS$grp))) # <--- need to change to depending on i if grp change wrt specimen.
        }
        if (is.null(prior_SS$grp)){ # <--- need to change to list if we have multiple slices.
          assign(paste("GSS_TPR", i, sep = "_"), 1)
        }
      }
      
      
      SS_tpr_prior <- set_prior_tpr_SS(model_options,data_nplcm)
      
      # set SS measurement priors: 
      # hyper-parameters for sensitivity:
      
      alpha_mat <- list() # dimension for slices.
      beta_mat  <- list()
      
      for(i in seq_along(JSS_list)){
        
        GSS_TPR_curr <- eval(parse(text = paste0("GSS_TPR_",i)))
        alpha_mat[[i]] <- matrix(NA, nrow=GSS_TPR_curr,ncol=JSS_list[[i]])
        beta_mat[[i]]  <- matrix(NA, nrow=GSS_TPR_curr,ncol=JSS_list[[i]])
        
        colnames(alpha_mat[[i]]) <- patho_SS_list[[i]]
        colnames(beta_mat[[i]]) <- patho_SS_list[[i]]
        
        for (g in 1:GSS_TPR_curr){
          alpha_mat[[i]][g,] <- unlist(SS_tpr_prior[[i]][[g]]$alpha)
          beta_mat[[i]][g,]  <- unlist(SS_tpr_prior[[i]][[g]]$beta)
        }
        
        if (GSS_TPR_curr>1){
          assign(paste("alphaS", i, sep = "_"), alpha_mat[[i]])    # <---- input SS TPR prior here.
          assign(paste("betaS", i, sep = "_"),  beta_mat[[i]])    
        }else{
          assign(paste("alphaS", i, sep = "_"), c(alpha_mat[[i]]))   # <---- input SS TPR prior here.
          assign(paste("betaS", i, sep = "_"),  c(beta_mat[[i]]))    
        }
      }
      names(alpha_mat) <- names(beta_mat)<- names(Mobs$MSS)
      
      if (!SS_TPR_strat){
        if (length(single_column_MSS)==0){
          # summarize into one name (for all measurements):
          in_data       <- unique(c(in_data,"Nd","Jcause","alphaEti",
                                    paste("JSS",1:length(JSS_list),sep="_"),
                                    paste("MSS",1:length(JSS_list),sep="_"),
                                    paste("templateSS",1:length(JSS_list),sep="_"),
                                    paste("alphaS",1:length(JSS_list),sep="_"),   
                                    paste("betaS",1:length(JSS_list),sep="_")))
        } else{
          in_data       <- unique(c(in_data,"Nd","Nu","Jcause","alphaEti",
                                    paste("JSS",1:length(JSS_list),sep="_")[-single_column_MSS],
                                    paste("MSS",1:length(JSS_list),sep="_"),
                                    paste("templateSS",1:length(JSS_list),sep="_"),
                                    paste("alphaS",1:length(JSS_list),sep="_"),
                                    paste("betaS",1:length(JSS_list),sep="_")))
        }
      }else {
        if (length(single_column_MSS)==0){
          # summarize into one name (for all measurements):
          in_data       <- unique(c(in_data,"Nd","Jcause","alphaEti",
                                    paste("JSS",1:length(JSS_list),sep="_"),
                                    paste("GSS_TPR",1:length(JSS_list),sep="_"),    # <-- added for TPR strata.
                                    paste("SS_TPR_grp",1:length(JSS_list),sep="_"), # <-- added for TPR strata.
                                    paste("MSS",1:length(JSS_list),sep="_"),
                                    paste("templateSS",1:length(JSS_list),sep="_"),
                                    paste("alphaS",1:length(JSS_list),sep="_"),   
                                    paste("betaS",1:length(JSS_list),sep="_")))
        } else{
          in_data       <- unique(c(in_data,"Nd","Nu","Jcause","alphaEti",
                                    paste("JSS",1:length(JSS_list),sep="_")[-single_column_MSS],
                                    paste("GSS_TPR",1:length(JSS_list),sep="_"),   # <-- added for TPR strata.
                                    paste("SS_TPR_grp",1:length(JSS_list),sep="_"),# <-- added for TPR strata.
                                    paste("MSS",1:length(JSS_list),sep="_"),
                                    paste("templateSS",1:length(JSS_list),sep="_"),
                                    paste("alphaS",1:length(JSS_list),sep="_"),
                                    paste("betaS",1:length(JSS_list),sep="_")))
        }
        
      }
      out_parameter <- unique(c(out_parameter, paste("thetaSS", seq_along(JSS_list), sep = "_"),
                                "pEti"))
    }
    
    #####################################
    # set up initialization function:
    #####################################
    if ("BrS" %in% use_measurements & !("SS" %in% use_measurements)){
      in_init       <-   function(){
        res <- list()
        for (s in seq_along(Mobs$MBS)){
          res_curr <- list()
          if (likelihood$k_subclass[s]==1){
            #res_curr[[1]] <- stats::rbeta(JBrS_list[[s]],1,1)
            
            GBrS_TPR_curr <- eval(parse(text = paste0("GBrS_TPR_",s)))
            if (GBrS_TPR_curr==1){
              res_curr[[1]] <- stats::rbeta(JBrS_list[[s]],1,1)
            } else{
              res_curr[[1]] <- matrix(stats::rbeta(GBrS_TPR_curr*JBrS_list[[s]],1,1),
                                      nrow=GBrS_TPR_curr,ncol=JBrS_list[[s]])
              if (JBrS_list[[s]]==1){
                res_curr[[1]] <- c(res_curr[[1]])
              }
            }
            res_curr[[2]] <- stats::rbeta(JBrS_list[[s]],1,1)
            names(res_curr) <- paste(c("thetaBS","psiBS"),s,sep="_")
            res <- c(res,res_curr)
          }
          if (likelihood$k_subclass[s] > 1){
            K_curr <- likelihood$k_subclass[s]
            res_curr[[1]] <- c(rep(.5,K_curr-1),NA)
            res_curr[[2]] <- c(rep(.5,K_curr-1),NA)
            # for different Eta's:
            #             res_curr[[2]] <- cbind(matrix(rep(.5,Jcause*(K_curr-1)),
            #                                           nrow=Jcause,ncol=K_curr-1),
            #                                    rep(NA,Jcause))
            res_curr[[3]] <- 1
            res_curr[[4]] <- 1 #<---- added together with 'alphadp0_case' below.
            
            names(res_curr) <- paste(c("r0","r1","alphadp0","alphadp0_case"),s,sep="_")
            res <- c(res,res_curr)
          }
        }
        res
      }
    }
    
    if (!("BrS" %in% use_measurements) & "SS" %in% use_measurements){
      in_init       <-   function(){
        tmp_thetaSS <- list()
        #tmp_psiSS <- list()
        tmp_Icat_case <- list()
        for(i in seq_along(JSS_list)){
          GSS_TPR_curr <- eval(parse(text = paste0("GSS_TPR_",i)))
          if (GSS_TPR_curr==1){
            tmp_thetaSS[[i]] <- stats::rbeta(JSS_list[[i]],1,1)
          } else{
            tmp_thetaSS[[i]] <- matrix(stats::rbeta(GSS_TPR_curr*JSS_list[[i]],1,1),
                                       nrow=GSS_TPR_curr,ncol=JSS_list[[i]])
          }
          if (i==1){
            #if (length(JSS_list)>1){
            #  warning("==[baker] Only the first slice of silver-standard data is used to 
            #          initialize 'Icat' in JAGS fitting. Choose wisely!\n ==")
            #}  
            tmp_Icat_case[[i]] <- init_latent_jags_multipleSS(MSS_list,likelihood$cause_list)
          }
        }
        
        res <- c(tmp_thetaSS,tmp_Icat_case)
        names(res) <- c(paste("thetaSS", seq_along(JSS_list), sep = "_"),"Icat")
        res
      }
    } 
    
    if ("BrS" %in% use_measurements & "SS" %in% use_measurements){    
      in_init       <-   function(){
        res <- list()
        for (s in seq_along(Mobs$MBS)){
          res_curr <- list()
          if (likelihood$k_subclass[s]==1){
            #res_curr[[1]] <- stats::rbeta(JBrS_list[[s]],1,1)
            GBrS_TPR_curr <- eval(parse(text = paste0("GBrS_TPR_",s)))
            if (GBrS_TPR_curr==1){
              res_curr[[1]] <- stats::rbeta(JBrS_list[[s]],1,1)
            } else{
              res_curr[[1]] <- matrix(stats::rbeta(GBrS_TPR_curr*JBrS_list[[s]],1,1),
                                      nrow=GBrS_TPR_curr,ncol=JBrS_list[[s]])
              if (JBrS_list[[s]]==1){
                res_curr[[1]] <- c(res_curr[[1]])
              }
            }
            res_curr[[2]] <- stats::rbeta(JBrS_list[[s]],1,1)
            names(res_curr) <- paste(c("thetaBS","psiBS"),s,sep="_")
            res <- c(res,res_curr)
          }
          if (likelihood$k_subclass[s] > 1){
            K_curr <- likelihood$k_subclass[s]
            res_curr[[1]] <- c(rep(.5,K_curr-1),NA)
            res_curr[[2]] <- c(rep(.5,K_curr-1),NA)
            # for different Eta's:
            # res_curr[[2]] <- cbind(matrix(rep(.5,Jcause*(K_curr-1)),
            #                               nrow=Jcause,ncol=K_curr-1),
            #                              rep(NA,Jcause))
            res_curr[[3]] <- 1
            res_curr[[4]] <- 1
            
            names(res_curr) <- paste(c("r0","r1","alphadp0","alphadp0_case"),s,sep="_")
            res <- c(res,res_curr)
          }
        }
        
        tmp_thetaSS <- list()
        #tmp_psiSS <- list()
        tmp_Icat_case <- list()
        for(i in seq_along(JSS_list)){
          GSS_TPR_curr <- eval(parse(text = paste0("GSS_TPR_",i)))
          if (GSS_TPR_curr==1){
            tmp_thetaSS[[i]] <- stats::rbeta(JSS_list[[i]],1,1)
          } else{
            tmp_thetaSS[[i]] <- matrix(stats::rbeta(GSS_TPR_curr*JSS_list[[i]],1,1),nrow=GSS_TPR_curr,ncol=JSS_list[[i]])
          }
          if (i==1){
            #if (length(JSS_list)>1){
            # warning("==[baker] Only the first slice of silver-standard data is
            #         used to initialize 'Icat' in JAGS fitting. Choose wisely!==\n ")
            #}
            tmp_Icat_case[[i]] <- init_latent_jags_multipleSS(MSS_list,likelihood$cause_list)
          }
        }
        res2 <- c(tmp_thetaSS,tmp_Icat_case)
        names(res2) <- c(paste("thetaSS", seq_along(JSS_list), sep = "_"),"Icat")
        #print(res2)
        c(res,res2)
      }
    }
    
    # etiology (measurement independent)
    alphaEti          <- prior$Eti_prior    # <-------- input etiology prior here.
    
    #
    # fit model :
    #
    
    # special operations:
    # get individual prediction:
    if (!is.null(mcmc_options$individual.pred) && mcmc_options$individual.pred){out_parameter <- c(out_parameter,"Icat")}
    # get posterior predictive distribution of BrS measurments:
    if (!is.null(mcmc_options$ppd) && mcmc_options$ppd){out_parameter <- c(out_parameter,paste("MBS.new",seq_along(Mobs$MBS),sep = "_"))}
    
    #
    # write the .bug files into mcmc_options$bugsmodel.dir; 
    # could later set it equal to result.folder.
    #
    
    use_jags <- (!is.null(mcmc_options$use_jags) && mcmc_options$use_jags)
    model_func         <- write_model_NoReg(model_options$likelihood$k_subclass,
                                            data_nplcm$Mobs,
                                            model_options$prior,
                                            model_options$likelihood$cause_list,
                                            model_options$use_measurements,
                                            mcmc_options$ppd,
                                            use_jags)
    
    model_bugfile_name <- "model_NoReg.bug"
    
    filename <- file.path(mcmc_options$bugsmodel.dir, model_bugfile_name)
    writeLines(model_func, filename)
    #
    # run the model:
    #
    # if (!use_jags){
    #   ##winbugs is the only current option:
    #   gs <- R2WinBUGS::bugs(data     = in_data,
    #                         inits    = in_init, 
    #                         parameters.to.save = out_parameter,
    #                         model.file = filename,
    #                         working.directory=mcmc_options$result.folder,
    #                         bugs.directory  = mcmc_options$winbugs.dir,  #<- special to WinBUGS.
    #                         n.iter         = mcmc_options$n.itermcmc,
    #                         n.burnin       = mcmc_options$n.burnin,
    #                         n.thin         = mcmc_options$n.thin,
    #                         n.chains       = mcmc_options$n.chains,
    #                         DIC      = FALSE,
    #                         debug    = mcmc_options$debugstatus);
    #   return(gs)
    # }
    
    here <- environment()
    if (use_jags){
      ##JAGS
      in_data.list <- lapply(as.list(in_data),get, envir= here)
      names(in_data.list) <- in_data
      #lapply(names(in_data.list), dump, append = TRUE, envir = here,
      #       file = file.path(mcmc_options$result.folder,"jagsdata.txt"))
      #do.call(file.remove, list(list.files(mcmc_options$result.folder, full.names = TRUE)))
      curr_data_txt_file <- file.path(mcmc_options$result.folder,"jagsdata.txt")
      if(file.exists(curr_data_txt_file)){file.remove(curr_data_txt_file)}
      dump(names(in_data.list), append = FALSE, envir = here,
           file = curr_data_txt_file)
      ## fix dimension problem.... convert say .Dmi=7:6 to c(7,6) (an issue for templateBS_1):
      bad_jagsdata_txt <- readLines(curr_data_txt_file)
      good_jagsdata_txt <- gsub( "([0-9]+):([0-9]+)", "c(\\1,\\2)", bad_jagsdata_txt,fixed = FALSE)
      writeLines(good_jagsdata_txt, curr_data_txt_file)
      
      # fix dimension problem.... convert say 7:6 to c(7,6) (an issue for a dumped matrix):
      inits_fnames <- list.files(mcmc_options$result.folder,pattern = "^jagsinits[0-9]+.txt",
                                 full.names = TRUE)
      for (fiter in seq_along(inits_fnames)){
        curr_inits_txt_file <- inits_fnames[fiter]
        bad_jagsinits_txt <- readLines(curr_inits_txt_file)
        good_jagsinits_txt <- gsub( "([0-9]+):([0-9]+)", "c(\\1,\\2)", bad_jagsinits_txt,fixed = FALSE)
        writeLines(good_jagsinits_txt, curr_inits_txt_file)
      }
      
      gs <- jags2_baker(data   = curr_data_txt_file,
                          inits  = in_init,
                          parameters.to.save = out_parameter,
                          model.file = filename,
                          working.directory = mcmc_options$result.folder,
                          n.iter         = as.integer(mcmc_options$n.itermcmc),
                          n.burnin       = as.integer(mcmc_options$n.burnin),
                          n.thin         = as.integer(mcmc_options$n.thin),
                          n.chains       = as.integer(mcmc_options$n.chains),
                          DIC            = FALSE,
                          clearWD        = FALSE,              #<--- special to JAGS.
                          jags.path      = mcmc_options$jags.dir# <- special to JAGS.
      )
      return(gs)
    }
  }

#' Initialize individual latent status (only for JAGS)
#' 
#' @details In JAGS 3.4.0, if an initial value contradicts the probabilistic specification, e.g.
#' \code{MSS_1[i,j] ~ dbern(mu_ss_1[i,j])}, where \code{MSS_1[i,j]=1} but \code{mu_ss_1[i,j]=0},
#' then JAGS cannot understand it. In PERCH application, this is most likely used when the specificity of the 
#' silver-standard data is 1. Note: this is not a problem in WinBUGS.
#' 
#' 
#' @param MSS_list A list of silver-standard measurement data, possibly with more than one 
#' slices; see \code{data_nplcm} argument in \code{\link{nplcm}}
#' @param cause_list See \code{model_options} arguments in \code{\link{nplcm}}
#' @param patho A vector of measured pathogen name for MSS; default is \code{colnames(MSS)}
#' 
#' @return a list of numbers, indicating categories of individual latent causes.
#' 
#' @family initialization functions
#' @export
init_latent_jags_multipleSS <- function(MSS_list,cause_list,
                                        patho=unlist(lapply(MSS_list,colnames))){
  # <--- revising for multiple silver-standard data.
  #table(apply(MSS,1,function(v) paste(v,collapse="")))
  MSS <- do.call(cbind,MSS_list)
  ind_positive <- which(apply(MSS,1,sum,na.rm=TRUE)>0)
  res <- sample.int(length(cause_list),size = nrow(MSS), replace=TRUE)
  if (length(ind_positive)>0){
    vec <- sapply(ind_positive, function(i) paste(unique(patho[which(MSS[i,]==1)]),collapse="+"))
    res[ind_positive] <- match_cause(cause_list,vec)
  }
  if (sum(is.na(res[ind_positive]))>0){ # <--- corrected to add res[].
    ind_NA <- which(is.na(res))
    stop(paste0("==[baker] Case(s) The ",paste(ind_NA,collapse=", "), "-th subject(s) have positive silver-standard
                measurements on pathogen combinations not specified in the 'cause_list' of 
                'model_options$likelihood'! Please consider if you want to delete these cases,
                or to add these combinations into 'cause_list'.==\n"))
  }
  res
  }

# MSS_list <- data_nplcm$Mobs$MSS
# cause_list <- model_options$likelihood$cause_list
# patho <- unlist(lapply(MSS_list,colnames))
# 
# init_latent_jags_multipleSS(MSS_list,cause_list)
# 
