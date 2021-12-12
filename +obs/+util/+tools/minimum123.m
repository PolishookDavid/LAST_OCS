function [xmin,ymin]=minimum123(x,y)
% find the (interpolated) position and value of the minimum of a vector of
%  values y (corresponding at abscissae x), possibly containing NaNs.
% The rule is:
%  - if the minimum value has two non-NaN neigbours, find the position as
%    that of the vertex of a parabola passing by the three points
%  - if the minimum is isolated, or at the extreme of the array, use the
%    value itself
    usablePoints=find(~isnan(y(:)));
    switch numel(usablePoints)
        case 0
            xmin=NaN;
            ymin=NaN;
        case 1
            % only one position with non NaN focus, use it
            xmin=x(usablePoints);
            ymin=y(usablePoints);
        case 2
            % two positions with non NaN focus, use the best
            [ymin,imin]= min(y(usablePoints));
            xmin=x(imin);
        otherwise
            [~,imin] = min(y(usablePoints));
            % minimum if the minimum is at the extremum
            if imin==1 || imin==numel(usablePoints)
                xmin=x(usablePoints(imin));
                ymin=y(usablePoints(imin));
            else
                % otherwise, three point parabolic interpolation
                p=usablePoints(imin-1:imin+1);
                f=x(p);
                v=y(p);
                [xmin,ymin]= obs.util.tools.parabolicInterpolation(f,v);
            end
    end
