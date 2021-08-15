function [f0,v0]=parabolicInterpolation(f,v)
% find the vertex of a parabola given three points
% trivial as it is, I'm not sure there is a pre-built function for it

% using https://stackoverflow.com/questions/717762/how-to-calculate-the-vertex-of-a-parabola-given-three-points
% for lazyness

 denom = (f(1)-f(2)) * (f(1)-f(3)) * (f(2)-f(3));
 A = (f(3) * (v(2)-v(1)) + f(2) * (v(1)-v(3)) + f(1) * (v(3)-v(2))) / denom;
 B = (f(3)^2*(v(1)-v(2)) + f(2)^2*(v(3)-v(1)) + f(1)^2*(v(2)-v(3))) / denom;
 C = (f(2)*f(3)*(f(2)-f(3))*v(1) + f(3)*f(1)*(f(3)-f(1))*v(2) + ...
      f(1)*f(2)*(f(1)-f(2))*v(3) ) / denom;

 f0 = -B / (2*A);
 v0 = C-B^2 / (4*A);
