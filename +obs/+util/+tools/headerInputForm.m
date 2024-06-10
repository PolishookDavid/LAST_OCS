function serialized=headerInputForm(Header)
% Header is an Nx3 cell containing Key, Val, Desc (eventually empty). this
%  function transforms it in a string suitable as argument for eval()
    nkeys=size(Header,1);

    valuecol=cell(size(Header,1),1);
    for i=1:nkeys
        val=Header{i,2};
        if isnumeric(val)
            if isempty(val)
                valuecol{i}='[]';
            else
                if isinteger(val)
                    valuecol{i}=num2str(val);
                else
                    valuecol{i}=num2str(val,'%f');
                end
            end
        else
            valuecol{i}=sprintf('''%s''',val);
        end
    end

    serialized=['[{' sprintf('''%s'';',Header{:,1}) '},{' ...
                    sprintf('%s;',valuecol{:}) '},{' ...
                    sprintf('''%s'';',Header{:,3}) '}]'];