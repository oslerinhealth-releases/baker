#' Insert measurement likelihood (without regression) code chunks into .bug model file
#' 
#' @param k_subclass the number of subclasses for the slices that require 
#' conditional dependence modeling (only applicable to BrS data); its length is 
#' of the same value as the number of BrS slices.
#' @param Mobs measurement data in the form of \code{data_nplcm}
#' @param prior prior specification from \code{model_options}
#' @param cause_list a list of latent status names (crucial for building templates; 
#' see \code{\link{make_template}})
#' @param use_measurements "BrS", or "SS"
#' @param ppd Default is NULL; set to TRUE for posterior predictive checking
#' @param use_jags Default is FALSE; set to TRUE if want to use JAGS for model fitting.
#' 
#' @return a long character string to be inserted into .bug model file as measurement
#' likelihood
#' 
#' @seealso It is used in \link{write_model_NoReg} for constructing a .bug file along with
#' specification of latent status distribution (\link{insert_bugfile_chunk_noreg_etiology})
#' 
#' @export
insert_bugfile_chunk_noreg_meas <-
  function(k_subclass,Mobs,prior,cause_list,use_measurements = "BrS",ppd=NULL,use_jags=FALSE) {
    if (!("BrS" %in% use_measurements) && !("SS" %in% use_measurements)){
      stop("==[baker] No BrS or SS measurements specified in the model! ==")
    }
    for (s in seq_along(Mobs$MBS)){
      if (k_subclass[s]>1 && ncol(Mobs$MBS[[s]])==1){
        stop("==[baker] Cannot do nested modeling for BrS measurements with only one column! ==")
      }  
    }
    
    # generate file:
    if ("BrS" %in% use_measurements){
      chunk_BrS_case <- ""
      chunk_BrS_ctrl <- ""
      chunk_BrS_subclass <- ""
      chunk_BrS_param <- ""
      for (s in seq_along(Mobs$MBS)){# begin iterate over slices:
        k_curr <- k_subclass[s]
        if (k_curr == 1 ){
          if (!use_jags){ # use winbugs:
            chunk_BrS_case  <- paste0(chunk_BrS_case,  add_meas_BrS_case_NoNest_Slice(s,Mobs,cause_list,ppd)$plug)
            chunk_BrS_param <- paste0(chunk_BrS_param, add_meas_BrS_param_NoNest_Slice(s,Mobs,cause_list)$plug)
          } else{# use jags:
            chunk_BrS_case  <- paste0(chunk_BrS_case,  add_meas_BrS_case_NoNest_Slice_jags(s,Mobs,prior,cause_list,ppd)$plug)
            chunk_BrS_param <- paste0(chunk_BrS_param, add_meas_BrS_param_NoNest_Slice_jags(s,Mobs,prior,cause_list)$plug)
          }
          chunk_BrS_ctrl  <- paste0(chunk_BrS_ctrl,  add_meas_BrS_ctrl_NoNest_Slice(s,Mobs,cause_list,ppd)$plug)
        }
        
        if ((k_curr > 1 )){
          if (!use_jags){# use winbugs:
            chunk_BrS_case  <- paste0(chunk_BrS_case,  add_meas_BrS_case_Nest_Slice(s,Mobs,cause_list,ppd)$plug)
            chunk_BrS_param <- paste0(chunk_BrS_param, add_meas_BrS_param_Nest_Slice(s,Mobs,cause_list)$plug)
          }else{#use jags:
            chunk_BrS_case  <- paste0(chunk_BrS_case,  add_meas_BrS_case_Nest_Slice_jags(s,Mobs,cause_list,ppd)$plug)
            chunk_BrS_param <- paste0(chunk_BrS_param, add_meas_BrS_param_Nest_Slice_jags(s,Mobs,cause_list)$plug)
          }
          chunk_BrS_subclass  <- paste0(chunk_BrS_subclass,  add_meas_BrS_subclass_Nest_Slice(s,Mobs,cause_list,ppd)$plug)
          chunk_BrS_ctrl  <- paste0(chunk_BrS_ctrl,  add_meas_BrS_ctrl_Nest_Slice(s,Mobs,cause_list,ppd)$plug)
        }
      }# end iterate over slices.
    }
    
    if ("BrS" %in% use_measurements & !("SS" %in% use_measurements)) {
      chunk <- paste0(
        "
        # BrS measurements:
        for (i in 1:Nd){
        ",chunk_BrS_case,"
        }
        for (i in (Nd+1):(Nd+Nu)){
        ",chunk_BrS_ctrl,"
        }
        
        ",chunk_BrS_subclass,"
        
        # bronze-standard measurement characteristics:
        ",chunk_BrS_param
      )
    }
    
    if ("BrS" %in% use_measurements & ("SS" %in% use_measurements)) {
      nslice_SS <- length(Mobs$MSS)
      chunk <- paste0(
        "
        # BrS and SS measurements:
        for (i in 1:Nd){
        ",chunk_BrS_case,"
        ",add_meas_SS_case(nslice_SS,Mobs,prior,cause_list)$plug,"
        }
        for (i in (Nd+1):(Nd+Nu)){
        ",chunk_BrS_ctrl,"
        }
        
        ",chunk_BrS_subclass,"
        
        # BrS and SS measurement characteristics:
        ",chunk_BrS_param,
        add_meas_SS_param(nslice_SS,Mobs,prior,cause_list)$plug
      )
    }
    
    if (!("BrS" %in% use_measurements) & ("SS" %in% use_measurements)) {
      nslice_SS <- length(Mobs$MSS)
      chunk <- paste0(
        "
        # SS measurements:
        for (i in 1:Nd){
        ",add_meas_SS_case(nslice_SS,Mobs,prior,cause_list)$plug,"
        }
        
        # SS measurement characteristics:
        ",add_meas_SS_param(nslice_SS,Mobs,prior,cause_list)$plug
      )
    }
    
    paste0(chunk,"\n")
  }



#' insert distribution for latent status code chunk into .bug file
#' 
#' @param ppd Default is NULL; set to TRUE for posterior predictive checking 
#' 
#' @return a long character string to be inserted into .bug model file 
#' as distribution specification for latent status
#' 
#' @export
insert_bugfile_chunk_noreg_etiology <- function(ppd = NULL){
  ppd_seg <- ""
  if (!is.null(ppd) && ppd){
    ppd_seg <- paste0("Icat.new[i] ~ dcat(pEti[1:Jcause])")
  }
  chunk_etiology <- paste0(
    "
    # etiology priors
    for (i in 1:Nd){
    Icat[i] ~ dcat(pEti[1:Jcause])
    ",
    ppd_seg,"
    }
    pEti[1:Jcause]~ddirch(alphaEti[])"
  )
  paste0(chunk_etiology,"\n")
}

##############################################################################
###############  REGRESSION MODELS                           #################
##############################################################################

#' Insert measurement likelihood (with regression) code chunks into .bug model file
#' 
#' @param Mobs Measurement data in the form of \code{data_nplcm}
#' @param prior Prior specification from \code{model_options}
#' @param cause_list A list of latent status names (crucial for building templates; 
#' see \code{\link{make_template}})
#' @param FPR_formula A list of FPR regression formula; check \code{model_options$likelihood$FPR_formula}
#' @param use_measurements "BrS", or "SS"
#' @param ppd Default is NULL; set to TRUE for posterior predictive checking
#' @param use_jags Default is FALSE; set to TRUE if want to use JAGS for model fitting.
#' 
#' @return A long character string to be inserted into .bug model file as measurement
#' likelihood
#' 
#' @seealso It is used in \link{write_model_Reg_NoNest} for constructing a .bug file along with
#' specification of latent status regression (\link{insert_bugfile_chunk_reg_etiology})
#' 
#' @export
insert_bugfile_chunk_reg_nonest_meas <-
  function(Mobs,prior,cause_list,FPR_formula,use_measurements = "BrS",ppd=NULL,use_jags=FALSE) {
    if (!("BrS" %in% use_measurements) && !("SS" %in% use_measurements)){
      stop("==[baker] No BrS or SS measurements specified in the model! ==")
    }
    # for (s in seq_along(Mobs$MBS)){
    #   if (k_subclass[s]>1 && ncol(Mobs$MBS[[s]])==1){
    #     stop("==[baker] Cannot do nested modeling for BrS measurements with only one column! ==")
    #   }  
    # }
    
    # generate file:
    if ("BrS" %in% use_measurements){
      chunk_BrS_case <- ""
      chunk_BrS_ctrl <- ""
      chunk_BrS_subclass <- ""
      chunk_BrS_param <- ""
      for (s in seq_along(Mobs$MBS)){# begin iterate over slices:
        # k_curr <- k_subclass[s]
        # if (k_curr == 1 ){
        if (!use_jags){ # use winbugs:
          stop("==[baker] WinBUGS code not developed. Set 'use_jags=TRUE'. ==\n")
          #chunk_BrS_case  <- paste0(chunk_BrS_case,  add_meas_BrS_case_NoNest_reg_Slice_jags(s,Mobs,cause_list,ppd)$plug)
          #chunk_BrS_param <- paste0(chunk_BrS_param, add_meas_BrS_param_NoNest_reg_Slice_jags(s,Mobs,cause_list)$plug)
        } else{# use jags:
          chunk_BrS_case  <- paste0(chunk_BrS_case,  add_meas_BrS_case_NoNest_reg_Slice_jags(s,Mobs,prior,cause_list,ppd)$plug)
          chunk_BrS_param <- paste0(chunk_BrS_param, add_meas_BrS_param_NoNest_reg_Slice_jags(s,Mobs,prior,cause_list,FPR_formula)$plug)
        }
        chunk_BrS_ctrl  <- paste0(chunk_BrS_ctrl,  add_meas_BrS_ctrl_NoNest_reg_Slice_jags(s,Mobs,cause_list,ppd)$plug)
        # }
        
        # if ((k_curr > 1 )){
        #   if (!use_jags){# use winbugs:
        #     chunk_BrS_case  <- paste0(chunk_BrS_case,  add_meas_BrS_case_Nest_Slice(s,Mobs,cause_list,ppd)$plug)
        #     chunk_BrS_param <- paste0(chunk_BrS_param, add_meas_BrS_param_Nest_Slice(s,Mobs,cause_list)$plug)
        #   }else{#use jags:
        #     chunk_BrS_case  <- paste0(chunk_BrS_case,  add_meas_BrS_case_Nest_Slice_jags(s,Mobs,cause_list,ppd)$plug)
        #     chunk_BrS_param <- paste0(chunk_BrS_param, add_meas_BrS_param_Nest_Slice_jags(s,Mobs,cause_list)$plug)
        #   }
        #   chunk_BrS_subclass  <- paste0(chunk_BrS_subclass,  add_meas_BrS_subclass_Nest_Slice(s,Mobs,cause_list,ppd)$plug)
        #   chunk_BrS_ctrl  <- paste0(chunk_BrS_ctrl,  add_meas_BrS_ctrl_Nest_Slice(s,Mobs,cause_list,ppd)$plug)
        # }
      }# end iterate over slices.
    }
    
    if ("BrS" %in% use_measurements & !("SS" %in% use_measurements)) {
      chunk <- paste0(
        "
        # BrS measurements:
        for (i in 1:Nd){
        ",chunk_BrS_case,"
        }
        for (i in (Nd+1):(Nd+Nu)){
        ",chunk_BrS_ctrl,"
        }
        ",chunk_BrS_subclass,"
        # BrS measurement characteristics:
        ",chunk_BrS_param
      )
    }
    
    if ("BrS" %in% use_measurements & ("SS" %in% use_measurements)) {
      nslice_SS <- length(Mobs$MSS)
      chunk <- paste0(
        "
        # BrS and SS measurements:
        for (i in 1:Nd){
        ",chunk_BrS_case,"
        ",add_meas_SS_case(nslice_SS,Mobs,prior,cause_list)$plug,"
        }
        for (i in (Nd+1):(Nd+Nu)){
        ",chunk_BrS_ctrl,"
        }
        ",chunk_BrS_subclass,"

        # BrS and SS measurement characteristics:
        ",chunk_BrS_param,
        add_meas_SS_param(nslice_SS,Mobs,prior,cause_list)$plug
      )
    }
    
    if (!("BrS" %in% use_measurements) & ("SS" %in% use_measurements)) {
      nslice_SS <- length(Mobs$MSS)
      chunk <- paste0(
        "
        # SS measurements:
        for (i in 1:Nd){
        ",add_meas_SS_case(nslice_SS,Mobs,prior,cause_list)$plug,"
        }
        
        # SS measurement characteristics:
        ",add_meas_SS_param(nslice_SS,Mobs,prior,cause_list)$plug
      )
    }
    
    paste0(chunk,"\n")
  }



#' insert etiology regression for latent status code chunk into .bug file
#' 
#' @param Eti_formula Etiology regression formula; Check \code{model_options$likelihood$Eti_formula}.
#' @param ppd Default is NULL; set to TRUE for posterior predictive checking 
#' @param Jcause The number of distinct causes, i.e., categories of latent health
#' status; equals \code{length(model_options$likelihood$cause_list)}.
#' 
#' @return a long character string to be inserted into .bug model file 
#' as distribution specification for latent status
#' 
#' @export
insert_bugfile_chunk_reg_etiology <- function(Eti_formula, Jcause, ppd = NULL){
  constant_Eti <- is_intercept_only(Eti_formula)
  
  # ER: etiology regression: #<---- add basis related operation here for PS.
  ER_has_basis <- ifelse(length(grep("s_date",Eti_formula))==0,FALSE,TRUE)
  ER_has_non_basis <- has_non_basis(Eti_formula)
    
  ppd_seg <- ""
  if (!is.null(ppd) && ppd){ppd_seg <- 
    "
      Icat.new[i] ~ dcat(pEti[1:Jcause])
  "}
  if (!constant_Eti){
    chunk_etiology <- paste0(
      "
      # etiology priors:
      mu_Eti_mat <- Z_Eti%*%betaEti # <--- Z_Eti with rows for cases, columns for covariates; betaEti: rows for covariates, columns for 1:Jcause.
      ")
  } else{
    chunk_etiology <- paste0(
      "
      # etiology priors:
      for (j in 1:Jcause){
          mu_Eti_mat[1:Nd,j] <- Z_Eti*betaEti[1,j] 
      }
      ")
  }
  
  ER_basis_seg <- ""
  if (ER_has_basis){
    ER_basis_seg <- paste0(ER_basis_seg,
    "
    # B-spline basis coefficients for etiology regression:
    betaEti[ER_basis_id[1],j] ~ dnorm(0,ER_prec_first)
    for (l in 2:ER_n_basis){# iterate over the vector of B-spline basis:
         betaEti[ER_basis_id[l],j] ~ dnorm(betaEti[ER_basis_id[l-1],j], ER_taubeta[j])
    }
    # select flexible semiparametric regression:
    ER_taubeta0[j,1] ~ dgamma(3,2)       ## <-- flexible fit.
    ER_taubeta_inv[j] ~ dpar(1.5,0.0025) ## <--- constant fit.
    ER_taubeta0[j,2] <- pow(ER_taubeta_inv[j],-1)
    ER_flexible_select[j] ~ dbern(ER_p_flexible_select)
    ER_ind_flex_select[j] <- 2- ER_flexible_select[j]
    ER_taubeta[j] <- ER_taubeta0[j,ER_ind_flex_select[j]]
    ")
  }
  
  ER_non_basis_seg <- ""
  if (ER_has_non_basis){
      ER_non_basis_seg <- paste0(ER_non_basis_seg,
      "
      #non_basis_coefficients (e.g., intercept):
        for (l in ER_non_basis_id){
            betaEti[l,j] ~ dnorm(0,ER_prec_nonbasis) # <- shared with the ps ones.
        }
      ")  
  }
  
  
  if (Jcause > 2) {
    chunk_etiology <- paste0(chunk_etiology,
    "
      for (i in 1:Nd){
        Icat[i] ~ dcat(pEti[i,1:Jcause])
        ",
          ppd_seg,
          "for (j in 1:Jcause){ 
              pEti[i,j] <- phi[i,j]/sum(phi[i,])
              log(phi[i,j]) <- mu_Eti_mat[i,j]
        }
      }
      
       ",
      "for (j in 1:Jcause){",
        ER_basis_seg,
        ER_non_basis_seg,
      " 
      }",
      c("",
        "#hyperprior of smoothness:
        ER_p_flexible_select ~ dbeta(1,1)
        ER_prec_first <- pow(sd_betaEti_basis,-2) #1/4 #precision for ps coefficients - redundant if no ps bases.
        ")[ER_has_basis+1],
      c("",
        "ER_prec_nonbasis <- pow(sd_betaEti_nonbasis,-2) #1/4 #precision nonbasis coefficients        
        ")[ER_has_non_basis+1]
          
      #"for (p in 1:(ncol_dm_Eti)){",
      #    # betaEti[p,1:(Jcause-1)] ~ dmnorm(zero_Jcause_1,0.1*I_Jcause_1)
      #    "
      #    for (j in 1:Jcause){
      #         betaEti[p,j] ~ dnorm(0,1/sd_betaEti^2)
      #    }
      #for (j in 1:(Jcause-1)){
      #  betaEti[p,j] ~ dnorm(0,1/sd_betaEti^2)
      # }
      #  betaEti[p,Jcause] <- 0
      #}"
      )
  } else{
    chunk_etiology <- paste0(chunk_etiology,
      "
      for (i in 1:Nd){
          Icat[i] ~ dcat(pEti[i,1:Jcause])
      ",
          ppd_seg,
        "for (j in 1:Jcause){ 
            pEti[i,j] <- phi[i,j]/sum(phi[i,])
            log(phi[i,j]) <- mu_Eti_mat[i,j]
        }
      }
      for (p in 1:(ncol_dm_Eti)){
          for (j in 1:Jcause){
               betaEti[p,j] ~ dnorm(0,1/sd_betaEti^2)
          } 
          #betaEti[p,1] ~ dnorm(0,1/2.25)
          #betaEti[p,Jcause] <- 0
      }"
    )    
  }
  paste0(chunk_etiology,"\n")
}






















##############################################################################
###############  REGRESSION MODELS: DISCRETE             #################
##############################################################################

#' Insert measurement likelihood (with regression; discrete) code chunks into .bug model file
#' 
#' @param Mobs Measurement data in the form of \code{data_nplcm}
#' @param prior Prior specification from \code{model_options}
#' @param cause_list A list of latent status names (crucial for building templates; 
#' see \code{\link{make_template}})
#' @param use_measurements "BrS", or "SS"
#' @param ppd Default is NULL; set to TRUE for posterior predictive checking
#' @param use_jags Default is FALSE; set to TRUE if want to use JAGS for model fitting.
#' 
#' @return A long character string to be inserted into .bug model file as measurement
#' likelihood
#' 
#' @seealso It is used in \link{write_model_Reg_NoNest} for constructing a .bug file along with
#' specification of latent status regression (\link{insert_bugfile_chunk_reg_etiology})
#' 
#' @export
insert_bugfile_chunk_reg_discrete_predictor_nonest_meas <-
  function(Mobs,prior,cause_list,use_measurements = "BrS",ppd=NULL,use_jags=FALSE) {
    if (!("BrS" %in% use_measurements) && !("SS" %in% use_measurements)){
      stop("==[baker] No BrS or SS measurements specified in the model! ==")
    }
    # for (s in seq_along(Mobs$MBS)){
    #   if (k_subclass[s]>1 && ncol(Mobs$MBS[[s]])==1){
    #     stop("==[baker] Cannot do nested modeling for BrS measurements with only one column! ==")
    #   }  
    # }
    
    # generate file:
    if ("BrS" %in% use_measurements){
      chunk_BrS_case <- ""
      chunk_BrS_ctrl <- ""
      chunk_BrS_subclass <- ""
      chunk_BrS_param <- ""
      for (s in seq_along(Mobs$MBS)){# begin iterate over slices:
        # k_curr <- k_subclass[s]
        # if (k_curr == 1 ){
        if (!use_jags){ # use winbugs:
          stop("==[baker] WinBUGS code coming soon. ==\n")
          #chunk_BrS_case  <- paste0(chunk_BrS_case,  add_meas_BrS_case_NoNest_reg_Slice_jags(s,Mobs,cause_list,ppd)$plug)
          #chunk_BrS_param <- paste0(chunk_BrS_param, add_meas_BrS_param_NoNest_reg_Slice_jags(s,Mobs,cause_list)$plug)
        } else{# use jags:
          chunk_BrS_case  <- paste0(chunk_BrS_case,  add_meas_BrS_case_NoNest_reg_discrete_predictor_Slice_jags(s,Mobs,prior,cause_list,ppd)$plug)
          chunk_BrS_param <- paste0(chunk_BrS_param, add_meas_BrS_param_NoNest_reg_discrete_predictor_Slice_jags(s,Mobs,prior,cause_list)$plug)
        }
        chunk_BrS_ctrl  <- paste0(chunk_BrS_ctrl,  add_meas_BrS_ctrl_NoNest_reg_discrete_predictor_Slice_jags(s,Mobs,cause_list,ppd)$plug)
        # }
        
        # if ((k_curr > 1 )){
        #   if (!use_jags){# use winbugs:
        #     chunk_BrS_case  <- paste0(chunk_BrS_case,  add_meas_BrS_case_Nest_Slice(s,Mobs,cause_list,ppd)$plug)
        #     chunk_BrS_param <- paste0(chunk_BrS_param, add_meas_BrS_param_Nest_Slice(s,Mobs,cause_list)$plug)
        #   }else{#use jags:
        #     chunk_BrS_case  <- paste0(chunk_BrS_case,  add_meas_BrS_case_Nest_Slice_jags(s,Mobs,cause_list,ppd)$plug)
        #     chunk_BrS_param <- paste0(chunk_BrS_param, add_meas_BrS_param_Nest_Slice_jags(s,Mobs,cause_list)$plug)
        #   }
        #   chunk_BrS_subclass  <- paste0(chunk_BrS_subclass,  add_meas_BrS_subclass_Nest_Slice(s,Mobs,cause_list,ppd)$plug)
        #   chunk_BrS_ctrl  <- paste0(chunk_BrS_ctrl,  add_meas_BrS_ctrl_Nest_Slice(s,Mobs,cause_list,ppd)$plug)
        # }
      }# end iterate over slices.
    }
    
    if ("BrS" %in% use_measurements & !("SS" %in% use_measurements)) {
      chunk <- paste0(
        "
        # BrS measurements:
        for (i in 1:Nd){
        ",chunk_BrS_case,"
        }
        for (i in (Nd+1):(Nd+Nu)){
        ",chunk_BrS_ctrl,"
        }
        ",chunk_BrS_subclass,"
        # BrS measurement characteristics:
        ",chunk_BrS_param
      )
    }
    
    if ("BrS" %in% use_measurements & ("SS" %in% use_measurements)) {
      nslice_SS <- length(Mobs$MSS)
      chunk <- paste0(
        "
        # BrS and SS measurements:
        for (i in 1:Nd){
        ",chunk_BrS_case,"
        ",add_meas_SS_case(nslice_SS,Mobs,prior,cause_list)$plug,"
        }
        for (i in (Nd+1):(Nd+Nu)){
        ",chunk_BrS_ctrl,"
        }
        
        ",chunk_BrS_subclass,"
        
        # BrS and SS measurement characteristics:
        ",chunk_BrS_param,
        add_meas_SS_param(nslice_SS,Mobs,prior,cause_list)$plug
      )
    }
    
    if (!("BrS" %in% use_measurements) & ("SS" %in% use_measurements)) {
      nslice_SS <- length(Mobs$MSS)
      chunk <- paste0(
        "
        # SS measurements:
        for (i in 1:Nd){
        ",add_meas_SS_case(nslice_SS,Mobs,prior,cause_list)$plug,"
        }
        
        # SS measurement characteristics:
        ",add_meas_SS_param(nslice_SS,Mobs,prior,cause_list)$plug
      )
    }
    
    paste0(chunk,"\n")
  }

#' insert etiology regression for latent status code chunk into .bug file; discrete predictors
#' 
#' @param ppd Default is NULL; set to TRUE for posterior predictive checking 
#' @param Jcause The number of distinct causes, i.e., categories of latent health
#' status; equals \code{length(model_options$likelihood$cause_list)}.
#' 
#' @return a long character string to be inserted into .bug model file 
#' as distribution specification for latent status
#' 
#' @export
insert_bugfile_chunk_reg_discrete_predictor_etiology <- function(Jcause, ppd = NULL){
  ppd_seg <- ""
  if (!is.null(ppd) && ppd){ppd_seg <- 
    "
    Icat.new[i] ~ dcat(pEti[Eti_stratum_id[i],1:Jcause])
  "}
  chunk_etiology <- paste0(
    "
      ")
  chunk_etiology <- paste0(chunk_etiology,
                           "
     for (i in 1:Nd){
           Icat[i] ~ dcat(pEti[Eti_stratum_id[i],1:Jcause])
           ",
                           ppd_seg,
                           "
     }
     for (s in 1:n_unique_Eti_level){
          pEti[s, 1:Jcause]~ddirch(alphaEti[s,])
      }
   ")
  paste0(chunk_etiology,"\n")
}
