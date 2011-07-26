function [cpxx, cpyy, dist] = cpSquare(xx, yy, cen)
%CPSQUARE  Closest Point function for a square
%   [cpx, cpy, dist] = cpSquare(x, y)
%      A square with side length 2 centered centered at
%      the origin.
%   [cpx, cpy, dist] = cpSquare(x, y, xc, yc)
%      A square with side length 2 centered centered at
%      the point (xc,yc)
%
%   Code is vectorized: any size/shape for x should work.
%   (well sort of: a loop inside)

  % defaults
  if (nargin < 3)
    cen = [0, 0];
  end

  % shift to the origin
  xx = xx - cen(1);
  yy = yy - cen(2);

  cpxx = zeros(size(xx));
  cpyy = zeros(size(yy));

  for i=1:length(xx(:))
    x = xx(i);
    y = yy(i);

    if (y >= 1)
      cpy = 1;
    elseif (y <= -1)
      cpy = -1;
    elseif (y >= abs(x))
      cpy = 1;
    elseif (y <= -abs(x))
      cpy = -1;
    else
      cpy = y;
    end

    if (x >= 1)
      cpx = 1;
    elseif (x <= -1)
      cpx = -1;
    elseif (x >= abs(y))
      cpx = 1;
    elseif (x <= -abs(y))
      cpx = -1;
    else
      cpx = x;
    end

    cpxx(i) = cpx;
    cpyy(i) = cpy;
  end

  dist = sqrt( (xx-cpxx).^2 + (yy-cpyy).^2 );

  % shift back
  cpx = cpx + cen(1);
  cpy = cpy + cen(2);

