function L = buildLaplacianMatrixAtCP(x, y, z, xi, yi, zi, p, band, use_ndgrid)


  % input checking
  if (~isvector(x)) || (~isvector(y)) || (~isvector(z))
    error('x, y and z must be vectors, not e.g., meshgrid output');
  end
  if ~(  (ndims(xi) == 2) && (size(xi,2) == 1)  )
    error('xi must be a column vector');
  end
  if ~(  (ndims(yi) == 2) && (size(yi,2) == 1)  )
    error('yi must be a column vector');
  end
  if ~(  (ndims(zi) == 2) && (size(zi,2) == 1)  )
    error('zi must be a column vector');
  end

  if (nargin == 6)
    p = [];
    makeBanded = false;
    use_ndgrid = false;
  elseif (nargin == 7)
    makeBanded = false;
    use_ndgrid = false;
  elseif (nargin == 8)
    if isempty(band) makeBanded = false; else makeBanded = true; end
    use_ndgrid = false;
  elseif (nargin == 9)
    if isempty(band) makeBanded = false; else makeBanded = true; end
  else
    error('unexpected inputs');
  end

  if (isempty(p))
    p = 3;
  end

  if (nargout > 1)
    makeListOutput = true;
  else
    makeListOutput = false;
  end

  T1 = cputime();
  dx = x(2)-x(1);   Nx = length(x);
  dy = y(2)-y(1);   Ny = length(y);
  dz = z(2)-z(1);   Nz = length(z);
  ddx = [dx  dy  dz];
  ptL = [x(1) y(1) z(1)];
  M = Nx*Ny*Nz;

  if (M > 1e15)
    error('too big to use doubles as indicies: implement int64 indexing')
  end

  dim = 3;
  N = p+1;
  EXTSTENSZ = N^dim;

  Li = repmat((1:length(xi))',1,EXTSTENSZ);
  Lj = zeros(size(Li));
  weights = zeros(size(Li));
  
  %tic
  % this used to be a call to buildInterpWeights but now most of
  % that is done here
  [Ibpt, Xgrid] = findGridInterpBasePt_vec({xi yi zi}, p, ptL, ddx);
  xw = LagrangeWeights1D_vec(Xgrid{1}, xi, ddx(1), N);
  yw = LagrangeWeights1D_vec(Xgrid{2}, yi, ddx(2), N);
  zw = LagrangeWeights1D_vec(Xgrid{3}, zi, ddx(3), N);
  
  % relative coordinates w.r.t. the central block.
  hx = xi - Xgrid{1} - dx;
  hy = yi - Xgrid{2} - dx;
  hz = zi - Xgrid{3} - dx;
            
  % weights of the laplacian in each coordinate direction.
  xwL = LaplacianWeightsUniform1D_vec(dx,hx);
  ywL = LaplacianWeightsUniform1D_vec(dy,hy);
  zwL = LaplacianWeightsUniform1D_vec(dz,hz);
  
  
  %tic
  % compute the weights and positions
  for k=1:N
    for i=1:N
      for j=1:N
        gi = (Ibpt{1} + i - 1);
        gj = (Ibpt{2} + j - 1);
        gk = (Ibpt{3} + k - 1);
        ijk = sub2ind([N,N,N], j, i, k);
        weights(:,ijk) = weights(:,ijk) + xwL(:,i) .* yw(:,j) .* zw(:,k);
        weights(:,ijk) = weights(:,ijk) + ywL(:,j) .* xw(:,i) .* zw(:,k);
        weights(:,ijk) = weights(:,ijk) + zwL(:,k) .* xw(:,i) .* yw(:,j);
        
        
        if (use_ndgrid)
          Lj(:,ijk) = sub2ind([Nx,Ny,Nz], gi, gj, gk);
          %Lj(:,ijk) = (gk-1)*(Nx*Ny) + (gj-1)*Nx + gi;
        else
          % all these do the same, but last one is fastest.  Although sub2ind
          % presumably has safety checks...
          %ind = (gk-1)*(Nx*Ny) + (gi-1)*Ny + gj;
          %ind = sub2ind([Ny,Nx,Nz], gj, gi, gk);
          %ind = round((gk-1)*(Nx*Ny) + (gi-1)*(Ny) + gj-1 + 1);
          Lj(:,ijk) = (gk-1)*(Nx*Ny) + (gi-1)*Ny + gj;
        end
      end
    end
  end
  %toc
  T1 = cputime() - T1;
  %fprintf('done new Ei,Ej,weights, total time: %g\n', T1);

  L = sparse(Li(:), Lj(:), weights(:), length(xi), M);
  L = L(:,band);
  
end
