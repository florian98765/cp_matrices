function [E,DiagwLinverse] = buildCPmatrixFromLaplacian3d2ndOrder2ndAttempt(x, y, z, xi, yi, zi, p, band, use_ndgrid)
% buildCPmatrixFromLaplacian3d 
% Return a 3D pseudo-interpolation matrix with the help of discrete Laplacian.

% u(cp) = u(cp) + [\Delta u](cp) - [\Delta u](cp)
% we then approximate the first [\Delta u](cp) using finite differences,
% hoping to get some positive weights for off-diag entries, and replace the
% second [\Delta u](cp) by what we know from the orginal PDE.



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

  %tic
  Ei = repmat((1:length(xi))',1,EXTSTENSZ);
  Ej = zeros(size(Ei));
  weights = zeros(size(Ei));
  % todo: integers seem slower(!), although use less memory.
  %Ei = repmat(uint32((1:length(xi))'),1,EXTSTENSZ);
  %Ej = zeros(size(Ei), 'uint32');
  %weights = zeros(size(Ei), 'double');
  %toc
  
  %tic
  % this used to be a call to buildInterpWeights but now most of
  % that is done here
  [Ibpt, Xgrid] = findGridInterpBasePt_vec({xi yi zi}, p, ptL, ddx);
  
  % relative coordinates w.r.t. the central block.
  cpxn = cell(6,1); 
  cpyn = cell(6,1);
  cpzn = cell(6,1);
  for i = 1:6
      cpxn{i} = xi;
      cpyn{i} = yi;
      cpzn{i} = zi;
  end
  cpxn{1} = xi - dx;
  cpxn{2} = xi + dx;
  cpyn{3} = yi - dy;
  cpyn{4} = yi + dy;
  cpzn{5} = zi - dz;
  cpzn{6} = zi + dz;
    
  %tic
  % compute the weights and positions
  for cnt = 1:6
      xw = LagrangeWeights1D_vec(Xgrid{1}, cpxn{cnt}, ddx(1),N);
      yw = LagrangeWeights1D_vec(Xgrid{2}, cpyn{cnt}, ddx(2),N);
      zw = LagrangeWeights1D_vec(Xgrid{3}, cpzn{cnt}, ddx(3),N);
      for k=1:N
          for i=1:N
              for j=1:N
                  gi = (Ibpt{1} + i - 1);
                  gj = (Ibpt{2} + j - 1);
                  gk = (Ibpt{3} + k - 1);
                  ijk = sub2ind([N,N,N], j, i, k);
                  weights(:,ijk) = weights(:,ijk) + xw(:,i) .* yw(:,j) .* zw(:,k);
        
                  if (use_ndgrid)
                      Ej(:,ijk) = sub2ind([Nx,Ny,Nz], gi, gj, gk);
                      %Ej(:,ijk) = (gk-1)*(Nx*Ny) + (gj-1)*Nx + gi;
                  else
                      % all these do the same, but last one is fastest.  Although sub2ind
                      % presumably has safety checks...
                      %ind = (gk-1)*(Nx*Ny) + (gi-1)*Ny + gj;
                      %ind = sub2ind([Ny,Nx,Nz], gj, gi, gk);
                      %ind = round((gk-1)*(Nx*Ny) + (gi-1)*(Ny) + gj-1 + 1);
                      Ej(:,ijk) = (gk-1)*(Nx*Ny) + (gi-1)*Ny + gj;
                  end
              end
          end
      end
  end
  weights = weights/dx^2;
  %toc
  T1 = cputime() - T1;
  %fprintf('done new Ei,Ej,weights, total time: %g\n', T1);

  E = sparse(Ei(:), Ej(:), weights(:), length(xi), M);
  E = E(:,band);
  
  % divide by the diagonal entries of the Laplace matrix to actually get
  % the entries of E
  DiagwLinverse = dx^2/6 * speye(length(xi),length(xi));
  %Epseudo = DiagwLinverse * E;
end
