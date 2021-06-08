function DecJ=j2000_Dec(MountObj,varargin)
    % like j2000 but return only Dec

    [~,DecJ] = j2000(MountObj,varargin{:});

end
