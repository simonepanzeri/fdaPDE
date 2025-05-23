#' Density initialization
#' 
#' @param data A matrix of dimensions #observations-by-ndim. Data are locations: each row corresponds to one point, 
#' the first column corresponds to the \code{x}-coordinates, the second column corresponds to the \code{y}-coordinates 
#' and, if ndim=3, the third column corresponds to the \code{z}-coordinates. 
#' @param FEMbasis A \code{FEMbasis} object describing the Finite Element basis, as created by \code{\link{create.FEM.basis}}.
#' @param lambda A scalar or vector of smoothing parameters. Default is NULL. It is useful only if \code{init='Heat'}.
#' @param heatStep Real specifying the time step for the discretized heat diffusionn process.
#' @param heatIter Integer specifying the number of iteriations to perform the discretized heat diffusion process.
#' @param init String. This parameter specifies the initialization procedure. It can be either 'Heat' or 'CV'.
#' @param nFolds An integer specifying the number of folds used in cross validation techinque. It is useful only 
#' for the case \code{init = 'CV'}.
#' @param search a flag to decide the search algorithm type (tree or naive or walking search algorithm).
#' @return If \code{init = 'Heat'} it returns a matrix in which each column contains the initial vector 
#' for each \code{lambda}. If \code{init = 'CV'} it returns the initial vector associated to the \code{lambda} given.
#' @description This function implements two methods for the density initialization procedure.
#' @usage DE.heat.FEM(data, FEMbasis, lambda=NULL, heatStep=0.1, heatIter=500, 
#'             init="Heat", nFolds=5, search = "tree")
#' @export
#' @examples
#' library(fdaPDE)
#' 
#' ## Create a 2D mesh over a squared domain
#' Xbound <- seq(-3, 3, length.out = 10)
#' Ybound <- seq(-3, 3, length.out = 10)
#' grid_XY <- expand.grid(Xbound, Ybound)
#' Bounds <- grid_XY[(grid_XY$Var1 %in% c(-3, 3)) | (grid_XY$Var2 %in% c(-3, 3)), ]
#' mesh <- create.mesh.2D(nodes = Bounds, order = 1)
#' mesh <- refine.mesh.2D(mesh, maximum_area = 0.2)
#' FEMbasis <- create.FEM.basis(mesh)
#' 
#' ## Generate data
#' n <- 50
#' set.seed(10)
#' data_x <- rnorm(n)
#' data_y <- rnorm(n)
#' data <- cbind(data_x, data_y)
#' 
#' plot(mesh)
#' points(data, col="red", pch=19, cex=0.5)
#' 
#' ## Density initialization
#' lambda = 0.1
#' sol = DE.heat.FEM(data, FEMbasis, lambda, heatStep=0.1, heatIter=500, init="Heat")
#' 
#' ## Visualization 
#' plot(FEM(coeff=sol$f_init, FEMbasis=FEMbasis))

DE.heat.FEM <- function(data, FEMbasis, lambda=NULL, heatStep=0.1, heatIter=500, init="Heat", nFolds=5, search="tree") 
{ 
  if(is(FEMbasis$mesh, "mesh.2D")){
    ndim = 2
    mydim = 2
  }else if(is(FEMbasis$mesh, "mesh.2.5D")){
    ndim = 3
    mydim = 2
  }else if(is(FEMbasis$mesh, "mesh.3D")){
    ndim = 3
    mydim = 3
  }else if(is(FEMbasis$mesh, "mesh.1.5D")){
    ndim=2
    mydim=1
  }else{
    stop('Unknown mesh class')
  }
  
  scaling= sqrt(dim(data)[1]); stepProposals=NULL; fvec=NULL;
  tol1=1e-4; tol2=0; print=FALSE; nfolds=0; nsimulations=500; step_method="Fixed_Step";
  direction_method="BFGS"; preprocess_method="NoCrossValidation"; inference = FALSE

    # Search algorithm
  if(search=="naive"){
    search=1
  }else if(search=="tree"){
    search=2
  }else if(search=="walking" & is(FEMbasis$mesh, "mesh.2.5D")){
  stop("walking search is not available for mesh class mesh.2.5D.")
  }else if(search=="walking" & is(FEMbasis$mesh, "mesh.1.5D")){
    stop("walking search is not available for mesh class mesh.1.5D.")
  }else if(search=="walking" & !is(FEMbasis$mesh, "mesh.2.5D") & !is(FEMbasis$mesh, "mesh.1.5D")){
    search=3
  }else{
    stop("'search' must must belong to the following list: 'naive', 'tree' or 'walking'.")
  }


  ###################### Checking parameters, sizes and conversion #################################
  checkParametersDE_init(data, FEMbasis, lambda, heatStep, heatIter, init, search) 
  
  ## Coverting to format for internal usage
  data = as.matrix(data)
  lambda = as.vector(lambda)
  
  checkParametersSizeDE_init(data, ndim) 
  ###################### End checking parameters, sizes and conversion #############################
  
  
  ###################### C++ Code Execution #########################################################
  bigsol = NULL
  if(is(FEMbasis$mesh, "mesh.2D")){	  
    
    bigsol = CPP_FEM.DE_init(data, FEMbasis, lambda, scaling, fvec, heatStep, heatIter, ndim, mydim, step_method, direction_method, preprocess_method,
                        stepProposals, tol1, tol2, print, nfolds, nsimulations, search, init, nFolds, inference)
    
  } else if(is(FEMbasis$mesh, "mesh.2.5D")){
    
    bigsol = CPP_FEM.manifold.DE_init(data, FEMbasis, lambda, scaling, fvec, heatStep, heatIter, ndim, mydim, step_method, direction_method, preprocess_method,
                                 stepProposals, tol1, tol2, print, nfolds, nsimulations, search, init, nFolds, inference)
    
  } else if(is(FEMbasis$mesh, "mesh.3D")){
    bigsol = CPP_FEM.volume.DE_init(data, FEMbasis, lambda, scaling, fvec, heatStep, heatIter, ndim, mydim, step_method, direction_method, preprocess_method,
                               stepProposals, tol1, tol2, print, nfolds, nsimulations, search, init, nFolds, inference)
  }else if(is(FEMbasis$mesh, "mesh.1.5D")){
    bigsol = CPP_FEM.graph.DE_init(data, FEMbasis, lambda, scaling, fvec, heatStep, heatIter, ndim, mydim, step_method, direction_method, preprocess_method,
                               stepProposals, tol1, tol2, print, nfolds, nsimulations, search, init, nFolds, inference)
  }
  
  ###################### Collect Results ############################################################  
  
  f_init = bigsol[[1]]
  
  reslist = list(f_init = f_init)
  return(reslist)
}
